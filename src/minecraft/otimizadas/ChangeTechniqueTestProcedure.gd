# ENVOLTÓRIO À MÃO sobre `ChangeTechniqueTestProcedure` (gerado), mesma assinatura. Diferença para o original: a Zushi Zushi oferece as técnicas de até
# 600 de custo (Moko = C, Rubble = V) SEM as grades de recompensa de 300 M / 500 M que o mod exige. Decisão do dono (12/11/2026): "C e V não fazem nada" — sem a
# grade elas nem apareciam. O Meteor (1250) segue pedindo a grade. As demais frutas ficam como no mod. No original `cost` só entra na conta do limite por grade,
# então passar 0 libera só essa trava (os requisitos por técnica continuam valendo).
# GATILHO: ao regerar as procedures, reconferir contra a nova `ChangeTechniqueTestProcedure` gerada.
extends RefCounted

const ORIGINAL := preload("res://src/minecraft/gerado/procedures/ChangeTechniqueTestProcedure.gd")
const FRUTAS_SEM_GRADE := [&"minepiece:item_devil_fruit_zushi_zushi"]
const TETO_SEM_GRADE := 600.0


static func execute(world, entity, p_devilFruit, p_cost: float, p_selectNum: float, p_skill: float) -> bool:
	if p_devilFruit != null and p_cost <= TETO_SEM_GRADE and FRUTAS_SEM_GRADE.has(StringName(str(p_devilFruit.getItem().id))):
		p_cost = 0.0
	return ORIGINAL.execute(world, entity, p_devilFruit, p_cost, p_selectNum, p_skill)
