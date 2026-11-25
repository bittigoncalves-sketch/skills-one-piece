class_name BarraDeItensHud
extends Control
# ============================================================================
#  HOTBAR DO INVENTÁRIO (1–9) — centro inferior do Modo História.
#  10/11/2026, pedido do dono: a barra experimental (1 2 3 4 5…) vira a HOTBAR do inventário estilo Minecraft. Os 9 slots são os slots 36–44 do
#  `InventarioMinecraft`; os itens numerados do jogo (luta, fruta, espada, vara, machado, água, comida, pokébola, bandeira) são itens `jogo:*` do inventário.
#  A tecla 1–9 escolhe o SLOT (como no Minecraft); arrastar o item na janela (E) muda o número. Luta/fruta/… continuam sendo ativados pela
#  `ProgressaoDoPersonagem.ativar_item` (UM ativo por vez; apertar o ativo de novo solta = mãos livres); item comum do inventário vai para a MÃO do jogador
#  (equipamento da camada Minecraft). A textura do Mojang é local (`assets/minecraft_local`); sem ela a barra desenha um painel próprio.
#  Só MOSTRA e PEDE: o que existe mora na progressão e no inventário.
# ============================================================================

signal trocou(id: String)

const ESCALA := 3
const TEXTURA := "res://assets/minecraft_local/gui/widgets.png"
const LARGURA_VANILLA := 182
const ALTURA_VANILLA := 22
const MARGEM := 14.0
const LADO := float(ALTURA_VANILLA * ESCALA)       # altura da barra (o `TecnicasHud` se posiciona acima dela)
const SLOTS := 9
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "barra"

var progressao: ProgressaoDoPersonagem
var _fundo: TextureRect
var _selecao: TextureRect
var _icones: Array[TextureRect] = []
var _numeros: Array[Label] = []
var _quantidades: Array[Label] = []
var _nome: Label
var _tem_textura := false
const TEMPO_DO_NOME := 2.0
const FADE_DO_NOME := 0.5
var _nome_t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_montar()


func _montar() -> void:
	for f in get_children():
		f.queue_free()
	_icones.clear()
	_numeros.clear()
	_quantidades.clear()
	var largura := LARGURA_VANILLA * ESCALA
	var altura := ALTURA_VANILLA * ESCALA
	custom_minimum_size = Vector2(largura, altura + 22.0)
	offset_left = -largura * 0.5
	offset_right = largura * 0.5
	offset_top = -(altura + 22.0 + MARGEM)
	offset_bottom = -MARGEM
	_fundo = TextureRect.new()
	_fundo.name = "Fundo"
	_fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fundo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fundo.position = Vector2(0, 22)
	_fundo.size = Vector2(largura, altura)
	var real := ProjectSettings.globalize_path(TEXTURA)
	var tex: Texture2D = null
	var fundo_selecao: Texture2D = null
	if FileAccess.file_exists(real):
		var img := Image.load_from_file(real)
		if img != null and not img.is_empty():
			var base := ImageTexture.create_from_image(img)
			var a := AtlasTexture.new()
			a.atlas = base
			a.region = Rect2(0, 0, LARGURA_VANILLA, ALTURA_VANILLA)
			tex = a
			var s := AtlasTexture.new()
			s.atlas = base
			s.region = Rect2(0, 22, 24, 24)
			fundo_selecao = s
	_tem_textura = tex != null
	_fundo.texture = tex
	add_child(_fundo)
	for i in SLOTS:
		var origem := Vector2(3 + i * 20, 3) * ESCALA + Vector2(0, 22)
		var ic := TextureRect.new()
		ic.name = "Slot%d" % i
		ic.position = origem
		ic.size = Vector2(16, 16) * ESCALA
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(ic)
		_icones.append(ic)
		var n := EstiloDaHistoria.rotulo(str(i + 1), EstiloDaHistoria.TEXTO_2, 6 * ESCALA)       # o NÚMERO da tecla, sempre visível
		n.name = "Numero%d" % i
		n.position = origem + Vector2(1, -1)
		n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		n.add_theme_constant_override("outline_size", 4)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(n)
		_numeros.append(n)
		var q := EstiloDaHistoria.rotulo("", Color.WHITE, 6 * ESCALA)
		q.name = "Qtd%d" % i
		q.position = origem + Vector2(17 * ESCALA - 40, 9 * ESCALA)
		q.size = Vector2(40, 12 * ESCALA)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		q.add_theme_color_override("font_outline_color", Color(0.15, 0.15, 0.15))
		q.add_theme_constant_override("outline_size", 4)
		q.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(q)
		_quantidades.append(q)
	_selecao = TextureRect.new()
	_selecao.name = "Selecao"
	_selecao.texture = fundo_selecao
	_selecao.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selecao.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_selecao.size = Vector2(24, 24) * ESCALA
	_selecao.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_selecao)
	_nome = EstiloDaHistoria.rotulo("", EstiloDaHistoria.DOURADO, 14)
	_nome.name = "Nome"
	_nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nome.position = Vector2(0, 0)
	_nome.size = Vector2(largura, 20)
	_nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_nome)


