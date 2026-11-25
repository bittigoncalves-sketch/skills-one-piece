extends SceneTree
## Integração real: catálogo → árvore/modelo → equipamento/HUD → input → ROOM.
## SOP_PORTA=24700 godot --headless --path . -s tools/dev_tests/test_ope_integracao.gd

var _failures := 0
var _checks := 0

func _init() -> void:
	await process_frame
	create_timer(30.0).timeout.connect(func():
		push_error("OPE integração: timeout")
		quit(2))
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(2.0).timeout
	var player: Node3D
	for actor in get_nodes_in_group("player"):
		if actor.is_multiplayer_authority():
			player = actor
	_ok(player != null, "jogador da arena real disponível")
	if player == null:
		quit(1)
		return
	var skills: Dictionary = SkillSystem.get_fruit_skills().get("ope_ope", {})
	_ok(skills.size() == 4, "quatro técnicas registradas")
	var pickup: Node3D = TreeAndFruitGenerator.active_fruits_map.get("ope_ope")
	_ok(is_instance_valid(pickup), "árvore Ope foi plantada na arena")
	if is_instance_valid(pickup):
		_ok(pickup.get_node_or_null("CoracaoOpe") != null, "GLB autoral carregou na fruta coletável")
		_ok(pickup.get_node_or_null("PickupArea/CollisionShape3D") != null \
			or pickup.get_node("PickupArea").get_child_count() > 0, "fruta tem colisão de coleta")
	player.equip_fruit("ope_ope")
	player.combat_mode = "fruit"
	await create_timer(0.05).timeout
	_ok(str(player.current_fruit_id) == "ope_ope", "equipamento preserva identidade Ope")
	if is_instance_valid(pickup):
		_ok(not pickup.visible, "equipar esconde a fruta coletável")
	var hud := get_first_node_in_group("hud")
	var ope_hud: Node = hud.get_node_or_null("OpeRoomHud") if hud else null
	_ok(ope_hud != null and ope_hud.visible, "indicador ROOM acompanha fruta local")
	var weapon: Node = player.get_node_or_null("OpeKikoku")
	_ok(weapon != null, "Kikoku integrada ao jogador")
	var energy_before := float(player.energy)
	player.begin_charge("X")
	await create_timer(0.10).timeout
	_ok(float(player._skill_cooldowns.get("X", 0.0)) <= 0.0, "Shambles sem ROOM não consome recarga")
	_ok(float(player.energy) >= energy_before, "Shambles sem ROOM não consome energia")
	_ok(not player.has_meta("ope_action"), "tentativa inválida não prende o personagem")
	player.begin_charge("Z")
	await create_timer(0.12).timeout
	var room: Node = player.get_meta("ope_room") if player.has_meta("ope_room") else null
	_ok(is_instance_valid(room), "Z pelo input real cria ROOM")
	if is_instance_valid(room):
		_ok(float(room.radius) == 18.0, "ROOM tem raio de 18 m")
		_ok(not room.ready_for_skills(), "expansão impede técnicas antecipadas")
		_ok(room.get_child_count() > 0, "ROOM monta apresentação visual")
	await create_timer(0.85).timeout
	_ok(is_instance_valid(room) and room.ready_for_skills(), "campo libera técnicas depois de expandir")
	_ok(not player.has_meta("ope_action"), "animação ROOM solta o compromisso")
	_ok(str(player.get_meta("custom_pose", "")) != "ope_room", "pose retorna após abertura")
	_ok(float(player._skill_cooldowns.get("Z", 0.0)) > 6.0, "recarga ROOM segue a tabela própria")
	var old_room_id := room.get_instance_id() if is_instance_valid(room) else 0
	player.begin_charge("Z")
	await process_frame
	var same_room: Node = player.get_meta("ope_room") if player.has_meta("ope_room") else null
	_ok(is_instance_valid(same_room) and same_room.get_instance_id() == old_room_id,
		"spam de Z durante recarga não recria ROOM")
	player.equip_fruit("gomu_gomu")
	await create_timer(0.15).timeout
	_ok(not is_instance_valid(room), "troca de fruta elimina ROOM")
	_ok(not player.has_meta("ope_room"), "troca limpa referência espacial")
	_ok(ope_hud != null and not ope_hud.visible, "HUD Ope desaparece ao trocar")
	if is_instance_valid(weapon):
		_ok(not weapon.visible, "Kikoku acompanha a troca de equipamento")
	if is_instance_valid(pickup):
		_ok(pickup.visible, "fruta retorna à árvore depois da troca")
	print("OPE INTEGRAÇÃO: %d verificações, %d falhas" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _ok(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
	print(("PASS " if condition else "FAIL ") + message)
