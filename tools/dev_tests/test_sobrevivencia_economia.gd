extends SceneTree
const P := preload("res://src/historia/tripulantes/provisoes.gd")
class Nav:
	extends Node
	var barcos: Array = []
	var _humanos := {}
	var tripulacao: Array = []
class Barco:
	extends Node
	var health := 25.0
	var max_health := 100.0
	var afundando := false
class Vitima:
	extends StaticBody3D
	func nome() -> String: return "Vítima de teste"
	func falar(_texto: String) -> void: pass
var falhas := 0
var total := 0
func _init() -> void: executar.call_deferred()
func ok(sim: bool, nome: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + nome)
func executar() -> void:
	await process_frame
	var p := ProgressaoDoPersonagem.new()
	var ids: Array[String] = []
	for id in ["sanji", "beto", "iara", "nami", "crocodile", "barba_negra"]:
		p.recrutados[id] = true
		var membro := Tripulacao.id_do_humano(id)
		P.adicionar(p, membro)
		P.atribuir(p, membro, ids.size())
		ids.append(membro)
	var d := P.estado(p)
	var nav := Nav.new()
	root.add_child(nav)
	var barco := Barco.new()
	root.add_child(barco)
	nav.barcos.append(barco)
	var sistema = load("res://src/historia/tripulantes/sobrevivencia.gd").new()
	sistema.progressao = p
	sistema.navegacao = nav
	root.add_child(sistema)
	var avisos: Array[String] = []
	sistema.aviso.connect(func(t: String): avisos.append(t))
	d.vagas[3] = ""
	p.ouro = 1000
	for m: Dictionary in d.membros.values(): m.fome = 150
	var n: Dictionary = sistema.necessidades()
	ok(n.comida == 0 and n.madeira == 3, "orçamento não cobra alimentação dos companheiros")
	sistema.servir_cargos()
	ok(p.ouro == 997 and int(d.estoque.get("pao", 0)) == 0, "somente reparos são cobrados")
	ok(d.membros.values().all(func(m): return not m.has("fome")), "companheiros guardados também dispensam fome")
	ok(barco.health == 100 and p.madeira == 0, "construtor compra três madeiras e repara setenta e cinco HP")
	ok(avisos.any(func(t): return "3 moedas" in t), "gasto direto avisa o jogador")
	sistema.servir_cargos()
	ok(p.ouro == 997 and int(d.estoque.get("pao", 0)) == 0, "serviço repetido não cobra necessidades já atendidas")
	d.estoque = {"refeicao": 4}
	ok(sistema.necessidades().comida == 0, "nutrição das refeições reduz compras de pão")
	d.gasto_direto = P.GASTO_DIRETO_MAX_DIA
	ok(not P.pagar(p, 1), "teto diário de gasto direto respeitado")
	P.avancar(p, 1)
	ok(P.pagar(p, 1), "novo dia renova teto")
	P.atribuir(p, ids[3], 3)
	d.reserva = 0
	d.estoque = {}
	barco.health = 25 # Ainda há reparo real a financiar, mesmo sem fome dos membros.
	var ouro := p.ouro
	var pedidos := avisos.size()
	sistema.servir_cargos()
	ok(p.ouro == ouro and avisos.size() == pedidos + 1, "estoquista sem reserva pede depósito sem sacar ouro")
	sistema.servir_cargos()
	ok(avisos.size() == pedidos + 1, "pedido não repete no mesmo dia")
	P.depositar(p, 100)
	sistema.servir_cargos()
	ok(d.reserva == 97 and int(d.estoque.get("pao", 0)) == 0, "depósito paga reparo, sem compras de comida")
	P.avancar(p, 1)
	var antes := avisos.size()
	sistema.servir_cargos()
	ok(avisos.size() == antes, "saldo suficiente evita novo pedido")
	d.membros[ids[5]].vida = 1
	ok(sistema.necessidades().saude == 2, "orçamento médico conta doses para estabilizar, sem cobrar regeneração natural")
	d.membros[ids[5]].vida = 100
	# Fonte real do dano no funil: chefe, NPC e jogador são distinguidos.
	var aliado = load("res://src/historia/tripulantes/aliado_da_tripulacao.gd").new()
	aliado.sistema = sistema
	aliado.id = ids[5]
	aliado.set_meta("membro_tripulacao", ids[5])
	root.add_child(aliado)
	aliado.set_physics_process(false)
	var npc := Node3D.new()
	root.add_child(npc)
	CombatResolver.aplicar(aliado, 500, 0, 0, Vector3.ZERO, Vector3.ZERO, 0, 0, false, null, npc)
	ok(aliado.health == 1, "funil identifica dano comum e médico salva")
	aliado.health = 100
	var zona := DamageZone.new()
	zona.caster = npc
	zona.damage = 500
	zona.corpo_a_corpo = false
	root.add_child(zona)
	zona._on_body(aliado)
	ok(aliado.health == 1, "médico recebe autor também da hitbox de projétil")
	zona.free()
	var jogador := Node3D.new()
	root.add_child(jogador)
	jogador.add_to_group("player")
	CombatResolver.aplicar(aliado, 500, 0, 0, Vector3.ZERO, Vector3.ZERO, 0, 0, false, jogador)
	ok(aliado.health == 1, "golpe do próprio jogador não mata tripulante")
	npc.add_to_group("chefes")
	CombatResolver.aplicar(aliado, 500, 0, 0, Vector3.ZERO, Vector3.ZERO, 0, 0, false, null, npc)
	ok(d.membros[ids[5]].morto and not Tripulacao.validos([ids[5]], p).has(ids[5]), "boss mata e morto não pode embarcar")
	ok(not aliado.has_meta("dano_de_boss"), "metadados do dano não vazam para o próximo golpe")
	var bandido = load("res://src/historia/tripulantes/aliado_da_tripulacao.gd").new()
	bandido.sistema = sistema
	root.add_child(bandido)
	bandido.set_physics_process(false)
	var vitima := Vitima.new()
	vitima.name = "vitima_roubo"
	root.add_child(vitima)
	d.politica = "roubar"
	ouro = p.ouro
	bandido._crime(vitima, d)
	bandido._crime(vitima, d)
	ok(p.ouro == ouro + 5 and d.vitimas.size() == 1, "roubo paga uma vez por vítima")
	var capturado := Vitima.new()
	capturado.name = "vitima_captura"
	root.add_child(capturado)
	d.politica = "escravizar"
	bandido._crime(capturado, d)
	ok(capturado.get_meta("escravizado", false) and d.vitimas.vitima_captura == "escravizar", "comandante registra NPC capturado")
	var morto := Vitima.new()
	morto.name = "vitima_morte"
	root.add_child(morto)
	d.politica = "matar"
	bandido._crime(morto, d)
	ok(not morto.visible and morto.get_meta("morto", false), "comandante maligno executa política de matar")
	var salvo := ProgressaoDoPersonagem.de_dict(p.para_dict())
	ok(P.estado(salvo).vitimas == d.vitimas and P.estado(salvo).reserva == d.reserva, "reserva e vítimas sobrevivem ao reload")
	for no in [sistema, nav, barco, jogador, npc, bandido, vitima, capturado, morto]: no.free()
	await process_frame
	print("RESULTADO ECONOMIA: %d checks, %d falhas" % [total, falhas])
	quit(1 if falhas else 0)
