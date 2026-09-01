class_name ToqueHud
extends Control
# ============================================================================
#  CONTROLES DE TOQUE — o jogo jogável com os dedos.
#
#  ------------------------------------------------ A DECISÃO CENTRAL
#  Este HUD não cria um segundo caminho de input: ele INJETA os mesmos eventos
#  que o teclado e o mouse já produzem (`Input.parse_input_event`). O joystick
#  vira W/A/S/D, os botões viram as teclas deles, e o arrasto vira movimento de
#  mouse.
#
#  ⚠️ POR QUE ASSIM. Nove arquivos leem teclado ou mouse direto — `MoveFrame`,
#  `Player`, os controladores de dash, buki, disparo. Um caminho paralelo de
#  input exigiria mexer nos nove e manter os dois em sincronia para sempre:
#  toda regra nova (uma trava, um cancelamento) teria de ser escrita duas vezes,
#  e a segunda seria esquecida. Injetando, o jogo inteiro continua com UM
#  caminho de entrada, e o toque é só mais uma fonte dele.
#
#  O preço é que o analógico do joystick vira digital (W/A/S/D). Não se perde
#  nada: `MoveFrame.ler()` já trata `f` e `r` como −1/0/1 mesmo no teclado.
#
#  ------------------------------------------------ AS DUAS METADES DA TELA
#  Esquerda anda, direita olha — a convenção que todo jogo 3D de celular usa, e
#  que o jogador já conhece de outros. O arrasto da direita só vale FORA dos
#  botões, senão apertar uma skill giraria a câmera junto.
# ============================================================================

## Ligado à força, para dar de testar no PC sem um aparelho.
static var forcar := false

const RAIO_BASE := 110.0        # o círculo do joystick
const RAIO_MANOPLA := 46.0
const ZONA_MORTA := 0.22        # fração do raio abaixo da qual não anda
## Arrasto → giro. ⚠️ CALIBRADO CONTRA O POLEGAR, não escolhido no olho: com
## 1,35 a medição deu 75° para 160 px, ou seja meia volta a cada ~220 px — um
## polegar percorre isso sem querer, e a câmera ficava incontrolável. 0,55 põe a
## meia volta perto de 500 px, que é um arrasto deliberado numa tela de celular.
const SENS_CAMERA := 0.55

## Os botões da direita: rótulo, tecla que injetam, e onde ficam (fração da
## tela, a partir do canto inferior direito).
const BOTOES := [
	{"nome": "M1",    "tecla": KEY_NONE,  "mouse": true, "x": 0.10, "y": 0.16, "r": 58.0},
	{"nome": "PULO",  "tecla": KEY_SPACE, "x": 0.24, "y": 0.10, "r": 48.0},
	{"nome": "DASH",  "tecla": KEY_Q,     "x": 0.24, "y": 0.30, "r": 40.0},
	{"nome": "F",     "tecla": KEY_F,     "x": 0.10, "y": 0.36, "r": 40.0},
	{"nome": "Z",     "tecla": KEY_Z,     "x": 0.38, "y": 0.34, "r": 38.0},
	{"nome": "X",     "tecla": KEY_X,     "x": 0.38, "y": 0.16, "r": 38.0},
	{"nome": "C",     "tecla": KEY_C,     "x": 0.52, "y": 0.30, "r": 38.0},
	{"nome": "V",     "tecla": KEY_V,     "x": 0.52, "y": 0.12, "r": 38.0},
]

var _base := Vector2.ZERO       # centro do joystick, fixado onde o dedo tocou
var _manopla := Vector2.ZERO
var _dedo_mov := -1             # índice do toque que controla o movimento
var _dedo_cam := -1             # e o que controla a câmera
var _teclas_ligadas := {}       # tecla -> true, para soltar o que foi apertado
var _dedo_botao := {}           # índice do toque -> qual botão ele segura


