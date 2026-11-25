extends SceneTree
# Capturas de uma fruta Mine Piece do controlador genérico no Modo História, com a câmera
# do jogador, para julgar no olho o que os testes headless não veem: cada técnica do ciclo
# R (carregando e depois de soltar), as variantes com Shift pedidas e a transformação.
# Alvo: BonecoDeDuelo de tamanho humano a 14 m. Também monta uma folha de contato por técnica.
#
# Uso:
#   DISPLAY=:1 <godot> --path . -s tools/dev_tests/captura_fruta_mine_piece.gd -- <id> <pasta> [shift=21,22]

const MAPA := "user://captura_fruta_mp_mapa.json"
const PROGRESSO := "user://captura_fruta_mp.json"
const INSTANTES := [0.1, 0.3, 0.6, 1.2, 2.0]
const SEGURAR := 0.6

var p: Node3D
var c
var boneco: Node3D
var fruta := ""
var saida := "/tmp/fruta_mp"
var com_shift: Array[int] = []
var lateral: Camera3D   # vista de lado (jogador e alvo no quadro), além da câmera do jogador


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	fruta = args[0] if args.size() > 0 else "hie_hie_mine_piece"
	if args.size() > 1:
		saida = args[1]
	for a in args:
		if a.begins_with("shift="):
			for n in a.trim_prefix("shift=").split(",", false):
				com_shift.append(int(n))
	DirAccess.make_dir_recursive_absolute(saida)
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	p = get_first_node_in_group("player")
	var prog = current_scene.get("progressao")
	p.set_meta("damage_immune", true)
	# Energia 700 (nível 7; 100 × nível e custos ×10 desde 23/10/2026): os 70 de antes.
	prog.nivel = maxi(prog.nivel, 7)
	prog.comer_fruta(fruta)
	for i in 30:
		await process_frame
	c = load("res://src/combat/frutas_mine_piece/controlador.gd").de(p)
	if c == null:
		push_error("fruta %s sem controlador genérico" % fruta)
		quit(1)
		return
	lateral = Camera3D.new()
	lateral.fov = 60.0
	current_scene.add_child(lateral)
	lateral.global_position = Vector3(18, 6, -7)
	lateral.look_at(Vector3(0, 2, -7), Vector3.UP)
	boneco = BonecoDeDuelo.new()
	boneco.position = Vector3(0, 1, -14)   # nascer na origem punha o jogador na cabeça dele
	current_scene.add_child(boneco)
	for f: Dictionary in CatalogoFrutasMinePiece.FICHAS[fruta].ciclo:
		var n := int(f.numero)
		await _tecnica(n, "%d_%s" % [n, str(f.nome).to_snake_case().replace(":", "")], false)
		if n in com_shift:
			await _tecnica(n, "%d_shift" % n, true)
	await _a_postos()
	p.remove_meta("damage_immune")
	for i in 4:
		p.take_damage(0.5, p.global_position + Vector3.FORWARD, Vector3.ZERO, 0.0)
		for q in 5:
			await physics_frame
	await _fotos("transformado", [0.4, 1.2])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	_folhas()
	print("capturas em ", saida)
	quit()


func _a_postos() -> void:
	c.cancelar()
	c.recarga = 0.0
	if c.corpo != null:
		c.corpo.desfazer()
	await physics_frame
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.1)
	p.call("_update_pivot")
	p.energy = p.max_energy
	boneco.call("parar")
	boneco.global_position = Vector3(0, 1, -14)
	boneco.set("health", float(boneco.get("max_health")))
	for g in ["gelo_hie_mine_piece"]:
		for n in get_nodes_in_group(g):
			n.queue_free()
	c.imunidade.clear()
	for i in 45:
		await physics_frame


func _tecnica(numero: int, nome: String, shift: bool) -> void:
	await _a_postos()
	c.selecao = numero
	_shift(shift)
	for i in 3:
		await physics_frame
	c.usar(true)
	await _fotos(nome + "_segura", [SEGURAR * 0.8])
	c.usar(false)
	await _fotos(nome, INSTANTES)
	_shift(false)


func _shift(apertado: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_SHIFT
	e.physical_keycode = KEY_SHIFT
	e.pressed = apertado
	Input.parse_input_event(e)


## Fotos nos instantes (segundos desde agora).
func _fotos(nome: String, instantes: Array) -> void:
	var t := 0.0
	for alvo in instantes:
		while t < float(alvo):
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		await process_frame
		var img := get_root().get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s/%s_%.2f.png" % [saida, nome, float(alvo)])
		var principal := get_root().get_viewport().get_camera_3d()
		lateral.make_current()
		await process_frame
		await process_frame
		img = get_root().get_viewport().get_texture().get_image()
		if img != null:
			img.save_png("%s/%s_%.2f_lado.png" % [saida, nome, float(alvo)])
		if principal != null:
			principal.make_current()


## Uma folha de contato (512 × 288 por foto, 3 colunas) por prefixo de técnica.
func _folhas() -> void:
	var grupos := {}
	for arquivo in DirAccess.get_files_at(saida):
		if not arquivo.ends_with(".png") or arquivo.begins_with("folha_"):
			continue
		var chave := arquivo.get_slice("_", 0)
		if arquivo.contains("_shift"):
			chave += "_shift"
		if arquivo.contains("_lado"):
			chave += "_lado"
		if not grupos.has(chave):
			grupos[chave] = []
		grupos[chave].append(arquivo)
	for chave in grupos:
		var lista: Array = grupos[chave]
		lista.sort()
		var linhas := ceili(lista.size() / 3.0)
		var folha := Image.create(512 * 3, 288 * linhas, false, Image.FORMAT_RGB8)
		for i in lista.size():
			var im := Image.load_from_file(saida.path_join(lista[i]))
			im.convert(Image.FORMAT_RGB8)
			im.resize(512, 288)
			folha.blit_rect(im, Rect2i(0, 0, 512, 288), Vector2i((i % 3) * 512, (i / 3) * 288))
		folha.save_png(saida.path_join("folha_%s.png" % chave))
