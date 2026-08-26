class_name Estilo
extends RefCounted
# ============================================================================
#  O ESTILO DO HUD — Fase 6 de docs/PLANO_VISUAL.md
#
#  Um lugar só para "de que cor e de que forma é a interface deste jogo". Antes
#  disto cada arquivo de `src/ui/` inventava a sua cor, o seu tamanho de fonte e
#  a sua espessura de contorno — e por isso a HUD não tinha identidade nenhuma,
#  só retângulos chapados com a fonte padrão.
#
#  ⚠️ A COR DA LINHA É A MESMA DO CONTORNO 3D. Não é coincidência nem gosto: o
#  jogo passou a ter linha preta na silhueta (Fase 2) e cor chapada (Fase 3). Um
#  HUD com borda de outra cor, ou sem borda, leria como se fosse de outro jogo
#  colado por cima. A interface tem que falar a mesma língua da cena.
# ============================================================================

# A mesma de `src/fx/shaders/contorno.gdshader`.
const LINHA := Color(0.04, 0.05, 0.09, 1.0)
const FUNDO := Color(0.05, 0.07, 0.12, 0.72)

const VIDA := Color(0.30, 0.90, 0.38)
const ENERGIA := Color(0.32, 0.62, 1.0)
const AVISO := Color(1.0, 0.82, 0.25)
const APAGADO := Color(0.72, 0.55, 0.55)
const LIGADO := Color(0.45, 1.0, 0.55)

const GROSSURA := 3.0
# Corte inclinado das pontas. É o que separa "barra de jogo de luta" de
# "retângulo": custa nada e é reconhecível de imediato.
const INCLINACAO := 9.0


## Rótulo com contorno — o contorno é obrigatório, não decoração: sem ele o
## texto claro some no chão claro e o texto escuro some na sombra.
static func texto(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", LINHA)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## O fundo de um painel: escuro, translúcido e com a MESMA borda das barras e
## do contorno 3D. É isto que impede o HUD de parecer dois jogos colados — as
## barras com identidade e as caixas ainda chapadas.
static func painel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = FUNDO
	sb.border_color = LINHA
	sb.set_border_width_all(int(GROSSURA))
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10.0)
	return sb


## Os quatro cantos do paralelogramo, da esquerda `x0` até `x1`.
static func pontos(x0: float, x1: float, altura: float) -> PackedVector2Array:
	var i := INCLINACAO
	return PackedVector2Array([
		Vector2(x0 + i, 0.0), Vector2(x1 + i, 0.0),
		Vector2(x1, altura), Vector2(x0, altura)])
