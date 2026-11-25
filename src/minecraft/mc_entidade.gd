class_name McEntidade
extends RefCounted
# ============================================================================
#  ADAPTADOR de um corpo do jogo (jogador, personagem do Mine Piece, inimigo, animal) para a
#  `Entity`/`LivingEntity`/`Mob` do Minecraft que as procedures traduzidas chamam
#  (docs/MINE_PIECE_COMPLETO_MEDICAO.md, E1). Um adaptador por corpo (`de(no)`, guardado em
#  meta): `entity != entityiterator` compara identidade, como no Java.
#
#  UNIDADES DO MOD: posição em BLOCOS (metros ÷ 0,88), movimento em blocos/TICK, ângulos em
#  graus no sentido do Minecraft (`yRot` 0 = +Z, cresce no sentido horário; no Godot
#  `rotation.y` 0 = −Z): yRot = 180° − rotation.y. As contas das procedures valem sem mudar
#  número nenhum (a mesma regra do `MundoMinePiece`).
# ============================================================================

const B := MundoMinePiece.METROS_POR_BLOCO
const TICK := MundoMinePiece.TICK
const META := "mc_entidade"

var no: Node3D
var _nbt := McNbt.new()
var _efeitos := {}                     # McEfeito → McEfeito.Instancia
var _atributos := {}                   # McAtributo → McAtributo.Instancia
var _rng := RandomNumberGenerator.new()
var tickCount := 0
## Campos públicos da `Entity` que as procedures escrevem direto.
var fallDistance := 0.0
var yRotO := 0.0
var xRotO := 0.0
var yBodyRot := 0.0
var yBodyRotO := 0.0
var yHeadRotO := 0.0
var yHeadRot := 0.0
var hurtMarked := false
var invulnerableTime := 0


static func de(corpo: Node3D) -> McEntidade:
	if corpo == null:
		return null
	if corpo.has_meta(META):
		return corpo.get_meta(META)
	var e := McEntidade.new()
	e.no = corpo
	corpo.set_meta(META, e)
	Mc.mundo(corpo.get_tree()).registrar(e)
	return e


func valida() -> bool:
	return is_instance_valid(no) and not no.is_queued_for_deletion()


# ------------------------------------------------------------ posição e giro
func getX() -> float: return no.global_position.x / B
func getY() -> float: return no.global_position.y / B
func getZ() -> float: return no.global_position.z / B
func position() -> McVec3: return McVec3.de_godot(no.global_position)
func blockPosition() -> McVec3: return position().containing()
func getOnPos() -> McVec3: return position().containing().below()


## MIRA DO JOGADOR (08/11/2026): o corpo do jogador não gira para onde a câmera aponta, então o `getLookAngle` do mod (que lê o yaw/pitch da
## entidade) dava SEMPRE a mesma direção ("o projétil sai sempre para o mesmo lado"). O controlador da fruta guarda a mira (raio da câmera)
## em `META_MIRA` a cada quadro; com ela, yaw, pitch e vetor de visão saem dela. Sem a meta (NPCs, inimigos), vale a rotação do nó.
const META_MIRA := "mc_mira"


func _mira() -> Variant:
	return no.get_meta(META_MIRA) if no.has_meta(META_MIRA) else null


func getYRot() -> float:
	var m: Variant = _mira()
	if m != null:
		return -rad_to_deg(atan2((m as Vector3).x, (m as Vector3).z))
	return 180.0 - rad_to_deg(no.global_rotation.y)
## `setYRot` do mod num JOGADOR HUMANO (nó com `_yaw`) não gira nada: no Minecraft a visão do jogador é do CLIENTE (o servidor reescreve a rotação
## dele a cada pacote de movimento), então golpes giratórios (Crash Pretzel, Mori Mori Root…) só mexem no corpo do servidor e nunca na câmera. Aqui
## o nó raiz é PAI da câmera: girá-lo desalinhava câmera, mira e WASD (`_yaw`) para sempre (varredura 09/11/2026: bisu_bisu Z/X, mori_mori Z…).
## Reorientação de verdade (teleporte com yaw) passa por `Conexao.teleport`, que escreve o `_yaw`.
func setYRot(graus: float) -> void:
	if "_yaw" in no:
		return
	no.rotation.y = deg_to_rad(180.0 - graus)
func getYHeadRot() -> float: return getYRot()
func setYHeadRot(graus: float) -> void: setYRot(graus)
func setYBodyRot(graus: float) -> void: setYRot(graus)
func getXRot() -> float:
	var m: Variant = _mira()
	if m != null:
		return rad_to_deg(asin(clampf(-(m as Vector3).y, -1.0, 1.0)))
	return float(no.get_meta("mc_xrot", 0.0))
func setXRot(graus: float) -> void: no.set_meta("mc_xrot", graus)


## `Entity.calculateViewVector(xRot, yRot)` do Minecraft.
func getViewVector(_parcial: float = 1.0) -> McVec3:
	var m: Variant = _mira()
	if m != null:
		var d := (m as Vector3).normalized()
		return McVec3.de(d.x, d.y, d.z)
	var f := deg_to_rad(getXRot())
	var g := deg_to_rad(-getYRot())
	return McVec3.de(sin(g) * cos(f), -sin(f), cos(g) * cos(f))


func getLookAngle() -> McVec3: return getViewVector()


func getBbHeight() -> float: return float(_ficha().get("altura", 1.8)) * escala(&"height")
func getBbWidth() -> float: return float(_ficha().get("largura", 0.6)) * escala(&"width")
func getEyeHeight() -> float: return getBbHeight() * 0.85
func getEyePosition(_parcial: float = 1.0) -> McVec3: return position().add(0.0, getEyeHeight(), 0.0)
func getBoundingBox() -> McAabb:
	var p := position()
	var w := getBbWidth() * 0.5
	return McAabb.de(McVec3.de(p.x - w, p.y, p.z - w), McVec3.de(p.x + w, p.y + getBbHeight(), p.z + w))


## `Vec2(xRot, yRot)` (comandos usam como rotação da fonte).
func resetFallDistance() -> void: fallDistance = 0.0
func isInWall() -> bool: return not level().noCollision(self)
## Projétil do mod (`AbstractArrow`): dano-base guardado no corpo.
func setBaseDamage(v: float) -> void: no.set_meta("mc_dano_base", v)
func getBaseDamage() -> float: return float(no.get_meta("mc_dano_base", 2.0))
func setCritArrow(_sim: bool) -> void: pass
func setKnockback(n: int) -> void: no.set_meta("mc_empurrao_projetil", n)


