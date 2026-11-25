extends SceneTree
## Integração real: opção temporária, rig, materiais, dano e reversão.
const OPTION := "SOP_TEST_CHARACTER_VISUAL"
const RESOURCE := "res://assets/models/bosses/buggy/buggy_boss_visual.tres"
var failures := 0

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func _init() -> void:
	await process_frame
	OS.unset_environment(OPTION)
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = true
	flow.dummies["AutoDummy"] = false
	flow.start_singleplayer()
	await create_timer(2.0).timeout
	var player := get_first_node_in_group("player") as CharacterBody3D
	var original_dummy := get_first_node_in_group("dummy") as TrainingDummy
	if player == null or original_dummy == null:
		check(false, "arena criou atores")
		quit(1)
		return
	player.set_physics_process(false)
	var rig := player.get("_rig") as PlayerRig
	var camera := player.get("_cam") as Camera3D
	var camera_before := camera.transform
	var shape := player.get("_colisor") as CollisionShape3D
	var collision_before := (shape.shape as BoxShape3D).size
	var original_mesh_name := rig.modelo().name
	check(rig.visual_definition == null, "padrão preserva modelo original")
	check(original_dummy._rig.visual_definition == null, "Dummy padrão preservado")
	OS.set_environment(OPTION, RESOURCE)
	player.call("_setup_character_model", "base")
	await process_frame
	check(rig.visual_definition != null, "Player carrega opção de teste")
	if rig.visual_definition == null:
		quit(1)
		return
	check(rig.modelo().get_parent() == player, "hierarquia do Player preservada")
	check((shape.shape as BoxShape3D).size == collision_before, "colisor inalterado")
	check(camera.transform.is_equal_approx(camera_before), "câmera inalterada pela troca")
	# O CameraRig usa autoloads: referência dinâmica evita o falso erro de -s.
	var camera_rig = player.get("_camera")
	camera_rig.alternar_perspectiva()
	player.call("_atualizar_visibilidade_corpo")
	check(not rig.modelo().visible, "primeira pessoa oculta o visual completo")
	camera_rig.alternar_perspectiva()
	player.call("_atualizar_visibilidade_corpo")
	check(rig.modelo().visible, "terceira pessoa restaura visual")
	check(rig.procedural()._n.size() == 13, "13 papéis resolvidos")
	var skel := BodyScanner._find_skeleton(rig.modelo())
	check(skel != null and skel.get_bone_count() == 41, "41 ossos importados")
	for side in ["L", "R"]:
		var rest_hand := rig.modelo().global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_rest(skel.find_bone(side + "_Hand")).origin
		check(rest_hand.x < 0 if side == "L" else rest_hand.x > 0, "lado anatômico " + side + ": " + str(rest_hand))
	check(rig.modelo().find_children("*", "CollisionObject3D", true, false).is_empty(), "visual não introduz colisores")
	var scale_value := rig.modelo().scale
	check(is_equal_approx(scale_value.x, scale_value.y) and is_equal_approx(scale_value.y, scale_value.z), "escala uniforme")
	# AABB de repouso antes de sockets/armas: prova do fit, não do skinning animado.
	var isolated := rig.visual_definition.instantiate_visual()["node"] as Node3D
	current_scene.add_child(isolated)
	var bounds := PlayerModelKit.model_aabb(isolated)
	var height := bounds.size.y * scale_value.y
	var floor_y := bounds.position.y * scale_value.y + rig.modelo().position.y
	print("MEASURE rest_height=", height, " feet_local_y=", floor_y, " scale=", scale_value)
	check(absf(height - 1.5) < 0.001, "altura de repouso 1,5 m")
	check(absf(floor_y + 0.8) < 0.001, "pés de repouso na base do colisor")
	isolated.free()
	var meshes := rig.modelo().find_children("tripo_part_*", "MeshInstance3D", true, false)
	check(meshes.size() == 13, "13 peças originais presentes")
	var textures := 0
	for mesh in meshes:
		check(mesh.material_override == null, "material original " + str(mesh.name))
		var material := (mesh as MeshInstance3D).get_active_material(0) as BaseMaterial3D
		if material and material.albedo_texture:
			textures += 1
	check(textures == 13, "13 texturas preservadas após Visual/tinta do Player")
	await _measure_animation(rig, skel)
	var dummy := TrainingDummy.new()
	current_scene.add_child(dummy)
	dummy.global_position = Vector3(4, 0.8, 0)
	check(dummy._rig.visual_definition != null, "Dummy instancia opção de teste")
	check(dummy._model.scale.is_equal_approx(scale_value), "Dummy não alonga eixo Z do GLB")
	var hp := dummy.health
	dummy.take_damage(25.0, player.global_position, Vector3(3, 1, 0), 0.2)
	check(is_equal_approx(dummy.health, hp - 25), "Dummy continua recebendo dano")
	check(dummy._pending_knockback.length() > 0, "knockback continua registrado")
	dummy.set_physics_process(false)
	var zone := DamageZone.new()
	current_scene.add_child(zone)
	zone.global_position = dummy.global_position
	zone.setup(11.0, 0.0, Vector3.ZERO, 0.6, player, 0.35)
	for i in 12:
		await physics_frame
	check(is_equal_approx(dummy.health, hp - 36), "DamageZone atinge hurtbox uma única vez")
	zone.queue_free()
	var auto := AutoDummy.new()
	current_scene.add_child(auto)
	auto.global_position = Vector3(-4, 0.8, 0)
	auto.set_physics_process(false)
	check(auto._model.find_child("tripo_part_0", true, false) != null, "AutoDummy carrega GLB")
	var colored := false
	for mesh in auto._model.find_children("tripo_part_*", "MeshInstance3D", true, false):
		colored = colored or mesh.material_override != null
	check(not colored, "AutoDummy preserva materiais")
	auto._attack()
	check(auto._rig.procedural()._baked != null, "AutoDummy inicia clipe no rig skinned")
	dummy.queue_free()
	auto.queue_free()
	OS.unset_environment(OPTION)
	player.call("_setup_character_model", "base")
	await process_frame
	check(rig.visual_definition == null and rig.modelo().name == original_mesh_name, "reversão restaura visual original")
	check(rig.animador() != null and rig.procedural() != null, "animadores originais restaurados")
	check((shape.shape as BoxShape3D).size == collision_before, "reversão preserva colisor")
	OS.set_environment(OPTION, "res://inexistente_visual_test.tres")
	player.call("_setup_character_model", "base")
	await process_frame
	check(rig.visual_definition == null, "opção inválida usa modelo original")
	OS.unset_environment(OPTION)
	print("BUGGY VISUAL FAILURES=", failures)
	quit(1 if failures else 0)

