extends SceneTree
# Captura frames LIMPOS de um estado de animação, sem precisar jogar.
# Monta uma cena mínima (câmera + luz + personagem), dirige o ProceduralAnimator
# com parâmetros fixos e salva PNGs — assim dá pra julgar a pose com calma e
# comparar antes/depois de um ajuste.
#
# Uso:
#   DISPLAY=:1 godot --path . -s tools/dev_tests/captura_anim.gd -- <personagem> <estado> <saida>
#   estados: idle | walk | run | air
#
# Ex.: DISPLAY=:1 godot --path . -s tools/dev_tests/captura_anim.gd -- crocodile walk /tmp/cap

const N_FRAMES := 8          # amostras ao longo do ciclo
const PASSOS_ENTRE := 10     # frames de simulação entre cada captura

func _init() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var cid: String = args[0] if args.size() > 0 else "crocodile"
	var estado: String = args[1] if args.size() > 1 else "walk"
	var saida: String = args[2] if args.size() > 2 else "/tmp/cap"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	var raiz := Node3D.new()
	get_root().add_child(raiz)

	# --- cenário mínimo: chão, luz, céu ---
	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.55, 0.58, 0.62)
	chao.material_override = cm
	raiz.add_child(chao)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-45, -35, 0)
	luz.light_energy = 1.3
	raiz.add_child(luz)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.72, 0.78, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.72)
	env.ambient_light_energy = 0.8
	amb.environment = env
	raiz.add_child(amb)

	# --- personagem ---
	var data := CharacterBuilder.build_character(cid)
	var modelo: Node3D = data["node"]
	raiz.add_child(modelo)
	var skinnado: bool = data.get("skinned", false)
	if skinnado:
		var arm := modelo.find_child("Armature", true, false)
		if arm is Node3D:
			(arm as Node3D).rotation.y += PI
		var ap: AnimationPlayer = data.get("anim_player")
		if ap:
			ap.active = false

	var prof := BodyScanner.scan(modelo)
	var anim := ProceduralAnimator.new()
	modelo.add_child(anim)
	anim.setup(prof)

	# Enquadra pelo tamanho REAL do personagem (cada modelo tem escala própria).
	await process_frame
	var ab: AABB = PlayerModelKit.skeleton_aabb(modelo) if skinnado else PlayerModelKit.model_aabb(modelo)
	var alt: float = maxf(ab.size.y, 0.5)
	var centro: Vector3 = ab.position + ab.size * 0.5
	print("[captura] altura=%.2f centro=%s" % [alt, str(centro)])

	# Perfil puro (de lado): é assim que se lê passada e balanço de braço.
	var cam := Camera3D.new()
	raiz.add_child(cam)
	cam.position = centro + Vector3(alt * 1.9, alt * 0.12, 0)
	cam.look_at(centro, Vector3.UP)

	# Chão na altura dos pés, pra dar referência de contato.
	chao.position.y = ab.position.y

	var vel := Vector3.ZERO
	var no_chao := true
	var correndo := false
	match estado:
		"walk": vel = Vector3(0, 0, -2.4)
		"run":
			vel = Vector3(0, 0, -6.0)
			correndo = true
		"air":
			vel = Vector3(0, -4.0, -2.0)
			no_chao = false

	print("[captura] ", cid, " / ", estado, " -> ", saida)
	print("[captura] skinnado=", skinnado, "  papeis=", (prof["nodes"] as Dictionary).size())

	# assenta a pose antes de capturar (o blend leva alguns frames)
	for i in 30:
		anim.update(vel, no_chao, false, 1.0 / 60.0, 0.0, correndo)

	for f in N_FRAMES:
		for i in PASSOS_ENTRE:
			anim.update(vel, no_chao, false, 1.0 / 60.0, 0.0, correndo)
		await process_frame
		await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("%s/%s_%s_%02d.png" % [saida, cid, estado, f])

	print("[captura] ok — ", N_FRAMES, " frames")
	quit()
