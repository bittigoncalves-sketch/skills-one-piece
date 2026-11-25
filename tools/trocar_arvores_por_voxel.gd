extends SceneTree
## Troca o VISUAL de todas as árvores do Modo História por árvores voxel
## (`ArvoreVoxel`), mantendo o resto de cada .glb: nós `Colisao*`, pontos `Fruta_*`,
## hierarquia e a MESMA caixa — por isso catálogo, escala, colisão, LOD e mapas seguem valendo.
##   godot --headless --path . --script tools/trocar_arvores_por_voxel.gd
## Depois: godot --headless --path . --import
## Os originais vão para art_src/backups/arvores_antes_voxel_2026-11-04/ (restaurar = copiar de volta
## os .glb e o catalogo.json, ou `git checkout` se estiverem limpos no git).
## Opcional: `-- id1 id2` troca só esses modelos.
## Idempotente: refaz a partir do que está na pasta, mas a altura/forma vêm só do id, não do desenho.

const PASTA := "res://mapas/modelos"
const BACKUP := "res://art_src/backups/arvores_antes_voxel_2026-11-04"
# Variante dos cocos por palmeira (ArvoreVoxel._cocos): 0 verdes, 1 secos, 2 mistos.
const COCOS := {"palm_tree": 0, "palm_tree-a6ckjyfsib": 1, "palm_tree-p0tgwyxbgr": 2,
	"palmeira_adulta": 1, "palmeira_jovem": 0, "palmeira_muda": 2, "palmeira_broto_alto": 0, "palmeira_broto": 1}
const VOXEL_ALVO := 0.35   # metros de mundo por voxel (tamanho_padrao do catálogo)

# Paletas naturais por família: [tronco, copa, corte(toco)].
const P_CARVALHO := ["7a5230", "4f9d3a"]
const P_VERDE := ["6b4a2b", "4f9d3a"]
const P_PARQUE := ["7a5a38", "5ab04a"]
const P_OLMO := ["6b4a2b", "5fa862"]
const P_BORDO := ["6b4a2b", "c0392b"]
const P_VENTO := ["5a3e28", "2f6b4d"]
const P_BETULA := ["e8e0cf", "6fb458"]
const P_VISCO := ["7a5230", "3d7a45"]
const P_PINHO := ["5e4128", "2f6b34"]
const P_ABETO := ["5e4128", "24604f"]
const P_CIPRESTE := ["5e4128", "2f6e3d"]
const P_PALMEIRA := ["8a6a45", "3f9a45"]
const P_CEREJA := ["5a3a2a", "f2a3c4"]
const P_GIGANTE := ["7a5a3a", "3f8f3a"]
const P_TOCO := ["6b4a2b", "6b4a2b", "d9b382"]

static func receita(id: String) -> Array:   # [forma, paleta] ou [] se não é árvore
	var r := id.replace("floresta_tree_", "")
	if id == "trees": return ["carvalho", P_VERDE]
	if id == "pine_trees": return ["pinheiro", P_PINHO]
	if id.begins_with("trees_cut"): return ["toco", P_TOCO]
	if id.begins_with("palm_tree"): return ["palmeira", P_PALMEIRA]
	if id.begins_with("toco_") or id == "floresta_tree_stump": return ["toco", P_TOCO]
	if id.begins_with("palmeira_"): return ["palmeira", P_PALMEIRA]
	if id.begins_with("cerejeira_"): return ["acacia", P_CEREJA]
	if id.begins_with("pinheiro_"): return ["pinheiro", P_PINHO]
	if id == "arvore_gigante": return ["baobab", P_GIGANTE]
	if id.begins_with("arvore_verde_"): return ["carvalho", P_VERDE]
	if not id.begins_with("floresta_tree_"): return []
	if r.begins_with("oak") or r.begins_with("simple"): return ["carvalho", P_CARVALHO]
	if r.begins_with("park"): return ["carvalho", P_PARQUE]
	if r.begins_with("maple"): return ["carvalho", P_BORDO]
	if r.begins_with("elm"): return ["acacia", P_OLMO]
	if r.begins_with("windswept"): return ["acacia", P_VENTO]
	if r.begins_with("birch"): return ["salgueiro", P_BETULA]
	if r.begins_with("with_mistletoe"): return ["salgueiro", P_VISCO]
	if r.begins_with("pine"): return ["pinheiro", P_PINHO]
	if r.begins_with("spruce"): return ["pinheiro", P_ABETO]
	if r.begins_with("cypress"): return ["pinheiro", P_CIPRESTE]
	return []

