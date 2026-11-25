class_name MochilaMinecraft
extends Control
## MOCHILA DE BORDO (19/11/2026, pedido do dono: "personalize a mochila para ficar diferente do Minecraft"). A lógica continua a do `InventarioMinecraft`
## (46 slots na ordem do `InventoryMenu`: clique esquerdo/direito/shift, 1–9, item preso ao mouse), mas a CARA é própria: layout reorganizado
## (equipamento em tira horizontal, fabricação ao lado da prévia, hotbar separada por um filete dourado) e moldura desenhada em código —
## fundo azul-petróleo, latão dourado, rebites — a mesma paleta do `EstiloDaHistoria`. Nenhuma textura do Mojang entra mais aqui.
## Página "MOCHILA" da central de janelas, ao lado do painel de itens (`InventarioDaHistoria`: frutas, pesca, armas, materiais).
## Só apresenta e pede: quem guarda é o `InventarioMinecraft` (na progressão, salvo com o personagem).
const ESCALA_PADRAO := 3
const ESCALA_MINIMA := 1.0
const ESCALA_MAXIMA := 6.0
const PASSO_DA_ESCALA := 0.25            # degraus: pixel não borra com escala quebrada demais
const FOLGA := 12.0                      # respiro, em px da página, em volta da mochila
const LARGURA := 176
const ALTURA := 162
const OURO := Color(0.95, 0.79, 0.40)
const FUNDO := Color(0.035, 0.095, 0.115)
const FUNDO_DO_SLOT := Color(0.075, 0.165, 0.195)
const FUNDO_DO_EQUIPAMENTO := Color(0.085, 0.135, 0.235)
const FUNDO_DO_RESULTADO := Color(0.19, 0.135, 0.05)
const COR_DE_DESTAQUE := Color(OURO, 0.30)
## Ícone-fantasma dos slots de armadura e da mão secundária quando vazios: container → nome do arquivo `empty_armor_slot_*`.
const FANTASMAS := {5: "helmet", 6: "chestplate", 7: "leggings", 8: "boots", 45: "shield"}
## A prévia do personagem (retângulo do layout, em px lógicos).
const PREVIA := Rect2(8, 8, 50, 62)

var inventario: InventarioMinecraft
var progressao: ProgressaoDoPersonagem            # para o ícone/nome dos itens do jogo (fruta, vara…)
var escala: float = float(ESCALA_PADRAO)      # fracionária: a mochila preenche a página da central (`ajustar_ao_espaco`)
var _posicoes: Array[Vector2] = []          # slot do container → canto (em px do layout 176×166)
var _icones: Array[TextureRect] = []
var _numeros: Array[Label] = []
var _cursor: Control
var _cursor_icone: TextureRect
var _cursor_numero: Label
var _dica: Label
var _sobre := -1
## Largura (px da página) que o painel de itens ocupa ao lado: a escala da grade só conta o que sobra (`HistoriaHud` define).
var largura_reservada := 0.0


func _init() -> void:
	name = "MochilaMinecraft"
	for i in InventarioMinecraft.TOTAL:
		_posicoes.append(posicao_do_slot(i))


## O layout próprio (origem de cada item de 16×16, em px lógicos): equipamento em tira horizontal no alto, fabricação 2×2 + resultado, mochila 3×9 e hotbar.
static func posicao_do_slot(i: int) -> Vector2:
	if i == InventarioMinecraft.RESULTADO:
		return Vector2(124, 45)
	if i >= InventarioMinecraft.GRADE_INI and i < InventarioMinecraft.GRADE_FIM:
		var k := i - InventarioMinecraft.GRADE_INI
		return Vector2(66 + (k % 2) * 18, 36 + (k / 2) * 18)
	if i >= InventarioMinecraft.ARMADURA_INI and i < InventarioMinecraft.ARMADURA_FIM:
		return Vector2(66 + (i - InventarioMinecraft.ARMADURA_INI) * 18, 8)
	if i >= InventarioMinecraft.MOCHILA_INI and i < InventarioMinecraft.MOCHILA_FIM:
		var k := i - InventarioMinecraft.MOCHILA_INI
		return Vector2(8 + (k % 9) * 18, 78 + (k / 9) * 18)
	if i >= InventarioMinecraft.HOTBAR_INI and i < InventarioMinecraft.HOTBAR_FIM:
		return Vector2(8 + (i - InventarioMinecraft.HOTBAR_INI) * 18, 138)
	return Vector2(146, 8)                  # mão secundária, ao fim da tira de equipamento


