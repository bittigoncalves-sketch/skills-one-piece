extends SceneTree
## Drop de pão ao derrotar inimigos + a vida de volta na barra acima da energia, sem corações (12/11/2026).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pao_e_barra_de_vida.gd
var total := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func q(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pao.json"))
	modo.set("progresso_forcado", "user://test_pao.json")
	root.get_node("GameFlow").start_story()
	await q(200)
	var m = get_first_node_in_group("modo_historia")
	var prog: ProgressaoDoPersonagem = m.progressao
	var Prov = load("res://src/historia/tripulantes/provisoes.gd")
	var pao0: int = int(Prov.estado(prog).estoque.get("pao", 0))
	var agua0: int = int(Prov.estado(prog).estoque.get("agua_potavel", 0))
	var sem_pao := 0
	var sem_agua := 0
	var fora_da_faixa := 0
	var aviso := ""
	for i in 200:
		var p0: int = int(Prov.estado(prog).estoque.get("pao", 0))
		var a0: int = int(Prov.estado(prog).estoque.get("agua_potavel", 0))
		aviso = m._sortear_provisoes()
		var dp: int = int(Prov.estado(prog).estoque.get("pao", 0)) - p0
		var da: int = int(Prov.estado(prog).estoque.get("agua_potavel", 0)) - a0
		if dp < 1: sem_pao += 1
		if da < 1: sem_agua += 1
		if dp > 2 or da > 2: fora_da_faixa += 1
	ok(sem_pao == 0 and sem_agua == 0, "TODO inimigo solta pão E água (22/11): em 200 inimigos, %d sem pão e %d sem água" % [sem_pao, sem_agua])
	ok(fora_da_faixa == 0, "sempre de 1 a 2 de cada")
	var pao1: int = int(Prov.estado(prog).estoque.get("pao", 0)) - pao0
	var agua1: int = int(Prov.estado(prog).estoque.get("agua_potavel", 0)) - agua0
	ok(pao1 >= 200 and pao1 <= 400 and agua1 >= 200 and agua1 <= 400, "foram para as provisões (+%d pães, +%d águas)" % [pao1, agua1])
	ok(aviso.contains("pã") and aviso.contains("águ"), "o aviso fala dos dois (\"%s\")" % aviso.strip_edges())
	# beber água dobra a regeneração de ENERGIA (e só dela)
	var vida = get_first_node_in_group("player")._vida
	var f0: float = vida.fator_da_agua()
	var bonus: Dictionary = Prov.bonus_de_energia_da_agua("agua_potavel")
	vida.premiar_agua(float(bonus.fator), float(bonus.duracao))
	ok(f0 == 1.0 and vida.fator_da_agua() == 2.0 and float(bonus.duracao) > 10.0, "beber água: energia ×2 por %.0f s (antes ×%.0f)" % [float(bonus.duracao), f0])
	ok(Prov.bonus_de_energia_da_agua("pao").fator == 1.0 and Prov.bonus_de_energia_da_agua("pao").duracao == 0.0, "comida não dá o bônus da água")
	vida.energia = 0.0
	vida.vida = vida.vida_max
	vida._t_ultimo_dano = -999999
	vida.regenerar(1.0)
	var com_agua: float = vida.energia
	vida.energia = 0.0
	vida._t_agua_ate_ms = -999999
	vida.regenerar(1.0)
	var sem_agua_e: float = vida.energia
	ok(sem_agua_e > 0.0 and absf(com_agua - 2.0 * sem_agua_e) < 0.01 * maxf(com_agua, 1.0), "a energia regenera o DOBRO com a água (%.2f × %.2f)" % [com_agua, sem_agua_e])
	# a vida é a barra do canto, visível, e os corações não são desenhados
	var barra: VidaEnergiaHud = null
	for n in get_nodes_in_group("hud"):
		for f in n.find_children("*", "VidaEnergiaHud", true, false):
			barra = f
	ok(barra != null and barra._vida.visible and barra._vida_rotulo.visible, "a barra de vida está visível")
	ok(barra != null and barra._vida.position.y < barra._energia.position.y, "a vida fica ACIMA da barra de energia")
	var hm = null
	for n in get_nodes_in_group("hud"):
		for f in n.find_children("*", "HudMinecraft", true, false):
			hm = f
	ok(hm == null or HudMinecraft.CORACOES == false, "os corações estão desligados")
	print("test_pao_e_barra_de_vida: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
