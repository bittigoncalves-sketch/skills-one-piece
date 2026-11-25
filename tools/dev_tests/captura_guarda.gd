extends SceneTree
## Captura da luta do Buggy no ringue (22/11/2026). Weston isolado (docs/MODO_HISTORIA.md):
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . --resolution 1280x720 --script tools/dev_tests/captura_luta_do_buggy.gd -- <pasta>
var saida := "/tmp/luta_do_buggy"
func q(n: int) -> void:
	for i in n: await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
	print("CAPTURA ", nome)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()
func _rodar() -> void:
	var R := RegrasDoDesafioBuggy
	var caminho := "user://captura_luta_buggy.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.nivel = R.NIVEL_DA_LUTA
	R._gravar(prog, R.ACEITOU)
	prog.aceitar_missao(R.MISSAO_LUTA)
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var d = null
	for i in 2400:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("desafio_buggy") != null:
			d = current_scene.desafio_buggy
			break
	await q(60)
	p.set_meta("damage_immune", true)
	p.global_position = d.chegada.buggy.global_position + Vector3(-5.0, 0.8, 0.0)
	for i in 400:
		await physics_frame
		if d.etapa == 3: break
	d.hud.caixa_de_fala().pular()
	for i in 300:
		await physics_frame
		if d.luta_ativa(): break
	var l = d.luta
	for i in 200:
		await physics_frame
		if l.fase == LutaDoBuggy.Fase.ESPERANDO: break
	l.set_process(false)                                   # congela a luta: só a pose
	p.set_meta("pose_externa", LutaDoBuggy.POSE_DE_GUARDA)
	var frente: Vector3 = Vector3.RIGHT
	var cam := Camera3D.new()
	cam.fov = 50.0
	root.add_child(cam)
	cam.current = true
	cam.global_position = p.global_position + Vector3(1.0, 0.5, 2.0)
	cam.look_at(p.global_position + Vector3.UP * 0.4)
	await q(10)
	await foto("08_guarda_frente")
	cam.global_position = p.global_position + Vector3(-0.2, 0.9, 1.6)
	cam.look_at(p.global_position + Vector3.UP * 0.4)
	await q(5)
	await foto("09_guarda_lado")
	quit()
