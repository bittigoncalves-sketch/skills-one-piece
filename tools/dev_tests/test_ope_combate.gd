extends SceneTree
## Contratos Ope com Player, TrainingDummy, piso/parede e hitboxes reais.
## SOP_PORTA=24710 XDG_DATA_HOME=/tmp/ope-combat-user godot --headless --path . \
##   --log-file /tmp/ope-combat.log -s tools/dev_tests/test_ope_combate.gd

const OPE := preload("res://src/combat/OpeController.gd")
const ZONE := preload("res://src/combat/OpeDamageZone.gd")
const HOME := Vector3(0, 101.0, 0)
var _checks := 0
var _failures := 0
var _token := 500
var _player: Node3D
var _dummy: Node3D
var _room: Node3D
var _world: Node3D

func _init() -> void:
	await process_frame
	create_timer(65.0).timeout.connect(func():
		push_error("OPE combate: timeout")
		quit(2))
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await _wait(2.0)
	for actor in get_nodes_in_group("player"):
		if actor.is_multiplayer_authority():
			_player = actor
	for actor in get_nodes_in_group("enemy"):
		actor.set_physics_process(false)
		actor.global_position = Vector3(1000, 100, 0)
		if actor is TrainingDummy and _dummy == null:
			_dummy = actor
	_ok(_player != null and _dummy != null, "Player e TrainingDummy reais disponíveis")
	if _player == null or _dummy == null:
		quit(1)
		return
	_world = current_scene
	_player.set_physics_process(false)
	_player.equip_fruit("ope_ope")
	_player.combat_mode = "fruit"
	_player.global_position = HOME
	_player.health = _player.max_health
	_player.energy = _player.max_energy
	_dummy.global_position = HOME + Vector3.FORWARD * 8.0
	_box(Vector3(0, 99.7, 0), Vector3(60, 0.6, 60))
	await _wait(0.15)
	await _invalid_requests()
	await _new_room()
	await _damage_contracts()
	await _shambles()
	await _real_skills()
	await _lifecycle()
	print("OPE COMBATE: %d verificações, %d falhas" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _invalid_requests() -> void:
	for slot in ["X", "C", "V"]:
		var energy_before := float(_player.energy)
		_request(slot)
		_ok(_player.energy == energy_before and not _player._server_cast_next_ms.has("fruit/ope_ope/" + slot),
			"%s sem ROOM não gasta energia nem agenda recarga" % slot)
	var before := float(_player.energy)
	_request("Z", Vector3(NAN, 0, 0))
	_ok(_player.energy == before and OPE.room_for(_player) == null, "mira NaN recusada sem custo")
	_token += 1
	_player._do_server_cast("Z", Vector3.FORWARD, HOME + Vector3.RIGHT * 30.0,
		0.0, _token, "fruit", "ope_ope")
	_ok(_player.energy == before and OPE.room_for(_player) == null, "origem forjada recusada sem custo")

func _damage_contracts() -> void:
	_dummy.health = _dummy.MAX_HP
	var hp_owner := float(_player.health)
	var spec := Balance.novo("ope_ope", "C")
	# Sete hitboxes independentes do MESMO cast devem parar no teto de cinco.
	for _i in 7:
		_zone_at(_dummy.global_position, spec)
	await _wait(0.20)
	_ok(is_equal_approx(_dummy.MAX_HP - _dummy.health, 320.0), "sete colisões reais Takt limitadas a 320 por alvo/cast")
	_ok(is_equal_approx(CombatResolver.gasto_em(spec.cast_id, _dummy), 320.0), "resolver registra teto compartilhado")
	_zone_at(_player.global_position, Balance.novo("ope_ope", "V"))
	await _wait(0.15)
	_ok(_player.health == hp_owner, "colisão da própria agulha não atinge o dono")
	_dummy.global_position = HOME + Vector3.RIGHT * 18.2
	var before := float(_dummy.health)
	_zone_at(_dummy.global_position, Balance.novo("ope_ope", "V"))
	await _wait(0.15)
	_ok(_dummy.health == before, "alvo fora da esfera não recebe dano mesmo sobreposto à hitbox")
	_dummy.global_position = HOME + Vector3.FORWARD * 8.0
	var wall := _box(HOME + Vector3.FORWARD * 4.0, Vector3(5, 5, 0.5))
	await _wait(0.10)
	_ok(OPE.pick_target(_player, Vector3.FORWARD, 36.0) == null, "parede sólida impede aquisição de alvo")
	var projectile := _zone_at(HOME + Vector3.FORWARD, Balance.novo("ope_ope", "C"), Vector3.FORWARD * 30.0)
	projectile.stop_on_collision = true
	await _wait(0.35)
	_ok(not is_instance_valid(projectile) and _dummy.health == before, "rocha colide com parede e não atravessa cobertura")
	wall.queue_free()
	await _wait(0.05)

func _shambles() -> void:
	_player.global_position = HOME
	_dummy.global_position = HOME + Vector3.FORWARD * 8.0
	await _wait(0.05)
	var result := OPE.shambles_destination(_player, Vector3.FORWARD)
	_ok(result.get("target") == _dummy, "Shambles adquire inimigo com piso livre")
	var owner_before := _player.global_position
	var target_before := _dummy.global_position
	var hp_before := float(_dummy.health)
	_request("X")
	await _wait(0.80)
	_ok(_player.global_position.distance_to(target_before) < 0.3 and _dummy.global_position.distance_to(owner_before) < 0.3,
		"Shambles troca as duas posições na resolução autoritativa")
	_ok(_dummy.health == hp_before, "troca não aplica dano")
	_player.global_position = HOME
	_dummy.global_position = HOME + Vector3.RIGHT * 25.0
	var free_result := OPE.shambles_destination(_player, Vector3.FORWARD)
	_ok(not free_result.is_empty() and not free_result.has("target"), "Shambles também encontra chão livre sem alvo")
	# Um teto baixo mantém o alvo visível, mas impede alojar o corpo do usuário.
	_dummy.global_position = HOME + Vector3.FORWARD * 8.0
	var roof := _box(HOME + Vector3(0, 3.5, -8), Vector3(3, 6, 3))
	await _wait(0.05)
	var obstructed := OPE.shambles_destination(_player, Vector3.FORWARD)
	_ok(obstructed.is_empty(), "destino sem altura para o corpo é recusado")
	_clear_cooldowns()
	var energy_before := float(_player.energy)
	_request("X")
	_ok(_player.energy == energy_before and not _player._server_cast_next_ms.has("fruit/ope_ope/X"),
		"Shambles obstruído não consome energia nem recarga")
	roof.queue_free()
	await _wait(0.10)

func _real_skills() -> void:
	_dummy.health = _dummy.MAX_HP
	_dummy.global_position = HOME + Vector3.FORWARD * 8.0
	_player.global_position = HOME
	_clear_cooldowns()
	_request("C")
	await _wait(2.20)
	var damage: float = _dummy.MAX_HP - float(_dummy.health)
	_ok(damage == 320.0, "C completo cria cinco rochas: dano real %.0f/320" % damage)
	await _wait(1.5)
	_dummy.health = _dummy.MAX_HP
	_dummy.global_position = HOME + Vector3.FORWARD * 5.0
	_player.global_position = HOME
	_clear_cooldowns()
	_request("V")
	await _wait(1.05)
	damage = _dummy.MAX_HP - float(_dummy.health)
	_ok(damage == 576.0, "Gamma Knife completo causa %.0f/576 num único acerto" % damage)
	_ok(_player.global_position.z < -2.0, "Gamma Knife avança para o alcance de contato")
	await _wait(0.50)
	_player.global_position = HOME
	_dummy.global_position = HOME + Vector3.RIGHT * 25.0
	_clear_cooldowns()
	var before := float(_player.energy)
	_request("C")
	_ok(before == _player.energy, "Takt sem alvo dentro da ROOM não consome energia")

func _lifecycle() -> void:
	# ROOM pode ser recentrada após recarga sem o cancel antigo roubar a pose nova.
	var old := _room
	_clear_cooldowns()
	_request("Z")
	_room = OPE.room_for(_player)
	await _wait(0.10)
	_ok(is_instance_valid(_room) and not is_instance_valid(old), "recast Z substitui ROOM anterior com segurança")
	_ok((_player.get_meta("ope_action") if _player.has_meta("ope_action") else null) == _room and _player.get_meta("is_casting", false),
		"cancelamento do campo anterior preserva a nova animação")
	await _wait(0.90)
	_player._cast.suprimir(5.0)
	await _wait(0.10)
	_ok(OPE.room_for(_player) == null, "supressão cancela campo persistente")
	_player._cast.limpar_silencio()
	await _new_room()
	_dummy.global_position = HOME + Vector3.FORWARD * 8.0
	_dummy.health = _dummy.MAX_HP
	_request("C")
	await _wait(0.20)
	_player.health = 0.0
	await _wait(1.5)
	_ok(OPE.room_for(_player) == null and (_player.get_meta("ope_action") if _player.has_meta("ope_action") else null) == null,
		"morte no startup limpa ROOM e ação")
	_ok(_dummy.health == _dummy.MAX_HP, "morte no startup impede projéteis tardios")
	_player.health = _player.max_health
	await _new_room()
	_player.equip_fruit("gomu_gomu")
	await _wait(0.10)
	_ok(OPE.room_for(_player) == null, "troca de fruta cancela ROOM")
	_player.equip_fruit("ope_ope")
	_player.combat_mode = "fruit"
	await _new_room()
	_player.combat_mode = "style"
	await _wait(0.10)
	_ok(OPE.room_for(_player) == null, "troca de modo cancela ROOM")

func _new_room() -> void:
	_clear_cooldowns()
	_player.energy = _player.max_energy
	_player.global_position = HOME
	_request("Z")
	await _wait(1.0)
	_room = OPE.room_for(_player)
	_ok(_room != null and _room.ready_for_skills(), "ROOM autoritativa expandida e pronta")

func _request(slot: String, direction: Vector3 = Vector3.FORWARD) -> void:
	_token += 1
	_player._do_server_cast(slot, direction, _player.global_position, 0.0,
		_token, "fruit", "ope_ope")

func _clear_cooldowns() -> void:
	_player._fruit_cooldowns.clear()
	_player._server_cast_next_ms.clear()

func _zone_at(at: Vector3, spec: DamageSpec, speed := Vector3.ZERO) -> Area3D:
	var zone := ZONE.new()
	zone.room_ref = weakref(_room)
	_world.add_child(zone)
	zone.global_position = at
	zone.setup(spec.dano, 0.0, speed, 0.6, _player, 0.7, null, 0.0)
	spec.marcar(zone)
	return zone

func _box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	_world.add_child(body)
	body.global_position = at
	return body

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print(("PASS " if condition else "FAIL ") + message)
