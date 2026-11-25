class_name JanelaDeLoja
extends PanelContainer
# ============================================================================
#  JANELA DE LOJA (03/10/2026) — a loja do NPC com quem o jogador falou (E).
#
#  Mesmo estilo do inventário (N): cabeça com o nome do NPC, a fala dele, as moedas
#  (o ouro da campanha) e uma linha por item com os botões da loja. Só desenha: as
#  regras são da `LojaDeNpc`. Refaz as linhas a cada mudança do progresso.
#  Fecha no E ou no ESC (quem lê a tecla é a `HistoriaHud`).
# ============================================================================

signal aviso(texto: String)

const LARGURA := 620.0
const ALTURA_DA_LISTA := 380.0
## Respiro mínimo entre a janela e a borda da tela (px lógicos): a janela encolhe até caber com ele.
const MARGEM_DA_TELA := 16.0
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "loja"

var progressao: ProgressaoDoPersonagem
var biblioteca: BibliotecaDeModelos
var npc: Node = null
var loja: LojaDeNpc = null

var _titulo: Label
var _fala: Label
var _moedas: Label
var _lista: VBoxContainer
var _cabeca: PanelContainer
var _rolagem: ScrollContainer
## Quanto a janela cresce para a loja aberta (`LojaDeNpc.escala_da_ui`), 15/10/2026.
var _escala := 1.0
var _roleta: RoletaHud = null
var _ferraria: Control = null


func ligar(prog: ProgressaoDoPersonagem, bib: BibliotecaDeModelos) -> void:
	progressao = prog
	biblioteca = bib
	# Adiado: o clique de um botão muda o progresso, e refazer as linhas DENTRO do sinal
	# daquele botão tiraria o botão da árvore no meio da própria emissão.
	prog.mudou.connect(func(): atualizar.call_deferred())


func _ready() -> void:
	GuiMinecraft.aplicar(self)    # fonte, botões e painéis do Minecraft (12/11/2026); sem as texturas locais, não faz nada
	add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	custom_minimum_size = Vector2(LARGURA, 0)
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	_cabeca = EstiloDaHistoria.cabeca("LOJA", ["E", "ESC"] as Array[String])
	raiz.add_child(_cabeca)
	_titulo = _cabeca.find_children("*", "Label", true, false)[0] as Label
	var margem := MarginContainer.new()
	for lado in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(lado, 24)
	margem.add_theme_constant_override("margin_top", 12)
	margem.add_theme_constant_override("margin_bottom", 18)
	raiz.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 10)
	margem.add_child(coluna)
	var topo := HBoxContainer.new()
	coluna.add_child(topo)
	_fala = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 14)
	_fala.name = "Fala"
	_fala.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Largura mínima OBRIGATÓRIA com quebra automática: sem ela o primeiro layout mede o
	# texto com largura 0, quebra letra por letra e a janela nasce com 1.600 px de altura.
	_fala.custom_minimum_size = Vector2(LARGURA - 190, 0)
	_fala.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_fala)
	_moedas = EstiloDaHistoria.rotulo("", EstiloDaHistoria.DOURADO, 16)
	_moedas.name = "Moedas"
	topo.add_child(_moedas)
	var rolagem := ScrollContainer.new()
	_rolagem = rolagem
	rolagem.custom_minimum_size = Vector2(0, ALTURA_DA_LISTA)
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	_lista = VBoxContainer.new()
	_lista.name = "Lista"
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_theme_constant_override("separation", 8)
	rolagem.add_child(_lista)


## Abre a loja de `quem` (um `NpcDaIlha`).
func abrir(quem: Node) -> void:
	npc = quem
	loja = quem.call("loja") if quem != null else null
	_titulo.text = str(quem.call("nome")).to_upper() if quem != null else "LOJA"
	_fala.text = loja.fala() if loja != null else ""
	_escala = loja.escala_da_ui() if loja != null else 1.0
	custom_minimum_size = Vector2(LARGURA * _escala, 0)
	_rolagem.custom_minimum_size = Vector2(0, ALTURA_DA_LISTA * _escala)
	_fala.custom_minimum_size = Vector2((LARGURA - 190) * _escala, 0)
	_fala.add_theme_font_size_override("font_size", roundi(14 * _escala))
	_moedas.add_theme_font_size_override("font_size", roundi(16 * _escala))
	visible = true
	atualizar()
	_centralizar()
	# De novo depois do layout do quadro: as linhas novas só medem quando entram na árvore.
	_centralizar.call_deferred()


