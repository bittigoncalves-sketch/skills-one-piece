extends Node3D
## Espuma com orçamento fixo: uma malha, até 40 marcas, sem emissores por frame.
## Os pontos ficam no mundo e acompanham a água enquanto a espuma se dissipa.
const MAX_MARCAS := 40
const VIDA := 4.0
const INTERVALO := 0.11
var _largura := 2.0
var _comprimento := 5.0
var _marcas: Array[Dictionary] = []
var _emissao := 0.0
var _desenho := 0.0
var _intensidade := 0.0
var _malha := ImmediateMesh.new()
var _vista: MeshInstance3D
var _material: StandardMaterial3D
var _ultima_posicao := Vector3.INF
var _vertices := PackedVector3Array()
var _cores := PackedColorArray()


func _ready() -> void:
	# Não herda balanço/escala do casco: a espuma pertence à superfície do mundo.
	top_level = true
	global_transform = Transform3D.IDENTITY
	_vista = MeshInstance3D.new()
	_vista.name = "Espuma"
	_vista.mesh = _malha
	_vista.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(0.84, 0.97, 1.0, 0.8)
	_material.no_depth_test = false
	_material.render_priority = 1
	_vista.material_override = _material
	add_child(_vista)


func configurar(largura: float, comprimento: float) -> void:
	_largura = maxf(largura, 0.4)
	_comprimento = maxf(comprimento, 0.6)


func limpar() -> void:
	_marcas.clear()
	_vertices.clear()
	_cores.clear()
	_malha.clear_surfaces()
	_emissao = 0.0
	_desenho = 0.0
	_intensidade = 0.0
	_ultima_posicao = Vector3.INF


func atualizar(posicao: Vector3, frente: Vector3, velocidade: float, delta: float, na_agua: bool) -> void:
	if _vista == null:
		return
	var dir := Vector3(frente.x, 0.0, frente.z).normalized()
	if dir.is_zero_approx():
		dir = Vector3.FORWARD
	if velocidade < 0.0:
		dir = -dir
	var direita := dir.cross(Vector3.UP)
	if _ultima_posicao.is_finite() and posicao.distance_to(_ultima_posicao) > maxf(_comprimento * 3.0, 30.0):
		_marcas.clear()
	_ultima_posicao = posicao
	for marca in _marcas:
		marca["idade"] += delta
	while not _marcas.is_empty() and float(_marcas[0]["idade"]) >= VIDA:
		_marcas.pop_front()
	var alvo := smoothstep(0.15, 4.0, absf(velocidade)) if na_agua else 0.0
	_intensidade = move_toward(_intensidade, alvo, delta * 2.5)
	_emissao += delta
	if na_agua and absf(velocidade) > 0.25 and _emissao >= INTERVALO:
		_emissao = fmod(_emissao, INTERVALO)
		# Uma amostra no máximo por atualização evita explosão após travadas.
		_marcas.append({"centro": posicao - dir * _comprimento * 0.40,
			"direita": direita, "idade": 0.0, "forca": _intensidade})
		if _marcas.size() > MAX_MARCAS:
			_marcas.pop_front()
	elif not na_agua or absf(velocidade) <= 0.25:
		_emissao = 0.0
	_desenho += delta
	if _desenho < 1.0 / 30.0:
		return
	_desenho = fmod(_desenho, 1.0 / 30.0)
	_desenhar(posicao, dir, direita, na_agua)


func _desenhar(posicao: Vector3, frente: Vector3, direita: Vector3, na_agua: bool) -> void:
	_malha.clear_surfaces()
	if _marcas.size() < 2 and (_intensidade < 0.01 or not na_agua):
		return
	_vertices.clear()
	_cores.clear()
	# Duas fitas afastam-se do rumo que o casco realmente percorreu. A curva
	# permanece na água quando o barco vira, em vez de girar como um decal filho.
	for i in range(1, _marcas.size()):
		var a := _marcas[i - 1]
		var b := _marcas[i]
		if (a["centro"] as Vector3).distance_to(b["centro"]) > _comprimento * 2.0:
			continue
		for lado in [-1.0, 1.0]:
			var pa: Vector3 = a["centro"] + a["direita"] * lado * (_largura * 0.43 + float(a["idade"]) * 0.75)
			var pb: Vector3 = b["centro"] + b["direita"] * lado * (_largura * 0.43 + float(b["idade"]) * 0.75)
			var faixa_a := 0.13 + float(a["idade"]) * 0.13
			var faixa_b := 0.13 + float(b["idade"]) * 0.13
			var alfa_a := float(a["forca"]) * pow(1.0 - float(a["idade"]) / VIDA, 1.8) * 0.65
			var alfa_b := float(b["forca"]) * pow(1.0 - float(b["idade"]) / VIDA, 1.8) * 0.65
			_faixa(pa, pb, a["direita"] * faixa_a, b["direita"] * faixa_b, alfa_a, alfa_b)
	# Arco de pressão: cresce com a velocidade e troca de ponta ao dar ré.
	if na_agua and _intensidade > 0.01:
		var proa := posicao + frente * _comprimento * 0.42
		for i in 10:
			var t0 := lerpf(-1.35, 1.35, float(i) / 10.0)
			var t1 := lerpf(-1.35, 1.35, float(i + 1) / 10.0)
			var ra := direita * sin(t0) + frente * cos(t0)
			var rb := direita * sin(t1) + frente * cos(t1)
			var a := proa + direita * sin(t0) * _largura * 0.45 + frente * cos(t0) * _largura * 0.12
			var b := proa + direita * sin(t1) * _largura * 0.45 + frente * cos(t1) * _largura * 0.12
			_faixa(a, b, ra * 0.14, rb * 0.14, _intensidade * 0.65, _intensidade * 0.65)
	if not _vertices.is_empty():
		_malha.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in _vertices.size():
			_malha.surface_set_color(_cores[i])
			_malha.surface_add_vertex(_vertices[i])
		_malha.surface_end()


func _faixa(a: Vector3, b: Vector3, raio_a: Vector3, raio_b: Vector3, alfa_a: float, alfa_b: float) -> void:
	# Bordas transparentes e miolo suave. Água seca corta cada trecho na costa.
	var pontos: Array[Vector3] = [a - raio_a, a, a + raio_a, b - raio_b, b, b + raio_b]
	for i in pontos.size():
		var y := AguaDoMundo.superficie_em(pontos[i].x, pontos[i].z)
		if is_nan(y):
			return
		pontos[i].y = y + 0.055
	for i in [0, 3, 1, 1, 3, 4, 1, 4, 2, 2, 4, 5]:
		var alfa := (alfa_a if i == 1 else alfa_b) if i == 1 or i == 4 else 0.0
		_cores.append(Color(1, 1, 1, alfa))
		_vertices.append(pontos[i])
