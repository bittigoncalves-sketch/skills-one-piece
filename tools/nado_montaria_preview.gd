extends SceneTree
## Fixture visual: Player real, sem capturar mouse nem salvar a campanha.
const SAIDA := "res://art_src/validation/nado_montaria"
var mundo: Node3D
var j: CharacterBody3D
var camera: Camera3D
var controle: Node

func _initialize() -> void:
	rodar.call_deferred()

func foto(nome: String) -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA.path_join(nome + ".png"))

func rodar() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	root.size = Vector2i(1280, 720)
	mundo = Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var chao := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(50, .2, 50)
	chao.mesh = caixa
	chao.position.y = -.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.45, .54, .42)
	chao.material_override = mat
	mundo.add_child(chao)
	chao.create_trimesh_collision()
	var modo: GDScript = load("res://src/historia/ModoHistoria.gd")
	j = modo.colocar_civil(mundo, 2, Vector3(0, .85, 0))
	j.set_physics_process(false)
	j.set_process(false)
	j.set_process_unhandled_input(false)
	j.set_process_input(false)
	await process_frame
	j.set_multiplayer_authority(1)
	camera = Camera3D.new()
	mundo.add_child(camera)
	camera.fov = 45
	camera.make_current()
	controle = load("res://src/historia/pets/montaria.gd").new()
	controle.jogador_de = func(): return j
	controle.biblioteca = MapaMontador.biblioteca_em_uso()
	mundo.add_child(controle)
	for especie: String in ["caranguejo", "horse", "cavalo_da_vila_leve"]:
		var companhia: Node = load("res://src/historia/pets/companhia.gd").new()
		companhia.alvo_de = func(): return j
		mundo.add_child(companhia)
		j.position = Vector3(2, .9, 0)
		var pet: CharacterBody3D = companhia._novo_corpo(especie, especie)
		mundo.add_child(pet)
		pet.position = Vector3(0, .04, 0)
		pet.set_physics_process(false)
		if especie != "caranguejo": pet._visual.rotation.y = pet._desvio_yaw
		for i in 3: await physics_frame
		print("MONTAR ", especie, " ", controle.montar(pet))
		for i in 80: controle.conduzir(Vector3.ZERO, false, false, 1.0 / 60)
		camera.position = Vector3(4, 2.6, -5)
		camera.look_at(Vector3(0, 1.0, 0))
		await foto(especie)
		if especie == "caranguejo":
			camera.position = Vector3(4.5, 1.8, 0)
			camera.look_at(Vector3(0, 1, 0))
			await foto("caranguejo_lateral")
		controle.desmontar(true)
		pet.queue_free()
		companhia.queue_free()
		await process_frame
	j.position = Vector3(0, .16, 0)
	j._char_model.rotation = Vector3.ZERO
	j.modo_na_agua = "nadando"
	chao.position.y = -2
	var oceano: Node3D = load("res://src/world/oceano_historia.gd").new()
	mundo.add_child(oceano)
	oceano.configurar({"pecas": [{"id": "baseplate", "tipo": "caixa", "posicao": Vector3(1000, -1, 1000), "tamanho": Vector3(10, 2, 10), "rotacao_graus": Vector3.ZERO}]})
	oceano.nivel = 0
	oceano.position.y = 0
	oceano.material.set_shader_parameter("tempo_fixo", 0.0)
	oceano.material.set_shader_parameter("altura_ondas", 0.0)
	var anim: Node = j._proc_anim
	camera.position = Vector3(2.7, 1.9, -3.4)
	camera.look_at(Vector3(0, .25, -.25))
	for i in 90: anim.update(Vector3(0, 0, -2.6), false, false, 1.0/60, 0)
	for fase in 4:
		for i in 20: anim.update(Vector3(0, 0, -2.6), false, false, 1.0/60, 0)
		await foto("crawl_%d" % fase)
	oceano.visible = false
	camera.position = Vector3(3.3, 1.2, -.2)
	camera.look_at(Vector3(0, .15, -.1))
	await foto("crawl_rig_lateral")
	if "--video" in OS.get_cmdline_user_args():
		camera.position = Vector3(2.7, 1.9, -3.4)
		camera.look_at(Vector3(0, .25, -.25))
		oceano.visible = true
		for i in 60:
			anim.update(Vector3(0, 0, -2.6), false, false, 1.0/30, 0)
			await foto("quadro_%03d" % i)
	print("NADO_MONTARIA_PREVIEW_OK mouse=", Input.mouse_mode)
	quit()
