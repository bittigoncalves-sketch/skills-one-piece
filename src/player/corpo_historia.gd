extends RefCounted
## Fonte editável dos corpos em blocos da campanha. Frente = -Z; pés = Y 0.
## Mantém o contrato do BodyScanner, inclusive punhos, dedos e encaixes de itens.
const Aparencia := preload("res://src/player/skin_historia.gd")
const TIPOS := ["masculino", "feminino"]


static func construir(tipo: String, tom := Aparencia.Tons.PADRAO, opcoes: Dictionary = {}) -> Dictionary:
	var visual := Aparencia.Personalizacao.normalizar(opcoes)
	var feminino := tipo == "feminino"
	var raiz := Node3D.new()
	raiz.name = "CharacterRoot_historia"
	raiz.set_meta("reference_proportions", true)
	raiz.set_meta("preserve_original_materials", true)
	raiz.set_meta("corpo_historia", "feminino" if feminino else "masculino")
	raiz.set_meta("tom_de_pele", Aparencia.Tons.normalizar(tom))
	raiz.set_meta("aparencia_historia", visual.duplicate())
	var tipo_skin := "feminino" if feminino else "masculino"
	var pele := Aparencia.material(tipo_skin, 7, tom, visual)
	var camisa := Aparencia.material(tipo_skin, 1, tom, visual)
	var abdomen_mat := Aparencia.material(tipo_skin, 2, tom, visual)
	var cintura := Aparencia.material(tipo_skin, 3, tom, visual)
	var calca := Aparencia.material(tipo_skin, 4, tom, visual)
	var bota := Aparencia.material(tipo_skin, 5, tom, visual)
	var manga := Aparencia.material(tipo_skin, 6, tom, visual)
	var torso := _junta(raiz, "Torso", Vector3(0, .72, 0))
	_caixa(torso, "Quadril", Vector3(.48, .16, .24), Vector3(0, .08, 0), cintura)
	var coluna := _junta(torso, "SpineLower", Vector3(0, .16, 0))
	var abdomen := _junta(coluna, "SpineMid", Vector3(0, .14, 0))
	_caixa(abdomen, "Abdomen", Vector3(.48, .32, .24), Vector3(0, .02, 0), abdomen_mat)
	var peito := _junta(abdomen, "Chest", Vector3(0, .18, 0))
	_caixa(peito, "Peito", Vector3(.48, .24, .24), Vector3(0, .12, 0), camisa)
	if feminino:
		for s: float in [-1.0, 1.0]:
			_busto(peito, s, camisa)
	var pescoco := _junta(peito, "Neck", Vector3(0, .24, 0))
	var alto := _junta(pescoco, "NeckUpper", Vector3.ZERO)
	var cabeca := _junta(alto, "Head", Vector3.ZERO)
	_caixa(cabeca, "Cabeca", Vector3(.48, .48, .48), Vector3(0, .24, 0), Aparencia.material(tipo_skin, 0, tom, visual))
	if feminino and visual.cabelo == "original":
		Aparencia.cabelo_longo(cabeca)
	for lado: String in ["L", "R"]:
		var s := -1.0 if lado == "L" else 1.0
		var clavicula := _junta(peito, "Clavicle_" + lado, Vector3(s * .12, .24, 0))
		_junta(peito, "Scapula_" + lado, Vector3(s * .14, .06, .11))
		var braco := _junta(clavicula, "UpperArm_" + lado, Vector3(s * (.21 if feminino else .24), 0, 0))
		var largura := .18 if feminino else .24
		_caixa(braco, "Braco", Vector3(largura, .30, .24), Vector3(0, -.15, 0), pele)
		_caixa(braco, "Manga", Vector3(largura + .002, .12, .242), Vector3(0, -.06, 0), manga)
		_junta(braco, "Elbow_" + lado, Vector3(0, -.30, 0))
		var antebraco := _junta(braco, "ForeArm_" + lado, Vector3(0, -.30, 0))
		var torcao := _junta(antebraco, "ForeArmTwist_" + lado, Vector3(0, -.10, 0))
		_caixa(torcao, "Antebraco", Vector3(largura, .21, .24), Vector3(0, -.005, 0), pele)
		var punho := _junta(antebraco, "Wrist_" + lado, Vector3(0, -.21, 0))
		_caixa(punho, "Pulso", Vector3(.12 if feminino else .16, .05, .17), Vector3(0, -.02, 0), pele)
		var mao := _junta(punho, "Hand_" + lado, Vector3(0, -.025, 0))
		_mao(mao, lado, s, pele, .75 if feminino else 1.0)
		var coxa := _junta(torso, "Thigh_" + lado, Vector3(s * .12, 0, 0))
		_caixa(coxa, "Coxa", Vector3(.24, .36, .24), Vector3(0, -.18, 0), calca)
		_junta(coxa, "Knee_" + lado, Vector3(0, -.36, 0))
		var canela := _junta(coxa, "Shin_" + lado, Vector3(0, -.36, 0))
		_caixa(canela, "Canela", Vector3(.24, .27, .24), Vector3(0, -.135, 0), calca)
		var pe := _junta(canela, "Foot_" + lado, Vector3(0, -.27, 0))
		_caixa(pe, "Bota", Vector3(.24, .09, .16), Vector3(0, -.045, .04), bota)
		var ponta := _junta(pe, "Ball_" + lado, Vector3(0, 0, -.04))
		_caixa(ponta, "PontaBota", Vector3(.24, .09, .08), Vector3(0, -.045, -.04), bota)
	preload("res://src/player/detalhes_historia.gd").aplicar(raiz, tipo_skin, tom, visual)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	raiz.add_child(ap)
	return {"node": raiz, "anim_player": ap, "skinned": false}


