extends SceneTree
# ============================================================================
#  MARCADOR DE MISSÃO NA TELA (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_marcador_de_missao.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_marcador_de_missao.gd -- --tela
#
#  Pedido do dono: "se a missão é matar 5 bandidos, o marcador fica nos bandidos até o
#  fim da missão; se a missão é completada, ela aponta para o NPC que irá pagar".
#  Na cena real da história (mapa e save de TESTE: Guarda, domador e 2 bandidos):
#  sem missão em andamento, o NPC que oferece a próxima; aceita, cada bandido VIVO marcado (o morto sai); olhando
#  para eles o marcador está na tela, de costas só o mais perto preso à borda; meta
#  cumprida, só o Guarda (com "?"); entregue, nada; a próxima (pet) marca o domador;
#  menu aberto esconde.
# ============================================================================

const MAPA := "user://test_marcador_de_missao.json"
const SAVE := "user://test_marcador_de_missao_progresso.json"
const PASTA := "res://art_src/validation/marcador_de_missao"

var total := 0
var falhas := 0
var tela := false


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	for par in [["guarda", "npc_missao_bandidos", Vector3(6, 0, 6)], ["domador", "npc_domador", Vector3(-30, 0, 20)],
			["bandido_1", "bandido", Vector3(0, 0, -40)], ["bandido_2", "bandido", Vector3(8, 0, -48)]]:
		var t := bib.tamanho_padrao(par[1])
		mapa.pecas.append(_peca(par[0], par[2] + Vector3.UP * t.y * 0.5, t, par[1]))
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	preload("res://tools/dev_tests/fixtures/jornada_concluida.gd").preparar(prog)
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	jogador.global_position = Vector3(0, 1.2, 0)
	if tela:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
		root.size = Vector2i(1280, 720)
	var marcador := cena.find_child("MarcadorDeMissao", true, false) as Control
	ok(marcador != null, "a HUD tem o marcador de missão")
	if marcador == null:
		return _fim()
	await quadros(20)
	# 17/10/2026: sem missão em andamento o marcador aponta onde começar a próxima (com "?").
	var inicio: Array = marcador.alvos()
	ok(not inicio.is_empty() and inicio.all(func(a: Dictionary) -> bool: return a["entregar"]),
		"sem missão aceita: marcado o NPC que oferece a próxima (%d)" % inicio.size())

	print("\n-- bandidos --")
	ok(prog.aceitar_missao("bandidos"), "aceita a missão dos bandidos")
	await quadros(20)
	var alvos: Array = marcador.alvos()
	ok(alvos.size() == 2 and alvos.all(func(a): return (a["no"] as Node).name == "Bandido" and not a["entregar"]),
		"aceita: os 2 bandidos marcados (%d)" % alvos.size())
	await _olhar(jogador, Vector3(4, 1, -44))
	var p: Array = marcador.projecoes()
	ok(p.any(func(x): return x["dentro"]), "olhando para o acampamento: marcador sobre eles na tela")
	await _foto("bandidos_na_tela")
	await _olhar(jogador, Vector3(0, 1, 40))
	p = marcador.projecoes()
	ok(p.all(func(x): return not x["dentro"]) and marcador.visible, "de costas: nenhum na tela, o mais perto fica preso à borda")
	ok(p.all(func(x): return absf((x["direcao"] as Vector2).x) > 0.9), "atrás da câmera: a seta vai para a lateral (vire para lá)")
	await _foto("bandidos_atras")
	var ninhos := get_nodes_in_group("ninhos_de_inimigo")
	var morto: Node3D = ninhos[0].get("boneco")
	morto.take_damage(99999.0, Vector3.ZERO)
	await quadros(30)
	ok(marcador.alvos().size() == 1, "bandido derrotado sai do marcador (sobra %d)" % marcador.alvos().size())
	for i in 5:
		prog.contar_abate("bandido")
	await quadros(20)
	alvos = marcador.alvos()
	ok(alvos.size() == 1 and (alvos[0]["no"] as NpcDaIlha).tipo == "npc_missao_bandidos" and alvos[0]["entregar"],
		"meta cumprida: só o Guarda, com \"?\" (quem paga)")
	await _olhar(jogador, Vector3(6, 2, 6) + Vector3(0, 0, 0))
	await _foto("entregar_no_guarda")
	ok(prog.entregar_missao("bandidos"), "entrega ao Guarda")
	await quadros(20)
	var proximo: Array = marcador.alvos()
	ok(not proximo.is_empty() and proximo.all(func(a: Dictionary) -> bool: return a["entregar"]) \
		and proximo.any(func(a: Dictionary) -> bool: return (a["no"] as NpcDaIlha).tipo == "npc_missao_bandidos"),
		"entregue: marcado o Guarda, onde a próxima (pet) começa")

	print("\n-- pet --")
	ok(prog.aceitar_missao("pet"), "aceita a missão do pet")
	await quadros(20)
	alvos = marcador.alvos()
	ok(alvos.size() == 1 and (alvos[0]["no"] as NpcDaIlha).tipo == "npc_domador", "a tarefa se resolve no domador: ele é marcado")
	get_first_node_in_group("hud").call("toggle_main_menu")
	await quadros(5)
	ok(not marcador.visible, "menu aberto: o marcador some")
	get_first_node_in_group("hud").call("toggle_main_menu")
	await quadros(5)
	ok(marcador.visible, "menu fechado: volta")
	_fim()


## Gira a câmera do jogador para `alvo` (yaw) e espera ela assentar.
func _olhar(jogador: Node3D, alvo: Vector3) -> void:
	var d := alvo - jogador.global_position
	jogador.set("_yaw", atan2(-d.x, -d.z))
	jogador.call("_update_pivot")
	await quadros(40)


func _peca(id: String, onde: Vector3, tamanho: Vector3, modelo: String) -> Dictionary:
	return {"id": id, "tipo": "modelo", "modelo": modelo, "posicao": onde, "tamanho": tamanho,
		"rotacao_graus": Vector3.ZERO, "colisao": true, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0}


func _foto(nome: String) -> void:
	if not tela:
		return
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join(nome + ".png")))
	print("     foto: ", PASTA.path_join(nome + ".png"))


func _fim() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(MAPA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nMARCADOR_DE_MISSAO %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
