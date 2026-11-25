class_name MatchHud
extends Control
# ============================================================================
#  HUD DA RODADA — cronômetro (topo-direito), tabela de kills/mortes e o painel
#  de pódio no fim dos 10 minutos.
#
#  Só LÊ o `Scoreboard` (grupo "scoreboard"); não decide nada. Quem conta é o
#  servidor — ver src/match/Scoreboard.gd.
#
#  A tabela é feita de três Labels em coluna (nome / K / M) em vez de um Label
#  só com espaços: a fonte do projeto não é monoespaçada, então texto alinhado
#  "na mão" desalinha assim que alguém tem placar de dois dígitos.
# ============================================================================

const PANEL_W := 300.0
const MARGIN := 20.0
const ROW_H := 26.0
const COL_NOME := 14.0
const COL_K := 190.0
const COL_M := 244.0
const RELOGIO_W := 150.0    # caixa do cronômetro, centrada no topo
const RELOGIO_H := 46.0

var _painel: Panel
var _relogio: Label
var _cab: Label
var _nomes: Label
var _kills: Label
var _mortes: Label

var _podio: Panel
var _podio_titulo: Label
var _podio_lista: Label
var _podio_rodape: Label

func _ready() -> void:
	# ⚠️ `set_anchors_preset` sozinho NÃO mexe nos offsets: ele recalcula para
	# MANTER o retângulo atual, que aqui era (0,0). Com tamanho zero, toda âncora
	# de filho resolve contra zero — o painel do placar ia parar em x = −320
	# (fora da tela, pela esquerda) e o cronômetro em x = −75, em cima da barra
	# de vida.
	#
	# Medido em 2026-08-12 por print do jogo rodando: `MatchHud.size = (0, 0)`.
	# O painel de kills/mortes nunca apareceu na tela por causa disto.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_painel()
	_build_podio()

func _process(_dt: float) -> void:
	var sb := get_tree().get_first_node_in_group("scoreboard")
	if sb == null:
		_painel.visible = false
		_podio.visible = false
		return
	_painel.visible = true
	# Na enchente o cronômetro já está em 00:00 e não diz mais nada — quem manda
	# na rodada passa a ser a água, então é a altura dela que aparece no lugar.
	if bool(sb.get("flooding")):
		_relogio.text = "🌊  ALAGANDO  %.0f m" % maxf(float(sb.get("flood_y")), 0.0)
		_relogio.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	else:
		_relogio.text = "⏱  " + _mmss(sb.time_left)
		# Últimos 30 s em vermelho: o fim da rodada tem que ser sentido, não lido.
		_relogio.add_theme_color_override("font_color",
			Color(1.0, 0.4, 0.35) if sb.time_left <= 30.0 else Color(1.0, 0.95, 0.7))

	var meu := _meu_peer()
	var nomes := ""
	var ks := ""
	var ms := ""
	for linha in sb.ranking():
		nomes += _nome(int(linha[0]), meu) + "\n"
		ks += "%d\n" % int(linha[1])
		ms += "%d\n" % int(linha[2])
	_nomes.text = nomes
	_kills.text = ks
	_mortes.text = ms
	_painel.size.y = 74.0 + maxf(float(sb.ranking().size()), 1.0) * ROW_H

	_atualiza_podio(sb, meu)

# ------------------------------------------------------------------- pódio
func _atualiza_podio(sb: Node, meu: int) -> void:
	var ativo: bool = sb.has_method("in_podium") and sb.in_podium()
	_podio.visible = ativo
	if not ativo:
		return
	var lista: Array = sb.podium_snapshot
	var txt := ""
	for i in lista.size():
		var l: Array = lista[i]
		var medalha: String = ["🥇", "🥈", "🥉"][i] if i < 3 else "   "
		txt += "%s  %-12s  %d kills   %d mortes\n" % [medalha, _nome(int(l[0]), meu), int(l[1]), int(l[2])]
	if txt == "":
		txt = "ninguém pontuou nesta rodada\n"
	_podio_lista.text = txt
	_podio_rodape.text = "próxima partida em %d s" % int(ceil(sb.podium_left))

# ------------------------------------------------------------------ helpers
func _meu_peer() -> int:
	return multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1

func _nome(peer: int, meu: int) -> String:
	return "Você" if peer == meu else "Jogador %d" % peer

func _mmss(segundos: float) -> String:
	var s := int(maxf(segundos, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]

# ------------------------------------------------------------- construção
func _build_painel() -> void:
	_painel = Panel.new()
	_painel.add_theme_stylebox_override("panel", Estilo.painel())
	_painel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_painel.position = Vector2(-PANEL_W - MARGIN, MARGIN)
	_painel.size = Vector2(PANEL_W, 100)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painel)

	_cab = _texto(_painel, Vector2(COL_NOME, 44), 15, Color(0.72, 0.78, 0.9))
	_cab.text = "JOGADOR"
	var ck := _texto(_painel, Vector2(COL_K, 44), 15, Color(0.72, 0.78, 0.9))
	ck.text = "K"
	var cm := _texto(_painel, Vector2(COL_M, 44), 15, Color(0.72, 0.78, 0.9))
	cm.text = "M"

	_nomes = _texto(_painel, Vector2(COL_NOME, 68), 18, Color(1, 1, 1))
	_kills = _texto(_painel, Vector2(COL_K, 68), 18, Color(0.45, 1.0, 0.55))
	_mortes = _texto(_painel, Vector2(COL_M, 68), 18, Color(1.0, 0.55, 0.5))

	# ---------------------------------------------------- CRONÔMETRO, no CENTRO
	# Ele saiu de dentro do painel do placar (que fica no canto superior direito)
	# e virou elemento próprio: o tempo restante é a informação que TODO mundo
	# olha o tempo inteiro, e no canto ela disputa espaço com a tabela.
	#
	# Ancorado em `PRESET_CENTER_TOP` com `pivot` no meio: assim ele continua
	# centrado em qualquer resolução, inclusive quando a janela é redimensionada.
	# Fase 6: mesma borda das barras e do contorno 3D — ver `Estilo.painel()`.
	var caixa := Panel.new()
	caixa.add_theme_stylebox_override("panel", Estilo.painel())
	caixa.set_anchors_preset(Control.PRESET_CENTER_TOP)
	caixa.size = Vector2(RELOGIO_W, RELOGIO_H)
	caixa.position = Vector2(-RELOGIO_W * 0.5, MARGIN)
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caixa)

	_relogio = _texto(caixa, Vector2.ZERO, 34, Color(1.0, 0.95, 0.7))
	_relogio.size = caixa.size
	_relogio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_relogio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_relogio.text = "⏱  05:00"

func _build_podio() -> void:
	_podio = Panel.new()
	_podio.add_theme_stylebox_override("panel", Estilo.painel())
	_podio.set_anchors_preset(Control.PRESET_CENTER)
	_podio.size = Vector2(520, 300)
	_podio.position = Vector2(-260, -150)
	_podio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podio.visible = false
	add_child(_podio)

	_podio_titulo = _texto(_podio, Vector2(0, 22), 34, Color(1.0, 0.86, 0.35))
	_podio_titulo.text = "FIM DA RODADA"
	_podio_titulo.size.x = 520
	_podio_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_podio_lista = _texto(_podio, Vector2(48, 84), 21, Color(1, 1, 1))

	_podio_rodape = _texto(_podio, Vector2(0, 250), 19, Color(0.7, 0.85, 1.0))
	_podio_rodape.size.x = 520
	_podio_rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _texto(pai: Control, pos: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pai.add_child(l)
	return l
