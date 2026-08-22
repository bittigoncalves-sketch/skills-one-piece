extends "res://src/tests/BaseTest.gd"
# ============================================================================
#  FSM DE COMBATE — Idle / Attacking / Dashing e o DASH CANCEL.
#
#  Rodar:
#    godot --headless --path . --script src/tests/test_fsm.gd
#
#  A regra em teste (Player.gd, `_etapa_locomocao`):
#
#      dash_bloqueado = estado != Idle
#      exceto: estado == Attacking E hit_confirmed  ->  liberado (dash cancel)
#
#  Ou seja: no meio de um golpe a esquiva só sai se o golpe CONECTOU. É o que
#  impede cancelar um golpe que errou e transforma o dash-cancel numa recompensa
#  por acertar.
#
#  --------------------------------------------------------------- 2026-08-21
#  ⚠️ ESTE TESTE NÃO TESTAVA NADA. Três defeitos, todos silenciosos:
#
#   1. `player` era `null` (ver o cabeçalho de BaseTest.gd) e todo passo
#      estourava "Invalid access ... on a base object of type 'Nil'" — enquanto
#      o teste imprimia ">>> TEST DONE" e saía com 0.
#
#   2. Ele apertava a AÇÃO "dash" do InputMap. A esquiva lê TECLA FÍSICA Q
#      (`Input.is_physical_key_pressed(KEY_Q)` em `src/player/move_frame.gd`) —
#      `Input.action_press("dash")` nunca moveu nada. Agora se injeta o evento
#      de teclado de verdade (`tecla()` do BaseTest).
#
#   3. Ele fazia `_fsm.transition_to("Attacking")` na mão, SEM golpe nenhum.
#      `CombatStateAttacking.physics_update` volta para Idle assim que
#      `_melee.trava() <= 0` — sem golpe a trava é 0, então o estado durava
#      exatamente UM quadro e a "checagem" do quadro seguinte lia Idle. Agora o
#      golpe entra pelo caminho real: `_request_melee()` -> buffer de input ->
#      `CombatStateIdle` consome -> `_melee.pedir()` -> Attacking com trava > 0.
#
#  ⚠️ ARMADILHA DE ORDEM DENTRO DO QUADRO: a esquiva dispara na SOLTURA do Q
#  (segurar MIRA, soltar LANÇA — ver `dash_controller.gd`), então todo teste de
#  dash precisa de pelo menos um quadro com a tecla presa antes de soltar.
# ============================================================================

# Marcos do roteiro, em quadros de física (60 Hz). Nomeados porque a ordem
# entre eles é o teste: mexer num sem olhar os outros quebra a encenação.
const F_ASSENTAR      := 20   # o corpo já caiu no chão e está parado
const F_SOCO_1        := 25
const F_CHECA_ATAQUE  := 28
const F_Q_BAIXO_1     := 29
const F_Q_SOLTO_1     := 33
const F_CHECA_BLOQ    := 36
const F_RESET         := 40
const F_SOCO_2        := 42
const F_HIT_CONFIRM   := 45
const F_Q_BAIXO_2     := 46
const F_Q_SOLTO_2     := 50
const F_CHECA_CANCEL  := 52
const F_CHECA_FIM     := 85

var _estado_no_bloqueio := ""
var _estado_no_cancel := ""
var _velocidade_no_cancel := 0.0
var _dash_no_bloqueio := false
var _dash_no_cancel := false

func preparar() -> void:
	# ⚠️ O boneco de treino anda e BATE sozinho. Um golpe dele no meio do teste
	# joga o Player para "Stunned" e o dash-cancel deixa de valer — falso
	# negativo perfeito. Mesma limpeza que `test_charge_up.gd` faz.
	if is_instance_valid(dummy):
		dummy.set_meta("is_frozen", true)
		dummy.set_meta("damage_immune", true)
		dummy.global_position = Vector3(0, 1.0, -1000.0)
	print("\n===== FSM DE COMBATE =====")