## Sobe o nome do item (o vanilla o põe acima dos corações e do XP): `px` acima do topo da barra de slots.
func subir_nome(px: float) -> void:
	if _nome != null:
		_nome.position = Vector2(0, 22.0 - px)


func _process(delta: float) -> void:
	if _nome == null:
		return
	_nome_t = maxf(_nome_t - delta, 0.0)
	_nome.modulate.a = clampf(_nome_t / FADE_DO_NOME, 0.0, 1.0)


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	prog.mudou.connect(atualizar)
	prog.itens_do_mod_mudaram.connect(atualizar)
	if is_inside_tree() and _icones.is_empty():
		_montar()
	atualizar()


## Os ids dos itens do jogo que estão na hotbar, na ordem dos slots.
func itens() -> Array[String]:
	return progressao.itens_da_barra() if progressao != null else ([] as Array[String])


## O slot (0–8) destacado: o do item do jogo ativo; sem item ativo, o slot selecionado do inventário.
func slot_destacado() -> int:
	if progressao == null:
		return 0
	var ativo := progressao.item_em_uso()
	if ativo == "espada":
		# a espada na mão pode estar num slot `jogo:espada` OU num `ef:<arma>`: vale o slot selecionado, se for um dos dois
		var sel := progressao.inventario.selecionado
		var no_sel := InventarioMinecraft.id_de(progressao.inventario.pilha(InventarioMinecraft.HOTBAR_INI + sel))
		if no_sel == ItensDoJogo.tag("espada") or (ItensEpicFight.e_de(no_sel) and ItensEpicFight.lamina_do_item(no_sel) == progressao.lamina_ef):
			return sel
	if ativo != "":
		var s := progressao.slot_da_barra(ativo)
		if s >= 0:
			return s
	return progressao.inventario.selecionado


## Tecla 1–9 (0–8 aqui) = o SLOT. Devolve true se havia item nele.
func escolher(slot: int) -> bool:
	if progressao == null or slot < 0 or slot >= SLOTS:
		return false
	var inv := progressao.inventario
	var p := inv.pilha(InventarioMinecraft.HOTBAR_INI + slot)
	if p.isEmpty():
		return false
	var id := InventarioMinecraft.id_de(p)
	inv.selecionado = slot
	if ItensDoJogo.e_do_jogo(id):
		if not progressao.ativar_item(ItensDoJogo.id_de(id), false):      # a tecla só ATIVA: apertar o mesmo número de novo não desliga o item
			return false
		trocou.emit(progressao.item_em_uso())
	elif ItensEpicFight.e_de(id):
		if not _empunhar_arma_ef(id):
			return false
		trocou.emit(progressao.item_em_uso())
	else:
		# item comum do inventário na mão: nenhum item do jogo ativo (mãos livres para o combate base); o equipamento da camada Minecraft segue o slot
		progressao.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
		progressao.mudou.emit()
		inv.mudou.emit()
		trocou.emit("")
	return true


## Seleciona o slot (0–8) como o Minecraft: vale mesmo VAZIO e não alterna. Item do jogo que o personagem tem fica ativo; qualquer outra coisa
## (bloco, slot vazio) deixa as mãos livres, com o slot selecionado na mão. Só mexe na seleção/ativo; o resto segue pela progressão.
func selecionar(slot: int) -> void:
	if progressao == null:
		return
	slot = posmod(slot, SLOTS)
	var inv := progressao.inventario
	inv.selecionado = slot
	var id := InventarioMinecraft.id_de(inv.pilha(InventarioMinecraft.HOTBAR_INI + slot))
	if ItensDoJogo.e_do_jogo(id) and progressao.itens_da_barra().has(ItensDoJogo.id_de(id)):
		progressao.item_ativo = ItensDoJogo.id_de(id)
	elif ItensEpicFight.e_de(id) and _empunhar_arma_ef(id):
		pass                                       # a arma do Epic Fight do slot foi para a mão (`equipar_lamina` já deixou "espada" ativa)
	else:
		progressao.item_ativo = ProgressaoDoPersonagem.NENHUM_ITEM
	progressao.mudou.emit()
	inv.mudou.emit()
	trocou.emit(progressao.item_em_uso())


