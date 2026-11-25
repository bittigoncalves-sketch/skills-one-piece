class_name DashController
extends RefCounted
# ============================================================================
#  ROLL — a esquiva do Q (era o DASH até 03/10/2026).
#
#  Pedido do dono (03/10/2026): "roll passando a ser a tecla Q, eliminando o
#  dash". Decisão: o roll HERDA o papel do dash no combate — mesma recarga, a
#  mesma janela de invulnerabilidade (0,28 s), o mesmo cancelamento de golpe que
#  acertou —, mas é um ROLAMENTO de verdade: dispara ao APERTAR Q (sem segurar para
#  mirar), rola para onde o WASD aponta (sem tecla, para a frente da câmera), o
#  corpo vira para o rumo e toca o clipe Mixamo "Sprinting Forward Roll". Os
#  rumos com pose própria (rolamento de costas, mergulho lateral) saíram: todo
#  roll é para a frente do próprio rumo. O nome da classe ficou para não quebrar
#  quem a consulta (Player, combate, testes).
#
#  Fase 4 de docs/ARQUITETURA_PLAYER.md. Primeiro dos três cortes do ciclo
#  físico, e o primeiro de propósito: a medição mostrou que **todos** os campos
#  de dash eram usados só dentro do `_etapa_locomocao` (8 de 9 usos de `_dash_t`,
#  4 de 5 de `_dash_dir` — o resto era a linha de declaração). Nada de fora
#  dependia deles.
#
#  ------------------------------------------------------------------ COMO FUNCIONA
#  Apertar Q DISPARA. A direção é travada no disparo: girar a câmera no meio do
#  roll não o curva. Durante o roll não há gravidade — só o plano.
#
#  ---------------------------------------------------------------- A FRONTEIRA
#  Este controlador é dono de: mira, recarga, tempo restante e direção travada.
#  Ele NÃO escreve `velocity` — devolve a velocidade que quer, e quem combina é
#  a etapa. É o princípio da arquitetura: cada componente é dono do seu estado,
#  o Player combina os resultados.
#
#  Os dois efeitos que transbordam para fora são PEDIDOS, não escritas:
#   • a janela de ROLAMENTO (`pedir_rolamento`) — que o pouso de precisão também
#     usa. Era um campo com dois donos;
#   • a imunidade a dano durante a esquiva, que é meta do corpo.
# ============================================================================

## 8 m em 0,65 s (12,3 m/s) — decisão do dono (03/10/2026, "aumentar a distância
## da rolagem"); era 4,5 m em 0,55 s. Mais curto e mais lento que o dash antigo
## (12 m em 0,28 s): é um rolamento que se vê, não um borrão.
const DISTANCIA := 8.0
const TEMPO := 0.65
const RECARGA := 1.5          # recarga entre rolls (a mesma do dash)
## Invulnerável no começo do roll — a MESMA janela do dash antigo (0,28 s), para o
## balanço do combate não mudar com a troca.
const IMUNE := 0.28
## Trecho do clipe "Sprinting Forward Roll" que o roll toca (mergulho → rolamento
## → levantar; o clipe inteiro tem 1,2 s).
const CLIPE := "res://assets/animations/sprinting_forward_roll.res"
const CLIPE_INICIO := 0.05
const CLIPE_FIM := 1.1
## ESQUIVA DO EPIC FIGHT (12/11/2026) — `DodgeSkill` + `DodgeAnimation` do jar 21.17.3.1. Com uma arma do EF equipada (`modo_ef`), o Q toca o clipe do mod:
##  • sem tecla ou com W/A/D: `roll_forward`, o corpo vira para o rumo pedido; com S: `roll_backward` (o corpo segue olhando para a frente e anda de costas);
##  • o avanço vem do próprio clipe (`Corpo:deslocamento`: 4,6 m em 0,633 s, na curva do clipe — não linear);
##  • invulnerável o clipe INTEIRO (o mod marca o ataque de entidade como MISSED de 0 ao fim) e sem recarga própria — só a estamina limita (4 de 15, já cobrada);
##  • som `roll` no início.
## Sem arma do EF o roll antigo do Mixamo (8 m, 0,65 s) segue igual: é decisão do dono de 03/10/2026 e o balanço da arena depende dele.
## NÃO feitos: encolher a caixa de colisão para 0,6×0,8 durante o clipe; explosão/magia/`BYPASS_DODGE` ainda são evitados (o mod os deixa passar).
const CLIPE_EF_FRENTE := "res://assets/epic_fight/res/ef_roll_forward.res"
const CLIPE_EF_TRAS := "res://assets/epic_fight/res/ef_roll_backward.res"
## Liga o Player a cada quadro: há arma do Epic Fight na mão?
var modo_ef := false
var _ef_ativo := false                # o roll em curso é o do EF (travado no disparo)
var _ef_clipe: Animation = null
var _ef_para_tras := false
var _ef_t := 0.0                      # tempo decorrido do clipe
var _ef_dist := 0.0                   # quanto andar NESTE quadro (m)

## O Q no AR não é mais daqui: virou o `DashNoAr` (15/10/2026) — habilidade comprada,
## com energia e recarga próprias. Este controlador é só o roll do chão.

var _dono: Node3D = null
var _q_antes: bool = false            # borda do Q
var _recarga: float = 0.0             # tempo até poder de novo
var _t: float = 0.0                   # tempo restante do roll
var _direcao: Vector3 = Vector3.FORWARD  # travada no disparo
var _passo: float = 0.0               # quanto do roll cabe NESTE quadro

func montar_em(dono: Node3D) -> void:
	_dono = dono

