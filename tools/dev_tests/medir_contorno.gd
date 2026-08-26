extends SceneTree
# ============================================================================
#  O PORTÃO DO CONTORNO — Fase 2 de docs/PLANO_VISUAL.md
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_contorno.gd -- <pasta>
#
#  A pergunta que ele responde não é "tem contorno?", é **"a silhueta do
#  personagem tem contorno EM TRÊS DISTÂNCIAS?"** — porque o jeito clássico de
#  errar contorno é ele existir de perto e sumir de longe (limiar em metros) ou
#  engrossar de perto e virar borrão (espessura em unidades de mundo).
#
#  ⚠️ COMO ELE ISOLA A LINHA. Fotografa o MESMO quadro duas vezes, com o nó
#  `Contorno` visível e invisível, e conta os pixels que ESCURECERAM. Comparar
#  com um limiar absoluto de "escuro" contaria a sombra do personagem e o azul
#  do buraco junto — a diferença entre os dois quadros só pode ser a linha.
# ============================================================================

const DISTANCIAS := [6.0, 18.0, 45.0]
const ESCURECEU := 0.05      # queda de luminância que conta como linha

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/contorno"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	_esconder_2d(get_root())

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	p.global_position = Vector3(0, 2.0, 0)
	p.velocity = Vector3.ZERO

	var mundo: Node = get_root().get_tree().current_scene
	var contorno: Node = null
	for n in mundo.get_children():
		if n.name == "Contorno":
			contorno = n
	if contorno == null:
		print("❌ o nó Contorno não está na cena — a Fase 2 não subiu")
		quit(1)
		return

	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.current = true
	cam.far = 900.0

	var falhas := 0
	print("\n── contorno da SILHUETA, por distância ──")
	for d in DISTANCIAS:
		var alvo := p.global_position + Vector3.UP * 1.0
		cam.global_position = alvo + Vector3(0, d * 0.18, d)
		cam.look_at(alvo, Vector3.UP)

		var imgs := []
		for lig in [false, true]:
			contorno.visible = lig
			var t1 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t1 < 400:
				await process_frame
			imgs.append(get_root().get_texture().get_image())
		var sem: Image = imgs[0]
		var com: Image = imgs[1]
		com.save_png("%s/dist_%02d.png" % [saida, int(d)])

		# só a janela central: é onde o personagem está, e é dele que se fala
		var cx := com.get_width() / 2
		var cy := int(com.get_height() * 0.55)
		var meia := int(com.get_height() * 0.30)
		var linha := 0
		var total := 0
		for y in range(maxi(0, cy - meia), mini(com.get_height(), cy + meia)):
			for x in range(maxi(0, cx - meia), mini(com.get_width(), cx + meia)):
				var a := sem.get_pixel(x, y)
				var b := com.get_pixel(x, y)
				var la: float = 0.2126 * a.r + 0.7152 * a.g + 0.0722 * a.b
				var lb: float = 0.2126 * b.r + 0.7152 * b.g + 0.0722 * b.b
				total += 1
				if la - lb > ESCURECEU:
					linha += 1
		var pct: float = 100.0 * linha / maxf(total, 1)
		var ok: bool = linha > 0
		falhas += 0 if ok else 1
		print("   %s a %4.1f m: %6d pixels de linha (%.2f%% da janela)" % [
			"✔" if ok else "✗", d, linha, pct])

	contorno.visible = true
	print("\n%s" % ("✅ a silhueta tem contorno nas três distâncias."
		if falhas == 0 else "❌ %d distância(s) sem contorno." % falhas))
	quit(1 if falhas > 0 else 0)

func _esconder_2d(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	elif n is Control:
		(n as Control).visible = false
	for f in n.get_children():
		_esconder_2d(f)
