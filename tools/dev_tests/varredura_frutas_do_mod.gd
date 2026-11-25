extends SceneTree
## Varredura das frutas do mod que o jogo passou a vender (08/11/2026): para CADA golpe de cada fruta, aperta a tecla (Z X C V B N),
## segura ~0,5 s, solta e mede se a técnica COMEÇOU (energia gasta / efeito do mod), se algo nasceu na cena (munição, partícula,
## entidade) e se feriu o alvo. Erros de script ficam no stderr: quem chama conta `SCRIPT ERROR` por fruta.
##   godot --headless --path . --script tools/dev_tests/varredura_frutas_do_mod.gd -- fruta1 fruta2 ...   (sem args: todas as novas)
var total := 0
var sem_efeito: Array[String] = []

func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://varredura_frutas_do_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -4)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	# O mod libera golpes por conquista: a varredura concede TODAS para enxergar todos os golpes de cada fruta.
	var avancos = McEntidade.de(jogador).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PerfilDeFrutas.frutas_so_do_mod()
	for id in ids:
		modo.equipar_fruta(jogador, "")
		await quadros(5)
		modo.equipar_fruta(jogador, id)
		await quadros(15)
		var c = jogador.get_node_or_null("FrutaMinePiece")
		if c == null or not c.fruta_ativa():
			print("FRUTA %s: NÃO EQUIPOU" % id)
			sem_efeito.append(id)
			continue
		var lista: Array = c.estado_das_tecnicas()
		print("FRUTA %s: %d golpes" % [id, lista.size()])
		for i in mini(lista.size(), 6):
			var letra: String = ["Z", "X", "C", "V", "B", "N"][i]
			c = jogador.get_node_or_null("FrutaMinePiece")
			if not is_instance_valid(c) or not c.fruta_ativa():
				print("  ❌ %s: o controlador sumiu antes do golpe %s" % [id, lista[i].nome])
				sem_efeito.append("%s/%s" % [id, lista[i].nome])
				continue
			McEntidade.de(jogador).removeAllEffects()
			await quadros(3)
			jogador.energy = jogador.max_energy
			jogador.global_position = Vector3(0, 1, 0)
			jogador.velocity = Vector3.ZERO
			alvo.health = alvo.max_health
			# O golpe anterior deixa técnica em curso e recarga global: sem isto o seguinte "não começa" (falso defeito de 15/11/2026, 13 casos).
			if c.ativo:
				c.cancelar()
			c.recarga = 0.0
			for n in c.recargas.keys():
				c.recargas[n] = 0.0
			await quadros(2)
			var e0: float = jogador.energy
			var filhos0 := current_scene.get_child_count()
			c.usar_tecla(letra, true)
			await quadros(30)
			var comecou: bool = (is_instance_valid(c) and c.ativo) or jogador.energy < e0 - 0.001
			if is_instance_valid(c):
				c.usar_tecla(letra, false)
			await quadros(70)
			var gasto: float = e0 - jogador.energy
			var nasceu := current_scene.get_child_count() - filhos0
			var dano: float = alvo.max_health - alvo.health
			total += 1
			var ok_tecnica := comecou or gasto > 0.001
			if not ok_tecnica:
				sem_efeito.append("%s/%s" % [id, lista[i].nome])
			print("  %s %-34s [%s] começou=%s gasto=%.0f nasceu=%d dano=%.0f (custo %.0f / energia máx %.0f%s)" % ["✅" if ok_tecnica else "❌", str(lista[i].nome), letra, str(comecou), gasto, nasceu, dano, float(lista[i].custo), float(jogador.max_energy), " BLOQUEADA" if bool(lista[i].bloqueada) else ""])
	print("\nVARREDURA %d golpes, %d sem começar: %s" % [total, sem_efeito.size(), ", ".join(sem_efeito)])
	quit()
