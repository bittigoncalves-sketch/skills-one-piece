class_name TempoLocal
extends RefCounted
# ============================================================================
#  TEMPO LOCAL (04/11/2026) — quanto menos vida o jogador tem, mais devagar passa o tempo AO REDOR
#  dele, num raio de 20 m: NPCs, animais, inimigos, bosses, disparos, animações. O jogador segue em
#  tempo normal. Só o MODO HISTÓRIA liga (`TempoLocalDaHistoria`); na arena multiplayer `jogador`
#  fica nulo e tudo aqui devolve 1 — desacelerar outro jogador seria injusto e exigiria replicar o
#  tempo pela rede.
#
#  Decisões do dono (04/11/2026):
#   • curva: tempo normal até 60 % de vida; daí desce em linha reta até 0,25× em 1 %;
#   • raio de 20 m, com 3 m de borda suave (sem "parede" onde o tempo muda de uma vez);
#   • zona vermelha (< 25 % de vida): as hitboxes dos disparos ficam visíveis.
#
#  COMO ENTRA NO JOGO: `Lentidao.fator(corpo)` — o fator de lentidão por corpo que animais, bonecos,
#  personagens do Mine Piece, executor de skill e animador procedural JÁ multiplicam no seu tempo —
#  passa a incluir `fator_de(corpo)`. Quem não passa por ali (DamageZone, NPC, clipe de animal)
#  chama `fator_de`/`fator_em` direto. O que ainda NÃO segue o tempo local: efeitos que movem a si
#  mesmos com `delta` (FireFXGrande, GoroFXGrande, YamiFX, Fireflies…), partículas e Tweens.
#  Gatilho: se um desses importar na jogabilidade, ligar a ele o `fator_em(global_position)`.
# ============================================================================

const RAIO := 20.0
const BORDA := 3.0
const VIDA_INICIO := 0.60        # fração de vida em que a lentidão começa
const VIDA_FIM := 0.01           # fração em que chega ao mínimo
const ESCALA_MINIMA := 0.25
const ZONA_VERMELHA := 0.25

## Quem é o "usuário" cuja vida dita o tempo. Nulo = recurso desligado (arena, menus, testes).
static var jogador: Node3D = null


static func ligado() -> bool:
	return jogador != null and is_instance_valid(jogador)


## Fração de vida do jogador (0..1). 1 se não houver jogador ou vida máxima.
static func fracao_de_vida() -> float:
	if not ligado():
		return 1.0
	var maxima := float(jogador.get("max_health"))
	if maxima <= 0.0:
		return 1.0
	return clampf(float(jogador.get("health")) / maxima, 0.0, 1.0)


## A curva pura: fração de vida -> escala do tempo ao redor (1 = normal).
static func curva(fracao: float) -> float:
	if fracao >= VIDA_INICIO:
		return 1.0
	var t := clampf((fracao - VIDA_FIM) / (VIDA_INICIO - VIDA_FIM), 0.0, 1.0)
	return lerpf(ESCALA_MINIMA, 1.0, t)


## Escala do tempo no centro do raio, agora.
static func escala_do_jogador() -> float:
	return curva(fracao_de_vida()) if ligado() else 1.0


## Escala do tempo num ponto do mundo: `escala_do_jogador` dentro do raio, 1 fora, borda suave.
static func fator_em(ponto: Vector3) -> float:
	if not ligado():
		return 1.0
	var escala := curva(fracao_de_vida())
	if escala >= 1.0:
		return 1.0
	var d := ponto.distance_to(jogador.global_position)
	if d >= RAIO:
		return 1.0
	var peso := smoothstep(RAIO, RAIO - BORDA, d)     # 0 na borda, 1 a 3 m para dentro
	return lerpf(1.0, escala, peso)


## Escala para um corpo: o jogador (e o que não tem posição) fica sempre em 1.
static func fator_de(corpo: Node) -> float:
	if jogador == null or corpo == null or corpo == jogador or not (corpo is Node3D) \
			or not (corpo as Node3D).is_inside_tree():
		return 1.0
	return fator_em((corpo as Node3D).global_position)


## DISPAROS andam mais devagar que o resto (04/11/2026: "as balas ainda estão muito rápidas"). A
## bala é rápida (80–125 m/s), então o mesmo ×0,25 do mundo ainda deixava ela a 25 m/s: o fator do
## disparo é o QUADRADO do do mundo (×0,0625 no mínimo) — a bala vira algo que se desvia. O disparo
## do próprio jogador (`autor`) segue normal.
static func fator_de_disparo(ponto: Vector3, autor: Node = null) -> float:
	if not ligado() or e_do_jogador(autor):
		return 1.0
	var f := fator_em(ponto)
	return f * f


## Zona vermelha: vida abaixo de 25 % e viva.
static func zona_vermelha() -> bool:
	if not ligado():
		return false
	var f := fracao_de_vida()
	return f < ZONA_VERMELHA and f > 0.0


## Disparo do próprio jogador anda no tempo do jogador (normal); o dos outros, no do mundo.
static func e_do_jogador(autor: Node) -> bool:
	return ligado() and autor != null and is_instance_valid(autor) and autor == jogador
