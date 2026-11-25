class_name MovimentoMinecraft
extends RefCounted
# ============================================================================
#  MOVIMENTAÇÃO DO MINECRAFT NO JOGADOR (31/10/2026). Decisão do dono: "base vanilla +
#  habilidades por cima" — andar, correr, agachar, pular, cair e a inércia (ar 0,91, atrito
#  do bloco) são os do Minecraft 1.20.1; geppo, wall run, escalada, esquiva e as técnicas
#  continuam mandando quando estão ativas (é a única locomoção de chão/ar desde 31/10/2026), na mesma ordem de precedência da etapa.
#
#  É a PONTE entre `McMovimento` (puro, blocos/ticks, 20 Hz) e o `CharacterBody3D`:
#    • roda a simulação em ticks de 0,05 s (acumulador) e expõe o deslocamento do tick
#      corrente como velocidade contínua (m/s) para os quadros do `move_and_slide`;
#    • devolve ao módulo o que o corpo conseguiu (parede, chão, teto) no quadro anterior;
#    • aceita impulso externo: se outro sistema (geppo, vault, knockback já somado antes)
#      mudou a velocidade, o módulo adota o valor em vez de brigar com ele.
#  Não escreve `velocity` sozinho — recebe e devolve, como os outros componentes do Player.
#
#  LIMITES CONHECIDOS (gatilhos para revisitar):
#    • atrito/velocidade/pulo do BLOCO: hoje padrão (0,6). Quando o relevo em blocos expuser o
#      id do bloco sob os pés, ligar `McMovimento.atrito_do_bloco` em `_ambiente`.
#    • água e escada: o módulo sabe (testado), mas o jogo tem controle de água próprio
#      (`jogador_na_agua.gd`) e a escalada do parkour — continuam deles até serem migrados.
# ============================================================================

const TICK := 0.05
const MAX_TICKS_POR_QUADRO := 3
## Teto da velocidade vertical (m/s) adotada de fora: geppo 15, vault 11, mergulho esmagador ~60.
const LIMITE_ADOCAO_Y := 60.0

var _m := McMovimento.new()
var _acum := 0.0
var _ativo_antes := false
var _y_registrado := 0.0         # velocity.y no fim do quadro anterior (depois do move_and_slide)
var _tem_registro := false
var _mult_pulo := 1.0            # passivas de fruta que mudam o pulo (1,0 = Minecraft puro)
var _pulo_pendente := false      # toque curto de Espaço entre dois ticks não se perde
var _desloc := Vector3.ZERO      # deslocamento do tick corrente (blocos)


func correndo() -> bool:
	return _m.correndo


## Estado exposto para testes e HUD.
func estado() -> McMovimento:
	return _m


## `gravidade_legada`: a gravidade que a etapa ainda subtrai de `velocity.y` no ar (m/s²).
## `mult`: multiplicador de velocidade vindo do resto do jogo (buffs, lentidões), 1,0 = padrão.
## `no_chao`/`teto`/`parede`: o que o corpo achou no `move_and_slide` do quadro anterior.
func velocidade(delta: float, dono: CharacterBody3D, q: MoveFrame, vel_atual: Vector3, mult: float,
		agachado: bool, gravidade_legada: float, mult_pulo := 1.0) -> Vector3:
	if not _ativo_antes:
		# Entrou agora (vinha de dash, pouso de skill…): continua do que o corpo já fazia.
		_m = McMovimento.new()
		_m.delta = McMovimento.de_metros_por_segundo(vel_atual)
		_acum = TICK                      # tica já no primeiro quadro: sem quadro "parado"
		_pulo_pendente = false
		_desloc = _m.delta
	_ativo_antes = true

	# Escrita vertical de FORA (geppo, vault, pulinho do knockback, mergulho): o vanilla não a
	# conhece, então ela é ADOTADA. Distingue-se pelo que se esperava: o fim do quadro anterior
	# menos a gravidade da locomoção antiga (que a etapa ainda aplica no ar). Limitada, para que
	# um teletransporte (velocidade absurda por um quadro) não vire um foguete.
	if _tem_registro:
		var esperado := _y_registrado - (gravidade_legada * delta if not dono.is_on_floor() else 0.0)
		if absf(vel_atual.y - esperado) > 0.5:
			_m.delta.y = clampf(vel_atual.y, -LIMITE_ADOCAO_Y, LIMITE_ADOCAO_Y) / (20.0 * MundoMinePiece.METROS_POR_BLOCO)
			_desloc.y = _m.delta.y

	_pulo_pendente = _pulo_pendente or q.espaco_agora
	_mult_pulo = mult_pulo
	_preparar_entrada(dono, q, mult, agachado)
	_acum = minf(_acum + delta, TICK * MAX_TICKS_POR_QUADRO)
	var ticks := 0
	while _acum >= TICK and ticks < MAX_TICKS_POR_QUADRO:
		_acum -= TICK
		ticks += 1
		_desloc = _m.avancar(_ambiente(dono))
		_pulo_pendente = false

	var v := McMovimento.para_metros_por_segundo(_desloc)
	return v


## Chamado no fim da `_etapa_mover`, com a velocidade que o `move_and_slide` deixou.
func registrar(vel_final: Vector3) -> void:
	_y_registrado = vel_final.y
	_tem_registro = true


## Chamado quando outro ramo da locomoção assumiu o corpo: o próximo quadro reentra "do zero".
func soltar() -> void:
	_ativo_antes = false
	_tem_registro = false


func _preparar_entrada(dono: CharacterBody3D, q: MoveFrame, mult: float, agachado: bool) -> void:
	var anda := q.dir.length_squared() > 0.01
	_m.frente = q.f if anda else 0.0
	_m.lado = -q.r if anda else 0.0           # Minecraft: esquerda é positivo
	_m.pulo = q.espaco_segurado or _pulo_pendente
	_m.agachar = agachado
	_m.correr_pedido = q.sprint
	_m.velocidade = McMovimento.VELOCIDADE_BASE_JOGADOR * mult
	_m.yaw = rad_to_deg(atan2(-q.frente.x, q.frente.z))


## O que o corpo achou no quadro anterior, no vocabulário do Minecraft.
func _ambiente(dono: CharacterBody3D) -> McMovimento.Ambiente:
	var a := McMovimento.Ambiente.new()
	a.multiplicador_pulo = _mult_pulo
	a.no_chao = dono.is_on_floor()
	if dono.is_on_wall():
		var n := dono.get_wall_normal()
		a.parede_normal = Vector3(n.x, 0.0, n.z).normalized()
		a.colisao_x = absf(n.x) > 0.3
		a.colisao_z = absf(n.z) > 0.3
	a.colisao_vertical = dono.is_on_ceiling() or (dono.is_on_floor() and _desloc.y < 0.0)
	return a
