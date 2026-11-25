extends SceneTree
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const SAVE := "user://test_sobrevivencia_integracao.json"
var falhas := 0
var total := 0
func _init() -> void: executar.call_deferred()
func ok(sim: bool, mensagem: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + mensagem)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var cena: Node = current_scene
	var sistema: Node = cena.get_node_or_null("Sobrevivencia")
	var hud: Node = cena.get("_hud")
	var j: Node3D = cena.jogador_local()
	var p: ProgressaoDoPersonagem = cena.progressao
	ok(sistema != null and j != null, "campanha monta com sobrevivência")
	if sistema == null or j == null: quit(1); return
	j.set_meta("damage_immune", true)
	ok(hud.abrir_menu_de_pets() and hud.menu_de_pets_aberto(), "B abre tripulação sem pet próximo")
	var antes: float = P.estado(p).sede
	await quadros(20)
	ok(is_equal_approx(P.estado(p).sede, antes), "menu pausa sede pelo relógio")
	hud.fechar_menu_de_pets()
	p.recrutados["nami"] = true
	P.adicionar(p, "humano_nami")
	P.atribuir(p, "humano_nami", 5)
	await quadros(5)
	ok(is_instance_valid(sistema.corpos.get("humano_nami")), "cargo cria humano na cena")
	var c: Node = sistema.corpos.get("humano_nami")
	if is_instance_valid(c):
		var barras: Node = hud.get_node_or_null("BarrasDeCriaturas")
		if barras != null: barras._buscar()
		ok(barras != null and barras.get("_criaturas").has(c), "HUD real registra o tripulante para vida e nível")
		c.set("health", 50)
		P.estado(p).membros.humano_nami.fome = 0
		sistema.avancar(0.001)
		ok(float(c.get("health")) > 50, "fome antiga zero não bloqueia regeneração do aliado real")
		P.guardar(p, "pao", 1)
		ok(not P.consumir(p, "pao", "humano_nami") and P.quantidade_comida(p) == 1, "companheiro não consome o estoque do jogador")
		sistema.avancar(0.001)
		ok(float(c.get("health")) > 50, "aliado alimentado volta a regenerar")
		var vida := float(c.get("health"))
		P.estado(p).vagas[5] = ""
		p.mudou.emit()
		await quadros(2)
		P.atribuir(p, "humano_nami", 5)
		await quadros(2)
		ok(absf(float(sistema.corpos.humano_nami.health) - vida) < 1, "recolher e chamar não cura")
	# Mesmas construções que a ilha inicial usa, sem ler/gravar mapa do dono.
	var dados := {"pecas": [
		{"modelo":"market_stalls_compact", "posicao":Vector3(12,3,12), "tamanho":Vector3(8,6,8), "rotacao_graus":Vector3.ZERO},
		{"modelo":"blacksmith", "posicao":Vector3(-12,3,12), "tamanho":Vector3(8,6,8), "rotacao_graus":Vector3.ZERO}]}
	var npcs: NpcsDaIlha = cena.get("_npcs")
	load("res://src/historia/missoes/inicio_da_jornada.gd").colocar_npcs(cena.get_node("Mapa"), dados, MapaMontador.biblioteca_em_uso(), npcs)
	ok(npcs.npcs.any(func(n): return n.tipo == "npc_comida") and npcs.npcs.any(func(n): return n.tipo == "npc_ferreiro"), "vendedor e ferreiro montam junto às construções")
	var vendedor: NpcDaIlha
	var ferreiro: NpcDaIlha
	for n in npcs.npcs:
		if n.tipo == "npc_comida": vendedor = n
		if n.tipo == "npc_ferreiro": ferreiro = n
	p.ouro = 20
	j.global_position = vendedor.global_position + Vector3(0,1,1)
	ok(npcs.interagir() and hud.loja_aberta(), "E abre a loja do vendedor")
	hud.get("_loja").executar("comprar", "agua_potavel")
	ok(int(P.estado(p).estoque.get("agua_potavel", 0)) == 1 and p.ouro == 19, "compra real da janela")
	hud.fechar_loja()
	# 20/11/2026: a missão da ferraria (e o minigame da forja, que só abria por ela) saíram com a cadeia da vara; o autosave segue conferido com a compra.
	await quadros(3)
	var salvo := ProgressaoDoPersonagem.carregar(SAVE)
	ok(int(P.estado(salvo).estoque.get("agua_potavel",0)) == 1, "autosave grava a compra sem XP")
	var avisos: Array[String] = []
	sistema.aviso.connect(func(t: String): avisos.append(t))
	P.estado(p).sede = 300
	sistema.avancar(4)
	ok(avisos.any(func(t): return "morreu de sede" in t) and P.estado(p).sede == 300, "quatro dias matam e respawn evita ciclo de mortes")
	await quadros(2)
	print("RESULTADO INTEGRACAO: %d checks, %d falhas" % [total, falhas])
	quit(1 if falhas else 0)
