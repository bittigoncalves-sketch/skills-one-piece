class_name MaguPoses
extends RefCounted
# ============================================================================
#  POSES DA MAGU MAGU NO MODO HISTÓRIA (14/10/2026).
#
#  Z — soco de lava: `magu_z_prep` arma o braço direito para trás (torção do tronco
#  contra o golpe) e `magu_z_soco` estende o braço; as duas são a mesma pose com um
#  cursor `s` (0 = armado, 1 = socando) para o animador misturar sem corte.
#  X — surfe: `magu_x_surf`, base larga e joelhos dobrados, braços abertos para o
#  equilíbrio, tronco inclinado e cabeça olhando para onde a onda vai.
#
#  O modelo, no surfe, é virado de lado para o rumo da onda (ver Player.gd,
#  `magu_surf`): o corpo olha para a DIREITA do rumo e o rumo fica à ESQUERDA do
#  personagem — por isso a cabeça gira para +Y (esquerda) e as pernas se abrem no
#  eixo X do próprio corpo (que é o eixo da prancha).
#  Como as outras poses de fruta, recebe o `_add` do animador (espelhamento e filtro
#  de papéis ausentes ficam com ele).
# ============================================================================

static func soco(add: Callable, off: Dictionary, w: float, s: float, t: float) -> void:
	if w <= 0.001:
		return
	var a := clampf(s, 0.0, 1.0)
	# Braço do soco: ombro atrás e cotovelo dobrado -> braço inteiro à frente, esticado.
	add.call(off, "UpperArm_R", Vector3(-0.95, -0.10, 0.30).lerp(Vector3(1.50, 0.0, 0.10), a) * w)
	add.call(off, "ForeArm_R", Vector3(1.55, 0.0, 0.0).lerp(Vector3(0.05, 0.0, 0.0), a) * w)
	# Braço de trás: guarda no armar, recolhe ao quadril no golpe.
	add.call(off, "UpperArm_L", Vector3(0.55, 0.0, -0.30).lerp(Vector3(-0.60, 0.0, -0.40), a) * w)
	add.call(off, "ForeArm_L", Vector3(1.00, 0.0, 0.0) * w)
	# Tronco: gira o ombro direito para trás e, no golpe, o joga para a frente.
	add.call(off, "Torso", Vector3(-0.12, -0.55, 0.0).lerp(Vector3(-0.28, 0.55, 0.0), a) * w)
	add.call(off, "Head", Vector3(0.10, 0.0, 0.0).lerp(Vector3(0.18, -0.25, 0.0), a) * w)
	# Base: perna esquerda à frente flexionada, direita atrás empurrando o chão.
	add.call(off, "Thigh_L", Vector3(0.45, 0.0, -0.10).lerp(Vector3(0.75, 0.0, -0.12), a) * w)
	add.call(off, "Shin_L", Vector3(-0.65, 0.0, 0.0).lerp(Vector3(-0.95, 0.0, 0.0), a) * w)
	add.call(off, "Thigh_R", Vector3(-0.25, 0.0, 0.15).lerp(Vector3(-0.50, 0.0, 0.18), a) * w)
	add.call(off, "Shin_R", Vector3(-0.45, 0.0, 0.0).lerp(Vector3(-0.30, 0.0, 0.0), a) * w)
	add.call(off, "Foot_R", Vector3(0.25, 0.0, 0.0) * w)

static func surf(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	var balanco := sin(t * 3.1)
	# Base larga sobre a prancha (mesma abertura do Hibashira) com joelhos dobrados.
	add.call(off, "Thigh_L", Vector3(0.50, 0.0, -0.52 - 0.04 * balanco) * w)
	add.call(off, "Thigh_R", Vector3(0.50, 0.0, 0.52 + 0.04 * balanco) * w)
	add.call(off, "Shin_L", Vector3(-0.90, 0.0, 0.0) * w)
	add.call(off, "Shin_R", Vector3(-0.90, 0.0, 0.0) * w)
	add.call(off, "Foot_L", Vector3(0.35, 0.0, 0.2) * w)
	add.call(off, "Foot_R", Vector3(0.35, 0.0, -0.2) * w)
	# Braços abertos, o da frente (esquerdo) mais baixo e esticado para a onda.
	add.call(off, "UpperArm_L", Vector3(0.10, 0.0, -1.15 + 0.10 * balanco) * w)
	add.call(off, "UpperArm_R", Vector3(0.10, 0.0, 1.30 - 0.10 * balanco) * w)
	add.call(off, "ForeArm_L", Vector3(0.20, 0.0, 0.0) * w)
	add.call(off, "ForeArm_R", Vector3(0.35, 0.0, 0.0) * w)
	# Tronco inclinado para dentro da curva e cabeça olhando para onde a onda vai.
	add.call(off, "Torso", Vector3(-0.30, 0.45, 0.08 * balanco) * w)
	add.call(off, "Head", Vector3(0.20, 0.55, 0.0) * w)
