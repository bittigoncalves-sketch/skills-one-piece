extends Node3D
## Jato sustentado preso à boca, direção travada no disparo e dano único por alvo.
const Colisao := preload("res://src/historia/bestas_mar/colisao_agua.gd")
const AGUA := preload("res://src/historia/bestas_mar/agua_comprimida.gdshader")
const DURACAO := .60
const RAIO := .55
var atirador: Node3D
var rumo := Vector3.FORWARD
var alcance := 55.0
var dano := 12.0
var idade := 0.0
var comprimento := 0.0
var _atingidos := {}
var _jato: MeshInstance3D
var _nucleo: MeshInstance3D
var _impacto: MeshInstance3D
var _aneis: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("efeitos_agua_bestas")
	var mat := ShaderMaterial.new()
	mat.shader = AGUA
	_jato = _tubo(RAIO, mat)
	var espuma := StandardMaterial3D.new()
	espuma.albedo_color = Color(.65, .90, 1.0)
	espuma.emission_enabled = true
	espuma.emission = Color(.15, .3, .4)
	_nucleo = _tubo(.19, espuma)
	for i in 8:
		var anel := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = .40
		toro.outer_radius = .58
		toro.rings = 16
		toro.ring_segments = 8
		anel.mesh = toro
		anel.material_override = espuma
		add_child(anel)
		_aneis.append(anel)
	_impacto = MeshInstance3D.new()
	var bola := SphereMesh.new()
	bola.radius = .75
	bola.height = 1.5
	_impacto.mesh = bola
	_impacto.material_override = mat
	add_child(_impacto)


func _tubo(raio: float, mat: Material) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	var cilindro := CylinderMesh.new()
	cilindro.top_radius = raio
	cilindro.bottom_radius = raio * .85
	cilindro.height = 1.0
	cilindro.radial_segments = 24
	no.mesh = cilindro
	no.material_override = mat
	add_child(no)
	return no


func _physics_process(delta: float) -> void:
	idade += delta
	if idade >= DURACAO or not is_instance_valid(atirador) or atirador.get("health") <= 0 \
			or atirador.get("estado") != "disparando_ataque" \
			or atirador.get_meta("is_frozen", false) or atirador.get_meta("in_black_hole", false):
		queue_free()
		return
	global_position = atirador.animador.boca()
	var contato := Colisao.varrer(atirador, global_position, rumo * alcance, RAIO)
	comprimento = global_position.distance_to(contato.posicao)
	# Y é o eixo dos cilindros. A mesma extensão do sweep governa a malha.
	var eixo := Vector3.RIGHT if absf(rumo.dot(Vector3.UP)) > .98 else Vector3.UP
	var x := eixo.cross(rumo).normalized()
	global_basis = Basis(x, rumo, x.cross(rumo)).orthonormalized()
	var espessura := minf(1.0, idade / .07) * minf(1.0, (DURACAO - idade) / .12)
	for tubo in [_jato, _nucleo]:
		tubo.position.y = comprimento * .5
		tubo.scale = Vector3(espessura, maxf(.001, comprimento), espessura)
	for i in _aneis.size():
		_aneis[i].position.y = fmod(i * 4.1 + idade * 42, maxf(.01, comprimento))
		_aneis[i].scale = Vector3.ONE * espessura
	_impacto.position.y = comprimento
	_impacto.visible = contato.colidiu
	_impacto.scale = Vector3.ONE * (1.0 + sin(idade * 65) * .15) * espessura
	var alvo: Node = contato.alvo
	if is_instance_valid(alvo) and not _atingidos.has(alvo.get_instance_id()) \
			and (not multiplayer.has_multiplayer_peer() or multiplayer.is_server()):
		_atingidos[alvo.get_instance_id()] = true
		CombatResolver.aplicar(alvo, dano, 0, 0, global_position, rumo * 16 + Vector3.UP * 2, .4, 0, false, null, atirador)
