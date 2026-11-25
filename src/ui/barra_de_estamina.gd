class_name BarraDeEstamina
extends Control
## Barra de ESTAMINA (Epic Fight, 10/11/2026) acima da barra de itens. Só mostra: a conta mora em `Estamina`.
## Aparece quando a estamina não está cheia (e some 1,5 s depois de encher), para não poluir a tela.
const LARGURA := 220.0
const ALTURA := 9.0
const ACIMA_DA_BARRA := 96.0       # barra de itens: 58 + margem 14 + folga
const COR_CHEIA := Color(0.35, 0.85, 0.45)
const COR_BAIXA := Color(0.95, 0.35, 0.25)
var _visivel_ate := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	name = "BarraDeEstamina"

func _process(_delta: float) -> void:
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador == null:
		return
	var e := Estamina.de(jogador)
	var agora := Time.get_ticks_msec() / 1000.0
	if e.fracao() < 0.999:
		_visivel_ate = agora + 1.5
	visible = agora < _visivel_ate
	if visible:
		queue_redraw()

func _draw() -> void:
	var jogador := get_tree().get_first_node_in_group("player")
	if jogador == null:
		return
	var e := Estamina.de(jogador)
	var x := (size.x - LARGURA) * 0.5
	var y := size.y - ACIMA_DA_BARRA
	draw_rect(Rect2(x - 2, y - 2, LARGURA + 4, ALTURA + 4), Color(0, 0, 0, 0.55))
	var f := e.fracao()
	draw_rect(Rect2(x, y, LARGURA * f, ALTURA), COR_BAIXA.lerp(COR_CHEIA, minf(f * 1.6, 1.0)))
	# marca o custo da esquiva (4 de 15), para o jogador ver quanto sobra
	var marca := x + LARGURA * (e.custo("roll") / e.maximo)
	draw_line(Vector2(marca, y - 2), Vector2(marca, y + ALTURA + 2), Color(1, 1, 1, 0.8), 1.0)
