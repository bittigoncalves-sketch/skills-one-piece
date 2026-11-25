extends RefCounted
# ============================================================================
#  ATRIBUTOS FÍSICOS DO MINE PIECE v14 — `PlayerPhysicalAbilityProcedure` (l. 60–71, 310–320,
#  451–452), lidos da fonte descompilada em 26/10/2026.
#
#  O mod NÃO tem pontos de atributo: Força, Resistência, Vida extra e Armadura saem do NÍVEL
#  (decisão do dono, 26/10/2026: "derivar do nível, como o mod" — AUDITORIA_FIDELIDADE, A6).
#  Quem tem estilo de luta (`PlayerSkill1 != 0`; aqui, todo personagem: Combate começa em 1)
#  usa o nível MENOS 1 nas contas. Os extras de estilos específicos (Estilo 3: +5 de vida e
#  +5 de tenacidade; Estilo 7: Força +20 %; ...) pertencem à onda E4 (estilos de luta).
#
#    Força (Strength, amplificador)    round(min(n, 34)); abaixo de 3 vale no máximo 1
#    Resistência (amplificador)        n < 3 → 0; senão round(min(n / 4, 3))
#    Vida (Health Boost, amplificador) round(min(n / 2,5, 9))
#    Armadura                          round(min(1 + n, 30))
#    Tenacidade (armor toughness)      round(min(n × 0,5, 30))
#  onde n = max(nível − 1, 0). Um amplificador a dá a + 1 níveis do efeito:
#    Strength +3 de dano por nível; Health Boost +4 HP por nível; Resistance −20 % por nível.
#  Velocidade e pulo (Speed/Jump Boost ao correr/pular) ainda NÃO foram portados.
# ============================================================================
const ARMADURA_MAXIMA := 30
const BONUS_POR_FORCA := 3.0
const HP_BASE := 20
const HP_POR_NIVEL_DE_EFEITO := 4


## O nível que as contas usam (quem tem estilo perde 1).
static func nivel_efetivo(nivel: int) -> int:
	return maxi(nivel - 1, 0)


static func amplificador_forca(nivel: int) -> int:
	var p := roundi(minf(float(nivel_efetivo(nivel)), 34.0))
	return mini(p, 1) if p < 3 else p


static func niveis_forca(nivel: int) -> int:
	return amplificador_forca(nivel) + 1


static func amplificador_resistencia(nivel: int) -> int:
	var n := nivel_efetivo(nivel)
	return 0 if n < 3 else roundi(minf(n / 4.0, 3.0))


static func niveis_resistencia(nivel: int) -> int:
	return amplificador_resistencia(nivel) + 1


static func amplificador_vida(nivel: int) -> int:
	return roundi(minf(nivel_efetivo(nivel) / 2.5, 9.0))


static func hp_maximo(nivel: int) -> int:
	return HP_BASE + HP_POR_NIVEL_DE_EFEITO * (amplificador_vida(nivel) + 1)


static func armadura(nivel: int) -> int:
	return roundi(minf(1.0 + nivel_efetivo(nivel), float(ARMADURA_MAXIMA)))


static func tenacidade(nivel: int) -> int:
	return roundi(minf(nivel_efetivo(nivel) * 0.5, 30.0))


static func bonus_fisico(nivel: int) -> float:
	return niveis_forca(nivel) * BONUS_POR_FORCA


## ENERGIA (`WhenRespawnProcedure` e `PlayerTickEventProcedure`, 26/10/2026; A9). Máximo com estilo de luta:
## min(4000, 200 × round((2 + nível) / 1,1)). A cada 10 tiques (0,5 s) volta (1 + round((2 + min(nível,19)) / 1,1 × 0,2)),
## o DOBRO com a vida cheia. As técnicas gastam o `custo_mod` direto, nas mesmas unidades.
static func energia_maxima(nivel: int) -> int:
	return mini(4000, 200 * roundi((2.0 + nivel) / 1.1))


## Custo de energia do que NÃO é do mod (frutas da arena, Rocket, pulo e dash no ar): esses números foram escritos para
## 100 de energia por nível (decisão de 23/10/2026). Com a energia do mod a proporção seria outra; este fator a mantém
## (custo × energia do mod / (100 × nível)). As técnicas do mod gastam o `custo_mod`, sem fator (27/10/2026).
static func fator_de_custo_fora_do_mod(nivel: int) -> float:
	return energia_maxima(nivel) / (100.0 * maxi(nivel, 1))


## Energia por SEGUNDO (a procedure repõe a cada 0,5 s), sem o dobro da vida cheia.
static func energia_por_segundo(nivel: int) -> float:
	return 2.0 * (1.0 + roundi((2.0 + minf(float(nivel), 19.0)) / 1.1 * 0.2))


## Dano que sobra: armadura e tenacidade do Minecraft, depois a Resistência (−20 %/nível).
static func dano_recebido(dano: float, nivel: int) -> float:
	return DadosEastBlue.dano_recebido({"armadura": armadura(nivel), "tenacidade": tenacidade(nivel),
		"resistencia": amplificador_resistencia(nivel)}, maxf(0.0, dano))
