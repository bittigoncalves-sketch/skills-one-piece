class_name McMovimento
extends RefCounted
# ============================================================================
#  MOVIMENTAÇÃO DO MINECRAFT 1.20.1, traduzida (31/10/2026). Fonte: o jar do cliente que o
#  CurseForge instalou, remapeado com os nomes oficiais e decompilado (não vai para o git):
#    LivingEntity.aiStep / travel / jumpFromGround / handleRelativeFrictionAndCalculateMovement
#    Entity.move / moveRelative / getInputVector · Player.getFlyingSpeed / travel (nado)
#    LocalPlayer.aiStep (entrada ×0,98, agachar ×0,3, regra da corrida)
#
#  PURO: sem nós, sem física do Godot. Unidades do Minecraft — BLOCOS e TICKS (20/s). Quem
#  quer metros do Godot converte com `para_metros_por_segundo`. A colisão NÃO mora aqui (é a
#  do corpo do Godot): o módulo devolve o deslocamento que o tick PEDE, e no tick seguinte
#  recebe, em `Ambiente`, o que o corpo conseguiu (bateu de lado? no chão? subiu a quê?).
#  Isso preserva a ordem do Minecraft — pedir → mover → arrasto/gravidade — sem reescrever
#  a colisão: `Entity.move` zera o eixo bloqueado, e é isso que `colisao_*` informa.
#
#  Um tick (`avancar`):
#    1. fecha o tick anterior (o que vem DEPOIS do `move` no `travel`): bloqueios, gravidade,
#       arrasto, escalada, fator de velocidade do bloco;
#    2. abre este: contagem do pulo, pulo, entrada (×0,98), `moveRelative`, escalada;
#    3. devolve o deslocamento a mover.
# ============================================================================

const GRAVIDADE := 0.08
const GRAVIDADE_QUEDA_LENTA := 0.01
const ARRASTO_VERTICAL := 0.98
const ARRASTO_DO_AR := 0.91
const ATRITO_PADRAO := 0.6
## Atrito de alguns blocos (Blocks.java). Quem não está aqui usa ATRITO_PADRAO.
const ATRITO_GELO := 0.98
const ATRITO_GELO_AZUL := 0.989
const ATRITO_SLIME := 0.8
## `Block.getSpeedFactor` / `getJumpFactor` (alma de areia e mel).
const FATOR_VEL_ALMA_DE_AREIA := 0.4
const FATOR_VEL_MEL := 0.4
const FATOR_PULO_MEL := 0.5

const VELOCIDADE_BASE_JOGADOR := 0.1            # atributo movement_speed
const BONUS_CORRIDA := 0.3                      # modificador multiply_total do sprint
const VOO_NO_AR := 0.02
const VOO_NO_AR_CORRENDO := 0.025999999
const FATOR_CHAO := 0.21600002
const FORCA_DO_PULO := 0.42
const IMPULSO_PULO_CORRENDO := 0.2
const ATRASO_DO_PULO := 10
const ENTRADA_ATRITO := 0.98                    # xxa/zza *= 0.98 a cada tick
const FATOR_AGACHAR := 0.3
const IMPULSO_MIN_PARA_CORRER := 0.8
const LIMITE_VELOCIDADE_ZERO := 0.003

# Água / lava / escada (travel).
const ARRASTO_DA_AGUA := 0.8
const ARRASTO_DA_AGUA_CORRENDO := 0.9
const VOO_NA_AGUA := 0.02
const ARRASTO_DA_AGUA_ESTRIDE := 0.54600006
const SUBIDA_NA_AGUA := 0.04
const DESCIDA_NA_AGUA := 0.04
const ALTURA_PULO_FLUIDO := 0.4
const LIMITE_ESCADA := 0.15
const SUBIDA_ESCADA := 0.2
const SAIDA_DA_AGUA := 0.3                      # empurrão ao bater na margem com espaço livre

# --- entrada do tick (o dono escreve antes de `avancar`) ----------------------------------
var frente := 0.0               # forwardImpulse: -1..1 (W +1)
var lado := 0.0                 # leftImpulse:    -1..1 (A +1 — esquerda é positivo no Minecraft)
var pulo := false               # tecla de pulo segurada
var agachar := false
var correr_pedido := false      # tecla de corrida segurada
var yaw := 0.0                  # graus do Minecraft (0 = +Z, 90 = −X); ver `yaw_do_godot`
var pitch := 0.0                # graus; só o nado usa
var velocidade := VELOCIDADE_BASE_JOGADOR  # atributo movement_speed SEM o bônus de corrida

