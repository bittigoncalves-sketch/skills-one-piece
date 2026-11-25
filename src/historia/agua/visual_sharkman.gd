extends RefCounted
## Adaptação ao rig da campanha: medidas em metros, sem usar a AABB de toda
## a hierarquia do Torso (que inclui braços, pernas e outros adornos).
const MARCA := "SharkmanHistoria"
const MATERIAIS := "sharkman_materiais_originais"
const PAPEIS := ["Torso", "Neck", "Head", "UpperArm_L", "UpperArm_R",
	"ForeArm_L", "ForeArm_R", "Hand_L", "Hand_R", "Thigh_L", "Thigh_R",
	"Shin_L", "Shin_R", "Foot_L", "Foot_R"]

static func aplicar(modelo: Node3D, id: String) -> void:
	if modelo.get_meta("raca_id", "") == id: return
	Racas.remover(modelo)
	Adornos.remover_marca(modelo, MARCA)
	for registro: Dictionary in modelo.get_meta(MATERIAIS, []):
		if is_instance_valid(registro.no): registro.no.material_override = registro.material
	modelo.remove_meta(MATERIAIS)
	modelo.set_meta("raca_id", id)
	if id != "sharkman": return
	var originais: Array[Dictionary] = []
	var malhas: Array = []
	FxUtil._collect_meshes(modelo, malhas)
	for no: MeshInstance3D in malhas:
		# Só a pele do corpo base. Armas e acessórios não mudam de material.
		if no.name.begins_with("_") or no.get_parent() == null: continue
		if not (no.name in PAPEIS or no.get_parent().name in PAPEIS): continue
		originais.append({"no": no, "material": no.material_override})
		no.material_override = Materiais.superficie(Color(.28, .52, .64))
	modelo.set_meta(MATERIAIS, originais)
	var costas := _encaixe(modelo, "Torso", "Dorsal")
	if costas != null:
		costas.position += Vector3(0, .35, .15) * costas.scale
		_barbatana(costas, Vector3(.07, .48, .38))
	for lado: String in ["L", "R"]:
		var braco := _encaixe(modelo, "ForeArm_" + lado, "Braco" + lado)
		if braco != null:
			braco.position += Vector3(-.07 if lado == "L" else .07, -.12, .04) * braco.scale
			_barbatana(braco, Vector3(.035, .23, .18))
	var cabeca := _encaixe(modelo, "Head", "Focinho")
	if cabeca != null:
		var focinho := MeshInstance3D.new()
		var forma := CapsuleMesh.new()
		forma.radius = .075
		forma.height = .3
		focinho.mesh = forma
		focinho.rotation.z = PI / 2
		focinho.position = Vector3(0, .09, -.16)
		focinho.material_override = Materiais.superficie(Color(.61, .78, .83))
		cabeca.add_child(focinho)

static func _encaixe(modelo: Node3D, papel: String, sufixo: String) -> Node3D:
	var osso := modelo.find_child(papel, true, false) as Node3D
	if osso == null: return null
	var no := Node3D.new()
	no.name = MARCA + sufixo
	osso.add_child(no)
	var escala := osso.global_basis.get_scale().abs()
	no.scale = Vector3.ONE / escala.max(Vector3.ONE * .001)
	return no

static func _barbatana(pai: Node3D, tamanho: Vector3) -> void:
	# Perfil curvo afilado, com espessura: lê como barbatana também de costas.
	var perfil := PackedVector2Array([Vector2(0, 0), Vector2(.18, .62),
		Vector2(.36, 1), Vector2(.5, .82), Vector2(.6, .50), Vector2(.78, .19), Vector2(1, 0)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pontos: Array[Vector3] = []
	for lado: float in [-.5, .5]:
		for p in perfil:
			pontos.append(Vector3(lado * tamanho.x, p.x * tamanho.y, p.y * tamanho.z))
	var n := perfil.size()
	for i in range(1, n - 1):
		for indice: int in [0, i + 1, i, n, n + i, n + i + 1]: st.add_vertex(pontos[indice])
	for i in n:
		var proximo := (i + 1) % n
		for indice: int in [i, proximo, n + i, proximo, n + proximo, n + i]: st.add_vertex(pontos[indice])
	st.generate_normals()
	var malha := MeshInstance3D.new()
	malha.mesh = st.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.21, .43, .55)
	material.roughness = .72
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	malha.material_override = material
	pai.add_child(malha)
