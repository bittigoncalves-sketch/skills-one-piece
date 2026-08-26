extends "res://src/tests/BaseTest.gd"
# ============================================================================
#  FSM DE COMBATE — as TRÊS fases do golpe e o DASH CANCEL.
#
#  Rodar:
#    godot --headless --path . --script src/tests/test_fsm.gd
#
#  ------------------------------------------------------------- 2026-08-25
#  O estado único "Attacking" virou três (§4.1 do PLANO_COMBATE_BATTLEGROUNDS):
#
#      AttackStartup  →  AttackActive  →  AttackRecovery  →  Idle
#         0,20 s           0,06 s           0,14 s
#
#  A REGRA EM TESTE MUDOU, e a mudança é o ponto:
#
#      antes:  dash liberado em "Attacking" inteiro, se hit_confirmed
#      agora:  dash liberado só em "AttackRecovery", e só se hit_confirmed
#
#  A diferença não é cosmética. Com a regra antiga dava para apertar, ver que o
#  golpe ia acertar e sumir ANTES DE A HITBOX NASCER — o startup não custava
#  nada. Startup e ativo agora são compromisso: apertou, vai.
#
#  ---------------------------------------------------------- OS TRÊS ROUNDS
#   A. as fases acontecem na ordem, e sem acerto o dash NÃO sai na recuperação
#   B. COM acerto, o dash ainda assim não sai no STARTUP (a regra nova)
#   C. COM acerto, na RECUPERAÇÃO, o dash sai — e quebra o estado de combate
#
#  ------------------------------------------------- POR QUE OS MARCOS SÃO CONTAS
#  Os quadros abaixo saem do frame data, não de números escritos à mão. Mexer
#  em `startup`/`ativo`/`recuperacao` no `Melee.gd` reposiciona o roteiro
#  sozinho — que é a mesma razão pela qual o `recuo` deixou de ser escrito à
#  mão em 2026-08-15 e o `inicio` em 2026-08-25.
#
#  ⚠️ O GOLPE COMEÇA UM QUADRO DEPOIS DO CLIQUE. `test_step` roda no sinal
#  `physics_frame`, ou seja DEPOIS de o `_physics_process` do Player já ter
#  passado; o buffer só é consumido no quadro seguinte.
#
#  ⚠️ ARMADILHA DE ORDEM DENTRO DO QUADRO: a esquiva dispara na SOLTURA do Q
#  (segurar MIRA, soltar LANÇA — ver `dash_controller.gd`), então todo teste de
#  dash precisa de pelo menos um quadro com a tecla presa antes de soltar.
#
#  ⚠️ Os três rounds erram de propósito (o boneco é levado para longe em
#  `preparar()`). Onde o teste precisa de acerto, `hit_confirmed` é escrito na
#  mão — é exatamente o que a `DamageZone.hit_landed` faz no jogo.
# ============================================================================

const HZ := 60.0

# Marcos derivados do frame data — preenchidos em `preparar()`.
var _f_soco := {}          # round -> quadro do clique
var _f_startup := {}       # round -> quadro para checar a fase startup
var _f_ativo := 0
var _f_recup := {}
var _f_hit := {}
var _f_q_baixo := {}
var _f_q_solto := {}
var _f_checa := {}
var _f_idle := 0
var _f_fim := 0

var _estado_no_bloqueio := ""
var _estado_no_startup := ""
var _estado_no_cancel := ""
var _velocidade_no_cancel := 0.0
var _dash_no_bloqueio := false
var _dash_no_startup := false
var _dash_no_cancel := false
var _viu_startup := false
var _viu_ativo := false
var _viu_recuperacao := false

