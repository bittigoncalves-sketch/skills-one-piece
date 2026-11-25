extends Node3D
## Acento de contato/lançamento em espaço do mundo, sem hitbox ou dano.
var tempo := 0.0
var duracao := 0.32
var _material: ShaderMaterial

func montar(raio: float, impacto: bool) -> void:
	duracao = 0.24 if impacto else 0.38
	var vertices := PackedVector3Array()
	var cores := PackedColorArray()
	# Quatro crescentes interrompidos: o centro permanece livre para o alvo.
	for arco in 4:
		for i in 16:
			var a := float(arco) * TAU / 4.0 + float(i) / 16.0 * 1.12
			var b := a + 1.12 / 16.0
			var interno := 0.78 + 0.17 * absf(float(i) / 8.0 - 1.0)
			var pontos := [Vector3(cos(a), sin(a), 0) * interno,
				Vector3(cos(a), sin(a), 0), Vector3(cos(b), sin(b), 0),
				Vector3(cos(a), sin(a), 0) * interno,
				Vector3(cos(b), sin(b), 0), Vector3(cos(b), sin(b), 0) * interno]
			for ponto: Vector3 in pontos:
				vertices.append(ponto * raio)
				cores.append(Color(0.78, 1.0, 0.63))
	if impacto:
		for i in 9:
			var a := float(i) * TAU / 9.0
			var direcao := Vector3(cos(a), sin(a), 0)
			var lado := Vector3(-sin(a), cos(a), 0) * 0.055
			for ponto: Vector3 in [direcao * 1.1 - lado, direcao * (1.65 + float(i % 3) * .15), direcao * 1.1 + lado]:
				vertices.append(ponto * raio)
				cores.append(Color(0.94, 1.0, 0.84))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = cores
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;
uniform float progresso = 0.0;
void vertex() { VERTEX *= mix(0.35, 1.6, 1.0-pow(1.0-progresso, 2.0)); }
void fragment() { ALBEDO = COLOR.rgb; ALPHA = 1.0-smoothstep(0.18, 1.0, progresso); }
"""
	_material = ShaderMaterial.new()
	_material.shader = shader
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _process(delta: float) -> void:
	tempo += delta
	if tempo >= duracao:
		queue_free()
	elif _material != null:
		_material.set_shader_parameter("progresso", tempo / duracao)
