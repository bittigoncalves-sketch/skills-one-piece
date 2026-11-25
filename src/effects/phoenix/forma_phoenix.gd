extends Node3D
## Fênix completa. Fonte autoral volumétrica e rig de pivôs rígidos.
## Frente -Z; origem nos pés. Animação nunca escala tronco ou membros.
const Geo := preload("res://src/effects/phoenix/geometria_phoenix.gd")
const Pluma := preload("res://src/effects/phoenix/plumagem_phoenix.gd")
const Fogo := preload("res://src/effects/phoenix/labaredas_phoenix.gd")
const CHAO := 0.075
const COXA := 0.59
const CANELA := 0.57
const ASSET := "res://assets/models/phoenix/fenix_anime.scn"
## Só o exportador utiliza a construção autoral; gameplay carrega a malha pronta.
var gerar_fonte := false
var asas: Array[Node3D] = []
var cotovelos: Array[Node3D] = []
var punhos: Array[Node3D] = []
var caudas: Array[Node3D] = []
var pernas: Array[Dictionary] = []
var bases_fechadas: Array[Array] = []
var bases_sentadas: Array[Array] = []
var corpo: Node3D
var pescoco: Node3D
var cabeca: Node3D
var tempo := 0.0
var voando := false
var ataque := 0.0
var estado_animacao := "parado"
var velocidade_local := Vector3.ZERO
var no_chao := true
var sentado := false
var _dados_recebidos := false
var _ar := 0.0
var _repouso := 0.0
var _marcha := 0.0
var _fase := 0.0
var _pouso := 0.0
var _antes_chao := true
var _antes_voo := false
var _decolagem := 0.0
var _pernas_ar := 0.0
var _azul: Material
var _turquesa: Material
var _claro: Material
var _escuro: Material
var _ouro: Material
var _bico: Material
var _fogo: Material
var _fogo_ouro: Material

static func chama() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/effects/phoenix/chama_phoenix.gdshader")
	return m

