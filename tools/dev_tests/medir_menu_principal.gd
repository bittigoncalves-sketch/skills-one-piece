extends SceneTree
# ============================================================================
#  O MENU PRINCIPAL CABE NA TELA?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_menu_principal.gd
#
#  ⚠️ POR QUE EXISTE. Ao acrescentar o botão de CUSTOMIZAÇÃO, o conteúdo passou a
#  somar 831 px numa tela de 720: o botão de CONFIGURAÇÕES ficava INTEIRAMENTE
#  fora e nada avisava. Menu não tem teste, não trava a bateria e não gera erro —
#  quebra em silêncio e só aparece quando alguém abre.
#
#  Esta sonda varre todo `Control` da árvore e reprova se algum ultrapassar a
#  tela. Assim o sexto botão não repete o que o quinto fez.
#
#  ⚠️ E o `MainMenu` é carregado em tempo de EXECUÇÃO (`load(...).new()`), não
#  referenciando a classe: ele depende do autoload `GameFlow`, que ainda não
#  existe quando um script de `-s` COMPILA.
# ============================================================================

func _init() -> void:
	await process_frame
	var menu: Control = (load("res://src/ui/MainMenu.gd") as GDScript).new()
	get_root().add_child(menu)
	for i in 45:
		await process_frame

	var tela: Vector2i = get_root().size
	print("tela: %d x %d" % [tela.x, tela.y])
	var fora: Array = []
	_varrer(menu, tela, fora)

	var botoes := 0
	for n in _todos(menu):
		if n is PanelContainer and (n as Control).custom_minimum_size.y >= 60:
			botoes += 1
	print("botões principais encontrados: %d" % botoes)

	if fora.is_empty():
		print("✓ nenhum controle passa da tela")
		quit(0)
		return
	print("❌ %d controle(s) fora da tela:" % fora.size())
	for f in fora:
		print("   %s" % f)
	quit(1)


func _varrer(n: Node, tela: Vector2i, fora: Array) -> void:
	if n is Control:
		var c := n as Control
		var r := c.get_global_rect()
		# Margem de 1 px: arredondamento de layout não é defeito.
		if r.size.x > 0.0 and (r.end.x > tela.x + 1 or r.end.y > tela.y + 1
				or r.position.x < -1 or r.position.y < -1):
			fora.append("%s pos(%.0f,%.0f) tam(%.0f,%.0f) fim(%.0f,%.0f)" % [
				c.name, r.position.x, r.position.y, r.size.x, r.size.y, r.end.x, r.end.y])
	for f in n.get_children():
		_varrer(f, tela, fora)


func _todos(n: Node) -> Array:
	var o: Array = [n]
	for f in n.get_children():
		o.append_array(_todos(f))
	return o
