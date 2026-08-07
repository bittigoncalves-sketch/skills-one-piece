extends SceneTree
# Voxeliza a malha dos personagens para o editor em Python poder MOSTRAR o
# modelo e você posicionar os marcadores de junta em cima dele — o mesmo método
# do Meshy (ombro em cima do ombro de verdade).
#
# Python não lê .glb/.fbx/.scn (binários), então quem varre a malha é o Godot.
# Exporta só os voxels da SUPERFÍCIE (célula com vizinho vazio): o miolo não
# aparece e o editor desenha 10x menos quadrados.
#
# Personagens: os 6 do jogo + qualquer .glb/.fbx/.scn largado em
# assets/models/inbox/ (caso de uso real: modelo novo do Meshy, ainda sem rig).
#
# Uso: godot --headless --path . -s tools/export_mesh.gd

const SAIDA := "res://tools/anim_editor/meshes/"
const INBOX := "res://assets/models/inbox/"
const PERSONAGENS := ["base", "buggy", "nami", "ace", "blackbeard", "crocodile"]
const ALTURA_GRADE := 30      # células no eixo mais alto — mais que isso trava o tkinter
const MAX_VOXELS := 2600      # teto de segurança

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var indice: Array = []

	for cid in PERSONAGENS:
		var d := CharacterBuilder.build_character(cid)
		var no: Node3D = d["node"]
		get_root().add_child(no)
		var r = _voxelizar(no, cid, "jogo")
		if r != null:
			indice.append(r)
		no.queue_free()

	# modelos novos largados na inbox
	var dir := DirAccess.open(INBOX)
	if dir:
		for arq in dir.get_files():
			var b := arq.to_lower()
			if not (b.ends_with(".glb") or b.ends_with(".fbx") or b.ends_with(".scn") or b.ends_with(".tscn")):
				continue
			var no2 = _carregar_solto(INBOX + arq)
			if no2 == null:
				print("  ✗ não carregou: ", arq)
				continue
			get_root().add_child(no2)
			var r2 = _voxelizar(no2, arq.get_basename(), "inbox")
			if r2 != null:
				indice.append(r2)
			no2.queue_free()
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(INBOX))

	var f := FileAccess.open(SAIDA + "index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"models": indice}, "  "))
	f.close()
	print("MALHAS EXPORTADAS: ", indice.size())
	quit()

func _carregar_solto(caminho: String):
	if caminho.to_lower().ends_with(".glb"):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(caminho), st) != OK:
			return null
		return doc.generate_scene(st)
	if not ResourceLoader.exists(caminho):
		return null
	var packed = load(caminho)
	return packed.instantiate() if packed else null

# ------------------------------------------------------------- voxelização
func _voxelizar(raiz: Node3D, nome: String, origem: String):
	var malhas: Array = []
	_coletar(raiz, malhas)
	if malhas.is_empty():
		print("  ✗ ", nome, ": sem malha")
		return null

	# caixa envolvente no espaço do MODELO
	var ab := AABB()
	var primeiro := true
	for par in malhas:
		var mi: MeshInstance3D = par[0]
		var t: Transform3D = par[1]
		var caixa := t * mi.mesh.get_aabb()
		if primeiro:
			ab = caixa
			primeiro = false
		else:
			ab = ab.merge(caixa)
	if ab.size.y < 0.0001:
		return null

	var celula: float = ab.size.y / float(ALTURA_GRADE)
	var ocupado := {}
	for par in malhas:
		var mi: MeshInstance3D = par[0]
		var t: Transform3D = par[1]
		_marcar_malha(mi.mesh, t, ab.position, celula, ocupado)

	# só a casca: célula com algum vizinho vazio
	var superficie: Array = []
	for k in ocupado:
		var c: Vector3i = k
		var interno := true
		for d in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,1,0),
				Vector3i(0,-1,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			if not ocupado.has(c + d):
				interno = false
				break
		if not interno:
			superficie.append([c.x, c.y, c.z])
	if superficie.size() > MAX_VOXELS:
		superficie = _ralear(superficie, MAX_VOXELS)

	var dados := {
		"name": nome,
		"source": origem,
		"cell": snappedf(celula, 0.00001),
		"origin": [snappedf(ab.position.x, 0.00001), snappedf(ab.position.y, 0.00001),
				   snappedf(ab.position.z, 0.00001)],
		"size": [snappedf(ab.size.x, 0.00001), snappedf(ab.size.y, 0.00001),
				 snappedf(ab.size.z, 0.00001)],
		"voxels": superficie,
	}
	var f := FileAccess.open(SAIDA + nome + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(dados))
	f.close()
	print("  ✓ %-12s %d voxels  altura %.2fm  (%s)" % [nome, superficie.size(), ab.size.y, origem])
	return {"name": nome, "source": origem, "voxels": superficie.size(),
			"height": snappedf(ab.size.y, 0.001)}

# Acumula a transformação dos nós, mas guarda também a que vale ATÉ a Armature.
#
# Nos modelos Meshy a malha já vem em Y-up: `mesh.get_aabb()` da Nami dá
# (0.78, 1.70, 0.55) — 1,70 na altura. O giro de −90° em X da Armature existe
# para orientar o ESQUELETO (que é Z-up), não a malha. Aplicar esse giro na
# malha também deita o personagem — a altura vira 0,55. Então, para malha
# skinnada, usa-se a transformação de ANTES da Armature.
func _coletar(n: Node, out: Array, acc: Transform3D = Transform3D(),
		antes_arm: Transform3D = Transform3D(), dentro_arm: bool = false) -> void:
	var t := acc
	if n is Node3D:
		t = acc * (n as Node3D).transform

	var vai_entrar := dentro_arm
	if not dentro_arm and (n is Skeleton3D or String(n.name).begins_with("Armature")):
		vai_entrar = true      # daqui pra baixo é espaço do esqueleto

	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		out.append([mi, antes_arm if (dentro_arm or mi.skin != null) else t])

	var prox_antes := antes_arm if vai_entrar else t
	for c in n.get_children():
		_coletar(c, out, t, prox_antes, vai_entrar)

# Amostra cada triângulo denso o bastante para não deixar buraco na casca.
func _marcar_malha(malha: Mesh, t: Transform3D, base: Vector3, celula: float, ocupado: Dictionary) -> void:
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		if arr.is_empty() or arr[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		var total: int = (idx.size() if idx != null else verts.size())
		var i := 0
		while i + 2 < total:
			var a: Vector3 = t * verts[idx[i] if idx != null else i]
			var b: Vector3 = t * verts[idx[i + 1] if idx != null else i + 1]
			var c: Vector3 = t * verts[idx[i + 2] if idx != null else i + 2]
			var passos: int = int(ceil(maxf(maxf(a.distance_to(b), b.distance_to(c)),
					a.distance_to(c)) / (celula * 0.6))) + 1
			passos = clampi(passos, 1, 24)
			for u in passos + 1:
				for v in passos + 1 - u:
					var fu := float(u) / float(passos)
					var fv := float(v) / float(passos)
					var p: Vector3 = a + (b - a) * fu + (c - a) * fv
					ocupado[Vector3i(
						int(floor((p.x - base.x) / celula)),
						int(floor((p.y - base.y) / celula)),
						int(floor((p.z - base.z) / celula)))] = true
			i += 3

func _ralear(lista: Array, teto: int) -> Array:
	var passo: float = float(lista.size()) / float(teto)
	var out: Array = []
	var i := 0.0
	while int(i) < lista.size() and out.size() < teto:
		out.append(lista[int(i)])
		i += passo
	return out
