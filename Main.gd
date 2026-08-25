extends Node3D
# ============================================================================
#  SKILLS ONE PIECE — orquestrador (mantido FINO de propósito).
#
#  Cada responsabilidade vive no seu próprio script (menos tokens por edição):
#    - WorldEnv       (src/world)     -> luz, céu, fog
#    - MapBuilder     (src/world)     -> mapa FIXO = plataforma + blocos (base)
#    - TreeScatter    (src/world)     -> árvores aleatórias sobre os blocos
#    - PickupSpawner  (src/entities)  -> frutos coletáveis
#    - Hud            (src/ui)        -> barra de técnicas + inventário
#    - Player         (Player.gd)     -> jogador + câmera
# ============================================================================

const TREE_COUNT := 11         # árvores espalhadas sobre blocos
const TREE_SEED := 771026       # semente fixa da distribuição das árvores

# INIMIGOS DESLIGADOS — o mapa é só de lutas entre jogadores. O código deles
# está inteiro em `disabled/enemies/` (Enemy.gd + EnemySpawner.gd + README.md),
# ainda compilando. Religar = pôr `true` aqui. Ver disabled/enemies/README.md.
const ENEMIES_ENABLED := false
const ENEMY_COUNT := 5

var _hud: Hud
var _players_root: Node3D
var _spawner: MultiplayerSpawner
var _enemies: EnemySpawner

# ⚠️ ENTIDADES DO MUNDO PRECISAM DE SPAWNER, IGUAL AOS JOGADORES (2026-08-22).
#
# O boneco de treino, o boneco automático e a espada nasciam dentro de
# `_start_server_content()`, que só roda `if multiplayer.is_server()`, e entravam
# na árvore com `add_child()` puro — fora de qualquer `MultiplayerSpawner`.
# Resultado: **o cliente nunca os recebia**. Quem entrava na sala via um mapa sem
# boneco de treino, sem boneco automático e sem espada, e não tinha como saber
# que eles existiam do outro lado.
#
# O `Placar` não precisa disso porque é criado nos DOIS lados no `_ready()`, com
# o mesmo nome — o RPC resolve pelo caminho do nó. Já estes três têm FÍSICA e
# ESTADO (vida, posição), então criá-los em paralelo faria duas simulações
# divergentes. O caminho certo é o mesmo dos jogadores: o servidor cria, o
# spawner replica, e um `MultiplayerSynchronizer` mantém posição e vida.
var _entities_root: Node3D
var _entity_spawner: MultiplayerSpawner

func _ready() -> void:
	WorldEnv.apply(self)
	var blocks: Array = MapBuilder.build(self)
	TreeScatter.scatter(self, blocks, TREE_COUNT, TREE_SEED)

	# Contêiner + spawner: o SERVIDOR cria os players e o MultiplayerSpawner os
	# replica p/ os clientes. Singleplayer = servidor local (host id 1) -> 1 player.
	_players_root = Node3D.new()
	_players_root.name = "Players"
	add_child(_players_root)

	_spawner = MultiplayerSpawner.new()
	_spawner.name = "PlayerSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _players_root.get_path()
	_spawner.spawn_function = _spawn_player_data

	# Entidades do mundo (bonecos, espada): mesmo desenho dos jogadores.
	_entities_root = Node3D.new()
	_entities_root.name = "Entities"
	add_child(_entities_root)

	_entity_spawner = MultiplayerSpawner.new()
	_entity_spawner.name = "EntitySpawner"
	add_child(_entity_spawner)
	_entity_spawner.spawn_path = _entities_root.get_path()
	_entity_spawner.spawn_function = _spawn_entity_data

	# Placar da rodada (kills/mortes/cronômetro). Existe nos DOIS lados com o
	# MESMO nome — é assim que os RPCs de estado resolvem o caminho do nó.
	var placar := Scoreboard.new()
	placar.name = "Placar"
	add_child(placar)

	_hud = Hud.new()
	add_child(_hud)

	# Inimigos (Fase 7): desligados. O nó só entra na árvore com a flag ligada —
	# e como a flag é const, servidor e clientes montam a MESMA árvore.
	if ENEMIES_ENABLED:
		_enemies = EnemySpawner.new()
		_enemies.name = "EnemyModule"
		add_child(_enemies)

	if multiplayer.is_server():
		ServerManager.peer_joined.connect(_spawn_player_for)
		ServerManager.peer_left.connect(_despawn_player_for)
		# Os spawns iniciais são ADIADOS: chamar MultiplayerSpawner.spawn() durante o
		# _ready (com peer ativo) dá "Parent node is busy adding/removing children".
		_start_server_content.call_deferred()

	# As frutas coletáveis são spawnadas por CADA ÁRVORE (TreeAndFruitGenerator).

