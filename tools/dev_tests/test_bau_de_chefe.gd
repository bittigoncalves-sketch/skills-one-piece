extends SceneTree
# ============================================================================
#  BAÚ DE CHEFE (18/11/2026).
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_bau_de_chefe.gd
#  Sorteio (poder pela força do chefe, variação, fruta nova), abrir (fruta guardada, baú some), save/recarga, e na cena real: chefe derrotado solta baú, capanga não.
# ============================================================================
const Baus := preload("res://src/historia/baus/baus_de_chefe.gd")
var total := 0
var falhas := 0
class HudFalsa extends Node:
	var avisos: Array[String] = []
	func avisar(t: String) -> void: avisos.append(t)
	func ligar_interagivel(_n: Node) -> void: pass
class JogadorFalso extends Node3D:
	pass
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	# --- poder pela força
	ok(Baus.poder_do_chefe(99) == 1 and Baus.poder_do_chefe(999) == 1 and Baus.poder_do_chefe(1000) == 2, "fama < 1000 = poder 1; 1000 = 2")
	ok(Baus.poder_do_chefe(9999) == 2 and Baus.poder_do_chefe(10000) == 3 and Baus.poder_do_chefe(149999) == 3, "10 mil = 3; 149999 ainda 3")
	ok(Baus.poder_do_chefe(150000) == 4 and Baus.poder_do_chefe(249999) == 4 and Baus.poder_do_chefe(250000) == 5 and Baus.poder_do_chefe(338613) == 5, "150 mil = 4; 250 mil e Mihawk = 5")
	ok(Baus.poder_do_chefe(0) == 1 and Baus.poder_do_chefe(1e12) == 5, "extremos ficam em 1–5")
	for p in range(1, 6):
		ok(not PerfilDeFrutas.frutas_do_poder(p).is_empty(), "o poder %d (%s) tem frutas para dar" % [p, PerfilDeFrutas.NOMES_DO_PODER[p - 1]])
	# --- gerente isolado
	var prog := ProgressaoDoPersonagem.new()
	var hud := HudFalsa.new()
	var jogador := JogadorFalso.new()
	root.add_child(hud)
	root.add_child(jogador)
	var gerente: Node3D = Baus.new()
	root.add_child(gerente)
	gerente.ligar(prog, hud, func() -> Node3D: return jogador)
	gerente.rng.seed = 12345
	var contagem := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for i in 4000:
		contagem[gerente.sortear_poder(3)] += 1
	ok(absf(contagem[3] / 4000.0 - 0.75) < 0.04 and absf(contagem[2] / 4000.0 - 0.20) < 0.04 and absf(contagem[4] / 4000.0 - 0.05) < 0.03 and contagem[1] == 0 and contagem[5] == 0,
		"base 3: ~75 %% rara, ~20 %% incomum, ~5 %% épica (%s)" % str(contagem))
	var baixo := 0
	var alto := 0
	for i in 2000:
		baixo += 1 if gerente.sortear_poder(1) < 1 else 0
		alto += 1 if gerente.sortear_poder(5) > 5 else 0
	ok(baixo == 0 and alto == 0, "o poder nunca sai de 1–5")
	# fruta nova de preferência
	var pool := PerfilDeFrutas.frutas_do_poder(5)
	for id in pool.slice(1):
		prog.guardar_akuma(id, 1)
	var sempre_a_nova := true
	for i in 60:
		sempre_a_nova = sempre_a_nova and gerente.sortear_fruta(5) == pool[0]
	ok(sempre_a_nova, "tendo as outras lendárias, só sai a que falta (%s)" % pool[0])
	prog.guardar_akuma(pool[0], 1)
	ok(pool.has(gerente.sortear_fruta(5)), "tendo todas do poder, repete uma delas (não fica sem baú)")
	for _id in prog.akumas_guardadas().keys(): prog.remover_akuma(_id, 99)
	# soltar e abrir
	var antes := hud.avisos.size()
	var b: Dictionary = gerente.soltar(Vector3(10, 0, 10), 338613.0, "Mihawk")
	ok(not b.is_empty() and gerente.baus.size() == 1 and int(b.poder) >= 1 and PerfilDeFrutas.frutas_a_venda().has(str(b.fruta)), "chefe forte solta um baú com uma fruta (poder %d: %s)" % [b.poder, b.fruta])
	ok(PerfilDeFrutas.poder_da_fruta(str(b.fruta)) == int(b.poder), "a raridade do baú é a da fruta que está dentro")
	ok(hud.avisos.size() == antes + 1 and hud.avisos.back().contains("Mihawk"), "avisa o baú e de quem caiu (%s)" % hud.avisos.back())
	jogador.global_position = Vector3(40, 0, 40)
	ok(gerente.dica() == "" and not gerente.interagir(), "longe, nada para abrir")
	jogador.global_position = Vector3(10, 0, 11)
	ok(gerente.dica().begins_with("E — abrir o baú"), "perto, a dica aparece (%s)" % gerente.dica())
	# persistência: um gerente novo reabre o baú que ficou no chão
	var gerente2: Node3D = Baus.new()
	root.add_child(gerente2)
	gerente2.ligar(prog, hud, func() -> Node3D: return jogador)
	ok(gerente2.baus.size() == 1 and gerente2.baus[0].fruta == b.fruta and gerente2.baus[0].poder == b.poder, "o baú não aberto volta ao recarregar o save")
	gerente2.queue_free()
	ok(gerente.interagir(), "E abre o baú")
	ok(prog.quantas_akuma(b.fruta) == 1 and gerente.baus.is_empty(), "a fruta vai para as guardadas e o baú some")
	ok(progressao_sem_baus(prog), "aberto, o baú sai do save")
	ok(not gerente.interagir(), "não abre duas vezes")
	# armas do Epic Fight nos baús
	ok(Baus.poder_da_arma("ef_wooden_dagger") == 1 and Baus.poder_da_arma("ef_stone_tachi") == 2 and Baus.poder_da_arma("ef_iron_spear") == 3 \
		and Baus.poder_da_arma("ef_uchigatana") == 4 and Baus.poder_da_arma("ef_netherite_greatsword") == 5 and Baus.poder_da_arma("ef_bokken") == 1, "poder da arma pelo material")
	var arma: String = gerente.sortear_arma(5)
	ok(arma != "" and Baus.poder_da_arma(arma) == 5, "sorteia arma do poder pedido (%s)" % arma)
	var nada_antes := prog.equipamentos.size()
	var br: Dictionary = gerente._criar(900, Vector3(10, 0, 10), "", 5, arma)
	gerente.baus.append(br) if not gerente.baus.has(br) else null
	ok(gerente.abrir(br) and prog.equipamentos.has(arma) and prog.inventario.contar(ItensEpicFight.id_do_item(arma)) == 1, "abrir baú de arma: vai para os equipamentos e a mochila")
	ok(gerente.sortear_arma(5) != arma, "arma que já tem não sai de novo")
	var cheio := ProgressaoDoPersonagem.new()
	for i in range(InventarioMinecraft.MOCHILA_INI, InventarioMinecraft.HOTBAR_FIM):
		cheio.inventario.slots[i] = InventarioMinecraft.nova("historia:bau_tesouros", 1)
	ok(not cheio.receber_arma("ef_iron_tachi") and not cheio.equipamentos.has("ef_iron_tachi"), "mochila cheia: recusa a arma sem perdê-la")
	# limite de baús no chão
	for i in Baus.MAX_PENDENTES + 5:
		gerente.soltar(Vector3(i, 0, 0), 5.0)
	ok(gerente.baus.size() == Baus.MAX_PENDENTES, "no máximo %d baús no chão" % Baus.MAX_PENDENTES)
	gerente.queue_free()
	# --- cena real
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_bau_de_chefe.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_bau_de_chefe.json"))
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var cena := current_scene
	var jog: Node3D = get_first_node_in_group("player")
	var baus: Node3D = cena.get("baus_de_chefe")
	ok(baus != null and jog != null, "o Modo História tem o gerente de baús")
	if baus == null or jog == null:
		quit(1)
		return
	jog.set_meta("damage_immune", true)
	var raiz: Node3D = cena.get("_raiz_do_mapa")
	ok(raiz != null, "a raiz do mapa existe")
	if raiz == null:
		quit(1)
		return
	var chefe := _personagem("mp_higuma", raiz, jog.global_position + Vector3(4, 0, 0))
	var capanga := _personagem("mp_bandit", raiz, jog.global_position + Vector3(-4, 0, 0))
	await quadros(5)
	ok(bool(chefe.ficha.get("chefe", false)) and not bool(capanga.ficha.get("chefe", false)), "Higuma é chefe; o bandido não")
	var antes_n: int = baus.baus.size()       # o baú FIXO do topo das plataformas do Geppo já está no chão (18/11/2026)
	cena.call("_ao_derrotar_personagem_east_blue", capanga)
	ok(baus.baus.size() == antes_n, "o bandido comum NÃO solta baú")
	cena.call("_ao_derrotar_personagem_east_blue", chefe)
	var novo: Dictionary = baus.baus.back() if baus.baus.size() > antes_n else {}
	ok(baus.baus.size() == antes_n + 1 and int(novo.get("poder", 9)) <= 2, "o Higuma (fraco) solta um baú comum/incomum (poder %d)" % int(novo.get("poder", -1)))
	var salvo: Dictionary = cena.progressao.dados_de("baus_de_chefe")
	ok((salvo.get("lista", []) as Array).size() == antes_n + 1, "o baú entrou no save")
	var bau: Dictionary = novo
	jog.global_position = (bau.pos as Vector3) + Vector3(1, 0, 0)
	ok(baus.interagir() and cena.progressao.quantas_akuma(bau.fruta) >= 1, "abrindo na cena, a fruta (%s) chega ao N › FRUTAS" % bau.fruta)
	print("BAU_DE_CHEFE: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
func progressao_sem_baus(prog: ProgressaoDoPersonagem) -> bool:
	return (prog.dados_de("baus_de_chefe").get("lista", []) as Array).is_empty()
func _personagem(modelo: String, raiz: Node3D, onde: Vector3) -> PersonagemMinePiece:
	var ficha := DadosEastBlue.ficha_do_modelo(modelo).duplicate(true)
	var p := PersonagemMinePiece.new()
	p.montar(ficha, modelo)
	p.renasce = false
	raiz.add_child(p)
	p.global_position = onde
	return p
