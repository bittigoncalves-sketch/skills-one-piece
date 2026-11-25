extends SceneTree
# ============================================================================
#  KIT DO BUILDER — fotos (06/10/2026): as cinco poses que os clipes do Builder
#  viram no jogador (`KitDoBuilder.POSES`) e um golpe com VFX no Modo História.
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_kit_do_builder.gd -- <pasta>
#
#  Mapa, progresso e skills de TESTE (nunca os do projeto).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")
const MAPA := "user://capturar_kit_mapa.json"
const PROGRESSO := "user://capturar_kit.json"
const PASTA := "user://capturar_kit_skills"


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	var s := Dados.novo()
	s.identificacao.id = "foto_vendaval"
	s.identificacao.nome = "Vendaval de teste"
	s.ativacao.tecla = "Z"
	s.condicoes.exige_alvo = false
	s.vfx.estilo = "Tornado"
	s.vfx.escala = 2.0
	s.eventos = [
		{"id": "anim", "tipo": "animacao", "inicio": 0.0, "duracao": 1.2, "habilitado": true, "parametros": {"clipe": "Vendaval"}},
		{"id": "fx", "tipo": "vfx", "inicio": 0.1, "duracao": 1.0, "habilitado": true, "parametros": {}},
		{"id": "tiro", "tipo": "projetil", "inicio": 0.2, "duracao": 0.1, "habilitado": true, "parametros": {"quantidade": 5, "abertura": 60.0, "velocidade": 6.0}},
	]
	s.configuracoes.duracao = 1.2
	SkillsPublicadas.publicar(s)
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	var p: Node3D = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta(KitDoBuilder.ID)
	for i in 30:
		await physics_frame
	# Câmera de lado para a pose ler.
	p.set("_yaw", deg_to_rad(80.0))
	p.call("_update_pivot")
	for clipe: String in KitDoBuilder.POSES:
		p.call("tocar_animacao_de_skill", clipe, 0.5, 1.0, 1.0)
		for i in 40:
			await process_frame
		await _foto(saida, "pose_" + clipe.to_lower())
	p.call("parar_animacao_de_skill")
	p.set("_yaw", 0.0)
	p.call("_update_pivot")
	for i in 20:
		await process_frame
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	for i in 30:
		await process_frame
	await _foto(saida, "golpe_vendaval")
	print("fotos em ", saida)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	SkillsPublicadas.pasta_forcada = ""
	quit(0)


func _foto(saida: String, nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))
