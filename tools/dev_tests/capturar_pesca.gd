extends SceneTree
# ============================================================================
#  PESCA — fotos (03/10/2026): vara na mão, linha e boia, briga com o HUD e a
#  barra de itens, e o pescador.
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_pesca.gd -- <pasta>
#
#  Mapa plano dos testes + um pescador; progresso de TESTE (rode com XDG_DATA_HOME
#  apontando para fora do save do dono).
# ============================================================================

const MAPA := "user://capturar_pesca_mapa.json"
const PROGRESSO := "user://capturar_pesca.json"
const NPC := Vector3(244.0, 0.0, 6.0)

var saida := ""
var cam: Camera3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var tam := BibliotecaDeModelos.padrao().info("npc_pescador")["tamanho"] as Vector3
	mapa["pecas"].append({"id": "pescador_1", "tipo": "modelo", "modelo": "npc_pescador",
		"posicao": NPC + Vector3.UP * tam.y * 0.5, "rotacao_graus": Vector3(0, -90, 0), "tamanho": tam,
		"cor": Color.WHITE, "material": "liso", "colisao": true})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 150:
		await physics_frame
	var p: Node3D = get_first_node_in_group("player")
	var cena := current_scene
	var pesca: Pescaria = cena.get("_pesca")
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	p.set_meta("damage_immune", true)
	cena.dar_fruta("rocket")
	prog.ganhar_equipamento("vara_de_pesca")
	prog.equipar_vara(true)
	pesca.semear(5)
	p.global_position = Vector3(250.0, 1.0, 0.0)
	p.set("_yaw", -PI * 0.5)
	for i in 60:
		await physics_frame

	cam = Camera3D.new()
	cam.fov = 45
	cena.add_child(cam)
	var corpo := p.global_position
	# 1) vara na mão — de lado (a câmera em −Z do jogador vê a frente, +X, à direita).
	await _foto("pesca_vara_na_mao", corpo + Vector3(0.9, 0.6, -3.8), corpo + Vector3(0.7, 0.4, 0))
	# 2) arremesso e espera: linha até a boia.
	pesca.botao_forcado = 1
	await physics_frame
	await physics_frame
	pesca.botao_forcado = 0
	for i in 70:
		await physics_frame
	await _foto("pesca_linha_e_boia", corpo + Vector3(-2.5, 3.2, -6.5), (corpo + pesca.posicao_da_boia) * 0.5)
	# 3) briga — câmera do jogo (HUD de tensão, barra de itens, dica).
	var t := 0.0
	while pesca.estado != Pescaria.Estado.MORDENDO and t < 8.0:
		await physics_frame
		t += 1.0 / 60.0
	pesca.botao_forcado = 1
	await physics_frame
	await physics_frame
	pesca.botao_forcado = 0
	var segurou := false
	for i in 150:
		var l := pesca.tensao
		if l != null:
			segurou = false if (l.avisando or l.correndo) else (true if l.tensao < 0.48 else (false if l.tensao > 0.6 else segurou))
		pesca.botao_forcado = 1 if segurou else 0
		await physics_frame
	var do_jogo := p.find_children("*", "Camera3D", true, false)
	if not do_jogo.is_empty():
		(do_jogo[0] as Camera3D).make_current()
	await _foto_atual("pesca_briga_hud")
	pesca.botao_forcado = 0
	# 4) o pescador.
	cam.make_current()
	await _foto("pesca_pescador", NPC + Vector3(3.4, 1.5, -1.6), NPC + Vector3(0, 1.0, 0))
	print("fotos em ", saida)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(0)


func _foto(nome: String, de: Vector3, para: Vector3) -> void:
	cam.make_current()
	cam.global_position = de
	cam.look_at(para)
	await _foto_atual(nome)


func _foto_atual(nome: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))
