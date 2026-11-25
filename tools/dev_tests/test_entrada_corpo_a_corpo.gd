extends SceneTree
# ============================================================================
#  TESTE DA ENTRADA DO COMBATE DIRECIONAL — a leitura da direção pelo mouse.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md, Fase 2 (D10, D11). Sem Player, sem tela:
#  as amostras de movimento entram com instante explícito, então a janela de
#  tempo é conferida sem depender do relógio do teste.
#
#  O clique de verdade, com mouse capturado, é julgado em
#  `test_combate_historia_tela.gd` (headless não captura o mouse — item 64).
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_entrada_corpo_a_corpo.gd
# ============================================================================

const SENS := 0.0035   # a mesma do Player (MOUSE_SENS); conferida abaixo contra a real
const D := GolpeDirecional.Direcao

var _falhas := 0
var _criados: Array[Node] = []   # entradas fora da árvore: liberadas no fim


func _init() -> void:
	await process_frame
	print("\n===== ENTRADA DO COMBATE DIRECIONAL =====")
	_classificacao()
	_janela_de_tempo()
	_anel_fixo()
	_sensibilidade()
	_contrato_sem_captura()
	_input_map()
	for n in _criados:
		n.free()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _nome(d: int) -> String:
	return GolpeDirecional.Direcao.keys()[d]


func _entrada() -> EntradaCorpoACorpo:
	var e := EntradaCorpoACorpo.new()
	_criados.append(e)
	e.montar(null, SENS)
	return e


# ---------------------------------------------------------------------- 1
func _classificacao() -> void:
	print("\n-- 1. gesto → direção (em radianos de câmera; y para baixo, como a tela) --")
	var z := 0.035
	var casos := [
		[Vector2(-0.10, 0.0), D.PARA_ESQUERDA, "mouse para a esquerda"],
		[Vector2(0.10, 0.0), D.PARA_DIREITA, "mouse para a direita"],
		[Vector2(0.0, -0.10), D.DE_CIMA, "mouse para cima"],
		[Vector2(0.0, 0.10), D.FRENTE, "mouse para baixo (reservado; v1 = frente)"],
		[Vector2(0.01, -0.01), D.FRENTE, "gesto dentro da zona morta"],
		[Vector2(-0.08, -0.06), D.PARA_ESQUERDA, "diagonal com horizontal dominante"],
		[Vector2(-0.05, -0.08), D.DE_CIMA, "diagonal com vertical dominante"],
		[Vector2(0.0, 0.0), D.FRENTE, "sem gesto nenhum"],
	]
	for c in casos:
		var obtido := EntradaCorpoACorpo.classificar(c[0], z)
		_ok(obtido == c[1], "%s → %s (obteve %s)" % [c[2], _nome(c[1]), _nome(obtido)])
	# Controle: o sinal importa. Se a classificação ignorasse o sentido, os dois
	# lados dariam o mesmo resultado e os casos acima ainda poderiam passar por sorte.
	_ok(EntradaCorpoACorpo.classificar(Vector2(-0.1, 0), z) != EntradaCorpoACorpo.classificar(Vector2(0.1, 0), z),
		"controle: esquerda e direita dão direções diferentes")


# ---------------------------------------------------------------------- 2
func _janela_de_tempo() -> void:
	print("\n-- 2. só o gesto recente conta --")
	var e := _entrada()
	var px := Vector2(-40, 0)          # 40 px × 0,0035 = 0,14 rad, bem acima da zona morta
	e.registrar_movimento(px, 1000)
	_ok(e.direcao_em(1050) == D.PARA_ESQUERDA, "50 ms depois do gesto: PARA_ESQUERDA")
	_ok(e.direcao_em(1000 + int(e.janela * 1000.0) + 50) == D.FRENTE, "passada a janela, o gesto velho não vale (FRENTE)")

	var soma := _entrada()
	for i in 6:
		soma.registrar_movimento(Vector2(0, -3), 2000 + i * 8)   # 18 px aos poucos = 0,063 rad
	_ok(soma.direcao_em(2050) == D.DE_CIMA, "vários movimentos pequenos SOMAM (%.3f rad para cima)" % -soma.gesto_em(2050).y)

	var anula := _entrada()
	anula.registrar_movimento(Vector2(-40, 0), 3000)
	anula.registrar_movimento(Vector2(40, 0), 3010)
	_ok(anula.direcao_em(3020) == D.FRENTE, "ir e voltar no mesmo instante se anula (FRENTE)")

	var esquece := _entrada()
	esquece.registrar_movimento(px, 4000)
	esquece.esquecer_gesto()
	_ok(esquece.direcao_em(4010) == D.FRENTE, "esquecer_gesto apaga o gesto guardado")


# ---------------------------------------------------------------------- 3
func _anel_fixo() -> void:
	print("\n-- 3. o anel não cresce --")
	var e := _entrada()
	for i in 500:
		e.registrar_movimento(Vector2(1, 0), 5000 + i)
	var gesto := e.gesto_em(5499)
	# Só as amostras que cabem no anel podem somar: 500 eventos de 1 px dariam
	# 1,75 rad se nada fosse descartado.
	_ok(gesto.x > 0.0 and gesto.x <= 64 * SENS + 0.0001,
		"500 eventos seguidos: soma limitada ao anel (%.4f rad, teto %.4f)" % [gesto.x, 64 * SENS])


# ---------------------------------------------------------------------- 4
func _sensibilidade() -> void:
	print("\n-- 4. a sensibilidade é a do jogador --")
	var player_gd: GDScript = load("res://Player.gd")
	_ok(is_equal_approx(float(player_gd.get_script_constant_map().get("MOUSE_SENS", -1.0)), SENS),
		"MOUSE_SENS do Player é %.4f (a instalação usa a constante, não cópia)" % SENS)
	var sem := EntradaCorpoACorpo.new()
	_criados.append(sem)
	sem.montar(null, 0.0)
	sem.registrar_movimento(Vector2(-400, 0), 6000)
	_ok(sem.direcao_em(6010) == D.FRENTE, "controle: sensibilidade zero não gera gesto (prova que ela entra na conta)")


# ---------------------------------------------------------------------- 5
func _contrato_sem_captura() -> void:
	print("\n-- 5. sem mouse capturado a entrada não consome o clique --")
	var executor := ExecutorCorpoACorpo.new()
	executor.montar(AtorDeCombate.new(), load("res://src/combat/direcional/estilos/boxe.tres"))
	var e := EntradaCorpoACorpo.new()
	e.montar(executor, SENS)
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ok(not e.tratar(clique) and not executor.ocupado(),
		"mouse solto: tratar() devolve false e nada começa (o Player recaptura o mouse, como sempre)")
	executor.free()
	e.free()


# ---------------------------------------------------------------------- 6
func _input_map() -> void:
	print("\n-- 6. as ações do InputMap --")
	for par in [[EntradaCorpoACorpo.ACAO_ATACAR, MOUSE_BUTTON_LEFT], [EntradaCorpoACorpo.ACAO_DEFENDER, MOUSE_BUTTON_RIGHT]]:
		var existe := InputMap.has_action(par[0])
		var ev := InputEventMouseButton.new()
		ev.button_index = par[1]
		ev.pressed = true
		_ok(existe and ev.is_action_pressed(par[0]), "%s existe e casa com o botão %d" % [par[0], par[1]])
	var errado := InputEventMouseButton.new()
	errado.button_index = MOUSE_BUTTON_RIGHT
	errado.pressed = true
	_ok(not errado.is_action_pressed(EntradaCorpoACorpo.ACAO_ATACAR), "controle: o botão direito NÃO é ataque")
