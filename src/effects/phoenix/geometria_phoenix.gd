extends RefCounted
## Geometria autoral em unidades de jogo: seções de corpo, penas e fitas curvas.
## A fonte é este gerador; não depende de uma malha binária sem edição.

static func malha(st: SurfaceTool, mat: Material) -> MeshInstance3D:
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh = st.commit()
	n.material_override = mat
	return n

static func tubo(pontos: PackedVector3Array, raios: PackedVector2Array, mat: Material, lados := 24) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pontos.size()-1:
		for j in lados:
			var vertices: Array[Vector3] = []
			for par: Vector2i in [Vector2i(i,j),Vector2i(i,j+1),Vector2i(i+1,j+1),Vector2i(i+1,j)]:
				var ang := TAU*par.y/lados
				vertices.append(pontos[par.x] + Vector3(cos(ang)*raios[par.x].x,0,sin(ang)*raios[par.x].y))
			for k in [0,2,1,0,3,2]: st.add_vertex(vertices[k])
	return malha(st, mat)

static func curva(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0-t
	return u*u*u*a + 3*u*u*t*b + 3*u*t*t*c + t*t*t*d

## Fita em Bézier com quilha: espessura visual das penas, sem cartões retos.
static func fita(a: Vector3, b: Vector3, c: Vector3, d: Vector3, largura: float, mat: Material, serrilha := false) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var pontos: Array[Vector3] = []
		var uvs: Array[Vector2] = []
		for j in 2:
			var t := float(i+j)/24.0
			var centro := curva(a,b,c,d,t)
			var tangente := curva(a,b,c,d,minf(t+0.01,1))-curva(a,b,c,d,maxf(t-0.01,0))
			var lateral := tangente.cross(Vector3.FORWARD).normalized()
			if lateral.length_squared()<0.1: lateral = Vector3.RIGHT
			var w := largura*pow(sin(PI*t),0.55)*(1.0-0.3*t)
			if serrilha: w *= 0.82+0.18*cos(t*TAU*5)
			pontos.append(centro-lateral*w)
			pontos.append(centro+Vector3(0,0,-0.045*sin(PI*t)))
			pontos.append(centro+lateral*w)
			uvs.append_array([Vector2(0,t),Vector2(0.5,t),Vector2(1,t)])
		for k in [0,3,4,0,4,1,1,4,5,1,5,2]:
			st.set_uv(uvs[k])
			st.add_vertex(pontos[k])
	return malha(st, mat)

static func placa(pontos: PackedVector3Array, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,pontos.size()-1):
		for p in [pontos[0],pontos[i],pontos[i+1]]: st.add_vertex(p)
	return malha(st,mat)
