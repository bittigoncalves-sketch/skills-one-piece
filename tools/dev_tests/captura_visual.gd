extends SceneTree
# ============================================================================
#  O PORTÃO DO PLANO VISUAL — sempre as MESMAS cinco cenas, antes e depois.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/captura_visual.gd -- <pasta>
#
#  Existe porque todo o `docs/PLANO_VISUAL.md` se julga com o olho, e olho não
#  lembra. Duas capturas do MESMO enquadramento, lado a lado, decidem em
#  segundos o que uma discussão não decide.
#
#  ⚠️ E ELA NÃO DEVOLVE SÓ IMAGEM. Cada cena vem com um HISTOGRAMA: brilho
#  médio, quanto da tela está estourado (acima de 0,9) e quanto está no preto
#  (abaixo de 0,1). Hoje o chão do jogo está colado no branco — "o chão parou
#  de estourar" tem que virar um NÚMERO, não uma opinião.
#
#  A HUD é escondida de propósito: ela é 2D e não muda com iluminação, então só
#  ocuparia pixel da comparação.
#
#  As cenas são fixas e escolhidas para cobrir o que o plano toca:
#    1 mundo    — o panorama; é onde névoa e perspectiva aérea aparecem
#    2 buraco   — a borda de um buraco de verdade, achado por raio; é o item de
#                 maior impacto em jogabilidade do plano (§7.1c)
#    3 perto    — o personagem em close; é onde banda de luz e contorno vão ler
#    4 emissivo — um golpe da Mera; é o teste do glow
#    5 ceu      — só céu; é onde as nuvens estilizadas entram
# ============================================================================

const CENAS := ["1_mundo", "2_buraco", "3_perto", "4_emissivo", "5_ceu"]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/captura_visual"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame

	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	# ⚠️ `CanvasLayer` NÃO é `CanvasItem`. A primeira versão testava
	# `h is CanvasItem` e a HUD continuava em tela em toda captura — a `Hud`
	# estende CanvasLayer. E não é só ela: AmmoHud, DummyToggleHud e o ScreenFX
	# são camadas próprias. Some com TODAS, varrendo a árvore.
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
	# Longe do spawn e imune: o boneco automático socando o alvo muda a captura.
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	p.set_meta("damage_immune", true)
	p.equip_fruit("mera_mera")

	var mundo: Node = get_root().get_tree().current_scene
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.current = true
	cam.far = 800.0

	var buraco := _achar_buraco(mundo)
	print("buraco escolhido: ", buraco)

	var poses := {
		"1_mundo":    [Vector3(0, 26, 62), Vector3(0, 2, 0)],
		"2_buraco":   [buraco + Vector3(11, 9, 11), buraco + Vector3(0, -6, 0)],
		"3_perto":    [Vector3(0, 3.2, 7.5), Vector3(0, 2.2, 0)],
		# ⚠️ DE LADO, e com um golpe que FICA. A primeira versão punha a câmera
		# atrás do jogador e disparava o Z (tiros de pistola): o projétil já
		# tinha saído de quadro na hora da captura, e a cena que existe para
		# julgar o GLOW não mostrava efeito nenhum. Agora é o C (vagalumes de
		# fogo), que permanece, visto de lado.
		"4_emissivo": [Vector3(7.5, 3.0, 4.0), Vector3(0, 2.4, -3.0)],
		"5_ceu":      [Vector3(0, 8, 0), Vector3(0, 40, -60)],
	}

	for nome in CENAS:
		p.global_position = Vector3(0, 2.0, 0)
		p.velocity = Vector3.ZERO
		if nome == "4_emissivo":
			p._skill_cooldowns["C"] = 0.0
			p.energy = p.max_energy
			p._fire_skill("C", Vector3(0, 0, -1), p.global_position + Vector3.UP * 1.2)
			var tf := Time.get_ticks_msec()
			while Time.get_ticks_msec() - tf < 700:
				await process_frame
		var pose: Array = poses[nome]
		cam.global_position = pose[0]
		cam.look_at(pose[1], Vector3.UP)
		var t1 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t1 < 500:
			await process_frame
		var img := get_root().get_texture().get_image()
		img.save_png("%s/%s.png" % [saida, nome])
		_histograma(nome, img)

	print("\n✓ %d capturas em %s" % [CENAS.size(), saida])
	quit()

# Acha um buraco DE VERDADE: joga um raio para baixo e aceita o ponto em que
# nada foi atingido. Não depende dos internos do MapBuilder — se o mapa mudar,
# a sonda continua achando.
func _achar_buraco(mundo: Node) -> Vector3:
	var espaco := (mundo.get_viewport().world_3d as World3D).direct_space_state
	for gz in range(3, 18):
		for gx in range(3, 18):
			var x := (gx - 10) * MapBuilder.CELL + MapBuilder.CELL * 0.5
			var z := (gz - 10) * MapBuilder.CELL + MapBuilder.CELL * 0.5
			if Vector2(x, z).length() < MapBuilder.SAFE_RADIUS + 6.0:
				continue
			var par := PhysicsRayQueryParameters3D.create(
				Vector3(x, 30, z), Vector3(x, -30, z))
			if espaco.intersect_ray(par).is_empty():
				return Vector3(x, 0, z)
	return Vector3(40, 0, 40)

# Brilho médio, estourado e preto. É o que transforma "ficou melhor" em número.
func _histograma(nome: String, img: Image) -> void:
	var passo := 4
	var soma := 0.0
	var n := 0
	var estourado := 0
	var preto := 0
	var pico := 0.0
	for y in range(0, img.get_height(), passo):
		for x in range(0, img.get_width(), passo):
			var c := img.get_pixel(x, y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			soma += l
			n += 1
			pico = maxf(pico, l)
			if l > 0.90:
				estourado += 1
			elif l < 0.10:
				preto += 1
	# O PICO importa tanto quanto a média: é ele que diz se existe algo
	# brilhando de verdade na cena — ou seja, se o glow está fazendo trabalho.
	print("   %-11s brilho médio %.3f | pico %.3f | estourado %5.1f%% | preto %5.1f%%" % [
		nome, soma / maxf(n, 1), pico,
		100.0 * estourado / maxf(n, 1), 100.0 * preto / maxf(n, 1)])

func _esconder_2d(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	elif n is Control:
		(n as Control).visible = false
	for f in n.get_children():
		_esconder_2d(f)
