# OTIMIZADA a partir de gerado/procedures/BlockToGrassProcedure.gd (11/11/2026) — NÃO é gerada: ver `Mc.OTIMIZADAS`.
# POR QUE: o Mori Mori V (`BlockToGrass` com `BlockRange` 32 → cubo de 64³) gastava 4,7 s num quadro (393 mil `getBlockState`, medido no mapa real
# com `tools/dev_tests/medir_skill_detalhe.gd`). O que muda: só a ESCOLHA das células; o corpo de cada célula é o original.
# EQUIVALÊNCIA: `tools/dev_tests/test_procedures_otimizadas.gd`. GATILHO: regerar a original → refazer esta cópia (o teste acusa).
# GERADO por tools/mine_piece/tradutor/traduzir.py de BlockToGrassProcedure.java — não editar.
extends RefCounted

static func execute(world, x: float, y: float, z: float, entity) -> void:
	if (entity != null):
		var block_a = Mc.bloco(&"minecraft:air").defaultBlockState()
		var logic_a: bool = false
		var destroy_type: String = ""
		var x_dis: float = 0.0
		var damage: float = 0.0
		var distance: float = 0.0
		var x_pos: float = 0.0
		var z_dis: float = 0.0
		var y_pos: float = 0.0
		var z_pos: float = 0.0
		var y_dis: float = 0.0
		var RANGE: float = 0.0
		if (not (world.isClientSide())):
			if (world.getLevelData().getGameRules().getBoolean(Mc.campo(&"GameRules", &"RULE_MOBGRIEFING"))):
				if (world.getLevelData().getGameRules().getBoolean(Mc.campo(&"GameRules", &"RULE_DOBLOCKDROPS"))):
					logic_a = true
					Mc.definir_em((world.getLevelData().getGameRules().getRule(Mc.campo(&"GameRules", &"RULE_DOBLOCKDROPS"))), false, world.getServer())
				destroy_type = "replace"
				damage = entity.getPersistentData().getDouble("BlockDamage")
				RANGE = entity.getPersistentData().getDouble("BlockRange")
				RANGE = max(RANGE * 2.0, 1.0)
				# [OTIMIZADA] só as células com bloco SOBREPOSTO (`McBlocosDinamicos`, no máximo 600) podem ser terra/areia/muda: o relevo da ilha
				# responde sempre pedra, e o resto é ar ou água. Varrer o cubo inteiro (64³ = 262 144 células, ~4,7 s no Mori Mori V) não muda nada.
				# Mesma ordem (x, y, z crescentes) e o mesmo corpo do original.
				var x_ini: int = int(Mc.math_round(x - RANGE * 0.5))
				var y_ini: int = int(Mc.math_round(y - RANGE * 0.5))
				var z_ini: int = int(Mc.math_round(z - Mc.math_round(RANGE * 0.5)))
				var lado: int = int(RANGE)
				for celula_sobreposta: Vector3i in world.blocos.celulas_na_caixa(Vector3i(x_ini, y_ini, z_ini), Vector3i(x_ini + lado - 1, y_ini + lado - 1, z_ini + lado - 1)):
					x_pos = celula_sobreposta.x
					y_pos = celula_sobreposta.y
					z_pos = celula_sobreposta.z
					x_dis = x_pos - x
					x_dis *= x_dis
					y_dis = y_pos - y
					y_dis *= y_dis
					if (not (world.isEmptyBlock(Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos])))):
						block_a = world.getBlockState(Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos]))
						if ((((((((block_a.getBlock() == Mc.bloco(&"minecraft:dirt") or block_a.getBlock() == Mc.bloco(&"minecraft:coarse_dirt")) or block_a.getBlock() == Mc.bloco(&"minecraft:podzol")) or block_a.getBlock() == Mc.bloco(&"minecraft:rooted_dirt")) or block_a.getBlock() == Mc.bloco(&"minecraft:sand")) or block_a.getBlock() == Mc.bloco(&"minecraft:sandstone")) or block_a.getBlock() == Mc.bloco(&"minecraft:red_sand")) or block_a.getBlock() == Mc.bloco(&"minecraft:red_sandstone"))):
							z_dis = z_pos - z
							z_dis *= z_dis
							distance = x_dis + y_dis + z_dis
							if (distance <= max(RANGE * 0.5 * RANGE * 0.5, 1.0)):
								if (not (world.getBlockState(Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos + 1.0, z_pos])).canOcclude())):
									if (Mc.e(world, &"ServerLevel")):
										world.getServer().getCommands().performPrefixedCommand(Mc.novo(&"CommandSourceStack", [Mc.campo(&"CommandSource", &"NULL"), Mc.novo(&"Vec3", [x_pos, y_pos, z_pos]), Mc.campo(&"Vec2", &"ZERO"), world, 4, "", Mc.estatico(&"Component", &"literal", [""]), world.getServer(), null]).withSuppressedOutput(), "setblock ~ ~ ~ minecraft:grass_block replace")
									if (randf() < 0.1 and Mc.e(world, &"Level")):
										var _bp = Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos])
										if (((Mc.estatico(&"BoneMealItem", &"growCrop", [Mc.novo(&"ItemStack", [Mc.item(&"minecraft:bone_meal")]), world, _bp]) or Mc.estatico(&"BoneMealItem", &"growWaterPlant", [Mc.novo(&"ItemStack", [Mc.item(&"minecraft:bone_meal")]), world, _bp, null]))) and not (world.isClientSide())):
											world.levelEvent(2005, _bp, 0)
								elif (((((not (world.getBlockState(Mc.estatico(&"BlockPos", &"containing", [x_pos + 1.0, y_pos, z_pos])).canOcclude()) or not (world.getBlockState(Mc.estatico(&"BlockPos", &"containing", [x_pos - 1.0, y_pos, z_pos])).canOcclude())) or not (world.getBlockState(Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos + 1.0])).canOcclude())) or not (world.getBlockState(Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos - 1.0])).canOcclude()))) and Mc.e(world, &"ServerLevel")):
									world.getServer().getCommands().performPrefixedCommand(Mc.novo(&"CommandSourceStack", [Mc.campo(&"CommandSource", &"NULL"), Mc.novo(&"Vec3", [x_pos, y_pos, z_pos]), Mc.campo(&"Vec2", &"ZERO"), world, 4, "", Mc.estatico(&"Component", &"literal", [""]), world.getServer(), null]).withSuppressedOutput(), "setblock ~ ~ ~ minecraft:dirt replace")
						elif (block_a.is_(Mc.estatico(&"BlockTags", &"create", [Mc.novo(&"ResourceLocation", ["minecraft:saplings"])])) and Mc.e(world, &"Level")):
							var _bp = Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos])
							if (((Mc.estatico(&"BoneMealItem", &"growCrop", [Mc.novo(&"ItemStack", [Mc.item(&"minecraft:bone_meal")]), world, _bp]) or Mc.estatico(&"BoneMealItem", &"growWaterPlant", [Mc.novo(&"ItemStack", [Mc.item(&"minecraft:bone_meal")]), world, _bp, null]))) and not (world.isClientSide())):
								world.levelEvent(2005, _bp, 0)
				if (logic_a):
					Mc.definir_em((world.getLevelData().getGameRules().getRule(Mc.campo(&"GameRules", &"RULE_DOBLOCKDROPS"))), true, world.getServer())
			entity.getPersistentData().putDouble("BlockRange", 0.0)
			entity.getPersistentData().putDouble("BlockDamage", 0.0)

