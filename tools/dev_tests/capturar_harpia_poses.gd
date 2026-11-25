extends SceneTree
## Sonda GPU isolada: não inicia modo história nem captura mouse.
const POSE = preload("res://src/historia/bosses/harpia/pose_harpia.gd")
const VENTO = preload("res://src/historia/bosses/harpia/vento_harpia.gd")
var _camera: Camera3D
var _saida := "res://art_src/validation/harpia"

func _init() -> void:
	_executar.call_deferred()

func _executar() -> void:
	if not OS.get_environment("HARPIA_CAPTURAS").is_empty():
		_saida = OS.get_environment("HARPIA_CAPTURAS")
	root.size = Vector2i(1200, 800)
	DirAccess.make_dir_recursive_absolute(_saida)
	var mundo := Node3D.new()
	root.add_child(mundo)
	var ambiente := WorldEnvironment.new()
	ambiente.environment = Environment.new()
	ambiente.environment.background_mode = Environment.BG_COLOR
	ambiente.environment.background_color = Color(0.035, 0.065, 0.1)
	ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.environment.ambient_light_color = Color(0.78, 0.85, 1)
	ambiente.environment.ambient_light_energy = 0.65
	mundo.add_child(ambiente)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, -25, 0)
	luz.light_energy = 2.0
	mundo.add_child(luz)
	_camera = Camera3D.new()
	_camera.fov = 42
	mundo.add_child(_camera)
	_camera.make_current()
	var bib := BibliotecaDeModelos.new("res://mapas/modelos")
	var modelo := bib.instanciar("harpia_-_animated_low_poly")
	mundo.add_child(modelo)
	var e := bib.info("harpia_-_animated_low_poly")
	var k := 7.0 / (e["tamanho"] as Vector3).x
	modelo.scale = Vector3.ONE * k
	modelo.position = -(e["centro"] as Vector3) * k
	var ap := modelo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for nome in ap.get_animation_list():
		if String(nome).to_lower().ends_with("gliding"):
			ap.play(nome)
			ap.seek(0.3, true)
			ap.pause()
			break
	var pose := POSE.new()
	pose.montar(modelo)
	var sk := modelo.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for i in sk.get_bone_count():
		print("OSSO ", i, " ", sk.get_bone_name(i), " pai ", sk.get_bone_parent(i), " pos ", modelo.to_local(sk.to_global(sk.get_bone_global_rest(i).origin)))
	for fase in ["base", "preparar_investida", "investida", "recuperar", "preparar_vendaval", "lancar_vendaval"]:
		pose.atualizar(fase, 0.5 if fase in ["recuperar", "lancar_vendaval"] else 1.0, 0.016)
		for vista in ["frente", "lateral", "cima"]:
			_camera.position = Vector3(0, 2.3, 12) if vista == "frente" else (Vector3(11, 2.5, 1) if vista == "lateral" else Vector3(0, 12, 0.1))
			_camera.look_at(Vector3.ZERO)
			await _foto(fase + "_" + vista)
	pose.restaurar()
	assert(not pose.active, "restaurar desativa o modifier")
	modelo.visible = false
	var vento := VENTO.new()
	mundo.add_child(vento)
	for modo in ["tornado", "investida", "preparacao"]:
		vento.configurar(modo, 2.5, 7.0)
		vento.atualizar(0.7, 1.0)
		_camera.position = Vector3(11, 6, 15)
		_camera.look_at(Vector3(0, 3, 0))
		await _foto("vento_" + modo)
	vento.limpar()
	assert(not vento.visible and not vento._audio.playing, "limpar interrompe visual e loop de vento")
	vento._audio.stream.save_to_wav(_saida.path_join("vento_procedural.wav"))
	print("HARPIA POSES: capturas em ", _saida)
	quit()

func _foto(nome: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_saida.path_join(nome + ".png"))
