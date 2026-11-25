extends RefCounted
# ============================================================================
#  NÍVEL E XP DO MINE PIECE (18/10/2026, docs/MINE_PIECE_SISTEMAS_PLANO.md, F6).
#
#  Decisão do dono: "curva do mod no XP" — a barra de XP, os tetos por ilha, as missões
#  dos níveis 8–10 e os 5 pontos por nível continuam; mudam o XP exigido por nível e o XP
#  de cada abate, que passam a ser os do mod.
#
#  No mod o nível SAI DA RECOMPENSA (`UpdateBountyProcedure`): recompensa B → nível
#    B < 10 mil ............ 5 × B / 10.000
#    10 mil a 100 mil ...... 5 + (B − 10.000) / 18.000
#    100 mil a 1 milhão .... 10 + (B − 100.000) / 90.000
#    ≥ 1 milhão ............ 20 + (B − 1.000.000) / 400.000
#  Invertido: a recompensa de cada nível é `recompensa_do_nivel`, e o XP de um nível ao
#  seguinte é a diferença (2.000 até o 5; 18.000 até o 10; 90.000 até o 20; 400.000 depois).
#
#  Recompensa de um abate (`WhenEntityDieProcedure`), lida da VÍTIMA; relida na fonte em 28/10/2026 (a versão de 18/10 usava a
#  armadura onde a fonte usa o ATAQUE, e não tinha os multiplicadores de armadura, tenacidade e haki):
#    força = (Força + 1 se tem o efeito) × (1 + 0,25 × (Resistência + 1 se tem o efeito)) + 0,33 × ATAQUE BASE
#    base  = (força + 1)² + 1
#    × vida:      min(1 + max(vida máx. − (2 + Força + 1) × 10, 0) × 0,02, 3)      (× 1 em vez de × 10 se a vítima é jogador)
#    × armadura:  1 + mín(armadura, 20) × 0,01
#    × tenacidade: 1 + mín(tenacidade, 8) × 0,02
#    × haki:      (1 + (nível do Haki do Armamento + 1) × 0,025) × (1 + (nível do Haki da Observação + 1) × 0,025)
#    × 25  (5 × a regra minepieceBountyMultiplier, padrão 5), arredondado, no mínimo 1
#  (Força/Resistência/Haki = amplificador do efeito; −1 = sem o efeito.)
#  O LIMITE anti-farm e o teto de 5 milhões ficam em `ProgressaoDoPersonagem.previa_do_abate` (B2).
# ============================================================================

const DIFICULDADE := 25.0
## `minepiecePlayerBountyLimit` (padrão 50) × 100.000: a recompensa máxima do jogador. Nível 30.
const RECOMPENSA_MAXIMA := 5000000


## O limite de recompensa que um abate de `fama` dá ao jogador (`WhenEntityDieProcedure`, caso sem PvP).
static func limite_por_vitima(fama: float) -> float:
	if fama < 15000.0:
		return minf(fama + 3000.0, 15000.0) * 3.0
	if fama < 150000.0:
		return minf(fama + 30000.0, 150000.0) * 3.0
	if fama < 1500000.0:
		return minf(fama + 300000.0, 1000000.0) * 3.0
	return fama * 3.0


## Menor recompensa (XP acumulado) com que `nivel_da_recompensa` dá `n`: a inversa EXATA do
## `UpdateBountyProcedure`, com o `Math.round` dele (o nível n começa meio degrau antes).
static func recompensa_do_nivel(n: int) -> int:
	if n <= 0:
		return 0
	if n <= 5:
		return 2000 * n - 1000
	if n <= 10:
		return 1000 + 18000 * (n - 5)
	if n <= 20:
		return 55000 + 90000 * (n - 10)
	return 800000 + 400000 * (n - 20)


## XP para ir do nível `n` ao seguinte.
static func xp_para(n: int) -> int:
	return recompensa_do_nivel(n + 1) - recompensa_do_nivel(n)


