extends SceneTree
# ============================================================================
#  TESTE — desenho por distância das ilhas (08/10/2026, docs/ILHA_DOS_MACACOS_PLANO.md,
#  etapa 4). O custo medido fica em `medir_lod_das_ilhas.gd` (GPU).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_lod_das_ilhas.gd
#
#  Pedido do dono: longe da ilha, ela é desenhada no mínimo (animais somem, construções
#  viram blocos...); fora de vista, não é desenhada. Confere, com o MAPA VIVO (só
#  leitura) e um progresso de teste:
#    A. a regra: classificação das peças e a folga contra pisca nos dois limites;
#    B. no jogo: na vila a ilha inicial está PERTO e a dos macacos LONGE; no meio do mar
#       a inicial vira relevo + blocos + copas, sem miúdos nem NPCs/bandidos (que param
#       de processar); a 2,3 km some até o fundo do mar dela; na volta tudo volta como
#       estava (o que estava escondido continua escondido).
# ============================================================================

const PROGRESSO := "user://test_lod_das_ilhas_progresso.json"
const Lod := preload("res://src/historia/ilhas/lod_das_ilhas.gd")

var _falhas := 0


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== DESENHO POR DISTÂNCIA DAS ILHAS =====")
	_regra()
	await _no_jogo()
	print("\nLOD_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


# ----------------------------------------------------------------- A. regra
func _regra() -> void:
	print("\n-- A. a regra --")
	var bib := BibliotecaDeModelos.padrao()
	var casos := [
		[{"tipo": "terreno"}, "chao"],
		[{"tipo": "caixa"}, "chao"],
		[{"tipo": "area_animais"}, "ignorar"],
		[{"tipo": "modelo", "modelo": "fantasy_house-bh2xhwunmf", "tamanho": bib.tamanho_padrao("fantasy_house-bh2xhwunmf")}, "construcao"],
		[{"tipo": "modelo", "modelo": "palm_tree", "tamanho": bib.tamanho_padrao("palm_tree")}, "arvore"],
		[{"tipo": "modelo", "modelo": "floresta_tree_oak_hero_green", "tamanho": Vector3(6, 9, 6)}, "arvore"],
		[{"tipo": "modelo", "modelo": "dock_long", "tamanho": bib.tamanho_padrao("dock_long")}, "miudo"],
		[{"tipo": "modelo", "modelo": "barrel_2", "tamanho": bib.tamanho_padrao("barrel_2")}, "miudo"],
		[{"tipo": "modelo", "modelo": "ship", "grupo": "navios", "tamanho": Vector3(10, 20, 30)}, "ignorar"],
		[{"tipo": "modelo", "modelo": "npc_pescador", "tamanho": Vector3.ONE}, "entidade"],
		[{"tipo": "modelo", "modelo": "bandido", "tamanho": Vector3.ONE}, "entidade"],
	]
	var errados: Array[String] = []
	for c in casos:
		var tipo := Lod.classificar(c[0], bib)
		if tipo != c[1]:
			errados.append("%s → %s (esperado %s)" % [c[0].get("modelo", c[0]["tipo"]), tipo, c[1]])
	_ok(errados.is_empty(), "classificação: relevo/placa = chão, casa = bloco, árvore = copa, cais e barril = miúdo, barco fora, NPC e bandido = entidade %s" % str(errados))
	var P := Lod.PERTO_ATE
	var V := Lod.VISIVEL_ATE
	var E := Lod.Estado
	_ok(Lod.proximo_estado(E.PERTO, P + 5.0) == E.PERTO and Lod.proximo_estado(E.PERTO, P + 20.0) == E.LONGE
		and Lod.proximo_estado(E.LONGE, P - 5.0) == E.LONGE and Lod.proximo_estado(E.LONGE, P - 20.0) == E.PERTO,
		"folga de %.0f m no limite de %.0f m (parado na borda não pisca)" % [Lod.FOLGA, P])
	_ok(Lod.proximo_estado(E.LONGE, V + 5.0) == E.LONGE and Lod.proximo_estado(E.LONGE, V + 20.0) == E.OCULTA
		and Lod.proximo_estado(E.OCULTA, V - 5.0) == E.OCULTA and Lod.proximo_estado(E.OCULTA, V - 20.0) == E.LONGE
		and Lod.proximo_estado(E.PERTO, V + 100.0) == E.OCULTA,
		"folga no limite de %.0f m; de perto para muito longe vai direto a OCULTA" % V)


# ---------------------------------------------------------------- B. jogo
func _no_jogo() -> void:
	print("\n-- B. no Modo História --")
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 150:
		await process_frame
	var jogador: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var lod: Lod = current_scene.get("_lod")
	_ok(jogador != null and lod != null, "o Modo História abriu com o desenho por distância")
	if jogador == null or lod == null:
		return
	jogador.set_meta("damage_immune", true)
	var ini: Dictionary = lod.get("_ilhas")["ilha_inicial"]
	var mac: Dictionary = lod.get("_ilhas")["ilha_dos_macacos"]
	print("     ilha inicial: chão %d · construções %d · árvores %d · miúdos %d · entidades %d" % [
		ini["chao"].size(), ini["grandes"].size(), ini["arvores"].size(), ini["miudos"].size(), ini["entidades"].size()])
	_ok(ini["grandes"].size() >= 20 and ini["arvores"].size() >= 300 and ini["miudos"].size() >= 100
		and ini["entidades"].size() >= 5 and ini["chao"].size() >= 100,
		"a ilha inicial tem construções, árvores, miúdos, entidades (NPCs, bandidos) e chão (relevo + fundo do mar)")
	_ok((ini["blocos"] as MultiMeshInstance3D).multimesh.instance_count == ini["grandes"].size()
		and (ini["copas"] as MultiMeshInstance3D).multimesh.instance_count == ini["arvores"].size(),
		"um bloco por construção e uma copa por árvore (2 MultiMesh)")
	await _quadros(40)
	_ok(lod.estado_de("ilha_inicial") == Lod.Estado.PERTO and lod.estado_de("ilha_dos_macacos") == Lod.Estado.LONGE,
		"na vila: a inicial PERTO, a dos macacos LONGE")
	_ok(_todos(mac["miudos"], false) and _todos(mac["chao"], true), "a dos macacos, de longe: relevo à vista, píer escondido")

	# Um NPC escondido de propósito ANTES de sair: na volta tem de continuar escondido.
	var npc: Node3D = ini["entidades"].filter(func(n): return n is NpcDaIlha)[0]
	npc.visible = false

	print("\n   no meio do mar (x = 814)")
	_por(jogador, Vector3(814, AguaDoMundo.nivel_em(814, 0) - 0.3, 0))
	await _quadros(40)
	_ok(lod.estado_de("ilha_inicial") == Lod.Estado.LONGE, "a inicial vira LONGE")
	_ok(_todos(ini["chao"], true) and _todos(ini["grandes"], false) and _todos(ini["arvores"], false) and _todos(ini["miudos"], false),
		"relevo e fundo à vista; construções, árvores e miúdos escondidos")
	_ok((ini["blocos"] as Node3D).visible and (ini["copas"] as Node3D).visible, "no lugar: blocos e copas")
	var parados: bool = ini["entidades"].all(func(n): return not n.visible and n.process_mode == Node.PROCESS_MODE_DISABLED)
	_ok(parados, "NPCs e bandidos somem e param de processar")

	print("\n   bem longe (x = 2300, depois dos macacos)")
	_por(jogador, Vector3(2300, AguaDoMundo.nivel_em(2300, 0) - 0.3, 0))
	await _quadros(40)
	_ok(lod.estado_de("ilha_inicial") == Lod.Estado.OCULTA and lod.estado_de("ilha_dos_macacos") == Lod.Estado.LONGE,
		"a 2 km a inicial some (OCULTA); a dos macacos fica LONGE")
	var fundo := current_scene.get_node_or_null("FundoDoMar") as Node3D
	_ok(_todos(ini["chao"], false) and not (ini["blocos"] as Node3D).visible and not (ini["copas"] as Node3D).visible
		and fundo != null and not fundo.visible, "nada da inicial é desenhado, nem o fundo do mar dela")

	print("\n   de volta à vila")
	_por(jogador, Vector3(152, 6, 20))
	await _quadros(40)
	_ok(lod.estado_de("ilha_inicial") == Lod.Estado.PERTO and _todos(ini["chao"], true) and _todos(ini["grandes"], true)
		and _todos(ini["arvores"], true) and not (ini["blocos"] as Node3D).visible, "PERTO de novo: tudo como era, sem blocos")
	var voltaram := true
	for n in ini["entidades"]:
		if n != npc:
			voltaram = voltaram and n.visible and n.process_mode != Node.PROCESS_MODE_DISABLED
	_ok(voltaram and not npc.visible and npc.process_mode != Node.PROCESS_MODE_DISABLED,
		"as entidades voltam a aparecer e processar; a que estava escondida continua escondida")

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))


func _todos(nos: Array, visivel: bool) -> bool:
	for n in nos:
		if is_instance_valid(n) and (n as Node3D).visible != visivel:
			return false
	return true


func _por(j: CharacterBody3D, onde: Vector3) -> void:
	j.global_position = onde
	j.velocity = Vector3.ZERO


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