func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var feitos := 0
	var falhas: Array[String] = []
	var tri_max := 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP))
	var cat := ProjectSettings.globalize_path(PASTA.path_join("catalogo.json"))
	if not FileAccess.file_exists(ProjectSettings.globalize_path(BACKUP + "/catalogo.json")):
		DirAccess.copy_absolute(cat, ProjectSettings.globalize_path(BACKUP + "/catalogo.json"))
	var so := OS.get_cmdline_user_args()   # -- id_do_modelo ... : só esses (teste rápido)
	for id in bib.ids():
		var rec := receita(id)
		if rec.is_empty() or (not so.is_empty() and not so.has(id)):
			continue
		var erro := _trocar(bib, id, rec)
		if erro.is_empty():
			feitos += 1
			tri_max = maxi(tri_max, int(bib.info(id)["triangulos"]))
		else:
			falhas.append("%s: %s" % [id, erro])
	print("Árvores trocadas: %d | maior malha: %d triângulos" % [feitos, tri_max])
	for f in falhas:
		push_error(f)
	quit(0 if falhas.is_empty() else 1)

func _trocar(bib: BibliotecaDeModelos, id: String, rec: Array) -> String:
	var caminho := PASTA.path_join(id + ".glb")
	var absoluto := ProjectSettings.globalize_path(caminho)
	var copia := ProjectSettings.globalize_path(BACKUP + "/" + id + ".glb")
	# O backup guarda SEMPRE o original: nunca sobrescreve um que já exista.
	if not FileAccess.file_exists(copia):
		DirAccess.copy_absolute(absoluto, copia)
		var colisao := ProjectSettings.globalize_path(bib.caminho_das_partes(id))
		if FileAccess.file_exists(colisao):
			DirAccess.copy_absolute(colisao, ProjectSettings.globalize_path(BACKUP + "/" + id + ".colisao.json"))
	var cena := BibliotecaDeModelos.carregar_glb(copia)   # sempre parte do original
	if cena == null:
		return "não abriu o .glb"
	var visuais: Array[MeshInstance3D] = []
	for no in cena.find_children("*", "MeshInstance3D", true, false):
		if not BibliotecaDeModelos.e_malha_de_colisao(no) and (no as MeshInstance3D).mesh != null:
			visuais.append(no)
	if visuais.size() != 1:
		cena.free()
		return "esperava 1 malha visual, achei %d" % visuais.size()
	var mi := visuais[0]
	# Tudo é construído no espaço do MODELO (eixo Y = para cima de verdade) e só no fim
	# levado ao espaço da malha: alguns .glb têm o nó da malha girado (Z-up do Blender).
	var mi_raiz := BibliotecaDeModelos._transformacao_ate(mi, cena)
	var destino: AABB = BibliotecaDeModelos.medir(cena)["aabb"]
	var info := bib.info(id)
	var tp: Vector3 = info.get("tamanho_padrao", info["tamanho"])
	var h := clampi(roundi(tp.y / VOXEL_ALVO), 6, 24)
	var lado := destino.size.y / h
	var forma: String = rec[0]
	var paleta: Array = rec[1]
	var partes_colisao: Array = []
	var celulas: Dictionary
	if id == "trees" or id == "pine_trees" or id.begins_with("trees_cut"):
		var n := 10 if id == "pine_trees" else 12
		var agrupado := _grupo(forma, n, destino, id)
		celulas = agrupado["celulas"]
		if forma != "toco":
			partes_colisao = agrupado["troncos"]
	else:
		celulas = ArvoreVoxel.celulas(forma, h, destino.size.x / (2.0 * lado), destino.size.z / (2.0 * lado), COCOS.get(id, hash(id)))
	# `medir` (e portanto o catálogo) usa o AABB LOCAL da malha levado à raiz: se o nó da malha
	# estiver girado fora dos eixos, esse AABB é mais folgado que a geometria. Ajusta o destino
	# até a caixa medida bater com a do original (converge em 1 passo quando não há giro).
	var alvo := destino
	var malha: ArrayMesh
	for passo in 14:
		malha = ArvoreVoxel.construir(celulas, destino, ArvoreVoxel.TAMANHO, mi_raiz.affine_inverse())
		var medida_: AABB = mi_raiz * malha.get_aabb()
		if (medida_.size - alvo.size).length() <= alvo.size.length() * 0.002 \
				and (medida_.position - alvo.position).length() <= alvo.size.length() * 0.002:
			break
		destino.size *= alvo.size / medida_.size
		destino.position += alvo.get_center() - medida_.get_center()
	var cores := {"tronco": Color(paleta[0]), "copa": Color(paleta[1]),
		"copa_clara": Color(paleta[1]).lightened(0.14),
		"corte": Color(paleta[2]) if paleta.size() > 2 else Color(paleta[0]),
		"coco_verde": Color("7ac143"), "coco_seco": Color("4a2f1a")}
	for i in malha.get_surface_count():
		var m := StandardMaterial3D.new()
		m.albedo_color = cores[malha.surface_get_name(i)]
		m.resource_name = "voxel_" + malha.surface_get_name(i)
		m.roughness = 1.0
		malha.surface_set_material(i, m)
	var invertidas := ArvoreVoxel.faces_invertidas(malha)
	if invertidas > 0:
		cena.free()
		return "%d faces invertidas na malha gerada" % invertidas
	mi.mesh = malha
	mi.material_override = null
	# Frutas penduradas: os `Fruta_*` do modelo antigo ficavam na copa antiga.
	var marcas := cena.find_children("Fruta_*", "Node3D", true, false)
	if not marcas.is_empty():
		var aj := ArvoreVoxel.ajuste(celulas, destino)
		var pts := ArvoreVoxel.pontos_de_fruta(celulas, marcas.size())
		for i in mini(marcas.size(), pts.size()):
			var no := marcas[i] as Node3D
			var no_modelo: Vector3 = aj["origem"] + (pts[i] + Vector3(0, 0.15, 0)) * aj["k"]
			var pai := BibliotecaDeModelos._transformacao_ate(no.get_parent() as Node3D, cena)
			no.position = pai.affine_inverse() * no_modelo
	var gltf := GLTFDocument.new()
	var estado := GLTFState.new()
	if gltf.append_from_scene(cena, estado) != OK or gltf.write_to_filesystem(estado, absoluto) != OK:
		cena.free()
		return "falhou ao exportar"
	var troncos_raiz: Array = []
	for t: PackedVector3Array in partes_colisao:
		var pts_raiz := PackedVector3Array()
		var aj2 := ArvoreVoxel.ajuste(celulas, destino)
		for v in t:
			pts_raiz.append(aj2["origem"] + v * aj2["k"])
		troncos_raiz.append(pts_raiz)
	cena.free()
	# Catálogo: sha/caixa/triângulos do arquivo novo. O resto (tamanho_padrao, frutífera,
	# categorias...) a própria `adicionar` preserva.
	var nova := BibliotecaDeModelos.carregar_glb(absoluto)
	if nova == null:
		return "o .glb novo não reabre"
	var medida := BibliotecaDeModelos.medir(nova)
	nova.free()
	var caixa: AABB = medida["aabb"]
	info.merge({"sha256": FileAccess.get_sha256(absoluto), "centro": caixa.get_center(),
		"tamanho": caixa.size, "triangulos": medida["triangulos"]}, true)
	if bib.adicionar(info) != OK:
		return "falhou ao gravar o catálogo"
	if not troncos_raiz.is_empty() and bib.definir_partes_de_colisao(id, troncos_raiz) != OK:
		return "falhou ao gravar a colisão em partes"
	return ""

