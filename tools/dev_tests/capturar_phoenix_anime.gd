extends SceneTree
## Turntable reproduzível do asset REAL da engine; história tem captura separada.
const Forma := preload("res://src/effects/phoenix/forma_phoenix.gd")
var SAIDA := OS.get_environment("PHOENIX_CAPTURA_DIR")

var f: Node3D
var camera: Camera3D
func _init() -> void: _rodar.call_deferred()
func _rodar() -> void:
	if SAIDA.is_empty(): SAIDA = "res://art_src/validation/phoenix_anime_2026-10-14/"
	DirAccess.make_dir_recursive_absolute(SAIDA)
	root.size = Vector2i(1440,1000)
	var mundo := Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("162638")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("c1d7f0")
	env.environment.ambient_light_energy = .40
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	mundo.add_child(env)
	var luz := DirectionalLight3D.new()
	mundo.add_child(luz)
	luz.rotation_degrees = Vector3(-40,-32,0)
	luz.light_energy = .9
	luz.shadow_enabled = true
	var chao := MeshInstance3D.new()
	chao.mesh = PlaneMesh.new()
	chao.mesh.size = Vector2(100,100)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("26394a")
	mat.roughness = 1
	chao.material_override = mat
	mundo.add_child(chao)
	f = Forma.new()
	mundo.add_child(f)
	f.set_process(false)
	camera = Camera3D.new()
	mundo.add_child(camera)
	camera.current = true
	camera.fov = 36
	for pose in ["parado","andando","sentado","voando","pousando"]:
		f.position = Vector3.ZERO
		f.atualizar_movimento(Vector3(0,0,-2.8) if pose=="andando" else Vector3.ZERO,pose in ["parado","andando","sentado"],pose=="voando",pose=="sentado")
		for i in 90: f._animar(1.0/60)
		if pose in ["voando","pousando"]: f.position.y = 1.7
		camera.position = Vector3(7,5,-10) if pose not in ["voando","pousando"] else Vector3(9,7,-13)
		camera.look_at(Vector3(0,1.8,.65) if pose not in ["voando","pousando"] else Vector3(0,3.0,.65))
		await foto(pose)
	f.atualizar_movimento(Vector3.ZERO,true,false,false)
	f.position = Vector3.ZERO
	for i in 90: f._animar(1.0/60)
	camera.position = Vector3(2.4,3.3,-3.7)
	camera.look_at(Vector3(0,2.55,-.25))
	await foto("rosto")
	camera.position = Vector3(6,4,8)
	camera.look_at(Vector3(0,1.7,1.3))
	await foto("dorso")
	f.atualizar_movimento(Vector3.ZERO,false,true,false)
	for i in 90: f._animar(1.0/60)
	f.position = Vector3(0,2,0)
	camera.position = Vector3(0,4,-17)
	camera.look_at(Vector3(0,3.5,.3))
	await foto("frente_voo")
	for fase in [0.0, PI/2.0, PI*1.5]:
		f.tempo = fase/6.2
		f._animar(0.0)
		await foto("batida_%d" % int(fase*100))
	camera.position = Vector3(0,7,17)
	camera.look_at(Vector3(0,3,1.5))
	await foto("verso_voo")
	print("PHOENIX_CAPTURE_OK")
	quit()
func foto(nome: String) -> void:
	_congelar_shader(f)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var erro := root.get_texture().get_image().save_png(SAIDA.path_join(nome+".png"))
	assert(erro == OK)
	print("CAPTURA ",nome," erro=",erro," ",f.medidas_rig())

func _congelar_shader(n: Node) -> void:
	if n is MeshInstance3D and n.material_override is ShaderMaterial:
		if n.material_override.shader.resource_path.ends_with("plasma_phoenix.gdshader"):
			n.material_override.set_shader_parameter("relogio",2.0)
	for c in n.get_children(): _congelar_shader(c)
