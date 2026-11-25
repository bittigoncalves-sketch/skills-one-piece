extends SceneTree
## Captura (JANELA, com autorização do dono): elenco com texturas novas e as 6 expressões do Buggy em close. Pula a cena (fase já "chegou").
const SAIDA := "res://art_src/validation/desafio_buggy/"
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + nome + ".png"))
func frames(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: _r.call_deferred()
func _r() -> void:
	await process_frame
	var caminho := "user://captura_elenco.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	RegrasDoDesafioBuggy.marcar_chegada(prog)
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd"); modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var d = null
	for i in 6000:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("desafio_buggy") != null:
			d = current_scene.desafio_buggy; break
	for no in current_scene.find_children("CicloDiaNoite", "", true, false): no.pausado = true
	await frames(120)
	p.global_position = Vector3(200, 6, 20)            # longe, para não atrapalhar
	var c = d.chegada
	var cam := Camera3D.new(); current_scene.add_child(cam); cam.make_current()
	# elenco em linha
	var M: Vector3 = c.ponto_no_chao(c.POS_MESA)
	cam.fov = 55.0
	cam.global_position = c.ponto_do_buggy_na_praia() + Vector3(-5.5, 1.9, 1.0)
	cam.look_at(c.ponto_do_buggy_na_praia() + Vector3(1.6, 1.2, 0.0), Vector3.UP)
	await frames(30)
	await foto("elenco_texturas_novas")
	# cada expressão em close (1,7 m) e à distância de jogo (~5 m)
	var rosto: Vector3 = c.rosto_do_buggy()
	for e in ["neutro", "riso", "raiva", "surpresa", "malicioso", "derrotado"]:
		ExpressoesDoBuggy.expressao(c.buggy, e)
		cam.fov = 28.0
		cam.global_position = rosto + Vector3(-1.7, 0.05, 0.0)
		cam.look_at(rosto, Vector3.UP)
		await frames(8)
		await foto("rosto_" + e)
		cam.fov = 45.0
		cam.global_position = rosto + Vector3(-5.0, 0.2, 0.6)
		cam.look_at(rosto + Vector3(0, -0.3, 0), Vector3.UP)
		await frames(6)
		await foto("rosto_" + e + "_jogo")
	print("CAPTURA_ELENCO ok")
	modo.set("progresso_forcado", "")
	quit(0)