## `Projectile.shoot(x, y, z, velocidade, imprecisão)` (blocos/tick): direção normalizada + desvio
## gaussiano 0,0075 × imprecisão, × velocidade; o projétil vira para onde vai.
func shoot(x: float, y: float, z: float, velocidade: float, imprecisao: float) -> void:
	var d := McVec3.de(x, y, z).normalize()
	d = d.add(_rng.randfn() * 0.0075 * imprecisao, _rng.randfn() * 0.0075 * imprecisao, _rng.randfn() * 0.0075 * imprecisao)
	var v := d.scale(velocidade)
	setDeltaMovement(v)
	setYRot(rad_to_deg(atan2(v.x, v.z)))
	setXRot(rad_to_deg(atan2(v.y, v.horizontalDistance())))
## `AbstractArrow.setPierceLevel(n)`: o projétil atravessa até n+1 alvos (cada um uma vez) antes de sumir.
func setPierceLevel(n: int) -> void: no.set_meta("mc_perfura", n)
func getPierceLevel() -> int: return int(no.get_meta("mc_perfura", 0))
func setSilent(_sim: bool) -> void: pass


func getRotationVector() -> McVec3: return McVec3.de(getXRot(), getYRot(), 0.0)
func getEyeY() -> float: return getY() + getEyeHeight()
func getBlockX() -> int: return floori(getX())
func getBlockY() -> int: return floori(getY())
func getBlockZ() -> int: return floori(getZ())


# Montaria: o jogo ainda não monta entidades do mod (barco/navio é outro sistema).
func isPassenger() -> bool: return false
func isVehicle() -> bool: return false
func getVehicle() -> McEntidade: return null
func getFirstPassenger() -> McEntidade: return null
func getPassengers() -> Array: return []
func stopRiding() -> void: pass


func swing(_mao: Variant = null, _todos := false) -> void: pass      # o golpe visual é do executor
## Fogo do Minecraft: 1 de dano por segundo enquanto queima (`tick_efeitos` conta).
var _fogo := 0
func isOnFire() -> bool: return _fogo > 0
func setSecondsOnFire(s: int) -> void: _fogo = maxi(_fogo, s * 20)
func getRemainingFireTicks() -> int: return _fogo
func setRemainingFireTicks(n: int) -> void: _fogo = n
func clearFire() -> void: _fogo = 0
func getAirSupply() -> int: return 300
func setAirSupply(_n: int) -> void: pass
func isUnderWater() -> bool: return isInWater()
func isInvisible() -> bool: return not no.visible
func isUsingItem() -> bool: return false
func isFallFlying() -> bool: return false
func isPickable() -> bool: return isAlive()
func getAbsorptionAmount() -> float: return 0.0
func setAbsorptionAmount(_v: float) -> void: Mc._falta("entidade", "setAbsorptionAmount")
func getTeam() -> Variant: return null
func isAlliedTo(_e: Variant) -> bool: return false
func getMobType() -> StringName: return &"UNDEFINED"
func hasPose(_p: Variant) -> bool: return false
func isCrouching() -> bool: return isShiftKeyDown()