func _centralizar() -> void:
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)
	_caber_na_tela()


## 19/11/2026, pedido do dono (a loja do Barba Negra não cabia na tela): a janela NUNCA passa da tela — se o corpo é maior que a área útil, ela inteira encolhe
## (escala em torno do centro) até caber; se já cabe, fica em 1. Refeito quando a tela muda de tamanho.
func _caber_na_tela() -> void:
	if not is_inside_tree():
		return
	if not get_viewport().size_changed.is_connected(_centralizar):
		get_viewport().size_changed.connect(_centralizar)
	pivot_offset = size * 0.5
	var tela := get_viewport_rect().size
	var cabe := minf((tela.x - 2.0 * MARGEM_DA_TELA) / maxf(size.x, 1.0), (tela.y - 2.0 * MARGEM_DA_TELA) / maxf(size.y, 1.0))
	scale = Vector2.ONE * minf(1.0, cabe)


func fechar() -> void:
	_fechar_ferraria()
	if _roleta != null:
		_roleta.fechar()
	visible = false
	npc = null
	loja = null


## Clique de um botão (a janela e os testes passam por aqui).
func executar(acao: String, id: String) -> String:
	if loja == null or progressao == null:
		return ""
	var texto := loja.executar(progressao, biblioteca, acao, id)
	if not texto.is_empty():
		aviso.emit(texto)
	if loja.get_script().resource_path.ends_with("loja_do_ferreiro.gd") and loja.get("iniciar_ferraria") == true:
		loja.set("iniciar_ferraria", false)
		_abrir_ferraria()
	var giro := loja.consumir_giro()
	if not giro.is_empty():
		_girar_roleta(giro)
	if loja.fecha_a_janela():
		fechar()
	return texto


func atualizar() -> void:
	if not visible or loja == null or _lista == null:
		return
	_moedas.text = "%s" % LojaDeNpc.moedas(progressao.ouro)
	# A fala acompanha o momento: no NPC de missão ela muda ao aceitar/entregar (e, na
	# cadeia do Guarda, passa para a próxima missão com a janela aberta).
	_fala.text = loja.fala()
	for filho in _lista.get_children():
		_lista.remove_child(filho)
		filho.queue_free()
	for l: Dictionary in loja.linhas(progressao, biblioteca):
		_lista.add_child(_montar_linha(l))
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


