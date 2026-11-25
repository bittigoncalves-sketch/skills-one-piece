class_name CoracaoVoxel
extends SubViewportContainer
# O CORAÇÃO VOXEL da reanimação (04/11/2026): um coração 3D de cubos que gira devagar e PULSA a
# cada batida, mostrado numa SubViewport de fundo transparente por cima da tela.
#
# O volume vem da equação implícita clássica do coração 3D
#     (x² + 9/4·y² + z² − 1)³ − x²·z³ − 9/80·y²·z³ ≤ 0     (z = para cima aqui: `y` do voxel),
# amostrada numa grade de `RAIO` voxels e meshada pelo MESMO `ArvoreVoxel.construir` das árvores
# (faces internas removidas, 26 % dos cubos mais claros para dar textura sem shader).

const RAIO := 13
const TAMANHO_DO_VOXEL := 0.1
const COR_ESCURA := Color(0.46, 0.04, 0.09)
const COR := Color(0.82, 0.08, 0.14)
const COR_CLARA := Color(1.0, 0.33, 0.38)

var _raiz: Node3D
var _viewport: SubViewport
var _pulso := 0.0           # 1 na batida, decai
var _t := 0.0
var _batendo := true
static var _malha: ArrayMesh = null


## As células do coração (Vector3i -> parte), com a base em y = 0 e centrado em x/z.
static func celulas() -> Dictionary:
	var c := {}
	var k := 1.3 / RAIO
	for ix in range(-RAIO, RAIO + 1):
		for iy in range(-RAIO, RAIO + 1):
			for iz in range(-RAIO, RAIO + 1):
				var x := ix * k
				var z := iy * k            # vertical da equação = y do voxel
				var y := iz * k * 1.15     # profundidade (um pouco mais gordo que a fórmula)
				var a := x * x + 2.25 * y * y + z * z - 1.0
				if a * a * a - x * x * z * z * z - 0.1125 * y * y * z * z * z <= 0.0:
					# A parte de baixo fica mais escura (o "tronco" do gerador): dá volume.
					c[Vector3i(ix, iy + RAIO, iz)] = ArvoreVoxel.TRONCO if iy < -RAIO * 0.45 else ArvoreVoxel.COPA
	return c


static func malha() -> ArrayMesh:
	if _malha == null:
		_malha = ArvoreVoxel.construir(celulas(), AABB(), TAMANHO_DO_VOXEL)
		var cores := {"tronco": COR_ESCURA, "copa": COR, "copa_clara": COR_CLARA}
		for i in _malha.get_surface_count():
			var m := StandardMaterial3D.new()
			m.albedo_color = cores[_malha.surface_get_name(i)]
			m.roughness = 0.55
			m.emission_enabled = true
			m.emission = m.albedo_color * 0.35
			_malha.surface_set_material(i, m)
	return _malha


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300, 300)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(512, 512)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_CLEAR_COLOR
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.55, 0.45, 0.45)
	_viewport.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 40, 0)
	_viewport.add_child(luz)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.35, 4.3)
	_viewport.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.3, 0))
	_raiz = Node3D.new()
	_viewport.add_child(_raiz)
	var mi := MeshInstance3D.new()
	mi.mesh = malha()
	mi.position = Vector3(0, 0, 0)
	_raiz.add_child(mi)


## Uma batida: o coração incha e volta.
func bater(forca := 1.0) -> void:
	_pulso = clampf(forca, 0.0, 1.0)


## Parado = o coração congelado e escuro (tela inicial); batendo = vivo.
func definir_batendo(sim: bool) -> void:
	_batendo = sim


func _process(delta: float) -> void:
	_t += delta
	_pulso = maxf(_pulso - delta * 3.2, 0.0)
	var escala := 1.0 + 0.16 * _pulso * _pulso + (0.015 * sin(_t * 9.0) if _batendo else 0.0)
	_raiz.scale = Vector3.ONE * escala
	_raiz.rotation.y = sin(_t * 0.7) * 0.45


## Número de cubos (para testes).
static func total_de_cubos() -> int:
	return celulas().size()
