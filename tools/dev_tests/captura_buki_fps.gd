extends SceneTree
## Captura da Buki em 1ª pessoa: arma na tela, tiro, explosão pequena/grande e dash do inimigo. Weston isolado (docs/MODO_HISTORIA.md):
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . --script tools/dev_tests/captura_buki_fps.gd -- <pasta>
var saida := "/tmp/buki_fps"
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
	modo.set("progresso_forcado", "user://captura_buki_fps.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_buki_fps.json"))
	root.get_node("GameFlow").start_story()
	await q(200)
	var p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	current_scene.progressao.comer_fruta("buki_buki")
	await q(30)
	p.global_position = Vector3(0, 1, 0)
	p._pitch = 0.0
	p._yaw = 0.0
	# parede de pedra clara a 14 m, na frente (−Z)
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(30, 10, 1); cs.shape = bx
	parede.add_child(cs)
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = bx.size; mi.mesh = bm
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.75, 0.72, 0.65); mi.material_override = mat
	parede.add_child(mi)
	current_scene.add_child(parede)
	parede.global_position = Vector3(0, 5, -14)
	await q(10)
	await foto("00_sem_arma")
	var marcos := {"Z": [8, 12, 15, 18, 22, 28], "X": [20, 40], "C": [4, 12], "V": [10, 24]}
	for slot in ["Z", "X", "C", "V"]:
		for k in p._skill_cooldowns.keys(): p._skill_cooldowns[k] = 0.0
		p._buki.esquecer_recargas_do_servidor()
		p.begin_charge(slot)
		await q(25)
		await foto("%s_1_arma_na_tela" % slot)
		p._buki.atirar()
		var feito := 0
		for m in marcos[slot]:
			await q(m - feito)
			feito = m
			await foto("%s_2_tiro_%02d" % [slot, m])
		await q(30)
		p._buki.guardar()
		await q(70)
	# dash do inimigo: arlong a 8 m na linha do tiro
	for k in p._skill_cooldowns.keys(): p._skill_cooldowns[k] = 0.0
	p._buki.esquecer_recargas_do_servidor()
	var ini := PersonagemMinePiece.new()
	ini.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	ini.position = Vector3(0, 1, -8)
	ini.ponto_de_origem = ini.position
	ini.set_meta("mc_sem_ia", true)
	current_scene.add_child(ini)
	await q(20)
	p.begin_charge("Z")
	await q(25)
	await foto("D_1_antes")
	p._buki.atirar()
	await q(4)
	await foto("D_2_dash")
	await q(10)
	await foto("D_3_depois")
	# minigun: rajada contínua (6 tiros) em 3 instantes
	p._buki.guardar()
	await q(70)
	for k in p._skill_cooldowns.keys(): p._skill_cooldowns[k] = 0.0
	p._buki.esquecer_recargas_do_servidor()
	p.begin_charge("V")
	await q(25)
	for i in 18:
		p._buki.atirar()
		await q(4)
		if i == 5: await foto("V_3_rajada_a")
		if i == 11: await foto("V_3_rajada_b")
		if i == 17: await foto("V_3_rajada_c")
	await q(40)
	p._buki.guardar()
	await q(70)
	# sniper com luneta (botão direito)
	for k in p._skill_cooldowns.keys(): p._skill_cooldowns[k] = 0.0
	p._buki.esquecer_recargas_do_servidor()
	p.begin_charge("C")
	await q(25)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	Input.parse_input_event(ev)
	await q(30)
	await foto("C_3_luneta")
	p._buki.atirar()
	await q(3)
	await foto("C_4_luneta_tiro")
	ev.pressed = false
	Input.parse_input_event(ev)
	quit()
