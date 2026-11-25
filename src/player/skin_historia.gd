extends RefCounted
## UV autoral: faces -Z,+Z,-X,+X,+Y,-Y; 8 linhas de 64px no atlas.
const Tons := preload("res://src/player/tons_de_pele.gd")
const Personalizacao := preload("res://src/player/aparencia_historia.gd")
const Atlas := preload("res://src/player/atlas_personalizado.gd")
static var _materiais: Dictionary = {}


static func material(tipo: String, linha: int, tom := Tons.PADRAO, opcoes: Dictionary = {}) -> StandardMaterial3D:
	var chave := "%s/%s/%d/%s" % [tipo, Tons.normalizar(tom), linha, JSON.stringify(Personalizacao.normalizar(opcoes))]
	if not _materiais.has(chave):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Atlas.textura(tipo, tom, opcoes)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mat.roughness = .9
		mat.set_meta("linha_skin", linha)
		if _materiais.size() >= 256: _materiais.erase(_materiais.keys()[0])
		_materiais[chave] = mat
	return _materiais[chave]


static func caixa(tamanho: Vector3, linha: int) -> ArrayMesh:
	var p := tamanho * .5
	# Vértices em sentido horário vistos de fora (frente do Godot).
	var faces := [
		[Vector3(-p.x,p.y,-p.z), Vector3(p.x,p.y,-p.z), Vector3(p.x,-p.y,-p.z), Vector3(-p.x,-p.y,-p.z)],
		[Vector3(p.x,p.y,p.z), Vector3(-p.x,p.y,p.z), Vector3(-p.x,-p.y,p.z), Vector3(p.x,-p.y,p.z)],
		[Vector3(-p.x,p.y,p.z), Vector3(-p.x,p.y,-p.z), Vector3(-p.x,-p.y,-p.z), Vector3(-p.x,-p.y,p.z)],
		[Vector3(p.x,p.y,-p.z), Vector3(p.x,p.y,p.z), Vector3(p.x,-p.y,p.z), Vector3(p.x,-p.y,-p.z)],
		[Vector3(-p.x,p.y,p.z), Vector3(p.x,p.y,p.z), Vector3(p.x,p.y,-p.z), Vector3(-p.x,p.y,-p.z)],
		[Vector3(-p.x,-p.y,-p.z), Vector3(p.x,-p.y,-p.z), Vector3(p.x,-p.y,p.z), Vector3(-p.x,-p.y,p.z)]]
	var normais := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT, Vector3.UP, Vector3.DOWN]
	var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in 6:
		for v: int in [0,2,1,0,3,2]:
			st.set_normal(normais[f])
			# Meio pixel de margem mantém a célula vizinha fora das bordas.
			st.set_uv(Vector2((f * 64 + .5 + uvs[v].x * 63) / 384.0, (linha * 64 + .5 + uvs[v].y * 63) / 512.0))
			st.add_vertex(faces[f][v])
	return st.commit()


static func cabelo_longo(cabeca: Node3D) -> void:
	var cabelo := Node3D.new()
	cabelo.name = "CabeloLongo"
	cabeca.add_child(cabelo)
	# Mechas fechadas, afiladas e encostadas: volume atrás do crânio e queda até
	# metade das costas. A frente (-Z) fica livre; acompanha Head em todas as poses.
	for i in 7:
		var x := (i - 3) * .077
		var fim := -.48 + absf(i - 3) * .045
		_mecha(cabelo, "Costas%d" % i, [Vector3(x,.46,.19), Vector3(x,.31,.275), Vector3(x * 1.07,-.06,.30), Vector3(x * .98,fim,.32)], [.09,.093,.093,.035], Color("493026") if i % 2 == 0 else Color("38261f"))
	for lado: float in [-1.0, 1.0]:
		_mecha(cabelo, "Lateral" + str(int(lado)), [Vector3(lado*.22,.43,0), Vector3(lado*.252,.15,-.03), Vector3(lado*.265,-.13,-.05), Vector3(lado*.30,-.28,-.035)], [.085,.085,.075,.02], Color("493026"))
		_mecha(cabelo, "Franja" + str(int(lado)), [Vector3(lado*.04,.46,-.22), Vector3(lado*.17,.39,-.249), Vector3(lado*.225,.23,-.25)], [.10,.085,.015], Color("51352a"))


static func _mecha(pai: Node3D, nome: String, centros: Array, larguras: Array, cor: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var aneis: Array = []
	for i in centros.size():
		var c: Vector3 = centros[i]
		var w: float = larguras[i] * .5
		aneis.append([c + Vector3(-w,0,-.025), c + Vector3(w,0,-.025), c + Vector3(w,0,.025), c + Vector3(-w,0,.025)])
	for i in range(aneis.size() - 1):
		for f in 4:
			var proximo := (f + 1) % 4
			var quad := [aneis[i][f], aneis[i][proximo], aneis[i+1][proximo], aneis[i+1][f]]
			for v: int in [0,2,1,0,3,2]: st.add_vertex(quad[v])
	for ponta: int in [0, aneis.size()-1]:
		for v: int in ([3,1,2,3,0,1] if ponta == 0 else [0,2,1,0,3,2]): st.add_vertex(aneis[ponta][v])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.roughness = .78
	mi.material_override = mat
	pai.add_child(mi)
