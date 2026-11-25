extends SceneTree
# ============================================================================
#  EDITOR DE JANELAS (05/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_editor_de_janelas.gd
#
#  Pedido do dono: no editor de mapa, ao lado de "Hitboxes", a opção que troca o 3D
#  pela edição das JANELAS do jogo: a lista de janelas na faixa da loja e, escolhida
#  uma, edição como num canvas. Decisões: posição, tamanho, texto e aparência; as
#  janelas do Modo História; salvo NO PROJETO.
#    A — o layout: endereço estável dos elementos (nome ou posição), gravar, aplicar,
#        salvar e reler;
#    B — o editor de verdade: o botão/tecla J troca o 3D pelo modo janelas (loja e
#        painel do 3D somem, atalhos do 3D desligados), cada janela do catálogo monta
#        na tela, clique escolhe o elemento, arrastar move, alças redimensionam,
#        texto/fonte/cores mudam, elemento de lista só muda o tamanho mínimo,
#        restaurar volta ao original, Ctrl+S salva;
#    C — o jogo: a janela de verdade aplica o layout salvo ao abrir.
#  Arquivo de layout de TESTE (nunca o do projeto).
# ============================================================================

const LAYOUT := "user://test_layout_janelas.json"
const MAPA := "user://test_editor_de_janelas_mapa.json"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYOUT))
	LayoutDeJanelas.caminho_forcado = LAYOUT
	LayoutDeJanelas.recarregar()
	print("\n===== A: layout =====")
	_layout()
	print("\n===== B: editor =====")
	await _editor()
	print("\n===== C: jogo =====")
	await _jogo()
	LayoutDeJanelas.caminho_forcado = ""
	LayoutDeJanelas.recarregar()
	print("\nEDITOR_JANELAS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _layout() -> void:
	var raiz := VBoxContainer.new()
	raiz.name = "Raiz"
	var titulo := Label.new()
	titulo.name = "Titulo"
	raiz.add_child(titulo)
	var sem_nome := Label.new()
	raiz.add_child(sem_nome)          # vira "@Label@nnn"
	var dentro := Label.new()
	sem_nome.add_child(dentro)
	get_root().add_child(raiz)
	var c1 := LayoutDeJanelas.caminho_de(raiz, titulo)
	var c2 := LayoutDeJanelas.caminho_de(raiz, dentro)
	_ok("endereço: nome fixo pelo nome, sem nome pela posição (%s, %s)" % [c1, c2], c1 == "Titulo" and c2 == "#1/#0")
	_ok("endereço volta ao mesmo nó", LayoutDeJanelas.no_por_caminho(raiz, c2) == dentro and LayoutDeJanelas.no_por_caminho(raiz, ".") == raiz)
	LayoutDeJanelas.gravar("teste", "Titulo", "texto", "Olá")
	LayoutDeJanelas.gravar("teste", "Titulo", "fonte", 22)
	LayoutDeJanelas.gravar("teste", "Titulo", "cor_texto", Color(1, 0, 0))
	LayoutDeJanelas.gravar("teste", "Titulo", "tam", Vector2(200, 30))
	LayoutDeJanelas.aplicar("teste", raiz)
	_ok("aplicar: texto, fonte, cor e tamanho mínimo (elemento de lista)",
		titulo.text == "Olá" and titulo.get_theme_font_size("font_size") == 22
		and titulo.get_theme_color("font_color").is_equal_approx(Color(1, 0, 0)) and titulo.custom_minimum_size == Vector2(200, 30))
	_ok("salvar grava o arquivo", LayoutDeJanelas.salvar() == OK and FileAccess.file_exists(LAYOUT))
	LayoutDeJanelas.recarregar()
	_ok("reler devolve o que foi salvo", str(LayoutDeJanelas.do_elemento("teste", "Titulo").get("texto")) == "Olá")
	LayoutDeJanelas.esquecer("teste", "Titulo")
	_ok("esquecer tira o elemento", LayoutDeJanelas.da_janela("teste").is_empty())
	raiz.queue_free()


func _editor() -> void:
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tools/dev_tests/fixtures/mapa_baseplate.json"),
		ProjectSettings.globalize_path(MAPA))
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = MAPA
	get_root().add_child(ed)
	current_scene = ed
	await _quadros(10)
	var doc: DocumentoMapa = ed.doc
	var peca: String = ed.inserir("caixa")
	await _quadros(3)
	var barra: BarraDoEditor = ed.get("_barra")
	var botao := barra.find_child("Janelas", true, false) as Button
	_ok("botão Janelas na barra, depois de Hitboxes", botao != null and botao.get_index() == (barra.get("_hitboxes") as Button).get_index() + 1)
	await _tecla(KEY_J)
	var je: EditorDeJanelas = ed.get("_janelas")
	_ok("J liga o modo janelas: loja e painel do 3D somem", je.ativo() and not (ed.get("_loja") as Control).visible
		and not (ed.get("_lateral") as Control).visible and botao.button_pressed)
	await _tecla(KEY_DELETE)
	_ok("atalhos do 3D desligados (Del não apagou a peça selecionada)", doc.tem(peca))

	var nomes := []
	var montaram := true
	for id in CatalogoDeJanelas.ids():
		je.escolher_janela(id)
		await _quadros(4)
		var j := je.janela
		var dentro := j != null and is_instance_valid(j) and j.is_visible_in_tree() \
			and Rect2(Vector2.ZERO, EditorDeJanelas.TELA).intersects(j.get_global_rect()) and j.get_global_rect().size.length() > 10.0
		montaram = montaram and dentro
		if not dentro:
			nomes.append(id)
	_ok("as %d janelas do catálogo montam na tela (falharam: %s)" % [CatalogoDeJanelas.ids().size(), str(nomes)], montaram)
	var img: Control = je.get("_imagem")
	_ok("a tela do jogo fica em 1280×720 e aparece REDUZIDA, 16:9 (%s, imagem %s)" % [je.get("_viewport").size, img.size.round()],
		je.get("_viewport").size == Vector2i(1280, 720) and absf(img.size.x / maxf(img.size.y, 1.0) - 16.0 / 9.0) < 0.01)

	# --- inventário: mover a janela arrastando no canvas
	je.escolher_janela("inventario")
	await _quadros(4)
	var inv := je.janela
	je.selecionar(inv)
	var antes := inv.position
	var k: float = je._escala()
	# Pela faixa de cima (cabeça): o clique escolhe o que está sob o cursor, e a janela
	# só arrasta inteira se o ponto for dela — a borda de 3 px do painel é dela.
	# (a 30 % da largura: o meio da borda é a ALÇA de cima, que redimensiona).
	var centro := (inv.get_global_rect().position + Vector2(inv.size.x * 0.3, 1.5)) * k
	je._canvas_input(_botao(centro, true))
	je._canvas_input(_movimento(centro + Vector2(40, 20)))
	je._canvas_input(_botao(centro + Vector2(40, 20), false))
	await _quadros(2)
	var esperado := antes + Vector2(40, 20) / k
	_ok("arrastar pela cabeça move a janela inteira (%s → %s, esperado %s)" % [antes, inv.position, esperado.round()],
		inv.position.distance_to(esperado) < 1.5 and LayoutDeJanelas.do_elemento("inventario", ".").has("pos"))
	# alça do canto de baixo à direita: redimensiona a janela (escolhida na árvore)
	je.selecionar(inv)
	var r := je._retangulo_no_canvas(inv)
	var tam0 := inv.size
	je._canvas_input(_botao(r.end, true))
	je._canvas_input(_movimento(r.end + Vector2(30, 0)))
	je._canvas_input(_botao(r.end + Vector2(30, 0), false))
	await _quadros(2)
	_ok("alça do canto redimensiona (%s → %s)" % [tam0, inv.size], inv.size.x > tam0.x + 20.0)
	# clique escolhe o elemento mais de dentro
	var rotulo: Label = null
	for l in inv.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and not (l as Label).text.is_empty():
			rotulo = l
			break
	var p_rot: Vector2 = rotulo.get_global_rect().get_center() * k
	je._canvas_input(_botao(p_rot, true))
	je._canvas_input(_botao(p_rot, false))
	_ok("clique escolhe o elemento mais de dentro (%s)" % je.caminho_selecionado(), je.selecionado == rotulo)
	var texto_original := rotulo.text
	je.mudar("texto", "MOCHILA DO PIRATA")
	je.mudar("fonte", 24)
	je.mudar("cor_texto", Color(1, 0.5, 0))
	_ok("texto, fonte e cor do texto mudam na hora", rotulo.text == "MOCHILA DO PIRATA" and rotulo.get_theme_font_size("font_size") == 24)
	_ok("elemento de lista: não move, tamanho vira mínimo", not je.movivel(rotulo))
	var caminho_rotulo := je.caminho_selecionado()
	je.selecionar(inv)
	je.mudar("cor_fundo", Color(0.2, 0.05, 0.05, 0.95))
	var sb := inv.get_theme_stylebox("panel") as StyleBoxFlat
	# A cor viaja como "#rrggbbaa": 8 bits por canal.
	var dif := (sb.bg_color - Color(0.2, 0.05, 0.05, 0.95)) if sb != null else Color.WHITE
	_ok("cor de fundo da janela", sb != null and maxf(maxf(absf(dif.r), absf(dif.g)), maxf(absf(dif.b), absf(dif.a))) < 0.01)
	# ctrl+s salva o layout
	await _tecla(KEY_S, true)
	_ok("Ctrl+S salva o layout das janelas", FileAccess.file_exists(LAYOUT)
		and FileAccess.get_file_as_string(LAYOUT).contains("MOCHILA DO PIRATA"))
	# restaurar: o elemento volta ao original
	je.escolher_janela("inventario")
	await _quadros(3)
	var de_novo := LayoutDeJanelas.no_por_caminho(je.janela, caminho_rotulo) as Label
	je.selecionar(de_novo)
	je.mudar("texto", "TEMPORÁRIO")
	je.restaurar()
	await _quadros(3)
	var restaurado := LayoutDeJanelas.no_por_caminho(je.janela, caminho_rotulo) as Label
	_ok("restaurar volta o texto original (\"%s\")" % restaurado.text, restaurado.text == texto_original)
	# volta o texto editado para o teste do jogo
	je.selecionar(restaurado)
	je.mudar("texto", "MOCHILA DO PIRATA")
	je.salvar()
	await _tecla(KEY_J)
	_ok("J de novo volta ao 3D (loja e painel de volta)", not je.ativo() and (ed.get("_loja") as Control).visible
		and (ed.get("_lateral") as Control).visible)
	_rotulo_salvo = caminho_rotulo
	ed.queue_free()
	await _quadros(3)


