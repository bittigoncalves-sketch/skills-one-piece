extends Node3D
# ============================================================================
#  RECIFES — corais, algas e bichos de fundo plantados no relevo marinho
#  (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E2). Direção do dono: "One Piece vibrante".
#
#  Onde cresce o quê sai do `RelevoMarinho` (fonte única): máscara de recife (baixios da
#  plataforma, 4–18 m), de rocha e a profundidade. Determinístico: a mesma semente planta o
#  mesmo recife sempre (nada vai para o arquivo do mapa — milhares de instâncias).
#
#  DESEMPENHO (escolhas medidas na E2/E7):
#   - blocos de 64 m montados SOB DEMANDA perto da câmera (no máximo um por quadro) e
#     soltos longe; cada bloco = um MultiMesh por espécie presente (poucas chamadas);
#   - alcance de desenho por bloco (`ALCANCE_DE_DESENHO`);
#   - tudo escondido com a câmera fora d'água: a superfície é opaca (decisão do dono,
#     14/10 — o fundo só aparece mergulhando), então desenhar corais de cima é desperdício.
#  Sem colisão (decoração): nadar atravessa. Gatilho: o dono pedir apoio/bloqueio nos
#  corais grandes → esferas só nas espécies grandes, só no bloco do jogador.
# ============================================================================

const MODELOS := "res://assets/models/mar/corais.glb"
const SHADER := preload("res://src/historia/mar/coral.gdshader")
const BLOCO := 64.0
const PASSO := 2.5                      # grade de candidatos (com jitter)
const RAIO_MONTAR := 150.0
const RAIO_SOLTAR := 230.0
const ALCANCE_DE_DESENHO := 120.0
const SEMENTE := 1410

## Espécies: malha no GLB, paleta (base, ponta) ×4 em sRGB, escala, balanço, detalhe,
## quanto afunda no chão (fração da altura) e se inclina com o chão.
const ESPECIES := {
	"coral_ramo": {"paleta": [["#ff6f61", "#ffd1a6"], ["#ff4f9a", "#ffc2e0"], ["#ff9f1c", "#ffe08a"], ["#b05cff", "#f0c8ff"]],
		"escala": [0.8, 1.6], "balanco": 0.0, "detalhe": 0.45, "afunda": 0.06, "inclina": 0.5},
	"coral_cerebro": {"paleta": [["#d9a404", "#ffe36e"], ["#e8577a", "#ffb3c4"], ["#7bc96f", "#d8f5b0"], ["#c47ae0", "#f2d0ff"]],
		"escala": [0.8, 1.9], "balanco": 0.0, "detalhe": -0.35, "afunda": 0.12, "inclina": 0.8},
	"coral_leque": {"paleta": [["#c8327f", "#ff8cc4"], ["#e0453f", "#ffa08f"], ["#8a55e6", "#d6b8ff"], ["#ff8a1f", "#ffd98a"]],
		"escala": [0.8, 1.5], "balanco": 0.55, "detalhe": 0.35, "afunda": 0.03, "inclina": 0.2},
	"coral_tubos": {"paleta": [["#7b2cbf", "#e0aaff"], ["#f4a300", "#ffe066"], ["#ef476f", "#ffc6d3"], ["#06a77d", "#9ef0c9"]],
		"escala": [0.8, 1.5], "balanco": 0.0, "detalhe": 0.35, "afunda": 0.05, "inclina": 0.4},
	"coral_mesa": {"paleta": [["#2a9d8f", "#a8f0e0"], ["#4cae4c", "#c9f29b"], ["#3a86ff", "#a9d1ff"], ["#e76f51", "#ffd0b5"]],
		"escala": [0.9, 1.8], "balanco": 0.0, "detalhe": 0.3, "afunda": 0.05, "inclina": 0.3},
	"anemona": {"paleta": [["#ff5d8f", "#fff0f5"], ["#ffb703", "#fff3b0"], ["#8338ec", "#e2ccff"], ["#00b4d8", "#caf0f8"]],
		"escala": [0.9, 1.8], "balanco": 0.45, "detalhe": 0.5, "afunda": 0.05, "inclina": 0.7},
	"alga": {"paleta": [["#3f8f6a", "#a8e6c1"], ["#7a9a3c", "#d7e87f"], ["#9a7330", "#e3b882"], ["#2a9d8f", "#9df0dc"]],
		"escala": [0.7, 1.4], "balanco": 1.0, "detalhe": 0.25, "afunda": 0.0, "inclina": 0.0},
	"coral_bolhas": {"paleta": [["#48cae4", "#e0fbff"], ["#f6bd60", "#fff7e0"], ["#f7a1c4", "#fff0f6"], ["#90e0a0", "#efffef"]],
		"escala": [0.9, 1.7], "balanco": 0.0, "detalhe": 0.4, "afunda": 0.1, "inclina": 0.6},
	"estrela": {"paleta": [["#ff6b35", "#ffb38a"], ["#e63946", "#ff9aa2"], ["#ffbe0b", "#fff1a8"], ["#9b5de5", "#e3c8ff"]],
		"escala": [1.0, 1.8], "balanco": 0.0, "detalhe": 0.5, "afunda": 0.2, "inclina": 1.0},
	"ourico": {"paleta": [["#240046", "#7b2cbf"], ["#10002b", "#3c096c"], ["#03045e", "#0077b6"], ["#370617", "#9d0208"]],
		"escala": [0.9, 1.5], "balanco": 0.0, "detalhe": 0.0, "afunda": 0.15, "inclina": 0.8},
}
## Peso de cada espécie no miolo do recife (as colônias escolhem pela vizinhança).
const PESO_RECIFE := {"coral_ramo": 22.0, "coral_cerebro": 14.0, "coral_leque": 9.0, "coral_tubos": 12.0,
	"coral_mesa": 10.0, "anemona": 10.0, "coral_bolhas": 10.0}

