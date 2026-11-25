# AJUSTADA de propósito (15/11/2026, pedido do dono) — NÃO é equivalente à gerada (`gerado/procedures/LogicRifleProcedure.gd`).
#
# O que muda: a faixa de tiro de quem NÃO é jogador e empunha fuzil/lançador/arco. No mod, a IA só dispara entre 8 m e 24 m (Yasopp e Van
# Augur: até 128 m). Na história os atiradores nascem e ficam mais longe que os espadachins, então a faixa vai a `ALCANCE_DO_ATIRADOR`
# (48 m). O MÍNIMO (8 m) e todo o resto (Chu, Charlos/Helmeppo, jogador, munição) seguem a gerada.
#
# Como: só a faixa 24 m < d ≤ ALCANCE é tratada aqui, repetindo as condições da gerada que vêm ANTES da distância; o resto delega.
# GATILHO: ao regerar as procedures, reconferir esta contra a nova `LogicRifleProcedure` gerada (Mc.AJUSTADAS).
extends RefCounted

const ALCANCE_DO_ATIRADOR := 48.0
const GERADA := "res://src/minecraft/gerado/procedures/LogicRifleProcedure.gd"


static func execute(world, entity, sneak: bool) -> bool:
	if entity != null and not Mc.e(entity, &"Player") and not Mc.e(entity, &"ChuEntity") \
			and not Mc.e(entity, &"CharlosEntity") and not Mc.e(entity, &"HelmeppoEntity") \
			and not Mc.e(entity, &"YasoppEntity") and not Mc.e(entity, &"Yasopp2Entity") \
			and not Mc.e(entity, &"VanAugurEntity") and not Mc.e(entity, &"VanAugur2Entity"):
		var distance: float = Mc.proc(&"GetDistanceProcedure").execute(entity)
		if distance > 24.0 and distance <= ALCANCE_DO_ATIRADOR:
			if Mc.e(entity, &"LivingEntity") and entity.hasEffect(Mc.efeito(&"minepiece:damage_effect")):
				return false
			var item_a = entity.getMainHandItem().copy() if Mc.e(entity, &"LivingEntity") else null
			if item_a != null:
				for etiqueta in ["forge:launcher", "forge:rifle", "forge:bow"]:
					if item_a.is_(Mc.estatico(&"ItemTags", &"create", [Mc.novo(&"ResourceLocation", [etiqueta])])):
						return true
			return false
	return (load(GERADA) as GDScript).execute(world, entity, sneak)
