# AJUSTADA a partir de gerado/procedures/FujitoraMeteorSmallProcedure.gd (13/11/2026) — NÃO é gerada e NÃO é equivalente à original: ver `Mc.AJUSTADAS`.
# POR QUE (queixa do dono: "o X é muito lento para cair os meteoros, o que o coloca em desvantagem"): o meteoro nascia 200 blocos acima e descia 0,5 bloco/tick
# (`teleportTo(y + y_power * 0,1)`, y_power −5) = ~400 ticks = 20 s no ar. O que muda: (1) nasce `ALTURA_DE_QUEDA` = 48 blocos acima; (2) y_power −8 (0,8 bloco/tick,
# ~1,2 s de queda medida); (3) AVISO no chão no ponto do impacto (anel roxo, HTCS: leitura antes do dano). Dano, alcance e posições seguem o mod.
# (4) o meteoro é desenhado como CUBO que gira (`forma_cubica`, ver `McCorpoDoMod._tornar_cubico`).
# GATILHO: regerar a original → reconferir esta cópia (o `test_poderes_htcs` mede o tempo de queda).
extends RefCounted

const ALTURA_DE_QUEDA := 48.0          # blocos acima do ponto do impacto (o mod: 200)
const VELOCIDADE_DE_QUEDA := -8.0       # y_power (o mod: −5); o meteoro desce y_power × 0,1 bloco por tick: ~1,2 s de queda com o aviso no chão

