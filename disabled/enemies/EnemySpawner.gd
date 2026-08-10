class_name EnemySpawner
extends Node
# ============================================================================
#  INIMIGOS — DESLIGADOS DO MAPA (ver README.md nesta pasta).
#
#  Toda a lógica de spawn/replicação dos inimigos morava no Main.gd. Ela foi
#  movida para cá inteira, sem alteração de comportamento, para que o mapa
#  fique limpo SEM perder o código. O Main só instancia este nó quando
#  `Main.ENEMIES_ENABLED` é true — hoje é false.
#
#  Religar = `Main.ENEMIES_ENABLED = true`. Nada mais.
#
#  Esta pasta NÃO tem `.gdignore` de propósito: o script continua compilando e
#  `class_name Enemy` segue no cache global, então nada quebra e o religar é
#  imediato.
# ============================================================================

const ENEMY_SCRIPT := "res://disabled/enemies/Enemy.gd"

var _root: Node3D
var _spawner: MultiplayerSpawner
var _seq := 0
var _count := 5

func _ready() -> void:
	_root = Node3D.new()
	_root.name = "Enemies"
	add_child(_root)

	_spawner = MultiplayerSpawner.new()
	_spawner.name = "EnemySpawner"
	add_child(_spawner)
	_spawner.spawn_path = _root.get_path()
	_spawner.spawn_function = _spawn_enemy_data

# Chamado pelo Main DEPOIS do _ready (spawn durante o _ready com peer ativo dá
# "Parent node is busy adding/removing children").
func start(count: int) -> void:
	_count = count
	for i in _count:
		spawn_one()
	var t := Timer.new()
	t.wait_time = 4.0
	t.autostart = true
	add_child(t)
	t.timeout.connect(_maintain)

func _maintain() -> void:
	if not multiplayer.is_server():
		return
	while _root.get_child_count() < _count:
		spawn_one()

func spawn_one() -> void:
	var ang := randf() * TAU
	var r := randf_range(8.0, 20.0)
	_seq += 1
	var data := {"id": _seq, "pos": [cos(ang) * r, 4.0, sin(ang) * r]}
	if multiplayer.has_multiplayer_peer():
		_spawner.spawn(data)
	else:
		_root.add_child(_spawn_enemy_data(data))

func _spawn_enemy_data(data: Dictionary) -> Node:
	var e := CharacterBody3D.new()
	e.set_script(load(ENEMY_SCRIPT))
	e.name = "E%d" % int(data.get("id", 0))
	var pos: Array = data.get("pos", [0, 4, 0])
	e.position = Vector3(pos[0], pos[1], pos[2])
	e.add_child(_make_sync())
	e.set_multiplayer_authority(1)   # servidor é a autoridade (IA + sync)
	return e

func _make_sync() -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p in ["position", "health", "net_facing", "net_tamed", "net_owner"]:
		cfg.add_property(NodePath(".:" + p))
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = cfg
	return sync
