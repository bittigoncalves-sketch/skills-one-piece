extends SceneTree
# ============================================================================
#  TESTE DO MODO HISTÓRIA — etapa 1: baseplate + jogador Civil andando.
#
#  Duas metades:
#    A. o ARQUIVO de mapa (sem subir o jogo): o válido carrega, o que sai relê
#       igual, e cada tipo de arquivo quebrado é recusado dizendo o campo;
#    B. o JOGO de verdade (GameFlow.start_story): a cena monta o mapa do arquivo,
#       o jogador fica em pé na baseplate, anda com WASD, renasce no spawn do
#       mapa ao cair, e as travas do Civil seguram ataque, dash, pulo duplo e
#       técnicas.
#
#  ⚠️ Cada trava tem CONTROLE POSITIVO: o mesmo gesto é repetido com as
#  capacidades completas e precisa funcionar. Sem isso "o dash não saiu" passaria
#  também se o teste simplesmente não soubesse disparar um dash.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_modo_historia.gd
# ============================================================================

# ⚠️ MAPA FIXO, não o do projeto. O `mapas/historia/baseplate.json` é editado pelo
# dono no editor de mapa; medir "tem 1 peça" nele quebrou este teste no mesmo dia
# em que o editor ficou pronto. Do mapa real, só se exige que continue VÁLIDO.
const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
# ⚠️ `load` em tempo de execução, NUNCA `preload` aqui em cima: o preload compila
# ModoHistoria → Player antes de os autoloads existirem no `godot -s`, e o Player
# fica no cache como "falhou" — o `new()` de depois quebra (medido em 14/09/2026).
var _modo_historia: GDScript
const PROGRESSO := "user://test_modo_historia_progresso.json"

var _falhas := 0


func _init() -> void:
	await process_frame
	_modo_historia = load("res://src/historia/ModoHistoria.gd")
	print("\n===== MODO HISTÓRIA =====")
	_arquivo_valido()
	_arquivos_quebrados()
	_padrao_da_arena()

	_modo_historia.set("mapa_forcado", MAPA)
	# Progresso de TESTE: o de quem joga (user://historia/progresso.json) não é lido nem gravado.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	_modo_historia.set("progresso_forcado", PROGRESSO)
	var game_flow := get_root().get_node("GameFlow")
	game_flow.start_story()
	for i in 900:                          # espera o jogador nascer (a carga cresceu e 120 quadros fixos não bastavam)
		await process_frame
		if i >= 60 and _jogador_local() != null:
			break
	for i in 20:
		await process_frame

	var cena := current_scene
	var jogador := _jogador_local()
	await _cena(cena, jogador)
	if jogador != null:
		await _andar(jogador)
		await _sem_clones(jogador)
		await _menu(jogador)
		await _renascer(jogador)
		await _ataque(jogador)
		await _dash(jogador)
		await _pulo_duplo(jogador)
		_tecnicas(jogador)
		await _status(jogador)

	_modo_historia.set("mapa_forcado", "")
	_modo_historia.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


# ------------------------------------------------------------- A. arquivo
func _arquivo_valido() -> void:
	print("\n-- A1. o mapa da baseplate carrega e relê igual --")
	var real := MapaArquivo.carregar(_modo_historia.get("MAPA_INICIAL"))
	_ok(real["ok"], "o mapa REAL do Modo História continua válido (%d peças) %s"
		% [real["mapa"]["pecas"].size() if real["ok"] else -1, str(real["erros"])])
	var lido := MapaArquivo.carregar(MAPA)
	_ok(lido["ok"], "o mapa fixo de teste é válido %s" % str(lido["erros"]))
	if not lido["ok"]:
		return
	var mapa: Dictionary = lido["mapa"]
	_ok(mapa["pecas"].size() == 1, "tem exatamente 1 peça (a baseplate)")
	var p: Dictionary = mapa["pecas"][0]
	_ok(p["id"] == "baseplate" and p["tamanho"] == Vector3(512, 2, 512),
		"a peça é a baseplate de 512 × 2 × 512 m")
	_ok(is_equal_approx(p["posicao"].y + p["tamanho"].y * 0.5, 0.0), "o topo da baseplate fica em y = 0")

	var texto := MapaArquivo.para_texto(mapa)
	var relido := MapaArquivo.ler_texto(texto)
	_ok(relido["ok"] and relido["mapa"] == mapa, "gravar → ler devolve o MESMO mapa")

	var destino := "user://test_modo_historia_mapa.json"
	var err := MapaArquivo.salvar(destino, mapa)
	var do_disco := MapaArquivo.carregar(destino)
	_ok(err == OK and do_disco["ok"] and do_disco["mapa"] == mapa,
		"salvar em disco e recarregar devolve o mesmo mapa (err=%s)" % error_string(err))
	_ok(not FileAccess.file_exists(destino + ".tmp"), "a gravação não deixa o temporário para trás")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(destino))

	# O gatilho declarado no MapaMontador precisa de um número para existir.
	var raiz := Node3D.new()
	get_root().add_child(raiz)
	var t0 := Time.get_ticks_usec()
	MapaMontador.montar(raiz, mapa)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("     montagem do mapa: %.2f ms (gatilho de revisão: 100 ms)" % ms)
	_ok(raiz.get_node_or_null("Mapa/baseplate/Colisao") != null, "o montador cria corpo, malha e colisão")
	raiz.free()