func ligar(inv: InventarioMinecraft, prog: ProgressaoDoPersonagem = null) -> void:
	inventario = inv
	progressao = prog
	inv.mudou.connect(atualizar)
	_montar()
	atualizar()
	_seguir_a_pagina.call_deferred()


## A mochila ocupa a página da central (a `ScrollContainer` que a guarda): maior escala, em degraus, que cabe com folga — e
## acompanha a janela quando ela encolhe ou cresce (a central inteira já escala com a tela; aqui é a proporção dentro dela).
func _seguir_a_pagina() -> void:
	var rol := _pagina()
	if rol == null:
		return
	if not rol.resized.is_connected(ajustar_ao_espaco):
		rol.resized.connect(ajustar_ao_espaco)
	ajustar_ao_espaco()


func _pagina() -> ScrollContainer:
	var n := get_parent()
	while n != null and not (n is ScrollContainer):
		n = n.get_parent()
	return n as ScrollContainer


func ajustar_ao_espaco() -> void:
	var rol := _pagina()
	if rol == null or inventario == null or rol.size.x <= 0.0 or rol.size.y <= 0.0:
		return                           # página ainda sem layout: a escala atual fica
	# Nunca mais que o corpo nominal da central: a página se estica quando OUTRA aba é mais larga (a PETS), e escalar sobre essa largura esticada faria a mochila
	# pedir mais que os 1040 px da janela (e a janela crescer) — o laço realimentado que o teste da central pegou.
	var area := Vector2(minf(rol.size.x, CentralDeJanelas.LARGURA), minf(rol.size.y, CentralDeJanelas.ALTURA))
	var nova := escala_que_cabe(area - Vector2(largura_reservada, 0.0))
	if not is_equal_approx(nova, escala):
		escala = nova
		_montar()
		atualizar()


static func escala_que_cabe(area: Vector2) -> float:
	var cabe := minf((area.x - FOLGA) / LARGURA, (area.y - FOLGA) / ALTURA)
	return clampf(floorf(cabe / PASSO_DA_ESCALA) * PASSO_DA_ESCALA, ESCALA_MINIMA, ESCALA_MAXIMA)


var _previa: PreviaDoPersonagem


func _montar() -> void:
	for f in get_children():
		remove_child(f)                  # já, não só `queue_free`: o nome (Titulo_*, Slot*) é reaproveitado na remontagem
		f.queue_free()
	_icones.clear()
	_numeros.clear()
	custom_minimum_size = Vector2(LARGURA, ALTURA) * escala
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	# A prévia 3D do personagem (mundo próprio) vive no retângulo `PREVIA`, montada só quando a janela abre — escondida, um personagem inteiro seria desenhado à toa.
	_previa = PreviaDoPersonagem.new()
	_previa.corpo_historia = progressao.corpo if progressao != null else ""
	_previa.tom_de_pele = progressao.tom_de_pele if progressao != null else "medio"
	_previa.aparencia_historia = progressao.aparencia.duplicate() if progressao != null else {}
	_previa.name = "PreviaMochila"
	_previa.montar_ao_entrar = false
	_previa.cor_da_base = Color(0.10, 0.10, 0.10)
	_previa.position = PREVIA.position * escala
	_previa.size = PREVIA.size * escala
	add_child(_previa)
	if is_visible_in_tree():
		_previa.remontar.call_deferred()      # a janela já está aberta (a escala mudou e tudo foi refeito)
	for i in InventarioMinecraft.TOTAL:
		var tr := TextureRect.new()
		tr.name = "Slot%d" % i
		tr.position = _posicoes[i] * escala
		tr.size = Vector2(16, 16) * escala
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		_icones.append(tr)
		var n := Label.new()
		n.name = "Qtd%d" % i
		n.add_theme_font_size_override("font_size", roundi(7 * escala))
		n.add_theme_color_override("font_color", Color.WHITE)
		n.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.05))
		n.add_theme_constant_override("outline_size", maxi(2, roundi(escala * 1.5)))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.size = Vector2(17, 11) * escala
		n.position = _posicoes[i] * escala + Vector2(1, 6) * escala
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(n)
		_numeros.append(n)
	for t in [["Fabricar", Vector2(66, 25)]]:      # o único título: o equipamento e a hotbar se explicam pelos ícones-fantasma e pelo filete dourado
		var l := Label.new()
		l.name = "Titulo_" + str(t[0])
		l.text = str(t[0]).to_upper()
		l.add_theme_font_size_override("font_size", roundi(7 * escala))
		l.add_theme_color_override("font_color", Color(OURO, 0.75))
		l.position = (t[1] as Vector2) * escala - Vector2(0, 2.0 * escala)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
	_cursor = Control.new()
	_cursor.name = "Cursor"
	_cursor.top_level = true
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.z_index = 100
	_cursor_icone = TextureRect.new()
	_cursor_icone.size = Vector2(16, 16) * escala
	_cursor_icone.position = -_cursor_icone.size * 0.5
	_cursor_icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cursor_icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cursor_icone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_cursor_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.add_child(_cursor_icone)
	_cursor_numero = Label.new()
	_cursor_numero.add_theme_font_size_override("font_size", roundi(6 * escala))
	_cursor_numero.add_theme_color_override("font_shadow_color", Color(0.25, 0.25, 0.25))
	_cursor_numero.add_theme_constant_override("shadow_offset_x", maxi(1, roundi(escala)))
	_cursor_numero.add_theme_constant_override("shadow_offset_y", maxi(1, roundi(escala)))
	_cursor_numero.position = Vector2(0, 0)
	_cursor_numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.add_child(_cursor_numero)
	add_child(_cursor)
	_dica = Label.new()
	_dica.name = "Dica"
	_dica.top_level = true
	_dica.visible = false
	_dica.z_index = 101
	_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dica.add_theme_font_size_override("font_size", 14)
	_dica.add_theme_stylebox_override("normal", _caixa_da_dica())
	add_child(_dica)