## Bosque: `n` mini-árvores numa grade irregular que cobre a caixa. Devolve as células e,
## por árvore, os 8 cantos do tronco (para a colisão em partes), em unidades de voxel.
func _grupo(forma: String, n: int, destino: AABB, id: String) -> Dictionary:
	var celulas := {}
	var troncos: Array[PackedVector3Array] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var cols := ceili(sqrt(n * destino.size.x / maxf(destino.size.z, 0.0001)))
	var lin := ceili(n / float(cols))
	var passo := 6
	var h := 10 if forma == "pinheiro" else 8
	var feitas := 0
	for j in lin:
		for i in cols:
			if feitas >= n:
				break
			feitas += 1
			var o := Vector3i(i * passo + rng.randi_range(-1, 1), 0, j * passo + rng.randi_range(-1, 1))
			var hh := h + rng.randi_range(-1, 2)
			var arv := ArvoreVoxel.celulas(forma, hh, 2.4, 2.4, feitas)
			for p: Vector3i in arv:
				if not celulas.has(p + o) or arv[p] == ArvoreVoxel.TRONCO:
					celulas[p + o] = arv[p]
			if forma != "toco":
				var t := roundi(hh * 0.4)
				var a := Vector3(o.x - 0.5, 0, o.z - 0.5)
				var b := Vector3(o.x + 0.5, t + 1, o.z + 0.5)
				var cantos := PackedVector3Array()
				for x in [a.x, b.x]:
					for y in [a.y, b.y]:
						for z in [a.z, b.z]:
							cantos.append(Vector3(x, y, z))
				troncos.append(cantos)
	return {"celulas": celulas, "troncos": troncos}
