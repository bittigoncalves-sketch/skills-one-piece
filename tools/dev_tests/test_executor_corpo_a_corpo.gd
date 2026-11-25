extends SceneTree
# ============================================================================
#  TESTE DO EXECUTOR DO COMBATE DIRECIONAL — sem Player, sem cena, sem tela.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 1. Prova o contrato do executor
#  com um ator falso: fases derivadas de um relógio só, sinais em ordem mesmo com
#  quadro longo, buffer de UMA posição só no fim da recuperação, cancelamento por
#  identidade e travas do ator.
#
#  ⚠️ Toda trava tem CONTROLE POSITIVO: o mesmo gesto, sem a trava, precisa
#  funcionar — senão "não aconteceu" passaria também com um teste que não sabe
#  disparar nada.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_executor_corpo_a_corpo.gd
# ============================================================================

const ESTILO := "res://src/combat/direcional/estilos/boxe.tres"
const DT := 1.0 / 60.0

var _falhas := 0
var _criados: Array[Node] = []   # executores fora da árvore: liberados no fim


class AtorFalso extends AtorDeCombate:
	## false = preso por trava dura (derrubado, congelado, morto): cancela o que estiver em curso.
	var livre := true
	## true = atordoado pelo dano (o "Stunned" do Player): cancela, menos o golpe que trocou no ATIVO.
	var atordoado := false
	## false = quem decide está travado (menu, sem capacidade): só impede começar.
	var pode := true

	func pode_iniciar() -> bool:
		return not impedido() and pode

	func impedido(contar_atordoamento := true) -> bool:
		return not livre or (contar_atordoamento and atordoado)


## Registra os sinais de um executor, na ordem em que chegaram.
class Gravador extends RefCounted:
	var eventos := []

	func ligar(e: ExecutorCorpoACorpo) -> void:
		e.golpe_iniciado.connect(func(g, id): eventos.append("inicio:%s:%d" % [g.id, id]))
		e.fase_mudou.connect(func(id, f): eventos.append("fase:%s:%d" % [GolpeDirecional.Fase.keys()[f], id]))
		e.golpe_encerrado.connect(func(id, m): eventos.append("fim:%s:%d" % [m, id]))

	func contar(prefixo: String) -> int:
		return eventos.filter(func(ev): return ev.begins_with(prefixo)).size()


func _init() -> void:
	await process_frame
	print("\n===== EXECUTOR DO COMBATE DIRECIONAL =====")
	var estilo := load(ESTILO) as EstiloCorpoACorpo
	_ok(estilo != null, "o estilo de boxe carrega (%s)" % ESTILO)
	if estilo != null:
		_dados(estilo)
		_fases(estilo)
		_quadro_longo(estilo)
		_buffer(estilo)
		_spam(estilo)
		_cancelamento(estilo)
		_travas_do_ator(estilo)
		_corpo(estilo)
		_guarda(estilo)
		_quebra_e_postura(estilo)
		_invariantes(estilo)
		_aparo_riposte_finta(estilo)
		_troca_no_ativo(estilo)
	for n in _criados:
		n.free()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _novo(estilo: EstiloCorpoACorpo) -> Array:
	var ator := AtorFalso.new()
	var e := ExecutorCorpoACorpo.new()
	_criados.append(e)
	e.montar(ator, estilo)
	var grav := Gravador.new()
	grav.ligar(e)
	return [e, ator, grav]


## Avança em passos de DT até `condicao` valer ou `limite` segundos passarem.
## Devolve o tempo decorrido.
func _ate(e: ExecutorCorpoACorpo, condicao: Callable, limite: float = 3.0) -> float:
	var t := 0.0
	while not condicao.call() and t < limite:
		e.avancar(DT)
		t += DT
	return t


