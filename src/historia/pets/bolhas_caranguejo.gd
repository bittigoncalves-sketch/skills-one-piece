extends Node3D
## Emissão finita, sem dano. Cada rajada vive 2,4 s, mesmo se o pet for recolhido.
const DURACAO := 2.4
var _tempo := 0.0
var _bolhas: Array[Dictionary] = []

func _ready() -> void:
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 16
	esfera.rings = 8
	var material := ShaderMaterial.new()
	material.shader = load("res://src/historia/pets/bolha.gdshader")
	for i in 9:
		var no := MeshInstance3D.new()
		no.mesh = esfera
		no.material_override = material
		no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(no)
		var raio := randf_range(.045, .12)
		no.scale = Vector3.ONE * raio
		no.position = Vector3(randf_range(-.08, .08), 0, randf_range(-.08, .08))
		_bolhas.append({"no": no, "raio": raio, "atraso": i * .07,
			"velocidade": Vector3(randf_range(-.24, .24), randf_range(.35, .7), randf_range(-.45, -.12))})

func _process(delta: float) -> void:
	_tempo += delta
	for b in _bolhas:
		var idade: float = _tempo - b.atraso
		var no: MeshInstance3D = b.no
		no.visible = idade > 0 and idade < 1.7
		if not no.visible:
			continue
		no.position += (b.velocidade as Vector3) * delta
		no.position.x += sin(idade * 5.0 + b.atraso * 10.0) * delta * .07
		var tamanho: float = b.raio * minf(1.0, idade * 8.0) * clampf((1.7 - idade) * 3.0, 0, 1)
		no.scale = Vector3.ONE * maxf(.001, tamanho)
	if _tempo >= DURACAO:
		queue_free()
