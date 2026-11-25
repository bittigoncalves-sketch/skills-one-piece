extends SceneTree
# Captura (com GPU) do VISUAL do Mine Piece: Arlong sacando a Kiribachi na mão, clipes de técnica,
# partículas e sons pelo nome. Câmera livre olhando o personagem.
#
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_visual_mine_piece.gd -- <pasta>

var saida := "/tmp/visual_mp"
var cam: Camera3D


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])


func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_visual_mp.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	jogador.max_health = 100000.0
	jogador.health = 100000.0
	jogador.global_position = Vector3(0, 1, 9)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED       # a câmera e o modelo do jogador não atrapalham a foto
	jogador.visible = false

	var arlong := PersonagemMinePiece.new()
	arlong.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	arlong.position = Vector3(0, 1, 0)
	arlong.ponto_de_origem = arlong.position
	current_scene.add_child(arlong)
	await quadros(10)

	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 45
	cam.current = true
	_olhar(Vector3(2.6, 1.7, -3.2), Vector3(0, 1.1, 0))   # 3/4 pela frente-direita do personagem
	await quadros(20)
	await foto("00_repouso")

	var ent := McEntidade.de(arlong)
	# Arma: direto pela camada (o mesmo caminho da IA).
	ent.setItemInHand(Mc.campo(&"InteractionHand", &"MAIN_HAND"),
		Mc.novo(&"ItemStack", [Mc.item(&"minepiece:kiribachi")]))
	await quadros(10)
	_olhar(Vector3(1.6, 1.5, -2.0), Vector3(-0.3, 1.2, 0))
	await foto("01_kiribachi_perto")
	_olhar(Vector3(-2.4, 1.5, -2.6), Vector3(0, 1.1, 0))
	await foto("02_kiribachi_lado")

	# Clipes de técnica.
	for clipe in ["sword_to_right", "sword_overhead", "punch_right", "kick_right", "guard"]:
		_olhar(Vector3(2.8, 1.7, -3.4), Vector3(0, 1.1, 0))
		ent.triggerAnim("procedure", clipe)
		for t in [4, 12, 24]:
			await quadros(t if t == 4 else 8 if t == 12 else 12)
			await foto("anim_%s_%02d" % [clipe, t])
		ent.triggerAnim("procedure", "empty")
		await quadros(20)

	await quadros(40)
	print("DBG pós-clipes: clipe=", arlong._clipe_atual, " trava=", arlong._clipe_trava, " anim=", arlong._anim.current_animation, " pos=", arlong.global_position)
	_olhar(Vector3(2.6, 1.7, -3.2), Vector3(0, 1.1, 0))
	await foto("03_depois_dos_clipes")
	# Partículas e corpo de golpe, pelo nome.
	var mundo := Mc.mundo(self)
	_olhar(Vector3(0, 2.0, -5.0), Vector3(0, 1.2, 0))
	for p in ["minecraft:crit", "minecraft:enchanted_hit", "minecraft:flame", "minecraft:cloud",
			"minepiece:particle_thunder_blue", "minepiece:particle_slash", "minepiece:particle_shockwave"]:
		mundo.sendParticles(p, 0.0, 1.2, 0.0, 24, 0.5, 0.5, 0.5, 0.3)
		await process_frame
		for e in current_scene.get_parent().get_children() + root.get_children():
			if e is CPUParticles3D:
				print("DBG particula ", p, " em ", e.global_position)
				break
		await quadros(14)
		await foto("part_" + p.replace(":", "_"))
		await quadros(50)
	mundo.explode(null, 0.0, 1.0, 0.0, 1.0)
	await quadros(8)
	await foto("part_explosao")
	await quadros(60)
	var golpe := McCorpoDoMod.criar("entity_strike", mundo, McVec3.de(0.0, 1.2, 0.0))
	golpe.set_meta("mc_textura", "slash_blue")
	await quadros(8)
	await foto("corpo_entity_strike")
	print("capturas em ", saida)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()


func _olhar(de: Vector3, para: Vector3) -> void:
	cam.global_position = de
	cam.look_at(para)
	cam.make_current()
