class_name MeleeController
extends RefCounted
# ============================================================================
#  CORPO A CORPO — o combo do clique: soco direito, soco esquerdo, chute.
#
#  Fase 7 de docs/ARQUITETURA_PLAYER.md. A tabela dos golpes (tempos, alcance,
#  clipe de animação) mora em `src/combat/Melee.gd` e continua lá — aqui fica o
#  ESTADO do combo e a decisão de quando o próximo golpe pode sair.
#
#  ---------------------------------------------------------------- OS 2 RELÓGIOS
#  `_trava`  RECUPERAÇÃO: enquanto corre, o clique não vira golpe. É o que dá
#            peso ao soco — sem ela o combo vira metralhadora.
#  `_janela` ENCADEAMENTO: tempo que ainda resta para o próximo clique continuar
#            o combo. Vencida, o próximo clique volta ao primeiro soco.
#
#  ------------------------------------------------- A FASE (2026-08-25, §4.1)
#  A FSM de combate deixou de ter um estado "Attacking" só e passou a ter três
#  (`AttackStartup` / `AttackActive` / `AttackRecovery`). Quem diz em qual
#  deles o golpe está é `fase()`, AQUI — e não um segundo relógio dentro da
#  FSM.
#
#  Isso é deliberado. O §4.1 do plano nomeia "dupla fonte de verdade" como o
#  defeito a matar (o corpo do `combat_state` sombreando o `_trava`), e dois
#  contadores para o mesmo golpe é exatamente isso: eles divergem no primeiro
#  hitstop, no primeiro `time_scale`, no primeiro quadro perdido. O relógio é
#  um só; a FSM LÊ.
#
#  ------------------------------------------------------------------- O BUFFER
#  Clique que chega DURANTE a recuperação não some: fica guardado e sai sozinho
#  quando a trava abre. Sem isso o combo pune justamente quem clica no ritmo —
#  e os tempos de recuperação cresceram (0,40 → 0,58 s) para o soco caber em
#  tela, o que só aumentou a janela em que o clique se perdia.
#
#  O buffer é curto de propósito: clique de 1 s atrás não é intenção de agora.
#
#  ---------------------------------------------------------------- A FRONTEIRA
#  Ele decide; o Player fala rede e apresenta. Os `@rpc` (`_net_melee`,
#  `_net_play_melee`) e o `_do_server_melee` ficam no Player desde a Fase 5:
#  RPC se resolve por CAMINHO DE NÓ.
#
#  ⚠️ Nunca chama `is_multiplayer_authority()`: a autoridade NÃO desce para
#  componentes criados no `_ready()` (medido na Fase 5: pai=7, filho=1).
# ============================================================================

# Até quanto antes de a trava abrir o clique ainda é guardado.
const BUFFER := 0.18

var _dono: Node = null

var _passo: int = 0        # em que golpe do combo estamos
var _janela: float = 0.0   # tempo restante para encadear
var _trava: float = 0.0    # recuperação: bloqueia o clique durante o golpe
var _buffer: float = 0.0   # clique que chegou na recuperação, esperando a vez

# --------------------------------------------------------- relógio do golpe
# `_t_golpe` conta PARA CIMA desde o clique; `_trava` conta para baixo. Os dois
# porque respondem perguntas diferentes: a trava diz "ainda estou preso?" e o
# `_t_golpe` diz "em que fase?". Derivar um do outro só funcionaria enquanto a
# trava não fosse alongada no meio do caminho — e a punição de whiff faz
# exatamente isso.
var _t_golpe: float = 0.0
var _passo_em_curso: int = -1   # índice do golpe em voo; -1 = nenhum
var _whiff_resolvido: bool = false

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------ leitura
func passo() -> int:    return _passo
func janela() -> float: return _janela
func trava() -> float:  return _trava

# Índice do golpe EM VOO (-1 = nenhum). Diferente de `passo()`, que já foi
# incrementado para o PRÓXIMO clique.
func passo_em_curso() -> int: return _passo_em_curso

# Em que fase o golpe está AGORA: "startup" | "ativo" | "recuperacao" | "".
# É o que a FSM lê para escolher entre AttackStartup/AttackActive/AttackRecovery
# (ver a nota "A FASE" no cabeçalho: o relógio é um só).
func fase() -> String:
	if _passo_em_curso < 0 or _trava <= 0.0:
		return ""
	var w = _dono.equipped_weapon if _dono and "equipped_weapon" in _dono else ""
	var su := Melee.startup(_passo_em_curso, w)
	if _t_golpe < su:
		return "startup"
	if _t_golpe < su + Melee.ativo(_passo_em_curso, w):
		return "ativo"
	return "recuperacao"

# Quanto falta da fase atual. Serve para sonda e para depuração — a FSM não
# precisa dele, porque quem termina o golpe é a trava.
func tempo_na_fase() -> float:
	return _t_golpe

# Zera o golpe em voo. Chamado por quem CANCELA (dash-cancel, combo breaker,
# morte): sem isso o `_passo_em_curso` fica apontando para um golpe que já não
# está mais em tela e a `fase()` mente para a FSM.
func cancelar_golpe() -> void:
	_passo_em_curso = -1
	_t_golpe = 0.0
	_whiff_resolvido = false
	_trava = 0.0
	_buffer = 0.0

