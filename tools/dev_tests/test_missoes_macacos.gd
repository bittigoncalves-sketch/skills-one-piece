extends SceneTree
# ============================================================================
#  MISSÕES DA ILHA DOS MACACOS v2 (22/11/2026) no jogo de verdade (mapa real, `ir_a_ilha`):
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_missoes_macacos.gd
#  Prova: a principal "O Rei da Selva" começa ao pisar na ilha; os 4 NPCs de missão existem com a "?"; cada uma das 5 missões anda e se entrega pelos
#  eventos reais (props com E, abates, peixe); o Gorila-rei nasce no covil e, derrotado, entrega a principal (XP, ouro, baú).
#  NÃO prova a vista (foto) nem a sensação de jogar.
# ============================================================================
const Missoes := preload("res://src/historia/missoes/missoes.gd")
var _ok_n := 0
var _falhas := 0
var cena: Node
var prog: ProgressaoDoPersonagem


func _ok(rotulo: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
	else:
		_falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _init() -> void:
	_executar.call_deferred()


func q(n: int) -> void:
	for i in n:
		await physics_frame


func _executar() -> void:
	var arquivo := "user://test_missoes_macacos.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", arquivo)
	var pe := ProgressaoDoPersonagem.carregar(arquivo)
	pe.corpo = "masculino"
	pe.salvar(arquivo)
	root.get_node("GameFlow").start_story()
	await q(300)
	cena = current_scene
	var j: Node3D = get_first_node_in_group("player")
	_ok("jogo montado", cena != null and j != null)
	if j == null:
		quit(1)
		return
	j.set_meta("damage_immune", true)
	prog = cena.get("progressao")
	_ok("antes de chegar, a principal ainda não começou", prog.estado_da_missao("rei_da_selva") == Missoes.DISPONIVEL)
	cena.call("ir_a_ilha", "ilha_dos_macacos")
	await q(400)
	_ok("pisar na ilha aceita sozinha \"O Rei da Selva\"", prog.estado_da_missao("rei_da_selva") == Missoes.ACEITA)

	# o cais rústico: de pé no meio do piso, o jogador não cai (colisão da malha do modelo) e fica a ~0,6 m do mar
	var pecas_cais: Dictionary = {}
	for p: Dictionary in MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]["pecas"]:
		if String(p["id"]) == "macacos_vila_cais":
			pecas_cais = p
	var pos_cais: Vector3 = pecas_cais["posicao"]
	j.global_position = Vector3(pos_cais.x, 4.0, pos_cais.z)
	j.velocity = Vector3.ZERO
	await q(90)
	_ok("de pé no cais novo (y=%.2f, esperado ~1,4 = piso a 0,6 m + 0,8 do centro do jogador)" % j.global_position.y, j.global_position.y > 1.2 and j.global_position.y < 1.7)
	j.global_position = Vector3(1500.0 - 128.0 + 6.0, 6.0, 4.0)
	await q(60)
	# NPCs de missão
	var npcs := {}
	for n in get_nodes_in_group("npc"):
		if n is NpcDaIlha:
			npcs[(n as NpcDaIlha).tipo] = n
	for t in ["npc_macaco_cozinheira", "npc_macaco_pescador", "npc_macaco_vigia", "npc_macaco_curandeiro", "npc_mestre_geppo"]:
		_ok("NPC %s vivo na ilha" % t, npcs.has(t))
	var esperado := {"npc_macaco_cozinheira": "cesto_de_bananas", "npc_macaco_pescador": "pesca_do_cais", "npc_macaco_vigia": "os_saqueadores", "npc_macaco_curandeiro": "os_quatro_totens"}
	for t in esperado:
		var n: NpcDaIlha = npcs.get(t)
		_ok("%s oferece %s com a \"?\"" % [t, esperado[t]], n != null and n.missao(prog) == esperado[t] and n.get_node_or_null("MarcaDeMissao") != null)
	_ok("a missão principal não trava as outras (paralela)", not Missoes.ha_em_andamento(prog) and Missoes.proximas(prog).size() >= 4)

	# props
	var props: Node3D = cena.get("props_dos_macacos")
	var cachos: Array = props.props.keys().filter(func(k: String) -> bool: return k.begins_with("macacos_sitio_cacho_"))
	var totens: Array = props.props.keys().filter(func(k: String) -> bool: return k.begins_with("macacos_sitio_totem_"))
	_ok("6 cachos, 4 totens e o fruto dourado no mapa (%d / %d / %s)" % [cachos.size(), totens.size(), str(props.props.has("macacos_sitio_fruto_dourado"))], cachos.size() == 6 and totens.size() == 4 and props.props.has("macacos_sitio_fruto_dourado"))
	if cachos.size() != 6 or totens.size() != 4:
		print("\nMISSOES_MACACOS props ausentes: parando (%d conferem | %d divergem)" % [_ok_n, _falhas])
		quit(1)
		return
	# colher com E sem a missão aceita não faz nada (e a dica manda aceitar)
	var corpo0: Node3D = props.props[cachos[0]]["corpo"]
	j.global_position = corpo0.global_position + Vector3(1.0, 1.0, 0.0)
	await q(3)
	_ok("sem a missão aceita o E não colhe (dica: %s)" % props.dica(), not props.interagir() and props.dica().contains("aceite a missão") and prog.abates_da_missao("cesto_de_bananas") == 0)
	# 1) cesto de bananas
	_ok("aceitar o cesto de bananas", prog.aceitar_missao("cesto_de_bananas"))
	_ok("agora o E colhe o cacho perto (dica: %s)" % props.dica(), props.dica().begins_with("E —") and props.interagir() and prog.abates_da_missao("cesto_de_bananas") == 1)
	for i in range(1, 5):
		props.coletar(cachos[i])
	_ok("5 cachos contam 5/6 (%d)" % prog.abates_da_missao("cesto_de_bananas"), prog.abates_da_missao("cesto_de_bananas") == 5 and prog.estado_da_missao("cesto_de_bananas") == Missoes.ACEITA)
	props.coletar(cachos[5])
	_ok("6/6: a missão fica pronta", prog.estado_da_missao("cesto_de_bananas") == Missoes.PRONTA)
	var ouro0 := prog.ouro
	_ok("entrega: +100 de ouro", prog.entregar_missao("cesto_de_bananas") and prog.ouro == ouro0 + 100)

	# 2) pesca
	prog.aceitar_missao("pesca_do_cais")
	prog.contar_abate("peixe", 3)
	_ok("pesca do cais pronta com 3 peixes", prog.estado_da_missao("pesca_do_cais") == Missoes.PRONTA and prog.entregar_missao("pesca_do_cais"))

	# 3) saqueadores (8 macacos humanoides) → destrava o fruto dourado
	_ok("o fruto dourado só depois dos saqueadores", not prog.aceitar_missao("fruto_dourado"))
	prog.aceitar_missao("os_saqueadores")
	prog.contar_abate("macaco", 8)
	_ok("saqueadores prontos e entregues", prog.estado_da_missao("os_saqueadores") == Missoes.PRONTA and prog.entregar_missao("os_saqueadores"))

	# 4) totens
	prog.aceitar_missao("os_quatro_totens")
	for t in totens:
		props.coletar(t)
	_ok("4 totens despertos: missão pronta", prog.estado_da_missao("os_quatro_totens") == Missoes.PRONTA and prog.entregar_missao("os_quatro_totens"))
	_ok("o totem desperto acende a luz", (props.props[totens[0]]["corpo"] as Node3D).get_node_or_null("LuzDoTotem") != null)

	# 5) fruto dourado
	_ok("aceitar o fruto dourado agora", prog.aceitar_missao("fruto_dourado"))
	props.coletar("macacos_sitio_fruto_dourado")
	_ok("fruto dourado colhido: pronta e entregue", prog.estado_da_missao("fruto_dourado") == Missoes.PRONTA and prog.entregar_missao("fruto_dourado"))
	_ok("os props feitos ficam no save (%d)" % prog.dados_de("macacos_props").get("feitos", []).size(), prog.dados_de("macacos_props").get("feitos", []).size() == 11)       # 6 cachos + 4 totens + 1 fruto

	# o Gorila-rei
	var gorila: AnimalDaIlha = null
	for a in get_nodes_in_group("animais"):
		if a is AnimalDaIlha and (a as AnimalDaIlha).especie == "gorila_rei":
			gorila = a
	_ok("o Gorila-rei nasceu no covil do Trono", gorila != null)
	if gorila != null:
		var c: Vector3 = gorila.global_position
		var trono := Vector3(1500.0 + 62.0, 10.0, -60.0)
		_ok("dentro do covil (a %.0f m do centro do Trono)" % Vector2(c.x - trono.x, c.z - trono.z).length(), Vector2(c.x - trono.x, c.z - trono.z).length() < 26.0 and absf(c.y - trono.y) < 6.0)
		_ok("é chefe de 1100 de vida com o cérebro de golpes", gorila.boss() and gorila.max_health == 1100.0 and gorila.get("combate") != null)
		var baus: Node3D = cena.get("baus_de_chefe")
		var antes_baus: int = baus.baus.size()
		var xp1 := prog.xp
		var ouro1 := prog.ouro
		gorila.health = 1.0
		gorila.take_damage(1000.0, j.global_position)
		await q(30)
		_ok("derrotado: a principal \"O Rei da Selva\" se entrega sozinha", prog.estado_da_missao("rei_da_selva") == Missoes.ENTREGUE)
		_ok("recompensa: ouro +800 (%d → %d) e XP subiu (%d → %d)" % [ouro1, prog.ouro, xp1, prog.xp], prog.ouro >= ouro1 + 800 and prog.xp > xp1)
		_ok("o chefe solta um baú (%d → %d)" % [antes_baus, baus.baus.size()], baus.baus.size() > antes_baus)
	print("\nMISSOES_MACACOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