static func execute(world, entity) -> void:
	if (entity != null):
		var CNT6: float = 0.0
		var HP: float = 0.0
		var range_: float = 0.0
		var x_pos: float = 0.0
		var y_pos: float = 0.0
		var z_pos: float = 0.0
		var yaw: float = 0.0
		var dis: float = 0.0
		var distance: float = 0.0
		var pitch: float = 0.0
		entity.getPersistentData().putDouble("cnt1", entity.getPersistentData().getDouble("cnt1") + 1.0)
		entity.fallDistance = 0.0
		if (Mc.e(entity, &"LivingEntity") and not (entity.level().isClientSide())):
			entity.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito(&"minepiece:cooldown_time"), int(entity.getPersistentData().getDouble("COOLDOWN_TICKS")), 0, false, false]))
		if (Mc.e(entity, &"LivingEntity") and not (entity.level().isClientSide())):
			entity.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito(&"minecraft:movement_slowdown"), 2, 9, false, false]))
		entity.setDeltaMovement(Mc.novo(&"Vec3", [0.0, min(entity.getDeltaMovement().y, -0.5), 0.0]))
		range_ = Mc.proc(&"ReturnEntitySizeProcedure").execute(entity)
		CNT6 = 1.0 + entity.getPersistentData().getDouble("cnt6") * 0.1
		x_pos = entity.getX()
		y_pos = entity.getY()
		z_pos = entity.getZ()
		if (Mc.e(entity, &"LivingEntity") and entity.getAttributes().hasAttribute(Mc.atributo(&"minepiece:animation_1"))):
			entity.getAttribute(Mc.atributo(&"minepiece:animation_1")).setBaseValue(-20.0)
		if (Mc.e(entity, &"LivingEntity") and entity.getAttributes().hasAttribute(Mc.atributo(&"minepiece:animation_2"))):
			entity.getAttribute(Mc.atributo(&"minepiece:animation_2")).setBaseValue(0.0)
		Mc.proc(&"PlayAnimationProcedure").execute(world, entity)
		if (entity.getPersistentData().getDouble("cnt1") > 0.0):
			entity.getPersistentData().putDouble("cnt1", -1.0)
			entity.getPersistentData().putDouble("cnt2", entity.getPersistentData().getDouble("cnt2") + 1.0)
			if (entity.getPersistentData().getDouble("cnt2") == 1.0 and Mc.e(world, &"Level")):
				if (not (world.isClientSide())):
					world.playSound(null, Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos, z_pos]), Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:gravity"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, 1.0)
				else:
					world.playLocalSound(x_pos, y_pos, z_pos, Mc.campo(&"ForgeRegistries", &"SOUND_EVENTS").getValue(Mc.novo(&"ResourceLocation", ["minepiece:gravity"])), Mc.campo(&"SoundSource", &"NEUTRAL"), 1.0, 1.0, false)
			yaw = deg_to_rad(entity.getYRot() + 90.0 + Mc.estatico(&"Mth", &"nextDouble", [Mc.estatico(&"RandomSource", &"create", []), -22.5, 22.5]))
			pitch = deg_to_rad(0.0)
			distance = 0.5 * entity.getBbWidth() + entity.getPersistentData().getDouble("cnt2") * 5.0 * range_
			x_pos = entity.getX() + cos(yaw) * cos(pitch) * distance
			y_pos = entity.getY() + sin(pitch) * -1.0 * distance
			z_pos = entity.getZ() + sin(yaw) * cos(pitch) * distance
			HP = 50 + ((entity.getEffect(Mc.efeito(&"minecraft:damage_boost")).getAmplifier() if Mc.e(entity, &"LivingEntity") and entity.hasEffect(Mc.efeito(&"minecraft:damage_boost")) else 0)) * 10
			Mc.proc(&"ParticleGeneratorCircleProcedure").execute(world, 36.0 * range_, 90.0, 3.0 * range_, 3.0 * range_, 8.0, x_pos, x_pos, y_pos, y_pos + 8.0, 0.0, z_pos, z_pos, "minepiece:particle_purple")
			entity.getPersistentData().putDouble("y_knockback", 0.5)
			entity.getPersistentData().putDouble("BlockDamage", 0.05)
			entity.getPersistentData().putDouble("BlockRange", 4.0 * range_)
			Mc.proc(&"BlockDestroyAllDirectionProcedure").execute(world, x_pos, y_pos, z_pos, entity)
			entity.getPersistentData().putDouble("knockback", 0.1)
			entity.getPersistentData().putDouble("Range", 8.0 * range_)
			Mc.proc(&"KnockbackProcedure").execute(world, x_pos, y_pos, z_pos, entity)
			entity.getPersistentData().putDouble("y_knockback", 0.0)
			if entity.has_method("level") and entity.get("no") != null:
				var onde_aviso: Vector3 = McVec3.de(x_pos, y_pos, z_pos).para_godot()
				PoderVfx.impacto(entity.no, onde_aviso, Color(0.7, 0.35, 1.0), 4.0 * range_ * MundoMinePiece.METROS_POR_BLOCO + 1.0, PoderVfx.Forma.TRIANGULO)       # aviso: onde vai cair
			if (Mc.e(world, &"ServerLevel")):
				var entityinstance = (Mc.tipo_entidade(&"minepiece:meteor")).create(world, null, null, Mc.estatico(&"BlockPos", &"containing", [x_pos, y_pos + ALTURA_DE_QUEDA, z_pos]), Mc.campo(&"MobSpawnType", &"MOB_SUMMONED"), false, false)
				if (entityinstance != null):
					entityinstance.setYRot(world.getRandom().nextFloat() * 360.0)
					Mc.proc(&"SetRangedAmmoProcedure").execute(entity, entityinstance)
					var _ent = entityinstance
					_ent.setYRot(entity.getYRot())
					_ent.setXRot(0.0)
					_ent.setYBodyRot(_ent.getYRot())
					_ent.setYHeadRot(_ent.getYRot())
					_ent.yRotO = _ent.getYRot()
					_ent.xRotO = _ent.getXRot()
					if (Mc.e(_ent, &"LivingEntity")):
						_ent.yBodyRotO = _ent.getYRot()
						_ent.yHeadRotO = _ent.getYRot()
					if (Mc.e(entityinstance, &"LivingEntity") and entityinstance.getAttributes().hasAttribute(Mc.atributo(&"minecraft:max_health"))):
						entityinstance.getAttribute(Mc.atributo(&"minecraft:max_health")).setBaseValue(HP)
					if (Mc.e(entityinstance, &"LivingEntity")):
						entityinstance.setHealth(float(HP))
					entityinstance.getPersistentData().putDouble("forma_cubica", 1.0)        # meteoros QUADRADOS (pedido do dono, 13/11/2026)
					entityinstance.getPersistentData().putDouble("x_power", 0.0)
					entityinstance.getPersistentData().putDouble("y_power", VELOCIDADE_DE_QUEDA)
					entityinstance.getPersistentData().putDouble("z_power", 0.0)
					entityinstance.getPersistentData().putDouble("cnt6", -2.5)
					if (Mc.e(entityinstance, &"LivingEntity") and entityinstance.getAttributes().hasAttribute(Mc.atributo(&"minepiece:size"))):
						entityinstance.getAttribute(Mc.atributo(&"minepiece:size")).setBaseValue(0.1 * range_)
					world.addFreshEntity(entityinstance)
		if (entity.getPersistentData().getDouble("cnt2") > 8.0):
			entity.getPersistentData().putDouble("skill", 0.0)