func _measure_animation(rig: PlayerRig, skel: Skeleton3D) -> void:
	var anim := rig.procedural()
	var initial: Dictionary = {}
	var amplitudes: Dictionary = {}
	for name in ["L_Upperarm", "R_Upperarm", "L_Thigh", "R_Thigh", "L_Calf", "R_Calf"]:
		initial[name] = skel.get_bone_pose_rotation(skel.find_bone(name))
		amplitudes[name] = 0.0
	for i in 120:
		anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0, false)
		for name in initial:
			var rotation := skel.get_bone_pose_rotation(skel.find_bone(name))
			amplitudes[name] = maxf(amplitudes[name], rad_to_deg(initial[name].angle_to(rotation)))
	for name in amplitudes:
		print("MEASURE walk_bone=", name, " excursion_degrees=", amplitudes[name])
		check(amplitudes[name] > 2.0, "osso se move no walk: " + name)
	anim.play_baked(Melee.clipe(0, ""), 1.0)
	var arm_start := skel.get_bone_pose_rotation(skel.find_bone("R_Upperarm"))
	var punch_amplitude := 0.0
	for i in 40:
		anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0, false)
		punch_amplitude = maxf(punch_amplitude, rad_to_deg(arm_start.angle_to(skel.get_bone_pose_rotation(skel.find_bone("R_Upperarm")))))
	check(punch_amplitude > 5.0, "clipe M1 move osso do braço: %.2f graus" % punch_amplitude)
	await process_frame
	await process_frame
	for side in ["L", "R"]:
		var socket := rig.modelo().find_child("Grip_" + side, true, false) as Node3D
		var bone := skel.find_bone(side + "_Hand")
		var expected := skel.global_transform * skel.get_bone_global_pose(bone).origin
		var error := socket.global_position.distance_to(expected) if socket else INF
		check(error < 0.001, "socket segue mão %s (erro %.6f m)" % [side, error])
