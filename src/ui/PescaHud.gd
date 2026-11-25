class_name PescaHud
extends Control
# ============================================================================
#  HUD DA PESCA (03/10/2026) — o medidor da briga, à direita do centro da tela.
#
#  Duas barras verticais lado a lado, desenhadas aqui mesmo (`_draw`):
#    TENSÃO   — faixa verde = zona boa (`TensaoDaLinha.ZONA_MIN..MAX`), topo vermelho =
#               perto de arrebentar, traço branco = a tensão agora;
#    CAPTURA  — enche dourada enquanto a tensão fica no verde.
#  Em cima, a raridade do peixe fisgado; um "!" pisca no aviso de corrida (solte!)
#  e fica vermelho durante ela. Na mordida, um "!" grande no centro.
#  Só lê a `Pescaria`; não decide nada.
# ============================================================================

const LARGURA := 26.0
const ALTURA := 220.0
const ESPACO := 12.0
const DESLOCAMENTO := 150.0      # px à direita do centro da tela
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "pesca"
const COR_RARIDADE := {
	"comum": Color(0.85, 0.9, 0.92), "incomum": Color(0.45, 0.85, 0.5),
	"raro": Color(0.4, 0.65, 1.0), "lendario": Color(1.0, 0.62, 0.2),
}

var pescaria: Pescaria
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


func _process(delta: float) -> void:
	_t += delta
	var mostrar := pescaria != null and is_instance_valid(pescaria) \
		and pescaria.estado in [Pescaria.Estado.BRIGANDO, Pescaria.Estado.MORDENDO]
	if mostrar != visible:
		visible = mostrar
	if visible:
		queue_redraw()


func _draw() -> void:
	if pescaria == null:
		return
	var centro := size * 0.5
	var fonte := get_theme_default_font()
	if pescaria.estado == Pescaria.Estado.MORDENDO:
		var k := 1.0 + 0.15 * sin(_t * 30.0)
		_texto(fonte, "!", centro + Vector2(0, -70), int(64 * k), EstiloDaHistoria.DOURADO)
		return
	var l := pescaria.tensao
	if l == null:
		return
	var x0 := centro.x + DESLOCAMENTO
	var y0 := centro.y - ALTURA * 0.5
	# Tensão.
	var caixa := Rect2(x0, y0, LARGURA, ALTURA)
	draw_rect(caixa.grow(3), Color(0.02, 0.075, 0.09, 0.82))
	draw_rect(caixa, Color(0.15, 0.18, 0.2, 0.9))
	var y_de := func(v: float) -> float: return y0 + ALTURA * (1.0 - v)
	draw_rect(Rect2(x0, y_de.call(TensaoDaLinha.ZONA_MAX), LARGURA,
		ALTURA * (TensaoDaLinha.ZONA_MAX - TensaoDaLinha.ZONA_MIN)), Color(0.25, 0.8, 0.35, 0.85))
	draw_rect(Rect2(x0, y0, LARGURA, ALTURA * 0.1), Color(0.9, 0.2, 0.15, 0.85))
	var y_t: float = y_de.call(l.tensao)
	draw_rect(Rect2(x0 - 5, y_t - 2, LARGURA + 10, 4), Color.WHITE)
	# Captura.
	var x1 := x0 + LARGURA + ESPACO
	var barra := Rect2(x1, y0, LARGURA * 0.6, ALTURA)
	draw_rect(barra.grow(3), Color(0.02, 0.075, 0.09, 0.82))
	draw_rect(barra, Color(0.15, 0.18, 0.2, 0.9))
	draw_rect(Rect2(x1, y0 + ALTURA * (1.0 - l.progresso), barra.size.x, ALTURA * l.progresso), EstiloDaHistoria.DOURADO)
	# Raridade e aviso de corrida.
	var cor: Color = COR_RARIDADE.get(l.raridade, Color.WHITE)
	_texto(fonte, TabelaDePeixes.NOME_DA_RARIDADE.get(l.raridade, l.raridade).to_upper(),
		Vector2(x0 + (LARGURA + ESPACO + barra.size.x) * 0.5, y0 - 14), 14, cor)
	if l.correndo or (l.avisando and fmod(_t, 0.2) < 0.1):
		_texto(fonte, "!", Vector2(x0 - 22, y_t + 10), 30, Color(1, 0.25, 0.2) if l.correndo else EstiloDaHistoria.DOURADO)


func _texto(fonte: Font, texto: String, meio: Vector2, tamanho: int, cor: Color) -> void:
	var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
	var pos := meio - Vector2(largura * 0.5, -tamanho * 0.35)
	draw_string_outline(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, 5, Color(0, 0, 0, 0.85))
	draw_string(fonte, pos, texto, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho, cor)
