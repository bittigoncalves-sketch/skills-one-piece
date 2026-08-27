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

const REGEN_ENERGIA_PCT := 0.005       # 0,5% do máximo por segundo
const REGEN_ENERGIA_KILL_PCT := 0.02   # 2% por segundo, depois de matar

# ---------------------------------------------------------- REGENERAÇÃO DE VIDA
# Pedido do dono, 2026-08-12. Os números são PERCENTUAIS do máximo, não valores
# absolutos: assim continuam válidos se a vida cheia mudar de 2048.
#
#   base .............. 0,5%/s  -> 10,24 hp/s, cura 0 -> cheio em 200 s
#   depois de apanhar . −90%    -> 1,02 hp/s enquanto a briga está quente
#   depois de uma kill  2,0%/s  -> 40,96 hp/s por 30 s, cura em 50 s
#
# A pedido do usuário (2026-08-21), a regeneração de energia agora segue
# EXATAMENTE o mesmo formato (percentual e com bônus de kill) da vida.
const REGEN_VIDA_PCT := 0.005        # 0,5% do máximo por segundo
const REGEN_VIDA_KILL_PCT := 0.02    # 2% por segundo, depois de matar
const BONUS_KILL_DURACAO := 30.0     # segundos de bônus por kill
const PENALIDADE_DANO := 0.10        # apanhou -> regenera a 10% (−90%)

# ⚠️ NÚMERO ASSUMIDO, não especificado pelo dono: por quanto tempo depois do
# último dano a penalidade de −90% continua valendo. 5 s é o tempo típico de
# "ainda estou em combate" — curto o bastante para premiar quem desengaja, longo
# o bastante para a penalidade significar alguma coisa numa troca de golpes.
# É o primeiro número a calibrar se a arena ficar lenta ou rápida demais.
const JANELA_DE_COMBATE := 5.0
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

# Carimbos de tempo (ms). Carimbo em vez de contador: não precisa de tique e
# sobrevive a qualquer quadro perdido.
var _t_ultimo_dano: int = -999999
var _t_bonus_kill: int = -999999

# ------------------------------------------------------------------- vida
# Devolve `true` quando a vida chegou a zero — quem decide o que fazer com isso
# é o Player (ele é quem fala com o placar).
func sofrer_dano(quantidade: float) -> bool:
	_t_ultimo_dano = Time.get_ticks_msec()   # esfria a regeneração
	vida = maxf(vida - quantidade, 0.0)
	return vida <= 0.0

# O dono deste corpo matou alguém: a regeneração dispara por 30 s.
func premiar_kill() -> void:
	_t_bonus_kill = Time.get_ticks_msec()
	print("🩸 Regeneração acelerada por 30s (kill).")

func em_combate() -> bool:
	return Time.get_ticks_msec() - _t_ultimo_dano < int(JANELA_DE_COMBATE * 1000.0)

func com_bonus_de_kill() -> bool:
	return Time.get_ticks_msec() - _t_bonus_kill < int(BONUS_KILL_DURACAO * 1000.0)

func restaurar() -> void:
	vida = vida_max
	energia = energia_max
	_t_ultimo_dano = -999999      # respawn zera o "estou em combate"

# ---------------------------------------------------------------- energia
# Regenera VIDA e ENERGIA. A penalidade de combate multiplica as duas; o bônus
# de kill acelera as duas.
func regenerar(delta: float) -> void:
	var fator := PENALIDADE_DANO if em_combate() else 1.0

	var pct_vida := REGEN_VIDA_KILL_PCT if com_bonus_de_kill() else REGEN_VIDA_PCT
	if vida < vida_max:
		vida = minf(vida + vida_max * pct_vida * fator * delta, vida_max)

	if energia < energia_max:
		energia = minf(energia + regen_energia_por_s(energia_max, com_bonus_de_kill()) * fator * delta,
			energia_max)

# A regen de energia EM VALOR ABSOLUTO (por segundo), a partir do percentual.
#
# ⚠️ EXISTE PARA TER UMA FONTE SÓ. Até 2026-08-21 havia uma constante absoluta
# `REGEN_ENERGIA` e as sondas de rede a liam direto; quando ela virou percentual
# (para continuar valendo se a energia cheia deixar de ser 4096), as sondas
# ficaram citando um nome que não existia mais — e passaram a NÃO COMPILAR, em
# silêncio, porque ninguém roda uma sonda de dois processos todo dia. Ver
# `docs/erros.md`.
#
# Quem quiser o número em unidades/s pergunta aqui em vez de refazer a conta.
static func regen_energia_por_s(maximo: float, com_kill: bool = false) -> float:
	return (REGEN_ENERGIA_KILL_PCT if com_kill else REGEN_ENERGIA_PCT) * maximo

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
	var base_cam := RosaDosVentos.base_do_corpo(yaw)   # definição canônica
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
