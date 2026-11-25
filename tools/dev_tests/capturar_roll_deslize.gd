extends SceneTree
# Fotos de lado do roll (Q) e do deslize (Ctrl) pelo clipe de ação (03/10/2026).
#   DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_roll_deslize.gd -- <pasta>
# Frente do modelo à DIREITA da foto (câmera em +X).
var j: CharacterBody3D
func _initialize() -> void:
	rodar.call_deferred()
func rodar() -> void:
	var saida: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(700, 600)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	j = load("res://src/historia/ModoHistoria.gd").colocar_civil(mundo, 2, Vector3(0, .85, 0))
	j.set_physics_process(false)
	j.set_process(false)
	await process_frame
	j._char_model.rotation = Vector3.ZERO
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.fov = 45
	cam.make_current()
	cam.position = Vector3(3.8, 1.0, 0)
	cam.look_at(Vector3(0, 0.75, 0))
	var anim = j._proc_anim
	for caso in [["roll", DashController.CLIPE, DashController.CLIPE_INICIO, DashController.CLIPE_FIM], ["deslize", "res://assets/animations/running_slide.res", 0.07, 1.44]]:
		for k in 6:
			anim.acao_clipe = caso[1]
			anim.acao_tempo = lerpf(caso[2], caso[3], k / 5.0)
			for i in 6:
				anim.update(Vector3(0, 0, -4), true, false, 1.0 / 60.0, 0.0)
			for i in 2: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(saida.path_join("%s_%d.png" % [caso[0], k]))
	quit()