var relevo: RelevoMarinho
## Devolve a câmera ativa (padrão: a do viewport).
var camera_de: Callable

var _malhas := {}
var _materiais := {}
var _blocos := {}                       # Vector2i → Node3D
var _fila: Array[Vector2i] = []
var _relogio := 0.0
var _colonias := FastNoiseLite.new()
var _florestas := FastNoiseLite.new()


func configurar(campo: RelevoMarinho) -> void:
	relevo = campo
	_colonias.seed = SEMENTE
	_colonias.frequency = 1.0 / 18.0
	_colonias.noise_type = FastNoiseLite.TYPE_CELLULAR
	_colonias.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_florestas.seed = SEMENTE + 1
	_florestas.frequency = 1.0 / 90.0
	_carregar_modelos()


func _carregar_modelos() -> void:
	var cena: PackedScene = load(MODELOS)
	if cena == null:
		push_warning("[Recifes] modelos ausentes: " + MODELOS)
		return
	var raiz := cena.instantiate()
	for nome in ESPECIES:
		var mi := raiz.find_child(nome, true, false) as MeshInstance3D
		if mi == null:
			push_warning("[Recifes] espécie sem malha no GLB: " + nome)
			continue
		_malhas[nome] = mi.mesh
		_materiais[nome] = _material(ESPECIES[nome])
	raiz.free()


static func _material(e: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	var bases: Array[Vector4] = []
	var pontas: Array[Vector4] = []
	for par in e["paleta"]:
		var b := Color(par[0]).srgb_to_linear()
		var p := Color(par[1]).srgb_to_linear()
		bases.append(Vector4(b.r, b.g, b.b, 1.0))
		pontas.append(Vector4(p.r, p.g, p.b, 1.0))
	m.set_shader_parameter("bases", bases)
	m.set_shader_parameter("pontas", pontas)
	m.set_shader_parameter("balanco", float(e["balanco"]))
	m.set_shader_parameter("detalhe_forca", float(e["detalhe"]))
	m.set_shader_parameter("sombra_min", 0.5)
	m.set_shader_parameter("suavidade", 0.16)
	return m


func _process(delta: float) -> void:
	if relevo == null or _malhas.is_empty():
		return
	var cam := _camera()
	if cam == null:
		return
	var p := cam.global_position
	var nivel := relevo.nivel
	visible = p.y < nivel + 0.3
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = 0.25
		_atualizar_fila(Vector2(p.x, p.z))
	if not _fila.is_empty():
		var c: Vector2i = _fila.pop_front()
		if not _blocos.has(c):
			_blocos[c] = _montar_bloco(c)


func _camera() -> Camera3D:
	if camera_de.is_valid():
		return camera_de.call()
	return get_viewport().get_camera_3d() if is_inside_tree() else null


func _atualizar_fila(p: Vector2) -> void:
	_fila.clear()
	var r := int(ceil(RAIO_MONTAR / BLOCO))
	var c0 := Vector2i(floori(p.x / BLOCO), floori(p.y / BLOCO))
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var c := c0 + Vector2i(i, j)
			if not _blocos.has(c) and _centro(c).distance_to(p) < RAIO_MONTAR + BLOCO * 0.71:
				_fila.append(c)
	_fila.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _centro(a).distance_squared_to(p) < _centro(b).distance_squared_to(p))
	for c in _blocos.keys():
		if _centro(c).distance_to(p) > RAIO_SOLTAR:
			var n: Node = _blocos[c]
			if n != null:
				n.queue_free()
			_blocos.erase(c)