# --- estado -------------------------------------------------------------------------------
var delta := Vector3.ZERO       # deltaMovement, blocos/tick
var correndo := false
var atraso_do_pulo := 0
var _pendente := false          # há um `move` do tick anterior a fechar
var _fric := ATRITO_PADRAO
var _estava_no_chao := false
var _caindo := false             # deltaMovement.y <= 0 ao abrir o tick (queda lenta, fluido)


## O que o mundo diz neste tick. Valores padrão = ar livre sobre bloco comum.
class Ambiente:
	extends RefCounted
	var no_chao := false
	## Resultado do `move` do tick anterior: o corpo foi barrado no eixo?
	var colisao_x := false
	var colisao_z := false
	var colisao_vertical := false
	var colisao_horizontal_leve := false        # `minorHorizontalCollision` (degrau baixo)
	## Parede não alinhada aos eixos (o relevo tem platôs girados): a velocidade perde só a
	## componente que ENTRA na parede, como o corpo do Godot desliza. ZERO = usar os flags.
	var parede_normal := Vector3.ZERO
	var atrito_bloco := ATRITO_PADRAO           # do bloco sob o corpo (+0,5 de margem)
	var fator_velocidade_bloco := 1.0           # alma de areia, mel…
	var fator_pulo_bloco := 1.0
	var na_agua := false
	var na_lava := false
	var sob_a_agua := false                     # olhos na água (nadando de verdade)
	var altura_fluido := 0.0                    # quanto do corpo está submerso (blocos)
	var escalavel := false                      # escada, trepadeira…
	var livre_para_sair_da_agua := false        # `isFree(x, y+0,6−y0, z)`: há onde subir
	var presa := Vector3.ZERO                   # teia (0,25;0,05;0,25), amora…; ZERO = livre
	var multiplicador_pulo := 1.0               # passivas do jogo sobre a força do pulo
	var efeito_pulo := 0                        # nível do Jump Boost (0 = sem)
	var queda_lenta := false
	var levitacao := -1                         # nível−1 do efeito (−1 = sem)
	var sem_gravidade := false
	var olhando_y := 0.0                        # componente Y do vetor de visão (nado)
	var nadando := false                        # pose de nado (corrida na água)


static func atrito_do_bloco(id: StringName) -> float:
	match id:
		&"minecraft:ice", &"minecraft:packed_ice", &"minecraft:frosted_ice":
			return ATRITO_GELO
		&"minecraft:blue_ice":
			return ATRITO_GELO_AZUL
		&"minecraft:slime_block":
			return ATRITO_SLIME
	return ATRITO_PADRAO


static func fator_velocidade_do_bloco(id: StringName) -> float:
	match id:
		&"minecraft:soul_sand", &"minecraft:honey_block":
			return FATOR_VEL_ALMA_DE_AREIA
	return 1.0


static func fator_pulo_do_bloco(id: StringName) -> float:
	return FATOR_PULO_MEL if id == &"minecraft:honey_block" else 1.0


## Godot: rotation.y (rad, 0 = −Z, anti-horário visto de cima) → yaw do Minecraft (graus).
## `McEntidade` usa a mesma conta (180° − rotação), com os eixos X/Z iguais aos do Godot.
static func yaw_do_godot(rotacao_y: float) -> float:
	return 180.0 - rad_to_deg(rotacao_y)


## blocos/tick → m/s do Godot.
static func para_metros_por_segundo(v: Vector3) -> Vector3:
	return v * (20.0 * MundoMinePiece.METROS_POR_BLOCO)


## m/s do Godot → blocos/tick.
static func de_metros_por_segundo(v: Vector3) -> Vector3:
	return v / (20.0 * MundoMinePiece.METROS_POR_BLOCO)


func velocidade_efetiva() -> float:
	return velocidade * (1.0 + BONUS_CORRIDA) if correndo else velocidade


## `Player.getFlyingSpeed`.
func _velocidade_no_ar() -> float:
	return VOO_NO_AR_CORRENDO if correndo else VOO_NO_AR