static func _caixa_da_dica() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.07, 0.0, 0.12, 0.92)
	s.border_color = Color(0.3, 0.0, 0.5, 1.0)
	s.set_border_width_all(2)
	s.set_content_margin_all(6)
	return s


func atualizar() -> void:
	if inventario == null or _icones.is_empty():
		return
	for i in InventarioMinecraft.TOTAL:
		var p := inventario.pilha(i)
		var id := InventarioMinecraft.id_de(p)
		_icones[i].texture = _textura_de(id) if id != "" else (RegrasDeItens.fantasma(FANTASMAS[i]) if FANTASMAS.has(i) else null)
		_icones[i].tooltip_text = ""
		_numeros[i].text = str(p.quantidade) if id != "" and p.quantidade > 1 else ""
		if id != "" and _icones[i].texture == null:         # sem arte: a inicial do nome, para o slot não parecer vazio
			_numeros[i].text = _nome_de(id).substr(0, 3) + ("" if p.quantidade <= 1 else " " + str(p.quantidade))
	var c := inventario.cursor
	var cid := InventarioMinecraft.id_de(c)
	_cursor_icone.texture = _textura_de(cid) if cid != "" else null
	_cursor_numero.text = str(c.quantidade) if cid != "" and c.quantidade > 1 else ""
	_cursor.visible = cid != ""
	_atualizar_dica()
	queue_redraw()


func _textura_de(id: String) -> Texture2D:
	return ItensDoJogo.textura(id, progressao) if ItensDoJogo.e_do_jogo(id) else RegrasDeItens.icone(id)


func _nome_de(id: String) -> String:
	return ItensDoJogo.nome(id, progressao) if ItensDoJogo.e_do_jogo(id) else RegrasDeItens.nome(id)


func slot_em(p: Vector2) -> int:
	var local := p / float(escala)
	for i in InventarioMinecraft.TOTAL:
		var o := _posicoes[i]
		if local.x >= o.x - 1 and local.x < o.x + 17 and local.y >= o.y - 1 and local.y < o.y + 17:
			return i
	return -1


