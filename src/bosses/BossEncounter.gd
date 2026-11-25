class_name BossEncounter
extends Node3D
## Registro de definições: identidade nunca é inferida de peer_id ou nome visual.
const DEFINITIONS := {"buggy": "res://assets/bosses/buggy/buggy_definition.tres"}
var _actors: Node3D
var _spawner: MultiplayerSpawner

func _ready() -> void:
	_actors = Node3D.new()
	_actors.name = "Actors"
	add_child(_actors)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "Spawner"
	add_child(_spawner)
	_spawner.spawn_path = NodePath("../Actors")
	_spawner.spawn_function = _make_actor
	if multiplayer.is_server() and _enabled():
		_spawn_initial.call_deferred()

func _enabled() -> bool:
	var explicit := OS.get_environment("SOP_BOSS_ENABLED")
	if explicit in ["0", "1"]:
		return explicit == "1"
	# As sondas antigas medem sistemas isolados; testes de Boss ligam explicitamente.
	for argument in OS.get_cmdline_args():
		if "tools/dev_tests/" in argument or "src/tests/" in argument:
			return false
	return true

func _spawn_initial() -> void:
	var spawn := _safe_spawn()
	if spawn == Vector3.INF:
		push_error("Nenhum ponto seguro encontrado para o encontro")
		return
	var data := {"definition": "buggy", "actor_id": 10001, "encounter_id": 1, "position": spawn}
	if multiplayer.has_multiplayer_peer():
		_spawner.spawn(data)
	else:
		_actors.add_child(_make_actor(data))

func _safe_spawn() -> Vector3:
	var space := get_world_3d().direct_space_state
	for radius in [18.0, 22.0, 26.0]:
		for angle in [0.0, 0.6, -0.6, 1.0, -1.0, 1.5, -1.5]:
			var point := Vector3(0, 1.12, -radius).rotated(Vector3.UP, angle)
			if MapBuilder.is_hole_area(point.x, point.z, 2.0, 2.0):
				continue
			var shape := BoxShape3D.new()
			shape.size = Vector3(2, 2.2, 2)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = point
			query.collision_mask = 15
			if space.intersect_shape(query, 1).is_empty():
				return point
	return Vector3.INF

func _make_actor(data: Dictionary) -> Node:
	var path: String = DEFINITIONS.get(str(data.get("definition", "")), "")
	if path.is_empty():
		return null
	var actor := BossActor.new()
	actor.definition = load(path) as BossDefinition
	actor.actor_id = int(data.actor_id)
	actor.encounter_id = int(data.encounter_id)
	actor.name = "Boss_" + str(actor.actor_id)
	actor.position = data.position
	actor.health = actor.definition.max_health
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var config := SceneReplicationConfig.new()
	for field in ["position", "rotation", "health", "dead", "state", "action_id", "action_elapsed", "action_sequence", "combo_index", "part_state", "part_transform", "reaction", "reaction_elapsed", "reaction_count", "mobility", "mobility_elapsed", "jumps_used", "dash_direction", "net_velocity"]:
		var property := NodePath(".:" + field)
		config.add_property(property)
		config.property_set_spawn(property, true)
		config.property_set_replication_mode(property, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_interval = 1.0 / 30.0
	sync.replication_config = config
	actor.add_child(sync)
	actor.set_multiplayer_authority(NetworkConfig.SERVER_ID)
	return actor
