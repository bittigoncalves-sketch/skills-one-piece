extends Node3D
## Vento editável, sem simulação de gameplay. Relógio absoluto fornecido pelo dono.
## Tornado: origem no chão, eixo +Y. Outros modos: frente local -Z.

const CODIGO := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 cor : source_color = vec4(0.45, 1.0, 0.48, 0.55);
uniform float tempo = 0.0;
uniform float intensidade = 1.0;
uniform float giro = 2.0;
uniform bool vertical = true;
uniform float formar = 1.0;
varying float onda;
void vertex() {
 float a = tempo * giro + (vertical ? 0.07 * sin(VERTEX.y * 1.7 - tempo * 3.0) : 0.0);
 float c = cos(a); float s = sin(a);
 if (vertical) { VERTEX.xz = mat2(vec2(c,s),vec2(-s,c)) * VERTEX.xz; }
 else { VERTEX.xy = mat2(vec2(c,s),vec2(-s,c)) * VERTEX.xy; }
 VERTEX.xz *= vertical ? mix(0.72, 1.0, formar) : 1.0;
 onda = 0.78 + 0.22 * sin(UV.x * 24.0 - tempo * 8.0);
}
void fragment() {
 float perfil = sin(UV.y * 3.14159265);
 float borda = smoothstep(0.02, 0.14, perfil);
 float ponta = smoothstep(0.0, 0.07, UV.x) * smoothstep(0.0, 0.07, 1.0-UV.x);
 // Faixa cel: margem verde escura, corpo saturado e lâmina marfim.
 vec3 tinta = mix(vec3(0.025,0.16,0.085), cor.rgb, step(0.34, perfil));
 ALBEDO = mix(tinta, vec3(0.89,1.0,0.78), step(0.90, perfil) * 0.8);
 ALPHA = cor.a * borda * ponta * intensidade;
}
"""
var _materiais: Array[ShaderMaterial] = []
var _shader: Shader
var _audio: AudioStreamPlayer3D
static var _som_vento: AudioStreamWAV

func configurar(modo: String, raio: float = 2.5, altura: float = 7.0) -> void:
	limpar()
	for filho in get_children():
		remove_child(filho)
		filho.queue_free()
	_materiais.clear()
	_audio = null
	_shader = Shader.new()
	_shader.code = CODIGO
	visible = true
	raio = maxf(raio, 0.1)
	altura = maxf(altura, 0.1)
	match modo:
		"tornado":
			for i in 3:
				_faixa(true, raio, altura, float(i) * TAU / 3.0, 1.25 + i * 0.09, 0.34 + i * 0.045, Color(0.27, 0.87, 0.38, 0.82), 3.6 + i * 0.18)
			for i in 3:
				_faixa(true, raio * 0.96, altura, float(i) * TAU / 3.0, 1.85, 0.035, Color(0.82, 1.0, 0.71, 0.9), 5.1)
			# Arcos abertos comunicam o raio de captura na base, sem disco opaco.
			for i in 3:
				_arco_chao(raio, float(i) * TAU / 3.0, 1.25, 0.07 + i * 0.045)
		"investida":
			for i in 6:
				_faixa(false, raio, altura, float(i) * TAU / 6.0, 0.32, 0.065, Color(0.76, 1.0, 0.83, 0.78), 3.2)
			for i in 3:
				_faixa(false, raio * 1.1, altura * 0.6, float(i) * TAU / 3.0, 0.82, 0.16, Color(0.44, 0.93, 0.62, 0.38), -2.1)
			for i in 7:
				_faixa(false, raio * (0.88 + float(i % 3) * 0.13), altura * 1.5, float(i) * TAU / 7.0, 0.025, 0.045, Color(0.87, 1.0, 0.81, 0.9), 0.25)
		"preparacao":
			for i in 4:
				_faixa(false, raio, altura, float(i) * TAU / 4.0, 0.7, 0.085, Color(0.58, 1.0, 0.66, 0.45), -2.5)
	if modo in ["tornado", "investida", "preparacao"]:
		_criar_audio(modo)
	atualizar(0.0, 0.0)

func atualizar(tempo: float, intensidade: float = 1.0) -> void:
	visible = intensidade > 0.001
	for mat in _materiais:
		mat.set_shader_parameter("tempo", tempo)
		mat.set_shader_parameter("intensidade", clampf(intensidade, 0.0, 1.0))
		mat.set_shader_parameter("formar", clampf(intensidade, 0.0, 1.0))
	if is_instance_valid(_audio):
		_audio.volume_db = -15.0 + linear_to_db(maxf(0.001, clampf(intensidade, 0.0, 1.0)))
		if visible and is_inside_tree() and not _audio.playing:
			_audio.play()
		elif not visible:
			_audio.stop()

func limpar() -> void:
	visible = false
	if is_instance_valid(_audio):
		_audio.stop()

func _exit_tree() -> void:
	limpar()

func _criar_audio(modo: String) -> void:
	if _som_vento == null:
		# Ruído de ar filtrado, determinístico e compartilhado. Sem arquivos externos
		# ou geração por quadro; transição circular evita clique no loop.
		const TAXA := 22050
		const N := TAXA * 2
		const COSTURA := 1102
		var rng := RandomNumberGenerator.new()
		rng.seed = 74513
		var amostras := PackedFloat32Array()
		var lento := 0.0
		var rapido := 0.0
		for i in N + COSTURA:
			var ruido := rng.randf_range(-1.0, 1.0)
			lento = lerpf(lento, ruido, 0.025)
			rapido = lerpf(rapido, ruido, 0.32)
			var t := float(i) / TAXA
			var modulacao := 0.76 + 0.14 * sin(t * TAU * 2.0) + 0.10 * sin(t * TAU * 3.5)
			amostras.append((rapido - lento * 0.75) * modulacao * 0.65)
		var dados := PackedByteArray()
		dados.resize(N * 2)
		for i in N:
			var valor := amostras[i + COSTURA]
			if i >= N - COSTURA:
				var f := float(i - (N - COSTURA)) / COSTURA
				valor = lerpf(valor, amostras[i - (N - COSTURA)], f)
			dados.encode_s16(i * 2, int(clampf(valor, -1, 1) * 32760.0))
		_som_vento = AudioStreamWAV.new()
		_som_vento.format = AudioStreamWAV.FORMAT_16_BITS
		_som_vento.mix_rate = TAXA
		_som_vento.data = dados
		_som_vento.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_som_vento.loop_end = N
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "ArEmMovimento"
	_audio.stream = _som_vento
	_audio.max_distance = 45.0
	_audio.unit_size = 7.0
	_audio.pitch_scale = 0.75 if modo == "tornado" else (1.35 if modo == "investida" else 0.95)
	_audio.volume_db = -18.0
	add_child(_audio)

func _faixa(vertical: bool, raio: float, altura: float, fase: float, voltas: float, largura: float, cor: Color, giro: float) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	const SEGMENTOS := 96
	for i in SEGMENTOS + 1:
		var t := float(i) / SEGMENTOS
		var a := fase + t * TAU * voltas
		var r := raio * (0.24 + 0.76 * pow(t, 0.65)) if vertical else raio * (0.45 + 0.55 * sin(t * PI * 0.8))
		for lado in 2:
			var h := (float(lado) - 0.5) * largura
			var v := Vector3(cos(a) * r, t * altura + h, sin(a) * r) if vertical else Vector3(cos(a) * (r + h), sin(a) * (r + h), (t - 0.25) * altura)
			vertices.append(v)
			uvs.append(Vector2(t, float(lado)))
		if i < SEGMENTOS:
			var b := i * 2
			indices.append_array(PackedInt32Array([b, b + 2, b + 1, b + 1, b + 2, b + 3]))
	_malha(vertices, uvs, indices, cor, vertical, giro)

func _arco_chao(raio: float, fase: float, extensao: float, y: float) -> void:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in 33:
		var t := float(i) / 32.0
		var a := fase + t * extensao
		for lado in 2:
			var r := raio - float(lado) * 0.16 * sin(t * PI)
			vertices.append(Vector3(cos(a) * r, y, sin(a) * r))
			uvs.append(Vector2(t, float(lado)))
		if i < 32:
			var b := i * 2
			indices.append_array(PackedInt32Array([b, b+2, b+1, b+1, b+2, b+3]))
	_malha(vertices, uvs, indices, Color(0.55, 0.92, 0.45, 0.8), true, 4.0)

func _malha(vertices: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, cor: Color, vertical: bool, giro: float) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("cor", cor)
	mat.set_shader_parameter("vertical", vertical)
	mat.set_shader_parameter("giro", giro)
	_materiais.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
