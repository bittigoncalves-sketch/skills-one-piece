extends Node3D
## Oceano visual do modo história/editor. Bases vêm do documento, nunca de uma
## segunda cópia do mapa. Duplicar baseplate no editor preserva o prefixo do id.
## Primeira etapa: superfície/ondas; não cria chão invisível nem simula natação.
const SHADER := preload("res://src/world/oceano_historia.gdshader")
const MAX_BASES := 64
const SEGMENTOS := 256

@export var nivel_relativo := -0.65
@export var largura_agua_clara := 85.0
@export var altura_ondas := 0.65
@export var velocidade_ondas := 1.0

var material: ShaderMaterial
var superficie: MeshInstance3D
var bases: Array[Dictionary] = []
var nivel := -0.65
var _documento: DocumentoMapa
var _atualizacao_pendente := false
var _tempo_simulado := 0.0


func configurar(mapa: Dictionary) -> void:
	bases.clear()
	for p: Dictionary in mapa.get("pecas", []):
		if e_base(p):
			bases.append(p)
	visible = not bases.is_empty()
	if bases.is_empty():
		return
	if bases.size() > MAX_BASES:
		push_warning("Oceano: as primeiras %d baseplates definem a costa nesta etapa." % MAX_BASES)
		bases.resize(MAX_BASES)
	if material == null:
		_criar_superficie()
	var caixas := PackedVector4Array()
	var giros := PackedVector2Array()
	caixas.resize(MAX_BASES)
	giros.resize(MAX_BASES)
	nivel = INF
	for i in bases.size():
		var p := bases[i]
		var pos: Vector3 = p["posicao"]
		var tam: Vector3 = p["tamanho"]
		var angulo := deg_to_rad((p["rotacao_graus"] as Vector3).y)
		caixas[i] = Vector4(pos.x, pos.z, tam.x * 0.5, tam.z * 0.5)
		giros[i] = Vector2(cos(angulo), sin(angulo))
		nivel = minf(nivel, pos.y + tam.y * 0.5 + nivel_relativo)
	position.y = nivel
	material.set_shader_parameter("bases", caixas)
	material.set_shader_parameter("giros", giros)
	material.set_shader_parameter("quantidade_bases", bases.size())
	material.set_shader_parameter("largura_raso", largura_agua_clara)
	material.set_shader_parameter("altura_ondas", altura_ondas)
	material.set_shader_parameter("velocidade", velocidade_ondas)


func ligar_editor(doc: DocumentoMapa) -> void:
	_documento = doc
	configurar(doc.para_mapa())
	doc.peca_adicionada.connect(_solicitar_atualizacao)
	doc.peca_mudou.connect(_solicitar_atualizacao)
	doc.peca_removida.connect(_solicitar_atualizacao)


func _solicitar_atualizacao(id: String) -> void:
	if not (id == "baseplate" or id.begins_with("baseplate_")) or _atualizacao_pendente:
		return
	_atualizacao_pendente = true
	_atualizar_documento.call_deferred()


func _atualizar_documento() -> void:
	_atualizacao_pendente = false
	configurar(_documento.para_mapa())


static func e_base(p: Dictionary) -> bool:
	var id := str(p.get("id", ""))
	return p.get("tipo") == "caixa" and (id == "baseplate" or id.begins_with("baseplate_"))


## Distância ao retângulo GIRADO, igual ao shader. Fora dos cantos usa distância
## euclidiana; entre ilhas prevalece a costa mais próxima, não a origem do mundo.
func distancia_da_costa(ponto: Vector2) -> float:
	var distancia := 1.0e6
	for p in bases:
		var pos: Vector3 = p["posicao"]
		var tam: Vector3 = p["tamanho"]
		var angulo := deg_to_rad((p["rotacao_graus"] as Vector3).y)
		var local := (ponto - Vector2(pos.x, pos.z)).rotated(angulo)
		var d := local.abs() - Vector2(tam.x, tam.z) * 0.5
		distancia = minf(distancia, d.max(Vector2.ZERO).length() + minf(maxf(d.x, d.y), 0.0))
	return distancia