# Conteúdo inicial do servidor (adiado p/ depois do _ready): host player (exceto
# dedicado), inimigos + reposição, e o dummy de treino.
func _start_server_content() -> void:
	if not GameFlow.is_dedicated:
		_spawn_player_for(multiplayer.get_unique_id())
	if ENEMIES_ENABLED and _enemies:
		_enemies.start(ENEMY_COUNT)

	# ⚠️ Estes iam para `add_child(self)` direto e só existiam no servidor
	# (2026-08-22). Agora passam pelo spawner e aparecem também no cliente.
	# Desde 2026-08-23 cada boneco só nasce se a preferência dele estiver ligada
	# (menu principal / canto inferior direito da HUD) — ver `GameFlow.dummies`.
	for tipo in POSICAO_DOS_BONECOS:
		if GameFlow.dummy_ligado(tipo):
			_spawn_entity(tipo, POSICAO_DOS_BONECOS[tipo])

	# ⚠️ A ESPADA SAIU DO MAPA (2026-08-23), a pedido do dono: ela é de uso FUTURO.
	#
	# Saiu daqui e SÓ daqui. `src/items/SwordPickup.gd`, a entrada no `_ENTIDADES`
	# abaixo, o combo `Melee.COMBO_SWORD` e as poses de `WeaponPoses` continuam
	# inteiros e compilando — devolver a espada ao mundo é reescrever esta linha:
	#
	#     _spawn_entity("SwordPickup", Vector3(2, 4, -2))
	#
	# Apagar o resto junto seria jogar fora um sistema pronto para poupar um nó.

# FONTE ÚNICA da posição de cada boneco. Estava escrita só no `_start_server_content`
# e o interruptor de partida precisa da MESMA posição para recriar o boneco no
# lugar certo — duas cópias divergiriam no primeiro ajuste de mapa.
#   TrainingDummy: à FRENTE do player (evita nascer um dentro do outro)
#   AutoDummy:     ao lado do primeiro
const POSICAO_DOS_BONECOS := {
	"TrainingDummy": Vector3(0, 4, -8),
	"AutoDummy":     Vector3(4, 4, -8),
}

# ---------------------------------------------------- LIGAR/DESLIGAR OS BONECOS
# Pedido de qualquer peer; QUEM APLICA É O SERVIDOR (2026-08-23).
#
# O boneco é um corpo com física e vida replicado pelo `_entity_spawner` — ver a
# nota grande lá em cima. Deixar cada cliente criar ou apagar o seu daria duas
# simulações divergentes do MESMO nó, que é exatamente o defeito que o spawner
# existe para não ter. Então o caminho é o mesmo do resto do jogo: o cliente
# PEDE, o servidor decide, e o spawner replica a criação (e a remoção).
#
# Consequência declarada: o interruptor é do MUNDO, não da tela. Num jogo de dois,
# desligar o boneco tira o boneco para os dois — o que é o comportamento correto
# para um corpo sólido que ambos podem socar. Esconder só do lado de quem clicou
# deixaria um jogador batendo num alvo invisível para o outro.
func pedir_dummy(tipo: String, ligado: bool) -> void:
	if multiplayer.has_multiplayer_peer():
		_net_definir_dummy.rpc_id(NetworkConfig.SERVER_ID, tipo, ligado)
	else:
		_aplicar_dummy(tipo, ligado)                    # sem rede (singleplayer puro/testes)

