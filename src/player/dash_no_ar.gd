class_name DashNoAr
extends RefCounted
# ============================================================================
#  DASH NO AR — o Q apertado FORA do chão (15/10/2026).
#
#  Separado do roll (`DashController`, o Q no chão) a pedido do dono: o roll é a
#  esquiva do chão, de graça e sempre liberada; o dash no ar é uma HABILIDADE — no
#  Modo História o jogador a compra do Barba Negra (`CapacidadesDoJogador.can_dash`),
#  gasta energia a cada uso (`custo_dash_no_ar`, 20) e recarrega em 0,1 s.
#
#  Mesma fronteira do roll: este componente NÃO escreve `velocity`. Devolve a que
#  quer e o Player combina. Os números (distância, tempo, imunidade) são os do dash
#  antigo, que morava dentro do roll: 5 m em 0,28 s, sem gravidade, imune o dash
#  inteiro, anel de choque e som. AO TERMINAR o impulso não continua: o Player corta
#  a velocidade horizontal para a de andar (`acabou`).
# ============================================================================

const DISTANCIA := 5.0           # 12 até 07/10, 8 até 08/10/2026 (dono)
const TEMPO := 0.28
## Quatro clipes autorais: o corpo mantém a frente da câmera no disparo.
const CLIPE := "res://assets/animations/dash_aereo/frente.tres"
const CLIPES := {
	"frente": CLIPE,
	"tras": "res://assets/animations/dash_aereo/tras.tres",
	"esquerda": "res://assets/animations/dash_aereo/esquerda.tres",
	"direita": "res://assets/animations/dash_aereo/direita.tres",
}
const CLIPES_ALTERNADOS := {
	"frente": "res://assets/animations/dash_aereo/frente_alternado.tres",
	"tras": "res://assets/animations/dash_aereo/tras_alternado.tres",
	"esquerda": "res://assets/animations/dash_aereo/esquerda_alternado.tres",
	"direita": "res://assets/animations/dash_aereo/direita_alternado.tres",
}
const CLIPE_INICIO := 0.0
const CLIPE_FIM := TEMPO

var _dono: CharacterBody3D = null
var _q_antes := false            # borda do Q
var _recarga := 0.0
var _t := 0.0                    # tempo restante do dash
var _direcao := Vector3.FORWARD  # travada no disparo
var _frente_do_corpo := Vector3.FORWARD
var _clipe := CLIPE
var _proxima_perna_alternada := false
var _passo := 0.0                # quanto do dash cabe NESTE quadro
var _acabou := false             # o dash acabou no quadro anterior


func montar_em(dono: CharacterBody3D) -> void:
	_dono = dono


func ativo() -> bool:    return _t > 0.0
func direcao() -> Vector3: return _direcao
func passo() -> float:   return _passo
func acabou() -> bool:   return _acabou
func recarga() -> float: return _recarga
func frente_do_corpo() -> Vector3: return _frente_do_corpo
func clipe() -> String: return _clipe

## 0 no disparo, 1 no fim do dash.
func progresso() -> float:
	return clampf(1.0 - _t / TEMPO, 0.0, 1.0) if _t > 0.0 else 0.0


## Tempo do clipe neste quadro.
func tempo_do_clipe() -> float:
	return lerpf(CLIPE_INICIO, CLIPE_FIM, progresso())


## Quanto de energia o disparo custa e qual a recarga vêm das capacidades do corpo:
## na arena o custo é 0 e a recarga é a de sempre; na história, os da progressão.
func _capacidades() -> CapacidadesDoJogador:
	if _dono != null and "capacidades" in _dono and _dono.capacidades != null:
		return _dono.capacidades
	return null


## Pode disparar AGORA? (separado de `atualizar` para o teste e a HUD perguntarem.)
func pode_disparar(bloqueado: bool) -> bool:
	if _dono == null or _t > 0.0 or _recarga > 0.0 or bloqueado or _dono.is_on_floor():
		return false
	var cap := _capacidades()
	if cap == null:
		return true
	return cap.can_dash and float(_dono.get("energy")) + 0.001 >= cap.custo_dash_no_ar


# Uma vez por quadro, ANTES de a etapa escrever `velocity`.
func atualizar(delta: float, q: MoveFrame, bloqueado: bool, mira_3d: Vector3 = Vector3.ZERO) -> void:
	var andava := _passo > 0.0
	_recarga = maxf(_recarga - delta, 0.0)
	var q_agora := q.dash_segurado and not _q_antes
	_q_antes = q.dash_segurado
	if q_agora and pode_disparar(bloqueado):
		var cap := _capacidades()
		if cap != null and cap.custo_dash_no_ar > 0.0:
			_dono.call("gastar_energia", cap.custo_dash_no_ar)
		_t = TEMPO
		_recarga = cap.recarga_dash_no_ar if cap != null else 1.5
		# W/S usam a inclinação da mira; A/D permanecem laterais à câmera.
		# Com Q sozinho, avança pela mira. O vetor final é normalizado, inclusive
		# nas diagonais, e fica travado até o fim do impulso.
		var pedido := q.dir
		if mira_3d.length_squared() > 0.01:
			if absf(q.f) > 0.01 or absf(q.r) > 0.01:
				pedido = mira_3d.normalized() * q.f + q.direita * q.r
			elif q.dir.length_squared() <= 0.01:
				pedido = mira_3d.normalized()
			if absf(pedido.y) > 0.97 and absf(q.r) < 0.01:
				pedido = Vector3.UP * signf(pedido.y)
		_direcao = pedido.normalized() if pedido.length_squared() > 0.01 else q.frente.normalized()
		_frente_do_corpo = q.frente.normalized()
		var frente := q.f if absf(q.f) > 0.01 else _direcao.dot(q.frente)
		var lado := q.r if absf(q.r) > 0.01 else _direcao.dot(q.direita)
		var nome := ("direita" if lado > 0.0 else "esquerda") if absf(lado) > absf(frente) else ("frente" if frente >= 0.0 else "tras")
		_clipe = CLIPES_ALTERNADOS[nome] if _proxima_perna_alternada else CLIPES[nome]
		_proxima_perna_alternada = not _proxima_perna_alternada
		# Anel de choque e som: LOCAIS, como sempre foram (o dash não tem RPC).
		_dono.set_meta("damage_immune", true)
		var cena := _dono.get_tree().current_scene
		FxUtil.dash_effect(cena, _dono.global_position, _direcao)
		AudioFX.dash(cena, _dono.global_position, randf_range(0.94, 1.06))

	_passo = 0.0
	if _t > 0.0:
		_passo = minf(_t, delta)
		_t = maxf(_t - delta, 0.0)
		if _t <= 0.0:
			_dono.set_meta("damage_immune", false)   # a janela é o dash inteiro
	# Andou até o quadro anterior e parou agora: aqui o Player corta o impulso.
	_acabou = andava and _passo <= 0.0


## A velocidade 3D que o dash quer neste quadro, sem gravidade. `_passo/delta`
## encurta SÓ o último quadro.
func velocidade(delta: float) -> Vector3:
	return _direcao * (DISTANCIA / TEMPO) * (_passo / delta)


## Cancela no meio (pouso, morte, água) e solta a imunidade.
func cancelar() -> void:
	if _t > 0.0 and _dono != null:
		_dono.set_meta("damage_immune", false)
	_t = 0.0
	_passo = 0.0
