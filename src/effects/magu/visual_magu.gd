extends RefCounted
## Fonte procedural editável; modelo canino já pertencente ao acervo do jogo.
const LAVA := preload("res://src/effects/magu/lava.gdshader")

static func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LAVA
	return m

static func elipsoide(pai: Node3D, pos: Vector3, tamanho: Vector3, mat: Material) -> MeshInstance3D:
	var no := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 24
	m.rings = 12
	no.mesh = m
	no.material_override = mat
	no.position = pos
	no.scale = tamanho
	pai.add_child(no)
	return no

const PUNHO_GLB := "res://assets/models/magu/punho_lava.glb"

## Punho fechado modelado no Blender (tools/blender/punho_lava.py); frente do soco = -Z.
## Sem o GLB importado, cai no punho procedural de esferas.
static func punho(mat: Material) -> Node3D:
	if not ResourceLoader.exists(PUNHO_GLB): return _punho_procedural(mat)
	var cena := load(PUNHO_GLB) as PackedScene
	if cena == null: return _punho_procedural(mat)
	var n := cena.instantiate() as Node3D
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	return n

static func _punho_procedural(mat: Material) -> Node3D:
	var n := Node3D.new()
	elipsoide(n, Vector3(0, 0, .3), Vector3(1.25, 1.2, 1.8), mat)
	for i in 4:
		elipsoide(n, Vector3((i-1.5)*.31, .25, -.57), Vector3(.42, .66, .65), mat)
	elipsoide(n, Vector3(.66, -.12, -.15), Vector3(.45, .7, .8), mat).rotation.z = -.5
	return n

const PRANCHA_GLB := "res://assets/models/magu/prancha_lava.glb"

## Prancha de surfe (tools/blender/prancha_lava.py). Frente = -Z, base em y=0.
static func prancha(mat: Material) -> Node3D:
	var cena := load(PRANCHA_GLB) as PackedScene if ResourceLoader.exists(PRANCHA_GLB) else null
	if cena == null:
		var n := Node3D.new()
		elipsoide(n, Vector3(0, .05, 0), Vector3(.7, .1, 2.6), mat)
		return n
	var n := cena.instantiate() as Node3D
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	return n

## Topo da crista da onda no espaço da malha (v = (PI/2)/2.5; altura 2,4 no centro).
const CRISTA_LOCAL := Vector3(0.0, 2.4, -1.07)

