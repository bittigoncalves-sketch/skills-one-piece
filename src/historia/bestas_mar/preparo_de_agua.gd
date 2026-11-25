extends Node3D
## Gotas convergem à boca: esfera para a salva, anéis para a compressão.
const AGUA := preload("res://src/historia/bestas_mar/agua_comprimida.gdshader")
var atirador: Node3D
var compressor := false
var _idade := 0.0
var _gotas: Array[MeshInstance3D] = []
var _centro: MeshInstance3D


func _ready() -> void:
	add_to_group("efeitos_agua_bestas")
	var mat := ShaderMaterial.new()
	mat.shader = AGUA
	for i in 9:
		var no := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = .13 if i > 0 else .4
		esfera.height = esfera.radius * 2
		no.mesh = esfera
		no.material_override = mat
		add_child(no)
		if i == 0: _centro = no
		else: _gotas.append(no)


func _process(delta: float) -> void:
	if not is_instance_valid(atirador) or atirador.get("health") <= 0 or atirador.get("estado") != "disparando_ataque":
		queue_free()
		return
	_idade += delta
	global_position = atirador.animador.boca()
	var t := clampf(float(atirador.animador.tempo) / 1.08, 0, 1)
	_centro.scale = Vector3.ONE * lerpf(.3, 1.5 if compressor else 1.0, t)
	for i in _gotas.size():
		var ang := i * TAU / _gotas.size() + _idade * 5
		var raio := lerpf(1.8, .35, fmod(t * 2 + i * .12, 1.0))
		_gotas[i].position = Vector3(cos(ang), sin(ang), sin(ang * 2) * .35) * raio