## O jogo está em modo toque? Em Android e iOS, sempre; no PC, só se forçado.
static func ativo() -> bool:
	return forcar or OS.get_name() in ["Android", "iOS"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = ativo()
	set_process_input(visible)


func _input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento is InputEventScreenTouch:
		_ao_tocar(evento as InputEventScreenTouch)
	elif evento is InputEventScreenDrag:
		_ao_arrastar(evento as InputEventScreenDrag)


func _ao_tocar(e: InputEventScreenTouch) -> void:
	if e.pressed:
		# Um botão sob o dedo tem prioridade: sem isso, apertar uma skill perto
		# da borda também giraria a câmera.
		var b := _botao_em(e.position)
		if b >= 0:
			_dedo_botao[e.index] = b
			_apertar(b, true)
			return
		if e.position.x < size.x * 0.5 and _dedo_mov < 0:
			_dedo_mov = e.index
			_base = e.position          # o joystick nasce ONDE o dedo tocou
			_manopla = e.position
			queue_redraw()
		elif _dedo_cam < 0:
			_dedo_cam = e.index
	else:
		if _dedo_botao.has(e.index):
			_apertar(int(_dedo_botao[e.index]), false)
			_dedo_botao.erase(e.index)
		elif e.index == _dedo_mov:
			_dedo_mov = -1
			_soltar_direcoes()
			queue_redraw()
		elif e.index == _dedo_cam:
			_dedo_cam = -1


func _ao_arrastar(e: InputEventScreenDrag) -> void:
	if e.index == _dedo_mov:
		_manopla = e.position
		_atualizar_direcoes()
		queue_redraw()
	elif e.index == _dedo_cam:
		# Vira movimento de mouse: a câmera do Player já sabe reagir a isso, e
		# não precisa aprender um segundo jeito de girar.
		var m := InputEventMouseMotion.new()
		m.relative = e.relative * SENS_CAMERA
		m.position = e.position
		Input.parse_input_event(m)


## O vetor do joystick vira as quatro teclas de direção. Uma tecla só é
## injetada quando MUDA de estado — repetir `pressed` a cada quadro entupiria a
## fila de eventos sem mudar nada.
func _atualizar_direcoes() -> void:
	var v: Vector2 = _manopla - _base
	if v.length() > RAIO_BASE:
		v = v.normalized() * RAIO_BASE
		_manopla = _base + v
	var n := v / RAIO_BASE
	if n.length() < ZONA_MORTA:
		_soltar_direcoes()
		return
	_definir(KEY_W, n.y < -ZONA_MORTA)
	_definir(KEY_S, n.y > ZONA_MORTA)
	_definir(KEY_A, n.x < -ZONA_MORTA)
	_definir(KEY_D, n.x > ZONA_MORTA)
	# Longe do centro = correr. É o que substitui o Shift, que não tem dedo.
	_definir(KEY_SHIFT, n.length() > 0.82)


func _soltar_direcoes() -> void:
	for k in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SHIFT]:
		_definir(k, false)


func _definir(tecla: Key, ligada: bool) -> void:
	if bool(_teclas_ligadas.get(tecla, false)) == ligada:
		return
	_teclas_ligadas[tecla] = ligada
	var e := InputEventKey.new()
	e.physical_keycode = tecla
	e.keycode = tecla
	e.pressed = ligada
	Input.parse_input_event(e)


func _apertar(indice: int, ligado: bool) -> void:
	var b: Dictionary = BOTOES[indice]
	if bool(b.get("mouse", false)):
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT
		m.pressed = ligado
		m.position = _centro_do_botao(indice)
		Input.parse_input_event(m)
	else:
		_definir(int(b["tecla"]), ligado)
	queue_redraw()


func _centro_do_botao(i: int) -> Vector2:
	var b: Dictionary = BOTOES[i]
	return Vector2(size.x * (1.0 - float(b["x"])), size.y * (1.0 - float(b["y"])))


func _botao_em(p: Vector2) -> int:
	for i in BOTOES.size():
		if p.distance_to(_centro_do_botao(i)) <= float(BOTOES[i]["r"]):
			return i
	return -1


func _draw() -> void:
	# JOYSTICK: só aparece com o dedo em cima. Um círculo fixo ocupando canto de
	# tela o tempo todo cobre o jogo sem precisar.
	if _dedo_mov >= 0:
		draw_circle(_base, RAIO_BASE, Color(1, 1, 1, 0.10))
		draw_arc(_base, RAIO_BASE, 0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(_manopla, RAIO_MANOPLA, Color(1, 1, 1, 0.28))

	var fonte := ThemeDB.fallback_font
	for i in BOTOES.size():
		var b: Dictionary = BOTOES[i]
		var c := _centro_do_botao(i)
		var r := float(b["r"])
		var apertado := _dedo_botao.values().has(i)
		draw_circle(c, r, Color(1, 1, 1, 0.22 if apertado else 0.12))
		draw_arc(c, r, 0, TAU, 32, Color(1, 1, 1, 0.45), 2.0)
		var texto := String(b["nome"])
		var largura := fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(fonte, c + Vector2(-largura * 0.5, 7), texto,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
