extends SceneTree
## Ícone 2D reproduzível: captura ortográfica transparente do modelo real do item.
const Bau := preload("res://src/inventario/bau_de_tesouros.gd")

func _init() -> void:
	executar.call_deferred()

func executar() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("e6e8f2")
	env.environment.ambient_light_energy = .8
	viewport.add_child(env)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, -25, 0)
	luz.light_energy = 1.4
	viewport.add_child(luz)
	viewport.add_child(Bau.modelo())
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.9
	viewport.add_child(cam)
	cam.position = Vector3(2, 1.9, -3)
	cam.look_at(Vector3(0,.44,0))
	cam.current = true
	for i in 6: await process_frame
	await RenderingServer.frame_post_draw
	var img := viewport.get_texture().get_image()
	var erro := img.save_png(Bau.ICONE)
	print("ICONE_BAU: ", error_string(erro), " ", img.get_size())
	quit(0 if erro == OK else 1)
