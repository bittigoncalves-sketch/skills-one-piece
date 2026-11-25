extends SceneTree
## Renderiza o SPRINT do base_v2 ao longo de um ciclo inteiro, de perfil e em 3/4.
## É a contraparte visual de `tools/dev_tests/medir_corrida.gd`: os números dizem
## que o braço varre 27°, isto diz se o braço varrendo 27° tem boa aparência.
##
## godot --path . --display-server x11 -s tools/dev_tests/captura_corrida.gd
const DT := 1.0 / 60.0
const VEL := Vector3(0, 0, -7.0)
const CICLO := 23.5          # quadros por ciclo no RUN (medido pelo test_walk_run)
var cam: Camera3D

func _init() -> void:
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-42, -145, 0)
	luz.light_energy = 1.5
	mundo.add_child(luz)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.85
	amb.environment = env
	mundo.add_child(amb)
	cam = Camera3D.new()
	mundo.add_child(cam)

	var d := CharacterBuilder.build_character("base")
	var m: Node3D = d["node"]
	mundo.add_child(m)
	var ab := PlayerModelKit.model_aabb(m)
	var ky: float = 1.5 / ab.size.y
	m.scale = Vector3(ky, ky, ky)
	m.position = Vector3(0, -ky * ab.position.y, 0)
	await process_frame
	var prof := BodyScanner.scan(m)
	var anim := ProceduralAnimator.new()
	m.add_child(anim)
	anim.setup(prof)
	for i in 240:                        # estabiliza o filtro
		anim.update(VEL, true, false, DT, 0.0, true)

	# 6 instantes de UM ciclo. Mais que isso não cabe no olho; menos esconde as
	# pontas do arco, que é justamente onde a pose antiga era rígida.
	var passo: int = int(round(CICLO / 6.0))
	for fase in 6:
		if fase > 0:
			for i in passo:
				anim.update(VEL, true, false, DT, 0.0, true)
		# PERFIL: é a vista que mostra o balanço do braço e a inclinação.
		cam.position = Vector3(2.30, 0.90, 0.0)
		cam.look_at(Vector3(0, 0.78, 0), Vector3.UP)
		cam.fov = 40
		await _capture("corrida_perfil_%d.png" % fase)
		# 3/4 de frente: mostra a torção de tronco e os ombros retraídos.
		cam.position = Vector3(1.35, 1.02, -2.15)
		cam.look_at(Vector3(0, 0.72, 0), Vector3.UP)
		await _capture("corrida_34_%d.png" % fase)
	quit()

func _capture(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://art_src/previews/" + nome)
	print("CAPTURA ", nome)
