extends Node3D
# ============================================================================
#  CARDUMES — peixes do mar (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E6).
#
#  Os peixes são os modelos da loja (categoria "pesca"). Eles têm esqueleto, e MultiMesh
#  não faz skinning: cada espécie é ASSADA uma vez na pose de repouso, levada ao espaço do
#  modelo e NORMALIZADA (comprimento 1, cabeça em −Z); cada superfície ganha o material de
#  nado (`peixe.gdshader`) com a cor original.
#
#  DESEMPENHO: a CPU move só o CENTRO de cada cardume (vaguear em volta de casa, fugir do
#  jogador, ficar entre o fundo e a superfície); rabo e oscilação de cada peixe são do
#  shader. Tudo só existe com a câmera SUBMERSA (a superfície é opaca — decisão do dono,
#  14/10), em blocos de 64 m em volta da câmera, determinísticos.
#  Peixes atravessam corais e cascos (decoração). Gatilho para desviar: o dono notar
#  peixe dentro de casco em captura/playtest.
# ============================================================================

const SHADER := preload("res://src/historia/mar/peixe.gdshader")
const BLOCO := 64.0
const RAIO_MONTAR := 110.0
const RAIO_SOLTAR := 170.0
const SEMENTE := 2027
const FUGIR_A := 7.0
## Tipos de cardume: espécies, peixes por cardume, comprimento (m), velocidade (m/s),
## raio da casa (m), espalhamento (m), onde vive.
const TIPOS := {
	"recife": {"especies": ["blue_tang", "yellow_tang", "clownfish", "zebra_clown_fish", "butterfly_fish",
		"moorish_idol", "royal_gramma", "cardinal_fish", "mandarin_fish", "tang"],
		"quantos": [10, 24], "tamanho": [0.42, 0.65], "velocidade": 1.6, "casa": 10.0, "espalha": 2.4},
	"recife_grande": {"especies": ["parrot_fish", "cowfish", "puffer", "lionfish", "coral_grouper"],
		"quantos": [3, 6], "tamanho": [0.6, 0.95], "velocidade": 1.2, "casa": 14.0, "espalha": 2.5},
	"aberto": {"especies": ["tuna", "red_snapper", "swordfish"],
		"quantos": [8, 16], "tamanho": [0.9, 1.5], "velocidade": 3.2, "casa": 30.0, "espalha": 3.5},
	"solitario": {"especies": ["humphead", "shark", "sunfish"],
		"quantos": [1, 1], "tamanho": [1.6, 2.8], "velocidade": 1.8, "casa": 25.0, "espalha": 0.0},
	"fossa": {"especies": ["anglerfish", "goblin_shark", "blobfish"],
		"quantos": [1, 3], "tamanho": [0.7, 1.2], "velocidade": 0.9, "casa": 12.0, "espalha": 2.0},
}

var relevo: RelevoMarinho
var jogador_de: Callable
var camera_de: Callable
var _bib: BibliotecaDeModelos
var _malhas := {}                    # espécie → ArrayMesh normalizada (ou null se falhou)
var _blocos := {}                    # Vector2i → Array[Dictionary] (cardumes)
var _relogio := 0.0


func ligar(contexto: Dictionary, campo: RelevoMarinho, jogador: Callable) -> void:
	relevo = campo
	jogador_de = jogador
	_bib = contexto.get("bib")


## A malha normalizada da espécie (assada uma vez). null se o modelo não serve.
func malha_de(especie: String) -> ArrayMesh:
	if _malhas.has(especie):
		return _malhas[especie]
	_malhas[especie] = _preparar(especie)
	return _malhas[especie]