# ------------------------------------------------------------------------------------------
#  O tick
# ------------------------------------------------------------------------------------------
## Devolve o deslocamento (blocos) que este tick pede ao `move` do corpo.
func avancar(a: Ambiente) -> Vector3:
	if _pendente:
		_fechar_tick(a)
	_atualizar_corrida(a)

	# --- LivingEntity.aiStep ---
	if atraso_do_pulo > 0:
		atraso_do_pulo -= 1
	var d := delta
	delta = Vector3(0.0 if absf(d.x) < LIMITE_VELOCIDADE_ZERO else d.x,
		0.0 if absf(d.y) < LIMITE_VELOCIDADE_ZERO else d.y,
		0.0 if absf(d.z) < LIMITE_VELOCIDADE_ZERO else d.z)

	_tratar_pulo(a)

	# Entrada: LocalPlayer.input.tick (agachar ×0,3) e aiStep (×0,98).
	var f := frente
	var l := lado
	if agachar:
		f *= FATOR_AGACHAR
		l *= FATOR_AGACHAR
	f *= ENTRADA_ATRITO
	l *= ENTRADA_ATRITO

	# --- LivingEntity.travel (parte de antes do `move`) ---
	_fric = a.atrito_bloco
	_estava_no_chao = a.no_chao
	_caindo = delta.y <= 0.0
	var entrada := Vector3(l, 0.0, f)         # (x = esquerda, z = frente), como o `Vec3` do jogo
	var gravidade := GRAVIDADE_QUEDA_LENTA if (a.queda_lenta and _caindo) else GRAVIDADE

	if a.na_agua and not a.na_lava:
		_pre_agua(a, entrada)
	elif a.na_lava:
		_pre_lava(entrada)
	else:
		var v_rel := _velocidade_efetiva_do_chao(a)
		_mover_relativo(v_rel, entrada)
		delta = _na_escada(a, delta)
	_pendente = true
	_gravidade_do_tick = gravidade
	_ramo = 1 if (a.na_agua and not a.na_lava) else (2 if a.na_lava else 0)
	return delta


var _gravidade_do_tick := GRAVIDADE
var _ramo := 0                  # 0 = chão/ar, 1 = água, 2 = lava


func _velocidade_efetiva_do_chao(a: Ambiente) -> float:
	# getFrictionInfluencedSpeed
	if a.no_chao:
		return velocidade_efetiva() * (FATOR_CHAO / (a.atrito_bloco * a.atrito_bloco * a.atrito_bloco))
	return _velocidade_no_ar()


## `Entity.moveRelative` + `getInputVector`: a entrada é normalizada se passar de 1, escalada
## pela velocidade e girada pelo yaw.
func _mover_relativo(vel: float, entrada: Vector3) -> void:
	var q := entrada.length_squared()
	if q < 1.0e-7:
		return
	var v := (entrada.normalized() if q > 1.0 else entrada) * vel
	var s := sin(deg_to_rad(yaw))
	var c := cos(deg_to_rad(yaw))
	delta += Vector3(v.x * c - v.z * s, v.y, v.z * c + v.x * s)


func _na_escada(a: Ambiente, v: Vector3) -> Vector3:
	if not a.escalavel:
		return v
	var x := clampf(v.x, -LIMITE_ESCADA, LIMITE_ESCADA)
	var z := clampf(v.z, -LIMITE_ESCADA, LIMITE_ESCADA)
	var y := maxf(v.y, -LIMITE_ESCADA)
	if y < 0.0 and agachar:
		y = 0.0                              # agachado na escada: não desliza
	return Vector3(x, y, z)


func _pre_agua(a: Ambiente, entrada: Vector3) -> void:
	# Player.travel: nadando, o vertical segue o olhar.
	if a.nadando:
		var olhar := a.olhando_y
		var k := 0.085 if olhar < -0.2 else 0.06
		if olhar <= 0.0 or pulo or a.livre_para_sair_da_agua:
			delta += Vector3(0.0, (olhar - delta.y) * k, 0.0)
	# EnchantmentHelper.getDepthStrider = 0 (sem encantamentos no jogo, por ora).
	_mover_relativo(VOO_NA_AGUA, entrada)


func _pre_lava(entrada: Vector3) -> void:
	_mover_relativo(0.02, entrada)


func _tratar_pulo(a: Ambiente) -> void:
	if not pulo:
		atraso_do_pulo = 0
		return
	var fluido := a.altura_fluido
	var na_agua_de_fato := a.na_agua and fluido > 0.0
	if na_agua_de_fato and not (a.no_chao and not (fluido > ALTURA_PULO_FLUIDO)):
		delta += Vector3(0.0, SUBIDA_NA_AGUA, 0.0)                     # jumpInLiquid(WATER)
	elif a.na_lava and not (a.no_chao and not (fluido > ALTURA_PULO_FLUIDO)):
		delta += Vector3(0.0, SUBIDA_NA_AGUA, 0.0)                     # jumpInLiquid(LAVA)
	elif (a.no_chao or (na_agua_de_fato and fluido <= ALTURA_PULO_FLUIDO)) and atraso_do_pulo == 0:
		_pular_do_chao(a)
		atraso_do_pulo = ATRASO_DO_PULO


