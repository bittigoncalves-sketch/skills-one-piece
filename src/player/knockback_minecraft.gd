class_name KnockbackMinecraft
extends RefCounted
# ============================================================================
#  KNOCKBACK NO ESTILO MINECRAFT (23/10/2026). Pedido do dono: "adicionar knockback e
#  som de recepção do dano no jogador; o knockback aplicado deve ser no mesmo estilo
#  do Minecraft". Só o jogador do Modo História (quem instala é o `ModoHistoria`); a
#  arena segue com o empurrão do `HealthController` (cresce com a vida perdida).
#
#  Minecraft Java (`LivingEntity.hurt` / `knockback`), convertido para a escala do jogo
#  (1 bloco = 0,88 m; a gravidade do jogo, 32 m/s², é a mesma do Minecraft):
#    • INVULNERÁVEL 10 ticks (0,5 s) depois de apanhar. Golpe MAIOR nesse tempo tira só
#      a diferença, sem empurrão; menor ou igual não entra.
#    • Empurrão FIXO para longe de quem bateu: 0,4 bloco/tick = 8 blocos/s. Não cresce
#      com a vida perdida nem dobra no ar.
#    • No chão, um pulinho de ~1 bloco (0,4 bloco/tick para cima).
#    • Arrasto no ar 0,91/tick, atrito no chão 0,546/tick: voa um pouco e para seco.
#  Mesmo molde do empurrão do `HealthController`: é DONO da própria velocidade e o
#  Player soma `impulso_do_quadro` por cima da locomoção (`Player._etapa_mover`).
# ============================================================================

const INVULNERAVEL := 0.5
const HORIZONTAL := 8.0 * RelevoEmBlocos.BLOCO               # m/s (≈ 7)
const ALTURA_DO_PULINHO := RelevoEmBlocos.BLOCO               # m
## Decaimento por segundo do empurrão: 0,91 e 0,546 por tick (20 ticks/s) → e^(−k·t).
const ARRASTO_NO_AR := 1.886                                  # −20·ln(0,91)
const ATRITO_NO_CHAO := 12.1                                  # −20·ln(0,546)

var _resta := 0.0
var _ultimo := 0.0
var _empurrao := Vector3.ZERO


func invulneravel() -> bool:
	return _resta > 0.0


## Quanto deste golpe entra (Minecraft): fora da janela, tudo; dentro, só o que passar
## do último golpe. Devolve {dano, empurra}; dano 0 = recusado.
func filtrar(amount: float) -> Dictionary:
	if _resta <= 0.0:
		_resta = INVULNERAVEL
		_ultimo = amount
		return {"dano": amount, "empurra": true}
	if amount <= _ultimo:
		return {"dano": 0.0, "empurra": false}
	var diferenca := amount - _ultimo
	_ultimo = amount
	return {"dano": diferenca, "empurra": false}


## Empurra para longe de quem bateu. `rumo` = direção do golpe quando a posição de quem
## bateu não serve (zero ou em cima da vítima). Devolve a velocidade VERTICAL do pulinho
## (0 no ar), que o Player escreve em `velocity.y`.
func empurrar(vitima: Vector3, atacante: Vector3, rumo: Vector3, gravidade: float, no_chao: bool, forca := 0.4) -> float:
	var dir := Vector3(vitima.x - atacante.x, 0.0, vitima.z - atacante.z)
	if atacante == Vector3.ZERO or dir.length_squared() < 0.0001:
		dir = Vector3(rumo.x, 0.0, rumo.z)
	if dir.length_squared() < 0.0001:
		return 0.0
	# Minecraft divide a velocidade que havia por 2 e soma o golpe: um segundo empurrão
	# logo depois não acumula até o infinito.
	# `forca` em blocos/tick (0,4 = o `hurt` do Minecraft; o `attack_knockback` do mob entra com × 0,5).
	_empurrao = _empurrao * 0.5 + dir.normalized() * HORIZONTAL * (forca / 0.4)
	return sqrt(2.0 * gravidade * ALTURA_DO_PULINHO) * minf(forca / 0.4, 1.0) if no_chao else 0.0


## Reduz o empurrão que acabou de ser dado (resistência a empurrão: `strength *= 1 − resistência`).
func atenuar(fator: float) -> void:
	_empurrao *= clampf(fator, 0.0, 1.0)


## O empurrão do `hurt` do Minecraft para quem NÃO tem um componente próprio (animais, bestas, boneco, inimigos do mapa): vetor
## horizontal em m/s, para LONGE de quem bateu, × (1 − resistência), no máximo a cada 0,5 s por vítima (a invulnerabilidade só
## limita o empurrão). Zero se o golpe veio de lugar nenhum. Quem chama soma ao `_empurrao` dele (e escala pelo porte, se quiser).
static func padrao(vitima: Node3D, atacante: Vector3, resistencia := 0.0) -> Vector3:
	if atacante == Vector3.ZERO or resistencia >= 1.0:
		return Vector3.ZERO
	var agora := Time.get_ticks_msec()
	if agora < int(vitima.get_meta("mc_kb_ate", 0)):
		return Vector3.ZERO
	var dir := Vector3(vitima.global_position.x - atacante.x, 0.0, vitima.global_position.z - atacante.z)
	if dir.length_squared() < 0.0001:
		return Vector3.ZERO
	vitima.set_meta("mc_kb_ate", agora + 500)
	return dir.normalized() * HORIZONTAL * (1.0 - resistencia)


func passar_tempo(delta: float) -> void:
	_resta = maxf(_resta - delta, 0.0)


## O que a física soma NESTE quadro; decai com o arrasto do ar ou o atrito do chão.
func impulso_do_quadro(delta: float, no_chao: bool) -> Vector3:
	if _empurrao.length_squared() < 0.0025:
		_empurrao = Vector3.ZERO
		return Vector3.ZERO
	var agora := _empurrao
	_empurrao *= exp(-(ATRITO_NO_CHAO if no_chao else ARRASTO_NO_AR) * delta)
	return agora


func cancelar() -> void:
	_empurrao = Vector3.ZERO
	_resta = 0.0
