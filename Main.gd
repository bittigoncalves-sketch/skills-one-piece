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

	var dummy := CharacterBody3D.new()
	dummy.set_script(load("res://src/entities/TrainingDummy.gd"))
	dummy.name = "TrainingDummy"
	dummy.position = Vector3(0, 4, -8)   # À FRENTE do player (evita nascer um dentro do outro)
	add_child(dummy)
	
	var auto_dummy := CharacterBody3D.new()
	auto_dummy.set_script(load("res://src/entities/AutoDummy.gd"))
	auto_dummy.name = "AutoDummy"
	auto_dummy.position = Vector3(4, 4, -8)   # Ao lado do primeiro dummy
	add_child(auto_dummy)

func _spawn_player_for(id: int) -> void:
	var data := {"id": id, "pos": [0, 4, 0]}   # clareira central
	if multiplayer.has_multiplayer_peer():
		_spawner.spawn(data)                    # replica p/ os clientes
	else:
		_players_root.add_child(_spawn_player_data(data))   # sem rede (harness/teste)

func _despawn_player_for(id: int) -> void:
	var n := _players_root.get_node_or_null(str(id))
	if n:
		n.queue_free()

# Determinística pelos dados: roda no servidor E em cada cliente (via spawner).
func _spawn_player_data(data: Dictionary) -> Node:
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
	player.call_deferred("equip_fruit", "gura_gura")
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
