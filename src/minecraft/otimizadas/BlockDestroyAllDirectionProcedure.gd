# OTIMIZADA a partir de gerado/procedures/BlockDestroyAllDirectionProcedure.gd (09/11/2026) — NÃO é gerada: ver `Mc.OTIMIZADAS`.
#
# POR QUE: no X do Batto Batto (Tempest Kick) cada lâmina (`AIProjectileSlash`) varre ~17 cubos por tick; com ~9 lâminas são ~150 chamadas por tick, cada
# uma testando dezenas de células — a mesma célula dezenas de vezes, quase todas INERTES (ar, ou bloco duro demais). Uma única IA custava ~100 ms
# por tick no mapa real (FPS 60 → ~8). Custo por célula inerte: BlockPos + isEmptyBlock + getBlockState + getDestroySpeed + 2 testes de tag.
#
# O QUE MUDA (só isto): a classificação intrínseca da célula — vazia / [estado, dureza ajustada por logs·planks, líquido-ou-waterlogged] — é feita UMA vez
# por célula por tick (`world.info_de_celulas`, refeita célula a célula no `setBlock`, zerada a cada tick/quadro) e a célula só entra no corpo original
# se alguma chamada com este dano poderia destruí-la: (dureza ≥ 0 e < dano) ou líquido. A condição de distância e TODO o corpo de destruição são os do original.
#
# EQUIVALÊNCIA: `tools/dev_tests/test_procedures_otimizadas.gd` roda esta e a original sobre o mesmo cenário e compara o mundo.
# GATILHO: se `tools/mine_piece/tradutor` regerar a original com mudança, refazer esta cópia (o teste acusa a divergência).
# GERADO por tools/mine_piece/tradutor/traduzir.py de BlockDestroyAllDirectionProcedure.java — não editar.
extends RefCounted

static func execute(world, x: float, y: float, z: float, entity) -> void:
	var t_total := Cronometro.ini()
	_executar(world, x, y, z, entity)
	Cronometro.fim(&"McMundo.BDAD_total", t_total)


