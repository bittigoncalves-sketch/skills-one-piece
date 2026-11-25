extends SceneTree
# ============================================================================
#  DESEMPENHO DA ENCHENTE — pedido do dono: "garantir o bom desempenho do jogo
#  quando a água começar".
#
#  ⚠️ POR QUE MEDIR TEMPO DE QUADRO E NÃO "FPS MÉDIO": a água pode custar caro em
#  um quadro só (a malha sendo regerada) e barato nos outros. Média esconde isso;
#  por isso aqui saem média E pior caso.
#
#  ⚠️ E POR QUE MEDIR COM A CÂMERA SUBMERSA: o custo de uma superfície
#  transparente é de OVERDRAW — ele só aparece quando ela cobre a tela inteira.
#  Medir de fora da água mediria quase nada.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/medir_fps_enchente.gd
# ============================================================================

const AMOSTRAS := 240


func _init() -> void:
	await process_frame
	# ⚠️ SEM ISTO A MEDIDA É INÚTIL. Com V-Sync ligado os três casos davam 6,94 ms
	#   cravados — que é 144 Hz, o teto do monitor, e não o custo de nada. Um
	#   número que não se move quando a cena muda não está medindo a cena.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var sb := get_root().get_tree().get_first_node_in_group("scoreboard")
	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break

	# ⚠️ SEGURAR A FASE DE PÉ. Sem um segundo corpo vivo, o jogador se afoga em 3 s,
	#   a enchente termina e a água some — e a medição do "pior caso" acaba medindo
	#   a arena SECA. Foi o que aconteceu na primeira rodada: o caso submerso deu
	#   MENOS custo que o caso anterior, que é impossível se houvesse água na tela.
	var vivo := Node3D.new()
	vivo.name = "2"
	get_root().get_node("Main/Players").add_child(vivo)
	vivo.add_to_group("player")
	vivo.global_position = Vector3(0, 60, 0)

	var base := await _medir("1. arena seca (referência)", sb)

	sb.time_left = 0.0
	await _quadros(10)
	var subindo := await _medir("2. água subindo, câmera fora d'água", sb)

	# Submerge a câmera: é o pior caso de overdraw.
	sb.flood_y = p.global_position.y + 30.0
	await _quadros(10)
	var dentro := await _medir("3. câmera DENTRO da água (pior caso)", sb)

	# ⚠️ CONTROLE QUE SEPARA DESENHO DE CONTA: a fase continua rodando (afogamento,
	#   subida do nível, varredura de jogadores), só a MALHA some. O que sobrar de
	#   custo aqui é lógica; o que sumir era renderização.
	var agua := _agua()
	if agua != null:
		agua.visible = false
		agua.set_process(false)
	var so_logica := await _medir("4. mesma fase, água escondida (controle)", sb)

	print("\n--- veredito ---")
	for caso in [["subindo", subindo], ["submerso", dentro], ["só lógica", so_logica]]:
		var m: Dictionary = caso[1]
		var piora: float = (float(m["media"]) / float(base["media"]) - 1.0) * 100.0
		print("   %-10s média %.2f ms (%+.1f%%) | pior %.2f ms | alagando=%s"
			% [caso[0], float(m["media"]), piora, float(m["pior"]), str(m["alagando"])])
	print("   referência: média %.2f ms | pior %.2f ms"
		% [float(base["media"]), float(base["pior"])])
	quit(0)


func _agua() -> Node3D:
	for n in get_root().get_node("Main").get_children():
		if String(n.name) == "AguaDaArena":
			return n as Node3D
	return null


func _medir(rotulo: String, sb: Node) -> Dictionary:
	# Descarta os primeiros quadros: o primeiro depois de uma mudança carrega o
	# custo de criar recursos, que não é o custo de rodar.
	await _quadros(20)
	var soma := 0.0
	var pior := 0.0
	var t := Time.get_ticks_usec()
	for i in AMOSTRAS:
		await process_frame
		var agora := Time.get_ticks_usec()
		var ms := float(agora - t) / 1000.0
		t = agora
		soma += ms
		pior = maxf(pior, ms)
	var media := soma / float(AMOSTRAS)
	# Registrado JUNTO com o número: uma medida de "durante a enchente" feita com
	# a enchente já encerrada é pior que medida nenhuma, porque parece boa notícia.
	var alagando: bool = bool(sb.get("flooding"))
	print("   %-40s média %6.2f ms | pior %6.2f ms | alagando=%s"
		% [rotulo, media, pior, str(alagando)])
	return {"media": media, "pior": pior, "alagando": alagando}


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