func preparar() -> void:
	# ⚠️ O boneco de treino anda e BATE sozinho. Um golpe dele no meio do teste
	# joga o Player para "Stunned" e o dash-cancel deixa de valer — falso
	# negativo perfeito. Mesma limpeza que `test_charge_up.gd` faz.
	if is_instance_valid(dummy):
		dummy.set_meta("is_frozen", true)
		dummy.set_meta("damage_immune", true)
		dummy.global_position = Vector3(0, 1.0, -1000.0)

	# ⚠️ MÃO LIVRE, NÃO ESPADA. O `BaseTest` equipa a espada por padrão (ver a
	# nota lá), e com ela `Melee.passo()` devolve o `COMBO_SWORD` — tabela
	# antiga, sem frame data. Todo o roteiro abaixo é medido no combo do punho.
	player.equipped_weapon = ""

	# ---- o roteiro, em quadros, saindo do frame data do JAB (passo 0) --------
	var q_startup := int(ceil(Melee.startup(0) * HZ))          # 12 quadros
	var q_ativo := int(ceil(Melee.ativo(0) * HZ))              #  4 quadros
	var q_trava_errou := int(ceil(Melee.recuo(0, "", true) * HZ))
	var q_trava_acertou := int(ceil(Melee.recuo(0, "", false) * HZ))

	# ROUND A — as fases, e o dash bloqueado na recuperação SEM acerto.
	_f_soco[0] = 25
	var a: int = _f_soco[0] + 1                                # o golpe começa aqui
	_f_startup[0] = a + int(q_startup / 2)                     # meio do startup
	_f_ativo = a + q_startup + int(q_ativo / 2)                # meio do ativo
	_f_q_baixo[0] = a + q_startup + q_ativo + 1                # já na recuperação
	_f_q_solto[0] = _f_q_baixo[0] + 2
	_f_recup[0] = _f_q_solto[0] + 2
	_f_checa[0] = _f_recup[0]
	_f_idle = a + q_trava_errou + 4

	# ROUND B — COM acerto, o dash ainda não sai no STARTUP.
	_f_soco[1] = _f_idle + 4
	var b: int = _f_soco[1] + 1
	_f_hit[1] = b + 2                                          # bem no começo
	_f_q_baixo[1] = b + 3
	_f_q_solto[1] = b + 5
	_f_checa[1] = b + 7                                        # ainda dentro do startup
	var fim_b: int = b + q_trava_acertou + 4

	# ROUND C — COM acerto, na RECUPERAÇÃO, o dash SAI.
	_f_soco[2] = fim_b + 4
	var c: int = _f_soco[2] + 1
	_f_hit[2] = c + q_startup + 1                              # durante o ativo
	_f_q_baixo[2] = c + q_startup + q_ativo + 1
	_f_q_solto[2] = _f_q_baixo[2] + 2
	# ⚠️ NO PRIMEIRO QUADRO DA ESQUIVA, não dois depois.
	#
	# A esquiva percorre `DISTANCIA` em `TEMPO` — ~12 m em 0,28 s — e a arena de
	# teste tem uma parede em z = −11,5. Medindo dois quadros depois do disparo,
	# o corpo já tinha batido nela e o `move_and_slide` zerado a velocidade: a
	# asserção lia 0,0 m/s e acusava um dash que na verdade saiu a 42,9 m/s
	# (medido). Falso negativo por CENÁRIO, não por código.
	#
	# O quadro do disparo é também o certo semanticamente: a pergunta é se o
	# corpo SAIU, e é neste instante que ele sai.
	_f_checa[2] = _f_q_solto[2] + 1
	_f_fim = _f_checa[2] + int(DashController.TEMPO * HZ) + 25

	print("\n===== FSM DE COMBATE — três fases =====")
	print("  frame data do jab: startup %.2fs (%dq) | ativo %.2fs (%dq) | trava %.2fs errando, %.2fs acertando"
		% [Melee.startup(0), q_startup, Melee.ativo(0), q_ativo,
			Melee.recuo(0, "", true), Melee.recuo(0, "", false)])

