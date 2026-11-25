extends SceneTree
## Inspeção de assets isolada, sem arena ou ENet. Requer renderer com janela.
const Binding := preload("res://src/characters/BaraHandBinding.gd")
const OUT := "res://art_src/validation/bara_bara/hands/"
class Fixture extends Node3D:
	var _char_model: Node3D

func _init() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.07, 0.085, 0.12)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.85, 0.9, 1)
	environment.environment.ambient_light_energy = 0.55
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -30, 0)
	key.light_energy = 1.1
	world.add_child(key)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 40
	for avatar in ["buggy", "base"]:
		var actor := Fixture.new()
		world.add_child(actor)
		if avatar == "buggy":
			var visual := load("res://assets/models/bosses/buggy/buggy_boss_visual.tres") as CharacterVisualDefinition
			actor._char_model = visual.instantiate_visual().node
			actor._char_model.scale = Vector3.ONE * 1.53
		else:
			actor._char_model = CharacterBuilder.build_character("base").node
			actor._char_model.scale = Vector3.ONE * 0.88
		actor.add_child(actor._char_model)
		var binding := Binding.new()
		if not binding.setup(actor):
			push_error(binding.reason)
			quit(1)
			return
		camera.position = Vector3(-2.5, 1.55, -3.5)
		camera.look_at(Vector3(0, 0.75, -0.1))
		await capture(avatar + "_attached")
		for side in 2:
			binding.present(side, true, binding.socket(side).translated(Vector3(0, 0, -0.65)))
		await capture(avatar + "_detached")
		var wrist := binding.socket(0).origin
		camera.position = wrist + Vector3(-0.8, 0.42, -1.4)
		camera.look_at(wrist + Vector3(0, 0, -0.3))
		camera.fov = 32
		await capture(avatar + "_left_wrist")
		binding.dispose()
		actor.queue_free()
		await process_frame
		camera.fov = 40
	world.queue_free()
	await process_frame
	quit()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(OUT + label + ".png")
	print("CAPTURE ", label, " = ", result)
	if result != OK:
		quit(1)
