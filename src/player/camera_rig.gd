class_name CameraRig
extends Node3D
# ============================================================================
#  CAMERA RIG — a câmera do jogador e tudo que se sente através dela.
#
#  Primeiro componente extraído do `Player.gd` (Fase 2 de
#  docs/ARQUITETURA_PLAYER.md). Foi escolhido para abrir porque é o de menor
#  risco: não tem RPC nenhum, quase só LÊ o estado do player, e o que ele
#  escreve é dele mesmo.
#
#  ESTE NÓ É O PIVÔ. A cadeia fica:
#      CameraRig (yaw/pitch) → Ombro (offset lateral) → SpringArm → Camera3D
#  O ombro empurra a câmera para a direita, deixando o corpo à esquerda e a mira
#  um pouco ao lado dele. O SpringArm impede a câmera de atravessar parede.
#
#  ---------------------------------------------------------------- FRONTEIRA
#  O princípio da arquitetura é: **cada componente é dono do seu estado; o
#  Player combina os resultados.** Aqui isso significa:
#
#   • O rig é DONO de: tremor, soco de FOV, fase do balanço, perspectiva,
#     distância da câmera e os nós da cadeia.
#   • O rig LÊ do player, por parâmetro: velocidade, se está no chão, se está
#     em sprint, a mira (yaw) e se a luneta está ligada.
#   • Quem quiser tremor ou soco de FOV **PEDE** (`pedir_shake`,
#     `pedir_fov_punch`) em vez de escrever no campo.
#
#  Esse último ponto é o motivo de o corte começar por aqui: `_fov_punch` tinha
#  TRÊS donos escrevendo direto (corpo a corpo, habilidades e o ciclo), e era um
#  dos 22 campos compartilhados que travavam a partição. Virou pedido.
# ============================================================================

const CAM_HEIGHT_TPS := 2.2   # altura do pivô em 3ª pessoa
const CAM_HEIGHT_FPS := 0.6   # altura do "olho" em 1ª pessoa
const SHOULDER_RIGHT := 1.1   # deslocamento p/ o ombro direito

# FOV por ESTADO. Degraus, não rampa: o salto de CORRENDO p/ SPRINT é o que faz
# o Shift dar o "clique" na mão.
#
# FOV_INTENSIDADE é o único número a mexer para calibrar a força do efeito. Os
# ganhos abaixo estão em graus "cheios" e guardam a PROPORÇÃO entre os estados;
# a intensidade escala todos juntos, então afinar não desmonta os degraus. Em
# 1.0 a variação era de 22° — forte demais em jogo. Em 0.10 sobra ~2,2°: o FOV
# respira sem chamar atenção.
const FOV_INTENSIDADE := 0.10
const FOV_BASE := 68.0
const FOV_G_ANDANDO := 4.0
const FOV_G_CORRENDO := 12.0
const FOV_G_SPRINT := 22.0
const FOV_G_AR := 3.0
const FOV_LUNETA := 22.0      # sniper da Buki: ~3x de aumento

var distancia: float = 6.0    # afastamento em 3ª pessoa (ajustável no scroll)

var _ombro: Node3D
var _spring: SpringArm3D
var _cam: Camera3D
var _primeira_pessoa := false

var _shake: float = 0.0       # tremor de tela que decai
var _fov_punch: float = 0.0   # zoom-in momentâneo ao atacar (decai)
var _bob_t: float = 0.0       # fase do balanço ao andar/correr
var _no_chao_antes := true    # p/ detectar o instante do pouso

# ------------------------------------------------------------------ montagem
# `dono` é o corpo: entra na exclusão do SpringArm para a câmera nunca colidir
# com o próprio jogador. `ativa` liga a Camera3D — só a do player local.
func montar(dono: CollisionObject3D, ativa: bool) -> void:
	_ombro = Node3D.new()
	_ombro.name = "Ombro"
	add_child(_ombro)

	_spring = SpringArm3D.new()
	_spring.name = "Spring"
	_spring.margin = 0.15
	var esfera := SphereShape3D.new()
	esfera.radius = 0.15
	_spring.shape = esfera
	_ombro.add_child(_spring)
	if dono:
		_spring.add_excluded_object(dono.get_rid())

	_cam = Camera3D.new()
	_cam.name = "Camera"
	_cam.near = 0.05
	_cam.current = ativa
	_spring.add_child(_cam)
	aplicar_perspectiva()

# A Camera3D, para quem precisa da direção da mira (tiro, raycast, alvo).
func camera() -> Camera3D:
	return _cam

func esta_montado() -> bool:
	return _cam != null

# ------------------------------------------------------------------- pedidos
# Tremor de tela. Pedido, não campo: vários sistemas querem sacudir a câmera, e
# nenhum deles precisa saber como o tremor decai.
func pedir_shake(quantidade: float) -> void:
	_shake = clampf(maxf(_shake, quantidade), 0.0, 1.0)

# Soco de FOV (zoom rápido no impacto). Era escrito direto por três domínios —
# ver o cabeçalho.
func pedir_fov_punch(quantidade: float) -> void:
	_fov_punch = maxf(_fov_punch, quantidade)

