extends SceneTree
# Capturas da Goro Goro (Mine Piece) no Modo História, com a câmera do jogador,
# para julgar no olho o que os testes headless não veem: poses, feixe, raios,
# meteoro, transformação e a HUD do R/Z.
#
# Uso:
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_goro_mine_piece.gd -- <pasta>

const MAPA := "user://captura_goro_mp_mapa.json"
const PROGRESSO := "user://captura_goro_mp.json"

var p: Node3D
var goro
var boneco: Node3D
var saida := "/tmp/goro_mp"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		saida = args[0]
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
	# Energia 200 (nível 2; 100 × nível e custos ×10 desde 23/10/2026): os 20 de antes.
	prog.nivel = maxi(prog.nivel, 2)
	prog.comer_fruta("goro_goro_mine_piece")
	for i in 30:
		await process_frame
	goro = load("res://src/combat/goro_mine_piece/goro_goro_mine_piece.gd").de(p)
	boneco = BonecoDeDuelo.new()
	current_scene.add_child(boneco)

	await _tecnica(21, "vari", [0.4, 0.75, 1.0], 0.5)
	await _tecnica(22, "el_thor", [0.3, 0.8, 1.05, 1.4], 0.5)
	await _tecnica(22, "el_thor_ceu", [0.6, 0.9, 1.2], 0.5, true)
	await _tecnica(23, "sango", [0.3, 0.9, 1.4], 0.5)
	await _tecnica(25, "mamaragan", [0.3, 0.7, 3.0], 0.1)
	await _raigo()
	await _a_postos()
	p.get("combate_direcional").aparou.emit(null, p.global_position)
	await _fotos("kari_krash", [0.1, 0.3])
	await _a_postos()
	for i in 4:
		p.health -= 0.5
		for q in 5:
			await physics_frame
	await _fotos("transformado", [0.4, 1.2])
	get_root().get_node("GameFlow")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("capturas em ", saida)
	quit()


func _a_postos() -> void:
	goro.encerrar()
	goro.recarga = 0.0
	if goro.elemental.ativa:
		goro._desfazer_elemental()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.12)
	p.call("_update_pivot")
	p.energy = p.max_energy
	boneco.call("parar")
	boneco.global_position = Vector3(0, 1, -6)
	boneco.set("health", float(boneco.get("max_health")))
	for i in 30:
		await physics_frame


func _tecnica(numero: int, nome: String, instantes: Array, segurar: float, com_shift := false) -> void:
	await _a_postos()
	goro.selecao = numero
	goro.usar(true)
	if com_shift:
		goro._executar("shift", 1)
	await _fotos(nome + "_segura", [segurar * 0.8])
	goro.usar(false)
	await _fotos(nome, instantes)
	goro._executar("shift", 0)


func _raigo() -> void:
	await _a_postos()
	goro.selecao = 29
	p.set("_pitch", 0.45)
	p.call("_update_pivot")
	goro.usar(true)
	await physics_frame
	goro.usar(false)
	await _fotos("raigo", [0.5, 3.0, 6.0, 9.0, 11.0, 12.5])
	goro.mamaragan = 0.0


## Fotos nos instantes (segundos desde agora).
func _fotos(nome: String, instantes: Array) -> void:
	var t := 0.0
	for alvo in instantes:
		while t < float(alvo):
			await physics_frame
			t += 1.0 / Engine.physics_ticks_per_second
		await process_frame
		var img := get_root().get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%.2f.png" % [saida, nome, float(alvo)])
