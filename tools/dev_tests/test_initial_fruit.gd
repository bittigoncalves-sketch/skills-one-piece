extends SceneTree
# ============================================================================
#  A FRUTA INICIAL CHEGA MESMO AO JOGADOR?
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_initial_fruit.gd
#
#  ------------------------------------------------------------- 2026-08-25
#  ⚠️ ESTE TESTE COBRAVA UM NOME ESCRITO À MÃO (`gura_gura`) e por isso vivia
#  vermelho. O nome vinha de uma sessão antiga; enquanto isso o jogo tinha TRÊS
#  escritores da fruta inicial discordando entre si (`Player.gd` dizia
#  `bara_bara`, `Main._spawn_player` equipava `mera_mera` e vencia). O teste não
#  estava errado sozinho — ele era a quarta opinião.
#
#  O que ele pergunta agora é a pergunta útil, e ela não tem nome dentro:
#
#      o `Player.FRUTA_INICIAL` declarado CHEGA ao corpo que nasce?
#
#  Assim ele passa a pegar o defeito de verdade — o `equip_fruit` adiado não
#  rodar, ou o `set_character` sobrescrever a fruta depois (item 34 da
#  LISTA_DE_CORRECOES) — e para de quebrar toda vez que alguém troca a fruta de
#  trabalho.
#
#  A constante é lida do SCRIPT, não copiada: `get_script_constant_map()` é o
#  mesmo caminho honesto que a `net_mp_client_probe.gd` já usa para a tabela de
#  recargas. Teste com a própria cópia da tabela envelhece em silêncio.
# ============================================================================

func _init() -> void:
	await process_frame
	var gf := get_root().get_node("GameFlow")
	gf.start_singleplayer()

	# Esperar a cena instanciar o Player
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 3000:
		await process_frame

	var player = null
	for p in get_root().get_tree().get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			player = p
			break

	if not player:
		print("❌ FALHOU - Jogador nao encontrado.")
		quit(1)
		return

	var mapa: Dictionary = player.get_script().get_script_constant_map()
	if not mapa.has("FRUTA_INICIAL"):
		print("❌ FALHOU - Player.gd não declara FRUTA_INICIAL (a fonte única sumiu).")
		quit(1)
		return
	var esperada: String = str(mapa["FRUTA_INICIAL"])

	if player.current_fruit_id != esperada:
		print("❌ FALHOU - FRUTA_INICIAL declara '%s', mas o corpo nasceu com '%s'."
			% [esperada, player.current_fruit_id])
		print("   Suspeitos, nesta ordem: o `equip_fruit` adiado de Main._spawn_player")
		print("   não rodou, ou `set_character()` escreveu por cima (item 34).")
		quit(1)
		return

	# A fruta tem que estar EQUIPADA de verdade, não só escrita no campo: sem
	# skills a barra de técnicas nasce vazia e `_fire_skill` recusa o golpe.
	var todas: Dictionary = SkillSystem.get_fruit_skills()
	var skills: Dictionary = todas.get(esperada, {})
	if skills.is_empty():
		print("❌ FALHOU - '%s' é a fruta inicial mas não tem skill nenhuma no SkillSystem." % esperada)
		print("   É o caso das 11 frutas de estoque (passiva sem golpe) — ver docs/frutas/README.md.")
		quit(1)
		return

	print("✅ PASSOU - o corpo nasceu com '%s' (Player.FRUTA_INICIAL) e ela tem %d slots: %s"
		% [esperada, skills.size(), str(skills.keys())])
	quit(0)
