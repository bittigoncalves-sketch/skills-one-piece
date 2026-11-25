extends SceneTree
## Escultura voxel autoral. A paleta vem da textura local; volumes interpretam seus relevos.
const TEXTURA := "res://assets/mine_piece/visual/entidades/transform_hito_hito_daibutsu_humanbeast.png"
const DESTINO := "res://assets/models/buda/buda_transformacao.tscn"
const CELULA := 0.5 # pixels do modelo original; dois voxels por pixel.
const METRO := 0.88 / 16.0 * 0.9375
var ouro: Color
var claro: Color
var sombra: Color
var escuro: Color
var medio: Color
var raiz: Node3D
var material: StandardMaterial3D
var voxels: Dictionary
var triangulos := 0

func _init() -> void:
	gerar()
	quit()

func gerar() -> void:
	var img := Image.load_from_file(TEXTURA)
	assert(img != null)
	# Cores opacas ordenadas: a textura usa ouro, creme e ocres para os detalhes.
	var contagem := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			if c.a > 0.99:
				contagem[c] = int(contagem.get(c,0)) + 1
	var cores := contagem.keys()
	cores.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	escuro = cores[0]
	sombra = cor_da_paleta(cores, Color("733b00"))
	medio = cor_da_paleta(cores, Color("a35a00"))
	claro = cor_da_paleta(cores, Color("fee483"))
	ouro = cores[0]
	for c: Color in cores:
		if contagem[c] > contagem[ouro]: ouro = c
	print("PALETA_BUDA: ", cores)
	raiz = Node3D.new()
	raiz.name = "BudaTransformacao"
	raiz.set_meta("referencia_textura", TEXTURA)
	raiz.set_meta("voxel_metros", CELULA * METRO)
	material = StandardMaterial3D.new()
	material.resource_name = "OuroDaTexturaMinePiece"
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.72
	var corpo := junta("Body", raiz, Vector3.ZERO)
	voxels = {}
	elipsoide(Vector3(0,-6.4,0), Vector3(5.0,6.3,2.8), ouro)
	elipsoide(Vector3(0,-8.0,1.0), Vector3(5.15,4.4,3.5), ouro)
	# Peitorais separados pelo sulco central escuro, como na faixa superior da textura.
	for lado in [-1.0,1.0]:
		elipsoide(Vector3(lado*2.5,-2.4,1.6), Vector3(2.65,2.0,2.0), ouro)
		elipsoide(Vector3(lado*2.4,-1.25,2.5), Vector3(2.0,0.65,0.65), claro)
		elipsoide(Vector3(lado*4.3,-6.4,1.4), Vector3(0.8,2.7,1.9), medio)
	# Luz central da barriga: o contorno ocre do atlas vira profundidade real.
	elipsoide(Vector3(0,-7.5,3.3), Vector3(3.4,3.4,1.35), ouro)
	elipsoide(Vector3(0,-5.8,4.15), Vector3(2.3,1.4,0.55), claro)
	elipsoide(Vector3(0,-9.1,4.55), Vector3(0.45,0.35,0.20), sombra)
	malha(corpo)
	var cabeca := junta("Head", raiz, Vector3(0,0.25,0))
	voxels = {}
	elipsoide(Vector3(0,4,0), Vector3(3.65,4.0,3.0), ouro)
	elipsoide(Vector3(0,3.4,1.8), Vector3(3.0,3.15,1.8), ouro)
	elipsoide(Vector3(0,0.7,1.8), Vector3(2.35,1.0,1.35), ouro)
	for lado in [-1.0,1.0]:
		elipsoide(Vector3(lado*3.9,2.6,0), Vector3(0.9,2.25,0.85), ouro)
		elipsoide(Vector3(lado*4.1,2.7,0.65), Vector3(0.35,1.35,0.3), sombra)
		elipsoide(Vector3(lado*1.4,4.35,3.15), Vector3(1.15,0.38,0.55), medio)
		elipsoide(Vector3(lado*1.4,3.8,3.35), Vector3(0.95,0.25,0.35), escuro)
		elipsoide(Vector3(lado*1.8,2.8,3.1), Vector3(0.9,0.6,0.45), claro)
	elipsoide(Vector3(0,3.25,3.5), Vector3(0.6,1.15,0.75), ouro)
	elipsoide(Vector3(0,2.5,3.65), Vector3(0.85,0.5,0.6), claro)
	elipsoide(Vector3(0,1.6,3.25), Vector3(1.15,0.25,0.35), sombra)
	elipsoide(Vector3(0,1.1,3.1), Vector3(0.85,0.25,0.35), claro)
	elipsoide(Vector3(0,5.35,3.4), Vector3(0.35,0.35,0.25), claro)
	# Os pontos dourados da cabeça no atlas viram cachos em relevo.
	elipsoide(Vector3(0,6.8,-0.25), Vector3(3.65,2.3,3.05), medio)
	for y in [5.75,6.75,7.75,8.5]:
		var fator := sqrt(maxf(0.12,1.0-pow((y-6.6)/2.5,2)))
		var n := roundi(20*fator)
		for i in n:
			var a: float = TAU * (float(i)+0.25*y)/n
			var p := Vector3(cos(a)*3.5*fator,y,sin(a)*2.95*fator-0.25)
			elipsoide(p,Vector3(0.62,0.62,0.62),ouro)
			elipsoide(p+Vector3(0,0.3,0.05),Vector3(0.28,0.28,0.28),claro)
	elipsoide(Vector3(0,9.0,-0.3),Vector3(1.4,1.25,1.35),medio)
	elipsoide(Vector3(0,9.65,-0.3),Vector3(0.9,0.65,0.9),ouro)
	malha(cabeca)
	for lado in [-1.0,1.0]:
		var prefixo := "Right" if lado < 0 else "Left"
		var braco := junta(prefixo+"Arm",raiz,Vector3(lado*6.5,-1.5,0))
		voxels = {}
		elipsoide(Vector3(0,-0.7,0),Vector3(2.4,2.1,2.45),ouro)
		elipsoide(Vector3(0,-3.0,0),Vector3(1.9,3.0,1.9),ouro)
		elipsoide(Vector3(0,-2.8,1.2),Vector3(1.5,1.85,1.0),claro)
		malha(braco)
		var antebraco := junta(prefixo+"ForeArm",braco,Vector3(0,-5.5,0))
		voxels = {}
		elipsoide(Vector3(0,-1.9,0),Vector3(1.8,2.5,1.8),ouro)
		elipsoide(Vector3(lado*0.8,-1.6,0.8),Vector3(0.65,1.8,0.9),medio)
		elipsoide(Vector3(0,-4.3,0.3),Vector3(1.75,1.35,1.5),ouro)
		for dedo in 4:
			elipsoide(Vector3(-1.15+dedo*0.75,-4.7,1.25),Vector3(0.35,0.85,0.55),claro)
		elipsoide(Vector3(-lado*1.65,-4.1,0.8),Vector3(0.55,1.0,0.65),medio)
		malha(antebraco)
		var perna := junta(prefixo+"Leg",raiz,Vector3(lado*2.5,-12,0))
		voxels = {}
		elipsoide(Vector3(0,-2.5,0),Vector3(2.2,3.5,2.25),ouro)
		elipsoide(Vector3(0,-2.3,1.5),Vector3(1.6,2.2,0.85),claro)
		malha(perna)
		var canela := junta(prefixo+"Shin",perna,Vector3(0,-5.5,0))
		voxels = {}
		elipsoide(Vector3(0,-0.25,0.65),Vector3(1.6,1.2,1.65),ouro)
		elipsoide(Vector3(0,-2.65,-0.1),Vector3(1.65,2.7,1.75),ouro)
		elipsoide(Vector3(0,-2.5,1.25),Vector3(0.65,2.3,0.55),claro)
		malha(canela)
		var pe := junta(prefixo+"Foot",canela,Vector3(0,-4.8,0))
		voxels = {}
		elipsoide(Vector3(0,-0.85,0.9),Vector3(1.9,0.85,2.7),ouro)
		for dedo in 4:
			elipsoide(Vector3(-1.2+dedo*0.8,-0.85,2.65),Vector3(0.4,0.65,0.65),claro)
		malha(pe)
	var cena := PackedScene.new()
	assert(cena.pack(raiz) == OK)
	assert(ResourceSaver.save(cena,DESTINO) == OK)
	print("BUDA_TRANSFORMACAO: ",triangulos," triângulos; cena salva em ",DESTINO)
	raiz.free()

