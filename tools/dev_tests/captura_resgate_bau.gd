extends SceneTree
## Captura (JANELA, com autorização do dono) da 3ª missão: Barba Negra com '?', baú disfarçado, mímico revelado, drop e bússola.
const SAIDA := "res://art_src/validation/resgate_bau/"
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + nome + ".png"))
func frames(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: _r.call_deferred()
func _r() -> void:
	await process_frame
	var caminho := "user://captura_bau.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	RegrasDoDesafioBuggy.marcar_chegada(prog); RegrasDoDesafioBuggy.resolver_copos(prog, true)
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd"); modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var d = null
	for i in 6000:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("resgate_do_bau") != null:
			d = current_scene.resgate_do_bau; break
	for no in current_scene.find_children("CicloDiaNoite", "", true, false): no.pausado = true
	await frames(90)
	var barba = null
	for n in current_scene.find_children("*", "NpcDaIlha", true, false):
		if n.tipo == "npc_barba_negra": barba = n
	var cam := Camera3D.new(); current_scene.add_child(cam); cam.make_current(); cam.fov = 50.0
	# 1) Barba Negra com o '?' da missão
	cam.global_position = barba.global_position + Vector3(4.5, 2.4, 5.0)
	cam.look_at(barba.global_position + Vector3(0, 2.2, 0), Vector3.UP)
	p.global_position = barba.global_position + Vector3(0, 0, 40)
	await frames(30)
	await foto("1_barba_negra_com_missao")
	# aceita a missão pela janela e espera o mímico nascer
	var loja = barba.loja(); loja.set("progressao", d.progressao)
	loja.executar(d.progressao, null, "aceitar", "resgate_do_bau")
	await frames(90)
	var m = d.mimico
	# 2) baú disfarçado
	cam.global_position = m.global_position + Vector3(-5.5, 2.2, 3.5)
	cam.look_at(m.global_position + Vector3(0, 0.4, 0), Vector3.UP)
	p.global_position = m.global_position + Vector3(-30, 1, 0)
	await frames(20)
	await foto("2_bau_disfarcado")
	# 3) mímico revelado (jogador perto) — câmera do jogador: põe o jogador a 4 m
	p.global_position = m.global_position + Vector3(-4.0, 1.0, 1.0)
	await frames(25)
	cam.global_position = m.global_position + Vector3(-1.9, 1.0, 1.3)          # de frente, de perto: tampa, dentes, língua
	cam.look_at(m.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	await frames(6)
	await foto("3_mimico_revelado")
	await frames(40)
	cam.look_at(m.global_position + Vector3(0, 0.45, 0), Vector3.UP)
	await foto("3b_mimico_fugindo")
	# 4) golpe e drop
	m.take_damage(20.0)
	await frames(15)
	await foto("4_mimico_estourando")
	await frames(45)
	var dr = d.drop
	cam.global_position = dr.global_position + Vector3(-2.2, 1.5, 1.8)
	cam.look_at(dr.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	await frames(10)
	await foto("5_drop_bau_misterioso")
	# 6) pega o drop: o item vai para a mochila (abre a mochila para mostrar)
	p.global_position = dr.global_position + Vector3(0.5, 0.0, 0.0)
	await frames(50)
	d.hud.abrir_mochila()
	await frames(20)
	await foto("6_item_na_mochila")
	print("CAPTURA_BAU ok")
	modo.set("progresso_forcado", "")
	quit(0)
