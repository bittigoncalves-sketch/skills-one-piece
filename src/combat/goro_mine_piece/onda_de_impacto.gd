extends Node3D
# ============================================================================
#  A ONDA DE CHOQUE DOS RAIOS: EntityImpactWave do Mine Piece v14 no modo 56
#  (AIImpactWaveProcedure), que o Sango (25% dos raios) e cada raio do Mamaragan
#  deixam no chão. Invisível no mod (textura "clear"): só a fumaça mostra.
#
#  SIZE começa em 0,1 e cresce 1,5 por tick até 15 (a base desce 0,75 por vez);
#  o corpo é 1,3 × SIZE blocos. Por 15 ticks, um RangeAttack de lado
#  1,5 × ((altura + largura) × 0,75 + 4) no meio do corpo: 16 × CNT6, 24 nos 6
#  últimos ticks, choque (efeito 11). `global_position` é a BASE, como no Minecraft.
#  Fora da tradução: a vida da entidade (50 no Sango, 200 no Mamaragan) — aqui ela
#  não é alvo de golpe. GATILHO: o dono pedir que dê para destruir a onda.
# ============================================================================

const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
const LADO_BASE := 1.3       # EntityType ENTITY_IMPACT_WAVE: sized(1.3, 1.3)
const VIDA := 15.0           # modo 56
const TAMANHO_FINAL := 15.0

var c
var cnt6 := 0.0
var tamanho := 0.1
var cnt1 := 0.0
var _acumulado := 0.0


func _physics_process(delta: float) -> void:
	if c == null or not is_instance_valid(c.ator):
		queue_free()
		return
	_acumulado += delta
	while _acumulado >= B.TICK and is_inside_tree():
		_acumulado -= B.TICK
		_tick()


func _tick() -> void:
	var lado := LADO_BASE * tamanho
	var meio := global_position + Vector3.UP * B.m(lado * 0.5)
	cnt1 += 1.0
	var fator := 1.0 + cnt6 * 0.1
	var alcance := (lado + lado) * 0.75 + 4.0
	if tamanho < TAMANHO_FINAL:
		var cresce := maxf(VIDA / TAMANHO_FINAL, 1.5)
		tamanho += cresce
		global_position.y -= B.m(cresce * 0.5)
	var forte := cnt1 > VIDA - 6.0
	var dano := (Balance.MINE_PIECE_GORO.onda_forte if forte else Balance.MINE_PIECE_GORO.onda) * fator + cnt1 * 0.001
	c.atacar(meio, B.Ataque.new(dano, 1.5 * alcance, 0.25 if forte else 0.1), meio)
	if fmod(cnt1, 6.0) == 1.0:
		c.fx_marca(meio, B.m(alcance) * 0.5)
	c.fx_fumaca(meio, int(alcance), B.m(alcance * 0.1), 1.0)
	if cnt1 > VIDA:
		queue_free()