## Os nomes `Geo_Palm_<lado>_Runtime` / `Geo_<parte>_Runtime` são o CONTRATO das mãos separáveis (`BaraHandBinding._bind_node_hand`): sem eles a Bara Bara
## recusa as técnicas com "Avatar sem mãos separáveis" (medido em 15/11/2026 com o corpo novo do Modo História, `test_frutas_na_historia`).
static func _mao(mao: Node3D, lado: String, s: float, pele: Material, largura: float) -> void:
	_caixa(mao, "Geo_Palm_%s_Runtime" % lado, Vector3(.19 * largura, .105, .14), Vector3(0, -.045, 0), pele)
	var dedos := ["Index", "Middle", "Ring", "Little"]
	for i in 4:
		var pai := mao
		var comprimento := .031 if i < 3 else .026
		for j in 3:
			var pos := Vector3(s * (-.072 + i * .048) * largura, -.095, -.003) if j == 0 else Vector3(0, -comprimento, 0)
			pai = _junta(pai, "%s%d_%s" % [dedos[i], j + 1, lado], pos)
			_caixa(pai, "Geo_Finger%d%d_%s_Runtime" % [i, j, lado], Vector3(.039 * largura, comprimento - .001, .085), Vector3(0, -comprimento * .5, 0), pele)
	var polegar := mao
	for j in 3:
		polegar = _junta(polegar, "Thumb%d_%s" % [j + 1, lado], Vector3(-s * .119 * largura, -.018, -.014) if j == 0 else Vector3(0, -.031, 0))
		_caixa(polegar, "Geo_Thumb%d_%s_Runtime" % [j, lado], Vector3(.044 * largura, .030, .07), Vector3(0, -.015, 0), pele)
	_junta(mao, "Grip_" + lado, Vector3(0, -.085, -.055))
	_junta(mao, "Weapon_" + lado, Vector3(0, -.085, -.055))


static func _junta(pai: Node3D, nome: String, pos: Vector3) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	no.position = pos
	pai.add_child(no)
	return no


static func _caixa(pai: Node3D, nome: String, tamanho: Vector3, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nome
	var mesh := BoxMesh.new()
	mesh.size = tamanho
	mi.mesh = Aparencia.caixa(tamanho, int(material.get_meta("linha_skin"))) if material.has_meta("linha_skin") else mesh
	mi.material_override = material
	mi.position = pos
	pai.add_child(mi)


static func _material(cor: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = .9
	return mat


static func _busto(pai: Node3D, lado: float, material: Material) -> void:
	# Perfil angular da referência feminina: rampa superior e base recolhida,
	# sem duas caixas soltas. Extrusão fechada, normais planas, frente = -Z.
	var perfil := PackedVector2Array([
		Vector2(.145, -.13), Vector2(.045, -.255),
		Vector2(-.055, -.255), Vector2(-.095, -.13)])
	var vertices: Array[Vector3] = []
	for x: float in [-.108, .108]:
		for yz in perfil:
			vertices.append(Vector3(x, yz.x, yz.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var faces := [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4],
		[1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
	for face: Array in faces:
		for i: int in [0, 1, 2, 0, 2, 3]:
			var v: Vector3 = vertices[face[i]]
			var u := clampf((v.x + lado * .112 + .24) / .48, 0.0, 1.0)
			var y := clampf(1.0 - (v.y + .09) / .24, 0.0, 1.0)
			st.set_uv(Vector2((.5 + u * 63) / 384.0, (64.5 + y * 63) / 512.0))
			st.add_vertex(v)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "Busto" + ("L" if lado < 0 else "R")
	mesh.mesh = st.commit()
	mesh.material_override = material
	mesh.position = Vector3(lado * .112, .09, 0)
	pai.add_child(mesh)
