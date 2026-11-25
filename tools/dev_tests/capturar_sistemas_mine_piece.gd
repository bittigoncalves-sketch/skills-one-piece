extends SceneTree
## Capturas dos sistemas do Mine Piece na campanha (18/10/2026, docs/MINE_PIECE_SISTEMAS_PLANO.md):
## monitor de FPS, barra com a água antes da comida, raid em andamento, um navio do mod à
## venda pilotado e as árvores das frutas Mine Piece na arena.
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_sistemas_mine_piece.gd
## Saída: art_src/validation/sistemas_mine_piece/*.png

const PASTA := "res://art_src/validation/sistemas_mine_piece"


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func _foto(nome: String) -> void:
	await frames(20)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [PASTA, nome])


func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://capturar_sistemas_mine_piece.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capturar_sistemas_mine_piece.json"))
	root.get_node("GameFlow").start_story()
	await frames(300)
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var P := preload("res://src/historia/tripulantes/provisoes.gd")
	P.guardar(prog, "agua_potavel", 3)
	P.guardar(prog, "pao", 2)
	prog.ativar_item("agua")
	await _foto("barra_agua_e_fps")
	# Raid no East Blue.
	cena.call("ir_a_ilha", "ilha_east_blue")
	await frames(30)
	prog.ativar_item("bandeira")
	var raid: Node = cena.get("raid")
	raid.iniciar()
	await frames(240)
	await _foto("raid_em_andamento")
	raid.cancelar("captura")
	# Navio do mod comprado, no cais.
	cena.call("ir_a_ilha", "ilha_inicial")
	await frames(30)
	var nav = cena.get("_navegacao")
	prog.barcos["mpe_ship_going_merry"] = true
	nav.lancar("mpe_ship_going_merry")
	await frames(20)
	var b: Node3D = nav.barco_do_jogador("mpe_ship_going_merry")
	if b != null:
		j.global_position = b.leme.global_position + Vector3.UP * 0.9
		await frames(30)
		await _foto("going_merry_no_cais")
	modo.set("progresso_forcado", "")
	# Arena: árvores Mine Piece.
	root.get_node("GameFlow").start_singleplayer()
	await frames(240)
	var arvore := current_scene.find_child("Tree_pika_pika_no_mi_mine_piece", true, false) as Node3D
	if arvore != null:
		var cam := Camera3D.new()
		current_scene.add_child(cam)
		cam.current = true
		cam.global_position = arvore.global_position + Vector3(4.5, 3.0, 4.5)
		cam.look_at(arvore.global_position + Vector3.UP * 1.5)
		await _foto("arena_arvore_pika_mine_piece")
	quit()