## Uma opção: faixa de cor, símbolo, nome e detalhe, a etiqueta de preço e os botões.
## Os campos `cor`/`simbolo`/`preco` são opcionais (a linha de sempre continua igual).
func _montar_linha(l: Dictionary) -> PanelContainer:
	var e := _escala
	var cor: Color = l.get("cor", Color.TRANSPARENT)
	var faixa := EstiloDaHistoria.linha_de_lista()
	faixa.name = "Linha_" + (str(l["id"]) if not str(l["id"]).is_empty() else "vazia")
	if cor.a > 0.0:
		var st := faixa.get_theme_stylebox("panel") as StyleBoxFlat
		st.bg_color = Color(cor, 0.10)
		st.border_color = Color(cor, 0.9)
		st.border_width_left = roundi(5 * e)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", roundi(12 * e))
	faixa.add_child(linha)
	var imagem := str(l.get("imagem", ""))
	if not imagem.is_empty():
		var retrato := TextureRect.new()
		retrato.name = "Imagem"
		retrato.texture = load(imagem) as Texture2D
		retrato.custom_minimum_size = Vector2(64, 64) * e
		retrato.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		retrato.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		retrato.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		retrato.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_child(retrato)
	var simbolo := str(l.get("simbolo", ""))
	if not simbolo.is_empty():
		var s := SimboloDeLoja.novo(simbolo, cor if cor.a > 0.0 else EstiloDaHistoria.DOURADO, 40.0 * e)
		s.name = "Simbolo"
		linha.add_child(s)
	var textos := VBoxContainer.new()
	textos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	textos.add_theme_constant_override("separation", 0)
	linha.add_child(textos)
	var nome := EstiloDaHistoria.rotulo(str(l["nome"]), EstiloDaHistoria.TEXTO, roundi(16 * e))
	if not imagem.is_empty(): nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	textos.add_child(nome)
	if not str(l["detalhe"]).is_empty():
		# 19/11/2026: o detalhe QUEBRA LINHA. Sem isso a frase da roleta ("Comuns: Nami, Sanji… · restam 7 de 7") media ~800 px numa linha só e a janela do
		# Barba Negra nascia com mais de 1.300 px de largura, passando da tela — a escala 1,3 só piorava. A largura mínima evita a quebra letra por letra.
		var detalhe := EstiloDaHistoria.rotulo(str(l["detalhe"]), EstiloDaHistoria.TEXTO_2, roundi(13 * e))
		detalhe.name = "Detalhe"
		detalhe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detalhe.custom_minimum_size = Vector2(160.0 * e, 0)
		textos.add_child(detalhe)
	var preco := int(l.get("preco", -1))
	if preco >= 0:
		linha.add_child(_etiqueta_de_preco(preco, cor))
	for b: Dictionary in l["botoes"]:
		var acao := str(b["acao"])
		var id := str(l["id"])
		var botao := EstiloDaHistoria.botao(str(b["texto"]), func(): executar(acao, id), true)
		botao.name = "%s_%s" % [acao, id]
		botao.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		botao.add_theme_font_size_override("font_size", roundi(14 * e))
		botao.disabled = not bool(b.get("ativo", true))
		linha.add_child(botao)
	return faixa


## "Grátis" (verde) ou "100" com a moeda; apagada quando falta ouro para pagar.
func _etiqueta_de_preco(preco: int, cor: Color) -> PanelContainer:
	var e := _escala
	var gratis := preco == 0
	var sem_ouro := progressao != null and preco > progressao.ouro
	var tinta := Color(0.45, 0.85, 0.5) if gratis else (Color(0.9, 0.42, 0.4) if sem_ouro else EstiloDaHistoria.DOURADO)
	var chip := PanelContainer.new()
	chip.name = "Preco"
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(tinta, 0.14)
	st.border_color = Color(tinta, 0.8)
	st.set_border_width_all(1)
	st.set_corner_radius_all(12)
	st.content_margin_left = 12 * e
	st.content_margin_right = 12 * e
	st.content_margin_top = 3 * e
	st.content_margin_bottom = 3 * e
	chip.add_theme_stylebox_override("panel", st)
	var texto := EstiloDaHistoria.rotulo("Grátis" if gratis else LojaDeNpc.moedas(preco), tinta, roundi(15 * e))
	texto.name = "Valor"
	chip.add_child(texto)
	return chip


## A roleta do Barba Negra: a roda gira sobre a janela e mostra quem saiu.
func _girar_roleta(giro: Dictionary) -> void:
	if _roleta == null:
		_roleta = RoletaHud.new()
		_roleta.name = "Roleta"
		_roleta.top_level = true      # cobre a tela inteira, não só a janela da loja
		add_child(_roleta)
	_roleta.biblioteca = biblioteca
	_roleta.girar(giro)

func _abrir_ferraria() -> void:
	if _ferraria != null: return
	get_child(0).hide()
	_ferraria = preload("res://src/ui/FerrariaHud.gd").new()
	add_child(_ferraria)
	_ferraria.cancelou.connect(_fechar_ferraria)
	_ferraria.concluiu.connect(func():
		progressao.contar_abate("ferraria")
		progressao.entregar_missao("ferraria")
		aviso.emit("Machado recebido! Equipe em N → ARMAS e corte três árvores.")
		_fechar_ferraria.call_deferred())

func _fechar_ferraria() -> void:
	if is_instance_valid(_ferraria):
		_ferraria.set("ativa", false)
		remove_child(_ferraria)
		_ferraria.queue_free()
	_ferraria = null
	get_child(0).show()
	atualizar.call_deferred()