func test_step(f: int, _delta: float) -> void:
	# Registra as fases vistas em QUALQUER quadro do round A — o `match` por
	# quadro exato erraria o `ativo`, que dura 4 quadros.
	if f > _f_soco[0] and f <= _f_idle:
		match _estado():
			"AttackStartup":   _viu_startup = true
			"AttackActive":    _viu_ativo = true
			"AttackRecovery":  _viu_recuperacao = true

	if f == 20:
		print("\n-- 1. a FSM nasce em Idle, com as três fases montadas --")
		ok(player._fsm != null, "o Player montou a máquina de estados")
		ok(player._fsm.state != null and player._fsm.state.name == "Idle",
			"estado inicial = Idle (lido: %s)" % _estado())
		ok(player._fsm.has_node("Idle") and player._fsm.has_node("AttackStartup")
			and player._fsm.has_node("AttackActive") and player._fsm.has_node("AttackRecovery")
			and player._fsm.has_node("Dashing"),
			"as fases do golpe existem (Idle/AttackStartup/AttackActive/AttackRecovery/Dashing)")
		# O "Stunned" foi pedido em sete pontos do Player.gd durante meses sem
		# existir — `transition_to` fazia `return` calado. Ver o cabeçalho de
		# `CombatStateStunned.gd`.
		ok(player._fsm.has_node("Stunned"),
			"o estado Stunned EXISTE (era referenciado em 7 pontos e não existia)")

	# ---------------------------------------------------------------- ROUND A
	elif f == _f_soco[0]:
		# Caminho REAL do clique: buffer de input -> CombatStateIdle consome.
		player._request_melee()

	elif f == _f_startup[0]:
		print("\n-- 2. o clique entra em AttackStartup --")
		ok(_estado() == "AttackStartup",
			"no meio do startup o estado é AttackStartup (lido: %s)" % _estado())
		ok(player._melee.trava() > 0.0,
			"o golpe travou o corpo por %.2f s" % player._melee.trava())
		ok(player.hit_confirmed == false,
			"o golpe começa SEM confirmação de acerto (hit_confirmed = false)")
		ok(player._melee.passo_em_curso() == 0,
			"o golpe em voo é o passo 0 (lido: %d)" % player._melee.passo_em_curso())

	elif f == _f_ativo:
		print("\n-- 3. a hitbox nasce: AttackActive --")
		ok(_estado() == "AttackActive",
			"no meio da janela ativa o estado é AttackActive (lido: %s)" % _estado())

	elif f == _f_q_baixo[0]:
		# Recarga zerada na mão: o que está em teste é o BLOQUEIO por estado,
		# não a recarga da esquiva.
		player._dash._recarga = 0.0
		player.hit_confirmed = false
		tecla(KEY_Q, true)

	elif f == _f_q_solto[0]:
		tecla(KEY_Q, false)

	elif f == _f_checa[0]:
		print("\n-- 4. sem hit_confirmed o dash-cancel é BLOQUEADO na recuperação --")
		_dash_no_bloqueio = player._dash.ativo()
		_estado_no_bloqueio = _estado()
		ok(not _dash_no_bloqueio,
			"a esquiva NÃO saiu no golpe que não conectou")
		ok(_estado_no_bloqueio == "AttackRecovery",
			"o golpe continua na recuperação (estado %s)" % _estado_no_bloqueio)
		ok(Vector2(player.velocity.x, player.velocity.z).length() < 5.0,
			"o corpo seguiu plantado (%.1f m/s no plano)"
				% Vector2(player.velocity.x, player.velocity.z).length())

	elif f == _f_idle:
		print("\n-- 5. as três fases aconteceram, na ordem, e o golpe acabou --")
		ok(_viu_startup, "a fase AttackStartup foi observada")
		ok(_viu_ativo, "a fase AttackActive foi observada")
		ok(_viu_recuperacao, "a fase AttackRecovery foi observada")
		ok(_estado() == "Idle", "acabada a trava, a FSM voltou para Idle (lido: %s)" % _estado())
		ok(player._melee.passo_em_curso() == -1,
			"não há mais golpe em voo (passo_em_curso = %d)" % player._melee.passo_em_curso())

	# ---------------------------------------------------------------- ROUND B
	elif f == _f_soco[1]:
		player._melee.cancelar_golpe()
		player._melee._passo = 0
		player._melee._janela = 0.0
		player._request_melee()

	elif f == _f_hit[1]:
		# Sintético: no jogo `hit_confirmed` só vira true quando a hitbox
		# encosta em alguém, e a hitbox nem nasceu ainda. É de propósito — a
		# pergunta deste round é se o STARTUP resiste mesmo à condição que
		# liberava o dash na regra antiga.
		player.hit_confirmed = true
		player._dash._recarga = 0.0

	elif f == _f_q_baixo[1]:
		tecla(KEY_Q, true)

	elif f == _f_q_solto[1]:
		tecla(KEY_Q, false)

	elif f == _f_checa[1]:
		print("\n-- 6. COM hit_confirmed, o dash AINDA NÃO sai no startup (regra nova) --")
		_dash_no_startup = player._dash.ativo()
		_estado_no_startup = _estado()
		ok(_estado_no_startup == "AttackStartup",
			"o golpe ainda está no startup (estado: %s)" % _estado_no_startup)
		ok(not _dash_no_startup,
			"a esquiva NÃO saiu: startup é compromisso, mesmo com o golpe confirmado")

	# ---------------------------------------------------------------- ROUND C
	elif f == _f_soco[2]:
		player._melee.cancelar_golpe()
		player._melee._passo = 0
		player._melee._janela = 0.0
		tecla(KEY_Q, false)
		# ESPAÇO PARA A ESQUIVA. O corpo passa a partida em z ≈ −9,8 (ver a nota
		# do `_f_checa[2]`), a 1,7 m da parede — e a esquiva quer 12 m. Sem isto,
		# o round mede a parede em vez do dash.
		player.global_position = Vector3(0, 1.0, 10.0)
		player.velocity = Vector3.ZERO
		player._request_melee()

	elif f == _f_hit[2]:
		# É isto que o jogo faz quando a hitbox do golpe acerta alguém.
		player.hit_confirmed = true
		player._dash._recarga = 0.0

	elif f == _f_q_baixo[2]:
		tecla(KEY_Q, true)

	elif f == _f_q_solto[2]:
		tecla(KEY_Q, false)

	elif f == _f_checa[2]:
		print("\n-- 7. COM hit_confirmed, na RECUPERAÇÃO, o dash-cancel SAI --")
		_dash_no_cancel = player._dash.ativo()
		_estado_no_cancel = _estado()
		_velocidade_no_cancel = Vector2(player.velocity.x, player.velocity.z).length()
		ok(_dash_no_cancel,
			"a esquiva disparou no meio do golpe (dash restante %.2f s)"
				% player._dash.tempo())
		# ⚠️ `player.ESTADOS_DE_ATAQUE`, NÃO `Player.ESTADOS_DE_ATAQUE`. Citar a
		# CLASSE aqui obriga o `Player.gd` a compilar no momento em que ESTE
		# script é carregado — antes dos autoloads existirem — e cai direto na
		# armadilha do cabeçalho do `BaseTest.gd`: "Identifier not found:
		# FruitNet", o teste nem monta. Pela instância, a resolução é em runtime.
		ok(not (_estado_no_cancel in player.ESTADOS_DE_ATAQUE),
			"o dash QUEBROU o estado de combate (estado: %s)" % _estado_no_cancel)
		ok(player._melee.passo_em_curso() == -1,
			"e o golpe em voo foi cancelado junto (passo_em_curso = %d)"
				% player._melee.passo_em_curso())
		ok(_velocidade_no_cancel > 10.0,
			"e o corpo saiu de verdade: %.1f m/s no plano (DISTANCIA/TEMPO = %.0f)"
				% [_velocidade_no_cancel, DashController.DISTANCIA / DashController.TEMPO])
		ok(bool(player.get_meta("damage_immune", false)),
			"durante a esquiva o Player fica imune a dano")

	elif f == _f_fim:
		print("\n-- 8. acabada a esquiva, a FSM volta para Idle --")
		ok(not player._dash.ativo(),
			"a esquiva terminou (dura %.2f s)" % DashController.TEMPO)
		ok(_estado() == "Idle", "estado final = Idle (lido: %s)" % _estado())
		ok(not bool(player.get_meta("damage_immune", false)),
			"a imunidade da esquiva foi devolvida")
		ok(player._dash.recarga() > 0.0,
			"a esquiva entrou em recarga (%.2f s)" % player._dash.recarga())

func is_test_done() -> bool:
	return frames >= _f_fim

func _estado() -> String:
	if player == null or player._fsm == null or player._fsm.state == null:
		return "<sem estado>"
	return String(player._fsm.state.name)
