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

const ENEMY_COUNT := 5

var _hud: Hud
var _players_root: Node3D
var _spawner: MultiplayerSpawner
var _enemies_root: Node3D
var _enemy_spawner: MultiplayerSpawner
var _enemy_seq := 0

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

	_hud = Hud.new()
	add_child(_hud)

	# Inimigos (Fase 7): mesmo padrão — servidor cria/replica, IA roda no servidor.
	_enemies_root = Node3D.new()
	_enemies_root.name = "Enemies"
	add_child(_enemies_root)
	_enemy_spawner = MultiplayerSpawner.new()
	_enemy_spawner.name = "EnemySpawner"
	add_child(_enemy_spawner)
	_enemy_spawner.spawn_path = _enemies_root.get_path()
	_enemy_spawner.spawn_function = _spawn_enemy_data

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
	for i in ENEMY_COUNT:
		_spawn_one_enemy()
	var t := Timer.new()
	t.wait_time = 4.0
	t.autostart = true
	add_child(t)
	t.timeout.connect(_maintain_enemies)

	var dummy := CharacterBody3D.new()
	dummy.set_script(load("res://src/entities/TrainingDummy.gd"))
	dummy.name = "TrainingDummy"
	dummy.position = Vector3(0, 4, -8)   # À FRENTE do player (evita nascer um dentro do outro)
	add_child(dummy)

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
	# Fruta inicial só p/ o host por enquanto (equip por-player = fase futura).
	if id == 1:
		player.call_deferred("equip_fruit", "suna_suna")
	return player

func _make_player_sync() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p in ["position", "net_velocity", "net_facing", "net_on_floor", "current_fruit_id"]:
		cfg.add_property(NodePath(".:" + p))
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	return sync

# ---- inimigos (Fase 7): spawn/replicação (servidor-autoridade) ----
func _maintain_enemies() -> void:
	if not multiplayer.is_server():
		return
	while _enemies_root.get_child_count() < ENEMY_COUNT:
		_spawn_one_enemy()

func _spawn_one_enemy() -> void:
	var ang := randf() * TAU
	var r := randf_range(8.0, 20.0)
	_enemy_seq += 1
	var data := {"id": _enemy_seq, "pos": [cos(ang) * r, 4.0, sin(ang) * r]}
	if multiplayer.has_multiplayer_peer():
		_enemy_spawner.spawn(data)
	else:
		_enemies_root.add_child(_spawn_enemy_data(data))

func _spawn_enemy_data(data: Dictionary) -> Node:
	var e := CharacterBody3D.new()
	e.set_script(load("res://src/entities/Enemy.gd"))
	e.name = "E%d" % int(data.get("id", 0))
	var pos: Array = data.get("pos", [0, 4, 0])
	e.position = Vector3(pos[0], pos[1], pos[2])
	e.add_child(_make_enemy_sync())
	e.set_multiplayer_authority(1)   # servidor é a autoridade (IA + sync)
	return e

func _make_enemy_sync() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p in ["position", "health", "net_facing", "net_tamed", "net_owner"]:
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
