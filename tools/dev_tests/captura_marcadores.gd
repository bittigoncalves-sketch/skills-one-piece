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
	var instrutor = d._achar_instrutor()
	# nível 1 → revanche aceita, falta treinar: o instrutor é o objetivo
	d.progressao.nivel = 1
	p.global_position = instrutor.global_position + Vector3(-8.0, 0.8, 8.0)
	await q(40)
	await foto("10_marcador_instrutor")
	d.progressao.nivel = 3
	d.progressao.mudou.emit()
	p.global_position = d.chegada.buggy.global_position + Vector3(-14.0, 0.8, 6.0)
	await q(40)
	await foto("11_marcador_buggy")
	quit()