static func _centro(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * BLOCO


## Garante os blocos em volta de p já montados (testes e capturas: sem esperar quadros).
func montar_em_volta(p: Vector2, raio := RAIO_MONTAR) -> void:
	var r := int(ceil(raio / BLOCO))
	var c0 := Vector2i(floori(p.x / BLOCO), floori(p.y / BLOCO))
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var c := c0 + Vector2i(i, j)
			if not _blocos.has(c) and _centro(c).distance_to(p) < raio + BLOCO * 0.71:
				_blocos[c] = _montar_bloco(c)


## Instâncias de um bloco: espécie → Array[Transform3D] (+ dados). Puro (sem nó):
## os testes leem daqui.
func plantar(c: Vector2i) -> Dictionary:
	var saida := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, SEMENTE))
	var origem := Vector2(c) * BLOCO
	var n := int(BLOCO / PASSO)
	for j in n:
		for i in n:
			var x := origem.x + (i + rng.randf()) * PASSO
			var z := origem.y + (j + rng.randf()) * PASSO
			var sorte := rng.randf()
			var s := relevo.amostra(x, z)
			var prof := relevo.nivel - s.x
			if prof < 3.0 or prof > 70.0:
				continue
			var especie := _escolher(rng, sorte, x, z, s, prof)
			if especie.is_empty() or not _malhas.has(especie):
				continue
			if not saida.has(especie):
				saida[especie] = []
			saida[especie].append(_instancia(rng, especie, x, z, s))
	return saida


## Qual espécie (ou nenhuma) nasce num candidato.
func _escolher(rng: RandomNumberGenerator, sorte: float, x: float, z: float, s: Vector4, prof: float) -> String:
	var recife := s.z
	if recife > 0.05 and sorte < pow(recife, 1.3) * 0.7:
		# Colônia: a célula do ruído celular puxa uma espécie dominante (manchas de uma
		# espécie só, como no recife de verdade); 35 % dos candidatos sorteiam livre.
		if rng.randf() < 0.65:
			return _sortear_peso(_colonias.get_noise_2d(x, z) * 0.5 + 0.5)
		return _sortear_peso(rng.randf())
	var floresta := _florestas.get_noise_2d(x, z)
	if floresta > 0.3 and prof > 7.0 and prof < 32.0 and s.y < 0.4 and sorte < (floresta - 0.3) * 0.9:
		return "alga"
	if s.y > 0.4:
		if sorte < 0.05:
			return "anemona"
		if sorte < 0.08:
			return "ourico"
		if sorte < 0.1 and prof > 12.0:
			return "coral_leque"
		return ""
	if prof < 28.0:
		if sorte < 0.008:
			return "estrela"
		if sorte < 0.012:
			return "ourico"
	return ""


static func _sortear_peso(u: float) -> String:
	var total := 0.0
	for k in PESO_RECIFE:
		total += PESO_RECIFE[k]
	var alvo := clampf(u, 0.0, 0.9999) * total
	for k in PESO_RECIFE:
		alvo -= PESO_RECIFE[k]
		if alvo < 0.0:
			return k
	return "coral_ramo"


func _instancia(rng: RandomNumberGenerator, especie: String, x: float, z: float, s: Vector4) -> Dictionary:
	var e: Dictionary = ESPECIES[especie]
	var escala := rng.randf_range(e["escala"][0], e["escala"][1]) * (1.0 + s.z * 0.35)
	var y := s.x
	# Normal do chão pelas diferenças do campo (0,5 m).
	var hx := relevo.altura(x + 0.5, z) - relevo.altura(x - 0.5, z)
	var hz := relevo.altura(x, z + 0.5) - relevo.altura(x, z - 0.5)
	var normal := Vector3(-hx, 1.0, -hz).normalized()
	var cima := Vector3.UP.slerp(normal, float(e["inclina"]))
	var giro := Basis(Vector3.UP, rng.randf() * TAU)
	var alinha := Basis(Quaternion(Vector3.UP, cima))
	var base := (alinha * giro).scaled(Vector3.ONE * escala)
	var afunda := float(e["afunda"]) * escala
	var malha: Mesh = _malhas[especie]
	afunda *= malha.get_aabb().size.y
	return {
		"transform": Transform3D(base, Vector3(x, y - afunda, z)),
		"custom": Color(rng.randf(), rng.randf(), rng.randf_range(0.7, 1.2), rng.randf_range(0.88, 1.08)),
	}


func _montar_bloco(c: Vector2i) -> Node3D:
	var no := Node3D.new()
	no.name = "Recife_%d_%d" % [c.x, c.y]
	add_child(no)
	var plantas := plantar(c)
	for especie in plantas:
		var lista: Array = plantas[especie]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _malhas[especie]
		mm.instance_count = lista.size()
		for k in lista.size():
			mm.set_instance_transform(k, lista[k]["transform"])
			mm.set_instance_custom_data(k, lista[k]["custom"])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = especie
		mmi.multimesh = mm
		mmi.material_override = _materiais[especie]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = ALCANCE_DE_DESENHO
		mmi.visibility_range_end_margin = 10.0
		no.add_child(mmi)
	return no


## Quantos blocos montados (medições e testes).
func blocos_montados() -> int:
	return _blocos.size()
