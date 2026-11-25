class_name BonecoDeDuelo
extends CharacterBody3D
# ============================================================================
#  BONECO DE DUELO — um oponente com o MESMO corpo e o MESMO executor do jogador.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D1). Existe porque defesa, reação por
#  lado e contato entre dois corpos não se testam contra um alvo que não luta. É
#  também a base dos inimigos com combate direcional do Modo História.
#
#  • Corpo: o `PlayerRig` monta o `base_v2` exatamente como no jogador (mesmo
#    encaixe, mesmo animador), então pose, IK e efetor medem o mesmo.
#  • Decisão: NENHUMA aqui. Quem quiser que ele lute chama
#    `combate_direcional.pedir_ataque(...)`, `encarar(...)` e `andar(...)`
#    (`CerebroDeTreino` no F8; `CerebroDeInimigo` quando é inimigo do mapa).
#
#  ⚠️ Não cita `Player` por nome: um script de teste (`godot -s`) que usa este
#  boneco compilaria o Player antes dos autoloads (armadilha do test_modo_historia).
# ============================================================================

signal derrotado(boneco: BonecoDeDuelo)

## Mesmo tamanho do colisor do Player (`Player.COLISOR_BASE`), repetido pela razão
## do cabeçalho. GATILHO: se o do Player mudar, mudar aqui (o teste confere).
const COLISOR := Vector3(1.0, 1.6, 1.0)
## Raio da cápsula — o mesmo `Player.RAIO_DA_CAPSULA` do Modo História (0,5: a mesma
## distância entre lutadores da caixa antiga).
const RAIO_DA_CAPSULA := 0.5
const GRAVIDADE := 32.0            # a mesma do Player
const VELOCIDADE_DE_GIRO := 12.0   # quão rápido o corpo encara quem mandaram encarar
const ESTILO_PADRAO := "res://src/combat/direcional/estilos/boxe.tres"

@export var vida_maxima := 250.0
## Quanto os golpes do boneco machucam, sobre o dano da ficha. 0,1 = a escala de
## inimigo comum contra o jogador da história (plano, §7.4: 2/3/5 contra vida 20).
## 10/11/2026 (pedido do dono, duas vezes): 0,1 → 0,3 → 0,5. Com a campanha em 0,5 o bandido tira ~7 por golpe de 32 de vida (~5 golpes para matar).
@export var multiplicador_de_dano := 0.5   # 10/11/2026: 0,5 restaurado às 20:17 (ver `JogadorDoMod.ESCALA_DO_GOLPE_DE_MOB`)

var health := 0.0
var max_health := 0.0
## Mesmo nome de campo do Player: é por ele que o golpe de outro executor acha a
## defesa deste corpo (`alvo.get("combate_direcional")`).
var combate_direcional: ExecutorCorpoACorpo = null

var _rig: PlayerRig
var _yaw_alvo := 0.0
var _empurrao := Vector3.ZERO
## Acima deste empurrão horizontal (m/s) o corpo está estontado: não anda por conta própria até ele decair (~0,3 s num golpe
## leve). Antes a caminhada somava ao empurrão e um inimigo andando para o jogador a ≥ 2 m/s ficava parado ao ser acertado.
const ESTONTEADO := 1.5
var _salto := 0.0
var _andar := Vector3.ZERO


func _ready() -> void:
	add_to_group("enemy")
	add_to_group(AlvosDeGolpe.GRUPO)
	max_health = vida_maxima
	health = vida_maxima
	# Cápsula, como o jogador do Modo História (01/10/2026): o boneco só existe lá, e
	# os dois corpos têm que pisar o relevo do mesmo jeito (com caixa ele flutuaria
	# nas encostas e empacaria em beirada que o jogador vence).
	var col := CollisionShape3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = RAIO_DA_CAPSULA
	forma.height = COLISOR.y
	col.shape = forma
	add_child(col)
	# Golpes acertam a caixa de antes (ver HurtboxDeCombate).
	HurtboxDeCombate.instalar(self, COLISOR)

	_rig = PlayerRig.new()
	_rig.name = "Rig"
	add_child(_rig)
	_rig.montar_em(self)
	_rig.montar("base")

	var executor := ExecutorCorpoACorpo.new()
	executor.name = "CombateDirecional"
	executor.montar(AtorBoneco.new(self), load(ESTILO_PADRAO) as EstiloCorpoACorpo)
	executor.multiplicador_de_dano = multiplicador_de_dano
	add_child(executor)   # por último: roda depois do corpo e do animador no quadro
	combate_direcional = executor
	var apresentacao := ApresentacaoDeCombate.new()
	apresentacao.name = "ApresentacaoDeCombate"
	executor.add_child(apresentacao)
	apresentacao.montar(executor)


func modelo_visual() -> Node3D:
	return _rig.modelo() if _rig != null else null