func _draw() -> void:
	var e := escala
	var u := maxf(1.0, e)                                       # 1 "pixel lógico" na tela, nunca menos de 1 px
	var todo := Rect2(Vector2.ZERO, Vector2(LARGURA, ALTURA) * e)
	draw_rect(todo, FUNDO)
	draw_rect(todo.grow(-u), Color(OURO, 0.55), false, u)            # moldura de latão
	draw_rect(todo.grow(-3.0 * e), Color(OURO, 0.16), false, u)      # filete interno
	for canto in [Vector2(3, 3), Vector2(LARGURA - 3, 3), Vector2(3, ALTURA - 3), Vector2(LARGURA - 3, ALTURA - 3)]:
		draw_rect(Rect2(canto * e - Vector2.ONE * 1.5 * e, Vector2.ONE * 3.0 * e), OURO)      # rebites
	var previa := Rect2(PREVIA.position * e, PREVIA.size * e)
	draw_rect(previa.grow(u), Color(OURO, 0.5), false, u)
	# a hotbar ganha uma faixa e um filete: é a "barra" do jogo, não mais uma fileira de mochila
	draw_rect(Rect2(Vector2(5, 135) * e, Vector2(LARGURA - 10, 22) * e), Color(OURO, 0.07))
	draw_line(Vector2(6, 134) * e, Vector2(LARGURA - 6, 134) * e, Color(OURO, 0.4), u)
	# seta da fabricação: grade → resultado
	var seta := PackedVector2Array([Vector2(106, 49) * e, Vector2(116, 53) * e, Vector2(106, 57) * e])
	draw_colored_polygon(seta, Color(OURO, 0.8))
	for i in InventarioMinecraft.TOTAL:
		var o := _posicoes[i] * e
		var fundo := FUNDO_DO_SLOT
		var borda := Color(OURO, 0.22)
		if i == InventarioMinecraft.RESULTADO:
			fundo = FUNDO_DO_RESULTADO
			borda = Color(OURO, 0.7)
		elif i >= InventarioMinecraft.ARMADURA_INI and i < InventarioMinecraft.ARMADURA_FIM or i == InventarioMinecraft.MAO_SECUNDARIA:
			fundo = FUNDO_DO_EQUIPAMENTO
			borda = Color(0.5, 0.68, 1.0, 0.45)
		draw_rect(Rect2(o - Vector2.ONE * e, Vector2(18, 18) * e), fundo)
		draw_rect(Rect2(o - Vector2.ONE * e, Vector2(18, 18) * e), borda, false, u)
		draw_rect(Rect2(o - Vector2.ONE * e, Vector2(18, 2) * e), Color(0, 0, 0, 0.35))      # sombra de cima: o slot parece afundado
	if _sobre >= 0:
		draw_rect(Rect2(_posicoes[_sobre] * e, Vector2(16, 16) * e), COR_DE_DESTAQUE)
	var sel := InventarioMinecraft.HOTBAR_INI + (inventario.selecionado if inventario != null else 0)
	draw_rect(Rect2(_posicoes[sel] * e - Vector2.ONE * e, Vector2(18, 18) * e), Color(OURO, 1.0), false, maxf(1.0, e))


func _gui_input(e: InputEvent) -> void:
	if inventario == null:
		return
	if e is InputEventMouseMotion:
		_sobre = slot_em((e as InputEventMouseMotion).position)
		_cursor.global_position = get_global_mouse_position()
		_atualizar_dica()
		queue_redraw()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var b := e as InputEventMouseButton
		var i := slot_em(b.position)
		if i < 0:
			return
		if b.button_index == MOUSE_BUTTON_LEFT:
			inventario.clique(i, 0, b.shift_pressed)
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			var tag := InventarioMinecraft.id_de(inventario.pilha(i))
			if progressao != null and ItensDeFruta.e_akuma(tag) and inventario.cursor.isEmpty():
				_comer_akuma(tag)             # 25/11/2026: botão direito numa Akuma come (como no jogo); com fruta no corpo, 2 cliques
			else:
				inventario.clique(i, 1, b.shift_pressed)
		accept_event()
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9 and _sobre >= 0:
			inventario.trocar_com_hotbar(_sobre, int(k) - int(KEY_1))
			accept_event()


signal avisou(texto: String)
var _confirma_id := ""
var _confirma_ate := 0


func _comer_akuma(tag: String) -> void:
	var agora := Time.get_ticks_msec()
	var r := ItensDeFruta.comer(progressao, tag, _confirma_id == tag and agora < _confirma_ate)
	_confirma_id = tag if r.estado == "confirmar" else ""
	_confirma_ate = agora + 4000
	avisou.emit(str(r.texto))


func _process(_d: float) -> void:
	if _cursor != null and _cursor.visible:
		_cursor.global_position = get_global_mouse_position()
	if _dica != null and _dica.visible:
		_dica.global_position = get_global_mouse_position() + Vector2(16, -8)


func _atualizar_dica() -> void:
	if _dica == null:
		return
	var vazio := inventario == null or not inventario.cursor.isEmpty() or _sobre < 0 or inventario.pilha(_sobre).isEmpty()
	_dica.visible = not vazio
	if not vazio:
		var id := InventarioMinecraft.id_de(inventario.pilha(_sobre))
		_dica.text = _nome_de(id) + ("" if ItensDoJogo.e_do_jogo(id) else "\n" + id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree() and inventario != null:
		inventario.fechar()              # fechar a janela devolve o cursor e a grade à mochila (como o Minecraft)
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree() and _previa != null and _previa.modelo == null:
		_previa.remontar()
