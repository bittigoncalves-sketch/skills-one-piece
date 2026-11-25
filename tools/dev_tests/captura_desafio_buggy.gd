extends SceneTree
## Captura visual do desafio do Buggy (21/11/2026): planos da cena, plateia, copos, moradores. JANELA (precisa de autorização do dono):
##   godot --display-driver x11 --resolution 1280x720 --path . --fixed-fps 60 --script res://tools/dev_tests/captura_desafio_buggy.gd
const SAIDA := "res://art_src/validation/desafio_buggy/"
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + nome + ".png"))
func frames(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: _rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	var caminho := "user://captura_buggy.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
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
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	for i in 600:
		await physics_frame
		if d.etapa == 1: break
	# a cena tem ~27 s (1620 quadros a 60 fps); um print no meio de cada plano
	var marcas := [["cena1_navio_aparece", 200], ["cena2_atracacao", 570], ["cena3_desembarque_a", 800], ["cena3_desembarque_b", 1000], ["cena4_close_no_rosto", 1480]]
	var passados := 0
	for m in marcas:
		await frames(int(m[1]) - passados)
		passados = int(m[1])
		await foto(String(m[0]))
	await frames(260)          # fim da cena
	print("etapa depois da cena: ", d.etapa)
	await frames(60 * 24)      # a tripulação caminha até a praia e os moradores correm
	var M: Vector3 = d.chegada.ponto_no_chao(d.chegada.POS_MESA)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	cam.fov = 58.0
	# de onde o jogador chega (oeste), olhando para a mesa e o Buggy
	cam.global_position = M + Vector3(-9.5, 2.2, 3.0)
	cam.look_at(M + Vector3(2.0, 1.2, 0.0), Vector3.UP)
	await frames(20)
	await foto("praia_chegando_na_mesa")
	cam.global_position = M + Vector3(-2.8, 1.7, -3.2)
	cam.look_at(M + Vector3(1.6, 1.3, 0.0), Vector3.UP)
	await frames(10)
	await foto("praia_mesa_e_buggy")
	cam.global_position = M + Vector3(10.0, 5.5, 9.0)
	cam.look_at(M + Vector3(-1.0, 0.6, 0.0), Vector3.UP)
	await frames(10)
	await foto("praia_plateia_em_anel")
	# o jogador chega e a conversa/jogo começam
	p.global_position = d.chegada.ponto_do_buggy_na_praia() + Vector3(-5.5, 0.3, 0.0)
	await frames(90)
	d.hud.caixa_de_fala().pular()
	await frames(10)
	cam.global_position = M + Vector3(-2.6, 2.3, 3.4)          # de lado: a cabeça do jogador não tapa os copos
	cam.look_at(M + Vector3(0.1, 1.0, 0.0), Vector3.UP)
	await frames(45)
	await foto("copos_na_mesa_mostra_a_pedra")
	await frames(200)
	await foto("copos_na_mesa_embaralhando")
	for i in 60 * 14:
		await physics_frame
		if d._jogo.fase == 3: break
	await foto("copos_na_mesa_escolha")
	d._jogo.escolher(d._jogo.pedra_no_copo())
	await frames(50)
	await foto("copos_na_mesa_revela_acerto")
	print("CAPTURA_BUGGY ok")
	modo.set("progresso_forcado", "")
	quit(0)
