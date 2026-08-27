extends SceneTree
# ============================================================================
#  VARREDURA DE 360° PELA CÂMERA DE VERDADE DO JOGO.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/captura_giro.gd -- <pasta>
#
#  POR QUE ELA EXISTE, e por que não bastava o `captura_visual.gd`: aquela sonda
#  cria uma `Camera3D` própria e a posiciona na mão. Ela nunca passa pelo
#  `CameraRig` — o pivô, o Ombro, o SpringArm. Ou seja: TODO defeito que mora na
#  cadeia da câmera (ombro, mola batendo em geometria, recorte perto) era
#  invisível para a bateria, por construção.
#
#  O dono relatou defeito visual "ao olhar para trás". Olhar para trás é
#  exatamente o que a outra sonda não sabe fazer.
#
#  O que ela varre:
#    • 8 rumos (a cada 45°), com o personagem PARADO no mesmo lugar. Só a
#      câmera gira. Assim, qualquer diferença entre os quadros é da câmera ou
#      do que ela vê — nunca do boneco ter andado.
#    • 3 inclinações no rumo de trás (180°), que é onde o relato aponta.
#
#  E, como no `captura_visual.gd`, cada quadro volta com HISTOGRAMA. Comparar
#  oito imagens com o olho é justamente onde o olho falha; o número não falha.
# ============================================================================

const RUMOS := [0, 45, 90, 135, 180, 225, 270, 315]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/captura_giro"
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
	if p == null:
		print("❌ sem jogador — a cena não subiu")
		quit(1)
		return

	# Os bonecos socam sozinhos e mudariam a imagem entre um rumo e outro.
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	p.set_meta("damage_immune", true)

	print("=== rumo | brilho | estourado | preto | pos. da câmera ===")
	for g in RUMOS:
		await _quadro(p, saida, "rumo_%03d" % g, deg_to_rad(float(g)), -0.25)

	# O rumo de trás, com três inclinações: se o defeito for a mola raspando o
	# chão ou o corpo, ele muda com a inclinação e não com o rumo.
	for par in [[-1.0, "baixo"], [0.0, "reto"], [0.45, "alto"]]:
		await _quadro(p, saida, "tras_%s" % par[1], PI, float(par[0]))

	print("\n✓ capturas em %s" % saida)
	quit()

func _quadro(p: Node3D, saida: String, nome: String, yaw: float, pitch: float) -> void:
	p.global_position = Vector3(0, 2.0, 0)
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	p._pitch = pitch
	p._camera.apontar(yaw, pitch)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 400:
		await process_frame
	var cam: Camera3D = p._camera.camera()
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [saida, nome])
	_histograma(nome, img, cam.global_position, p.global_position)

func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem:
			f.visible = false
		else:
			_esconder_2d(f)

# Brilho médio, fração estourada e fração no preto — os mesmos três números do
# `captura_visual.gd`, para que as duas sondas sejam comparáveis. `dist` é a
# distância da câmera ao corpo: se a mola estiver colapsando (câmera entrando no
# personagem ou na geometria), ela cai, e isso aparece SEM olhar a imagem.
func _histograma(nome: String, img: Image, cam_pos: Vector3, corpo: Vector3) -> void:
	var passo := 4
	var soma := 0.0
	var n := 0
	var estourado := 0
	var preto := 0
	for y in range(0, img.get_height(), passo):
		for x in range(0, img.get_width(), passo):
			var c := img.get_pixel(x, y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			soma += l
			n += 1
			if l > 0.9:
				estourado += 1
			elif l < 0.1:
				preto += 1
	print("%-12s | %.3f | %5.1f%% | %5.1f%% | dist=%.2f" % [
		nome, soma / float(n), 100.0 * estourado / float(n),
		100.0 * preto / float(n), cam_pos.distance_to(corpo)])