func ativo() -> bool:      return _t > 0.0
func rolando() -> bool:    return _t > 0.0
func _tempo_total() -> float: return _ef_clipe.length if _ef_ativo and _ef_clipe != null else TEMPO
func direcao() -> Vector3: return _direcao
func passo() -> float:     return _passo
func recarga() -> float:   return _recarga
func tempo() -> float:     return _t

## Caminho do clipe do roll em curso (o do mod ou o do Mixamo).
func clipe() -> String:
	if _ef_ativo:
		return CLIPE_EF_TRAS if _ef_para_tras else CLIPE_EF_FRENTE
	return CLIPE

## Para onde o CORPO olha: no roll de costas do mod ele segue olhando para a frente e anda para trás.
func rumo_do_corpo() -> Vector3:
	return -_direcao if _ef_ativo and _ef_para_tras else _direcao

## 0 no disparo, 1 no fim do roll.
func progresso() -> float:
	return clampf(1.0 - _t / _tempo_total(), 0.0, 1.0) if _t > 0.0 else 0.0

## Tempo do clipe do roll neste quadro.
func tempo_do_clipe() -> float:
	if _ef_ativo and _ef_clipe != null:
		return clampf(_ef_t, 0.0, _ef_clipe.length)
	return lerpf(CLIPE_INICIO, CLIPE_FIM, progresso())

# Chamado uma vez por quadro, ANTES de a etapa escrever `velocity`.
# `bloqueado` = o combate está usando o corpo (carregando, rajada, pistola do
# Yami): não dá para rolar no meio disso.
func atualizar(delta: float, q: MoveFrame, bloqueado: bool) -> void:
	if _recarga > 0.0:
		_recarga = maxf(_recarga - delta, 0.0)

	var q_agora := q.dash_segurado and not _q_antes
	_q_antes = q.dash_segurado
	# Só no CHÃO: fora dele o Q é o dash no ar (`DashNoAr`).
	var no_chao := _dono is CharacterBody3D and (_dono as CharacterBody3D).is_on_floor()
	# ESTAMINA (Epic Fight, 10/11/2026): o roll custa 4 de 15. Sem estamina o Q não rola; a regeneração corre aqui.
	var estamina := Estamina.de(_dono)
	if estamina != null:
		estamina.passar_tempo(delta)
	if q_agora and _recarga <= 0.0 and _t <= 0.0 and not bloqueado and no_chao \
			and (estamina == null or estamina.gastar_habilidade("roll")):
		_ef_ativo = modo_ef
		_ef_para_tras = _ef_ativo and q.f < 0.0
		_ef_clipe = load(CLIPE_EF_TRAS if _ef_para_tras else CLIPE_EF_FRENTE) as Animation if _ef_ativo else null
		if _ef_clipe == null:
			_ef_ativo = false
		_ef_t = 0.0
		_t = _tempo_total()
		_recarga = 0.0 if _ef_ativo else RECARGA
		if _ef_ativo and _dono != null:
			SonsEpicFight.tocar(_dono, _dono.global_position, ["roll"])
		# Direção = TECLA segurada (W frente, D lado, S ré...). Sem tecla nenhuma,
		# a frente da câmera. As duas vêm do yaw puro, sem pitch: o roll é sempre
		# horizontal.
		_direcao = q.dir.normalized() if q.dir.length_squared() > 0.01 else q.frente
		if _dono:
			_dono.pedir_rolamento(TEMPO)
			_dono.set_meta("damage_immune", true)
			# Sem o anel de choque e sem o som do DASH antigo (pedido do dono,
			# 03/10/2026): o roll é só o corpo rolando.

	# Consome o tempo DEPOIS do gatilho, para o disparo já andar neste quadro.
	# `_passo` é quanto do roll cabe no quadro: no último ele é MENOR que o delta.
	_passo = 0.0
	_ef_dist = 0.0
	if _t > 0.0:
		var antes := _t
		_passo = minf(_t, delta)
		_t = maxf(_t - delta, 0.0)
		if _ef_ativo and _ef_clipe != null:
			var t0 := _ef_t
			_ef_t += _passo
			_ef_dist = _deslocamento_do_clipe(_ef_t) - _deslocamento_do_clipe(t0)
		# A invulnerabilidade acaba quando o roll passa de IMUNE (ou acaba); no roll do mod, só no fim do clipe.
		var limite := 0.0 if _ef_ativo else _tempo_total() - IMUNE
		if _dono and antes > limite and _t <= limite:
			_dono.set_meta("damage_immune", false)

# A velocidade que o roll quer neste quadro. Sobrescrever o vetor INTEIRO zera o Y
# de propósito: durante o roll não há gravidade. O fator `_passo/delta` encurta SÓ
# o último quadro (nos demais é 1.0).
func velocidade(delta: float) -> Vector3:
	if _ef_ativo:
		return _direcao * (_ef_dist / delta)
	var por_segundo := DISTANCIA / TEMPO
	return _direcao * por_segundo * (_passo / delta)


## Quanto o clipe do mod já andou (m, sempre positivo) até o tempo `t`: o `Corpo:deslocamento` (x lado, z frente).
func _deslocamento_do_clipe(t: float) -> float:
	for i in _ef_clipe.get_track_count():
		if String(_ef_clipe.track_get_path(i)) == "Corpo:deslocamento":
			var v: Variant = _ef_clipe.value_track_interpolate(i, clampf(t, 0.0, _ef_clipe.length))
			return Vector2((v as Vector3).x, (v as Vector3).z).length() if v is Vector3 else 0.0
	return 0.0
