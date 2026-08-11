class_name AmmoHud
extends Control
# ============================================================================
#  MUNIÇÃO NA TELA — canto inferior direito.
#
#  A munição é a PENALIDADE da Buki Buki no Mi; penalidade que o jogador não vê
#  não existe. Aparece só quando há arma empunhada e some junto com ela.
#
#  POR QUE AQUI, e não numa das duas HUDs que já existiam:
#   • `StatusEffectsHud` é canto SUPERIOR direito e já divide o espaço com o
#     placar da partida (MatchHud). Munição é informação de mira, precisa ficar
#     perto do centro-baixo da tela, não no topo.
#   • `SkillBar` é canto inferior ESQUERDO e lista os quatro slots; enfiar o
#     contador lá misturaria "o que eu posso sacar" com "quanto me resta".
#  Inferior DIREITO é a convenção de FPS e é o único canto livre da tela.
#
#  Do StatusEffectsHud vem o padrão que EU REUSO: ícone DESENHADO no `_draw`
#  (sem .png que possa não importar num clone) e `Player.local_player()` para
#  achar o jogador — `get_first_node_in_group("player")` devolve o corpo do HOST
#  quando se está no cliente (bug real, docs/erros.md 2026-08-10).
# ============================================================================

const PlayerScript := preload("res://Player.gd")

const LARGURA := 250.0
const ALTURA := 78.0
const MARGEM := 20.0

var _painel: Control
var _icone: ArmaIcone
var _nome: Label
var _contador: Label
var _pentes: PenteDeBalas

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir()
	visible = false

func _process(_dt: float) -> void:
	var eu := PlayerScript.local_player(get_tree())
	if eu == null or not eu.has_method("buki_arma"):
		visible = false
		return
	var slot: String = str(eu.call("buki_arma"))
	if slot == "":
		visible = false
		return

	var balas: int = int(eu.call("buki_municao"))
	var total: int = maxi(int(eu.call("buki_municao_max")), 1)
	visible = true
	_painel.position = Vector2(size.x - LARGURA - MARGEM, size.y - ALTURA - MARGEM)

	_icone.slot = slot
	_icone.queue_redraw()
	_nome.text = "[%s] %s" % [slot, BukiFX.nome_da_arma(slot).to_upper()]
	_contador.text = "%d / %d" % [balas, total]
	# Vermelho no último terço: é o aviso de que o rodízio de armas vem aí.
	var apertado := float(balas) / float(total) <= 0.34
	_contador.add_theme_color_override("font_color",
		Color(1.0, 0.35, 0.30) if apertado else Color(1, 1, 1))
	_pentes.balas = balas
	_pentes.total = total
	_pentes.cor = Color(1.0, 0.35, 0.30) if apertado else Color(1.0, 0.82, 0.35)
	_pentes.queue_redraw()

# ------------------------------------------------------------------ construção
func _construir() -> void:
	_painel = ColorRect.new()
	(_painel as ColorRect).color = Color(0, 0, 0, 0.55)
	_painel.size = Vector2(LARGURA, ALTURA)
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painel)

	_icone = ArmaIcone.new()
	_icone.position = Vector2(12, 14)
	_icone.size = Vector2(48, 48)
	_icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(_icone)

	_nome = _texto(Vector2(70, 8), 15, Color(0.85, 0.90, 0.96))
	_contador = _texto(Vector2(70, 26), 30, Color(1, 1, 1))

	_pentes = PenteDeBalas.new()
	_pentes.position = Vector2(70, ALTURA - 16)
	_pentes.size = Vector2(LARGURA - 84, 8)
	_pentes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(_pentes)

func _texto(pos: Vector2, tam: int, cor: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_painel.add_child(l)
	return l


# ============================================================================
#  SILHUETA DA ARMA — desenhada, uma por slot. O jogador reconhece o que está na
#  mão pelo canto do olho, sem ler o nome.
# ============================================================================
class ArmaIcone extends Control:
	var slot: String = "Z"
	const ACO := Color(0.80, 0.84, 0.90)
	const ESCURO := Color(0.45, 0.48, 0.54)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		match slot:
			"Z":   # pistola: cano curto + coronha
				draw_rect(Rect2(w * 0.14, h * 0.34, w * 0.62, h * 0.16), ACO)
				draw_rect(Rect2(w * 0.20, h * 0.50, w * 0.18, h * 0.30), ESCURO)
			"X":   # canhão: tubo grosso com a boca alargada
				draw_rect(Rect2(w * 0.12, h * 0.36, w * 0.62, h * 0.28), ACO)
				draw_rect(Rect2(w * 0.70, h * 0.28, w * 0.16, h * 0.44), ESCURO)
			"C":   # sniper: cano LONGO e fino + luneta em cima
				draw_rect(Rect2(w * 0.06, h * 0.44, w * 0.86, h * 0.10), ACO)
				draw_rect(Rect2(w * 0.34, h * 0.28, w * 0.30, h * 0.10), ESCURO)
				draw_rect(Rect2(w * 0.14, h * 0.54, w * 0.16, h * 0.24), ESCURO)
			_:     # minigun: feixe de canos
				for i in 3:
					draw_rect(Rect2(w * 0.16, h * (0.28 + i * 0.16), w * 0.66, h * 0.08), ACO)
				draw_rect(Rect2(w * 0.06, h * 0.24, w * 0.10, h * 0.44), ESCURO)


# ============================================================================
#  O PENTE — um risquinho por bala enquanto couber; virou barra quando não cabe
#  (o minigun tem 100). Ver as balas SUMIREM uma a uma é o que faz a penalidade
#  ser sentida; com 100 o que importa é a proporção.
# ============================================================================
class PenteDeBalas extends Control:
	var balas: int = 0
	var total: int = 1
	var cor: Color = Color(1.0, 0.82, 0.35)

	func _draw() -> void:
		if total <= 0:
			return
		if total <= 20:
			var passo := size.x / float(total)
			var largura := maxf(passo - 3.0, 2.0)
			for i in total:
				var c: Color = cor if i < balas else Color(1, 1, 1, 0.14)
				draw_rect(Rect2(i * passo, 0.0, largura, size.y), c)
		else:
			draw_rect(Rect2(0, 0, size.x, size.y), Color(1, 1, 1, 0.14))
			draw_rect(Rect2(0, 0, size.x * clampf(float(balas) / float(total), 0.0, 1.0), size.y), cor)