# ------------------------------------------------------------------ dados
func _dados(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 1. a ficha do estilo --")
	var erros := estilo.validar()
	_ok(erros.is_empty(), "boxe.tres é válido %s" % str(erros))
	for d in GolpeDirecional.DIRECOES_BASE:          # as 4 do gesto; os encaixes extras (AUTO_4/NO_AR/CORRIDA) são opcionais
		var g := estilo.golpe_para(d)
		_ok(g != null, "há golpe para %s (%s)" % [GolpeDirecional.Direcao.keys()[d], g.id if g else "-"])

	# A validação precisa SABER reprovar: tira um golpe e exige erro.
	var quebrado := estilo.duplicate() as EstiloCorpoACorpo
	quebrado.golpes = estilo.golpes.slice(1)
	_ok(not quebrado.validar().is_empty(), "controle: estilo sem uma direção é recusado")


# ------------------------------------------------------------------ fases
func _fases(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 2. as fases saem do relógio da ficha --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var grav: Gravador = par[2]
	var g := estilo.golpe_para(GolpeDirecional.Direcao.FRENTE)

	_ok(e.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "pedido no neutro começa o golpe")
	_ok(e.estado == ExecutorCorpoACorpo.Estado.PREPARO and e.golpe_atual == g and e.id_acao == 1,
		"entra em PREPARO com o golpe da frente, ação #1")
	_ok(e.atacando() and e.em_preparo() and e.ocupado(), "consultas públicas batem com o estado")

	var t_ativo := _ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	_ok(absf(t_ativo - g.preparo) <= DT + 0.0001, "ATIVO começa no fim do preparo (%.3f s, ficha %.2f)" % [t_ativo, g.preparo])
	var t_rec := t_ativo + _ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.RECUPERACAO)
	_ok(absf(t_rec - (g.preparo + g.ativo)) <= DT + 0.0001, "RECUPERAÇÃO começa depois do ativo (%.3f s)" % t_rec)
	var t_fim := t_rec + _ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.NEUTRO)
	_ok(absf(t_fim - g.duracao()) <= DT + 0.0001, "volta ao NEUTRO na duração da ficha (%.3f s, ficha %.2f)" % [t_fim, g.duracao()])
	_ok(not e.atacando() and e.golpe_atual == null and not e.golpe_valido(1), "neutro não tem golpe válido")
	_ok(grav.eventos == ["inicio:boxe_jab:1", "fase:PREPARO:1", "fase:ATIVO:1", "fase:RECUPERACAO:1", "fase:FIM:1", "fim:fim:1"],
		"sinais na ordem: %s" % str(grav.eventos))


