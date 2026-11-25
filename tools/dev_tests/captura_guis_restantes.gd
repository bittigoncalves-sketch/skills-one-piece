extends SceneTree
## Telas que faltavam com o tema global: loja, pesca, técnicas, ferramentas (catálogo de janelas), customização, arena.
##   DISPLAY=:1 godot --path . -s tools/dev_tests/captura_guis_restantes.gd -- <pasta>
var saida := "/tmp/guis_mc"
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()
func foto(nome: String, n := 20) -> void:
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
	var apoio := Node.new()
	root.add_child(apoio)
	var bib := BibliotecaDeModelos.padrao()
	for id in ["loja", "pesca", "tecnicas", "ferramentas", "status"]:
		var cont := Control.new()
		cont.size = Vector2(1280, 720)
		root.add_child(cont)
		var j := CatalogoDeJanelas.criar(id, cont, apoio, bib)
		await foto("janela_" + id)
		cont.queue_free()
	var cm := CustomizacaoMenu.new()
	root.add_child(cm)
	await foto("customizacao", 40)
	quit()