## `LivingEntity.jumpFromGround` + `getJumpPower`.
func _pular_do_chao(a: Ambiente) -> void:
	var forca := FORCA_DO_PULO * a.fator_pulo_bloco * a.multiplicador_pulo + 0.1 * float(a.efeito_pulo)
	delta.y = forca
	if correndo:
		var r := deg_to_rad(yaw)
		delta += Vector3(-sin(r) * IMPULSO_PULO_CORRENDO, 0.0, cos(r) * IMPULSO_PULO_CORRENDO)


## `LocalPlayer.aiStep`: quando a corrida começa e quando acaba.
func _atualizar_corrida(a: Ambiente) -> void:
	var impulso := frente >= IMPULSO_MIN_PARA_CORRER
	if not correndo:
		if correr_pedido and impulso and not agachar and (a.no_chao or a.sob_a_agua) \
				and not (a.na_agua and not a.sob_a_agua):
			correndo = true
	else:
		var para := frente <= 0.00001 or (a.colisao_x or a.colisao_z) and not a.colisao_horizontal_leve \
			or (a.na_agua and not a.sob_a_agua)
		if para:
			correndo = false


## O que vem depois do `move` no `travel` (e no fim de `Entity.move`).
func _fechar_tick(a: Ambiente) -> void:
	_pendente = false
	# Entity.move: eixo bloqueado perde a velocidade; teto/chão zeram o vertical
	# (Block.updateEntityAfterFallOn).
	if a.parede_normal != Vector3.ZERO:
		var entra := delta.dot(a.parede_normal)
		if entra < 0.0:
			delta -= a.parede_normal * entra
	else:
		if a.colisao_x:
			delta.x = 0.0
		if a.colisao_z:
			delta.z = 0.0
	if a.colisao_vertical:
		delta.y = 0.0
	if a.presa != Vector3.ZERO:                 # makeStuckInBlock: o corpo para e anda devagar
		delta = Vector3.ZERO
	# Entity.move: getBlockSpeedFactor multiplica x/z.
	delta.x *= a.fator_velocidade_bloco
	delta.z *= a.fator_velocidade_bloco

	match _ramo:
		1:
			_pos_agua(a)
		2:
			_pos_lava(a)
		_:
			_pos_chao(a)


func _pos_chao(a: Ambiente) -> void:
	var y := delta.y
	# Escalar: encostar na parede ou pular numa escada sobe 0,2.
	if (a.colisao_x or a.colisao_z or pulo) and a.escalavel:
		y = SUBIDA_ESCADA
	if a.levitacao >= 0:
		y += (0.05 * float(a.levitacao + 1) - y) * 0.2
	elif not a.sem_gravidade:
		y -= _gravidade_do_tick
	var k := _fric * ARRASTO_DO_AR if _estava_no_chao else ARRASTO_DO_AR
	delta = Vector3(delta.x * k, y * ARRASTO_VERTICAL, delta.z * k)


func _pos_agua(a: Ambiente) -> void:
	var arrasto := ARRASTO_DA_AGUA_CORRENDO if correndo else ARRASTO_DA_AGUA
	var v := delta
	if (a.colisao_x or a.colisao_z) and a.escalavel:
		v.y = 0.2
	v = Vector3(v.x * arrasto, v.y * 0.8, v.z * arrasto)
	v = _queda_no_fluido(v, a)
	delta = v
	if (a.colisao_x or a.colisao_z) and a.livre_para_sair_da_agua:
		delta.y = SAIDA_DA_AGUA


func _pos_lava(a: Ambiente) -> void:
	var v := delta
	if a.altura_fluido <= ALTURA_PULO_FLUIDO:
		v = Vector3(v.x * 0.5, v.y * 0.8, v.z * 0.5)
		v = _queda_no_fluido(v, a)
	else:
		v *= 0.5
	if not a.sem_gravidade:
		v.y -= _gravidade_do_tick / 4.0
	delta = v
	if (a.colisao_x or a.colisao_z) and a.livre_para_sair_da_agua:
		delta.y = SAIDA_DA_AGUA


## `LivingEntity.getFluidFallingAdjustedMovement`.
func _queda_no_fluido(v: Vector3, a: Ambiente) -> Vector3:
	if a.sem_gravidade or correndo:
		return v
	var caindo := _caindo
	var novo: float
	if caindo and absf(v.y - 0.005) >= 0.003 and absf(v.y - _gravidade_do_tick / 16.0) < 0.003:
		novo = -0.003
	else:
		novo = v.y - _gravidade_do_tick / 16.0
	return Vector3(v.x, novo, v.z)