func test_step(f: int, _delta: float) -> void:
	match f:
		F_ASSENTAR:
			print("\n-- 1. a FSM nasce em Idle --")
			ok(player._fsm != null, "o Player montou a máquina de estados")
			ok(player._fsm.state != null and player._fsm.state.name == "Idle",
				"estado inicial = Idle (lido: %s)" % _estado())
			ok(player._fsm.has_node("Idle") and player._fsm.has_node("Attacking")
				and player._fsm.has_node("Dashing"),
				"os três estados de combate existem (Idle/Attacking/Dashing)")

		F_SOCO_1:
			# Caminho REAL do clique: buffer de input -> CombatStateIdle consome.
			player._request_melee()

		F_CHECA_ATAQUE:
			print("\n-- 2. o clique leva a FSM para Attacking --")
			ok(_estado() == "Attacking",
				"3 quadros após o clique o estado é Attacking (lido: %s)" % _estado())
			ok(player._melee.trava() > 0.0,
				"o golpe travou o corpo por %.2f s (é ele que segura o estado)"
					% player._melee.trava())
			ok(player.hit_confirmed == false,
				"o golpe começa SEM confirmação de acerto (hit_confirmed = false)")

		F_Q_BAIXO_1:
			# Recarga zerada na mão: o que está em teste é o BLOQUEIO por estado,
			# não a recarga de 1,5 s da esquiva.
			player._dash._recarga = 0.0
			player.hit_confirmed = false
			tecla(KEY_Q, true)

		F_Q_SOLTO_1:
			tecla(KEY_Q, false)

		F_CHECA_BLOQ:
			print("\n-- 3. sem hit_confirmed o dash-cancel é BLOQUEADO --")
			_dash_no_bloqueio = player._dash.ativo()
			_estado_no_bloqueio = _estado()
			ok(not _dash_no_bloqueio,
				"a esquiva NÃO saiu no meio do golpe que não conectou")
			ok(_estado_no_bloqueio == "Attacking",
				"o golpe continua correndo (estado %s)" % _estado_no_bloqueio)
			ok(Vector2(player.velocity.x, player.velocity.z).length() < 5.0,
				"o corpo seguiu plantado (%.1f m/s no plano)"
					% Vector2(player.velocity.x, player.velocity.z).length())

		F_RESET:
			# Encerra o golpe anterior à força para o segundo round começar limpo.
			player._melee._trava = 0.0
			player._melee._janela = 0.0
			player._melee._buffer = 0.0
			player._melee._passo = 0

		F_SOCO_2:
			player._request_melee()

		F_HIT_CONFIRM:
			# É isto que o jogo faz quando a hitbox do golpe acerta alguém.
			ok(_estado() == "Attacking",
				"segundo golpe em curso antes de confirmar o acerto (estado: %s)" % _estado())
			player.hit_confirmed = true
			player._dash._recarga = 0.0

		F_Q_BAIXO_2:
			tecla(KEY_Q, true)

		F_Q_SOLTO_2:
			tecla(KEY_Q, false)

		F_CHECA_CANCEL:
			print("\n-- 4. com hit_confirmed o dash-cancel SAI --")
			_dash_no_cancel = player._dash.ativo()
			_estado_no_cancel = _estado()
			_velocidade_no_cancel = Vector2(player.velocity.x, player.velocity.z).length()
			ok(_dash_no_cancel,
				"a esquiva disparou no meio do golpe (dash restante %.2f s)"
					% player._dash.tempo())
			ok(_estado_no_cancel != "Attacking",
				"o dash QUEBROU o estado de combate (estado: %s)" % _estado_no_cancel)
			ok(_velocidade_no_cancel > 10.0,
				"e o corpo saiu de verdade: %.1f m/s no plano (DISTANCIA/TEMPO = %.0f)"
					% [_velocidade_no_cancel, DashController.DISTANCIA / DashController.TEMPO])
			ok(bool(player.get_meta("damage_immune", false)),
				"durante a esquiva o Player fica imune a dano")

		F_CHECA_FIM:
			print("\n-- 5. acabada a esquiva, a FSM volta para Idle --")
			ok(not player._dash.ativo(),
				"a esquiva terminou (dura %.2f s)" % DashController.TEMPO)
			ok(_estado() == "Idle", "estado final = Idle (lido: %s)" % _estado())
			ok(not bool(player.get_meta("damage_immune", false)),
				"a imunidade da esquiva foi devolvida")
			ok(player._dash.recarga() > 0.0,
				"a esquiva entrou em recarga (%.2f s)" % player._dash.recarga())

func is_test_done() -> bool:
	return frames >= F_CHECA_FIM

func _estado() -> String:
	if player == null or player._fsm == null or player._fsm.state == null:
		return "<sem estado>"
	return String(player._fsm.state.name)
