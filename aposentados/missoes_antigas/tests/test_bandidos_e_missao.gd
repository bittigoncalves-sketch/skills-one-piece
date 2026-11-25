extends SceneTree
# ============================================================================
#  BANDIDOS + MISSÃO DO GUARDA DA VILA (08/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_bandidos_e_missao.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_bandidos_e_missao.gd -- --tela
#
#  Pedido do dono: "adicionar no mapa bandidos com base no dummy que é capaz de lutar,
#  adicione-os em campo aberto; adicionar um npc na vila com uma interrogação amarela
#  acima da cabeça que dá a missão de matar os bandidos". Escolhas dele: Base com roupa
#  de bandido; 2 acampamentos de 3, 25–75 XP cada; matar 5 → 300 XP + 50 ouro, uma vez.
#  Na cena real da história (mapa e save de TESTE):
#    1. os bandidos nascem como o boneco que luta, vestidos de bandido;
#    2. sem a missão, bandido dá 25–75 XP e não conta;
#    3. "?" amarela → E → Aceitar → "?" cinza, contador 0 / 5 na tela;
#    4. 5 bandidos → 5 / 5, "?" amarela de novo, "volte ao Guarda"; o 6º não passa da meta;
#    5. Entregar → +300 XP e +50 ouro, uma vez; a próxima da cadeia aparece; salvar/carregar guarda;
#    6. besta do mar abatida dá o XP da dificuldade;
#    7. o MAPA VIVO tem 2 acampamentos de 3 bandidos longe da vila e o Guarda na praça.
# ============================================================================

const MAPA := "user://test_bandidos_e_missao.json"
const SAVE := "user://test_bandidos_e_missao_progresso.json"
const PASTA := "res://art_src/validation/bandidos"
const Missoes := preload("res://src/historia/missoes/missoes.gd")

