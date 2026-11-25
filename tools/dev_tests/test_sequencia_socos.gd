extends SceneTree
## Sequência usa entrada + executor reais, relógio controlado e ator sem visual.
const D := GolpeDirecional.Direcao
var falhas := 0
var checks := 0
var e: ExecutorCorpoACorpo
var entrada: EntradaCorpoACorpo
var ator: AtorTeste
var inicios: Array[int] = []

class AtorTeste extends AtorDeCombate:
	var livre := true
	func pode_iniciar() -> bool:
		return livre
	func impedido(_contar_atordoamento := true) -> bool:
		return not livre

func _init() -> void:
	await process_frame
	for dt in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 144.0]:
		montar()
		for direcao in [D.FRENTE, D.PARA_ESQUERDA, D.PARA_DIREITA, D.DE_CIMA, D.FRENTE]:
			# Enum 1 = PARA_ESQUERDA; nomes dos golpes são anatômicos.
			ok(clique() and e.golpe_atual.direcao == direcao, "sequência por clique em %.0f Hz: %d" % [1.0 / dt, direcao])
			terminar(dt)
			passar(.15, dt)
		ok(inicios.size() == 5, "nenhum soco automático sem clique")
		passar(1.3, dt)
		ok(clique() and e.golpe_atual.direcao == D.FRENTE, "pausa reinicia jab")
		limpar()
	montar()
	clique()
	var identidade := e.id_acao
	for i in 10:
		ok(not clique(), "clique precoce não finta nem avança")
	ok(e.id_acao == identidade, "spam preserva golpe inicial")
	passar(e.golpe_atual.preparo + e.golpe_atual.ativo + .03)
	for i in 10:
		ok(clique(), "buffer aceita um próximo golpe")
	terminar()
	ok(e.golpe_atual != null and e.golpe_atual.direcao == 1, "buffer avança exatamente um soco")
	terminar()
	ok(inicios.size() == 2, "spam não cria fila automática")
	clique()
	e.cancelar(&"dano")
	ok(clique() and e.golpe_atual.direcao == D.FRENTE, "interrupção reinicia sequência")
	terminar()
	entrada.atualizar_defesa(true)
	entrada.atualizar_defesa(false)
	passar(.3)
	ok(clique() and e.golpe_atual.direcao == D.FRENTE, "defesa reinicia sequência")
	terminar()
	ator.livre = false
	entrada.avancar_sequencia(.01)
	ok(not clique(), "ator impedido não ataca")
	ator.livre = true
	ok(clique() and e.golpe_atual.direcao == D.FRENTE, "retomada após trava começa no jab")
	terminar()
	entrada.registrar_movimento(Vector2(30, 0), 1000)
	ok(entrada.pedir_clique(1000) and e.golpe_atual.direcao == D.PARA_DIREITA, "gesto explícito escolhe o golpe")
	entrada.esquecer_gesto()
	terminar()
	var boxe := e.estilo
	e.trocar_estilo(load("res://src/combat/direcional/estilos/espada.tres"))
	for i in 2:
		ok(clique() and e.golpe_atual.direcao == D.FRENTE, "espada conserva estocada no clique parado")
		terminar()
	e.trocar_estilo(boxe)
	ok(clique() and e.golpe_atual.direcao == D.FRENTE, "voltar às mãos reinicia jab")
	terminar()
	entrada.suspensa = true
	ok(not clique(), "arma de fruta suspende socos")
	entrada.suspensa = false
	# Controle da regressão: sem sequência configurada, o comportamento anterior
	# repete jab. A mesma entrada precisa produzir resultados diferentes com ela.
	var anterior := boxe.duplicate() as EstiloCorpoACorpo
	anterior.sequencia_cliques = []
	e.trocar_estilo(anterior)
	for i in 3:
		ok(clique() and e.golpe_atual.direcao == D.FRENTE, "controle sem sequência repete jab")
		terminar()
	var invalido := boxe.duplicate() as EstiloCorpoACorpo
	invalido.sequencia_cliques = [99]
	ok(not invalido.validar().is_empty(), "validador rejeita direção inexistente")
	invalido.sequencia_cliques = [0]
	invalido.janela_sequencia = 0
	ok(not invalido.validar().is_empty(), "validador rejeita sequência sem janela")
	limpar()
	print("SEQUENCIA SOCOS: %d/%d passaram" % [checks - falhas, checks])
	quit(1 if falhas else 0)

func montar() -> void:
	e = ExecutorCorpoACorpo.new()
	ator = AtorTeste.new()
	e.montar(ator, load("res://src/combat/direcional/estilos/boxe.tres"))
	entrada = EntradaCorpoACorpo.new()
	entrada.montar(e, .0035)
	inicios.clear()
	e.golpe_iniciado.connect(func(g, _id): inicios.append(g.direcao))

func clique() -> bool:
	return entrada.pedir_clique(2000)

func passar(tempo: float, dt := 1.0 / 60.0) -> void:
	var restante := tempo
	while restante > 0:
		var passo := minf(dt, restante)
		e.avancar(passo)
		entrada.avancar_sequencia(passo)
		restante -= passo

func terminar(dt := 1.0 / 60.0) -> void:
	var id := e.id_acao
	for i in int(3.0 / dt):
		if not e.atacando() or e.id_acao != id:
			return
		passar(dt, dt)
	ok(false, "golpe termina dentro do limite")

func limpar() -> void:
	entrada.free()
	e.free()

func ok(cond: bool, texto: String) -> void:
	checks += 1
	if not cond:
		falhas += 1
	print(("OK " if cond else "FALHA ") + texto)
