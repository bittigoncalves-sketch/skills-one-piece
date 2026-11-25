extends Control
# ============================================================================
#  BÚSSOLA NA TELA (08/10/2026) — aponta para a Ilha dos Macacos.
#
#  Pedido do dono: completar as missões do Guarda "facilita a busca" da ilha; escolha
#  dele: "uma bússola que aponta para a ilha". É o prêmio da última missão
#  (`desbloqueios["bussola"]`).
#  Fica logo abaixo das barras de vida e energia (segue as barras se o dono as mover
#  no editor de janelas). A agulha gira com a CÂMERA: para cima = para onde a câmera
#  olha. Ao lado, o nome da ilha e a distância até a costa. Some na própria ilha, com
#  menu aberto e enquanto não há corpo.
# ============================================================================

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const RAIO := 30.0
const ESPACO := 14.0

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable
var alvo := Ilhas.MACACOS
## Bússola de MISSÃO (21/11/2026): se `ponto_de_missao` devolver um Vector3, a agulha aponta para ele (com `nome_do_ponto`) e a bússola aparece sem exigir o prêmio da ilha.
var ponto_de_missao: Callable = Callable()
var nome_do_ponto := "Cais"
var caixa := Rect2()                     # a placa da ilha-alvo
var abaixo_de: Control                   # as barras de vida e energia
var _angulo := 0.0
var _rotulo: Label


func _ready() -> void:
	name = "Bussola"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(RAIO * 2.0, RAIO * 2.0)
	_rotulo = Label.new()
	_rotulo.position = Vector2(RAIO * 2.0 + 10.0, RAIO - 22.0)
	_rotulo.add_theme_font_size_override("font_size", 16)
	_rotulo.add_theme_color_override("font_shadow_color", Color.BLACK)
	_rotulo.add_theme_constant_override("shadow_offset_x", 1)
	_rotulo.add_theme_constant_override("shadow_offset_y", 1)
	add_child(_rotulo)
	visible = false


func _process(_delta: float) -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	var cam := get_viewport().get_camera_3d()
	var hud := get_parent()
	var ponto: Variant = ponto_de_missao.call() if ponto_de_missao.is_valid() else null
	if ponto is Vector3:
		_processar_ponto(j, cam, hud, ponto as Vector3)
		return
	visible = progressao != null and bool(progressao.desbloqueios.get("bussola", false)) and progressao.ilha != alvo \
		and j != null and cam != null and caixa.has_area() \
		and not (hud != null and hud.has_method("is_menu_open") and hud.call("is_menu_open"))
	if not visible:
		return
	if abaixo_de != null:
		position = abaixo_de.position + Vector2(0.0, abaixo_de.size.y + ESPACO)
	var p := j.global_position
	var para := Vector3(caixa.get_center().x, 0.0, caixa.get_center().y) - Vector3(p.x, 0.0, p.z)
	var frente := -cam.global_basis.z
	var direita := cam.global_basis.x
	var angulo := atan2(para.dot(Vector3(direita.x, 0.0, direita.z)), para.dot(Vector3(frente.x, 0.0, frente.z)))
	if absf(wrapf(angulo - _angulo, -PI, PI)) > deg_to_rad(0.5):
		_angulo = angulo
		queue_redraw()
	_rotulo.text = "%s\n%s" % [Ilhas.nome(alvo), _distancia(Ilhas.distancia(caixa, p))]


func _processar_ponto(j: Node3D, cam: Camera3D, hud: Node, alvo_pos: Vector3) -> void:
	visible = j != null and cam != null and not (hud != null and hud.has_method("is_menu_open") and hud.call("is_menu_open"))
	if not visible:
		return
	if abaixo_de != null:
		position = abaixo_de.position + Vector2(0.0, abaixo_de.size.y + ESPACO)
	_angulo = angulo_para(j.global_position, alvo_pos, cam.global_basis)
	queue_redraw()
	_rotulo.text = "%s\n%s" % [nome_do_ponto, _distancia(Vector2(alvo_pos.x - j.global_position.x, alvo_pos.z - j.global_position.z).length())]


## Ângulo da agulha (0 = em frente da câmera, + = à direita) de `de` para `para`, no plano horizontal. Estático para o teste.
static func angulo_para(de: Vector3, para: Vector3, base: Basis) -> float:
	var v := Vector3(para.x - de.x, 0.0, para.z - de.z)
	var frente := -base.z
	var direita := base.x
	return atan2(v.dot(Vector3(direita.x, 0.0, direita.z)), v.dot(Vector3(frente.x, 0.0, frente.z)))


func angulo() -> float:
	return _angulo


func _draw() -> void:
	var c := Vector2(RAIO, RAIO)
	draw_circle(c, RAIO, Estilo.FUNDO)
	draw_arc(c, RAIO - 1.0, 0.0, TAU, 40, Estilo.LINHA, 2.0, true)
	draw_arc(c, RAIO - 4.0, 0.0, TAU, 40, Color(1, 1, 1, 0.18), 1.0, true)
	var dir := Vector2(sin(_angulo), -cos(_angulo))          # tela: y para baixo
	var lado := Vector2(-dir.y, dir.x)
	var ponta := c + dir * (RAIO - 6.0)
	var cauda := c - dir * (RAIO - 10.0)
	draw_colored_polygon(PackedVector2Array([ponta, c + lado * 6.0, c - lado * 6.0]), Estilo.AVISO)
	draw_colored_polygon(PackedVector2Array([cauda, c + lado * 6.0, c - lado * 6.0]), Color(0.85, 0.87, 0.92, 0.9))
	draw_circle(c, 3.0, Estilo.LINHA)


## "850 m", "1,2 km".
static func _distancia(m: float) -> String:
	if m < 1000.0:
		return "%d m" % roundi(m)
	return ("%.1f km" % (m / 1000.0)).replace(".", ",")