var _rotulo_salvo := ""


func _jogo() -> void:
	LayoutDeJanelas.recarregar()
	var tela := Control.new()
	tela.size = Vector2(1280, 720)
	get_root().add_child(tela)
	var prog := CatalogoDeJanelas.progresso_de_exemplo()
	var inv := InventarioDaHistoria.new()
	tela.add_child(inv)
	inv.ligar(prog, null, null)
	inv.visible = true
	inv.mostrar_aba("frutas")
	await _quadros(3)
	var salvo := LayoutDeJanelas.do_elemento("inventario", ".")
	var rotulo := LayoutDeJanelas.no_por_caminho(inv, _rotulo_salvo) as Label
	_ok("no jogo, o inventário abre com o texto e a posição do layout (%s)" % (rotulo.text if rotulo else "?"),
		rotulo != null and rotulo.text == "MOCHILA DO PIRATA" and inv.position.distance_to(LayoutDeJanelas._vec(salvo.get("pos"))) < 1.0)
	inv.mostrar_aba("frutas")
	await _quadros(2)
	_ok("trocar de aba mantém o layout (posição %s)" % inv.position, inv.position.distance_to(LayoutDeJanelas._vec(salvo.get("pos"))) < 1.0)
	tela.queue_free()


func _botao(p: Vector2, pressionado: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressionado
	ev.position = p
	return ev


func _movimento(p: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	return ev


func _tecla(codigo: Key, ctrl := false) -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = codigo
		ev.keycode = codigo
		ev.ctrl_pressed = ctrl
		ev.pressed = pressionada
		Input.parse_input_event(ev)
		await process_frame
	await process_frame


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