static func onda(mat: Material) -> Node3D:
	var n := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 32:
		for y in 12:
			var vs: Array[Vector3] = []
			for ij in [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
				var u: float = ij.x/32.0
				var v: float = ij.y/12.0
				var a: float = v * 2.5
				vs.append(Vector3((u-.5)*8.0, sin(a)*2.4*(.8+.2*sin(u*PI)), -v*1.7 + .2*sin(u*TAU*3.0)))
			for i in [0,1,2,0,2,3]: st.add_vertex(vs[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	n.add_child(mi)
	return n

static func vulcao(mat: Material) -> Node3D:
	var n := Node3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Seção fechada: encosta, lábio da cratera e interior incandescente.
	var perfil := [Vector2(3.6,0),Vector2(2.6,.65),Vector2(1.6,2.8),Vector2(1.1,3.0),Vector2(.72,2.15),Vector2(0,1.95)]
	for i in 64:
		for j in perfil.size()-1:
			var vs: Array[Vector3] = []
			for ij in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var a: float = ij.x*TAU/64.0
				var r: float = perfil[ij.y].x * (1.0+.07*sin(a*7.0)+.04*cos(a*13.0))
				vs.append(Vector3(cos(a)*r,perfil[ij.y].y*(1.0+.05*sin(a*9.0)),sin(a)*r))
			for k in [0,2,1,0,3,2]: st.add_vertex(vs[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	n.add_child(mi)
	return n

static func cao(mat: Material, altura := 3.2) -> Node3D:
	var raiz := Node3D.new()
	var modelo: Node3D = load("res://mapas/modelos/dog.glb").instantiate()
	raiz.add_child(modelo)
	var caixa := AABB()
	var primeira := true
	for no in modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := no as MeshInstance3D
		var t := Transform3D.IDENTITY
		var atual: Node = mi
		while atual != raiz:
			if atual is Node3D: t = (atual as Node3D).transform * t
			atual = atual.get_parent()
		var b: AABB = t * mi.get_aabb()
		caixa = b if primeira else caixa.merge(b)
		primeira = false
		mi.material_override = mat
	# Jogador: cápsula de 1,6 m. Cão: 3,2 m de altura, escala uniforme.
	var fator := altura / maxf(caixa.size.y,.01)
	modelo.scale *= fator
	# O dog.glb olha para +Z; a técnica orienta o nó com look_at (-Z à frente).
	modelo.rotate_y(PI)
	var centro := Vector3(caixa.get_center().x,caixa.position.y,caixa.get_center().z)*fator
	modelo.position -= modelo.basis.orthonormalized()*centro
	for ap in modelo.find_children("*", "AnimationPlayer", true, false):
		for clip in ap.get_animation_list():
			if "run" in str(clip).to_lower() or "walk" in str(clip).to_lower():
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
				ap.play(clip)
				break
	return raiz

static func faiscas(pai: Node3D, mat: Material, quantidade := 14) -> void:
	for i in quantidade:
		var a := i*TAU/quantidade
		var m := elipsoide(pai, Vector3.ZERO, Vector3.ONE*(.12+.06*(i%3)), mat)
		m.set_meta("vel", Vector3(cos(a)*3.5,3.0+(i%4),sin(a)*3.5))
		m.set_meta("brasa", true)

static func animar_brasas(pai: Node3D, delta: float) -> void:
	for n in pai.get_children():
		if not n.has_meta("brasa"): continue
		var v: Vector3 = n.get_meta("vel")
		v.y -= delta*6.0
		n.position += v*delta
		n.set_meta("vel",v)

## Material de partícula billboard sem iluminação (brasa/gota ou fumaça).
static func _mat_particula(aditivo: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if aditivo: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m

static func _rampa(cores: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(range(cores.size()).map(func(i): return float(i)/(cores.size()-1)))
	g.colors = PackedColorArray(cores)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func _gpu(quantidade: int, vida: float, pm: ParticleProcessMaterial, malha: QuadMesh, mat: Material) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = quantidade
	p.lifetime = vida
	p.process_material = pm
	malha.material = mat
	p.draw_pass_1 = malha
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-20,-6,-20), Vector3(40,30,40))
	return p

## Gotas de lava que sobem e CAEM no chão (gravidade forte, esfriam de amarelo a vermelho).
static func gotas_de_lava(pai: Node3D, pos: Vector3, raio: float, quantidade := 36) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = raio
	pm.direction = Vector3.UP
	pm.spread = 55.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 7.0
	pm.gravity = Vector3(0,-14.0,0)
	pm.scale_min = .5
	pm.scale_max = 1.2
	pm.color_ramp = _rampa([Color(1,.95,.35,1),Color(1,.45,.04,1),Color(.8,.08,0,.9),Color(.25,.03,0,0)])
	var q := QuadMesh.new()
	q.size = Vector2(.22,.22)
	var p := _gpu(quantidade, 1.5, pm, q, _mat_particula(true))
	p.position = pos
	pai.add_child(p)
	return p

## Fumaça preta densa saindo da boca do vulcão.
static func fumaca_negra(pai: Node3D, pos: Vector3, escala := 1.0) -> GPUParticles3D:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = .9*escala
	pm.direction = Vector3.UP
	pm.spread = 14.0
	pm.initial_velocity_min = 2.0*escala
	pm.initial_velocity_max = 3.6*escala
	pm.gravity = Vector3(.5,1.2,0)
	pm.damping_min = .3
	pm.damping_max = .6
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.4
	pm.turbulence_noise_scale = 1.6
	pm.scale_min = 1.8*escala
	pm.scale_max = 3.2*escala
	pm.scale_curve = _curva([[0.0,.35],[.5,1.0],[1.0,1.5]])
	pm.color_ramp = _rampa([Color(.02,.02,.02,0),Color(.04,.035,.035,.85),Color(.1,.09,.09,.55),Color(.12,.11,.11,0)])
	var q := QuadMesh.new()
	q.size = Vector2(1,1)
	var p := _gpu(48, 4.5, pm, q, _mat_particula(false))
	p.position = pos
	pai.add_child(p)
	return p

static func _curva(pontos: Array) -> CurveTexture:
	var c := Curve.new()
	for pt in pontos: c.add_point(Vector2(pt[0],pt[1]))
	var t := CurveTexture.new()
	t.curve = c
	return t

## Bola de lava lançada em arco (balística simulada em animar_bolas).
static func bola_de_lava(pai: Node3D, mat: Material, origem: Vector3, velocidade: Vector3, tamanho: float) -> MeshInstance3D:
	var b := elipsoide(pai, Vector3.ZERO, Vector3.ONE*tamanho, mat)
	b.top_level = true
	b.global_position = origem
	b.set_meta("bola", true)
	b.set_meta("vel", velocidade)
	gotas_de_lava(b, Vector3.ZERO, tamanho*.3, 8).amount_ratio = 1.0
	return b

## Move as bolas em arco e remove cada uma ao tocar o chão.
static func animar_bolas(pai: Node3D, delta: float, chao_y: Callable) -> void:
	for n in pai.get_children():
		if not n.has_meta("bola"): continue
		var v: Vector3 = n.get_meta("vel")
		v.y -= delta*16.0
		n.global_position += v*delta
		n.set_meta("vel",v)
		if v.y < 0.0 and n.global_position.y <= float(chao_y.call(n.global_position)) + .1:
			n.queue_free()

static func animar_cao(raiz: Node3D, velocidade: float) -> void:
	for ap in raiz.find_children("*", "AnimationPlayer", true, false):
		var clip := "run" if velocidade > .3 else "idle"
		if ap.has_animation(clip):
			if ap.current_animation != clip: ap.play(clip,.15)
			ap.speed_scale = clampf(velocidade/6.3,.5,2.0) if clip == "run" else 1.0