func distanceToSqr(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> float:
	var alvo: Variant = a.position() if a is McEntidade else a
	return position().distanceToSqr(alvo, b, c)


func distanceTo(e: McEntidade) -> float: return sqrt(distanceToSqr(e))


func setPos(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> void:
	no.global_position = McVec3._xyz(a, b, c) * B
	_foto_tocou()


## Dono (projéteis e entidades de golpe do mod).
func setOwner(e: Variant) -> void: no.set_meta("mc_dono", e)
func getOwner() -> McEntidade:
	var d: Variant = no.get_meta("mc_dono") if no.has_meta("mc_dono") else null    # get_meta(.., null) imprime erro se falta
	return d if d is McEntidade and (d as McEntidade).valida() else null


func teleportTo(x: float, y: float, z: float) -> void:
	no.global_position = Vector3(x, y, z) * B
	_foto_tocou()


## A foto das caixas do mundo (`McMundo.getEntitiesOfClass`) vale por quadro: posição escrita pelo mod atualiza a caixa desta entidade.
func _foto_tocou() -> void:
	if no.is_inside_tree():
		var m := Mc.mundo(no.get_tree())
		if m != null:
			m.foto_atualizar(self)
func moveTo(x: Variant, y: Variant = 0.0, z: Variant = 0.0, yaw: float = NAN, _pitch: float = 0.0) -> void:
	var p := McVec3._xyz(x, y, z)                  # moveTo(Vec3) ou moveTo(x, y, z, yaw, pitch)
	teleportTo(p.x, p.y, p.z)
	if not is_nan(yaw):
		setYRot(yaw)


# ------------------------------------------------------------ movimento (blocos/tick)
func getDeltaMovement() -> McVec3:
	var v: Vector3 = no.get("velocity") if "velocity" in no else Vector3.ZERO
	return McVec3.de(v.x, v.y, v.z).scale(TICK / B)


## `LivingEntity.knockback(força, x, z)`: a força é em blocos/tick e o Java empurra a vítima para (−x, −z) (`v/2 − dir × força`);
## `Mob.doHurtTarget` manda (sin yRot, −cos yRot) do atacante, ou seja, para onde ele olha. `KnockbackMinecraft` faz a mesma
## conta em m/s. A resistência a empurrão da vítima reduz a força (`força *= 1 − resistência`).
func knockback(forca: float, x: float, z: float) -> void:
	var resiste := clampf(getAttributeValue(Mc.atributo(&"minecraft:generic.knockback_resistance")), 0.0, 1.0)
	forca *= 1.0 - resiste
	if forca <= 0.0:
		return
	var rumo := Vector3(-x, 0.0, -z)
	if rumo.length_squared() < 0.0001:
		return
	var kb: Variant = no.get("knockback_minecraft") if "knockback_minecraft" in no else no.get("_kb_mc")
	if kb == null:
		return
	var salto: float = kb.empurrar(no.global_position, Vector3.ZERO, rumo, 32.0, onGround(), forca)
	if salto > 0.0 and "velocity" in no:
		no.velocity.y = salto


func setDeltaMovement(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> void:
	var v := McVec3._xyz(a, b, c) * (B / TICK)
	if no.has_method("definir_movimento_de_skill"):
		no.definir_movimento_de_skill(v, true)            # personagem do Mine Piece
	elif "velocity" in no:
		no.velocity = v


func push(a: Variant, b: Variant = 0.0, c: Variant = 0.0) -> void:
	setDeltaMovement(getDeltaMovement().add(a, b, c))


func onGround() -> bool: return no.is_on_floor() if no is CharacterBody3D else true
func isShiftKeyDown() -> bool: return bool(no.get("_agachar").ativo) if no.get("_agachar") != null else false
func isSprinting() -> bool: return _correndo or (no.has_method("_is_sprinting") and no._is_sprinting())
func isInWater() -> bool: return not str(no.get("modo_na_agua") if "modo_na_agua" in no else "").is_empty()
func isInWaterOrBubble() -> bool: return isInWater()
func isInWaterRainOrBubble() -> bool: return isInWater()   # chuva: o jogo não tem


# ------------------------------------------------------------ vida e dano
func getHealth() -> float: return float(no.get("health")) if "health" in no else 0.0
func getMaxHealth() -> float: return float(no.get("max_health")) if "max_health" in no else 0.0
func setHealth(v: float) -> void:
	if "health" in no:
		no.health = clampf(v, 0.0, getMaxHealth())
func heal(v: float) -> void: setHealth(getHealth() + v)
func isAlive() -> bool: return valida() and (getHealth() > 0.0 if "health" in no else true)
func isDeadOrDying() -> bool: return not isAlive()


## `hurt(fonte, dano)`: o dano do mod é em pontos de vida do mod — a mesma unidade da vida da
## história (jogador 20, ficha do personagem). Passa pelo funil do jogo (`take_damage`).
func hurt(fonte: Variant, dano: float) -> bool:
	Mc.contar("hurt:%s:%s:%.1f" % ["jogador" if no.is_in_group("player") else "outro", "vivo" if isAlive() else "morto", dano])
	if not isAlive() or not no.has_method("take_damage"):
		return false
	# O truque do mod para tocar animação: ferir com o tipo `start_animation` (999999). Quem trata é o handler
	# LivingAttackEvent (PlayAnimationEntity/Player → triggerAnim), que cancela; sem dano de verdade.
	if fonte is McFonteDeDano and fonte.tipo == &"minepiece:start_animation":
		McEvento.disparar(&"LivingAttackEvent", self, fonte, dano)
		return false
	var atacante: McEntidade = fonte.atacante if fonte is McFonteDeDano else null
	if atacante != null and atacante.valida() and CombatResolver.e_fogo_amigo(no, atacante.no):
		return false                  # fruta do jogador não fere tripulação, pet nem aliado invocado dele
	var de_onde := atacante.no.global_position if atacante != null and atacante.valida() else Vector3.ZERO
	if atacante != null and atacante.valida():
		no.set_meta("autor_do_dano", atacante.no.get_instance_id())
	# O funil do jogo só recebe posição: o TIPO do dano (damage_combat, curse…) vai junto por meta, para
	# a IA do mod montar os eventos com a fonte verdadeira — é ele que a guarda `is(forge:combat)` do
	# handler de dano lê para não ferir de dentro do próprio evento sem fim.
	var anterior: Variant = no.get_meta("fonte_mc") if no.has_meta("fonte_mc") else null
	no.set_meta("fonte_mc", fonte)
	no.take_damage(dano, de_onde, Vector3.ZERO, 0.0)
	if atacante != null and atacante.valida() and atacante.no.is_in_group("player"):
		PoderDaFruta.contato(atacante.no, no.global_position, dano)        # HTCS: impacto, solo e tremor no contato (só visual)
	if anterior != null:
		no.set_meta("fonte_mc", anterior)
	elif no.has_meta("fonte_mc"):
		no.remove_meta("fonte_mc")
	return true


func kill() -> void:
	if no.has_method("take_damage"):
		# `/kill` do Minecraft ignora a invulnerabilidade (`Invulnerable:1b`, a meta `damage_immune`): o comando mata mesmo assim.
		var imune: bool = no.get_meta("damage_immune", false)
		if imune:
			no.set_meta("damage_immune", false)
		no.take_damage(getHealth() + 1.0e6)
		if imune and is_instance_valid(no):
			no.set_meta("damage_immune", true)
		# Chefe com vida em barras (ou capanga de 5 golpes) limita o dano de UM golpe: o `/kill` não passa por esse filtro, a vida vai a zero e o corpo morre.
		if is_instance_valid(no) and float(no.get("health")) > 0.0 and no.has_method("_morrer"):
			no.set("health", 0.0)
			no.call("_morrer")


func discard() -> void:
	no.queue_free()


func remove(_motivo: Variant = null) -> void: discard()
func damageSources() -> McFonteDeDano.Fontes: return McFonteDeDano.Fontes.new()


# ------------------------------------------------------------ alvo (Mob)
func getTarget() -> McEntidade:
	var cerebro: Variant = no.get("cerebro") if "cerebro" in no else null
	var alvo: Variant = cerebro.alvo if cerebro != null else no.get("alvo") if "alvo" in no else null
	return McEntidade.de(alvo) if alvo != null and is_instance_valid(alvo) and alvo is Node3D else null


func setTarget(e: McEntidade) -> void:
	var cerebro: Variant = no.get("cerebro") if "cerebro" in no else null
	if cerebro != null:
		cerebro.alvo = e.no if e != null else null


func isAggressive() -> bool: return getTarget() != null
func getLastHurtByMob() -> McEntidade:
	var quem: Variant = no.get("ultimo_agressor") if "ultimo_agressor" in no else null
	# O agressor pode já ter sido liberado (morreu e saiu da cena): testar a validade ANTES do tipo.
	return McEntidade.de(quem) if quem != null and is_instance_valid(quem) and quem is Node3D else null


# ------------------------------------------------------------ efeitos
func addEffect(inst: McEfeito.Instancia, _fonte: Variant = null) -> bool:
	if inst == null or inst.efeito == null:
		return false
	var atual: McEfeito.Instancia = _efeitos.get(inst.efeito)
	if atual == null:
		_efeitos[inst.efeito] = McEfeito.instancia(inst.efeito, inst.duracao, inst.amplificador,
			inst.ambiente, inst.visivel, inst.icone)
		_modificadores_do_efeito(inst.efeito, inst.amplificador)
		_gancho(inst.efeito, "ao_comecar", inst.amplificador)
		return true
	var mudou := atual.atualizar(inst)
	if mudou:
		_modificadores_do_efeito(inst.efeito, atual.amplificador)
	return mudou


## O que o efeito vanilla faz nos atributos (tabela `McEfeito.MODIFICADORES`): põe, troca ou tira o modificador.
func _modificadores_do_efeito(e: McEfeito, amplificador: int, tirar := false) -> void:
	for m: Array in McEfeito.MODIFICADORES.get(e.id, []):
		var a := getAttribute(Mc.atributo(m[0]))
		if a == null:
			continue
		var chave := "efeito:%s:%s" % [e.id, m[0]]
		a.modificadores.erase(chave)
		if not tirar:
			var mod := McAtributo.Modificador.new()
			mod.uuid = chave
			mod.nome = String(e.id)
			mod.valor = float(m[1]) * (amplificador + 1)
			mod.operacao = m[2]
			a.modificadores[chave] = mod
		a._mudou()


func hasEffect(e: McEfeito) -> bool: return _efeitos.has(e)
func getEffect(e: McEfeito) -> McEfeito.Instancia: return _efeitos.get(e)
func removeEffect(e: McEfeito) -> bool:
	var inst: McEfeito.Instancia = _efeitos.get(e)
	if inst == null:
		return false
	_efeitos.erase(e)
	_modificadores_do_efeito(e, inst.amplificador, true)
	_gancho(e, "ao_acabar", inst.amplificador)
	return true
func getActiveEffects() -> Array: return _efeitos.values()
func removeAllEffects() -> bool:
	var tinha := not _efeitos.is_empty()
	for e in _efeitos.keys():
		removeEffect(e)
	return tinha


## Um tick dos efeitos (o `McMundo` chama 20 vezes por segundo), como o `tickEffects` do Minecraft:
## `applyEffectTick` quando `isDurationEffectTick` deixa (é ASSIM que as técnicas do mod rodam: o efeito
## `minepiece:skill` despacha a técnica escolhida), a duração desce, e ao vencer roda o "ao acabar".
func tick_efeitos() -> void:
	tickCount += 1
	if _fogo > 0:
		_fogo -= 1
		if _fogo % 20 == 0 and not isInWater():
			hurt(McFonteDeDano.de(&"minecraft:on_fire"), 1.0)
	if _ticks_congelado > 0:
		if isFullyFrozen() and tickCount % 40 == 0:
			hurt(McFonteDeDano.de(&"minecraft:freeze"), 1.0)
		_ticks_congelado = maxi(_ticks_congelado - 2, 0)
	for e: McEfeito in _efeitos.keys():
		var inst: McEfeito.Instancia = _efeitos.get(e)
		if inst == null:
			continue                                   # removido por outro gancho neste tick
		var periodo := int(e.ganchos().get("periodo", 0))
		if periodo > 0 and (inst.duracao == -1 or inst.duracao % periodo == 0):
			_gancho(e, "tick", inst.amplificador)
		if _efeitos.get(e) == inst and not inst.tick():
			removeEffect(e)


func _gancho(e: McEfeito, qual: String, amplificador: int) -> void:
	for nome in e.ganchos().get(qual, []):
		Mc.chamar(StringName(str(nome)), Mc.argumentos_de(self, {"amplifier": amplificador}))


# ------------------------------------------------------------ atributos
func getAttribute(a: McAtributo) -> McAtributo.Instancia:
	if a == null:
		return null
	if not _atributos.has(a):
		var i := McAtributo.Instancia.new()
		i.atributo = a
		i.base = _base_do_atributo(a)
		i.ao_mudar = _atributo_mudou
		_atributos[a] = i
	return _atributos[a]


func getAttributeValue(a: McAtributo) -> float:
	var i := getAttribute(a)
	return i.getValue() if i != null else 0.0


func getAttributeBaseValue(a: McAtributo) -> float:
	var i := getAttribute(a)
	return i.getBaseValue() if i != null else 0.0


func getAttributes() -> McEntidade: return self          # `getAttributes().hasAttribute(a)`
func hasAttribute(a: McAtributo) -> bool: return a != null
func getInstance(a: McAtributo) -> McAtributo.Instancia: return getAttribute(a)


## Base de cada atributo: o `createAttributes` do MOD quando a entidade é do mod; senão a ficha do
## personagem do jogo (unidades do mod) ou o jogador.
func _base_do_atributo(a: McAtributo) -> float:
	var do_mod: Dictionary = Mc.ficha_do_mod(str(no.get("id_personagem")) if "id_personagem" in no else "").get("atributos", {})
	var campo := String(a.id).trim_prefix("minecraft:generic.")
	if a.id != &"minecraft:generic.max_health" and do_mod.has(campo):
		return float(do_mod[campo])            # a vida máxima vem do corpo (que já nasce com a do mod)
	if do_mod.has(String(a.id)):
		return float(do_mod[String(a.id)])
	var f := _ficha()
	match a.id:
		&"minecraft:generic.max_health": return getMaxHealth()
		&"minecraft:generic.armor": return float(f.get("armadura", no.get_meta("armadura_historia", 0.0)))
		&"minecraft:generic.movement_speed": return float(f.get("velocidade", 0.1 if no.is_in_group("player") else a.padrao))
		&"minecraft:generic.attack_damage": return float(f.get("dano_corpo", 1.0 if no.is_in_group("player") else a.padrao))
		&"minecraft:generic.knockback_resistance": return float(f.get("resistencia_a_empurrao", 0.0))
		&"minecraft:generic.follow_range": return float(f.get("alcance_de_perseguicao", a.padrao))
	return a.padrao


func _atributo_mudou(i: McAtributo.Instancia) -> void:
	if i.atributo.id == &"minecraft:generic.max_health" and "max_health" in no:
		no.max_health = i.getValue()
		setHealth(getHealth())


# ------------------------------------------------------------ dados e identidade
func getPersistentData() -> McNbt: return _nbt
func level() -> McMundo: return Mc.mundo(no.get_tree())
func getLevel() -> McMundo: return level()
func getServer() -> McMundo: return level()
func getCommandSenderWorld() -> McMundo: return level()
func getRandom() -> McAleatorio: return McAleatorio.de(_rng)
func getStringUUID() -> String: return str(no.get_instance_id())
func getUUID() -> String: return getStringUUID()
func getId() -> int: return no.get_instance_id()
func getType() -> McTipoEntidade:
	if no.is_in_group("player"):
		return Mc.tipo_entidade(&"minecraft:player")
	var id := str(no.get("id_personagem")) if "id_personagem" in no else ""
	return Mc.tipo_entidade(StringName(("minepiece:" + id) if not id.is_empty() else "minecraft:mob"))


func getName() -> McTexto: return McTexto.de(no.nome_de_exibicao() if no.has_method("nome_de_exibicao") else str(no.name))
func getDisplayName() -> McTexto: return getName()
func setNoAi(sim: bool) -> void: definir_marca("NoAI", sim)
func isNoAi() -> bool: return bool(no.get_meta("mc_sem_ia", false))
func setInvulnerable(sim: bool) -> void: definir_marca("Invulnerable", sim)
func setPersistenceRequired() -> void: definir_marca("PersistenceRequired", true)


## Marcas do `data merge entity` / setters do Minecraft, no corpo do jogo:
##   NoAI → `mc_sem_ia` (o cérebro para; o tick do mod continua, como no Minecraft);
##   Invulnerable → `damage_immune` (a meta que jogador e personagem já respeitam);
##   PersistenceRequired → `mc_persistente` (o spawn natural não some com ele);
##   LeftHanded → só guardado.
func definir_marca(marca: String, sim: bool) -> void:
	match marca:
		"NoAI": no.set_meta("mc_sem_ia", sim)
		"Invulnerable": no.set_meta("damage_immune", sim)
		"PersistenceRequired": no.set_meta("mc_persistente", sim)
		"LeftHanded": no.set_meta("mc_canhoto", sim)
## `Entity.setNoGravity`: o projétil do mod (`McCorpoDoMod._tick_de_projetil`) deixa de cair.
func setNoGravity(sim: bool) -> void: no.set_meta("mc_sem_gravidade", sim)
func isNoGravity() -> bool: return bool(no.get_meta("mc_sem_gravidade", false))
func setInvisible(sim: bool) -> void:
	if no.has_method("ocultar_corpo_por_skill"):
		no.ocultar_corpo_por_skill(sim)
	else:
		no.visible = not sim


# ------------------------------------------------------------ capability (PlayerVariables do mod)
## `LazyOptional` do Forge: `orElse(padrão)` e `ifPresent(função)`.
class Opcional:
	extends RefCounted
	var valor: Variant = null
	func orElse(_padrao: Variant) -> Variant: return valor if valor != null else _padrao
	func ifPresent(f: Callable) -> void:
		if valor != null:
			f.call(valor)
	func isPresent() -> bool: return valor != null


var _variaveis: McVariaveisDoMod.PlayerVariables


## `getCapability(PLAYER_VARIABLES_CAPABILITY, lado)`: as variáveis do mod desta entidade (no mod
## só o jogador tem; aqui todo corpo tem, com os padrões — o mod lê o padrão para quem não tem).
func getCapability(cap: Variant, _lado: Variant = null) -> Opcional:
	if _variaveis == null:
		_variaveis = McVariaveisDoMod.PlayerVariables.new()
	var o := Opcional.new()
	if str(cap) == "ITEM_HANDLER":                               # `ForgeCapabilities.ITEM_HANDLER`: o inventário
		o.valor = Manipulador.new(self) if no.is_in_group("player") else null
	else:
		o.valor = _variaveis if no.is_in_group("player") else null
	return o


## `IItemHandler` do jogador: o INVENTÁRIO estilo Minecraft (hotbar, mochila, armadura, mão secundária: `InventarioMinecraft`, 10/11/2026) MAIS o que as
## procedures do mod puseram nas mãos/armadura (`setItemSlot`), nessa ordem. Sem progressão (testes): só o equipado.
class Manipulador:
	extends RefCounted
	const ESPACOS: Array[StringName] = [&"MAINHAND", &"OFFHAND", &"FEET", &"LEGS", &"CHEST", &"HEAD"]
	var dono: McEntidade
	func _init(d: McEntidade) -> void: dono = d
	func _inv() -> InventarioMinecraft:
		var p := ItensDoMod.progressao(dono.no.get_tree()) if dono.valida() and dono.no.is_inside_tree() else null
		return p.inventario if p != null else null
	func getSlots() -> int:
		var inv := _inv()
		return ESPACOS.size() + (InventarioMinecraft.TOTAL - InventarioMinecraft.MOCHILA_INI if inv != null else 0)
	func getStackInSlot(i: int) -> McItem.Pilha:
		if i < ESPACOS.size():
			return dono.getItemBySlot(ESPACOS[maxi(i, 0)])
		var inv := _inv()
		return inv.pilha(InventarioMinecraft.MOCHILA_INI + i - ESPACOS.size()) if inv != null else McItem.pilha(null, 0)
	## Só a parte do inventário aceita item (as mãos/armadura são do `setItemSlot`). Devolve o que sobrou.
	func insertItem(_i: int, pilha: McItem.Pilha, simular: bool) -> McItem.Pilha:
		var inv := _inv()
		if inv == null or pilha == null or pilha.isEmpty() or simular:
			return pilha
		return inv.inserir(pilha)
	func extractItem(i: int, n: int, simular: bool) -> McItem.Pilha:
		var inv := _inv()
		if inv == null or i < ESPACOS.size():
			return McItem.pilha(null, 0)
		var s: McItem.Pilha = inv.pilha(InventarioMinecraft.MOCHILA_INI + i - ESPACOS.size())
		if s.isEmpty():
			return McItem.pilha(null, 0)
		var t := mini(n, s.quantidade)
		var saida := s.copy()
		saida.quantidade = t
		if not simular:
			inv.remover(String(s.item.id), t)
		return saida


# ------------------------------------------------------------ equipamento (itens na mão e no corpo)
## EquipmentSlot: MAINHAND, OFFHAND, HEAD, CHEST, LEGS, FEET. InteractionHand: MAIN_HAND, OFF_HAND.
var _equipamento := {}
var _correndo := false


func getItemBySlot(espaco: Variant) -> McItem.Pilha:
	return _equipamento.get(StringName(str(espaco)), McItem.pilha(null, 0))


func setItemSlot(espaco: Variant, pilha: McItem.Pilha) -> void:
	var chave := StringName(str(espaco))
	_equipamento[chave] = pilha if pilha != null else McItem.pilha(null, 0)
	# Arma/escudo na mão: o corpo desenha o item (mpi_<item>.glb) no osso da mão.
	if chave in [&"MAINHAND", &"OFFHAND"] and is_instance_valid(no) and no.has_method("equipar_na_mao"):
		var p: McItem.Pilha = _equipamento[chave]
		no.equipar_na_mao(chave, StringName(str(p.item.id)).trim_prefix("minepiece:") if not p.isEmpty() else &"")


func getMainHandItem() -> McItem.Pilha: return getItemBySlot(&"MAINHAND")
func getOffhandItem() -> McItem.Pilha: return getItemBySlot(&"OFFHAND")
func getItemInHand(mao: Variant) -> McItem.Pilha:
	return getItemBySlot(&"OFFHAND" if str(mao) == "OFF_HAND" else &"MAINHAND")
func setItemInHand(mao: Variant, pilha: McItem.Pilha) -> void:
	setItemSlot(&"OFFHAND" if str(mao) == "OFF_HAND" else &"MAINHAND", pilha)
func getArmorSlots() -> Array:
	return [getItemBySlot(&"FEET"), getItemBySlot(&"LEGS"), getItemBySlot(&"CHEST"), getItemBySlot(&"HEAD")]


# ------------------------------------------------------------ inventário do jogador (Player.getInventory)
## O mod usa do inventário só `armor` (índice 0 = botas ... 3 = elmo), `setChanged` e
## `clearOrCountMatchingItems` (317 / 76 / 8 usos). Os slots de armadura são os do equipamento da entidade;
## o resto do inventário (mochila, hotbar) ainda não existe no jogo: contar/tirar vale só para o que está
## equipado (mãos e armadura) — o jogo tem inventário próprio, fora da camada.
const _ESPACOS_ARMADURA: Array[StringName] = [&"FEET", &"LEGS", &"CHEST", &"HEAD"]
class Armadura:
	extends RefCounted
	var dono: McEntidade
	func obter(i: Variant) -> McItem.Pilha: return dono.getItemBySlot(McEntidade._ESPACOS_ARMADURA[int(i)])
	func definir_chave(i: Variant, v: Variant) -> McItem.Pilha:
		var antes := obter(i)
		dono.setItemSlot(McEntidade._ESPACOS_ARMADURA[int(i)], v)
		return antes
	func size() -> int: return 4
class Inventario:
	extends RefCounted
	var dono: McEntidade
	var armor: Armadura
	func setChanged() -> void: pass
	## Conta (count = 0) ou tira até `count` itens que casam (count < 0: todos), nas mãos e na armadura.
	func clearOrCountMatchingItems(teste: Callable, count: int, _craft: Variant = null) -> int:
		var achados := 0
		for espaco in [&"MAINHAND", &"OFFHAND", &"FEET", &"LEGS", &"CHEST", &"HEAD"]:
			var p: McItem.Pilha = dono.getItemBySlot(espaco)
			if p.isEmpty() or not bool(teste.call(p)):
				continue
			achados += p.getCount()
			if count != 0:
				dono.setItemSlot(espaco, McItem.pilha(null, 0))
		return achados
class MenuDoInventario:
	extends RefCounted
	func getCraftSlots() -> Array: return []
var _inventario: Inventario
var inventoryMenu := MenuDoInventario.new()
func getInventory() -> Inventario:
	if _inventario == null:
		_inventario = Inventario.new()
		_inventario.dono = self
		_inventario.armor = Armadura.new()
		_inventario.armor.dono = self
	return _inventario


# ------------------------------------------------------------ animação de técnica (GeckoLib `triggerAnim`)
## `triggerAnim("procedure", nome)`: toca o clipe de mesmo nome do modelo; "empty" devolve ao ciclo base.
## O nome fica em `mc_animacao` (o campo `animationprocedure` que `GetEntityAnimationProcedure` lê).
func triggerAnim(_controlador: Variant, nome: String) -> void:
	no.set_meta("mc_animacao", nome)
	Mc.contar("anim:" + nome)
	if is_instance_valid(no) and no.has_method("tocar_tecnica"):
		no.tocar_tecnica(nome)
func setAnimation(nome: String) -> void: triggerAnim("procedure", nome)

## `entity.getClass().getField("animationprocedure")` / `.getMethod("setAnimation", String).invoke(...)`: reflexão
## de Java reduzida ao que as procedures usam.
class ClasseJava:
	extends RefCounted
	func getField(nome: String) -> Campo:
		var c := Campo.new()
		c.nome = nome
		return c
	func getMethod(nome: String, _tipo: Variant = null) -> Metodo:
		var m := Metodo.new()
		m.nome = nome
		return m
class Campo:
	extends RefCounted
	var nome := ""
	func obter(alvo: Variant) -> Variant:
		return alvo.no.get_meta("mc_animacao", "") if alvo is McEntidade and nome == "animationprocedure" else Mc._falta("campo", nome)
class Metodo:
	extends RefCounted
	var nome := ""
	func invoke(alvo: Variant, a: Variant = null) -> Variant:
		if alvo is McEntidade and nome == "setAnimation":
			(alvo as McEntidade).triggerAnim("procedure", str(a))
			return null
		return Mc._falta("metodo", nome)
func getClass() -> ClasseJava: return ClasseJava.new()


## Congelamento (`Entity.ticksFrozen`): 140 ticks = congelado por completo; fora da neve em pó cai 2 por tick (`tick_efeitos`);
## congelado por completo leva 1 de dano a cada 40 ticks. Os golpes da Hie (Effect12: +20, teto 80) e o Okuchi no Makami usam isto.
const TICKS_PARA_CONGELAR := 140
var _ticks_congelado := 0
func getPercentFrozen() -> float: return minf(float(_ticks_congelado), float(TICKS_PARA_CONGELAR)) / TICKS_PARA_CONGELAR
func getTicksFrozen() -> int: return _ticks_congelado
func setTicksFrozen(n: int) -> void: _ticks_congelado = maxi(n, 0)
func isFullyFrozen() -> bool: return _ticks_congelado >= TICKS_PARA_CONGELAR


## `lookAt(âncora, ponto)`: vira o corpo (guinada e inclinação do Minecraft) para o ponto, em blocos.
func lookAt(_ancora: Variant, ponto: Variant) -> void:
	if not (ponto is McVec3):
		return
	var de := position().add(0.0, getEyeHeight(), 0.0)
	var d := (ponto as McVec3).subtract(de)
	var plano := sqrt(d.x * d.x + d.z * d.z)
	setYRot(rad_to_deg(atan2(-d.x, d.z)))
	no.set_meta("mc_xrot", -rad_to_deg(atan2(d.y, plano)))


func setSprinting(sim: bool) -> void: _correndo = sim
## `setShiftKeyDown`: o mod faz NPC agachar (IA de espreita). No corpo do jogo é a meta que o agachar lê.
func setShiftKeyDown(sim: bool) -> void:
	if valida():
		no.set_meta("agachado_mc", sim)
## `displayClientMessage(texto, barraDeAcao)`: aviso na tela do jogador (ex.: "alvo inválido"). O HUD do jogo ainda
## não tem este canal: CONTADO (`hud:mensagem`) em vez de engolido.
## `Player.displayClientMessage(texto, barraDeAção)`: a mensagem do mod vira o aviso do HUD do jogo (só para o jogador
## local; o texto traduzido do mod, sem os códigos de cor `§x`). Outros corpos não têm tela.
func displayClientMessage(texto: Variant = null, _barra: Variant = false) -> void:
	if not valida() or not no.is_in_group("player") or not no.is_multiplayer_authority():
		return
	var hud := no.get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("avisar"):
		Mc._falta("hud", "mensagem_sem_hud")
		return
	var t := McTexto.traduzir(str(texto.texto if texto is McTexto else texto))
	var limpo := RegEx.create_from_string("§.").sub(t, "", true)
	hud.avisar(limpo)
func setCustomName(texto: Variant) -> void:
	if valida():
		if texto == null:
			no.remove_meta("nome_mc") if no.has_meta("nome_mc") else null
		else:
			no.set_meta("nome_mc", str(texto))
## `load(tag)`: recria o corpo a partir do NBT (o mod usa em entidades virtuais). Só a vida é restaurada.
func load(tag: McNbt) -> void:
	if tag == null:
		return
	if tag.contains("Health"):
		setHealth(tag.getFloat("Health"))
	if tag.contains("BlockState") and no.has_method("definir_bloco"):      # bloco em queda
		var estado: Variant = tag.dados.get("BlockState")
		var nome := str((estado as McNbt).dados.get("Name", "minecraft:stone")) if estado is McNbt else str(estado)
		no.definir_bloco(StringName(nome))
func getCustomName() -> Variant: return str(no.get_meta("nome_mc")) if valida() and no.has_meta("nome_mc") else null
## `saveWithoutId(tag)`: o mod lê o corpo como NBT para recriá-lo (`load`). Só o que a camada guarda.
func saveWithoutId(tag: McNbt) -> McNbt:
	tag.putFloat("Health", getHealth())
	tag.putDouble("PosX", getX())
	tag.putDouble("PosY", getY())
	tag.putDouble("PosZ", getZ())
	return tag


# ------------------------------------------------------------ metas de IA (goalSelector/targetSelector)
## No jogo quem escolhe alvo e anda é o `CerebroMinePiece`. As metas do mod viram pedidos a ele:
## `HurtByTargetGoal` = revidar quem bateu (o cérebro já faz em `foi_atacado`).
class Meta:
	extends RefCounted
	var tipo: StringName
	var args: Array
	static func de(t: StringName, a: Array) -> Meta:
		var m := Meta.new()
		m.tipo = t
		m.args = a
		return m


class SeletorDeMetas:
	extends RefCounted
	var dono: McEntidade
	var metas := {}
	func addGoal(prioridade: int, m: Variant) -> void:
		metas[m] = prioridade
		if m is Meta and (m as Meta).tipo == &"HurtByTargetGoal":
			var quem := dono.getLastHurtByMob()
			var cerebro: Variant = dono.no.get("cerebro") if "cerebro" in dono.no else null
			if quem != null and cerebro != null and cerebro.has_method("foi_atacado"):
				cerebro.foi_atacado(quem.no)
	func removeGoal(m: Variant) -> void: metas.erase(m)
	func getRunningGoals() -> Array: return []
	func getAvailableGoals() -> Array: return metas.keys()


var _alvo_metas := SeletorDeMetas.new()
var _acao_metas := SeletorDeMetas.new()
var targetSelector: SeletorDeMetas:
	get:
		_alvo_metas.dono = self
		return _alvo_metas
var goalSelector: SeletorDeMetas:
	get:
		_acao_metas.dono = self
		return _acao_metas


## `getNavigation()`: no jogo quem anda é o corpo (`andar`, o mesmo do cérebro).
class Navegacao:
	extends RefCounted
	var dono: McEntidade
	func stop() -> void:
		if dono.no.has_method("andar"):
			dono.no.andar(Vector3.ZERO)
	func moveTo(a: Variant, b: Variant = 1.0, c: Variant = null, d: Variant = null) -> bool:
		var alvo: Vector3
		var vel := 1.0
		if a is McEntidade:
			alvo = (a as McEntidade).no.global_position
			vel = float(b)
		else:
			alvo = Vector3(float(a), float(b), float(c)) * B
			vel = float(d) if d != null else 1.0
		if not dono.no.has_method("andar"):
			return false
		var dir := alvo - dono.no.global_position
		dir.y = 0.0
		var rapidez: float = dono.no.velocidade_de_andar() if dono.no.has_method("velocidade_de_andar") else 3.0
		dono.no.andar(dir.normalized() * rapidez * vel if dir.length() > 0.3 else Vector3.ZERO)
		return true
	func isDone() -> bool: return true
	func isInProgress() -> bool: return false


func getNavigation() -> Navegacao:
	var n := Navegacao.new()
	n.dono = self
	return n


# ------------------------------------------------------------ conquistas (advancements) — sem sistema no jogo
## Tudo "já concluído": o mod só dá conquista a quem ainda não a tem, então nada é concedido (contado).
class Progresso:
	extends RefCounted
	func isDone() -> bool: return true
	func getRemainingCriteria() -> Array: return []
	func awardCriterion(_c: Variant) -> bool: return false
class Conquistas:
	extends RefCounted
	func getAdvancement(id: Variant) -> Variant:
		Mc._falta("conquista", str(id))
		return id
	func getOrStartProgress(_a: Variant) -> Progresso: return Progresso.new()
	func award(_a: Variant, _c: Variant) -> bool: return false
var server: McMundo:
	get: return level()
## O jogador tem as conquistas de verdade (`McConquistas`); os outros corpos, o stub "já concluído" acima.
func getAdvancements() -> Variant:
	if valida() and no.is_in_group("player"):
		return conquistas_do_jogador()
	return Conquistas.new()


var _avancos: McConquistas.Avancos
## A progressão trocou (carregar save): o estado das conquistas é outro dicionário.
func religar_conquistas() -> void:
	_avancos = null
func conquistas_do_jogador() -> McConquistas.Avancos:
	if _avancos == null:
		_avancos = McConquistas.Avancos.new()
		_avancos.jogador = self
		_avancos.estado = no.get_meta("conquistas_do_mod") if no.has_meta("conquistas_do_mod") else {}
		no.set_meta("conquistas_do_mod", _avancos.estado)
	return _avancos


## `SynchedEntityData`: o estado que o mod sincroniza (TEXTURE, ANIMATION, SHOOT, DATA_*). Valor inicial = o do
## `defineSynchedData` da classe (extraído em `entidades_do_mod.json`, campo `dados`); guardado no corpo.
class Dados:
	extends RefCounted
	var dono: McEntidade
	func _mapa() -> Dictionary:
		if not dono.no.has_meta("mc_dados"):
			var id := str(dono.no.get("id_personagem")) if "id_personagem" in dono.no else ""
			dono.no.set_meta("mc_dados", (Mc.ficha_do_mod(id).get("dados", {}) as Dictionary).duplicate())
		return dono.no.get_meta("mc_dados")
	func obter(chave: Variant = null) -> Variant: return _mapa().get(str(chave), 0)
	func get_(chave: Variant) -> Variant: return obter(chave)
	func definir_chave(chave: Variant, valor: Variant) -> Variant:
		var m := _mapa()
		var antes: Variant = m.get(str(chave))
		m[str(chave)] = valor
		return antes
	func set_(chave: Variant, valor: Variant) -> void: definir_chave(chave, valor)
func getEntityData() -> Dados:
	var d := Dados.new()
	d.dono = self
	return d
func setTexture(nome: String) -> void: getEntityData().definir_chave("TEXTURE", nome)
## `obter` devolve a textura (String) ou o padrão numérico 0 quando nunca foi posta: só texto vale (comparar texto com 0 dava erro todo quadro).
func getTexture() -> String:
	var t: Variant = getEntityData().obter("TEXTURE")
	return t if t is String else ""


## `player.getCooldowns().addCooldown(item, ticks)`: recarga POR ITEM (09/11/2026, item 5): antes era um no-op e a habilidade de arma do mod nunca
## esperava. Vale em tempo de relógio (tique do Minecraft = 0,05 s); guardada no corpo, então `getCooldowns()` devolve sempre a mesma.
class Recargas:
	extends RefCounted
	var _ate_ms := {}                                          # id do item → Time.get_ticks_msec() em que libera
	func addCooldown(item: Variant, ticks: Variant) -> void:
		if item == null or int(ticks) <= 0:
			return
		_ate_ms[str(item.id if item is McItem else item)] = Time.get_ticks_msec() + int(float(ticks) * 50.0)
	func isOnCooldown(item: Variant) -> bool:
		var k := str(item.id if item is McItem else item)
		return _ate_ms.has(k) and Time.get_ticks_msec() < int(_ate_ms[k])
	func getCooldownPercent(item: Variant, _parcial: Variant = 0.0) -> float:
		var k := str(item.id if item is McItem else item)
		return 1.0 if isOnCooldown(item) else 0.0
func getCooldowns() -> Recargas:
	if not no.has_meta("mc_recargas"):
		no.set_meta("mc_recargas", Recargas.new())
	return no.get_meta("mc_recargas")


## `serverPlayer.connection.teleport(x, y, z, yaw, pitch)` (blocos).
class Conexao:
	extends RefCounted
	var dono: McEntidade
	func teleport(x: Variant, y: Variant, z: Variant, yaw: Variant = null, pitch: Variant = null) -> void:
		dono.no.global_position = Vector3(float(x), float(y), float(z)) * MundoMinePiece.METROS_POR_BLOCO
		dono._foto_tocou()
		# O mod reenvia a visão ATUAL (`teleport(x, y, z, getYRot(), getXRot())`): no Minecraft isso não gira nada. Aqui `getYRot()` é a
		# MIRA do jogador, e gravá-la no nó raiz girava a câmera (filha do nó) em relação ao `_yaw` do WASD/mira — o B do Batto Batto
		# (StepBlock) deixava câmera e teclas tortas para sempre (09/11/2026). Só uma reorientação de verdade muda a visão, e a visão do
		# jogador é o `_yaw`, nunca a rotação do nó.
		if yaw != null and absf(wrapf(float(yaw) - dono.getYRot() + 180.0, 0.0, 360.0) - 180.0) > 0.01:
			if "_yaw" in dono.no:
				dono.no.set("_yaw", deg_to_rad(180.0 - float(yaw)))
				if dono.no.has_method("_update_pivot"):
					dono.no.call("_update_pivot")
			else:
				dono.setYRot(float(yaw))
		if pitch != null:
			dono.no.set_meta("mc_xrot", float(pitch))
var connection: Conexao:
	get:
		var c := Conexao.new()
		c.dono = self
		return c


# ------------------------------------------------------------ jogador (modo de jogo)
## O jogo não tem criativo/espectador: todo jogador é SURVIVAL (o mod pula quem não é).
class Habilidades:
	extends RefCounted
	var instabuild := false
	var invulnerable := false
	var flying := false
	var mayfly := false


class ModoDeJogo:
	extends RefCounted
	func getGameModeForPlayer() -> StringName: return &"SURVIVAL"


class Perfil:
	extends RefCounted
	var nome := ""
	var id := ""
	func getName() -> String: return nome
	func getId() -> String: return id


var gameMode := ModoDeJogo.new()
func getGameProfile() -> Perfil:
	var p := Perfil.new()
	p.nome = getName().getString()
	p.id = getStringUUID()
	return p
var _habilidades := Habilidades.new()
func getAbilities() -> Habilidades: return _habilidades

# ------------------------------------------------------------ pacote de servidor (ver `McServidor`)
## O jogo não tem criativo/espectador: todo jogador é SURVIVAL. `setGameMode` do mod (arena PVP) é registrado mas não muda regra.
func getGameMode() -> StringName: return StringName(no.get_meta("mc_modo_de_jogo", McServidor.MODO_PADRAO))
func setGameMode(modo: Variant) -> void: no.set_meta("mc_modo_de_jogo", StringName(str(modo)))
func closeContainer() -> void: pass                        # menus do Minecraft (inventário/baú): o jogo usa outras telas
func getFoodData() -> McServidor.Alimento:
	if not no.has_meta("mc_alimento"):
		no.set_meta("mc_alimento", McServidor.Alimento.new())
	return no.get_meta("mc_alimento")
func tame(dono: Variant = null) -> bool:
	no.set_meta("mc_domesticado", true)
	if dono is McEntidade:
		no.set_meta("mc_dono_id", (dono as McEntidade).getStringUUID())
	return true
func isTame() -> bool: return bool(no.get_meta("mc_domesticado", false))
func setPickUpDelay(_n: Variant) -> void: pass
func startRiding(_outro: Variant, _forcar: Variant = false) -> bool: return false     # montaria é outro sistema (`montaria.gd`)
func isInvulnerable() -> bool: return bool(no.get_meta("damage_immune", false))
func isCreative() -> bool: return false
func isSpectator() -> bool: return false


func _ficha() -> Dictionary:
	var f: Variant = no.get("ficha") if "ficha" in no else null
	return f if f is Dictionary else {}


# ------------------------------------------------------------ escala do corpo (Pehkui: `scale set|add|subtract pehkui:<tipo>`)
## `height` e `width` (1 = tamanho normal) e `reach` (alcance de interação). Guardado no corpo (`mc_escala`) e APLICADO por
## quem sabe redimensionar: o jogador (`definir_escala_de_forma`: modelo + cápsula + hurtbox + câmera, junto com a raça),
## o personagem (`aplicar_escala_mc`) e o corpo virtual (desenho). `getBbHeight/getBbWidth` já devolvem a caixa escalada.
## `reach` fica registrado, mas o alcance do corpo a corpo do jogador não o lê (ver docs/MINE_PIECE_COMPLETO_MEDICAO.md).
const ESCALA_MINIMA := 0.1
const ESCALA_MAXIMA := 16.0


func escala(tipo: StringName) -> float:
	if not valida() or not no.has_meta("mc_escala"):
		return 1.0
	return float((no.get_meta("mc_escala") as Dictionary).get(tipo, 1.0))


func definirEscala(tipo: StringName, valor: float) -> void:
	if not valida():
		return
	var e: Dictionary = no.get_meta("mc_escala") if no.has_meta("mc_escala") else {}
	e[tipo] = clampf(valor, ESCALA_MINIMA, ESCALA_MAXIMA)
	no.set_meta("mc_escala", e)
	var h := escala(&"height")
	var w := escala(&"width")
	if no.has_method("definir_escala_de_forma"):                 # o jogador
		no.definir_escala_de_forma(h, w)
	elif no.has_method("aplicar_escala_mc"):                     # personagem do mod
		no.aplicar_escala_mc(h, w)
	# corpo virtual (`McCorpoDoMod`): o desenho lê `escala(&"height")` a cada quadro, nada a fazer aqui