@rpc("any_peer", "call_local", "reliable")
func _net_definir_dummy(tipo: String, ligado: bool) -> void:
	if not multiplayer.is_server():
		return
	_aplicar_dummy(tipo, ligado)

# Idempotente de propósito: chamar duas vezes com o mesmo valor não cria um
# boneco em cima do outro nem tenta apagar o que já não existe. O nome do nó é o
# próprio `tipo` (ver `_spawn_entity_data`), então a busca é direta.
func _aplicar_dummy(tipo: String, ligado: bool) -> void:
	if not POSICAO_DOS_BONECOS.has(tipo) or not is_instance_valid(_entities_root):
		return
	var existente := _entities_root.get_node_or_null(NodePath(tipo))
	if ligado and existente == null:
		_spawn_entity(tipo, POSICAO_DOS_BONECOS[tipo])
	elif not ligado and existente != null:
		existente.queue_free()      # o MultiplayerSpawner replica a remoção

func _spawn_entity(tipo: String, pos: Vector3) -> void:
	var data := {"tipo": tipo, "pos": [pos.x, pos.y, pos.z]}
	if multiplayer.has_multiplayer_peer():
		_entity_spawner.spawn(data)                       # replica p/ os clientes
	else:
		_entities_root.add_child(_spawn_entity_data(data)) # sem rede (harness/teste)

# Determinística pelos dados: roda no servidor E em cada cliente (via spawner).
# Espelha `_spawn_player_data` de propósito — mesma forma, mesma leitura.
const _ENTIDADES := {
	"TrainingDummy": "res://src/entities/TrainingDummy.gd",
	"AutoDummy":     "res://src/entities/AutoDummy.gd",
	"SwordPickup":   "res://src/items/SwordPickup.gd",
}

func _spawn_entity_data(data: Dictionary) -> Node:
	var tipo := str(data.get("tipo", ""))
	var caminho: String = _ENTIDADES.get(tipo, "")
	if caminho == "":
		push_error("[Main] entidade desconhecida no spawner: '%s'" % tipo)
		return null
	var pos: Array = data.get("pos", [0, 4, 0])
	# A espada é `Area3D` (coletável); os bonecos são `CharacterBody3D` (têm física).
	var no: Node3D = Area3D.new() if tipo == "SwordPickup" else CharacterBody3D.new()
	no.set_script(load(caminho))
	no.name = tipo
	no.position = Vector3(pos[0], pos[1], pos[2])
	# A AUTORIDADE FICA NO SERVIDOR (id 1), ao contrário dos jogadores, cuja
	# autoridade é o dono do corpo. Quem simula o boneco é quem decide o dano —
	# e dano, neste projeto, é sempre do servidor (ver `DamageZone._on_body`).
	no.add_child(_make_entity_sync(tipo))
	no.set_multiplayer_authority(NetworkConfig.SERVER_ID)
	return no

# `position` para todo mundo; `health` só para quem tem vida. Sem replicar a
# vida, a barra e o número flutuante do cliente contariam uma história própria —
# o mesmo defeito que `net_vida_do_servidor` corrigiu no Player.
func _make_entity_sync(tipo: String) -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	cfg.add_property(NodePath(".:position"))
	if tipo != "SwordPickup":
		cfg.add_property(NodePath(".:health"))
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	return sync

# ---------------------------------------------------------- CORES DOS JOGADORES
# id do peer -> índice em `Player.CORES`. **Só o servidor mantém isto.** Os
# clientes não precisam: a cor viaja no dicionário de spawn, que o
# `MultiplayerSpawner` replica — ver a nota em `Player.aplicar_cor_do_jogador`.
var _cores_por_peer: Dictionary = {}

