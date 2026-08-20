extends SceneTree
# Captura a linha do tempo de um golpe da Gura Gura em quadros LIMPOS, para
# julgar a animação com o olho em vez de só com o medidor.
#
# Diferente do `captura_anim.gd`, que amostra um CICLO de locomoção, aqui o eixo
# é a FASE do golpe: as capturas caem em instantes escolhidos da linha do tempo
# (recuo, golpe, assentamento), que é onde a leitura de um soco se decide.
#
# Uso:
#   DISPLAY=:0 godot --path . -s tools/dev_tests/captura_gura.gd -- <estado> <saida> [frente|lado]
#   estados: gura_v_tpose | gura_v_lift | gura_z_soco | gura_x_arremesso | gura_c_kabutsuchi
#
# Ex.: DISPLAY=:0 godot --path . -s tools/dev_tests/captura_gura.gd -- gura_v_tpose /tmp/gura frente

# Instantes da fase, em segundos. Cobrem os três tempos de um soco com folga.
const INSTANTES := [0.00, 0.05, 0.09, 0.13, 0.17, 0.24, 0.34, 0.50, 0.75]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var estado: String = args[0] if args.size() > 0 else "gura_v_tpose"
	var saida: String = args[1] if args.size() > 1 else "/tmp/gura"
	var vista: String = args[2] if args.size() > 2 else "frente"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	var raiz := Node3D.new()
	get_root().add_child(raiz)

	var chao := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(20, 20)
	chao.mesh = pm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.30, 0.34, 0.40)
	chao.material_override = cm
	raiz.add_child(chao)

	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-42, -30, 0)
	luz.light_energy = 1.5
	raiz.add_child(luz)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.42, 0.60)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.78, 0.88)
	env.ambient_light_energy = 0.9
	amb.environment = env
	raiz.add_child(amb)

	var data := CharacterBuilder.build_character("base")
	var modelo: Node3D = data["node"]
	raiz.add_child(modelo)

	var anim := ProceduralAnimator.new()
	modelo.add_child(anim)
	anim.setup(BodyScanner.scan(modelo))

	await process_frame
	var ab: AABB = PlayerModelKit.model_aabb(modelo)
	var alt: float = maxf(ab.size.y, 0.5)
	var centro: Vector3 = ab.position + ab.size * 0.5
	chao.position.y = ab.position.y

	# FRENTE é a vista que prova o T (os dois braços abertos e simétricos). LADO
	# é a que prova o empurrão à frente do soco. As duas juntas contam o golpe.
	var cam := Camera3D.new()
	raiz.add_child(cam)
	if vista == "lado":
		cam.position = centro + Vector3(alt * 1.25, alt * 0.05, 0)
	else:
		cam.position = centro + Vector3(0, alt * 0.05, alt * 1.25)
	cam.look_at(centro, Vector3.UP)

	# ⚠️ O animador lê a `custom_pose` do PAI (`get_parent().get_meta(...)`), e o
	# pai aqui é o modelo — não o Player. Escrever no lugar errado dá uma captura
	# do idle e a impressão de que a pose não existe.
	modelo.set_meta("custom_pose", estado)

	# Deixa o PESO da pose assentar antes de a fase começar a valer: o blend do
	# animador leva ~0,2 s para chegar a 1,0. Sem isto o quadro "0,00 s" sairia
	# meio idle e o recuo apareceria fraco.
	#
	# A fase só é zerada na TROCA de estado, então preparo o corpo com o estado
	# anterior da cadeia (o `gura_v_lift` é quem antecede o T no jogo).
	modelo.set_meta("custom_pose", "gura_v_lift" if estado == "gura_v_tpose" else "")
	for i in 40:
		anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0)
	modelo.set_meta("custom_pose", estado)

	print("[captura] %s / vista %s -> %s" % [estado, vista, saida])
	var passado := 0.0
	for k in INSTANTES.size():
		var alvo: float = INSTANTES[k]
		while passado < alvo:
			anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0)
			passado += 1.0 / 60.0
		await process_frame
		await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("%s/%s_%s_%d_%03d.png" % [saida, estado, vista, k, int(alvo * 1000.0)])
	print("[captura] ok — %d quadros" % INSTANTES.size())
	quit()
