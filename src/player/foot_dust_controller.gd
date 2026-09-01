extends RefCounted
## Poeira de deslocamento: cartões 2D pequenos, sem física e sem hitbox.
## A decisão usa física (chão + distância percorrida), não a fase da animação,
## para continuar correta com rigs skinnados e clipes sobrepostos.

const PASSADA_ANDANDO := 0.48
const PASSADA_CORRENDO := 0.40
const VELOCIDADE_MINIMA := 0.35

var _dono: Node3D = null
var _emissores: Array[GPUParticles3D] = []
var _distancia := 0.0
var _lado := 0

func montar_em(dono: Node3D) -> void:
	_dono = dono
	for lateral in [-0.17, 0.17]:
		var p := _criar_emissor()
		p.position = Vector3(lateral, -0.92, 0.03)
		dono.add_child(p)
		_emissores.append(p)

func atualizar(delta: float, velocidade: Vector3, no_chao: bool, bloqueado: bool = false) -> void:
	if _dono == null or not is_instance_valid(_dono):
		return
	var planar := Vector2(velocidade.x, velocidade.z).length()
	if not no_chao or bloqueado or planar < VELOCIDADE_MINIMA:
		_distancia = 0.0
		return
	_distancia += planar * delta
	var passo := PASSADA_CORRENDO if planar >= 6.0 else PASSADA_ANDANDO
	if _distancia < passo:
		return
	_distancia = fmod(_distancia, passo)
	_emitir_no_pe(_lado, planar)
	_lado = 1 - _lado

func _criar_emissor() -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.16)
	pm.spread = 45.0
	pm.gravity = Vector3(0.0, -8.0, 0.0)
	pm.initial_velocity_min = 0.7
	pm.initial_velocity_max = 1.7
	pm.scale_min = 0.7
	pm.scale_max = 1.25
	pm.color_ramp = FxUtil.gradient([
		Color(0.36, 0.30, 0.23, 0.68),
		Color(0.48, 0.40, 0.30, 0.44),
		Color(0.38, 0.32, 0.25, 0.0),
	])
	var p := FxUtil.particles(8, 0.42, true, pm, FxUtil.grain(0.11), 1.0)
	p.name = "PoeiraDoPe"
	p.emitting = false
	return p

func _emitir_no_pe(indice: int, planar: float) -> void:
	if indice < 0 or indice >= _emissores.size():
		return
	var p := _emissores[indice]
	if not is_instance_valid(p):
		return
	# Sprint solta cinco cartões; caminhada, quatro. A vida curta limita a
	# aproximadamente 45 cartões vivos mesmo com vários jogadores correndo.
	p.amount = 10 if planar >= 6.0 else 8
	p.restart()
	p.emitting = true
