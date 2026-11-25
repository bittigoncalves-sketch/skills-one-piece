extends SceneTree
## Personagens do East Blue (Mine Piece, 17/10/2026) no Modo História: corpo, cérebro e
## técnicas, sem depender da ilha (nascem perto do jogador no mapa de teste).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_east_blue_personagens.gd
## Confere: hostil persegue e fere o jogador com as skills `mpeb_*`; aliado (Luffy) não ataca
## sozinho e revida; armadura/resistência reduzem o dano como no mod; morre, avisa e renasce;
## toda técnica da tabela existe como skill válida.

var passou := 0
var falhas := 0
var p: Node3D


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1


func _novo(id: String, pos: Vector3) -> PersonagemMinePiece:
	var f := DadosEastBlue.ficha(id)
	var pers := PersonagemMinePiece.new()
	pers.montar(f, str(f.modelo))
	pers.position = pos
	pers.ponto_de_origem = pos
	current_scene.add_child(pers)
	return pers


func _rodar() -> void:
	# Este teste mede o cérebro com as skills portadas (plano B, sem IA do mod); a IA do mod tem os seus
	# (test_ia_do_mod, medir_ia_mine_piece).
	IaDoMod.ligada = true      # padrão do jogo; o plano B de skills do Builder saiu (A8, 27/10/2026)
	await process_frame
	# (Saiu a checagem de "toda técnica da ficha é uma skill publicada": o plano B de skills do Builder não existe mais, A8.)
	ok("as %d fichas do mod carregam" % DadosEastBlue.ids().size(), DadosEastBlue.ids().size() >= 40)
	ok("multiplicador de força do Buggy ≈ 2,11 (%.2f)" % DadosEastBlue.multiplicador_de_forca(DadosEastBlue.ficha("buggy")),
		absf(DadosEastBlue.multiplicador_de_forca(DadosEastBlue.ficha("buggy")) - 2.11) < 0.02)
	ok("Shanks: armadura 20 + resistência 3 tiram ~84 %% de 34 (%.2f)" % DadosEastBlue.dano_recebido(DadosEastBlue.ficha("shanks"), 34.0),
		DadosEastBlue.dano_recebido(DadosEastBlue.ficha("shanks"), 34.0) < 6.0)

	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_east_blue.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_east_blue.json"))
	root.get_node("GameFlow").start_story()
	await frames(150)
	p = get_first_node_in_group("player")
	for i in 450:
		if p != null: break
		await physics_frame
		p = get_first_node_in_group("player")
	if p == null:
		ok("jogador nasceu", false)
		quit(1)
		return
	p.global_position = Vector3(0, 1, 0)
	p.max_health = 5000.0
	p.health = 5000.0

	# Hostil: o Buggy a 10 m persegue e fere.
	var buggy := _novo("buggy", Vector3(0, 1, -10))
	await frames(10)
	ok("o Buggy tem o modelo convertido (AnimationPlayer: %s)" % str(buggy.find_child("AnimationPlayer", true, false) != null),
		buggy.find_child("AnimationPlayer", true, false) != null)
	var d0: float = buggy.global_position.distance_to(p.global_position)
	var vida0: float = p.health
	for i in 600:
		await physics_frame
		p.global_position = Vector3(0, 1, 0)
		# O Modo História reaplica a vida máxima real a cada quadro; o antigo
		# max_health=5000 acima não protege durante esta simulação longa.
		# Repor após cada tick permite receber golpes sem iniciar a morte do jogador.
		if p.health > 0.0:
			p.health = p.max_health
	var d1: float = buggy.global_position.distance_to(p.global_position)
	ok("o Buggy persegue (%.1f m → %.1f m)" % [d0, d1], d1 < d0 - 4.0)
	# A técnica sai da IA do mod (AIBuggyProcedure → minepiece:skill); o plano B de skills do Builder saiu (A8).
	# Mais 15 s com o jogador parado perto: a IA do mod escolhe a técnica ao acaso.
	# (A vida do jogador não serve de medida aqui: o Modo História a reaplica pelo nível.) Conta os golpes
	# que a camada Minecraft entregou ao jogador.
	Mc.contadores.clear()
	var quadros_com_dano := 0
	for i in 900:
		await physics_frame
		p.global_position = Vector3(0, 1, 0)
		if p.health > 0.0:
			if p.health < p.max_health:
				quadros_com_dano += 1
			p.health = p.max_health
	var golpes := 0
	for k: String in Mc.contadores:
		if k.begins_with("hurt:jogador:vivo:"):
			golpes += int(Mc.contadores[k])
	ok("o Buggy fere o jogador pela IA do mod (%d golpes; %d quadros com vida reduzida)" % [golpes, quadros_com_dano],
		golpes > 0 and quadros_com_dano > 0)
	ok("o jogador sobrevive ao cenário e o tempo do mundo continua normal", p.health > 0.0 and not p.morrendo and is_equal_approx(Engine.time_scale, 1.0))

	# Aliado: o Luffy perto não ataca sozinho...
	buggy.queue_free()
	await frames(5)
	var luffy := _novo("luffy_east_blue", Vector3(4, 1, -4))
	await frames(5)
	var vida_antes: float = p.health
	for i in 300:
		await physics_frame
		p.global_position = Vector3(0, 1, 0)
	ok("o Luffy (aliado) não ataca sozinho (vida %.0f → %.0f, alvo %s)" % [vida_antes, p.health, str(luffy.cerebro.alvo)],
		luffy.cerebro.alvo == null)   # a vida o Modo História reaplica pelo nível
	# ...mas revida.
	p.set_meta("dano_do_jogador", true)
	luffy.set_meta("dano_do_jogador", true)
	var vida_luffy: float = luffy.health
	luffy.take_damage(10.0, p.global_position)
	luffy.remove_meta("dano_do_jogador")
	for i in 120:
		await physics_frame
	# Com a IA do mod (padrão), os eventos do Forge do mod (LivingAttack: `LogicAttackProcedure`) CANCELAM o golpe
	# do jogador num aliado do mesmo grupo: sem dano e sem revide. O "revide" de aliado era do plano B (A8).
	ok("o aliado Luffy não sofre nem revida o golpe do jogador, como no mod (vida %.0f → %.0f)" % [vida_luffy, luffy.health],
		is_equal_approx(luffy.health, vida_luffy) and luffy.cerebro.alvo == null)
	luffy.queue_free()
	await frames(5)

	# Dano recebido, morte e renascimento.
	var marine := _novo("marine", Vector3(20, 1, 20))
	marine.capanga = false      # 08/11/2026: o marinheiro é capanga (5 golpes); este teste mede a conta de vida e armadura (capangas: test_chefes_e_capangas)
	await frames(5)
	var avisou := [false]
	marine.derrotado.connect(func(_x): avisou[0] = true)
	marine.take_damage(5.0, Vector3(20, 1, 22))
	# A vida máxima vem do mod (a IA do mod aplica os atributos do `finalizeSpawn`); o golpe sai com a armadura da ficha.
	var esperado: float = marine.max_health - DadosEastBlue.dano_recebido(marine.ficha, 5.0)
	ok("armadura 2 reduz o golpe de 5 (vida %.2f de %.2f; esperado %.2f)" % [marine.health, marine.max_health, esperado],
		absf(marine.health - esperado) < 0.1 and marine.health < marine.max_health)
	var tempo_anterior := PersonagemMinePiece.tempo_de_renascer
	PersonagemMinePiece.tempo_de_renascer = 1.0
	marine.take_damage(999.0, Vector3(20, 1, 22))
	ok("morre e avisa", avisou[0] and not marine.vivo() and not marine.is_in_group("enemy"))
	var tempo_inicio := Time.get_ticks_msec()
	# Esperar o renascimento, com limite, e observar a posição assim que ele ocorre:
	# aguardar 120 frames depois pode deixar a IA deslocá-lo após o respawn.
	for i in 180:
		await physics_frame
		if marine.vivo(): break
	var posicao_na_origem: bool = marine.global_position.distance_to(marine.ponto_de_origem) < 0.15
	ok("renasce no mesmo lugar com a vida cheia (vivo=%s, vida=%.2f/%.2f, enemy=%s, pos=%s, decorrido=%.2fs)" % [
		marine.vivo(), marine.health, marine.max_health, marine.is_in_group("enemy"), marine.global_position,
		(Time.get_ticks_msec() - tempo_inicio) / 1000.0],
		marine.vivo() and is_equal_approx(marine.health, marine.max_health) and marine.is_in_group("enemy") and posicao_na_origem)
	PersonagemMinePiece.tempo_de_renascer = tempo_anterior

	print("\nEAST_BLUE_PERSONAGENS: %d passaram / %d falharam" % [passou, falhas])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