# Onde a câmera olha. O yaw/pitch continuam sendo do Player, porque quem os
# escreve é o INPUT (e a mira assistida das armas) — o rig só aponta.
func apontar(yaw: float, pitch: float) -> void:
	rotation = Vector3(pitch, yaw, 0)

func alternar_perspectiva() -> bool:
	_primeira_pessoa = not _primeira_pessoa
	aplicar_perspectiva()
	return _primeira_pessoa

func em_primeira_pessoa() -> bool:
	return _primeira_pessoa

func aplicar_perspectiva() -> void:
	if _spring == null:
		return
	if _primeira_pessoa:
		position.y = CAM_HEIGHT_FPS
		_ombro.position.x = 0.0
		_spring.spring_length = 0.0
	else:
		position.y = CAM_HEIGHT_TPS
		_ombro.position.x = SHOULDER_RIGHT
		_spring.spring_length = distancia

func ajustar_distancia(passo: float) -> void:
	distancia = clampf(distancia + passo, 2.0, 15.0)

# --------------------------------------------------------------------- ciclo
# Chamado pelo Player todo quadro. Recebe o estado que precisa em vez de ir
# buscá-lo — é o que mantém a fronteira honesta.
func atualizar(delta: float, velocidade: Vector3, vel_ref: float, no_chao: bool,
		sprint: bool, yaw: float, luneta: bool) -> void:
	if _cam == null:
		return
	var planar := Vector2(velocidade.x, velocidade.z).length()
	var spd := clampf(planar / maxf(vel_ref, 0.001), 0.0, 1.2)

	# --- offsets = TREMOR + BALANÇO (h_offset/v_offset NÃO afetam a mira) ---
	var sh := _shake * 0.09
	if _shake > 0.0:
		_shake = maxf(_shake - delta * 3.5, 0.0)
	var sx := randf_range(-sh, sh)
	var sy := randf_range(-sh, sh)
	var andando := spd > 0.05 and no_chao
	_bob_t += delta * (4.0 + spd * 9.0)
	var amp := (spd * 0.024) if andando else 0.0
	_cam.h_offset = lerpf(_cam.h_offset, sx + cos(_bob_t) * amp, 0.5)
	_cam.v_offset = lerpf(_cam.v_offset, sy + absf(sin(_bob_t)) * amp, 0.5)

	# ------------------------------------------------------------------ FOV
	_fov_punch = maxf(_fov_punch - delta * 22.0, 0.0)
	var ganho := 0.0
	if spd > 0.05:
		ganho = lerpf(FOV_G_ANDANDO, FOV_G_CORRENDO, clampf(spd, 0.0, 1.0))
		if sprint:
			ganho = lerpf(ganho, FOV_G_SPRINT, clampf((spd - 0.7) / 0.5, 0.0, 1.0))
	if not no_chao:
		ganho += FOV_G_AR                    # no ar abre um pouco: sensação de queda
	var alvo_fov: float = FOV_BASE + ganho * FOV_INTENSIDADE - _fov_punch
	# A luneta SOBRESCREVE o FOV de velocidade de propósito: mirar tem prioridade
	# sobre "respirar".
	if luneta:
		alvo_fov = FOV_LUNETA
	# Abre RÁPIDO e fecha DEVAGAR. Simétrico dá a impressão de a câmera respirar
	# junto com cada tranco do passo.
	var vel_fov := 9.0 if alvo_fov > _cam.fov else 3.5
	_cam.fov = lerpf(_cam.fov, alvo_fov, vel_fov * delta)

	# --- inclinação: rolagem ao andar de lado + gingado no ritmo do passo ---
	var direita := Basis(Vector3.UP, yaw) * Vector3(1, 0, 0)
	var strafe := clampf(velocidade.dot(direita) / maxf(vel_ref, 0.001), -1.0, 1.0)
	var tilt := -strafe * 3.5 + (sin(_bob_t) * spd * 1.2 if andando else 0.0)
	_cam.rotation.z = lerpf(_cam.rotation.z, deg_to_rad(tilt), 6.0 * delta)

	# Recuo da câmera ao correr (só 3ª pessoa)
	if not _primeira_pessoa and _spring:
		_spring.spring_length = lerpf(_spring.spring_length, distancia + spd * 0.9, 4.0 * delta)

	# Tranco ao aterrissar
	if no_chao and not _no_chao_antes:
		pedir_shake(0.3)
	_no_chao_antes = no_chao

	_efeitos_de_tela(spd, sprint)

# EFEITOS DE VELOCIDADE na tela. Quatro camadas que entram em faixas DIFERENTES.
# Antes só a vinheta era visível — ela entrava em 0,4 e as linhas só em 0,85, que
# quase nunca se alcança, então o resultado prático era "a tela escurece".
func _efeitos_de_tela(spd: float, sprint: bool) -> void:
	var v: float = spd * (1.15 if sprint else 1.0)
	ScreenFX.set_borrao(clampf((v - 0.35) * 0.7, 0.0, 0.5))          # o mundo escorre nas bordas
	ScreenFX.set_speed_lines(clampf((v - 0.50) * 0.8, 0.0, 0.4))
	ScreenFX.set_aberracao_base(clampf((v - 0.62) * 0.8, 0.0, 0.3))
	ScreenFX.set_vignette(clampf((v - 0.70) * 0.6, 0.0, 0.2))
