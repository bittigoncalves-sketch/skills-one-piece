extends SceneTree
## Captura o corte VERTICAL da Yoru em 5 fases, de lado e em 3/4, com o
## marcador de fio/dorso ligado. Serve para OLHAR o que
## `tools/dev_tests/medir_fio_yoru.gd` mede em número.
## godot --path . --display-server x11 -s tools/dev_tests/captura_fio_yoru.gd
class Fixture extends Node3D:
	var _char_model: Node3D
	var _proc_anim: Node

func _init() -> void:
	await process_frame
	root.size = Vector2i(760, 860)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("101a26")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("adbaca")
	env.environment.ambient_light_energy = 0.75
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 2.2
	world.add_child(light)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.current = true
	var p := Fixture.new()
	world.add_child(p)
	p._char_model = CharacterBuilder.build_character("base").node
	p.add_child(p._char_model)
	var caixa := PlayerModelKit.model_aabb(p._char_model)
	var fator := 1.5 / caixa.size.y
	p._char_model.scale = Vector3.ONE * fator
	p._char_model.position.y = -fator * caixa.position.y
	var socket: Node3D = p._char_model.find_child("Weapon_R", true, false)
	socket.rotation.x = PI
	var sword := YoruSword.ligar_na_mao(socket)
	var rig := YoruRig.new()
	rig.setup(p, sword)
	var tag := OS.get_environment("TAG")
	if tag == "":
		tag = "atual"
	DirAccess.make_dir_recursive_absolute("res://art_src/previews/yoru_fio")
	var id := "M1_2"
	var m := YoruMoves.get_move(id)
	var dur: float = YoruMoves.duration(id)
	for vista in [["lado", Vector3(5.0, 1.3, 0.0)], ["tres_quartos", Vector3(3.4, 2.0, -4.2)]]:
		camera.position = vista[1]
		camera.look_at(Vector3(0, 1.05, 0))
		for k in 5:
			# do fim da preparação até o fim da janela ativa
			var t: float = float(m.startup) * 0.55 + (float(m.startup) * 0.45 + float(m.active)) * float(k) / 4.0
			rig.pose(id, minf(t, dur), Vector3.FORWARD)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(
				"res://art_src/previews/yoru_fio/%s_%s_%d.png" % [tag, vista[0], k])
	print("CAPTURA ok tag=", tag)
	quit()