func junta(nome: String,pai: Node3D,pos: Vector3) -> Node3D:
	var no := Node3D.new()
	no.name = nome
	pai.add_child(no)
	no.position = pos*METRO
	no.owner = raiz
	return no

func cor_da_paleta(cores: Array, alvo: Color) -> Color:
	var melhor: Color = cores[0]
	for c: Color in cores:
		if Vector3(c.r,c.g,c.b).distance_squared_to(Vector3(alvo.r,alvo.g,alvo.b)) < Vector3(melhor.r,melhor.g,melhor.b).distance_squared_to(Vector3(alvo.r,alvo.g,alvo.b)):
			melhor = c
	return melhor

func elipsoide(centro: Vector3,raios: Vector3,cor: Color) -> void:
	var minimo := Vector3i(((centro-raios)/CELULA).floor())
	var maximo := Vector3i(((centro+raios)/CELULA).ceil())
	for x in range(minimo.x,maximo.x+1):
		for y in range(minimo.y,maximo.y+1):
			for z in range(minimo.z,maximo.z+1):
				var p := Vector3i(x,y,z)
				if ((Vector3(p)*CELULA-centro)/raios).length_squared() <= 1.0:
					voxels[p] = cor

func malha(pai: Node3D) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var passo := CELULA*METRO
	for p: Vector3i in voxels:
		for n: Vector3i in [Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,1,0),Vector3i(0,-1,0),Vector3i(0,0,1),Vector3i(0,0,-1)]:
			if voxels.has(p+n): continue
			var normal := Vector3(n)
			var u := Vector3.UP if n.y == 0 else Vector3.RIGHT
			var v := normal.cross(u)
			var centro := (Vector3(p)+normal*0.5)*passo
			var vertices := [centro+(-u-v)*passo*0.5,centro+(u-v)*passo*0.5,centro+(u+v)*passo*0.5,centro+(-u+v)*passo*0.5]
			for i in [0,2,1,0,3,2]:
				st.set_normal(normal)
				st.set_color(voxels[p])
				st.add_vertex(vertices[i])
	st.index()
	var m := MeshInstance3D.new()
	m.name = "Volume"
	m.mesh = st.commit()
	m.material_override = material
	pai.add_child(m)
	m.owner = raiz
	triangulos += m.mesh.surface_get_array_index_len(0)/3