func _preparar(especie: String) -> ArrayMesh:
	if _bib == null or not _bib.tem(especie):
		return null
	var raiz := _bib.instanciar(especie)
	if raiz == null:
		return null
	add_child(raiz)
	var mi := raiz.find_children("*", "MeshInstance3D", true, false)
	if mi.is_empty():
		raiz.free()
		return null
	var fonte := mi[0] as MeshInstance3D
	# Na pose de repouso, o skinning desta malha é a transformação do nó dela (o armature
	# do GLB tem escala 100 e gira Y↔Z). `bake_mesh_from_current_skeleton_pose` não serve:
	# a skin só é registrada no servidor de renderização (falha no headless). A conta é a
	# composição das transformações LOCAIS até a raiz — não depende de estar na árvore.
	var assada := fonte.mesh as ArrayMesh
	if assada == null:
		raiz.free()
		return null
	var rel := Transform3D.IDENTITY
	var n: Node = fonte
	while n != null and n != raiz:
		if n is Node3D:
			rel = (n as Node3D).transform * rel
		n = n.get_parent()
	# Caixa no espaço do modelo, eixo comprido e a ponta larga (cabeça).
	var caixa := AABB()
	var primeiro := true
	for s in assada.get_surface_count():
		for v in assada.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = rel * v
			caixa = AABB(p, Vector3.ZERO) if primeiro else caixa.expand(p)
			primeiro = false
	# Espaço do modelo da loja: Y para cima; o comprido é Z (ou X, se o modelo veio deitado).
	var eixo := Vector3.AXIS_Z if caixa.size.z >= caixa.size.x else Vector3.AXIS_X
	var comprimento := caixa.size[eixo]
	if comprimento <= 0.0:
		raiz.free()
		return null
	var centro := caixa.get_center()
	var largura := [0.0, 0.0]
	var contagem := [0, 0]
	var outro := Vector3.AXIS_X if eixo == Vector3.AXIS_Z else Vector3.AXIS_Z
	for s in assada.get_surface_count():
		for v in assada.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			var p: Vector3 = rel * v
			var t := (p[eixo] - caixa.position[eixo]) / comprimento
			var lado := 1 if t > 0.75 else (0 if t < 0.25 else -1)
			if lado >= 0:
				largura[lado] += absf(p[outro] - centro[outro])
				contagem[lado] += 1
	var cabeca_no_maximo: bool = largura[1] / maxi(contagem[1], 1) > largura[0] / maxi(contagem[0], 1)
	# Base que leva o eixo comprido a Z, com a cabeça em −Z; escala para comprimento 1.
	var base := Basis.IDENTITY
	if eixo == Vector3.AXIS_X:
		base = Basis(Vector3.UP, -PI / 2.0)
	var ponta := 1.0 if cabeca_no_maximo else -1.0
	if ponta > 0.0:
		base = Basis(Vector3.UP, PI) * base
	var final := Transform3D(base.scaled(Vector3.ONE / comprimento), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -centro) * rel
	var saida := ArrayMesh.new()
	for s in assada.get_surface_count():
		var arrays := assada.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in vs.size():
			vs[k] = final * vs[k]
			if k < ns.size():
				ns[k] = (final.basis * ns[k]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = vs
		arrays[Mesh.ARRAY_NORMAL] = ns
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		arrays[Mesh.ARRAY_TANGENT] = null
		saida.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var original := assada.surface_get_material(s)
		if original == null and fonte.mesh != null and s < fonte.mesh.get_surface_count():
			original = fonte.get_active_material(s)
		var m := ShaderMaterial.new()
		m.shader = SHADER
		m.set_shader_parameter("cor", (original as BaseMaterial3D).albedo_color if original is BaseMaterial3D else Color(0.8, 0.8, 0.8))
		m.set_shader_parameter("sombra_min", 0.5)
		m.set_shader_parameter("suavidade", 0.16)
		saida.surface_set_material(s, m)
	raiz.free()
	return saida


func _process(delta: float) -> void:
	if relevo == null or _bib == null:
		return
	var cam := _camera()
	if cam == null:
		return
	var p := cam.global_position
	visible = p.y < relevo.nivel + 0.3
	if not visible:
		return
	_relogio -= delta
	if _relogio <= 0.0:
		_relogio = 0.5
		_atualizar_blocos(Vector2(p.x, p.z))
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	for c in _blocos:
		for cardume: Dictionary in _blocos[c]:
			mover(cardume, delta, j.global_position if j != null else Vector3.INF)


func _camera() -> Camera3D:
	if camera_de.is_valid():
		return camera_de.call()
	return get_viewport().get_camera_3d() if is_inside_tree() else null


func _atualizar_blocos(p: Vector2) -> void:
	var r := int(ceil(RAIO_MONTAR / BLOCO))
	var c0 := Vector2i(floori(p.x / BLOCO), floori(p.y / BLOCO))
	var montados := 0
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var c := c0 + Vector2i(i, j)
			if not _blocos.has(c) and _centro(c).distance_to(p) < RAIO_MONTAR + BLOCO * 0.71 and montados < 2:
				_blocos[c] = _montar_bloco(c)
				montados += 1
	for c in _blocos.keys():
		if _centro(c).distance_to(p) > RAIO_SOLTAR:
			for cardume: Dictionary in _blocos[c]:
				(cardume["no"] as Node).queue_free()
			_blocos.erase(c)


## Garante os blocos em volta de p (testes e capturas).
func montar_em_volta(p: Vector2, raio := RAIO_MONTAR) -> void:
	var r := int(ceil(raio / BLOCO))
	var c0 := Vector2i(floori(p.x / BLOCO), floori(p.y / BLOCO))
	for j in range(-r, r + 1):
		for i in range(-r, r + 1):
			var c := c0 + Vector2i(i, j)
			if not _blocos.has(c) and _centro(c).distance_to(p) < raio + BLOCO * 0.71:
				_blocos[c] = _montar_bloco(c)


static func _centro(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * BLOCO


## Os cardumes de um bloco (sem nó): [{tipo, especie, casa: Vector3, quantos, tamanho}].
## Determinístico. Os testes leem daqui.
func planejar(c: Vector2i) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(c.x, c.y, SEMENTE))
	var origem := Vector2(c) * BLOCO
	for k in 6:
		var x := origem.x + rng.randf() * BLOCO
		var z := origem.y + rng.randf() * BLOCO
		var s := relevo.amostra(x, z)
		var prof := relevo.nivel - s.x
		var sorte := rng.randf()
		var tipo := ""
		if prof < 3.0:
			continue
		if s.z > 0.3 and sorte < 0.55:
			tipo = "recife"
		elif s.z > 0.3 and sorte < 0.75:
			tipo = "recife_grande"
		elif prof > 70.0 and sorte < 0.35:
			tipo = "fossa"
		elif prof > 25.0 and sorte < 0.12:
			tipo = "aberto"
		elif prof > 12.0 and sorte < 0.03:
			tipo = "solitario"
		if tipo.is_empty():
			continue
		var t: Dictionary = TIPOS[tipo]
		var especie: String = t["especies"][rng.randi() % (t["especies"] as Array).size()]
		var meio := minf(prof * 0.45, 6.0) if tipo.begins_with("recife") else prof * rng.randf_range(0.3, 0.7)
		saida.append({"tipo": tipo, "especie": especie, "casa": Vector3(x, s.x + maxf(1.5, meio), z),
			"quantos": rng.randi_range(t["quantos"][0], t["quantos"][1]),
			"tamanho": rng.randf_range(t["tamanho"][0], t["tamanho"][1]), "semente": rng.randi()})
	return saida


func _montar_bloco(c: Vector2i) -> Array[Dictionary]:
	var cardumes: Array[Dictionary] = []
	for plano in planejar(c):
		var malha := malha_de(plano["especie"])
		if malha == null:
			continue
		var t: Dictionary = TIPOS[plano["tipo"]]
		var rng := RandomNumberGenerator.new()
		rng.seed = plano["semente"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = malha
		mm.instance_count = plano["quantos"]
		var espalha: float = t["espalha"]
		for k in mm.instance_count:
			var o := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 0.5), rng.randf_range(-1.2, 1.2)) * espalha
			var escala: float = plano["tamanho"] * rng.randf_range(0.85, 1.15)
			mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)).scaled(Vector3.ONE * escala), o))
			mm.set_instance_custom_data(k, Color(rng.randf(), rng.randf(), rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.35)))
		var no := MultiMeshInstance3D.new()
		no.name = "Cardume_%s" % plano["especie"]
		no.multimesh = mm
		no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# A névoa da água (E7) deixa ~5 % a 70 m: além de 80 m o cardume não aparece.
		no.visibility_range_end = 80.0
		no.visibility_range_end_margin = 10.0
		no.extra_cull_margin = espalha + 2.0
		add_child(no)
		no.global_position = plano["casa"]
		cardumes.append({"no": no, "casa": plano["casa"], "tipo": plano["tipo"], "velocidade": Vector3.ZERO,
			"angulo": rng.randf() * TAU, "agitacao": 0.0, "tamanho": plano["tamanho"]})
	return cardumes