## Arma do Epic Fight no slot: equipa a lâmina (o mesmo caminho da aba ARMAS). Falso se o personagem não tem a arma (quebrou).
func _empunhar_arma_ef(id: String) -> bool:
	var lamina := ItensEpicFight.lamina_do_item(id)
	if lamina == "" or not progressao.equipar_lamina(lamina, true):
		return false
	return true


## A roda do mouse (`Inventory.swapPaint`): `sinal` > 0 é a roda PARA CIMA e anda um slot para a ESQUERDA (selected −= signum), com volta de 9 a 1.
func rolar(sinal: float) -> void:
	if progressao == null or is_zero_approx(sinal):
		return
	selecionar(slot_destacado() - int(signf(sinal)))


func nome_do_item(id: String) -> String:
	return ItensDoJogo.nome(id, progressao)


func icone_do_item(id: String) -> String:
	return ItensDoJogo.caminho_do_icone(id, progressao)


func atualizar() -> void:
	if progressao == null or _icones.is_empty():
		return
	var inv := progressao.inventario
	var destacado := slot_destacado()
	for i in SLOTS:
		var p := inv.pilha(InventarioMinecraft.HOTBAR_INI + i)
		var id := InventarioMinecraft.id_de(p)
		var jogo := ItensDoJogo.e_do_jogo(id)
		_icones[i].texture = (ItensDoJogo.textura(id, progressao) if jogo else RegrasDeItens.icone(id)) if id != "" else null
		var ativo := i == destacado
		_icones[i].modulate = Color.WHITE if (ativo or id == "") else Color(1, 1, 1, 0.7)
		_numeros[i].add_theme_color_override("font_color", EstiloDaHistoria.DOURADO if ativo else EstiloDaHistoria.TEXTO_2)
		var q := ""
		if jogo and (id == ItensDoJogo.tag("comida") or id == ItensDoJogo.tag("agua")):
			var provisoes := preload("res://src/historia/tripulantes/provisoes.gd")
			q = str(provisoes.quantidade_comida(progressao) if id == ItensDoJogo.tag("comida") else provisoes.quantidade_agua(progressao))
		elif not jogo and p.quantidade > 1:
			q = str(p.quantidade)
		_quantidades[i].text = q
		if id != "" and _icones[i].texture == null:         # sem arte: a inicial do nome, para o slot não parecer vazio
			_quantidades[i].text = (ItensDoJogo.nome(id) if jogo else RegrasDeItens.nome(id)).substr(0, 3)
	_selecao.position = Vector2(-1 + destacado * 20, -1) * ESCALA + Vector2(0, 22)
	_selecao.visible = _tem_textura
	var item_ativo := inv.pilha(InventarioMinecraft.HOTBAR_INI + destacado)
	var ativo_id := InventarioMinecraft.id_de(item_ativo)
	var texto := "" if ativo_id == "" or (ItensDoJogo.e_do_jogo(ativo_id) and progressao.item_em_uso() == "") \
		else (ItensDoJogo.nome(ativo_id, progressao) if ItensDoJogo.e_do_jogo(ativo_id) else RegrasDeItens.nome(ativo_id))
	# `Gui.toolHighlightTimer`: o nome do item da mão aparece 2 s quando ele MUDA e some (apagando nos últimos 0,5 s).
	if texto != _nome.text:
		_nome_t = TEMPO_DO_NOME if texto != "" else 0.0
	_nome.text = texto
	queue_redraw()
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


func _draw() -> void:
	if not _tem_textura:           # sem a textura local: painel próprio no mesmo layout
		var topo := 22.0
		draw_rect(Rect2(Vector2(0, topo), Vector2(LARGURA_VANILLA, ALTURA_VANILLA) * ESCALA), Color(0.1, 0.1, 0.1, 0.8))
		for i in SLOTS:
			draw_rect(Rect2(Vector2(3 + i * 20, 3) * ESCALA + Vector2(0, topo), Vector2(16, 16) * ESCALA), Color(0.3, 0.3, 0.3, 0.9))
		var d := slot_destacado()
		draw_rect(Rect2(Vector2(1 + d * 20, 1) * ESCALA + Vector2(0, topo), Vector2(20, 20) * ESCALA), EstiloDaHistoria.DOURADO, false, 3)