## Nível de quem tem a recompensa `b`: a conta do `UpdateBountyProcedure`, com o `Math.round` dele.
static func nivel_da_recompensa(b: float) -> int:
	if b >= 1000000.0:
		return roundi(20.0 + (b - 1000000.0) / 400000.0)
	if b >= 100000.0:
		return roundi(10.0 + (b - 100000.0) / 90000.0)
	if b >= 10000.0:
		return roundi(5.0 + (b - 10000.0) / 18000.0)
	return roundi(5.0 * (b / 10000.0))


## Recompensa (XP) por derrotar uma vítima com estes números.
static func xp_de_abate(vida_max: float, forca := -1.0, resistencia := -1.0, armadura := 0.0, ataque_base := 0.0,
		tenacidade := 0.0, haki_armamento := -1.0, haki_observacao := -1.0, vitima_e_jogador := false) -> int:
	var f := (forca + 1.0) if forca >= 0.0 else 0.0
	var r := (resistencia + 1.0) if resistencia >= 0.0 else 0.0
	var forca_total := f * (1.0 + 0.25 * r) + 0.33 * ataque_base
	var base := pow(forca_total + 1.0, 2.0) + 1.0
	base *= minf(1.0 + maxf(vida_max - (2.0 + f) * (1.0 if vitima_e_jogador else 10.0), 0.0) * 0.02, 3.0)
	base *= 1.0 + minf(armadura, 20.0) * 0.01
	base *= 1.0 + minf(tenacidade, 8.0) * 0.02
	base *= 1.0 + ((haki_armamento + 1.0) if haki_armamento >= 0.0 else 0.0) * 0.025
	base *= 1.0 + ((haki_observacao + 1.0) if haki_observacao >= 0.0 else 0.0) * 0.025
	return maxi(roundi(maxf(base * DIFICULDADE, 1.0)), 1)

## A conta sobre a VÍTIMA VIVA, como o mod: Força e Resistência são os amplificadores dos efeitos que ela tem agora
## (marinheiros e piratas sorteiam isso ao nascer) e a armadura é o atributo com os modificadores. Sem a IA do mod
## (não há efeitos) cai na ficha.
static func xp_do_personagem(p: Node) -> int:
	if p.get("ia_do_mod") == null or not IaDoMod.ligada or not p.ia_do_mod.tem_ia():
		return xp_da_ficha(p.ficha, p.max_health)
	var e := McEntidade.de(p)
	var forca := e.getEffect(Mc.efeito(&"minecraft:strength"))
	var resistencia := e.getEffect(Mc.efeito(&"minecraft:resistance"))
	var h_arm := e.getEffect(Mc.efeito(&"minepiece:armament_haki"))
	var h_obs := e.getEffect(Mc.efeito(&"minepiece:observation_haki"))
	return xp_de_abate(e.getAttributeValue(Mc.atributo(&"minecraft:generic.max_health")),
		float(forca.amplificador) if forca != null else -1.0, float(resistencia.amplificador) if resistencia != null else -1.0,
		e.getAttributeValue(Mc.atributo(&"minecraft:generic.armor")), e.getAttributeBaseValue(Mc.atributo(&"minecraft:generic.attack_damage")),
		e.getAttributeValue(Mc.atributo(&"minecraft:generic.armor_toughness")),
		float(h_arm.amplificador) if h_arm != null else -1.0, float(h_obs.amplificador) if h_obs != null else -1.0)


## A mesma conta para uma ficha de personagem do Mine Piece (`DadosEastBlue`).
static func xp_da_ficha(ficha: Dictionary, vida_max: float) -> int:
	return xp_de_abate(vida_max, float(ficha.get("forca", -1.0)), float(ficha.get("resistencia", -1.0)),
		float(ficha.get("armadura", 0.0)), float(ficha.get("dano_corpo", 0.0)), float(ficha.get("tenacidade", 0.0)))