func _arquivos_quebrados() -> void:
	print("\n-- A2. arquivo quebrado é recusado, dizendo o motivo --")
	var base := {"formato": MapaArquivo.FORMATO, "versao": 1, "nome": "t",
		"spawn": {"posicao": [0, 1, 0]},
		"pecas": [{"id": "a", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [1, 1, 1]}]}
	_ok(MapaArquivo.validar(base)["ok"], "o caso-base mínimo é válido (opcionais têm padrão)")

	_recusa(MapaArquivo.ler_texto("{ isto não é json"), "JSON", "texto que não é JSON")
	_recusa(MapaArquivo.validar([1, 2]), "raiz", "raiz que não é objeto")
	_recusa(_com(base, "formato", "outro-jogo/mapa"), "formato", "formato de outro jogo")
	_recusa(_com(base, "versao", 2), "versao", "versão mais nova que a build")
	_recusa(_com(base, "spawn", null), "spawn", "sem spawn")
	_recusa(_com(base, "pecas", "nada"), "pecas", "\"pecas\" que não é lista")
	_recusa(_peca(base, "tamanho", [1, -1, 1]), "tamanho", "tamanho negativo")
	_recusa(_peca(base, "tamanho", [1, 1]), "tamanho", "vetor com 2 números")
	_recusa(_peca(base, "posicao", [0, "alto", 0]), "posicao", "coordenada que não é número")
	_recusa(_peca(base, "posicao", [0, INF, 0]), "posicao", "coordenada infinita")
	_recusa(_peca(base, "id", "a/b"), "id", "id com barra (quebraria o nome do nó)")
	_recusa(_peca(base, "tipo", "piramide"), "tipo", "tipo desconhecido")
	_recusa(_peca(base, "cor", "red"), "cor", "cor fora de #rrggbb")
	_recusa(_peca(base, "material", "vidro"), "material", "material desconhecido")
	_recusa(_peca(base, "colisao", "sim"), "colisao", "colisão que não é booleano")

	var repetido := base.duplicate(true)
	repetido["pecas"].append(repetido["pecas"][0].duplicate(true))
	_recusa(MapaArquivo.validar(repetido), "repetido", "dois ids iguais")

	var demais := base.duplicate(true)
	var lista: Array = []
	for i in MapaArquivo.MAX_PECAS + 1:
		lista.append({"id": "p%d" % i, "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [1, 1, 1]})
	demais["pecas"] = lista
	_recusa(MapaArquivo.validar(demais), "teto", "mais peças que o teto")

	var dois_erros := _peca_crua(base, "cor", "red")
	dois_erros["pecas"][0]["material"] = "vidro"
	var r := MapaArquivo.validar(dois_erros)
	_ok(not r["ok"] and r["erros"].size() == 2, "junta TODOS os erros de uma vez (%d)" % r["erros"].size())


func _padrao_da_arena() -> void:
	print("\n-- A3. a arena continua com tudo liberado --")
	var p: Node = load("res://Player.gd").new()
	var c: CapacidadesDoJogador = p.capacidades
	_ok(c.can_attack and c.can_dash and c.can_double_jump and c.can_use_skills,
		"Player novo nasce com as capacidades completas")
	_ok(p.ponto_de_renascimento == Scoreboard.RESPAWN, "e renasce no centro da arena, como antes")
	p.free()


func _recusa(r: Dictionary, palavra: String, caso: String) -> void:
	var texto := " | ".join(r["erros"])
	_ok(not r["ok"] and r["mapa"].is_empty() and texto.contains(palavra),
		"recusa %s → %s" % [caso, texto if not texto.is_empty() else "(sem mensagem)"])


func _com(base: Dictionary, chave: String, valor: Variant) -> Dictionary:
	var d := base.duplicate(true)
	d[chave] = valor
	return MapaArquivo.validar(d)


func _peca(base: Dictionary, chave: String, valor: Variant) -> Dictionary:
	return MapaArquivo.validar(_peca_crua(base, chave, valor))


func _peca_crua(base: Dictionary, chave: String, valor: Variant) -> Dictionary:
	var d := base.duplicate(true)
	d["pecas"][0][chave] = valor
	return d


# ----------------------------------------------------------------- B. jogo
func _cena(cena: Node, jogador: Node) -> void:
	print("\n-- B1. a cena do Modo História --")
	_ok(cena != null and cena.name == "ModoHistoria", "a cena ativa é ModoHistoria (%s)" % (cena.name if cena else "nenhuma"))
	var forma := cena.get_node_or_null("Mapa/baseplate/Colisao") as CollisionShape3D if cena else null
	_ok(forma != null and (forma.shape as BoxShape3D).size == Vector3(512, 2, 512),
		"a baseplate saiu do ARQUIVO, com colisão de 512 × 2 × 512 m")
	_ok(cena != null and cena.get_node_or_null("Mapa") != null and cena.get_node("Mapa").get_child_count() == 1,
		"abriu o mapa FIXO de teste (1 peça), não o mapa vivo do projeto")
	_ok(get_root().get_tree().get_first_node_in_group("scoreboard") == null
		and cena.get_node_or_null("Placar") == null, "sem placar da arena")
	_ok(get_root().get_tree().get_nodes_in_group("dummy").is_empty(), "sem bonecos de treino")
	_ok(jogador != null, "o jogador local nasceu")
	if jogador == null:
		return
	for i in 60:
		await physics_frame
	var y: float = jogador.global_position.y
	print("     jogador em %s, no chão = %s" % [jogador.global_position, jogador.is_on_floor()])
	_ok(jogador.is_on_floor() and y > 0.5 and y < 1.3, "está em pé sobre a baseplate (y = %.2f)" % y)
	# Desde a A11 (30/10/2026) o Civil nasce com o Estilo de Combate Base (item "Luta", id `estilo_de_combate_base`), que usa o mesmo mecanismo da fruta: NÃO é Akuma no Mi.
	_ok(jogador.current_fruit_id in ["", "estilo_de_combate_base"], "o Civil não tem Akuma no Mi (nasce com '%s')" % jogador.current_fruit_id)
	var c: CapacidadesDoJogador = jogador.capacidades
	# Desde 30/09/2026 a campanha começa com Combate 1 (decisão do dono): o Civil já bate.
	_ok(c.can_attack and not c.can_dash and not c.can_double_jump and not c.can_use_skills,
		"nasceu Civil já podendo bater (Combate 1), sem dash, pulo duplo nem técnicas")


func _andar(jogador: Node) -> void:
	print("\n-- B2. WASD --")
	for tecla: int in [KEY_W, KEY_A, KEY_S, KEY_D]:
		var antes: Vector3 = jogador.global_position
		_tecla(tecla, true)
		for i in 45:
			await physics_frame
		_tecla(tecla, false)
		for i in 20:
			await physics_frame
		var d: Vector3 = jogador.global_position - antes
		d.y = 0.0
		_ok(d.length() > 1.5, "%s anda %.2f m em 0,75 s" % [OS.get_keycode_string(tecla), d.length()])
	_ok(jogador.is_on_floor(), "continua no chão depois de andar")


# ⚠️ O MENU REAL NÃO SOBE AQUI. `MainMenu.gd` cita `GameFlow` por identificador,
# e em `godot -s` autoload não vira identificador (o mesmo ruído tolerado pelo
# `test_compila`): `MainMenu.new()` falha só neste ambiente. O que se prova é o
# CONTRATO que o Player usa — `is_menu_open()` verdadeiro para o WASD — com um
# menu substituto no lugar do real. Abrir o menu de verdade fica para o jogo.
class MenuSubstituto extends Control:
	var aberto := false
	func is_open() -> bool:
		return aberto
	func toggle() -> void:
		aberto = not aberto
	func open_menu() -> void:
		aberto = true


# Os "clones" da corrida são nós `EcoDeMovimento` postos na cena atual pelo
# `AfterimageTrail`. Controle positivo: com o rastro ligado, a mesma corrida cria.
func _sem_clones(jogador: Node) -> void:
	print("\n-- B2b. corrida sem clones --")
	_ok(not jogador.ecos_de_movimento_ligados, "o Civil nasce com o rastro de corrida desligado")
	var sem := await _correr_e_contar_ecos(jogador)
	_ok(sem == 0, "correr 1 s com Shift não deixa clone nenhum (%d)" % sem)
	jogador.ecos_de_movimento_ligados = true
	var com := await _correr_e_contar_ecos(jogador)
	_ok(com > 0, "controle: com o rastro ligado, a mesma corrida deixa clones (%d)" % com)
	jogador.ecos_de_movimento_ligados = false
	for i in 40:
		await physics_frame
	_ok(_contar_ecos() == 0, "ao desligar, os clones que existiam somem")


func _correr_e_contar_ecos(jogador: Node) -> int:
	_tecla(KEY_SHIFT, true)
	_tecla(KEY_W, true)
	var maior := 0
	for i in 60:
		await physics_frame
		maior = maxi(maior, _contar_ecos())
	_tecla(KEY_W, false)
	_tecla(KEY_SHIFT, false)
	for i in 30:
		await physics_frame
	return maior


func _contar_ecos() -> int:
	var n := 0
	for filho in current_scene.get_children():
		if String(filho.name).begins_with("EcoDeMovimento"):
			n += 1
	return n


func _menu(jogador: Node) -> void:
	print("\n-- B3. menu do ESC (contrato com o Player) --")
	var hud := get_root().get_tree().get_first_node_in_group("hud")
	_ok(hud != null and hud.get_script() != null and str(hud.get_script().resource_path).ends_with("HistoriaHud.gd"), "a HUD do grupo \"hud\" é a HistoriaHud")   # por caminho do script: `is HistoriaHud` compilava o Player antes dos autoloads
	_ok(hud.has_method("toggle_main_menu") and hud.has_method("is_menu_open"),
		"cumpre o contrato que o Player consulta (toggle_main_menu, is_menu_open)")
	var substituto := MenuSubstituto.new()
	hud.add_child(substituto)
	hud._menu = substituto
	hud.toggle_main_menu()
	_ok(hud.is_menu_open(), "o menu abre")
	var antes: Vector3 = jogador.global_position
	_tecla(KEY_W, true)
	for i in 30:
		await physics_frame
	_tecla(KEY_W, false)
	var d: Vector3 = jogador.global_position - antes
	d.y = 0.0
	_ok(d.length() < 0.05, "com o menu aberto o W não anda (%.3f m)" % d.length())
	hud.toggle_main_menu()
	_ok(not hud.is_menu_open(), "o menu fecha")
	hud._menu = null
	substituto.queue_free()


func _renascer(jogador: Node) -> void:
	print("\n-- B4. queda no vazio --")
	# 15/10/2026: na história o vazio fica em -150 (o fundo do mar chega a -80), não em -40.
	jogador.global_position = Vector3(300, Scoreboard.VOID_Y_HISTORIA - 10.0, 0)
	var d: float = 1.0e9
	for i in 400:                                # a morte no vazio tem fluxo próprio (animação/atraso): espera o renascimento em vez de contar 30 quadros
		await physics_frame
		d = (jogador.global_position - Vector3(0, 3, 0)).length()
		if d < 3.5:
			break
	_ok(d < 3.5, "renasceu no spawn do MAPA (a %.2f m de [0, 3, 0])" % d)
	for i in 60:
		await physics_frame


func _ataque(jogador: Node) -> void:
	print("\n-- B5. ataque travado (com controle positivo) --")
	# O corpo do jogo já bate (Combate 1); a TRAVA se mede pondo o Civil à mão.
	jogador.capacidades = CapacidadesDoJogador.civil()
	jogador._request_melee()
	var saiu := await _saiu_do_idle(jogador, 20)
	_ok(not saiu, "Civil: pedir corpo a corpo não sai do Idle")
	_tecla_mouse(jogador)
	saiu = await _saiu_do_idle(jogador, 20)
	_ok(not saiu, "Civil: clique esquerdo não ataca")

	jogador.capacidades = CapacidadesDoJogador.completas()
	# Com as mãos livres/"Luta" o pedido vira o BATER do clique do Minecraft (V5) e não o golpe: para medir a TRAVA de capacidade, o controle desliga o clique de blocos.
	var clique = jogador.clique_de_blocos
	jogador.clique_de_blocos = null
	jogador._request_melee()
	saiu = await _saiu_do_idle(jogador, 40)
	jogador.clique_de_blocos = clique
	_ok(saiu, "controle: com capacidades completas o mesmo pedido ataca")
	jogador.capacidades = CapacidadesDoJogador.civil()
	for i in 90:
		await physics_frame


func _dash(jogador: Node) -> void:
	# 03/10/2026: o Q virou ROLL e ficou SEMPRE liberado (decisão do dono: "liberar
	# o uso do Q"). Antes o Civil não esquivava até a progressão desbloquear o dash.
	print("\n-- B6. roll liberado para o Civil --")
	_ok(await _tentar_dash(jogador), "Civil: Q rola (roll sempre liberado)")
	for i in 110:
		await physics_frame


func _pulo_duplo(jogador: Node) -> void:
	print("\n-- B7. pulo simples livre, pulo duplo travado (com controle positivo) --")
	var r := await _tentar_pulo_duplo(jogador)
	_ok(r["pulou"], "Civil: o pulo simples do chão funciona (subiu %.2f m)" % r["altura"])
	_ok(r["geppos"] == 0, "Civil: Espaço no ar não gasta geppo (%d)" % r["geppos"])
	jogador.capacidades = CapacidadesDoJogador.completas()
	r = await _tentar_pulo_duplo(jogador)
	_ok(r["geppos"] == 1, "controle: com capacidades completas o Espaço no ar faz o geppo (%d)" % r["geppos"])
	jogador.capacidades = CapacidadesDoJogador.civil()


func _tecnicas(jogador: Node) -> void:
	print("\n-- B8. técnicas travadas --")
	var energia: float = jogador.energy
	jogador.begin_charge("Z")
	_ok(not jogador._charging and jogador.energy == energia, "Civil: begin_charge(\"Z\") não carrega nem gasta")
	jogador.release_charge("Z")


# ------------------------------------------------------------- B9. status (M)
func _status(jogador: Node) -> void:
	print("\n-- B9. status do personagem (tecla M) --")
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.progressao
	_ok(prog != null and prog.nivel == 1, "a cena carregou a progressão (nível 1)")
	# Os números vêm da PROGRESSÃO (fonte única: `hp_maximo()`/`energia_maxima()`), não de literais que envelheciam a cada rebalanceamento (eram 20/10; hoje 24/600 no nível 1).
	_ok(is_equal_approx(jogador.max_health, float(prog.hp_maximo())) and is_equal_approx(jogador.health, float(prog.hp_maximo()))
		and is_equal_approx(jogador.max_energy, float(prog.energia_maxima())),
		"o corpo nasce com os números da progressão: vida %d/%d, energia %d" % [prog.hp_maximo(), prog.hp_maximo(), prog.energia_maxima()])
	# A energia de parede deixou de existir em 03/10/2026 (andar na superfície
	# removido; o wall run novo não cobra). A decisão de 16/09 ("no Modo História o
	# parkour não gasta energia") passou a valer em todo lugar.
	_ok(not ("parkour_gasta_energia" in jogador), "o parkour não gasta energia (energia de parede removida em 03/10)")

	var hud := get_root().get_tree().get_first_node_in_group("hud")
	await _apertar(KEY_M)
	var janela: JanelaDeStatus = hud.janela_de_status()
	_ok(hud.status_aberto() and hud.is_menu_open(), "M abre a janela de status e ela conta como menu (WASD para)")
	_ok(janela._rotulos["nivel"].text.begins_with("1 — Civil") and janela._rotulos["xp"].text == "0 / 2.000"
		and janela._rotulos["hp"].text == "24 / 24", "a janela mostra Nível 1 — Civil, XP 0 / 2.000, Vida 24 / 24")

	prog.ganhar_xp(2000)
	await process_frame
	# Com a janela aberta o aviso fica armado mas escondido (30/09/2026): ele caía em
	# cima da janela. Aparece ao fechar — conferido depois do ESC, abaixo.
	_ok(prog.nivel == 2 and hud._tempo_do_aviso > 0.0 and not hud._aviso.visible
		and hud._aviso.text.contains("Nível 1 → Nível 2"),
		"ganhar 2.000 XP sobe para o nível 2 e arma o aviso \"Level Up!\" (escondido com a janela aberta)")
	await process_frame
	_ok(is_equal_approx(jogador.max_health, float(prog.hp_maximo())) and janela._rotulos["hp"].text == "%d / %d" % [prog.hp_maximo(), prog.hp_maximo()],
		"vida máxima do corpo vem do nível (%d), na janela também" % prog.hp_maximo())
	var salvo := ProgressaoDoPersonagem.carregar(PROGRESSO)
	_ok(salvo.nivel == 2, "o progresso foi gravado no arquivo")
	await _visual_do_status(hud, janela, prog)

	await _apertar(KEY_ESCAPE)
	_ok(not hud.status_aberto() and not (hud._menu != null and hud._menu.is_open()),
		"ESC fecha a janela SEM abrir o menu principal por cima")
	hud.avisar("teste")
	await process_frame
	_ok(hud._aviso.visible, "com a janela fechada o aviso aparece")
	prog.definir_skill("combate", 1)
	await process_frame
	_ok(jogador.capacidades.can_attack, "Skill de Combate 1 libera o ataque no corpo na hora")


## A janela nova (30/09/2026): interface de jogo, larga, sem ferramentas de teste e sem
## ícone. Cada checagem tem o controle que mostra que ela sabe reprovar.
func _visual_do_status(hud: Node, janela: JanelaDeStatus, prog: ProgressaoDoPersonagem) -> void:
	print("\n-- B9b. a janela de status nova --")
	await process_frame
	await process_frame
	var botoes_de_teste := janela.find_children("*", "Button", true, false).filter(
		func(b): return b.text.ends_with("XP") or b.text in ["Comer Rocket", "Parado", "Reiniciar campanha"])
	_ok(botoes_de_teste.is_empty() and janela.find_child("Bonecos", true, false) == null,
		"a janela de Status não tem mais botões de teste (%d)" % botoes_de_teste.size())
	var painel: Control = hud.ferramentas_de_teste()
	var no_painel := 0 if painel == null else painel.find_children("*", "Button", true, false).filter(
		func(b): return b.text in ["+100 XP", "+1.000 XP", "Comer Rocket", "Parado"]).size()
	_ok(no_painel == 4, "controle: os botões de teste existem no painel F8 (%d de 4)" % no_painel)

	var tela: Rect2 = janela.get_viewport_rect()
	var caixa: Rect2 = janela.get_global_rect()
	_ok(caixa.size.x >= 900.0 and tela.encloses(caixa),
		"a janela é larga (%.0f px) e cabe inteira na tela %s" % [caixa.size.x, str(tela.size)])
	var centro_x: float = absf(caixa.get_center().x - tela.get_center().x)
	_ok(centro_x < 2.0, "e está centralizada (desvio de %.1f px)" % centro_x)
	var rolagem: ScrollContainer = janela._rolagem
	await process_frame
	await process_frame
	var barra := rolagem.get_v_scroll_bar()          # medido na barra real: `custom_minimum_size` deixou de ser o mecanismo (a janela ficou responsiva)
	_ok(barra.max_value <= barra.page + 1.0,
		"em 1280×720 o conteúdo todo cabe sem rolar (conteúdo %.0f px, janela %.0f px)" % [barra.max_value, barra.page])
	_ok(janela._previa != null and is_instance_valid(janela._previa.modelo) and janela._previa.viewport.own_world_3d,
		"a prévia 3D montou o personagem ao abrir, num mundo próprio")

	_ok(janela._linhas_atributo.size() == ProgressaoDoPersonagem.ATRIBUTOS.size() and not janela._linhas_atributo["forca"].has("mais"),
		"a janela lista os atributos do nível, sem botões de ponto")

	var espada: Array = janela._marcadores["espada"]
	prog.definir_skill("espada", 2)
	await process_frame
	var acesos: int = espada.filter(func(m): return m.aceso()).size()
	_ok(espada.size() == 4 and acesos == 2 and janela._rotulos["skill_espada"].text == "Treinada",
		"skill: quatro marcadores, dois acesos no nível 2 (%d) — Treinada" % acesos)
	prog.definir_skill("espada", 0)
	await process_frame
	acesos = espada.filter(func(m): return m.aceso()).size()
	_ok(acesos == 0, "controle: no nível 0 nenhum marcador aceso (%d)" % acesos)
	_ok(janela._barras["hp"]._r > 0.99 and janela._barra_xp.cor == JanelaDeStatus.DOURADO,
		"vida cheia na barra verde, XP em barra dourada — as barras do HUD")

	var estranhos: Array = []
	for rotulo in janela.find_children("*", "Label", true, false) + janela.find_children("*", "Button", true, false):
		for c in rotulo.text:
			if c.unicode_at(0) >= 0x2600:
				estranhos.append(c)
	# Imagem visível com textura = ícone. O `ScrollContainer` do Godot 4.6 tem dois
	# `TextureRect` internos (as dicas de rolagem), escondidos e sem textura nossa.
	var imagens: Array = janela.find_children("*", "TextureRect", true, false).filter(
		func(t): return t.is_visible_in_tree() and t.texture != null)
	_ok(estranhos.is_empty() and imagens.is_empty(),
		"nenhum ícone nem emoji na janela (caracteres %s, imagens %d)" % [str(estranhos), imagens.size()])

	await _apertar(KEY_F8)
	_ok(hud.ferramentas_abertas() and hud.is_menu_open(), "F8 abre as ferramentas de teste e elas contam como menu")
	await _apertar(KEY_F8)
	_ok(not hud.ferramentas_abertas() and hud.status_aberto(), "F8 fecha as ferramentas; o Status continua aberto")


func _apertar(code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	get_root().push_input(ev, true)
	await process_frame
	var solta := ev.duplicate() as InputEventKey
	solta.pressed = false
	get_root().push_input(solta, true)
	await process_frame


# --------------------------------------------------------------- utilidades
func _jogador_local() -> Node:
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			return p
	return null


func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)


# O caminho do clique inteiro: `_unhandled_input` → `_request_melee`. No headless
# o mouse nunca fica capturado e o primeiro clique só tentaria capturar, então o
# evento é entregue direto ao Player com o mouse já "capturado" do ponto de vista
# da regra — o que se testa aqui é o ramo do botão esquerdo, não a captura.
func _tecla_mouse(jogador: Node) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	jogador._unhandled_input(ev)


# ⚠️ Pergunta ao PLAYER se ele está atacando, e não à FSM. Desde a Fase 3 do combate
# direcional (16/09/2026) o golpe do Modo História é do executor e a FSM fica em
# Idle; `esta_atacando()` responde pelos dois caminhos.
func _saiu_do_idle(jogador: Node, quadros: int) -> bool:
	for i in quadros:
		await physics_frame
		if jogador.esta_atacando():
			return true
	return false


func _tentar_dash(jogador: Node) -> bool:
	_tecla(KEY_Q, true)
	for i in 6:
		await physics_frame
	_tecla(KEY_Q, false)
	for i in 4:
		await physics_frame
		if jogador._dash.ativo():
			return true
	return false


func _tentar_pulo_duplo(jogador: Node) -> Dictionary:
	for i in 30:
		await physics_frame
	var y0: float = jogador.global_position.y
	_tecla(KEY_SPACE, true)
	for i in 3:
		await physics_frame
	_tecla(KEY_SPACE, false)
	for i in 8:
		await physics_frame
	var altura: float = jogador.global_position.y - y0
	_tecla(KEY_SPACE, true)
	await physics_frame
	await physics_frame
	var geppos: int = jogador._parkour.geppos()
	_tecla(KEY_SPACE, false)
	for i in 90:
		await physics_frame
	return {"pulou": altura > 0.5, "altura": altura, "geppos": geppos}
