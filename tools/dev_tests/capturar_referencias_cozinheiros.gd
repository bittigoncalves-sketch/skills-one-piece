extends SceneTree
## Referências reais do elenco, sem jogador nem captura do mouse.
func _initialize() -> void:
	_executar.call_deferred()

func _executar() -> void:
	var mundo := Node3D.new()
	root.add_child(mundo)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.17, 0.20, 0.25)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_energy = 0.8
	mundo.add_child(env)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, -25, 0)
	mundo.add_child(luz)
	var ids := ["nami", "blackbeard", "crocodile"]
	for i in ids.size():
		var corpo := Node3D.new()
		corpo.position = Vector3((i - 1) * 2.2, 0.8, 0)
		mundo.add_child(corpo)
		var rig := PlayerRig.new()
		corpo.add_child(rig)
		rig.montar_em(corpo)
		rig.montar(ids[i])
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.position = Vector3(0, 2.5, -9)
	cam.look_at(Vector3(0, 1.1, 0))
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_src/validation/cozinheiros/referencias.png")
	quit()
