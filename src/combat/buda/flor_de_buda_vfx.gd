extends Node3D
## Flor, ondas, raios e faíscas: somente malhas e materiais nativos, sem imagens.
var petalas: Array[MeshInstance3D] = []
var ondas: Array[MeshInstance3D] = []
var materiais: Array[StandardMaterial3D] = []
var particulas: MultiMeshInstance3D
var raios: MultiMeshInstance3D
var nucleo: MeshInstance3D
var luz: OmniLight3D

func _ready() -> void:
	name = "FlorDeBudaVFX"
	add_to_group("flor_de_buda_vfx")
	var dourado := material(Color(1.0,0.64,0.08,0.72), 2.5)
	var branco := material(Color(1.0,0.94,0.62,0.8), 3.5)
	var petala := malha_petala()
	for i in 24:
		var m := MeshInstance3D.new()
		m.mesh = petala
		m.material_override = dourado if i < 12 else branco
		m.rotation.y = TAU * float(i%12)/12.0 + (0.26 if i >= 12 else 0.0)
		m.position.y = 0.12 + (0.12 if i >= 12 else 0.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		petalas.append(m)
	for i in 3:
		var m := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.95
		torus.outer_radius = 1.0
		torus.rings = 64
		torus.ring_segments = 8
		m.mesh = torus
		m.material_override = branco
		m.position.y = 0.2+i*0.7
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		ondas.append(m)
	var cristal := PrismMesh.new()
	cristal.size = Vector3(0.09,0.30,0.09)
	particulas = multimalha(cristal, 72, branco)
	var raio := PrismMesh.new()
	raio.size = Vector3(0.18,1.0,0.18)
	raios = multimalha(raio, 20, dourado)
	nucleo = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0
	esfera.height = 2.0
	esfera.radial_segments = 32
	esfera.rings = 16
	nucleo.mesh = esfera
	nucleo.material_override = material(Color(1.0,0.86,0.34,0.4), 4.0)
	nucleo.position.y = 1.0
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nucleo)
	luz = OmniLight3D.new()
	luz.light_color = Color(1.0,0.72,0.24)
	luz.omni_range = 16.0
	luz.position.y = 2.0
	add_child(luz)
	avancar(0.0)

func material(cor: Color, emissao: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = cor
	mat.emission_enabled = true
	mat.emission = Color(cor.r,cor.g,cor.b)
	mat.emission_energy_multiplier = emissao
	mat.set_meta("alpha_base", cor.a)
	materiais.append(mat)
	return mat

func multimalha(mesh: Mesh, quantidade: int, mat: Material) -> MultiMeshInstance3D:
	var m := MultiMeshInstance3D.new()
	m.multimesh = MultiMesh.new()
	m.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	m.multimesh.mesh = mesh
	m.multimesh.instance_count = quantidade
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

func avancar(t: float) -> void:
	if petalas.is_empty(): return
	var abrir := smoothstep(0.15,1.2,t)
	var explosao := maxf(0.0,t-1.2)
	var apagar := 1.0-smoothstep(2.0,2.8,t)
	for mat in materiais:
		var cor := mat.albedo_color
		cor.a = float(mat.get_meta("alpha_base"))*apagar
		mat.albedo_color = cor
	for i in petalas.size():
		var k := (0.2+abrir*0.8) * (1.0+explosao*0.45)
		if i >= 12: k *= 0.72
		petalas[i].scale = Vector3(k,0.5+abrir*0.5,k)
	for i in ondas.size():
		var pulso := maxf(0.0,explosao-float(i)*0.10)
		ondas[i].visible = pulso > 0.0
		ondas[i].scale = Vector3.ONE*(1.0+minf(pulso/0.9,1.0)*9.0)
	nucleo.visible = explosao > 0.0 and explosao < 0.45
	nucleo.scale = Vector3.ONE*(0.2+explosao*10.0)
	luz.light_energy = (0.6+abrir*0.9+maxf(0.0,1.0-explosao*4.0)*float(explosao>0)*4.0)*apagar
	for i in 72:
		var a := float(i)*2.399963 + t*0.35
		var r := (1.2+float(i%9)*0.38)*(0.4+abrir*0.6)+explosao*(2.0+float(i%4))
		var p := Vector3(cos(a)*r,0.4+fmod(float(i)*0.27+t*1.4,4.5)+explosao*1.2,sin(a)*r)
		var k := (0.45+float(i%3)*0.25)*apagar
		particulas.multimesh.set_instance_transform(i,Transform3D(Basis.from_euler(Vector3(t,a,t*0.4)).scaled(Vector3.ONE*k),p))
	raios.visible = explosao > 0.0
	for i in 20:
		var a := TAU*float(i)/20.0
		var direcao := Vector3(cos(a),0.3+float(i%4)*0.18,sin(a)).normalized()
		var comprimento := (2.5+float(i%5)*0.6)*minf(explosao*7.0,1.0)*apagar
		var b := Basis(Quaternion(Vector3.UP,direcao)).scaled(Vector3(1.0,comprimento,1.0))
		raios.multimesh.set_instance_transform(i,Transform3D(b,Vector3.UP+direcao*(2.0+explosao*5.0)))

func malha_petala() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 12:
		var pontos: Array[Vector3] = []
		for u in [float(j)/12.0,float(j+1)/12.0]:
			var largura: float = sin(PI*u)*1.05
			for lado in [-1.0,1.0]:
				pontos.append(Vector3(lado*largura,0.08+pow(u,2.0)*2.4,0.45+u*4.7))
		for i in [0,2,1,1,2,3]: st.add_vertex(pontos[i])
	st.generate_normals()
	return st.commit()
