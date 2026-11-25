class_name MarcadorDeAcerto
extends Control
## MARCADOR DE ACERTO ao estilo FPS (21/11/2026): um "X" branco no retículo que pisca ~0,18 s quando a bala da Buki fere alguém; vermelho e maior no abate.
## Só desenha: o dano é da `DamageZone`. Fica no grupo "marcador_de_acerto"; quem acerta chama `MarcadorDeAcerto.piscar(arvore, abate)`.

const DURACAO := 0.18
const DURACAO_ABATE := 0.32
const COR := Color(1, 1, 1, 0.95)
const COR_ABATE := Color(1.0, 0.25, 0.2, 1.0)

var _t := 0.0
var _total := DURACAO
var _abate := false


func _ready() -> void:
	add_to_group("marcador_de_acerto")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


static func piscar(arvore: SceneTree, abate := false) -> void:
	if arvore == null:
		return
	for no in arvore.get_nodes_in_group("marcador_de_acerto"):
		if no is MarcadorDeAcerto:
			(no as MarcadorDeAcerto).acionar(abate)


func acionar(abate: bool) -> void:
	_abate = abate or (_abate and _t > 0.0)
	_total = DURACAO_ABATE if _abate else DURACAO
	_t = _total
	visible = true
	queue_redraw()


func _process(delta: float) -> void:
	if _t <= 0.0:
		return
	_t -= delta
	if _t <= 0.0:
		visible = false
		_abate = false
	queue_redraw()


func _draw() -> void:
	if _t <= 0.0:
		return
	var u := clampf(_t / _total, 0.0, 1.0)                    # 1 → 0
	var c := (COR_ABATE if _abate else COR)
	c.a *= u
	var centro := size * 0.5
	var folga := (7.0 + (1.0 - u) * 5.0) * (1.4 if _abate else 1.0)      # os traços se afastam ao sumir
	var comp := 9.0 * (1.4 if _abate else 1.0)
	for dir in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var a: Vector2 = centro + dir * folga
		draw_line(a, a + dir * comp, Color(0, 0, 0, c.a * 0.6), 4.0)
		draw_line(a, a + dir * comp, c, 2.0)
