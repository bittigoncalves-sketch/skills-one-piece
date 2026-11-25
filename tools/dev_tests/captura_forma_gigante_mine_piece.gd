extends SceneTree
# Captura (com GPU) da forma gigante do mod, pela CÂMERA REAL do jogador: normal e escala 4.
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_forma_gigante_mine_piece.gd -- <pasta>
var saida := "/tmp/forma_mp"

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])

func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_forma.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var ref := PersonagemMinePiece.new()
	ref.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	ref.position = jogador.global_position + Vector3(3.0, 0, -4.0)
	ref.ponto_de_origem = ref.position
	ref.set_meta("mc_sem_ia", true)
	current_scene.add_child(ref)
	await quadros(60)
	await foto("1_normal")
	var ej := McEntidade.de(jogador)
	var fonte := McComandos.Fonte.new()
	fonte.mundo = ej.level()
	fonte.entidade = ej
	fonte.posicao = ej.position()
	for c in ["scale set pehkui:width 4 @s", "scale set pehkui:height 4 @s"]:
		McComandos.executar(fonte, c)
	await quadros(90)
	await foto("2_gigante")
	print("CAMERA y=%s" % str(jogador.get_viewport().get_camera_3d().global_position))
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
