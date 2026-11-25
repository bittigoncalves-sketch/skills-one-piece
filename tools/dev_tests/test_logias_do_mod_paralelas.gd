extends SceneTree
# ============================================================================
#  LOGIAS DO FLUXO DO MOD EM PARALELO (24/11/2026): Mera, Magu, Suna, Yami, Mori — as técnicas do mod rodam em sessões
#  (`SessoesDoMod`): uma técnica em curso não trava as outras, cada uma com a sua recarga; soltar a tecla vale só para a técnica
#  dela; tudo termina e o corpo volta ao repouso.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_logias_do_mod_paralelas.gd
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func tecla(codigo: Key, apertou: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = apertou
	Input.parse_input_event(e)

func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_logias_do_mod_paralelas.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -12)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	# O mod libera golpes por conquista (grades): concede todas para a fruta oferecer o que tem.
	var avancos = McEntidade.de(jogador).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	for id in SessoesDoMod.FRUTAS:
		# É a progressão que manda no equipado (qualquer `mudou` reequipa a dela): come a fruta por ela.
		var prog: ProgressaoDoPersonagem = current_scene.progressao
		prog.tirar_fruta()
		await quadros(5)
		prog.dar_fruta_de_teste(id, 1)
		prog.comer_fruta(id)
		await quadros(15)
		var c = jogador.get_node_or_null("FrutaMinePiece")
		ok(c != null and c.paralelas != null, "%s: controlador do mod com sessões paralelas" % id)
		if c == null or c.paralelas == null:
			continue
		var mapa: Dictionary = c.mapa_de_teclas()
		var teclas: Array = mapa.keys()
		ok(teclas.size() >= 3, "%s: uma tecla por técnica (%d)" % [id, teclas.size()])
		var sem_som: Array = []
		for letra: String in teclas:
			var arq := SonsDasTecnicas.caminho(id, int(mapa[letra]))
			if not (ResourceLoader.exists(arq) and load(arq) is AudioStream):
				sem_som.append(arq)
		ok(sem_som.is_empty() and ResourceLoader.exists(SonsDasTecnicas.caminho(id, 0)), "%s: som novo de carga e de cada técnica (faltam %s)" % [id, sem_som])
		jogador.max_energy = 100000.0
		jogador.energy = jogador.max_energy
		jogador.global_position = Vector3(0, 1.0, 0)
		jogador.velocity = Vector3.ZERO
		await quadros(5)
		var pico := 0
		var comecadas := 0
		for letra: String in teclas.slice(0, 4):
			tecla(OS.find_keycode_from_string(letra), true)
			await quadros(3)
			comecadas += 1
			pico = maxi(pico, c.paralelas.total())
		ok(pico >= 2, "%s: várias técnicas vivas juntas, nenhuma travou as outras (pico %d de %d)" % [id, pico, comecadas])
		var com_recarga := 0
		for n in c._recargas.keys():
			if float(c._recargas[n]) > 0.0:
				com_recarga += 1
		ok(com_recarga >= 2, "%s: recarga por técnica (%d em recarga)" % [id, com_recarga])
		for letra: String in teclas.slice(0, 4):
			tecla(OS.find_keycode_from_string(letra), false)
		for i in 900:
			await physics_frame
			if not c.paralelas.tem():
				break
		ok(not c.paralelas.tem(), "%s: todas terminam (restam %d)" % [id, c.paralelas.total()])
		await quadros(30)
		ok(not c.ativo, "%s: o controlador volta ao repouso" % id)
		ok(not McEntidade.de(jogador).hasEffect(Mc.efeito("minepiece:skill")) and float(McEntidade.de(jogador).getPersistentData().getDouble("skill")) == 0.0,
			"%s: o mod não guarda técnica nenhuma" % id)
	print("\nLOGIAS_DO_MOD %d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