## Vira o corpo para `ponto` (com o teto de giro do golpe em curso).
func encarar(ponto: Vector3) -> void:
	var d := ponto - global_position
	d.y = 0.0
	if d.length_squared() > 0.0001:
		_yaw_alvo = RosaDosVentos.yaw_para(d.normalized())


## Zera empurrão e velocidade. Teletransportar sem isto deixa o knockback do golpe
## anterior arrastando o corpo para longe da posição nova (visto no teste, 16/09).
func parar() -> void:
	_empurrao = Vector3.ZERO
	_andar = Vector3.ZERO
	velocity = Vector3.ZERO


## Velocidade de caminhada pedida (m/s, no plano). Vale até o próximo pedido: quem
## decide pede a cada quadro, e `Vector3.ZERO` para. O golpe e a guarda freiam pela
## ficha (`fator_de_movimento`), como no jogador.
func andar(velocidade_no_plano: Vector3) -> void:
	_andar = Vector3(velocidade_no_plano.x, 0.0, velocidade_no_plano.z)


## Encara uma direção de yaw já pronta (radianos, convenção do Player).
func encarar_yaw(yaw: float) -> void:
	_yaw_alvo = yaw


func _physics_process(delta: float) -> void:
	var t := Cronometro.ini()
	_physics_process_corpo(delta)
	Cronometro.fim(&"Corpo.fisica", t)


func _physics_process_corpo(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVIDADE * delta
	var caminhada := _andar * (combate_direcional.fator_de_movimento() if combate_direcional != null else 1.0) \
		* Lentidao.fator(self)          # lentidão de skill do Builder
	if Vector2(_empurrao.x, _empurrao.z).length() > ESTONTEADO:
		caminhada = Vector3.ZERO        # estontado: o empurrão manda (senão a caminhada o anulava e o alvo "não saía do lugar")
	velocity.x = _empurrao.x + caminhada.x
	velocity.z = _empurrao.z + caminhada.z
	if _salto > 0.0:
		velocity.y = _salto
		_salto = 0.0
	_empurrao = _empurrao.move_toward(Vector3.ZERO, 14.0 * delta)
	if combate_direcional != null:
		velocity += combate_direcional.impulso_do_quadro()
	EscaladaDeMob.ajudar(self, delta)
	move_and_slide()
	HurtboxDeCombate.sincronizar(self)   # hurtbox no lugar NESTE quadro

	var modelo := modelo_visual()
	if modelo != null:
		var atual := modelo.rotation.y
		var passo := wrapf(lerp_angle(atual, _yaw_alvo, clampf(VELOCIDADE_DE_GIRO * delta, 0.0, 1.0)) - atual, -PI, PI)
		var teto := combate_direcional.giro_maximo() * delta if combate_direcional != null else INF
		modelo.rotation.y = atual + clampf(passo, -teto, teto)
	var animador := _rig.procedural() if _rig != null else null
	if animador != null:
		animador.update(velocity, is_on_floor(), false, delta, 0.0)


## Esquiva com dash contra a Buki Buki (22/11/2026): lado, recarga de 3 s e efeito em `EsquivaDeDisparo`; o impulso entra no `_empurrao`.
func esquivar_de_disparo(rumo: Vector3, _chegada_em := 0.0) -> bool:
	if health <= 0.0 or not is_on_floor():
		return false
	var lateral := EsquivaDeDisparo.tentar(self, rumo)
	if lateral == Vector3.ZERO:
		return false
	_empurrao += lateral * EsquivaDeDisparo.IMPULSO
	return true


## Mesma assinatura do Player e dos inimigos: é o que o `CombatResolver` chama.
func take_damage(amount: float, _attacker_pos: Vector3 = Vector3.ZERO,
		base_knockback: Vector3 = Vector3.ZERO, _hitstun_duration: float = 0.3) -> void:
	if health <= 0.0:
		return
	IaUnificada.acordar_por_dano(self)      # IA unificada: levar dano acorda (10/11/2026)
	health = maxf(health - amount, 0.0)
	if amount > 0.0:
		FxUtil.flash_dano(modelo_visual())
		if is_inside_tree():
			FxUtil.damage_number(get_tree().current_scene, global_position + Vector3.UP * 1.7, amount, Color(1.0, 0.75, 0.2))
	_empurrao += Vector3(base_knockback.x, 0.0, base_knockback.z)
	if Vector2(base_knockback.x, base_knockback.z).length() < 0.1 and amount > 0.0:
		_empurrao += KnockbackMinecraft.padrao(self, _attacker_pos)      # golpe cru: o empurrão do Minecraft
	# Empurrão para CIMA (o Air Strike da Rocket lança o alvo): entra como impulso no
	# quadro seguinte, não como deslocamento contínuo — quem traz de volta é a gravidade.
	if base_knockback.y > 0.0:
		_salto = maxf(_salto, base_knockback.y)
	if health <= 0.0:
		_concluir_derrota()


func _concluir_derrota() -> void:
	if combate_direcional != null:
		combate_direcional.cancelar(&"derrotado")
	derrotado.emit(self)