## Um passo do cardume: vaguear em volta da casa, fugir do jogador, ficar na água.
func mover(cardume: Dictionary, delta: float, jogador: Vector3) -> void:
	var no: Node3D = cardume["no"]
	var t: Dictionary = TIPOS[cardume["tipo"]]
	var casa: Vector3 = cardume["casa"]
	cardume["angulo"] += delta * float(t["velocidade"]) / maxf(float(t["casa"]), 1.0)
	var a: float = cardume["angulo"]
	var alvo := casa + Vector3(cos(a), sin(a * 1.7) * 0.25, sin(a)) * float(t["casa"])
	var desejado := (alvo - no.global_position).normalized() * float(t["velocidade"])
	var fugindo := jogador.is_finite() and no.global_position.distance_to(jogador) < FUGIR_A
	if fugindo:
		var longe := (no.global_position - jogador)
		longe.y *= 0.3
		desejado = longe.normalized() * float(t["velocidade"]) * 3.0
	cardume["agitacao"] = move_toward(float(cardume["agitacao"]), 1.0 if fugindo else 0.0, delta * (4.0 if fugindo else 0.6))
	var v: Vector3 = cardume["velocidade"]
	v = v.lerp(desejado, clampf(delta * (3.0 if fugindo else 1.2), 0.0, 1.0))
	cardume["velocidade"] = v
	var p := no.global_position + v * delta
	var chao := relevo.altura(p.x, p.z)
	var tam: float = cardume["tamanho"]
	p.y = clampf(p.y, chao + 0.6 + tam, relevo.nivel - 1.0 - tam)
	no.global_position = p
	if v.length() > 0.05:
		# A cabeça é −Z, e `looking_at` aponta o −Z para onde o cardume nada.
		var alvo_base := Basis.looking_at(v.normalized(), Vector3.UP)
		no.global_basis = no.global_basis.slerp(alvo_base, clampf(delta * 3.0, 0.0, 1.0)).orthonormalized()
	no.set_instance_shader_parameter("agitacao", cardume["agitacao"])


## Quantos cardumes montados (medições e testes).
func cardumes_montados() -> int:
	var n := 0
	for c in _blocos:
		n += (_blocos[c] as Array).size()
	return n