var total := 0
var falhas := 0
var tela := false
var modo_atual: Node
var camera: Camera3D


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
	mapa.pecas[0].tamanho = Vector3(128, 2, 128)
	var t_band := bib.tamanho_padrao("bandido")
	for i in 6:
		var onde := Vector3(-30 + (i % 3) * 6, t_band.y / 2, -40 + (i / 3) * 8)
		mapa.pecas.append(_modelo("bandido_%d" % i, "bandido", onde, t_band))
	var t_g := bib.tamanho_padrao("npc_missao_bandidos")
	mapa.pecas.append(_modelo("guarda", "npc_missao_bandidos", Vector3(10, t_g.y / 2, 10), t_g))
	var t_fogo := bib.tamanho_padrao("bonfire")
	mapa.pecas.append(_modelo("fogueira", "bonfire", Vector3(-24, t_fogo.y / 2, -36), t_fogo))
	var t_b := bib.tamanho_padrao("besta_mar_bovina")
	mapa.pecas.append(_modelo("bovina", "besta_mar_bovina", Vector3(54, t_b.y / 2, 40), t_b))
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	InimigoDoMapa.tempo_de_renascer = 0.5
	root.get_node("GameFlow").start_story()
	await quadros(150)
	modo_atual = current_scene
	var prog: ProgressaoDoPersonagem = modo_atual.get("progressao")
	preload("res://tools/dev_tests/fixtures/jornada_concluida.gd").preparar(prog)
	# As missões de madeira saíram (10/11/2026): os bandidos vêm logo depois da facção.
	var jogador: Node3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	if tela:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
		root.size = Vector2i(1280, 720)
		camera = Camera3D.new()
		current_scene.add_child(camera)

	# 1. Nascem vestidos.
	var ninhos := _ninhos()
	var vestidos := 0
	for n in ninhos:
		if n.boneco != null and n.boneco.name == "Bandido" and n.boneco.modelo_visual().find_child("RoupaDeBandido", true, false) != null:
			vestidos += 1
	ok(ninhos.size() == 6 and vestidos == 6, "6 bandidos nascem como o boneco que luta, vestidos (%d/%d)" % [vestidos, ninhos.size()])
	ok(ninhos.all(func(n): return n.comportamento == NinhoDeInimigo.BANDIDO), "os ninhos sabem que são de bandido")
	await _foto_de(ninhos[0].boneco, "bandidos_de_perto", Vector3(3.2, 1.6, -4.5))

	# 2. Sem missão: XP sim, contagem não.
	var antes := _xp_total(prog)
	await _matar(ninhos[0])
	var ganho := _xp_total(prog) - antes
	ok(ganho >= 25 and ganho <= 75, "bandido derrotado dá 25–75 XP (+%d)" % ganho)
	ok(prog.estado_da_missao("bandidos") == Missoes.DISPONIVEL and prog.abates_da_missao("bandidos") == 0,
		"sem aceitar a missão, o abate não conta")

	# 3. O Guarda: "?" amarela, E, Aceitar.
	var npcs: NpcsDaIlha = modo_atual.get("_npcs")
	var guarda: NpcDaIlha = npcs.npcs.filter(func(n): return n.tipo == "npc_missao_bandidos")[0]
	await quadros(20)
	var marca := guarda.find_child("MarcaDeMissao", false, false) as Label3D
	ok(marca != null and marca.visible and marca.text == "?" and marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO),
		"o Guarda da vila tem a \"?\" amarela acima da cabeça")
	ok(marca != null and marca.global_position.y > guarda.global_position.y + NpcDaIlha.ALTURA, "a \"?\" fica acima da cabeça (%.2f m)" %
		(marca.global_position.y - guarda.global_position.y if marca else 0.0))
	jogador.global_position = guarda.global_position + Vector3(0, 1, 2)
	await quadros(10)
	ok(npcs.interagir(), "E perto do Guarda abre a conversa")
	var loja: LojaDeNpc = guarda.loja()
	ok(loja.fala() == Missoes.dados("bandidos")["oferta"], "ele oferece a missão: \"%s\"" % loja.fala())
	await _foto_de(guarda, "guarda_oferece", Vector3(-1.8, 1.9, 3.4))
	var linha: Dictionary = loja.linhas(prog, null)[0]
	ok(linha.botoes[0].texto == "Aceitar" and linha.botoes[0].ativo, "o botão é Aceitar (%s)" % linha.detalhe)
	var aviso := loja.executar(prog, null, "aceitar", "bandidos")
	_fechar_janela()
	await quadros(20)
	var rastreador := modo_atual.find_child("RastreadorDeMissoes", true, false) as Label
	ok(prog.estado_da_missao("bandidos") == Missoes.ACEITA and aviso.contains("Missão aceita"), "aceita (\"%s\")" % aviso)
	ok(marca.visible and marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO_EM_ANDAMENTO), "aceita: a \"?\" fica cinza (em andamento)")
	ok(rastreador != null and rastreador.text.contains("Bandidos no campo — 0 / 5"), "na tela: \"%s\"" % (rastreador.text if rastreador else "?"))

	# 4. Cinco bandidos (renascem em 0,5 s no teste).
	for i in 5:
		var n := await _vivo()
		await _matar(n)
	ok(prog.abates_da_missao("bandidos") == 5 and prog.estado_da_missao("bandidos") == Missoes.PRONTA, "5 bandidos: missão pronta (5 / 5)")
	await quadros(20)
	ok(marca.visible and marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO), "pronta: a \"?\" volta a amarela (entregar)")
	ok(rastreador.text.contains("volte ao Guarda da vila"), "na tela: \"%s\"" % rastreador.text)
	await _foto_tela("rastreador_pronta")
	await _matar(await _vivo())
	ok(prog.abates_da_missao("bandidos") == 5, "o 6º não passa da meta (%d)" % prog.abates_da_missao("bandidos"))

	# 5. Entregar.
	var ouro0 := prog.ouro
	var xp0 := _xp_total(prog)
	linha = loja.linhas(prog, null)[0]
	ok(linha.botoes[0].texto == "Entregar" and linha.botoes[0].ativo, "o botão vira Entregar")
	aviso = loja.executar(prog, null, "entregar", "bandidos")
	ok(prog.ouro - ouro0 == 50 and _xp_total(prog) - xp0 == 300, "entregue: +%d XP e +%d ouro (%s)" % [_xp_total(prog) - xp0, prog.ouro - ouro0, aviso])
	await quadros(20)
	# Cadeia do Guarda (08/10/2026, Ilha dos Macacos): entregue a 1ª, a "?" segue amarela
	# porque a próxima (pet) já está disponível — `test_cadeia_do_guarda` cobre o resto.
	ok(marca.visible and marca.modulate.is_equal_approx(NpcDaIlha.COR_MISSAO) and rastreador.text.begins_with("◇ Próxima"),
		"entregue: o contador sai da tela, o rastreador indica a próxima e a \"?\" segue amarela")
	ok(loja.executar(prog, null, "entregar", "bandidos").is_empty() and prog.ouro - ouro0 == 50, "não dá para entregar duas vezes")
	ok(loja.fala() == Missoes.dados("pet")["oferta"], "depois ele oferece a próxima: \"%s\"" % loja.fala())
	var volta := ProgressaoDoPersonagem.de_dict(prog.para_dict())
	ok(volta.estado_da_missao("bandidos") == Missoes.ENTREGUE and volta.abates_da_missao("bandidos") == 5, "salvar/carregar guarda a missão entregue")

	# 6. Besta do mar dá XP da dificuldade.
	var bovina: Node3D = get_nodes_in_group("bestas_do_mar")[0]
	var xp_b := _xp_total(prog)
	bovina.take_damage(99999.0, bovina.global_position + Vector3(0, 0, 5))
	await quadros(5)
	# XP de abate = recompensa do Mine Piece pela vida (18/10/2026; era a dificuldade).
	var esperado := preload("res://src/historia/recompensa_mine_piece.gd").xp_de_abate(float(bovina.ficha.vida))
	ok(_xp_total(prog) - xp_b == esperado and esperado > 100, "besta do mar abatida dá o XP do Mine Piece (+%d)" % (_xp_total(prog) - xp_b))

	# 7. O mapa vivo.
	_mapa_vivo()
	InimigoDoMapa.tempo_de_renascer = 60.0
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("BANDIDOS_E_MISSAO %d conferem | %d divergem" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)


