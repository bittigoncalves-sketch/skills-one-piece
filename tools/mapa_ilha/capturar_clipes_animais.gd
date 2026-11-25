extends SceneTree
# ============================================================================
#  CLIPES DOS ANIMAIS NO GODOT — folha de quadros com GPU (02/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_clipes_animais.gd -- cow [horse ...]
#        [--saida res://art_src/validation/animais_rig]
#
#  Prova do rig (tools/blender/rig_animais.py) DEPOIS da importação: o modelo da loja na
#  escala do jogo (tamanho padrão), num chão com a cápsula de 1,6 m do jogador ao lado
#  como régua, e cada clipe (idle, walk, run, damage, attack, death) em 6 quadros de
#  lado. Uma folha por espécie: <saida>/<id>_godot.png. Não toca no mapa.
# ============================================================================

## Voador não tem walk/run: a linha deles mostra o "fly" (bater asas).
const CLIPES := ["idle", "walk", "run", "damage", "attack", "death", "fly"]
const QUADROS := 6
const TAM := Vector2i(320, 240)

var saida := "res://art_src/validation/animais_rig"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	var args := Array(OS.get_cmdline_user_args())
	if args.has("--saida"):
		saida = args[args.find("--saida") + 1]
		args.remove_at(args.find("--saida") + 1)
		args.erase("--saida")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = TAM
	var bib := BibliotecaDeModelos.padrao()
	var cena := _estudio()
	root.add_child(cena)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cena.add_child(cam)
	cam.make_current()
	for id: String in args:
		var modelo := bib.instanciar(id)
		if modelo == null:
			push_error("sem modelo " + id)
			continue
		var t: Vector3 = bib.info(id)["tamanho"]
		var c: Vector3 = bib.info(id)["centro"]
		var k := bib.tamanho_padrao(id).y / maxf(t.y, 0.0001)
		modelo.scale = Vector3.ONE * k
		modelo.position = Vector3(-c.x * k, -(c.y - t.y * 0.5) * k, -c.z * k)
		cena.add_child(modelo)
		var ap := modelo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var altura := t.y * k
		var comp := t.z * k
		var vista := maxf(comp * 1.5, altura * 2.2)
		cam.size = vista
		cam.position = Vector3(10.0, vista * 0.36, 0.0)
		cam.look_at(Vector3(0, vista * 0.36, 0))
		var folha := Image.create(TAM.x * QUADROS, TAM.y * CLIPES.size(), false, Image.FORMAT_RGBA8)
		for linha in CLIPES.size():
			# Mesmo casamento de nomes do jogo: acha "extra/damage" (biblioteca gerada para
			# os modelos que já vieram com ossos) e "Rig|...|monkey_walk".
			var nome := AnimadorDeAnimal._clipe_por_chave(ap.get_animation_list(), CLIPES[linha])
			if nome.is_empty():
				continue
			var dur := ap.get_animation(nome).length
			ap.play(nome)
			ap.pause()
			for q in QUADROS:
				ap.seek(dur * q / (QUADROS - 1), true)
				for i in 3:
					await process_frame
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				folha.blit_rect(img, Rect2i(Vector2i.ZERO, TAM), Vector2i(q * TAM.x, linha * TAM.y))
		folha.save_png(ProjectSettings.globalize_path(saida.path_join(id + "_godot.png")))
		print("CLIPES_GODOT %s: %s" % [id, ", ".join(ap.get_animation_list())])
		modelo.queue_free()
		await process_frame
	quit()


func _estudio() -> Node3D:
	var cena := Node3D.new()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.84, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	cena.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50, 35, 0)
	sol.shadow_enabled = true
	cena.add_child(sol)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(40, 40)
	chao.mesh = plano
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.55, 0.38)
	chao.material_override = mat
	cena.add_child(chao)
	# Régua: a cápsula do jogador (1,6 m), atrás do bicho.
	var regua := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.3
	capsula.height = 1.6
	regua.mesh = capsula
	regua.position = Vector3(-1.5, 0.8, 0)
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.9, 0.5, 0.2, 0.5)
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	regua.material_override = m2
	cena.add_child(regua)
	return cena
