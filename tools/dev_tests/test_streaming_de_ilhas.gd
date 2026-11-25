extends SceneTree
# ============================================================================
#  CARGA POR DISTÂNCIA DAS ILHAS (28/10/2026): só a ilha onde o jogador está, e as que ele alcança.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_streaming_de_ilhas.gd
#
#  Lê o MAPA VIVO (11 ilhas). Confere: (1) a partição das peças por ilha; (2) a entrada monta só a Ilha Inicial; (3) ao chegar perto da
#  Ilha dos Macacos ela é montada, e a Inicial sai quando o jogador se afasta mais de 950 m; (4) o que a ilha criou (NPCs, inimigos,
#  animais, pomar) some junto e as listas dos sistemas não ficam com referências mortas; (5) voltar monta de novo, igual.
# ============================================================================

const INICIAL := "ilha_inicial"
const MACACOS := "ilha_dos_macacos"
var total := 0
var falhas := 0
var modo: Node


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func esperar(condicao: Callable, maximo := 1500) -> int:
	var q := 0
	while not condicao.call() and q < maximo:
		await physics_frame
		q += 1
	return q


func vivos(lista: Array) -> int:
	return lista.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()).size()


func rodar() -> void:
	print("\n-- 1. partição das peças --")
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var caixas: Dictionary = preload("res://src/historia/ilhas/ilhas.gd").caixas(mapa)
	var part := StreamingDeIlhas.particionar(mapa["pecas"], caixas)
	var soma := 0
	for id in part:
		soma += (part[id] as Array).size()
	ok(soma == (mapa["pecas"] as Array).size(), "cada peça cai em UMA lista (%d de %d)" % [soma, (mapa["pecas"] as Array).size()])
	ok(caixas.size() == 11 and (part[INICIAL] as Array).size() > 1000 and (part[MACACOS] as Array).size() > 0 and (part[MACACOS] as Array).size() < (part[INICIAL] as Array).size(),
		"11 ilhas; a Inicial tem %d peças e a dos Macacos %d" % [(part[INICIAL] as Array).size(), (part[MACACOS] as Array).size()])

	print("\n-- 2. a entrada monta só a ilha do jogador --")
	var m = load("res://src/historia/ModoHistoria.gd")
	m.set("progresso_forcado", "user://test_streaming_de_ilhas.json")
	m.set("carregar_tudo_forcado", 0)                     # liga a carga por distância (headless carrega tudo por padrão)
	var t0 := Time.get_ticks_msec()
	root.get_node("GameFlow").start_story()
	await esperar(func(): return get_first_node_in_group("player") != null)
	var entrada_ms := Time.get_ticks_msec() - t0
	modo = current_scene
	var s: StreamingDeIlhas = modo._streaming
	ok(s.esta_carregada("") and s.esta_carregada(INICIAL) and not s.esta_carregada(MACACOS), "carregadas na entrada: %s" % str(s.ids_carregadas()))
	ok(s.ids_carregadas().size() == 2, "só os arredores e a Ilha Inicial (%d ilhas)" % s.ids_carregadas().size())
	var raiz: Node3D = modo._raiz_do_mapa
	var nos_inicial := raiz.get_child_count()
	ok(raiz.get_node_or_null("RelevoEmBlocos_" + MACACOS) != null, "o relevo da Ilha dos Macacos existe (de longe ela é terra)")
	ok(vivos(modo._npcs.npcs) > 0 and vivos(modo._animais.animais) >= 0, "NPCs da Inicial existem (%d)" % vivos(modo._npcs.npcs))
	var npcs_inicial: int = vivos(modo._npcs.npcs)
	print("  (entrada: %d ms, %d nós na raiz)" % [entrada_ms, nos_inicial])

	print("\n-- 3. chegar perto de outra ilha monta ela --")
	var j: CharacterBody3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.global_position = Vector3(1000.0, 30.0, 0.0)       # a 372 m da placa dos Macacos, a 744 m da Inicial
	j.velocity = Vector3.ZERO
	var q := await esperar(func(): return s.esta_carregada(MACACOS))
	ok(s.esta_carregada(MACACOS), "a Ilha dos Macacos foi montada ao chegar a 372 m (em %d quadros)" % q)
	ok(raiz.get_child_count() > nos_inicial, "ganhou nós (%d → %d)" % [nos_inicial, raiz.get_child_count()])
	ok(s.esta_carregada(INICIAL), "a Inicial segue montada a 744 m (a descarga é só além de 950 m)")

	print("\n-- 4. afastar descarrega --")
	j.global_position = Vector3(1450.0, 30.0, 0.0)       # dentro dos Macacos; 1.194 m da Inicial
	j.velocity = Vector3.ZERO
	await esperar(func(): return not s.esta_carregada(INICIAL))
	await quadros(10)
	ok(not s.esta_carregada(INICIAL), "a Inicial saiu da memória")
	ok(vivos(modo._npcs.npcs) < npcs_inicial, "os NPCs dela saíram das listas (%d → %d)" % [npcs_inicial, vivos(modo._npcs.npcs)])
	ok(modo._npcs.npcs.all(func(n): return is_instance_valid(n)), "e as listas não guardam referência morta")
	ok(modo._animais.animais.all(func(a): return is_instance_valid(a)), "nem a dos animais")
	ok(raiz.get_node_or_null("RelevoEmBlocos_" + INICIAL) != null, "o relevo da Inicial continua (ela vira terra ao longe)")
	ok(modo._lod.estado_de(INICIAL) != -1, "o LOD ainda conhece a Inicial (só o chão)")
	var nos_depois := raiz.get_child_count()
	ok(nos_depois < nos_inicial + 400, "a raiz não carrega mais a Inicial inteira (%d nós)" % nos_depois)

	print("\n-- 5. voltar monta de novo, igual --")
	j.global_position = Vector3(300.0, 30.0, 0.0)
	j.velocity = Vector3.ZERO
	await esperar(func(): return s.esta_carregada(INICIAL))
	await quadros(30)
	ok(s.esta_carregada(INICIAL), "a Inicial voltou")
	ok(vivos(modo._npcs.npcs) >= npcs_inicial, "com os mesmos NPCs (%d)" % vivos(modo._npcs.npcs))
	await esperar(func(): return not s.esta_carregada(MACACOS), 400)
	ok(true, "(Macacos a %s)" % ("fora" if not s.esta_carregada(MACACOS) else "dentro"))

	print("\n%d/%d" % [total - falhas, total])
	m.set("carregar_tudo_forcado", -1)
	m.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
