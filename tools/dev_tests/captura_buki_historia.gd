extends SceneTree
## Captura da Buki Buki no Modo História (armas na mão, tiro). Rodar no Weston isolado (docs/MODO_HISTORIA.md):
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . --script tools/dev_tests/captura_buki_historia.gd -- <pasta>
var saida := "/tmp/buki_hist"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()
func q(n: int) -> void:
	for i in n: await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_buki.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_buki.json"))
	root.get_node("GameFlow").start_story()
	await q(200)
	var p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	current_scene.progressao.comer_fruta("buki_buki")
	await q(30)
	p._pitch = 0.0
	p._yaw = 0.0
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 40
	cam.current = true
	for slot in ["Z"]:
		for k in p._skill_cooldowns.keys(): p._skill_cooldowns[k] = 0.0
		p.begin_charge(slot)
		p.release_charge(slot)
		await q(50)
		var c: Vector3 = p.global_position + Vector3(0, 1.1 if slot != "X" else 0.1, 0)
		cam.global_position = c + p.global_basis.x * (3.2 if slot != "X" else 4.5) + (-p.global_basis.z) * 0.6 + Vector3(0, 0.2, 0)
		cam.look_at(c, Vector3.UP)
		await foto("mira_" + slot)
		for i in 3:
			p._buki.atirar()
			await q(2)
		await foto("tiro_" + slot)
	quit()
