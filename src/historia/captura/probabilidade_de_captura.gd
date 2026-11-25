class_name ProbabilidadeDeCaptura
extends RefCounted
# ============================================================================
#  PROBABILIDADE DE CAPTURA (08/11/2026) — a conta dos jogos Pokémon (Gerações III/IV) aplicada à pokébola do jogo.
#
#  Fontes (pesquisadas em 08/11/2026): Bulbapedia "Catch rate" e a calculadora Gen III/IV do Dragonfly Cave.
#    a = (3·HPmax − 2·HP) · taxa_de_captura · bola · status / (3·HPmax)        (mínimo 1; a ≥ 255 = captura garantida)
#    Cada arremesso faz 4 "chacoalhadas"; cada uma passa com probabilidade q = (a/255)^¼ (b/65536 no jogo, com
#    b = 1048560 / ⁴√(16711680/a), a conta de ponto fixo de lá — NÃO confirmada nas páginas lidas, vem do conhecimento
#    geral da série) e só captura se as 4 passam: chance por bola = q⁴ = a/255.
#    Ball: Poké 1×, Great 1,5×, Ultra 2×, Master garantida (a 255×). Status: sono/gelo 2× (Ger. III/IV; 2,5× da V em diante),
#    paralisia/queimadura/veneno 1,5×.  Taxa de captura: de 3 (lendários) a 255 (os mais comuns); Rattata 255, Pidgey 255,
#    Pikachu 190, Charmander/Bulbasaur 45, Dragonite 45, Mewtwo/lendários 3.
#
#  ADAPTAÇÃO ao jogo — a "raridade" do inimigo vem da DIFICULDADE dele (o mesmo XP de abate que o jogo já calcula: vida × dano, ver
#  `FichaDeAnimal.xp_por_dificuldade` e `Recompensa.xp_da_ficha`), em faixas que reproduzem as taxas clássicas:
#      XP ≤ 5 comum 255 · ≤ 20 incomum 120 · ≤ 75 raro 45 · ≤ 150 muito raro 15 · > 150 lendário 3.
#  Chefes continuam fora (não capturáveis). Hoje só existe a Pokébola comum (1×): `BOLAS` já traz as outras para quando existirem.
# ============================================================================

const Recompensa := preload("res://src/historia/recompensa_mine_piece.gd")
const FAIXAS: Array[Dictionary] = [
	{"ate_xp": 5.0, "nome": "comum", "taxa": 255},
	{"ate_xp": 20.0, "nome": "incomum", "taxa": 120},
	{"ate_xp": 75.0, "nome": "raro", "taxa": 45},
	{"ate_xp": 150.0, "nome": "muito raro", "taxa": 15},
	{"ate_xp": INF, "nome": "lendário", "taxa": 3},
]
const BOLAS := {"pokebola": 1.0, "grande": 1.5, "ultra": 2.0}      # modificadores da fórmula
## Só para teste: valor 0..1 que substitui TODO sorteio (0 = sempre passa, 0.99999 = sempre falha). Negativo = sorteio de verdade.
static var sorteio_fixo := -1.0
const A_MAXIMO := 255.0
const CHACOALHADAS := 4


## Faixa de raridade para um XP de abate.
static func faixa_do_xp(xp: float) -> Dictionary:
	for f in FAIXAS:
		if xp <= float(f["ate_xp"]):
			return f
	return FAIXAS[FAIXAS.size() - 1]


## O XP de abate (a dificuldade) de `alvo`: ficha de animal (xp), personagem do mod (vida, armadura...) ou, na falta, a vida.
static func xp_de(alvo: Node) -> float:
	var ficha: Variant = alvo.get("ficha")
	var vida_max := float(alvo.get("max_health")) if alvo.get("max_health") != null else 0.0
	if ficha is Dictionary:
		if (ficha as Dictionary).has("xp"):
			return float(ficha["xp"])
		if (ficha as Dictionary).has("dano_corpo") or (ficha as Dictionary).has("armadura"):
			return float(Recompensa.xp_da_ficha(ficha, vida_max))
	return maxf(vida_max / 10.0, 1.0)


static func faixa_de(alvo: Node) -> Dictionary:
	return faixa_do_xp(xp_de(alvo))


## `a` da fórmula. `fracao_de_vida` 0..1; `bola` = modificador da pokébola.
static func valor_a(fracao_de_vida: float, taxa_de_captura: float, bola := 1.0, status := 1.0) -> float:
	var h := clampf(fracao_de_vida, 0.0, 1.0)
	var a := (3.0 - 2.0 * h) * taxa_de_captura * bola * status / 3.0
	return clampf(floorf(a), 1.0, A_MAXIMO)       # o jogo arredonda para baixo a cada passo e nunca deixa cair de 1


## Chance de capturar com UMA bola: as 4 chacoalhadas (q⁴ = a/255).
static func chance(a: float) -> float:
	if a >= A_MAXIMO:
		return 1.0
	return pow(pow(a / A_MAXIMO, 0.25), float(CHACOALHADAS))


## Sorteia o arremesso. Devolve {capturou: bool, chacoalhadas: int (0..4), a, chance}.
static func sortear(a: float, rng: RandomNumberGenerator = null) -> Dictionary:
	var q := pow(clampf(a / A_MAXIMO, 0.0, 1.0), 0.25) if a < A_MAXIMO else 1.0
	var n := 0
	for i in CHACOALHADAS:
		var r := sorteio_fixo if sorteio_fixo >= 0.0 else (rng.randf() if rng != null else randf())
		if r < q:
			n += 1
		else:
			break
	return {"capturou": n == CHACOALHADAS, "chacoalhadas": n, "a": a, "chance": chance(a)}