## Réplica da ondulacao do shader em coordenadas mundiais. O tempo é compartilhado
## explicitamente: TIME do renderer pode avançar durante carregamento/pausa.
func superficie_em(x: float, z: float) -> float:
	var t := _tempo_simulado * velocidade_ondas
	var amplitude := altura_ondas
	if material != null:
		# ⚠️ `get_shader_parameter` devolve NULO para uniforme nunca definido no
		# material (o padrão do shader não volta por aqui). `tempo_fixo` só existe no
		# teste das ondas; no jogo `float(null)` estourava a cada amostra (03/10/2026).
		var fixo := _param("tempo_fixo", -1.0)
		t = (fixo if fixo >= 0.0 else _tempo_simulado) * _param("velocidade", velocidade_ondas)
		amplitude = _param("altura_ondas", altura_ondas)
	var p := Vector2(x, z)
	var d := distancia_da_costa(p)
	var mar := sin(p.dot(Vector2(0.105, 0.046)) - t * 1.05)
	mar += 0.48 * sin(p.dot(Vector2(-0.066, 0.16)) - t * 1.38 + 1.7)
	mar += 0.22 * sin(p.dot(Vector2(0.28, 0.19)) - t * 1.85)
	var perto := 1.0 - smoothstep(8.0, 65.0, d)
	var rebentacao := sin(d * 0.72 + t * 1.65 + sin(x * 0.10 + z * 0.07) * 0.35)
	return nivel + amplitude * (mar * 0.55 * lerpf(0.22, 1.0, 1.0 - perto) + rebentacao * 0.19 * perto)


func _param(nome: String, padrao: float) -> float:
	var v: Variant = material.get_shader_parameter(nome)
	return float(v) if v != null else padrao


func normal_em(x: float, z: float) -> Vector3:
	var h := superficie_em(x, z)
	return Vector3((h - superficie_em(x + 0.35, z)) / 0.35, 1.0,
		(h - superficie_em(x, z + 0.35)) / 0.35).normalized()


func _physics_process(delta: float) -> void:
	_tempo_simulado += delta
	if material != null:
		material.set_shader_parameter("tempo_simulado", _tempo_simulado)


func _criar_superficie() -> void:
	material = ShaderMaterial.new()
	material.shader = SHADER
	superficie = MeshInstance3D.new()
	superficie.name = "Superficie"
	superficie.mesh = _malha()
	superficie.material_override = material
	superficie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# O shader desloca vértices até ±altura_ondas; a caixa plana original cortaria
	# ondas na borda da câmera. Margem também cobre ajustes artísticos usuais.
	superficie.extra_cull_margin = 8.0
	add_child(superficie)


func _process(_delta: float) -> void:
	if not visible or material == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# O relevo usa coordenadas MUNDIAIS: seguir a câmera só move a tesselação,
	# não arrasta ondas/textura junto do jogador. Longe, a malha fica progressiva.
	global_position = Vector3(snappedf(camera.global_position.x, 1.0), nivel,
		snappedf(camera.global_position.z, 1.0))


static func _coordenada(i: int) -> float:
	var t := (float(i) / SEGMENTOS - 0.5) * 2.0
	var a := absf(t)
	return signf(t) * (a * 128.0 if a <= 0.75 else 96.0 + pow((a - 0.75) * 4.0, 2.0) * 15904.0)


static func _malha() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in SEGMENTOS + 1:
		for x in SEGMENTOS + 1:
			vertices.append(Vector3(_coordenada(x), 0.0, _coordenada(z)))
			normais.append(Vector3.UP)
	for z in SEGMENTOS:
		for x in SEGMENTOS:
			var a := z * (SEGMENTOS + 1) + x
			var c := a + SEGMENTOS + 1
			indices.append_array(PackedInt32Array([a, a + 1, c, a + 1, c + 1, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return malha
