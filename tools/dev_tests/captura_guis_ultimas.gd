extends SceneTree
## Roleta, ferraria e tripulação com o tema: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_guis_ultimas.gd -- <pasta>
var saida := "/tmp/guis_ult"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()
func foto(nome: String, n := 25) -> void:
	for i in n:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
func _rodar() -> void:
	GuiMinecraft.ligar_normalizacao(self)
	var fundo := ColorRect.new()
	fundo.color = Color(0.3, 0.45, 0.3)
	fundo.size = Vector2(1280, 720)
	root.add_child(fundo)
	var cl := CanvasLayer.new()
	root.add_child(cl)
	var prog := CatalogoDeJanelas.progresso_de_exemplo()
	var bib := BibliotecaDeModelos.padrao()
	var tr := JanelaDaTripulacao.new()
	cl.add_child(tr)
	tr.ligar(prog, bib)
	tr.perguntar()
	await foto("tripulacao")
	tr.queue_free()
	var fe: Control = load("res://src/ui/FerrariaHud.gd").new()
	cl.add_child(fe)
	fe.visible = true
	await foto("ferraria")
	fe.queue_free()
	var ro := RoletaHud.new()
	ro.duracao = 30.0
	cl.add_child(ro)
	ro.girar({"id": "x", "nome": "Tripulante de Teste", "raridade": "raro"})
	await foto("roleta_girando", 40)
	ro.pular()
	await foto("roleta", 60)
	quit()
