extends SceneTree
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const Missoes := preload("res://src/historia/missoes/missoes.gd")
var falhas := 0
var checks := 0
func _init() -> void: executar.call_deferred()
func ok(condicao: bool, nome: String) -> void:
	checks += 1
	if not condicao:
		falhas += 1
		push_error("FALHOU: " + nome)
	else: print("OK: " + nome)
func executar() -> void:
	await process_frame
	var p := ProgressaoDoPersonagem.new()
	var d := P.estado(p)
	ok(d.fome == 200.0 and d.sede == 300.0, "capacidades iniciais")
	ok(not P.avancar(p, 3.99) and d.sede > 0, "vivo antes de quatro dias")
	ok(P.avancar(p, 0.01) and d.sede == 0, "sede zero em quatro dias exatos")
	d.sede = 300.0
	d.fome = 200.0
	for i in 4000: P.avancar(p, 0.001)
	ok(d.sede == 0 and d.fome == 0, "quatro dias repartidos em passos zeram fome e sede")
	p.ouro = 10
	ok(not P.comprar(p, "agua_do_mar") and p.ouro == 10, "água não potável não é consumível")
	ok(P.comprar(p, "agua_potavel") and p.ouro == 9, "compra debita uma vez")
	ok(P.consumir(p, "agua_potavel") and d.sede == 75, "beber restaura 75 de sede")
	ok(not P.consumir(p, "agua_potavel"), "não bebe sem estoque")
	ok(not P.comprar(p, "pao", -1) and not P.comprar(p, "pao", 20), "compras inválidas não debitam")
	var dono := Node.new()
	root.add_child(dono)
	var vida := HealthController.new()
	vida.montar_em(dono)
	vida.vida = 10; vida.energia = 10
	dono.set_meta("fome", 0.0)
	vida.regenerar(10)
	ok(vida.vida == 10 and vida.energia == 10, "fome zero interrompe ambas as regenerações")
	dono.set_meta("fome", 1.0)
	vida.regenerar(10)
	ok(vida.vida > 10 and vida.energia > 10, "comida libera regeneração")
	dono.free()
	p = ProgressaoDoPersonagem.new()
	# 20/11/2026: a cadeia da vara (vara → peixe raro → ferraria → facção/60 pães) saiu do jogo; os testes dela estão em `aposentados/missoes_antigas/`.
	ok(p.estado_da_missao("vara_inicial") == "disponivel" and p.estado_da_missao("treino") == "disponivel" and not p.equipamentos.has("machado"), "nova campanha: sem missão da vara, treino disponível, sem machado")
	ok(not P.estado(p).estoque.has("pao") or int(P.estado(p).estoque.get("pao", 0)) == 0, "sem a facção, a campanha não começa com os 60 pães")
	var salvo := ProgressaoDoPersonagem.de_dict(p.para_dict())
	ok(salvo.estado_da_missao("treino") == "disponivel", "o save de uma campanha nova preserva o treino disponível")
	p = ProgressaoDoPersonagem.new()
	for id in CatalogoDeTripulantes.ids():
		p.recrutados[id] = true
		P.adicionar(p, Tripulacao.id_do_humano(id))
	for i in 10:
		var pet_id := p.adicionar_pet("caranguejo", "Tripulante %d" % i)
		P.adicionar(p, pet_id)
	d = P.estado(p)
	ok(d.membros.size() == 16, "limite dezesseis membros")
	ok(not P.adicionar(p, "intruso"), "não adiciona NPC sem recrutar")
	var ids: Array = d.membros.keys()
	for i in 6: ok(P.atribuir(p, str(ids[i]), i), "atribuição vaga %d" % i)
	P.atribuir(p, str(ids[0]), 5)
	ok(d.vagas.count(ids[0]) == 1 and d.vagas[0] == "", "arrastar entre cargos não duplica membro")
	P.atribuir(p, str(ids[0]), 0)
	P.atribuir(p, str(ids[5]), 5)
	p.ouro = 100
	ok(P.depositar(p, 20) and p.ouro == 80 and d.reserva == 20, "depósito de reserva")
	ok(P.pagar(p, 10) and d.reserva == 10 and p.ouro == 80, "estoquista usa reserva")
	ok(not P.pagar(p, 11) and p.ouro == 80, "estoquista não retira dinheiro sem depósito")
	var controle := preload("res://src/historia/tripulantes/sobrevivencia.gd").new()
	controle.progressao = p
	root.add_child(controle)
	for m: Dictionary in d.membros.values(): m.fome = 125
	controle.servir_cargos()
	ok(p.ouro == 80 and d.reserva >= 0, "abastecimento respeita orçamento")
	var corpo := preload("res://src/historia/tripulantes/aliado_da_tripulacao.gd").new()
	corpo.id = ids[5]
	corpo.sistema = controle
	corpo.set_meta("membro_tripulacao", ids[5])
	corpo.set_meta("dano_de_npc", true)
	root.add_child(corpo)
	corpo.set_physics_process(false)
	corpo.take_damage(500)
	ok(corpo.health == 1, "médico impede morte por NPC")
	corpo.set_meta("dano_de_boss", true)
	corpo.take_damage(500)
	ok(d.membros[ids[5]].morto, "boss ignora médico")
	var menu := MenuDeComportamento.new()
	root.add_child(menu)
	menu.ligar(p, controle)
	menu.abrir_tripulacao()
	ok(menu.get("_vagas").get_child_count() == 6, "menu apresenta seis cargos")
	var cell: Control = menu.get("_vagas").get_child(0).get_child(1)
	ok(cell._can_drop_data(Vector2.ZERO, {"tripulante": ids[6]}), "drag real aceita membro")
	cell._drop_data(Vector2.ZERO, {"tripulante": ids[6]})
	ok(d.vagas[0] == ids[6], "drop atualiza cargo")
	menu.free()
	controle.free()
	await process_frame
	print("RESULTADO: %d checks, %d falhas" % [checks, falhas])
	quit(1 if falhas else 0)
