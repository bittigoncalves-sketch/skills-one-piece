class_name BarraHud
extends Control
# ============================================================================
#  A BARRA DO HUD — vida, energia, e o que mais vier.
#
#  Desenha um PARALELOGRAMO com contorno grosso, em vez do `ColorRect` chapado
#  que havia antes. Ver `Estilo` para o porquê de a linha ser a mesma do
#  contorno 3D.
#
#  ⚠️ É `_draw()` E NÃO NÓS FILHOS. A versão antiga era dois `ColorRect`
#  empilhados e a barra andava mudando `fill.size.x`. Retângulo não inclina, e
#  três nós por barra multiplicam por cada barra da tela. Aqui é uma chamada de
#  desenho por camada, e a forma é livre.
# ============================================================================

var cor: Color = Estilo.VIDA
var _r: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `r` de 0 a 1. Só redesenha quando muda de verdade — `queue_redraw()` a cada
## quadro com o mesmo valor é trabalho jogado fora, e a vida fica parada a maior
## parte da partida.
func valor(r: float) -> void:
	var novo := clampf(r, 0.0, 1.0)
	if absf(novo - _r) < 0.0005:
		return
	_r = novo
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var largura := size.x - Estilo.INCLINACAO
	draw_colored_polygon(Estilo.pontos(0.0, largura, h), Estilo.FUNDO)
	if _r > 0.0:
		draw_colored_polygon(Estilo.pontos(0.0, largura * _r, h), cor)
	# Contorno por último, para ficar por cima das duas camadas.
	var p := Estilo.pontos(0.0, largura, h)
	var fechado := PackedVector2Array([p[0], p[1], p[2], p[3], p[0]])
	draw_polyline(fechado, Estilo.LINHA, Estilo.GROSSURA)
