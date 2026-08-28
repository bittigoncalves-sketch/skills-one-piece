extends SceneTree
func _init() -> void:
	var S := "/tmp/claude-1000/-home-gabriel-bitti-dev/4b4195b4-fa72-4474-b4ee-43d04c087a61/scratchpad/cor"
	DirAccess.make_dir_recursive_absolute(S)
	await process_frame
	var menu := CustomizacaoMenu.new()
	get_root().add_child(menu)
	for i in 40: await process_frame
	menu._selecionar_categoria("cor")
	for i in 15: await process_frame
	print("### PELES no catálogo: %d | CORES: %d" % [Paleta.PELES.size(), Paleta.CORES.size()])
	print("### filhos da lista da direita: %d" % menu._lista_direita.get_child_count())
	var rotulos: Array = []
	for f in menu._lista_direita.get_children():
		var txt := _texto(f)
		if txt != "": rotulos.append(txt)
	print("### rótulos: %s" % str(rotulos))
	var r := menu._lista_direita.get_global_rect()
	print("### lista: pos(%.0f,%.0f) tam(%.0f,%.0f) fim y=%.0f | tela y=%d" % [
		r.position.x, r.position.y, r.size.x, r.size.y, r.end.y, get_root().size.y])
	get_root().get_texture().get_image().save_png("%s/aba_cor.png" % S)
	quit()
func _texto(n: Node) -> String:
	if n is Label: return (n as Label).text
	for f in n.get_children():
		var t := _texto(f)
		if t != "": return t
	return ""
