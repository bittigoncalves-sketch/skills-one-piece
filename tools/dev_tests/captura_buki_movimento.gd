extends SceneTree
## Buki em MOVIMENTO (andar, correr, atirar andando). Weston isolado, como captura_buki_historia.gd.
var saida := "/tmp/buki_mov"
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
func tecla(k: Key, v: bool) -> void:
	var ev := InputEventKey.new(); ev.physical_keycode = k; ev.keycode = k; ev.pressed = v
	Input.parse_input_event(ev)
func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_buki_mov.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_buki_mov.json"))
	root.get_node("GameFlow").start_story()
	await q(200)
	var p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	current_scene.progressao.comer_fruta("buki_buki")
	await q(30)
	for slot in ["V", "C"]:
		for k in p._skill_cooldowns.keys(): p._skill_cooldowns[k] = 0.0
		p.begin_charge(slot); p.release_charge(slot)
		await q(40)
		for modo_mov in ["andar", "correr"]:
			p.global_position = Vector3(0, 0.8, 0); p.velocity = Vector3.ZERO
			if modo_mov == "correr": tecla(KEY_SHIFT, true)
			tecla(KEY_W, true)
			await q(50)
			p._buki.atirar()
			await q(2)
			await foto("%s_%s" % [slot, modo_mov])
			tecla(KEY_W, false); tecla(KEY_SHIFT, false)
			await q(30)
	quit()
