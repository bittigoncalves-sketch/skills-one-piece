class_name SimboloDeLoja
extends Control
# ============================================================================
#  SÍMBOLO DE LOJA (15/10/2026) — o ícone colorido de uma opção da loja, desenhado com
#  primitivas (sem fonte nem textura: o mesmo desenho em qualquer máquina).
#  `tipo`: cruz (retirar), pulo, dash, roleta, estrela. Desconhecido = losango.
# ============================================================================

var tipo := ""
var cor := Color.WHITE


static func novo(a_tipo: String, a_cor: Color, lado: float) -> SimboloDeLoja:
	var s := SimboloDeLoja.new()
	s.tipo = a_tipo
	s.cor = a_cor
	s.custom_minimum_size = Vector2(lado, lado)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return s


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	draw_circle(c, r, Color(cor, 0.16))
	draw_arc(c, r - 1.0, 0.0, TAU, 40, Color(cor, 0.85), 2.0, true)
	var k := r * 0.52
	var traco := maxf(r * 0.16, 2.0)
	match tipo:
		"cruz":
			draw_line(c + Vector2(-k, -k), c + Vector2(k, k), cor, traco, true)
			draw_line(c + Vector2(-k, k), c + Vector2(k, -k), cor, traco, true)
		"pulo":
			for dy in [-0.45, 0.25]:
				var y: float = c.y + k * float(dy)
				draw_polyline(PackedVector2Array([Vector2(c.x - k, y + k * 0.55), Vector2(c.x, y - k * 0.1),
					Vector2(c.x + k, y + k * 0.55)]), cor, traco, true)
		"dash":
			draw_line(c + Vector2(-k, 0), c + Vector2(k * 0.7, 0), cor, traco, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(k, 0), c + Vector2(k * 0.25, -k * 0.6),
				c + Vector2(k * 0.25, k * 0.6)]), cor)
		"roleta":
			# Três fatias (comum / incomum / lendário) e o pino no meio.
			var cores := [Color(0.72, 0.78, 0.84), Color(0.35, 0.78, 0.45), Color(0.98, 0.72, 0.18)]
			var angulos := [0.0, TAU * 0.5, TAU * 0.78, TAU]
			for i in 3:
				var pts := PackedVector2Array([c])
				var passos := 10
				for j in passos + 1:
					var a: float = lerpf(angulos[i], angulos[i + 1], float(j) / passos) - PI * 0.5
					pts.append(c + Vector2(cos(a), sin(a)) * k * 1.15)
				draw_colored_polygon(pts, cores[i])
			draw_circle(c, k * 0.28, Color(0.05, 0.1, 0.12))
		"estrela":
			var pts := PackedVector2Array()
			for i in 10:
				var raio := k * (1.2 if i % 2 == 0 else 0.5)
				var a := -PI * 0.5 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * raio)
			draw_colored_polygon(pts, cor)
		_:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, 0),
				c + Vector2(0, k), c + Vector2(-k, 0)]), cor)
