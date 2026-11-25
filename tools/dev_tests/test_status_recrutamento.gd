extends SceneTree
## Integração pela campanha isolada: estoque, entrada, derrota real, persistência e energia.
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const SAVE := "user://test_status_recrutamento.json"
var falhas := 0
var total := 0
class AlvoTeste extends Node3D:
	var recebido := 0.0
	func take_damage(dano: float, _de: Vector3, _kb: Vector3, _stun: float) -> void:
		recebido += dano
func _init() -> void: executar.call_deferred()
func ok(sim: bool, mensagem: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + mensagem)
func frames(n: int) -> void:
	for i in n: await physics_frame
func tecla(hud: Node, codigo: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = true
	hud._input(e)
func executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await frames(120)
	var cena: Node = current_scene
	var j: Node3D = cena.jogador_local()
	var p: ProgressaoDoPersonagem = cena.progressao
	var hud: Node = cena.get("_hud")
	var sistema: Node = cena.get_node("Sobrevivencia")
	var r: Node = cena.get_node("Recrutamento")
	ok(j != null and r != null, "campanha monta com recrutamento")
	if j == null or r == null: quit(1); return
	j.set_meta("damage_immune", true)
	var regras := load("res://src/historia/atributos_mine_piece.gd")
	# Atributos DERIVADOS do nível (PlayerPhysicalAbility do mod; A6, 26/10/2026): sem pontos nem tetos de ponto.
	var limites := ProgressaoDoPersonagem.new()
	limites.nivel = 60
	ok(limites.hp_maximo() == 60 and regras.bonus_fisico(60) == 105 and regras.armadura(60) == 30, "nível 60: 60 HP (Aumento de Vida IX), Força 35 níveis (+105) e armadura 30")
	var antigo := ProgressaoDoPersonagem.new()
	antigo.nivel = 10
	var cru := antigo.para_dict()
	cru["atributos"] = {"vida": 40, "forca": 99}
	cru["pontos"] = 999
	var migrado := ProgressaoDoPersonagem.de_dict(cru)
	ok(migrado.hp_maximo() == regras.hp_maximo(10), "save antigo: atributos e pontos gravados são ignorados, a vida vem do nível")
	ok(is_equal_approx(regras.dano_recebido(10, 30), 0.4), "nível 30: armadura 30 + tenacidade 15 + Resistência IV (10 → 0,4)")
	p.nivel = 4
	p.mudou.emit()
	var vitima := AlvoTeste.new()
	cena.add_child(vitima)
	CombatResolver.aplicar(vitima, 7, 0, 0, j.global_position, Vector3.ZERO, 0, 0, false, j)
	ok(is_equal_approx(vitima.recebido, 7.0 + regras.bonus_fisico(4)), "dano físico soma arma 7 + Força do nível 4 (+12) pelo funil real")
	vitima.recebido = 0
	CombatResolver.aplicar(vitima, 7, 0, 0, j.global_position, Vector3.ZERO, 0, 0, false, null, j)
	ok(is_equal_approx(vitima.recebido, 7), "bônus físico não vaza para fruta")
	j.remove_meta("damage_immune")
	j.health = j.max_health
	j.take_damage(10)
	ok(is_equal_approx(j.health, j.max_health - regras.dano_recebido(10, 4)), "armadura e Resistência do nível reduzem o dano no Player real")
	j.set_meta("damage_immune", true)
	p.nivel = 1
	p.mudou.emit()
	vitima.queue_free()
	# Água sempre antes da comida (18/10/2026).
	ok(p.itens_da_barra() == ["luta", "agua", "comida", "pokebola", "bandeira"], "um item → água 2, comida 3, pokébola 4, bandeira 5")
	p.ganhar_equipamento("espada")        # o personagem novo só começa com as lâminas do Epic Fight
	p.equipar_espada(true)
	ok(p.itens_da_barra() == ["luta", "espada", "agua", "comida", "pokebola", "bandeira"], "dois itens → água 3, comida 4, pokébola 5, bandeira 6")
	p.equipar_espada(false)
	P.guardar(p, "agua_potavel", 2)
	P.estado(p).sede = 100
	tecla(hud, KEY_1 + p.slot_da_barra("agua"))        # a hotbar do inventário tem slots fixos por item (água no 6), não mais "água = 2"
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_RIGHT
	mouse.pressed = true
	hud._input(mouse)
	ok(P.quantidade_agua(p) == 1 and P.estado(p).sede > 100, "água (slot da barra): botão direito bebe exatamente uma")
	mouse.pressed = false
	hud._input(mouse)
	P.guardar(p, "pao", 3)
	P.estado(p).fome = 100
	tecla(hud, KEY_1 + p.slot_da_barra("comida"))
	mouse.pressed = true
	hud._input(mouse)
	ok(P.quantidade_comida(p) == 2 and P.estado(p).fome > 100, "botão direito consome exatamente um pão")
	mouse.pressed = false
	hud._input(mouse)
	ok(P.quantidade_comida(p) == 2, "soltar o botão não consome de novo")
	P.estado(p).estoque.clear()
	mouse.pressed = true
	hud._input(mouse)
	ok(P.quantidade_comida(p) == 0, "estoque vazio não fica negativo")
	p.recrutados.nami = true
	P.adicionar(p, "humano_nami")
	P.estado(p).membros.humano_nami.fome = 0
	P.estado(p).membros.humano_nami.vida = 50
	sistema.avancar(0.001)
	ok(float(P.estado(p).membros.humano_nami.vida) > 50, "companheiro regenera mesmo com fome antiga zerada")
	ok(not P.estado(p).membros.humano_nami.has("fome") and sistema.necessidades().comida == 0, "migração remove fome e despesas dos companheiros")
	var bib := MapaMontador.biblioteca_em_uso()
	var inimigo := InimigoDoMapa.new()
	inimigo.set_meta("modelo_recrutavel", "mp_luffy")
	# Usa o primeiro modelo real do East Blue, sem depender de grafia no catálogo.
	# Chefe do mod só finaliza (ficha.chefe): o teste de recrutar usa o primeiro que NÃO é chefe.
	var ficha: Dictionary = {}
	for id_ficha: Variant in DadosEastBlue.ids():
		if not bool(DadosEastBlue.ficha(str(id_ficha)).get("chefe", false)):
			ficha = DadosEastBlue.ficha(str(id_ficha))
			break
	inimigo.set_meta("modelo_recrutavel", str(ficha.modelo))
	cena.add_child(inimigo)
	j.global_position = Vector3(0, 1, 0)
	inimigo.global_position = j.global_position + Vector3(0, 0, -2)
	var mortes := [0]
	inimigo.derrotado.connect(func(_n): mortes[0] += 1)
	# 30/10/2026: o F saiu; recruta quem a pokébola captura com a vida vermelha (`Recrutamento.capturar`).
	ProbabilidadeDeCaptura.sorteio_fixo = 0.99999       # 08/11/2026: a pokébola SORTEIA (raridade × vida); aqui o sorteio é ruim
	ok(r.tentar(inimigo)["resultado"] == r.Resultado.ESCAPOU and mortes[0] == 0, "vida cheia com sorteio ruim: escapou e ele segue vivo")
	ProbabilidadeDeCaptura.sorteio_fixo = -1.0
	inimigo.health = inimigo.max_health * 0.2
	ok(r.capturar(inimigo) == r.Resultado.CAPTURADO, "vida vermelha: capturado")
	await frames(2)
	ok(mortes[0] == 1 and not inimigo.visible, "o corpo sai pela morte normal, uma vez")
	ok(Tripulacao.disponiveis(p, bib).any(func(a): return a.id.begins_with("humano_recruta_")), "recrutado aparece na tripulação")
	ok(is_instance_valid(sistema.corpos.get("humano_recruta_1")), "recrutado ocupa cargo e nasce como aliado")
	var salvo := ProgressaoDoPersonagem.de_dict(p.para_dict())
	ok(not Tripulacao.aliado(salvo, bib, "humano_recruta_1").is_empty(), "recrutamento persiste no save")
	var visual := TripulanteHumano.new()
	cena.add_child(visual)
	visual.montar("recruta_1", bib, Tripulacao.ficha_recrutada(salvo, "recruta_1"))
	ok(visual.corpo() != null and visual.corpo().get_child_count() > 0, "recrutado monta visual também para bordo")
	visual.queue_free()
	inimigo._renascer()
	CombatResolver.aplicar(inimigo, 99999, 0, 0, j.global_position, Vector3.ZERO, 0, 0, false, j)
	await frames(2)
	ok(mortes[0] == 2 and p.dados_de("recrutas").sequencia == 1 and not inimigo.get_meta("aguardando_recrutamento", false), "derrotado de verdade morre direto, sem recrutar")
	# Animal real, pelo mesmo funil de dano, entra no sistema de pets da tripulação.
	var vaca := AnimalDaIlha.new()
	vaca.montar(bib, "cow", FichaDeAnimal.normalizar(bib.ficha_de_animal("cow")), {"especie": "cow", "base": Basis(), "centro": Vector3.ZERO, "meio": Vector3(4, 1, 4)})
	cena.add_child(vaca)
	vaca.global_position = j.global_position + Vector3(2, 0, 0)
	vaca.alvo = null
	vaca.health = vaca.max_health * 0.2
	ok(r.capturar(vaca) == r.Resultado.CAPTURADO, "animal com a vida vermelha é capturado")
	await frames(2)
	ok(Tripulacao.disponiveis(p, bib).any(func(a): return a.especie == "cow" and P.estado(p).membros.has(a.id)), "animal capturado entra na tripulação como pet persistente")
	# Personagem Mine Piece real mantém o modelo e torna-se aliado persistente.
	var pers := PersonagemMinePiece.new()
	cena.add_child(pers)
	pers.montar(ficha, str(ficha.modelo))
	pers.global_position = j.global_position + Vector3(-2, 0, 0)
	pers.health = pers.max_health * 0.2
	ok(r.capturar(pers) == r.Resultado.CAPTURADO, "personagem Mine Piece com a vida vermelha é capturado")
	await frames(2)
	ok(not Tripulacao.ficha_recrutada(p, "recruta_2").is_empty(), "captura recruta personagem Mine Piece real")
	p.comer_fruta("pika_pika_no_mi_mine_piece")
	p.item_ativo = "fruta"
	p.mudou.emit()
	await frames(10)
	var custo: float = j.custo_de_energia_do_cast("Z")
	j.max_energy = 1
	j.energy = 1
	var tecnicas: Node = hud.get("_tecnicas")
	tecnicas.atualizar(j, true)
	ok(custo > 1 and tecnicas.get("_linhas").Z.cadeado.visible, "custo acima da capacidade mostra cadeado")
	j.begin_charge("Z")
	ok(not j.get("_fruit_cooldowns").has("Z") or float(j.get("_fruit_cooldowns").Z) <= 0, "energia insuficiente não inicia recarga")
	j.max_energy = custo + 10
	j.energy = 0
	tecnicas.atualizar(j, true)
	ok(not tecnicas.get("_linhas").Z.cadeado.visible and "sem energia" in tecnicas.texto_da_linha("Z"), "capacidade suficiente sem carga não usa cadeado")
	ok(is_equal_approx(j.custo_de_energia_do_cast("Z"), custo), "investir em Energia não aumenta custo da skill")
	print("RESULTADO STATUS_RECRUTAMENTO: %d checks, %d falhas" % [total, falhas])
	quit(1 if falhas else 0)
