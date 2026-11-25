class_name CameraLivre
extends Camera3D
# ============================================================================
#  CÂMERA LIVRE do editor — os comandos do Roblox Studio, para quem vem de lá:
#
#    botão direito segurado + mouse   olhar
#    W A S D                          andar no plano da câmera
#    Q / E                            descer / subir
#    Shift                            3× mais rápido
#    roda do mouse                    avançar / recuar
#    F                                enquadrar a seleção (chamado pelo editor)
#
#  ⚠️ Não anda com Ctrl segurado (Ctrl+S, Ctrl+D são atalhos do editor) nem com
#  um campo de texto em foco — digitar "d" no nome de uma peça não pode mover a
#  câmera.
# ============================================================================

const VELOCIDADE := 24.0
const SENSIBILIDADE := 0.004
const PASSO_DA_RODA := 4.0

var ativa := true

var _olhando := false
var _yaw := 0.0
var _pitch := -0.45


func _ready() -> void:
	far = 4000.0
	fov = 70.0
	_aplicar_olhar()


func olhando() -> bool:
	return _olhando


func posicionar(posicao: Vector3, alvo: Vector3) -> void:
	position = posicao
	var d := (alvo - posicao).normalized()
	_yaw = atan2(-d.x, -d.z)
	_pitch = asin(clampf(d.y, -1.0, 1.0))
	_aplicar_olhar()


## Recua a câmera até o raio caber na tela, mantendo a direção de olhar.
func enquadrar(centro: Vector3, raio: float) -> void:
	var distancia := maxf(raio, 1.0) / tan(deg_to_rad(fov) * 0.5) * 1.2
	position = centro + basis.z * distancia


## Chamado pelo editor no `_input` (e não no `_unhandled_input`), para o olhar
## continuar mesmo com o mouse passando por cima de um painel.
func tratar_evento(evento: InputEvent) -> bool:
	if not ativa:
		return false
	if evento is InputEventMouseButton:
		var b := evento as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_RIGHT:
			_olhando = b.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if b.pressed else Input.MOUSE_MODE_VISIBLE
			return true
	elif evento is InputEventMouseMotion and _olhando:
		var m := evento as InputEventMouseMotion
		_yaw -= m.relative.x * SENSIBILIDADE
		_pitch = clampf(_pitch - m.relative.y * SENSIBILIDADE, -1.5, 1.5)
		_aplicar_olhar()
		return true
	return false


## A roda só vale fora dos painéis (lá ela rola a lista) — por isso é separada.
func tratar_roda(evento: InputEventMouseButton) -> bool:
	if not ativa or not evento.pressed:
		return false
	var rapido := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
		position -= basis.z * PASSO_DA_RODA * rapido
		return true
	if evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		position += basis.z * PASSO_DA_RODA * rapido
		return true
	return false


func _process(delta: float) -> void:
	if not ativa or Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
		return
	# Tree também: renomear no Explorer abre um campo de texto dentro da árvore,
	# e o foco da janela principal continua apontando para a Tree.
	var foco := get_viewport().gui_get_focus_owner()
	if foco is LineEdit or foco is Tree:
		return
	var direcao := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): direcao -= basis.z
	if Input.is_physical_key_pressed(KEY_S): direcao += basis.z
	if Input.is_physical_key_pressed(KEY_A): direcao -= basis.x
	if Input.is_physical_key_pressed(KEY_D): direcao += basis.x
	if Input.is_physical_key_pressed(KEY_E): direcao += Vector3.UP
	if Input.is_physical_key_pressed(KEY_Q): direcao -= Vector3.UP
	if direcao == Vector3.ZERO:
		return
	var rapido := 3.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	position += direcao.normalized() * VELOCIDADE * rapido * delta


func _aplicar_olhar() -> void:
	basis = Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
