extends SceneTree
# ============================================================================
#  CLIPES REASSADOS (conversão v3) NO JOGO — fotos com GPU (07/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_clipes_no_jogo.gd -- <pasta>
#
#  Um jogador de verdade (`ModoHistoria.colocar_civil`) com o ProceduralAnimator do jogo:
#  a corrida e o sprint pela marcha (`update` com velocidade), o resto pelo clipe de ação
#  (o caminho do roll do Q, do deslize, do parkour e do bloco Animação do Builder).
#  Uma linha por caso, 5 instantes, vista 3/4 de frente. Sai `clipes_no_jogo.png`.
# ============================================================================

const A := "res://assets/animations/"
const CASOS := [
	["corrida", ""], ["sprint", ""], ["roll do Q", "sprinting_forward_roll"], ["deslize", "running_slide"],
	["wall run", "wall_run"], ["punching", "punching"], ["roundhouse_kick", "roundhouse_kick"],
	["uppercut_jab", "uppercut_jab"],
]
const QUADROS := 5

var j: CharacterBody3D


func _initialize() -> void:
	rodar.call_deferred()


func rodar() -> void:
	var saida: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(640, 560)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var chao := MeshInstance3D.new()
	chao.mesh = PlaneMesh.new()
	(chao.mesh as PlaneMesh).size = Vector2(8, 8)
	mundo.add_child(chao)
	j = load("res://src/historia/ModoHistoria.gd").colocar_civil(mundo, 2, Vector3(0, .85, 0))
	j.set_physics_process(false)
	j.set_process(false)
	await process_frame
	j._char_model.rotation = Vector3.ZERO
	var rotulo := Label3D.new()
	rotulo.font_size = 40
	rotulo.pixel_size = 0.004
	rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rotulo.no_depth_test = true
	rotulo.position = Vector3(0, 2.35, 0)
	mundo.add_child(rotulo)
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.fov = 45
	cam.make_current()
	cam.position = Vector3(2.3, 1.45, -3.3)
	cam.look_at(Vector3(0, 0.9, 0))
	var anim = j._proc_anim
	var folha: Image = null
	for c in CASOS.size():
		var nome: String = CASOS[c][0]
		var clipe: String = CASOS[c][1]
		var dur := 0.73
		if clipe != "":
			dur = (load(A + clipe + ".res") as Animation).length
		for k in QUADROS:
			var u := (k + 0.5) / QUADROS
			rotulo.text = "%s  %d/%d" % [nome, k + 1, QUADROS]
			if clipe == "":
				# A marcha: avança o ciclo pela velocidade (corrida ou sprint).
				anim.acao_clipe = ""
				var sprint := nome == "sprint"
				for i in (12 if k > 0 else 90):
					anim.update(Vector3(0, 0, -7.0 if sprint else -4.5), true, false, 1.0 / 60.0, 0.0, sprint)
			else:
				anim.acao_clipe = A + clipe + ".res"
				anim.acao_tempo = dur * u
				for i in 6:
					anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0)
			for i in 2:
				await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.resize(320, 280, Image.INTERPOLATE_BILINEAR)
			if folha == null:
				folha = Image.create(320 * QUADROS, 280 * CASOS.size(), false, img.get_format())
			folha.blit_rect(img, Rect2i(0, 0, 320, 280), Vector2i(320 * k, 280 * c))
	folha.save_png(saida.path_join("clipes_no_jogo.png"))
	print("CAPTURA OK: ", saida.path_join("clipes_no_jogo.png"))
	quit()