# --------------------------------------------------------------------- clique
# `yaw` entra por parâmetro: a mira é do Player desde a Fase 2.
func pedir(yaw: float) -> void:
	if not _dono._is_authority or _dono._charging:
		return
	var hud := _dono.get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("is_menu_open") and hud.is_menu_open():
		return

	# Clique durante a recuperação: guarda em vez de perder (ver o cabeçalho).
	if _trava > 0.0:
		if _trava <= BUFFER:
			_buffer = BUFFER
		return

	var w = _dono.equipped_weapon if _dono and "equipped_weapon" in _dono else ""
	var combo_len = Melee.COMBO_SWORD.size() if w == "sword" else Melee.COMBO.size()
	
	# Janela vencida (ou combo terminado) -> recomeça do primeiro soco.
	if _janela <= 0.0 or _passo >= combo_len:
		_passo = 0
	var golpe := Melee.passo(_passo, w)
	var s := 1.0
	if "scale" in _dono:
		s = _dono.scale.y

	# A TRAVA É O FRAME DATA (2026-08-25) — era a duração da animação inteira
	# desde 2026-08-15. Ver o histórico das três fases em `Melee.recuo()`.
	#
	# ⚠️ E NÃO ESCALA COM O PORTE. O `* s` fazia sentido quando o número era
	# escrito à mão (personagem grande, golpe mais pesado), mas o clipe toca no
	# mesmo `vel` seja qual for a escala: manter o fator daria à Gura Gura, que
	# dobra a escala ao equipar (`scale = 2`), uma trava de 2,98 s para uma
	# animação de 1,49 s. Com frame data isso vale ainda mais: 0,40 s é um alvo
	# de JOGO, não uma medida do boneco.
	_trava = Melee.recuo(_passo, w)
	_janela = Melee.JANELA

	# Abre o relógio de fase deste golpe. `hit_confirmed` volta a false aqui
	# também, e não só no `CombatStateIdle`: o segundo golpe de um combo não
	# passa pelo Idle, e herdar a confirmação do golpe anterior daria dash-cancel
	# de graça num golpe que ainda não acertou nada.
	_passo_em_curso = _passo
	_t_golpe = 0.0
	_whiff_resolvido = false
	if _dono and "hit_confirmed" in _dono:
		_dono.hit_confirmed = false

	var fwd := RosaDosVentos.frente(yaw)   # definição canônica: RosaDosVentos
	var origem: Vector3 = _dono.global_position + Vector3.UP * (1.0 * s)

	# ⚠️ O TRANCO DE CÂMERA SAI NO SOCO, NÃO NO CLIQUE. Ele já foi disparado
	# aqui direto — ou seja, até 0,5 s antes de a hitbox nascer: a tela sacudia
	# na preparação e ficava parada no impacto. Era exatamente o sintoma
	# relatado, "o impacto não sai no momento do soco".
	var t_impacto := _dono.get_tree().create_timer(Melee.startup(_passo, w))
	var forca: float = float(golpe["shake"])
	t_impacto.timeout.connect(func():
		_dono.add_camera_shake(forca)
		_dono.pedir_soco_de_fov(3.0))

	_dono.pedir_golpe_no_servidor(_passo, origem, fwd)
	_passo += 1

# --------------------------------------------------------------------- ciclo
# Corre os relógios do combo.
func tick(delta: float, yaw: float) -> void:
	if _passo_em_curso >= 0:
		_t_golpe += delta
		_resolver_whiff()

	if _trava > 0.0:
		_trava = maxf(_trava - delta, 0.0)
		if _trava == 0.0:
			_passo_em_curso = -1      # o golpe saiu de tela; não há mais fase
			if _buffer > 0.0:
				_buffer = 0.0
				pedir(yaw)            # o clique guardado sai agora que a trava abriu

	if _buffer > 0.0:
		_buffer = maxf(_buffer - delta, 0.0)
	if _janela > 0.0:
		_janela = maxf(_janela - delta, 0.0)
		if _janela == 0.0:
			_passo = 0            # esfriou: o próximo clique volta ao soco direito

# -------------------------------------------------------- PUNIÇÃO DE WHIFF
# "recuperação ×1,35 se errar" (§4.3 do plano): o que se pune é ter ficado
# exposto, não ter tentado — por isso alonga só a recuperação, nunca o startup
# nem o ativo.
#
# ⚠️ POR QUE NÃO NO CLIQUE. No clique ainda não se sabe se o golpe erra: a
# hitbox só nasce no fim do startup. A conta certa é ao FECHAR a janela ativa —
# aí `hit_confirmed` já é a resposta final daquele golpe.
#
# ⚠️ POR QUE NÃO NUM `SceneTreeTimer`. Timer solto foi como a morte deixava
# `is_casting` pendurado para sempre (item 23, e a mesma nota está em
# `RecepcaoDeDano.aplicar`): o respawn não tem como cancelar o que já foi
# agendado, e a trava alongada sobreviveria à própria morte do jogador. O
# contador já existe; usar ele custa uma comparação por quadro.
func _resolver_whiff() -> void:
	if _whiff_resolvido:
		return
	var w = _dono.equipped_weapon if _dono and "equipped_weapon" in _dono else ""
	if not Melee.tem_frame_data(_passo_em_curso, w):
		_whiff_resolvido = true
		return
	if _t_golpe < Melee.startup(_passo_em_curso, w) + Melee.ativo(_passo_em_curso, w):
		return
	_whiff_resolvido = true
	if _dono and "hit_confirmed" in _dono and _dono.hit_confirmed:
		return                        # acertou: recuperação normal
	_trava += Melee.recuperacao(_passo_em_curso, w) * (Melee.WHIFF_MULT - 1.0)