func _quadro_longo(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 3. um quadro longo não engole fase --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var grav: Gravador = par[2]
	var g := estilo.golpe_para(GolpeDirecional.Direcao.DE_CIMA)
	e.pedir_ataque(GolpeDirecional.Direcao.DE_CIMA)
	e.avancar(g.preparo + g.ativo + 0.01)
	_ok(e.estado == ExecutorCorpoACorpo.Estado.RECUPERACAO, "um salto que passa do ativo cai na recuperação")
	_ok(grav.contar("fase:ATIVO") == 1 and grav.eventos.find("fase:ATIVO:1") < grav.eventos.find("fase:RECUPERACAO:1"),
		"o ATIVO foi avisado, e antes da recuperação: %s" % str(grav.eventos))


# ----------------------------------------------------------------- buffer
func _buffer(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 4. buffer: uma posição, só no fim da recuperação --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var grav: Gravador = par[2]
	# O golpe de recuperação mais longa: o buffer do boxe (0,30 s) cobre a recuperação
	# INTEIRA do jab, e o descarte do clique cedo precisa de onde acontecer.
	var g: GolpeDirecional = estilo.golpes[0]
	for candidato in estilo.golpes:
		if candidato.recuperacao > g.recuperacao:
			g = candidato
	_ok(g.recuperacao > estilo.buffer, "(preparação) %s tem recuperação %.2f s > buffer %.2f s" % [g.id, g.recuperacao, estilo.buffer])
	e.pedir_ataque(g.direcao)

	_ok(not e.pedir_ataque(g.direcao), "no PREPARO o clique na mesma direção é recusado")
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	_ok(not e.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "no ATIVO o clique é recusado")
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.RECUPERACAO)
	_ok(not e.pedir_ataque(GolpeDirecional.Direcao.FRENTE) and not e.tem_buffer(),
		"no começo da recuperação o clique é descartado, não guardado")

	_ate(e, func(): return g.duracao() - e.tempo_da_acao() <= estilo.buffer * 0.5)
	_ok(e.pedir_ataque(GolpeDirecional.Direcao.PARA_DIREITA) and e.tem_buffer(), "no fim da recuperação o clique fica guardado")
	_ok(e.pedir_ataque(GolpeDirecional.Direcao.PARA_ESQUERDA) and e.tem_buffer(), "um segundo clique substitui, não soma")
	_ate(e, func(): return e.id_acao == 2)
	_ok(e.estado == ExecutorCorpoACorpo.Estado.PREPARO and e.golpe_atual != null
		and e.golpe_atual.direcao == GolpeDirecional.Direcao.PARA_ESQUERDA,
		"o guardado sai sozinho, com a direção MAIS RECENTE")
	_ok(grav.contar("inicio:") == 2 and not e.tem_buffer(), "exatamente um golpe a mais, e o buffer esvazia")


func _spam(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 5. spam não paga --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var grav: Gravador = par[2]
	var t := 0.0
	var cliques := 0
	while t < 1.0:
		e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
		cliques += 1
		e.avancar(DT)
		t += DT
	var menor := INF
	for g in estilo.golpes:
		menor = minf(menor, g.duracao())
	var teto := int(floor(1.0 / menor)) + 1
	var golpes := grav.contar("inicio:")
	_ok(golpes <= teto, "%d cliques em 1 s viram %d golpe(s); teto teórico %d" % [cliques, golpes, teto])
	_ok(golpes >= 2, "controle: clicar sem parar ainda encadeia pelo buffer (%d golpes)" % golpes)


# ----------------------------------------------------------- cancelamento
func _cancelamento(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 6. cancelar troca a identidade --")
	var g := estilo.golpe_para(GolpeDirecional.Direcao.FRENTE)

	# Controle: sem cancelar, o ativo chega.
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var grav: Gravador = par[2]
	e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	_ate(e, func(): return e.tempo_da_acao() >= g.preparo * 0.5)
	_ate(e, func(): return false, g.preparo)
	_ok(grav.contar("fase:ATIVO") == 1, "controle: sem cancelar, o ATIVO chega")

	par = _novo(estilo)
	e = par[0]
	grav = par[2]
	e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	_ate(e, func(): return e.tempo_da_acao() >= g.preparo * 0.5)
	var id_velho := e.id_acao
	e.cancelar(&"teste")
	_ok(e.estado == ExecutorCorpoACorpo.Estado.NEUTRO and e.id_acao != id_velho,
		"cancelar volta ao NEUTRO e troca o id (%d → %d)" % [id_velho, e.id_acao])
	_ok(not e.golpe_valido(id_velho), "o id velho deixa de valer")
	_ate(e, func(): return false, g.preparo)
	_ok(grav.contar("fase:ATIVO") == 0, "depois de cancelado, o ATIVO nunca chega")
	_ok(grav.eventos.back() == "fim:teste:%d" % id_velho, "o encerramento diz o motivo (%s)" % grav.eventos.back())

	# Cancelar com clique guardado: o guardado morre junto.
	e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	var no_fim_da_recuperacao := func() -> bool:
		return e.estado == ExecutorCorpoACorpo.Estado.RECUPERACAO and g.duracao() - e.tempo_da_acao() <= estilo.buffer * 0.5
	_ate(e, no_fim_da_recuperacao)
	e.pedir_ataque(GolpeDirecional.Direcao.FRENTE)
	_ok(e.tem_buffer(), "(preparação) há um clique guardado")
	var inicios := grav.contar("inicio:")
	e.cancelar(&"teste")
	_ate(e, func(): return false, 0.5)
	_ok(not e.tem_buffer() and grav.contar("inicio:") == inicios, "cancelar descarta o clique guardado")


# ------------------------------------------------------------ travas do ator
func _travas_do_ator(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 7. travas do ator --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var ator: AtorFalso = par[1]
	var grav: Gravador = par[2]

	ator.pode = false
	_ok(not e.pedir_ataque(GolpeDirecional.Direcao.FRENTE) and not e.ocupado(), "sem poder iniciar (menu, capacidade), não começa")
	ator.pode = true
	_ok(e.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "controle: liberado, o mesmo pedido começa")

	ator.pode = false   # abrir o menu NO MEIO do golpe
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	_ok(e.estado == ExecutorCorpoACorpo.Estado.ATIVO, "menu aberto no meio do golpe NÃO o cancela (compromisso)")
	ator.pode = true

	ator.livre = false  # atordoado no meio do golpe
	e.avancar(DT)
	_ok(e.estado == ExecutorCorpoACorpo.Estado.NEUTRO and grav.eventos.back().begins_with("fim:impedido"),
		"corpo preso cancela o golpe (%s)" % grav.eventos.back())
	_ok(not e.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "preso, não começa outro")
	ator.livre = true


# ------------------------------------------------------------------- corpo
func _corpo(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 8. o corpo durante o golpe --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var g := estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA)
	_ok(e.fator_de_movimento() == 1.0 and is_inf(e.giro_maximo()), "no neutro: movimento inteiro, giro livre")
	e.pedir_ataque(GolpeDirecional.Direcao.PARA_ESQUERDA)
	_ok(is_equal_approx(e.fator_de_movimento(), g.fator_movimento_preparo)
		and is_equal_approx(e.giro_maximo(), deg_to_rad(g.giro_max_preparo)), "no preparo: valores da ficha")
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	_ok(is_equal_approx(e.fator_de_movimento(), g.fator_movimento_ativo)
		and is_equal_approx(e.giro_maximo(), deg_to_rad(g.giro_max_ativo)), "no ativo: valores da ficha")
	_ok(e.fator_de_movimento() > 0.0, "atacar nunca zera o movimento por padrão (×%.2f)" % e.fator_de_movimento())


# -------------------------------------------------------------------- guarda
func _guarda(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 9. guarda: pedir, baixar, voltar --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var E := ExecutorCorpoACorpo.Estado

	e.erguer_guarda()
	_ok(e.estado == E.GUARDA and e.em_guarda(), "erguer no neutro: GUARDA na hora")
	_ok(is_equal_approx(e.fator_de_movimento(), estilo.fator_movimento_guarda), "em guarda anda ×%.2f (ficha)" % e.fator_de_movimento())
	e.baixar_guarda()
	_ok(e.estado == E.BAIXANDO, "soltar: BAIXANDO")
	e.erguer_guarda()   # re-apertar logo em seguida
	_ok(e.estado == E.BAIXANDO, "re-apertar durante BAIXANDO não ergue de volta na hora")
	var t := _ate(e, func(): return e.estado == E.GUARDA, 1.0)
	_ok(e.estado == E.GUARDA and absf(t - estilo.baixar_guarda) <= DT + 0.0001,
		"a guarda só volta quando BAIXANDO acaba (%.3f s; ficha %.2f)" % [t, estilo.baixar_guarda])

	e.baixar_guarda()
	_ate(e, func(): return e.estado == E.NEUTRO, 1.0)
	_ok(e.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "(preparação) golpe começou")
	# Passada a janela de finta, o aperto novo já não interrompe (dentro dela é finta —
	# coberto na seção 12).
	var g_prep := e.golpe_atual
	_ate(e, func(): return e.tempo_da_acao() > g_prep.preparo * estilo.janela_de_finta)
	e.erguer_guarda()
	_ok(e.estado == E.PREPARO, "guarda pedida DEPOIS da janela de finta não interrompe o golpe")
	var g := e.golpe_atual
	var liberada := g.preparo + g.ativo + g.recuperacao * estilo.guarda_liberada_na_recuperacao
	_ate(e, func(): return e.estado == E.RECUPERACAO)
	_ok(e.estado == E.RECUPERACAO, "no começo da recuperação a guarda pedida ainda espera")
	var t2 := _ate(e, func(): return e.estado == E.GUARDA, 1.0)
	var instante := g.preparo + g.ativo + t2
	_ok(e.estado == E.GUARDA and absf(instante - liberada) <= 2.0 * DT,
		"a guarda interrompe a recuperação a partir de %d%% dela (entrou em %.3f s; liberada %.3f s)"
		% [int(estilo.guarda_liberada_na_recuperacao * 100), instante, liberada])

	# A guarda tirou o corpo do golpe mais cedo, mas a recuperação dele ainda corre: o
	# clique fica guardado e só sai quando ela acaba (portão de game feel, 16/09).
	var t_guarda := g.preparo + g.ativo + t2
	_ok(e.pedir_ataque(GolpeDirecional.Direcao.PARA_ESQUERDA) and e.estado == E.GUARDA and e.tem_buffer(),
		"da guarda recém-saída de um golpe, o clique espera o resto da recuperação (guardado)")
	var t3 := _ate(e, func(): return e.estado == E.PREPARO, 1.0)
	_ok(e.estado == E.PREPARO and absf(t_guarda + t3 - g.duracao()) <= 2.0 * DT,
		"e sai quando a recuperação original acaba (%.3f s; golpe dura %.3f s)" % [t_guarda + t3, g.duracao()])
	var fresca := _novo(estilo)
	(fresca[0] as ExecutorCorpoACorpo).erguer_guarda()
	_ok((fresca[0] as ExecutorCorpoACorpo).pedir_ataque(GolpeDirecional.Direcao.FRENTE)
		and (fresca[0] as ExecutorCorpoACorpo).estado == E.PREPARO, "da GUARDA sem golpe pendente se ataca direto")
	_ate(e, func(): return not e.atacando(), 2.0)
	_ok(e.estado == E.GUARDA, "guarda ainda pedida: ao fim do golpe o corpo volta sozinho para a GUARDA")

	par = _novo(estilo)
	e = par[0]
	var ator: AtorFalso = par[1]
	e.erguer_guarda()
	ator.livre = false
	e.avancar(DT)
	_ok(e.estado == E.NEUTRO, "corpo preso (atordoado por fora) larga a guarda")
	ator.livre = true
	e.avancar(DT)
	_ok(e.estado == E.GUARDA, "controle: solto, com a guarda ainda pedida, ela volta")


func _quebra_e_postura(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 10. postura e quebra de guarda --")
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var E := ExecutorCorpoACorpo.Estado
	var hook := estilo.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA)
	_ok(is_equal_approx(e.postura, estilo.postura_maxima), "nasce com a postura cheia (%.0f)" % e.postura)

	e.erguer_guarda()
	e.receber_bloqueio(hook)
	_ok(is_equal_approx(e.postura, estilo.postura_maxima - hook.dano_de_postura), "bloquear tira o dano de postura do golpe (%.0f)" % e.postura)
	_ate(e, func(): return false, estilo.postura_atraso * 0.8)
	_ok(is_equal_approx(e.postura, estilo.postura_maxima - hook.dano_de_postura), "antes do atraso a postura não sobe")
	_ate(e, func(): return false, estilo.postura_atraso * 0.2 + 1.0)
	_ok(e.postura > estilo.postura_maxima - hook.dano_de_postura, "depois do atraso ela regenera (%.1f)" % e.postura)
	_ate(e, func(): return false, 5.0)
	_ok(is_equal_approx(e.postura, estilo.postura_maxima), "e para no máximo")

	e.quebrar_guarda(hook)
	_ok(e.estado == E.QUEBRA and is_equal_approx(e.postura, estilo.postura_apos_quebra),
		"quebra: estado QUEBRA, postura volta a %.0f" % e.postura)
	_ok(not e.pedir_ataque(GolpeDirecional.Direcao.FRENTE), "na quebra não se ataca")
	e.baixar_guarda()
	e.erguer_guarda()
	_ok(e.estado == E.QUEBRA, "na quebra a guarda não sobe")
	_ok(is_equal_approx(e.fator_de_movimento(), estilo.fator_movimento_quebra), "na quebra anda ×%.2f" % e.fator_de_movimento())
	var t := _ate(e, func(): return e.estado != E.QUEBRA, 3.0)
	_ok(absf(t - estilo.duracao_da_quebra) <= DT + 0.0001 and e.estado == E.GUARDA,
		"a quebra dura a ficha (%.3f s) e, com a guarda pedida, o corpo volta a ela" % t)


func _invariantes(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 11. invariantes de jogo nos dados --")
	_ok(estilo.validar().is_empty(), "boxe.tres cumpre os invariantes (§7.5)")
	var quebra_curta := estilo.duplicate() as EstiloCorpoACorpo
	quebra_curta.duracao_da_quebra = 0.2
	_ok(not quebra_curta.validar().is_empty(), "sabotagem: quebra mais curta que o preparo mais rápido é recusada")
	var prende := estilo.duplicate(true) as EstiloCorpoACorpo
	prende.golpes[0].hitstun = 5.0
	_ok(not prende.validar().is_empty(), "sabotagem: hitstun que prende o alvo é recusado")


# ------------------------------------------------------ aparo, riposte, finta
func _aparo_riposte_finta(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 12. aparo, riposte e finta --")
	var E := ExecutorCorpoACorpo.Estado
	var D := GolpeDirecional.Direcao

	# Janela de aparo: conta do aperto, e expira.
	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	e.erguer_guarda()
	_ok(e.aparando(), "aperto novo: janela de aparo aberta")
	var t := _ate(e, func(): return not e.aparando(), 1.0)
	_ok(absf(t - estilo.janela_de_aparo) <= DT + 0.0001 and e.em_guarda(),
		"a janela fecha em %.3f s (ficha %.2f) e a guarda continua" % [t, estilo.janela_de_aparo])

	# Botão segurado: a guarda que volta sozinha depois de um golpe NÃO apara.
	e.pedir_ataque(D.FRENTE)
	_ate(e, func(): return e.em_guarda(), 2.0)
	_ok(e.em_guarda() and not e.aparando(), "guarda que volta sozinha (botão segurado) não abre janela de aparo")

	# Spam: soltar e apertar de novo gasta a janela durante BAIXANDO.
	e.baixar_guarda()
	e.erguer_guarda()
	_ate(e, func(): return e.em_guarda(), 1.0)
	_ok(e.em_guarda() and not e.aparando(),
		"soltar e reapertar: quando a guarda sobe (BAIXANDO %.2f s) a janela (%.2f s) já passou — spam não apara"
		% [estilo.baixar_guarda, estilo.janela_de_aparo])

	# Riposte.
	par = _novo(estilo)
	e = par[0]
	var g := estilo.golpe_para(D.FRENTE)
	e.aparar(g)
	_ok(e.janela_de_riposte_aberta(), "aparar abre a janela de riposte")
	e.pedir_ataque(D.FRENTE)
	_ok(e.golpe_e_riposte() and not e.janela_de_riposte_aberta(), "o golpe seguinte é riposte, e a janela foi usada")
	_ok(not e.pode_fintar(), "riposte não finta")
	var ate_ativo := _ate(e, func(): return e.estado == E.ATIVO, 1.0)
	_ok(absf(ate_ativo - g.preparo * estilo.fator_de_riposte) <= DT + 0.0001,
		"o preparo do riposte dura %.3f s (ficha %.2f × %.1f = %.3f)" % [ate_ativo, g.preparo, estilo.fator_de_riposte, g.preparo * estilo.fator_de_riposte])
	_ate(e, func(): return not e.atacando(), 2.0)
	e.aparar(g)
	_ate(e, func(): return false, estilo.janela_de_riposte + 0.05)
	e.pedir_ataque(D.FRENTE)
	_ok(not e.golpe_e_riposte(), "controle: passada a janela, o golpe é normal")

	# Rebote.
	par = _novo(estilo)
	e = par[0]
	e.pedir_ataque(D.PARA_ESQUERDA)
	e.ser_aparado()
	_ok(e.estado == E.REBATIDO and e.golpe_atual == null, "aparado: REBATIDO, golpe desfeito")
	_ok(not e.pedir_ataque(D.FRENTE), "rebatido não ataca")
	e.erguer_guarda()
	_ok(e.estado == E.REBATIDO, "rebatido não ergue a guarda na hora")
	var t_reb := _ate(e, func(): return e.estado != E.REBATIDO, 1.0)
	_ok(absf(t_reb - estilo.duracao_rebatido) <= DT + 0.0001 and e.em_guarda(),
		"o rebote dura %.3f s (ficha %.2f) e, com a guarda pedida, ela sobe logo depois" % [t_reb, estilo.duracao_rebatido])

	# Finta de golpe para golpe.
	par = _novo(estilo)
	e = par[0]
	var fintas := []
	e.fintou.connect(func(de, para): fintas.append([de, para]))
	e.pedir_ataque(D.PARA_ESQUERDA)
	var id_antes := e.id_acao
	var postura_antes := e.postura
	_ok(not e.pedir_ataque(D.PARA_ESQUERDA), "clicar a MESMA direção no preparo não finta")
	_ok(e.pedir_ataque(D.PARA_DIREITA) and e.golpe_atual.direcao == D.PARA_DIREITA and e.id_acao != id_antes,
		"clicar outra direção no começo do preparo troca o golpe (finta)")
	_ok(is_equal_approx(e.postura, postura_antes - estilo.custo_da_finta) and fintas == [[D.PARA_ESQUERDA, D.PARA_DIREITA]],
		"a finta custa %.0f de postura e avisa (%s)" % [estilo.custo_da_finta, str(fintas)])
	_ok(not e.pedir_ataque(D.FRENTE) and e.golpe_atual.direcao == D.PARA_DIREITA, "segunda finta no mesmo ataque é recusada")

	par = _novo(estilo)
	e = par[0]
	e.pedir_ataque(D.PARA_ESQUERDA)
	var g2 := e.golpe_atual
	_ate(e, func(): return e.tempo_da_acao() > g2.preparo * estilo.janela_de_finta)
	_ok(not e.pedir_ataque(D.PARA_DIREITA), "depois da janela de finta, trocar de direção é recusado")

	par = _novo(estilo)
	e = par[0]
	e.postura = estilo.custo_da_finta - 1.0
	e.pedir_ataque(D.PARA_ESQUERDA)
	_ok(not e.pedir_ataque(D.PARA_DIREITA), "sem postura para pagar, não há finta")

	# Finta para a guarda.
	par = _novo(estilo)
	e = par[0]
	e.pedir_ataque(D.DE_CIMA)
	e.erguer_guarda()
	_ok(e.em_guarda() and e.golpe_atual == null and e.aparando(),
		"aperto novo do botão direito no começo do preparo: finta para a guarda, já na janela de aparo")

	# Atacar a partir da guarda SEGURADA não é finta.
	par = _novo(estilo)
	e = par[0]
	e.erguer_guarda()
	e.pedir_ataque(D.FRENTE)
	e.avancar(DT)
	_ok(e.estado == E.PREPARO and e.guarda_pedida(), "atacar com a guarda segurada não vira finta (sem aperto novo)")

	_portao_da_guarda_e_da_finta(estilo)

	var rebote_longo := estilo.duplicate() as EstiloCorpoACorpo
	rebote_longo.duracao_rebatido = 0.2
	_ok(not rebote_longo.validar().is_empty(), "sabotagem: rebote maior que o preparo do riposte mais rápido é recusado")


## Portão de game feel das Fases 4–5 (crítico de combate, 16/09): as duas estratégias
## degeneradas que ele achou, reproduzidas pela sequência de entradas que as explora.
func _portao_da_guarda_e_da_finta(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 13. segurar a guarda não encurta o golpe; a finta não vaza pela guarda --")
	var E := ExecutorCorpoACorpo.Estado
	var D := GolpeDirecional.Direcao

	# A. "Segura RMB e martela LMB": para cada golpe, o intervalo entre dois inícios não
	# pode ser menor que a duração dele — e a guarda TEM de ter interrompido (senão o
	# teste não passou pelo atalho que quer provar fechado).
	for golpe in estilo.golpes:
		var par := _novo(estilo)
		var e: ExecutorCorpoACorpo = par[0]
		var inicios: Array[float] = []
		var relogio := [0.0]
		e.golpe_iniciado.connect(func(_g, _id): inicios.append(relogio[0]))
		var interrompidos := [0]
		e.golpe_encerrado.connect(func(_id, motivo): if motivo == &"guarda": interrompidos[0] += 1)
		e.erguer_guarda()
		while relogio[0] < 3.0:
			e.pedir_ataque(golpe.direcao)
			e.avancar(DT)
			relogio[0] += DT
		var menor := INF
		for i in range(1, inicios.size()):
			menor = minf(menor, inicios[i] - inicios[i - 1])
		_ok(inicios.size() >= 3 and interrompidos[0] >= 2 and menor >= golpe.duracao() - DT - 0.0001,
			"%s com RMB segurado: %d golpes em 3 s, a guarda interrompeu %d×, menor intervalo %.3f s (golpe dura %.3f s)"
			% [golpe.id, inicios.size(), interrompidos[0], menor, golpe.duracao()])

	# Clique guardado na guarda some se o corpo apanhar.
	var par_b := _novo(estilo)
	var eb: ExecutorCorpoACorpo = par_b[0]
	var grav_b: Gravador = par_b[2]
	var jab := estilo.golpe_para(D.FRENTE)
	eb.erguer_guarda()
	eb.pedir_ataque(D.FRENTE)
	_ate(eb, func(): return eb.estado == E.GUARDA, 2.0)
	eb.pedir_ataque(D.FRENTE)
	var guardou := eb.tem_buffer()
	eb.receber_acerto(jab, ResolucaoDeContato.Lado.FRENTE)
	_ate(eb, func(): return false, 1.0)
	_ok(guardou and grav_b.contar("inicio:") == 1, "clique guardado na guarda é descartado quando o corpo apanha")

	# B. Reiniciar pela guarda: LMB, RMB (finta para a guarda), LMB. O golpe novo nasce
	# antes do fim do preparo fintado e herda a finta — um segundo RMB não finta.
	var par_f := _novo(estilo)
	var ef: ExecutorCorpoACorpo = par_f[0]
	var fintas := [0]
	ef.fintou.connect(func(_de, _para): fintas[0] += 1)
	ef.pedir_ataque(D.DE_CIMA)
	ef.avancar(DT)
	ef.erguer_guarda()
	ef.baixar_guarda()
	ef.pedir_ataque(D.DE_CIMA)
	var reiniciou := ef.estado == E.PREPARO
	ef.avancar(DT)
	ef.erguer_guarda()
	_ok(reiniciou and fintas[0] == 1 and ef.estado == E.PREPARO and not ef.pode_fintar(),
		"LMB → RMB (finta) → LMB: o golpe reiniciado herda a finta e o 2º RMB não finta (%d finta)" % fintas[0])
	var par_c := _novo(estilo)
	var ec: ExecutorCorpoACorpo = par_c[0]
	var overhand := estilo.golpe_para(D.DE_CIMA)
	ec.pedir_ataque(D.DE_CIMA)
	ec.avancar(DT)
	ec.erguer_guarda()
	ec.baixar_guarda()
	_ate(ec, func(): return ec.estado == E.NEUTRO, 1.0)
	_ate(ec, func(): return false, overhand.preparo)
	ec.pedir_ataque(D.DE_CIMA)
	_ok(ec.pode_fintar(), "controle: passado o preparo que foi fintado, o golpe novo pode fintar de novo")


# ------------------------------------------------------------- troca no ATIVO
## §7.1: acerto no ATIVO não interrompe. O dano do Player atordoa sempre, então o golpe
## que levou o acerto no ATIVO precisa ignorar o atordoamento — e SÓ ele, e só isso.
func _troca_no_ativo(estilo: EstiloCorpoACorpo) -> void:
	print("\n-- 14. acerto no ATIVO não interrompe (o atordoamento do dano não cancela) --")
	var D := GolpeDirecional.Direcao
	var jab := estilo.golpe_para(D.FRENTE)

	var par := _novo(estilo)
	var e: ExecutorCorpoACorpo = par[0]
	var ator: AtorFalso = par[1]
	var grav: Gravador = par[2]
	e.pedir_ataque(D.FRENTE)
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	e.receber_acerto(jab, ResolucaoDeContato.Lado.FRENTE)
	ator.atordoado = true   # o que o `take_damage` do Player faz logo depois
	e.avancar(DT)
	_ok(e.atacando(), "acertado no ATIVO e atordoado, o golpe continua (%s)" % ExecutorCorpoACorpo.Estado.keys()[e.estado])
	_ate(e, func(): return not e.atacando())
	_ok(grav.eventos.back().begins_with("fim:fim"), "o golpe que trocou vai até o fim (%s)" % grav.eventos.back())
	_ok(not e.pedir_ataque(D.FRENTE), "ainda atordoado depois do golpe, não começa outro")
	ator.atordoado = false

	# Controle: o MESMO atordoamento no PREPARO, sem acerto no ATIVO, cancela.
	e.pedir_ataque(D.FRENTE)
	e.avancar(DT)
	ator.atordoado = true
	e.avancar(DT)
	_ok(not e.atacando() and grav.eventos.back().begins_with("fim:impedido"),
		"controle: atordoado no PREPARO, o golpe cai (%s)" % grav.eventos.back())
	ator.atordoado = false

	# A marca não vaza para o golpe seguinte.
	e.pedir_ataque(D.FRENTE)
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	ator.atordoado = true
	e.avancar(DT)
	_ok(not e.atacando() and grav.eventos.back().begins_with("fim:impedido"),
		"golpe novo sem acerto no ATIVO: o atordoamento o cancela (%s)" % grav.eventos.back())
	ator.atordoado = false

	# Trava dura cancela até o golpe que trocou.
	e.pedir_ataque(D.FRENTE)
	_ate(e, func(): return e.estado == ExecutorCorpoACorpo.Estado.ATIVO)
	e.receber_acerto(jab, ResolucaoDeContato.Lado.FRENTE)
	ator.livre = false
	e.avancar(DT)
	_ok(not e.atacando() and grav.eventos.back().begins_with("fim:impedido"),
		"trava dura (derrubado, morto) cancela até o golpe que trocou (%s)" % grav.eventos.back())
	ator.livre = true
