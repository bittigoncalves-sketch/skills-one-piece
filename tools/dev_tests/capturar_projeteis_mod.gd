extends SceneTree
## Captura de tela (precisa de janela): põe na frente do jogador um projétil do mod de cada tipo e fotografa, para ver quais
## aparecem. 30/10/2026.   godot --path . --resolution 1280x720 --script res://tools/dev_tests/capturar_projeteis_mod.gd
const IDS := ["bullet", "projectile_slash", "projectile_water_bullet", "missile", "booger", "heart_bullet"]
func _init() -> void:
	call_deferred("_r")
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://captura_proj.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_proj.json"))
	root.get_node("GameFlow").start_story()
	var j: Node3D = null
	var limite := Time.get_ticks_msec() + 150000
	while j == null and Time.get_ticks_msec() < limite:
		await physics_frame
		j = get_first_node_in_group("player")
	for i in 240: await physics_frame
	j.set_meta("damage_immune", true)
	j.set("_yaw", 0.0); j.set("_pitch", 0.15); j.call("_update_pivot")
	var mundo: McMundo = McEntidade.de(j).level()
	var cam: Camera3D = get_root().get_camera_3d()
	var corpos := []
	for i in IDS.size():
		# Em fila, a 3,5 m da câmera, na altura do olhar: dá para ver cada um.
		var pos: Vector3 = cam.global_position + (-cam.global_basis.z) * 3.5 + cam.global_basis.x * (float(i) - 2.5) * 1.0
		var c := McCorpoDoMod.criar(IDS[i], mundo, McVec3.de_godot(pos))
		c.projetil = false             # parado, para a foto
		c.ia_do_mod.set_process(false)
		c.ia_do_mod.set_physics_process(false)
		c.set_physics_process(false)   # sem o tick do mod, que os apaga sozinho
		c.global_position = pos
		corpos.append(c)
		print("CAP ", IDS[i], " desenho=", c.get("_desenho") != null)
	for i in 6: await physics_frame
	for i in IDS.size():
		print("CAP vivo? ", IDS[i], " ", is_instance_valid(corpos[i]) and corpos[i].is_inside_tree(), " pos=", corpos[i].global_position if is_instance_valid(corpos[i]) else "-",
			" desenho_visivel=", (corpos[i]._desenho != null and corpos[i]._desenho.is_visible_in_tree()) if is_instance_valid(corpos[i]) else "-")
	for i in IDS.size():
		var d: MeshInstance3D = corpos[i]._desenho
		if d != null:
			print("CAP malha ", IDS[i], " aabb=", d.get_aabb(), " escala=", d.scale, " global=", d.global_position, " mat_override=", d.material_override, " mat_surf0=", d.get_active_material(0), " layers=", d.layers, " camera_pos=", get_root().get_camera_3d().global_position if get_root().get_camera_3d() else "-")
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("/tmp/claude-1000/-home-gabriel-bitti-dev/e6059e18-2962-419b-9059-a5ecd1abfd33/scratchpad")
	root.get_texture().get_image().save_png("/tmp/claude-1000/-home-gabriel-bitti-dev/e6059e18-2962-419b-9059-a5ecd1abfd33/scratchpad/projeteis_mod.png")
	print("CAP foto salva")
	modo.set("progresso_forcado", "")
	quit()