static func _executar(world, x: float, y: float, z: float, entity) -> void:
	if (entity != null):
		var logic_water: bool = false
		var glass: bool = false
		var logic_a: bool = false
		var type_flame: bool = false
		var water_breakable: bool = false
		var water: bool = false
		var rock: bool = false
		var wood: bool = false
		var x_dis: float = 0.0
		var damage: float = 0.0
		var distance: float = 0.0
		var cnt_x: float = 0.0
		var x_pos: float = 0.0
		var z_dis: float = 0.0
		var knockback: float = 0.0
		var z_pos: float = 0.0
		var speed: float = 0.0
		var hardness: float = 0.0
		var y_pos: float = 0.0
		var y_dis: float = 0.0
		var RANGE: float = 0.0
		var block_a = Mc.bloco(&"minecraft:air").defaultBlockState()
		var destroy_type: String = ""
		var old_block: String = ""
		if (not (world.isClientSide())):
			if (world.getLevelData().getGameRules().getBoolean(Mc.campo(&"GameRules", &"RULE_MOBGRIEFING"))):
				if (world.getLevelData().getGameRules().getBoolean(Mc.campo(&"GameRules", &"RULE_DOBLOCKDROPS"))):
					logic_a = true
					Mc.definir_em((world.getLevelData().getGameRules().getRule(Mc.campo(&"GameRules", &"RULE_DOBLOCKDROPS"))), false, world.getServer())
				if (entity.getPersistentData().getDouble("effect") == 3.0):
					type_flame = true
				water_breakable = true
				if (((Mc.e(entity, &"RubbleEntity") or Mc.e(entity, &"EntityBirdEntity")) or Mc.e(entity, &"EntityPartisanEntity"))):
					water_breakable = false
				if (((Mc.e(entity, &"RubbleEntity") or Mc.e(entity, &"TornadoEntity")) or Mc.e(entity, &"PadEntity"))):
					type_flame = false
				if (not (entity.getPersistentData().getBoolean("noParticle")) and not ((entity.getPersistentData().getDouble("BlockRange") >= 6.0))):
					var var88: String = "destroy"
				else:
					var var10000: String = "replace"
				knockback = entity.getPersistentData().getDouble("knockback")
				damage = entity.getPersistentData().getDouble("BlockDamage")
				RANGE = entity.getPersistentData().getDouble("BlockRange") + 1.0
				world._estado_pronto()
				var info_mapa: Dictionary = world.info_de_celulas
				var limite_d2: float = max(RANGE * 0.5 * RANGE * 0.5, 1.0)       # [OTIMIZADA] o raio ao quadrado do corpo original, usado para podar o cubo
				x_pos = Mc.math_round(x - RANGE * 0.5)
				var index0: int = 0
				while index0 < int(RANGE):
					x_dis = x_pos - x
					x_dis *= x_dis
					y_pos = Mc.math_round(y - RANGE * 0.5)
					var index1: int = 0
					while index1 < int(RANGE):
						y_dis = y_pos - y
						y_dis *= y_dis
						z_pos = Mc.math_round(z - RANGE * 0.5)
						# [OTIMIZADA] linha toda fora da esfera: nenhuma célula dela passaria na condição de distância do corpo (nada acontece nelas).
						var index2: int = 0 if (x_dis + y_dis) <= limite_d2 else int(RANGE)
						while index2 < int(RANGE):
							var d2_antes: float = z_pos - z
							if (x_dis + y_dis + d2_antes * d2_antes) > limite_d2:
								Cronometro.contar(&"McMundo.BDAD_celulas_podadas")
								z_pos += 1
								index2 += 1
								continue
							var cel := Vector3i(floori(x_pos), floori(y_pos), floori(z_pos))
							var info: Variant = info_mapa.get(cel)
							if info == null:
								var t_cl := Cronometro.ini()
								info = _classificar_celula(world, cel)
								Cronometro.fim(&"McMundo.BDAD_classificar", t_cl)
								info_mapa[cel] = info
							var currentPos = null
							# [OTIMIZADA] célula vazia ou que NENHUMA chamada com este dano destruiria: nada acontece (ver o cabeçalho). O resto é o original.
							if (not (info is bool)) and ((info[1] >= 0.0 and info[1] < damage) or info[2]):
								Cronometro.contar(&"McMundo.BDAD_celulas_candidatas")
								currentPos = Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos])
								block_a = info[0]
								hardness = info[1]
								z_dis = z_pos - z
								z_dis *= z_dis
								distance = x_dis + y_dis + z_dis
								if (distance <= max(RANGE * 0.5 * RANGE * 0.5, 1.0)):
									Cronometro.contar(&"McMundo.BDAD_celulas_no_corpo")
									distance = sqrt(distance)
									cnt_x = 0.0
									var e_l = world.getBlockState(currentPos.east())
									if (e_l.canOcclude() or e_l.getFluidState().isSource()):
										cnt_x += 2.0
									var o_l = world.getBlockState(currentPos.west())
									if (o_l.canOcclude() or o_l.getFluidState().isSource()):
										cnt_x += 2.0
									var s_l = world.getBlockState(currentPos.south())
									if (s_l.canOcclude() or s_l.getFluidState().isSource()):
										cnt_x += 2.0
									var n_l = world.getBlockState(currentPos.north())
									if (n_l.canOcclude() or n_l.getFluidState().isSource()):
										cnt_x += 2.0
									if (not (_marca(block_a, &"jujutsucraft:barrier"))):
										var a_l = world.getBlockState(currentPos.above())
										if (a_l.canOcclude() or a_l.getFluidState().isSource()):
											cnt_x += 1
										var b_l = world.getBlockState(currentPos.below())
										if (b_l.canOcclude() or b_l.getFluidState().isSource()):
											cnt_x += 1
									if (block_a.getBlock() == Mc.bloco(&"minecraft:water") and cnt_x < 10.0):
										if (knockback >= 0.0):
											Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 4.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.5, 5.0]) * knockback, x_pos, x_pos + x_pos - x, y_pos, y_pos + absf(y_pos - y), z_pos, z_pos + z_pos - z, "minepiece:particle_water")
										elif (knockback < 0.0):
											Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 4.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.05, 0.5]) * distance, x_pos, x, y_pos, y, z_pos, z, "minepiece:particle_water")
										if (knockback >= 1.0):
											water = true
									if (cnt_x < 8.0):
										if (not ((Mc.e(block_a.getBlock(), &"LiquidBlock"))) and not ((Mc.e(block_a.getBlock().getStateDefinition().getProperty("waterlogged"), &"BooleanProperty") and block_a.getValue(block_a.getBlock().getStateDefinition().getProperty("waterlogged"))))):
											if (not (_marca(block_a, &"minecraft:impermeable")) and type_flame):
												if (knockback >= 0.0):
													Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 1.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.5, 5.0]) * knockback, x_pos, x_pos + x_pos - x, y_pos, y_pos + y_pos - y, z_pos, z_pos + z_pos - z, "minepiece:particle_magma")
												elif (knockback < 0.0):
													Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 1.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.2, 2.0]) * distance, x_pos, x, y_pos, y, z_pos, z, "minepiece:particle_magma")
											if (_marca(block_a, &"minecraft:mineable/pickaxe")):
												if (knockback >= 0.0):
													Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 1.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.1, 1.0]) * knockback, x_pos, x_pos + x_pos - x, y_pos, y_pos + y_pos - y, z_pos, z_pos + z_pos - z, ("minepiece:particle_ice" if _marca(block_a, &"forge:ice") else "minepiece:particle_big_smoke"))
												elif (knockback < 0.0):
													Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 1.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.01, 0.1]) * distance, x_pos, x, y_pos, y, z_pos, z, ("minepiece:particle_ice" if _marca(block_a, &"forge:ice") else "minepiece:particle_big_smoke"))
												rock = true
											elif (_marca(block_a, &"minecraft:mineable/axe") and hardness > 0.0):
												wood = true
											elif (_marca(block_a, &"minecraft:impermeable")):
												if (knockback >= 0.0):
													Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 4.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.2, 2.0]) * knockback, x_pos, x_pos + x_pos - x, y_pos, y_pos + y_pos - y, z_pos, z_pos + z_pos - z, "minepiece:particle_broken_glass_small")
												elif (knockback < 0.0):
													Mc.proc(&"ParticleGeneratorProcedure").execute(world, 1.0, 4.0, 10.0, Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.025, 0.25]) * distance, x_pos, x, y_pos, y, z_pos, z, "minepiece:particle_broken_glass_small")
												glass = true
											if (_marca(block_a, &"jujutsucraft:barrier")):
												if (not (world.isClientSide())):
													var be = world.getBlockEntity(currentPos)
													old_block = (be.getPersistentData().getString("old_block") if be != null else "")
													world.setBlock(currentPos, (Mc.campo(&"ForgeRegistries", &"BLOCKS").getValue(Mc.novo(&"ResourceLocation", ["jujutsucraft:domain_hole"]))).defaultBlockState(), 3)
													var newBe = world.getBlockEntity(currentPos)
													if (newBe != null):
														newBe.getPersistentData().putString("old_block", old_block)
														newBe.getPersistentData().putString("old_barrier", (str(block_a) + str("")).replace("}", "").replace("Block{", ""))
														newBe.getPersistentData().putDouble("delay_time", distance)
											elif (not (world.isClientSide())):
												world.setBlock(currentPos, Mc.bloco(&"minecraft:air").defaultBlockState(), 3)
											if (not (entity.getPersistentData().getBoolean("ExtinctionBlock"))):
												var spawnChance: float = 0.0
												if (type_flame and randf() < 0.1 + spawnChance):
													block_a = Mc.bloco(&"minecraft:fire").defaultBlockState()
												elif (not (_marca(block_a, &"jujutsucraft:barrier")) and randf() < 0.1 + spawnChance):
													block_a = block_a
												else:
													block_a = Mc.bloco(&"minecraft:air").defaultBlockState()
												if (not (block_a.isAir()) and not (_marca(block_a, &"minecraft:impermeable"))):
													speed = Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.1, 1.0]) * min(knockback * 1.0, 3.0)
													if (Mc.e(world, &"ServerLevel")):
														var entityinstance = Mc.tipo_entidade(&"minecraft:falling_block").create(world)
														if (entityinstance != null):
															var _compoundTag = entityinstance.saveWithoutId(Mc.novo(&"CompoundTag", []))
															Mc.por(_compoundTag, "BlockState", Mc.estatico(&"NbtUtils", &"writeBlockState", [block_a]))
															entityinstance.load(_compoundTag)
															entityinstance.setPos(Mc.math_round(x_pos) + 0.5, Mc.math_round(y_pos), Mc.math_round(z_pos) + 0.5)
															var _ent = entityinstance
															if (not (_ent.level().isClientSide()) and _ent.getServer() != null):
																_ent.getServer().getCommands().performPrefixedCommand(Mc.novo(&"CommandSourceStack", [Mc.campo(&"CommandSource", &"NULL"), _ent.position(), _ent.getRotationVector(), (_ent.level() if Mc.e(_ent.level(), &"ServerLevel") else null), 4, _ent.getName().getString(), _ent.getDisplayName(), _ent.level().getServer(), _ent]), "data merge entity @s {Time:560,DropItem:0b,HurtEntities:0b}")
															if (distance != 0.0):
																entityinstance.setDeltaMovement(Mc.novo(&"Vec3", [(x_pos - x) / distance * speed + entity.getPersistentData().getDouble("x_knockback"), (y_pos - y) / distance * speed + entity.getPersistentData().getDouble("y_knockback"), (z_pos - z) / distance * speed + entity.getPersistentData().getDouble("z_knockback")]))
															world.addFreshEntity(entityinstance)
										elif (logic_water):
											if (not (world.isClientSide())):
												world.setBlock(currentPos, Mc.bloco(&"minecraft:air").defaultBlockState(), 3)
											water = true
							Cronometro.contar(&"McMundo.BDAD_celulas_varridas")
							z_pos += 1
							index2 += 1
						y_pos += 1
						index1 += 1
					x_pos += 1
					index0 += 1
				if (not (entity.getPersistentData().getBoolean("noEffect"))):
					var pitch: float = float(Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), 0.9, 1.1]))
					if (rock and Mc.e(world, &"Level")):
						if (not (world.isClientSide())):
							world.playSound(null, Mc.estatico(&"BlockPos", &"containing", [x, y, z]), Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:stone_crash"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch)
						else:
							world.playLocalSound(x, y, z, Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:stone_crash"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch, false)
					if (wood and Mc.e(world, &"Level")):
						if (not (world.isClientSide())):
							world.playSound(null, Mc.estatico(&"BlockPos", &"containing", [x, y, z]), Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["entity.zombie.break_wooden_door"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch)
						else:
							world.playLocalSound(x, y, z, Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["entity.zombie.break_wooden_door"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch, false)
					if (glass and Mc.e(world, &"Level")):
						if (not (world.isClientSide())):
							world.playSound(null, Mc.estatico(&"BlockPos", &"containing", [x, y, z]), Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:glass_crash"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch)
						else:
							world.playLocalSound(x, y, z, Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:glass_crash"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch, false)
					if (water and Mc.e(world, &"Level")):
						if (not (world.isClientSide())):
							world.playSound(null, Mc.estatico(&"BlockPos", &"containing", [x, y, z]), Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:water_splash"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch)
						else:
							world.playLocalSound(x, y, z, Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:water_splash"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, pitch, false)
				if (logic_a):
					Mc.definir_em((world.getLevelData().getGameRules().getRule(Mc.campo(&"GameRules", &"RULE_DOBLOCKDROPS"))), true, world.getServer())
			entity.getPersistentData().putDouble("BlockRange", 0.0)
			entity.getPersistentData().putDouble("BlockDamage", 0.0)
			entity.getPersistentData().putBoolean("noParticle", false)
			entity.getPersistentData().putBoolean("noEffect", false)
			entity.getPersistentData().putBoolean("ExtinctionBlock", false)


## Classificação intrínseca (não depende de quem pergunta): `true` = vazia; senão [estado, dureza ajustada, líquido-ou-waterlogged].
static func _classificar(world, x_pos: float, y_pos: float, z_pos: float) -> Variant:
	var currentPos = Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos])
	if (world.isEmptyBlock(currentPos)):
		return true
	var block_a = world.getBlockState(currentPos)
	var hardness: float = block_a.getDestroySpeed(world, currentPos)
	if ((_marca(block_a, &"minecraft:logs") or _marca(block_a, &"minecraft:planks"))):
		hardness *= 0.5
	var liquido: bool = (Mc.e(block_a.getBlock(), &"LiquidBlock") or Mc.e(block_a.getBlock().getStateDefinition().getProperty("waterlogged"), &"BooleanProperty") and block_a.getValue(block_a.getBlock().getStateDefinition().getProperty("waterlogged")))
	return [block_a, hardness, liquido]


## Igual a `_classificar`, mas pela CÉLULA (sem montar `BlockPos`, `isEmptyBlock` e `getBlockState` separados): `world.estado_da_celula` é o
## `getBlockState` sobre a mesma célula, com o mesmo cache por quadro. `getDestroySpeed` ignora os argumentos neste jogo (`McBloco.Estado`).
static func _classificar_celula(world, cel: Vector3i) -> Variant:
	var block_a = world.estado_da_celula(cel)
	if block_a.isAir():
		return true
	var hardness: float = block_a.getDestroySpeed(world, null)
	if (_marca(block_a, &"minecraft:logs") or _marca(block_a, &"minecraft:planks")):
		hardness *= 0.5
	var liquido: bool = (Mc.e(block_a.getBlock(), &"LiquidBlock") or Mc.e(block_a.getBlock().getStateDefinition().getProperty("waterlogged"), &"BooleanProperty") and block_a.getValue(block_a.getBlock().getStateDefinition().getProperty("waterlogged")))
	return [block_a, hardness, liquido]


## `estado.is_(BlockTags.create(tag))` memorizado por (tag, bloco): a pertença a uma tag só depende do bloco (e construir `ResourceLocation` + tag a cada
## célula era o que mais custava no corpo da destruição).
static var _marcas := {}


static func _marca(estado, tag: StringName) -> bool:
	var por_bloco: Dictionary = _marcas.get(tag, {})
	var id: StringName = estado.bloco.id
	if por_bloco.has(id):
		return por_bloco[id]
	var r: bool = estado.is_(Mc.estatico(&"BlockTags", &"create", [Mc.novo(&"ResourceLocation", [String(tag)])]))
	por_bloco[id] = r
	_marcas[tag] = por_bloco
	return r
