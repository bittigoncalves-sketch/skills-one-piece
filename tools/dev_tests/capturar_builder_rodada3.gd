extends SceneTree
# ============================================================================
#  RODADA 3 DO BUILDER — fotos com GPU (07/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_builder_rodada3.gd -- <pasta>
#
#    f_voo_jogo / f_voo_lado   o F da Pika: o corpo virou cometa voando para a mira
#    editor_clipe              o editor com um chute (roundhouse_kick) na prévia
#    editor_ancora             o inspetor do VFX com a Âncora "Alvo" e o anel no alvo
#  Mapa e progresso de TESTE; a Pika é a publicada no projeto.
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://capturar_builder_rodada3_mapa.json"
const PROGRESSO := "user://capturar_builder_rodada3.json"

var saida := ""


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	root.size = Vector2i(1600, 900)
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _quadros(150)
	var p: Node3D = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _quadros(30)
	p.global_position = Vector3(0, 0.8, 0)
	p.set("_yaw", 0.0)
	p.set("_pitch", 0.1)
	p.call("_update_pivot")
	await _quadros(20)
	p.set("energy", float(p.get("max_energy")))
	var lateral := Camera3D.new()
	current_scene.add_child(lateral)
	_f(true)
	await _quadros(28)
	await _foto(p.get("_cam"), "f_voo_jogo")
	lateral.global_position = p.global_position + Vector3(9.0, 2.0, 4.0)
	lateral.look_at(p.global_position)
	await _foto(lateral, "f_voo_lado")
	_f(false)
	await _quadros(60)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")

	# Editor: um chute na prévia e o anel ancorado no alvo.
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(60)
	var ed := current_scene
	var s := Dados.novo()
	s.identificacao.id = "chute_ancorado"
	s.identificacao.nome = "Chute ancorado"
	s.configuracoes.duracao = 1.2
	s.eventos = [{"id": "chute", "tipo": "animacao", "inicio": 0.0, "duracao": 1.2, "habilitado": true,
		"parametros": {"clipe": "roundhouse_kick", "velocidade": 1.0, "intensidade": 1.0}},
		{"id": "anel_no_alvo", "tipo": "vfx", "inicio": 0.1, "duracao": 1.0, "habilitado": true,
		"parametros": {"estilo": "Anel", "escala": 1.2, "ancora": "Alvo", "cor": "#ffd23f"}}]
	ed.call("_documento", s)
	await _quadros(10)
	ed.call("selecionar_evento", "anel_no_alvo")
	await _quadros(5)
	(ed.get("arena") as Node).call("buscar", 0.55)
	await _quadros(10)
	await _janela("editor_ancora")
	ed.call("selecionar_evento", "chute")
	(ed.get("arena") as Node).call("buscar", 0.55)
	await _quadros(10)
	await _janela("editor_clipe")
	print("fotos em ", saida)
	quit(0)


func _f(apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F
	ev.physical_keycode = KEY_F
	ev.pressed = apertada
	Input.parse_input_event(ev)


func _foto(cam: Camera3D, nome: String) -> void:
	cam.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _janela(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
