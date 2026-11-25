extends Control
## Mesma leitura da pesca: faixa verde e traço branco, sem porcentagens.
var valor := 0.0
var zona := Vector2(0.35, 0.65)
var acertos := 0
var subindo := true

func _ready() -> void:
	custom_minimum_size = Vector2(104, 190)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func atualizar(posicao: float, faixa: Vector2, feitos: int, sobe: bool) -> void:
	valor = posicao
	zona = faixa
	acertos = feitos
	subindo = sobe
	queue_redraw()

func _draw() -> void:
	var x := size.x * 0.5 - 14
	var y := 16.0
	var altura := size.y - 48
	var caixa := Rect2(x, y, 28, altura)
	draw_rect(caixa.grow(3), Color("091920"))
	draw_rect(caixa, Color("34414b"))
	draw_rect(Rect2(x, y + altura * (1 - zona.y), 28, altura * (zona.y - zona.x)), Color("40b968"))
	for limite in [zona.x, zona.y]:
		draw_line(Vector2(x - 3, y + altura * (1 - limite)), Vector2(x + 31, y + altura * (1 - limite)), Color("b0efbc"), 1)
	var traco_y := y + altura * (1 - valor)
	draw_rect(Rect2(x - 6, traco_y - 2, 40, 4), Color.WHITE)
	var sinal := -1.0 if subindo else 1.0
	draw_colored_polygon(PackedVector2Array([Vector2(x + 44, traco_y + sinal * 5), Vector2(x + 40, traco_y - sinal * 3), Vector2(x + 48, traco_y - sinal * 3)]), Color.WHITE)
	for i in 3:
		draw_circle(Vector2(size.x * 0.5 + (i - 1) * 18, size.y - 12), 4, EstiloDaHistoria.DOURADO if i < acertos else Color("34414b"))