# O menor índice ainda livre. Assim quem sai devolve a cor para o próximo que
# entrar, em vez de a paleta ir se esgotando ao longo da partida.
func _cor_livre() -> int:
	var usados := _cores_por_peer.values()
	for i in Player.CORES.size():
		if not usados.has(i):
			return i
	# Mais jogadores que cores: repete a paleta em vez de deixar alguém sem cor.
	return _cores_por_peer.size() % Player.CORES.size()

func _spawn_player_for(id: int) -> void:
	if not _cores_por_peer.has(id):
		_cores_por_peer[id] = _cor_livre()
	var data := {"id": id, "pos": [0, 4, 0], "cor": _cores_por_peer[id]}   # clareira central
	if multiplayer.has_multiplayer_peer():
		_spawner.spawn(data)                    # replica p/ os clientes
	else:
		_players_root.add_child(_spawn_player_data(data))   # sem rede (harness/teste)

func _despawn_player_for(id: int) -> void:
	_cores_por_peer.erase(id)   # devolve a cor para a paleta
	var n := _players_root.get_node_or_null(str(id))
	if n:
		n.queue_free()

# Determinística pelos dados: roda no servidor E em cada cliente (via spawner).
func _spawn_player_data(data: Dictionary) -> Node:
	print("[Main] _spawn_player_data chamado com data=", data)
	var id := int(data.get("id", 1))
	var pos: Array = data.get("pos", [0, 4, 0])
	var player := CharacterBody3D.new()
	player.set_script(load("res://Player.gd"))
	player.name = str(id)                       # nome = peer id (achável no despawn)
	player.position = Vector3(pos[0], pos[1], pos[2])
	player.add_child(_make_player_sync())
	player.set_multiplayer_authority(id)        # recursivo -> inclui o synchronizer
	# TODO jogador nasce com a fruta inicial — não só o host.
	#
	# Antes era `if id == 1`, e o cliente nascia SEM fruta: barra de técnicas
	# vazia e `_fire_skill` caindo no fallback `gomu_gomu`. Isso não era um dos
	# bugs relatados, mas atrapalhava a leitura de "as skills não funcionam no
	# cliente" — dava para atribuir ao bug da HUD o que era falta de fruta.
	# Escolha por-jogador continua sendo fase futura; o ponto aqui é que os dois
	# lados comecem iguais.
	# Lê a constante do Player em vez de repetir o nome — ver a nota em
	# `Player.FRUTA_INICIAL` sobre os três escritores que discordavam.
	player.call_deferred("equip_fruit", Player.FRUTA_INICIAL)

	# COR: `-1` quando o dado não traz nada (spawn sem rede, testes) — aí o
	# personagem fica com a aparência original, como sempre foi.
	#
	# ⚠️ ADIADO, como o `equip_fruit`: `aplicar_cor_do_jogador` pinta as malhas do
	# `_char_model`, e o rig só é montado no `_ready()` — que ainda não correu,
	# porque este nó nem entrou na árvore. Pintar agora não acharia malha nenhuma.
	player.call_deferred("aplicar_cor_do_jogador", int(data.get("cor", -1)))
	return player

func _make_player_sync() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p in ["position", "net_velocity", "net_facing", "net_on_floor", "current_fruit_id"]:
		cfg.add_property(NodePath(".:" + p))
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	return sync

# Chamado pelo PickupSpawner quando um corpo entra no coletável.
func _on_collect(body: Node, fruto: Dictionary, cor: Color, area: Area3D) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("equip_fruit"):
		body.equip_fruit(str(fruto.get("id", "")))
	if _hud:
		_hud.add_item({
			"nome": fruto.get("nome", "?"),
			"tipo": fruto.get("tipo", ""),
			"passiva": fruto.get("passiva", ""),
			"cor": cor,
		})
	area.queue_free()
