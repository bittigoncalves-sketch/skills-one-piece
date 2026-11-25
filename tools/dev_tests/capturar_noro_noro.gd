extends SceneTree
# ============================================================================
#  NORO NORO NO MI — fotos em jogo (06/10/2026): carregar, segurar, soltar (feixe),
#  final e o alvo lento (cintilas + rastro fantasma). Duas vistas: a câmera REAL do
#  jogador e uma lateral (para ler as poses).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_noro_noro.gd -- <pasta>
#
#  Mapa e progresso de TESTE; a fruta é a publicada no projeto (`tools/criar_noro_noro.gd`).
# ============================================================================

const MAPA := "user://capturar_noro_mapa.json"
const PROGRESSO := "user://capturar_noro.json"

var saida := ""
var lateral: Camera3D
var cam_jogo: Camera3D


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	var p: Node3D = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("noro_noro")
	await _fisica(20)
	var boneco := BonecoDeDuelo.new()
	boneco.position = Vector3(0, 1.0, -6)
	current_scene.add_child(boneco)
	p.global_position = Vector3(0, 0.8, 0)
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.08)
	p.call("_update_pivot")
	await _fisica(40)
	boneco.call("parar")
	cam_jogo = p.get("_cam")
	lateral = Camera3D.new()
	current_scene.add_child(lateral)
	lateral.global_position = Vector3(5.5, 1.6, -2.4)
	lateral.look_at(Vector3(0, 1.1, -2.4))
	lateral.fov = 55.0

	p.set("energy", float(p.get("max_energy")))
	p.begin_charge("Z")
	await _fisica(18)
	await _duas("1_carregar")
	await _fisica(40)
	await _duas("2_segurar")
	p.release_charge("Z")
	await _fisica(22)
	await _duas("3_soltar")
	await _fisica(26)
	await _duas("4_final")
	await _fisica(20)
	lateral.global_position = Vector3(3.2, 1.6, -3.2)
	lateral.look_at(Vector3(0, 1.0, -6))
	boneco.call("andar", Vector3(1.5, 0, 0))
	await _fisica(40)
	await _foto(lateral, "5_alvo_lento")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("fotos em ", saida)
	quit(0)


func _duas(nome: String) -> void:
	await _foto(cam_jogo, nome + "_jogo")
	await _foto(lateral, nome + "_lado")


func _foto(cam: Camera3D, nome: String) -> void:
	cam.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame
