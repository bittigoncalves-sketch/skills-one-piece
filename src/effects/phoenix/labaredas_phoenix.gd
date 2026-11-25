extends RefCounted
## Fonte de volumes de fogo: seção lenticular fechada sobre Bézier.
## UV.x atravessa a labareda, UV.y segue o fluxo; COLOR.r fixa a raiz no shader.
const Pluma := preload("res://src/effects/phoenix/plumagem_phoenix.gd")
const Geo := preload("res://src/effects/phoenix/geometria_phoenix.gd")

static func lingua(a: Vector3, b: Vector3, c: Vector3, d: Vector3, largura: float, mat: Material, normal := Vector3.UP, fase := 0.0, raiz := 0.15, ponta := 0.0) -> MeshInstance3D:
	var vs := PackedVector3Array()
	var cores := PackedColorArray()
	var uvs := PackedVector2Array()
	var ids := PackedInt32Array()
	const ANEIS := 49
	const LADOS := 12
	for i in ANEIS:
		var t := float(i)/(ANEIS-1)
		var centro := Geo.curva(a,b,c,d,t)
		var tangente := (Geo.curva(a,b,c,d,minf(1,t+.001))-Geo.curva(a,b,c,d,maxf(0,t-.001))).normalized()
		var lateral := tangente.cross(normal).normalized()
		if lateral.length_squared()<.1: lateral = tangente.cross(Vector3.RIGHT).normalized()
		var n := lateral.cross(tangente).normalized()
		var envelope := lerpf(raiz,ponta,t)+pow(sin(PI*t),.75)*(1-t*.38)
		var onda := sin(t*TAU*2.4+fase)*sin(PI*t)*.13
		centro += lateral*onda*largura
		for j in LADOS:
			var ang := TAU*j/LADOS
			var lado := cos(ang)
			# Recortes assimétricos, maiores na ponta, evitam a borda oval de pena.
			var recorte := 1.0-.28*pow(maxf(0,sin(t*TAU*3.5+fase+lado*1.8)),4)*t
			vs.append(centro+lateral*lado*largura*envelope*recorte+n*sin(ang)*largura*.17*envelope)
			uvs.append(Vector2(lado*.5+.5,t))
			cores.append(Color(t, fase/TAU, 0, 1))
	Pluma._connect_rings(ids,ANEIS,LADOS)
	Pluma._cap(vs,cores,uvs,ids,a,0,LADOS,true)
	Pluma._cap(vs,cores,uvs,ids,d,(ANEIS-1)*LADOS,LADOS,false)
	cores[ANEIS*LADOS] = Color(0,fase/TAU,0,1)
	cores[ANEIS*LADOS+1] = Color(1,fase/TAU,0,1)
	return Pluma._mesh(vs,cores,uvs,ids,mat)