static func material(cor: Color, brilho := 0.12) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.emission_enabled = true
	m.emission = cor
	m.emission_energy_multiplier = brilho
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## API compartilhada pelos efeitos existentes.
static func volume(pai: Node3D, pos: Vector3, tamanho: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radial_segments = 32
	m.rings = 20
	m.radius = 0.5
	m.height = 1.0
	n.mesh = m
	n.material_override = mat
	pai.add_child(n)
	n.position = pos
	n.scale = tamanho
	return n

static func pena(comprimento: float, largura: float, curva: float, mat: Material) -> MeshInstance3D:
	return Pluma.pena(comprimento, largura, curva, mat)

func _pivo(pai: Node3D, nome: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = nome
	pai.add_child(n)
	n.position = pos
	return n

func _pena(pai: Node3D, base: Vector3, direcao: Vector3, largura: float, mat: Material, normal := Vector3.UP, curva := 0.06) -> void:
	var n := Pluma.pena(direcao.length(), largura, curva, mat)
	var y := direcao.normalized()
	var x := y.cross(normal).normalized()
	if x.length_squared()<0.1: x = y.cross(Vector3.RIGHT).normalized()
	n.basis = Basis(x,y,x.cross(y).normalized())
	n.position = base
	pai.add_child(n)

func _tubo(pai: Node3D, pontos: Array, raios: Array, mat: Material, lados := 24) -> void:
	pai.add_child(Pluma.tubo(PackedVector3Array(pontos),PackedVector2Array(raios),mat,lados))

func _ready() -> void:
	if not gerar_fonte and ResourceLoader.exists(ASSET):
		var cena := load(ASSET) as PackedScene
		var asset := cena.instantiate() as Node3D
		add_child(asset)
		_ligar_rig(asset)
		_animar(0.0)
		return
	_construir_fonte()

func _ligar_rig(asset: Node3D) -> void:
	corpo = asset.get_node("Corpo")
	pescoco = corpo.get_node("Pescoco")
	cabeca = pescoco.get_node("Cabeca")
	for lado in [-1.0,1.0]:
		var sufixo := "E" if lado<0 else "D"
		var asa: Node3D = corpo.get_node("Ombro"+sufixo)
		var cotovelo: Node3D = asa.get_node("Cotovelo"+sufixo)
		asas.append(asa)
		cotovelos.append(cotovelo)
		punhos.append(cotovelo.get_node("Punho"+sufixo))
		_bases_da_asa(lado)
		var quadril: Node3D = asset.get_node("Quadril"+sufixo)
		var joelho: Node3D = quadril.get_node("Joelho")
		pernas.append({"quadril":quadril,"joelho":joelho,"pe":joelho.get_node("Tornozelo"),"lado":lado})
	for i in 5:
		var cadeia: Node3D = corpo.get_node("Cauda%d"%i)
		caudas.append(cadeia)
		for j in range(1,4):
			cadeia = cadeia.get_node("Segmento%d"%j)
			caudas.append(cadeia)

func _plasma(fundo: String, meio: String, nucleo: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/effects/phoenix/plasma_phoenix.gdshader")
	m.set_shader_parameter("fundo",Color(fundo))
	m.set_shader_parameter("meio",Color(meio))
	m.set_shader_parameter("nucleo",Color(nucleo))
	return m

func _lingua(pai: Node3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, largura: float, mat: Material, normal := Vector3.UP, fase := 0.0, raiz := .15, ponta := 0.0) -> void:
	pai.add_child(Fogo.lingua(a,b,c,d,largura,mat,normal,fase,raiz,ponta))

func _construir_fonte() -> void:
	_azul = material(Color("008bd8"),.45)
	_turquesa = material(Color("04c9f5"),.5)
	_claro = material(Color("69f8ff"),.4)
	_escuro = material(Color("034778"),.1)
	_ouro = material(Color("ffe04b"),.55)
	_bico = material(Color("fff57a"),.35)
	_fogo = _plasma("0064ba","08c8f7","83ffff")
	_fogo_ouro = _plasma("ff931d","ffdf45","fff6a0")
	corpo = _pivo(self,"Corpo",Vector3(0,1.18,0))
	_montar_corpo()
	_montar_cabeca()
	for lado in [-1.0,1.0]:
		_montar_asa(lado)
		_montar_perna(lado)
	_montar_caudas()
	_consolidar_rig(self)
	_animar(0.0)

func _montar_corpo() -> void:
	_tubo(corpo,[Vector3(0,-.29,.20),Vector3(0,-.08,.10),Vector3(0,.29,0),Vector3(0,.66,-.04),Vector3(0,.88,-.08)],
		[Vector2(.06,.09),Vector2(.25,.30),Vector2(.36,.37),Vector2(.34,.30),Vector2(.18,.20)],_turquesa,36)
	# Mechas longas contínuas envolvem o peito; não há escamas ovais.
	for i in 18:
		var ang := TAU*i/18.0
		var radial := Vector3(cos(ang),0,sin(ang))
		var a := radial*.23+Vector3(0,.81,-.05)
		var d := radial*(.23+(.12 if i%3==0 else 0.0))+Vector3(0,-.34,.14)
		_lingua(corpo,a,radial*.45+Vector3(0,.51,-.03),radial*.41+Vector3(0,.06,.02),d,.11,_fogo,radial,i*.7)
	for lado in [-1.0,1.0]:
		for i in 4:
			var a := Vector3(lado*(.17+i*.045),.61-i*.10,-.24)
			_lingua(corpo,a,a+Vector3(lado*.21,.16,-.05),a+Vector3(lado*.33,.36,.03),a+Vector3(lado*.23,.62,.06),.09,_fogo_ouro,Vector3.FORWARD,i*.8)
	# Marca escura angular da referência, acompanhando o volume do esterno.
	var marca := PackedVector3Array([Vector3(-.20,.47,-.382),Vector3(-.09,.49,-.405),Vector3(-.12,.60,-.365),Vector3(-.035,.55,-.39),Vector3(0,.64,-.365),Vector3(.04,.54,-.39),Vector3(.14,.59,-.365),Vector3(.11,.47,-.405),Vector3(.20,.46,-.382),Vector3(.12,.35,-.41),Vector3(.08,.36,-.43),Vector3(.03,.21,-.405),Vector3(0,.14,-.39),Vector3(-.04,.23,-.405),Vector3(-.09,.35,-.43),Vector3(-.14,.34,-.405)])
	# Triangulação côncava, em vez de fan que cruzaria as pontas da marca.
	var poligono := PackedVector2Array()
	for v in marca: poligono.append(Vector2(v.x,v.y))
	var indices := Geometry2D.triangulate_polygon(poligono)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in indices: st.add_vertex(marca[i])
	corpo.add_child(Geo.malha(st,_escuro))

func _montar_cabeca() -> void:
	pescoco = _pivo(corpo,"Pescoco",Vector3(0,.72,-.13))
	_tubo(pescoco,[Vector3(0,-.12,.04),Vector3(0,.16,.03),Vector3(0,.41,-.02),Vector3(0,.66,-.15),Vector3(0,.87,-.19)],
		[Vector2(.23,.25),Vector2(.19,.20),Vector2(.145,.17),Vector2(.15,.18),Vector2(.17,.2)],_turquesa,32)
	for i in 8:
		var ang := TAU*i/8.0
		var radial := Vector3(cos(ang),0,sin(ang))
		_lingua(pescoco,radial*.16+Vector3(0,.76,-.17),radial*.22+Vector3(0,.49,-.09),radial*.24+Vector3(0,.15,.01),radial*.24+Vector3(0,-.21,.07),.085,_fogo,radial,i*.8)
	cabeca = _pivo(pescoco,"Cabeca",Vector3(0,.83,-.19))
	_tubo(cabeca,[Vector3(0,-.14,.025),Vector3(0,0,0),Vector3(0,.2,-.01),Vector3(0,.34,.04),Vector3(0,.4,.08)],
		[Vector2(.13,.16),Vector2(.21,.27),Vector2(.23,.29),Vector2(.17,.23),Vector2(.035,.06)],_azul,32)
	for lado in [-1.0,1.0]:
		# Órbita afilada em cunha: canto interno baixo, expressão de rapina.
		cabeca.add_child(Geo.placa(PackedVector3Array([Vector3(lado*.07,.14,-.278),Vector3(lado*.218,.235,-.206),Vector3(lado*.224,.145,-.202),Vector3(lado*.13,.105,-.257)]),_escuro))
		cabeca.add_child(Geo.placa(PackedVector3Array([Vector3(lado*.101,.145,-.281),Vector3(lado*.206,.202,-.220),Vector3(lado*.199,.143,-.225),Vector3(lado*.14,.125,-.261)]),_ouro))
		volume(cabeca,Vector3(lado*.153,.155,-.263),Vector3(.023,.047,.019),_escuro)
		volume(cabeca,Vector3(lado*.147,.174,-.274),Vector3(.012,.012,.009),_bico)
		_pena(cabeca,Vector3(lado*.065,.163,-.27),Vector3(lado*.22,.103,.083),.027,_turquesa,Vector3(lado*.5,.3,-1),.008)
		for i in 4:
			var a := Vector3(lado*.15,.21-i*.07,.02)
			_lingua(cabeca,a,a+Vector3(lado*.12,-.08,.03),a+Vector3(lado*.14,-.15,.16),a+Vector3(lado*.07,-.24,.30),.065,_fogo,Vector3(lado,0,0),i*.9)
	_tubo(cabeca,[Vector3(0,.12,-.24),Vector3(0,.06,-.37),Vector3(0,-.09,-.46),Vector3(0,-.34,-.48)],
		[Vector2(.095,.06),Vector2(.073,.054),Vector2(.042,.034),Vector2(.001,.001)],_bico,20)
	for i in 7:
		var x := (i-3)*.045
		var a := Vector3(x,.29,.04+absf(x)*.5)
		var h := 1.10-absf(x)*2.5+sin(i*2.7)*.08
		_lingua(cabeca,a,a+Vector3(-.20,.28,.03),a+Vector3(.24,h*.70,.13),a+Vector3(-.08,h,.14),.125 if i==3 else .085,_fogo_ouro,Vector3.FORWARD,i*.9)
		if i%2==0:
			_lingua(cabeca,a+Vector3(0,.25,.02),a+Vector3(.24,.40,.04),a+Vector3(.28,.65,.07),a+Vector3(.17,.73,.10),.07,_fogo_ouro,Vector3.FORWARD,i*.9)
	# Mechas da testa quebram o domo redondo; olhos ficam livres na frente.
	for i in 7:
		var x := (i-3)*.052
		var a := Vector3(x,.17,-.245+absf(x)*.32)
		_lingua(cabeca,a,a+Vector3(x*.3,.15,-.035),a+Vector3(-x*.5,.30,.08),a+Vector3(x*.3,.41,.14),.048,_fogo,Vector3.FORWARD,i*.8)
	# Bico e olhos acompanham a cabeça afilada, sem escalar o pivô do rig.
	for n in cabeca.get_children():
		if n is MeshInstance3D:
			n.position.x *= .80
			n.scale.x *= .80

func _montar_asa(lado: float) -> void:
	var sufixo := "E" if lado<0 else "D"
	var asa := _pivo(corpo,"Ombro"+sufixo,Vector3(lado*.32,.65,.04))
	asas.append(asa)
	var cotovelo := _pivo(asa,"Cotovelo"+sufixo,Vector3(lado*.95,.10,.08))
	cotovelos.append(cotovelo)
	var punho := _pivo(cotovelo,"Punho"+sufixo,Vector3(lado*.91,.06,-.12))
	punhos.append(punho)
	_bases_da_asa(lado)
	for parte in 3:
		var joint: Node3D = [asa,cotovelo,punho][parte]
		var comprimento := .95 if parte<2 else 1.65
		# Bordo contínuo em arco, com volume; cobre a conexão entre articulações.
		_lingua(joint,Vector3(-lado*.15,0,0),Vector3(lado*.35,.17,-.18),Vector3(lado*comprimento*.8,.19,-.20),Vector3(lado*(comprimento+.22),.10,.08),.23,_fogo,Vector3.UP,parte*.6,.75,0.0)
		# Três camadas de línguas em leque, azuis e douradas entrelaçadas.
		for fila in 3:
			for i in 9:
				var t := float(i)/8.0
				var x := t*comprimento
				var avanco := (parte*.48+t*.58)
				var a := Vector3(lado*x,.11+fila*.055,-.04+fila*.19-avanco)
				var longa := .54+fila*.23+sin(t*PI)*.18+avanco+sin(i*2.4+fila*.9)*.10
				var abertura := (.20+t*.40 if parte<2 else .42+t*.7)+sin(i*1.7+fila)*.10
				var d := a+Vector3(lado*abertura,-.10,longa-(t*.42 if parte==2 else 0.0))
				var mat: Material = _fogo_ouro if fila==1 and (i+parte)%3==1 else _fogo
				_lingua(joint,a,a+Vector3(lado*.06,.03,longa*.35),d+Vector3(-lado*.24,.08,-longa*.18),d,.17 if fila<2 else .20,mat,Vector3.UP,i*.7+fila)
				if fila==2 and i%2==0:
					_lingua(joint,a+Vector3(0,.02,longa*.38),d+Vector3(-lado*.32,.04,-.31),d+Vector3(lado*.13,.04,-.17),d+Vector3(lado*.13,.02,.12),.10,_fogo,Vector3.UP,i*.7)
		# Brasas douradas compridas também no verso da asa.
		for i in 3:
			var a := Vector3(lado*(.12+i*comprimento*.32),-.06,.12)
			_lingua(joint,a,a+Vector3(lado*.12,-.05,.4),a+Vector3(-lado*.03,-.08,.72),a+Vector3(lado*.25,-.03,1.13),.085,_fogo_ouro,Vector3.DOWN,i*1.3)
	# O gancho de fogo na extremidade é um traço central da referência.
	_lingua(punho,Vector3(lado*1.13,.14,-.02),Vector3(lado*2.30,.24,-2.50),Vector3(lado*3.30,.23,-2.40),Vector3(lado*2.70,.18,-1.15),.34,_fogo,Vector3.UP,1.0)
	for i in 4:
		var a := Vector3(lado*(.65+i*.27),.17,-.12)
		_lingua(punho,a,a+Vector3(lado*.32,.10,-.34),a+Vector3(lado*.52,.05,-.65),a+Vector3(lado*.29,.06,-.76),.11,_fogo_ouro if i==1 else _fogo,Vector3.UP,i*.8)

func _base_asa(direcao: Vector3, lado: float, vertical: float) -> Basis:
	var x := direcao.normalized()*lado
	# A plumagem larga repousa para fora e para trás, não dentro do solo.
	var caimento := Vector3(lado*sqrt(1-vertical*vertical),-vertical,0)
	var z := (caimento-x*x.dot(caimento)).normalized()
	return Basis(x,z.cross(x).normalized(),z)

func _bases_da_asa(lado: float) -> void:
	for vertical in [.99,.97]:
		var b0 := _base_asa(Vector3(lado*.22,-.08,.91),lado,vertical)
		var b1 := _base_asa(Vector3(-lado*.12,-.05,-.90),lado,vertical)
		var b2 := _base_asa(Vector3(lado*.08,-.08,1),lado,vertical)
		var bases := [b0,b0.inverse()*b1,b1.inverse()*b2]
		if vertical>.98: bases_fechadas.append(bases)
		else: bases_sentadas.append(bases)

func _montar_perna(lado: float) -> void:
	var quadril := _pivo(self,"QuadrilE" if lado<0 else "QuadrilD",Vector3(lado*.235,1.02,.05))
	var joelho := _pivo(quadril,"Joelho",Vector3(0,-COXA,0))
	var pe := _pivo(joelho,"Tornozelo",Vector3(0,-CANELA,0))
	pernas.append({"quadril":quadril,"joelho":joelho,"pe":pe,"lado":lado})
	_tubo(quadril,[Vector3.ZERO,Vector3(0,-.23,0),Vector3(0,-COXA,0)],
		[Vector2(.15,.16),Vector2(.14,.15),Vector2(.073,.08)],_azul,24)
	for i in 8:
		var a := TAU*i/8.0
		_pena(quadril,Vector3(cos(a)*.12,-.11,sin(a)*.12),Vector3(cos(a)*.04,-.37,.035),.077,_turquesa,Vector3(cos(a),0,sin(a)),.018)
	_tubo(joelho,[Vector3(0,.035,0),Vector3(0,-.28,0),Vector3(0,-CANELA,0)],
		[Vector2(.075,.08),Vector2(.054,.061),Vector2(.06,.07)],_claro,20)
	for i in 8:
		_pena(joelho,Vector3(0,-.06-i*.055,-.062),Vector3(0,-.075,-.008),.052,_bico if i%3==0 else _turquesa,Vector3.FORWARD,.008)
	for dedo in 4:
		var tras := dedo==3
		var x := 0.0 if tras else (dedo-1)*.11
		var fim := Vector3(x*1.6,-.035,.20 if tras else -.30-absf(x)*.2)
		_tubo(pe,[Vector3(x*.4,0,0),Vector3(x,-.02,fim.z*.45),fim],
			[Vector2(.045,.05),Vector2(.034,.035),Vector2(.019,.02)],_claro,14)
		_tubo(pe,[fim+Vector3(0,.018,0),fim+Vector3(0,.005,.07 if tras else -.08),fim+Vector3(0,-.035,.10 if tras else -.11)],
			[Vector2(.029,.03),Vector2(.021,.025),Vector2(.001,.001)],_bico,14)

func _montar_caudas() -> void:
	for i in 5:
		var cadeia := _pivo(corpo,"Cauda%d"%i,Vector3((i-2)*.105,-.12,.32))
		for segmento in 4:
			if segmento>0: cadeia = _pivo(cadeia,"Segmento%d"%segmento,Vector3(0,0,.92))
			caudas.append(cadeia)
			var w := (.18 if i%2 else .26)*(1-segmento*.13)
			var final := segmento==3
			var d := Vector3((i-2)*.035,.05,1.32 if final else 1.02)
			_lingua(cadeia,Vector3(0,0,-.10),Vector3(-.06,.02,.25),Vector3(.10,.04,.72),d,w,_fogo,Vector3.UP,i*.8+segmento*.3,1.0,0.0 if final else .88)
			_lingua(cadeia,Vector3(0,.06,-.12),Vector3(w*.3,.07,.25),Vector3(-w*.35,.08,.70),d+Vector3(0,.05,.10),w*.29,_fogo_ouro,Vector3.UP,i*.8,1.0,0.0 if final else .8)
			if final:
				_lingua(cadeia,Vector3(0,0,.32),Vector3(w*2,.05,.72),Vector3(w*3,.04,1.12),d+Vector3(w,.03,-.1),w*.65,_fogo,Vector3.UP,i*.8)

func _consolidar_rig(n: Node3D) -> void:
	for c in n.get_children():
		if c is Node3D and not c is MeshInstance3D: _consolidar_rig(c)
	Pluma.consolidar(n)

func atualizar_movimento(v: Vector3, chao: bool, voo: bool, repouso: bool) -> void:
	velocidade_local = v
	no_chao = chao
	voando = voo
	sentado = repouso and chao and not voo
	_dados_recebidos = true

func _process(delta: float) -> void:
	_animar(delta)

func _animar(delta: float) -> void:
	if not is_instance_valid(corpo): return
	var chao := no_chao if _dados_recebidos else not voando
	if chao and not _antes_chao: _pouso = 1.0
	if voando and not _antes_voo: _decolagem = 1.0
	_antes_chao = chao
	_antes_voo = voando
	tempo += delta
	_pouso = move_toward(_pouso,0.0,delta*2.4)
	_decolagem = move_toward(_decolagem,0.0,delta*1.8)
	_ar = move_toward(_ar,0.0 if chao and not voando else 1.0,delta*2.5)
	_pernas_ar = move_toward(_pernas_ar,1.0 if voando and velocidade_local.y>-.8 else 0.0,delta*3.5)
	_repouso = move_toward(_repouso,1.0 if sentado and chao else 0.0,delta*1.8)
	var rapidez := Vector2(velocidade_local.x,velocidade_local.z).length()
	_marcha = move_toward(_marcha,clampf(rapidez/2.0,0,1) if chao and not sentado else 0.0,delta*5)
	var passo := clampf(.24+rapidez*.055,.24,.65)
	# Durante 60% do ciclo o pé recua à velocidade do solo; o restante é balanço.
	_fase += delta*TAU*rapidez*.60/(passo*2)
	estado_animacao = "voando" if _ar>.5 else "parado"
	if chao and _marcha>.1: estado_animacao = "andando"
	if sentado: estado_animacao = "sentado" if _repouso>.99 else "sentando"
	elif _repouso>.01: estado_animacao = "levantando"
	if (not chao and not voando) or _pouso>0: estado_animacao = "pousando"
	if _decolagem>0: estado_animacao = "decolando"
	var batida := sin(tempo*6.2)
	var impacto := sin(_pouso*PI)*.15
	corpo.position.y = 1.18-_repouso*.63-impacto+sin(tempo*2)*.012+((1-absf(cos(_fase)))*.045-.13)*_marcha
	corpo.rotation.x = -_ar*(.22+clampf(rapidez/18,0,1)*.35)-_repouso*.13+_marcha*.055
	corpo.rotation.z = sin(_fase)*.035*_marcha
	pescoco.rotation.x = -corpo.rotation.x*.65+sin(tempo*1.7)*.025
	cabeca.rotation.x = -pescoco.rotation.x*.35
	cabeca.rotation.y = sin(tempo*.7)*.045*(1-_marcha)
	for i in asas.size():
		var lado := -1.0 if i==0 else 1.0
		asas[i].position.y = .65+.22*(1-_ar)+_repouso*.60
		var aberto := smoothstep(0.0,1.0,_ar)
		var freio := .25 if estado_animacao=="pousando" else 0.0
		# Interpolar até uma pose fixa evita trocar o hemisfério do quaternion
		# quando o cotovelo fechado está perto de 180° durante a decolagem.
		var base_voo := Basis.from_euler(Vector3(1.08,-lado*.10,lado*.12))
		var bater := Basis.from_euler(Vector3(0,0,lado*(batida*.24+freio)*aberto))
		var b1 := Basis.from_euler(Vector3(0,(lado*.14+maxf(0,batida)*lado*.22)*aberto,lado*sin(tempo*6.2-.5)*.085*aberto))
		var b2 := Basis.from_euler(Vector3(0,-lado*.12*aberto,lado*sin(tempo*6.2-1)*.10*aberto))
		asas[i].basis = (bases_fechadas[i][0] as Basis).slerp(bases_sentadas[i][0],_repouso).slerp(base_voo,aberto)*bater
		cotovelos[i].basis = (bases_fechadas[i][1] as Basis).slerp(bases_sentadas[i][1],_repouso).slerp(Basis.IDENTITY,aberto)*b1
		punhos[i].basis = (bases_fechadas[i][2] as Basis).slerp(bases_sentadas[i][2],_repouso).slerp(Basis.IDENTITY,aberto)*b2
		var fase := fposmod(_fase+(PI if i==1 else 0.0),TAU)/TAU
		var z := lerpf(-passo,passo,fase/.60) if fase<.60 else lerpf(passo,-passo,smoothstep(0,1,(fase-.60)/.40))
		var eleva := 0.0 if fase<.60 else sin((fase-.60)/.40*PI)*.18
		var direcao_passo := Vector3(velocidade_local.x,0,velocidade_local.z).normalized()
		var alvo := Vector3(lado*.235,CHAO+eleva*_marcha,-.02)-direcao_passo*z*_marcha
		alvo.y = lerpf(alvo.y,.48,_pernas_ar)
		alvo.z = lerpf(alvo.z,.24,_pernas_ar)
		alvo.z = lerpf(alvo.z,-.13,_repouso)
		_posar_perna(pernas[i],alvo)
	for i in caudas.size():
		var segmento := i%4
		var indice := i/4
		caudas[i].rotation.x = sin(tempo*2.5-segmento*.62-indice*.4)*.065+(.10+_ar*.42 if segmento==0 else -.035)+_repouso*(-.10 if segmento==0 else .0)
		caudas[i].rotation.y = sin(tempo*1.8-segmento*.7+indice*.6)*.075+(float(indice)-2)*.075

func _posar_perna(perna: Dictionary, alvo: Vector3) -> void:
	var quadril: Node3D = perna.quadril
	var joelho: Node3D = perna.joelho
	var pe: Node3D = perna.pe
	var lado: float = perna.lado
	quadril.position = corpo.transform*Vector3(lado*.235,-.12,.04)
	var vetor := alvo-quadril.position
	var d := clampf(vetor.length(),absf(COXA-CANELA)+.001,COXA+CANELA-.001)
	var direcao := vetor.normalized()
	var projecao := (COXA*COXA+d*d-CANELA*CANELA)/(2*d)
	var altura := sqrt(maxf(0,COXA*COXA-projecao*projecao))
	var dobra := (Vector3.FORWARD-direcao*direcao.dot(Vector3.FORWARD)).normalized()
	var pos_joelho := quadril.position+direcao*projecao+dobra*altura
	var x := direcao.cross(dobra).normalized()
	var y0 := (quadril.position-pos_joelho).normalized()
	var y1 := (pos_joelho-(quadril.position+direcao*d)).normalized()
	var base0 := Basis(x,y0,x.cross(y0).normalized())
	var base1 := Basis(x,y1,x.cross(y1).normalized())
	quadril.basis = base0
	joelho.basis = base0.inverse()*base1
	pe.basis = base1.inverse()*Basis(Vector3.RIGHT,_pernas_ar*.28)

func medidas_rig() -> Dictionary:
	var medidas := {"estado":estado_animacao,"ar":_ar,"repouso":_repouso,"pes":[],"comprimentos":[]}
	for p in pernas:
		medidas.pes.append(to_local(p.pe.global_position))
		medidas.comprimentos.append([p.quadril.global_position.distance_to(p.joelho.global_position),p.joelho.global_position.distance_to(p.pe.global_position)])
	return medidas
