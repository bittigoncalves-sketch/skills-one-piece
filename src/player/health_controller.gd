class_name HealthController
extends RefCounted
# ============================================================================
#  VIDA, ENERGIA E EMPURRÃO.
#
#  Fase 8 de docs/ARQUITETURA_PLAYER.md — e a mais importante em conceito, não
#  em linhas. É aqui que o diagrama que ABRIU esta refatoração vira código:
#
#      MovementController  →  velocidade do movimento
#      HealthController    →  velocidade do empurrão      (este arquivo)
#                                   ↓
#                          Player / física combina
#                                   ↓
#                             velocity final
#
#  ------------------------------------------- POR QUE O EMPURRÃO É UM CAMPO
#  O knockback simplesmente NÃO FUNCIONAVA. A locomoção reatribuía
#  `velocity.x/z` todo quadro, então o empurrão era escrito e apagado antes de
#  chegar na física. A correção foi dar a ele um campo PRÓPRIO, somado depois —
#  e foi essa descoberta que originou o princípio da arquitetura inteira:
#
#      cada componente é dono do seu estado; o Player combina os resultados.
#
#  Só o componente HORIZONTAL vira impulso. O vertical entra direto na
#  `velocity` porque o eixo Y **não** é reatribuído pela locomoção — só pela
#  gravidade.
#
#  ---------------------------------------------------------------- FRONTEIRA
#  Aqui mora o NÚMERO e a REGRA. Ficam no Player: os dois `@rpc`
#  (`net_apply_knockback`, `net_force_respawn`), a porta pública `take_damage`
#  (chamada de fora pela `DamageZone`), o feedback (flash, som, número
#  flutuante, HUD) e a conversa com o `Scoreboard`.
#
#  ⚠️ Nunca chama `is_multiplayer_authority()`: a autoridade NÃO desce para
#  componentes criados no `_ready()` (medido na Fase 5: pai=7, filho=1).
# ============================================================================

const REGEN_ENERGIA := 320.0   # por segundo
const DECAIMENTO := 4.0        # 1/s — quanto o empurrão perde força por segundo

var _dono: Node = null

var vida: float = 2048.0
var vida_max: float = 2048.0
var energia: float = 4096.0
var energia_max: float = 4096.0

# O empurrão que ainda não foi consumido pela física. Some sozinho em ~1 s, e é
# por isso que o controle volta ao jogador.
var _empurrao: Vector3 = Vector3.ZERO

func montar_em(dono: Node) -> void:
	_dono = dono

# ------------------------------------------------------------------- vida
# Devolve `true` quando a vida chegou a zero — quem decide o que fazer com isso
# é o Player (ele é quem fala com o placar).
func sofrer_dano(quantidade: float) -> bool:
	vida = maxf(vida - quantidade, 0.0)
	return vida <= 0.0

func restaurar() -> void:
	vida = vida_max
	energia = energia_max

# ---------------------------------------------------------------- energia
func regenerar(delta: float) -> void:
	energia = minf(energia + REGEN_ENERGIA * delta, energia_max)

func gastar(custo: float) -> void:
	energia = maxf(energia - custo, 0.0)

# --------------------------------------------------------------- empurrão
# Escala o empurrão pelas regras do jogo e guarda o horizontal.
# **SEMPRE roda no dono do corpo** — ver o comentário de `take_damage` no Player:
# as duas regras abaixo dependem de `is_on_floor()` e do TECLADO da vítima, e no
# servidor `Input.is_key_pressed` leria o teclado do HOST.
#
# Devolve o componente VERTICAL, que o Player soma direto na `velocity`.
func empurrar(base: Vector3, no_chao: bool, yaw: float) -> float:
	if base.length() <= 0.1:
		return 0.0
	var final_kb := SkillSystem.calculate_knockback(base, vida, vida_max)

	# Regra 1: atingido no AR, o knockback DOBRA.
	if not no_chao:
		final_kb *= 2.0
		print("✈️ Atingido no AR! Knockback dobrado!")

	# Regra 2: dá pra resistir andando contra — até 70%, nunca 100%.
	var f := 0.0
	var r := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    f += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  f -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): r += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  r -= 1.0
	var base_cam := Basis.from_euler(Vector3(0, yaw, 0))
	var tentativa := (-base_cam.z) * f + (base_cam.x) * r
	if tentativa.length_squared() > 0.01:
		tentativa = tentativa.normalized()
		var dot := tentativa.dot(final_kb.normalized())
		if dot < 0.85:                      # está tentando ir pra outra direção
			var reducao := remap(clampf(dot, -1.0, 0.5), 0.5, -1.0, 0.0, 0.70)
			var mult := clampf(1.0 - reducao, 0.30, 1.0)   # nunca abaixo de 30%
			final_kb *= mult
			print("🛡️ Knockback Reduzido por Movimento (", int(reducao * 100), "% resistido)!")

	_empurrao += Vector3(final_kb.x, 0.0, final_kb.z)
	print("🚀 Knockback Final Aplicado: ", final_kb)
	return final_kb.y

# Pedido direto, sem passar pelas regras de dano (recuo do canhão da Buki).
func empurrar_cru(direcao: Vector3, forca: float) -> void:
	_empurrao += direcao * forca

# O que a física deve somar NESTE quadro, e o empurrão decai junto. Só
# horizontal: o Y já foi entregue lá em cima.
func impulso_do_quadro(delta: float) -> Vector3:
	if _empurrao.length_squared() <= 0.01:
		_empurrao = Vector3.ZERO
		return Vector3.ZERO
	var agora := Vector3(_empurrao.x, 0.0, _empurrao.z)
	_empurrao = _empurrao.move_toward(Vector3.ZERO, DECAIMENTO * delta * _empurrao.length())
	return agora