func _mapa_vivo() -> void:
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var pecas: Array = lido["mapa"]["pecas"]
	var spawn: Vector3 = lido["mapa"]["spawn"]["posicao"] if lido["mapa"]["spawn"] is Dictionary else Vector3(152, 0, 20)
	var bandidos := pecas.filter(func(p): return p.tipo == "modelo" and p.get("modelo") == "bandido")
	var guardas := pecas.filter(func(p): return p.tipo == "modelo" and p.get("modelo") == "npc_missao_bandidos")
	var longe := bandidos.all(func(p): return Vector2(p.posicao.x - spawn.x, p.posicao.z - spawn.z).length() > 75.0)
	var campos := {}
	for p in bandidos:
		campos[String(p.id).get_slice("_", 1)] = int(campos.get(String(p.id).get_slice("_", 1), 0)) + 1
	ok(bandidos.size() == 6 and campos.size() == 2 and campos.values().all(func(n): return n == 3) and longe,
		"mapa vivo: 2 acampamentos de 3 bandidos, todos a mais de 75 m da vila (%s)" % str(campos))
	ok(guardas.size() == 1 and Vector2(guardas[0].posicao.x - spawn.x, guardas[0].posicao.z - spawn.z).length() < 15.0,
		"mapa vivo: o Guarda da vila na praça, perto de onde o jogador nasce")


func _ninhos() -> Array:
	return modo_atual.find_children("Ninho_*", "NinhoDeInimigo", true, false)


func _vivo() -> NinhoDeInimigo:
	for i in 200:
		for n in _ninhos():
			if n.boneco != null and is_instance_valid(n.boneco) and n.boneco.health > 0.0:
				return n
		await physics_frame
	return null


func _matar(n: NinhoDeInimigo) -> void:
	if n == null or n.boneco == null:
		return
	n.boneco.take_damage(99999.0, n.boneco.global_position + Vector3(0, 0, 2))
	await quadros(4)


## XP total acumulado (níveis já subidos + o XP de agora): ganho com level up no meio.
func _xp_total(p: ProgressaoDoPersonagem) -> int:
	var soma := p.xp
	for n in range(1, p.nivel):
		soma += ProgressaoDoPersonagem.xp_para(n)
	return soma


func _fechar_janela() -> void:
	var hud = get_first_node_in_group("hud")
	var janela = hud.call("janela_de_loja") if hud else null
	if janela:
		janela.visible = false


func _modelo(id: String, modelo: String, onde: Vector3, tamanho: Vector3) -> Dictionary:
	return {"id": id, "tipo": "modelo", "modelo": modelo, "posicao": onde, "tamanho": tamanho,
		"rotacao_graus": Vector3.ZERO, "colisao": true, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0}


func _foto_de(alvo: Node3D, nome: String, de: Vector3) -> void:
	if not tela or alvo == null:
		return
	camera.global_position = alvo.global_position + de
	camera.look_at(alvo.global_position + Vector3(0, 1.2, 0))
	camera.make_current()
	await _foto_tela(nome)


func _foto_tela(nome: String) -> void:
	if not tela:
		return
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA.path_join(nome + ".png"))
