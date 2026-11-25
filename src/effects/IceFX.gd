class_name IceFX
extends RefCounted

# ============================================================================
#  ICE FX — Geração de GELO procedural e detalhada (Hie Hie no Mi).
#
#  SKILLS:
#   Z: Disparo de Gelo — Projétil de gelo rápido (estilo Higan, mas de gelo).
#   X: Iceberg — Erguer a mão direita, criar um iceberg gigante e lançá-lo.
#   C: Investida de Gelo — Dash congelante; ao atingir o alvo, congela por 5s.
#   V: Ice Age — Congela o chão por 50 segundos. Qualquer um que pise
#      (menos o conjurador) é congelado por 5s, ganha 2s de imunidade e recongela.
#
#  07/10/2026 (Hie refeita no Skills Builder, pedido do dono): TODOS os golpes
#  congelam 0,7 s (`CONGELAR`), com 0,5 s de imunidade depois (`IMUNIDADE`) — o Z
#  (agora do Builder), o X, o C e o campo do V. Os "5 s/2 s" acima são o de antes.
# ============================================================================

const CONGELAR := 0.7
const IMUNIDADE := 0.5

const FROST := [
	Color(0.85, 0.95, 1.0, 0.95), # azul gelo brilhante
	Color(0.45, 0.75, 1.0, 0.8),  # ciano translúcido
	Color(0.2, 0.5, 0.85, 0.4),   # azul profundo
	Color(0.1, 0.2, 0.4, 0.0),    # névoa que some
]

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match variant:
		0: _disparo_de_gelo(world, origin, dir, damage, caster, spec)
		1: _iceberg(world, origin, dir, damage, caster, spec)
		2: _investida_de_gelo(world, origin, dir, damage, caster, spec)
		_: _ice_age(world, caster.global_position if caster else origin, damage, caster, spec)

static func _frost_proc(radius: float, up: float) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 45.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = up
	pm.gravity = Vector3(0, -0.3, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color_ramp = FxUtil.gradient(FROST)
	pm.scale_curve = FxUtil.curve([[0.0, 0.2], [0.3, 1.0], [1.0, 0.0]])
	if radius > 0.0:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = radius
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.9
	return pm

static func _crystal_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.65, 0.88, 1.0, 0.78)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.08
	mat.metallic = 0.25
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.75, 1.0)
	mat.emission_energy_multiplier = 2.5
	return mat

static func _crystal(height: float, width: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(width, height, width)
	mi.mesh = pm
	mi.material_override = _crystal_mat()
	return mi

# FLECHA DE GELO (rajada do Z, análoga à bala de fogo da Mera) — projétil fino,
# ciano brilhante, viaja MUITO rápido, com rastro e knockback.
static func bullet(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	# Uma flecha da RAJADA Z — mesma spec do pente inteiro (`Player._spec_do_disparo`).
	var fwd := dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	if fwd != Vector3.ZERO:
		zone.look_at(origin + fwd, Vector3.UP)   # -Z aponta pro alvo

	var shard := MeshInstance3D.new()             # lasca alongada (flecha)
	var pm := PrismMesh.new()
	pm.size = Vector3(0.14, 0.14, 0.7)
	shard.mesh = pm
	shard.rotation_degrees.x = -90               # ponta pra frente (-Z)
	shard.material_override = _crystal_mat()
	zone.add_child(shard)

	var core := MeshInstance3D.new()              # miolo branco-gelo na ponta
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	core.mesh = sm
	core.position.z = -0.32
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.97, 1.0)
	cm.emission_enabled = true
	cm.emission = Color(0.6, 0.92, 1.0)
	cm.emission_energy_multiplier = 6.0
	core.material_override = cm
	zone.add_child(core)

	var tp := ParticleProcessMaterial.new()       # rastro gelado
	tp.direction = Vector3(0, 0, 1)
	tp.spread = 8.0
	tp.initial_velocity_min = 1.0
	tp.initial_velocity_max = 3.0
	tp.scale_min = 0.25
	tp.scale_max = 0.7
	tp.color_ramp = FxUtil.gradient([Color(0.85, 0.97, 1.0, 1.0), Color(0.4, 0.75, 1.0, 0.5), Color(0.1, 0.3, 0.6, 0)])
	zone.add_child(FxUtil.particles(24, 0.3, false, tp, FxUtil.grain(0.2)))

	AudioFX.snap(world, origin, 1.5)              # "tiro" agudo e cristalino
	zone.setup(damage, 9.0, fwd * 55.0, 0.7, caster, 0.32)   # flecha RÁPIDA + knockback
	if spec != null:
		spec.marcar(zone)

# ---------- Z: Disparo de Gelo (Cópia da Higan, mas elemento Gelo) ----------
static func _disparo_de_gelo(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd := dir.normalized()
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin
	if fwd != Vector3.ZERO:
		zone.look_at(origin + fwd, Vector3.UP)

	# Projétil em cápsula alongada de gelo
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.12
	cap.height = 0.7
	body.mesh = cap
	body.rotation_degrees.x = 90
	body.material_override = _crystal_mat()
	zone.add_child(body)

	# Miolo ciano brilhante
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	core.mesh = sm
	core.position.z = -0.3
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.85, 0.95, 1.0)
	cm.emission_enabled = true
	cm.emission = Color(0.5, 0.9, 1.0)
	cm.emission_energy_multiplier = 5.0
	core.material_override = cm
	zone.add_child(core)

	# Rastro de partículas de gelo
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 10.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.5
	pm.scale_min = 0.3
	pm.scale_max = 0.9
	pm.color_ramp = FxUtil.gradient([Color(0.8, 0.95, 1.0, 1.0), Color(0.3, 0.7, 1.0, 0.6), Color(0.1, 0.3, 0.6, 0.0)])
	zone.add_child(FxUtil.particles(45, 0.6, false, pm, FxUtil.grain(0.15)))

	zone.setup(spec.dano, 14.0, fwd * 32.0, 1.2, caster, 0.8)
	spec.marcar(zone)

# ---------- X: Iceberg (Mão direita para cima, cria iceberg e o lança) ----------
static func _iceberg(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd := dir.normalized()

	# Levanta a mão direita do caster (se possuir modelo articulado)
	if caster and caster.has_node("_char_model"):
		var model: Node = caster.get_node("_char_model")
		var arm: Node = model.find_child("*Arm_R*", true, false)
		if arm and arm is Node3D:
			var tw_arm := caster.create_tween()
			tw_arm.tween_property(arm, "rotation_degrees:x", -130.0, 0.2)
			tw_arm.tween_property(arm, "rotation_degrees:x", 0.0, 0.4).set_delay(0.5)

	# Criação do Iceberg
	var zone := DamageZone.new()
	world.add_child(zone)
	var spawn_pos := origin + fwd * 2.0 + Vector3.UP * 1.0
	zone.global_position = spawn_pos
	if fwd != Vector3.ZERO:
		zone.look_at(spawn_pos + fwd, Vector3.UP)

	# METEORO DE GELO: pedra ARREDONDADA (esfera low-poly = cara de rocha) + lascas
	# irregulares pra quebrar a silhueta — referência a um meteoro, mas de gelo.
	var berg := Node3D.new()
	zone.add_child(berg)
	var rock := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.7
	sph.height = 3.2
	sph.radial_segments = 8
	sph.rings = 5
	rock.mesh = sph
	rock.material_override = _crystal_mat()
	berg.add_child(rock)
	for c in [[1.2, 0.4, 0.3, 0.75], [-1.0, -0.5, 0.6, 0.65], [0.2, 1.3, -0.5, 0.6], [-0.4, 0.3, -1.2, 0.7]]:
		var chunk := MeshInstance3D.new()
		var cs := SphereMesh.new()
		cs.radius = c[3]
		cs.height = c[3] * 2.0
		cs.radial_segments = 6
		cs.rings = 4
		chunk.mesh = cs
		chunk.position = Vector3(c[0], c[1], c[2])
		chunk.material_override = _crystal_mat()
		berg.add_child(chunk)

	# Efeito de crescimento inicial
	berg.scale = Vector3(0.1, 0.1, 0.1)
	var tw_grow := zone.create_tween()
	tw_grow.tween_property(berg, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	zone.add_child(FxUtil.particles(120, 1.2, false, _frost_proc(2.0, 3.0), FxUtil.grain(0.4)))
	zone.setup(spec.dano, 25.0, fwd * 22.0, 1.8, caster, 2.5)
	spec.marcar(zone)
	# Todos os golpes da Hie congelam (07/10/2026): o acerto é do servidor (`hit_landed`).
	zone.hit_landed.connect(func(alvo: Node) -> void: congelar(alvo))

# ---------- C: Investida de Gelo (Dash + Congelamento por 5s no Alvo) ----------
static func _investida_de_gelo(world: Node, origin: Vector3, dir: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var fwd := dir.normalized()

	# Aplica impulso de dash no caster
	if caster and caster is CharacterBody3D:
		(caster as CharacterBody3D).velocity = fwd * 28.0 + Vector3.UP * 4.0

	# HITBOX: a investida é uma DamageZone que avança com o dash.
	# Antes era um Area3D CRU chamando take_damage() na mão (o `if body.has_method`
	# da lambda). Machucava, mas ficava fora de todo o pipeline de combate — sem
	# knockback, sem crédito de kill no placar, sem hit-stop — e a auditoria lia o
	# golpe como "só visual", porque neste projeto hitbox É `DamageZone`.
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	# Aura gélida acompanhando a investida
	zone.add_child(FxUtil.particles(100, 0.8, false, _frost_proc(1.8, 2.0), FxUtil.grain(0.3)))

	# CONGELAR continua sendo a mecânica do golpe. Conectado ANTES do `setup` para
	# rodar antes do `_on_body` da própria DamageZone.
	zone.body_entered.connect(func(body: Node3D):
		if body == caster or not _decide(world):
			return
		congelar(body)
	)

	# KNOCKBACK ZERO de propósito: a investida PRENDE o alvo num bloco de gelo.
	# Empurrão mandaria o bloco pra longe e desmancharia o controle, que é o ponto
	# do golpe. Movimento: os mesmos 12 m em 0,45 s do tween antigo -> 26,7 m/s.
	zone.setup(spec.dano, 0.0, fwd * 26.7, 0.45, caster, 2.2)
	spec.marcar(zone)

# ---------- V: Ice Age (Congela o Chão por 50 segundos) ----------
static func _ice_age(world: Node, center_pos: Vector3, damage: float, caster: Node,
		spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	# Modo História (10/10/2026, pedido do dono): o V vira o LUGAR em gelo — relevo, casas e
	# árvores branco-azulados num raio FIXO, sem crescer (`EraDoGelo`). Na arena, o de antes.
	if world != null and world.is_inside_tree() and world.get_tree().get_first_node_in_group("modo_historia") != null:
		EraDoGelo.lancar(world, center_pos, caster, spec)
		return
	var floor_pos := Vector3(center_pos.x, 0.05, center_pos.z)

	# HITBOX: a ERUPÇÃO inicial, quando a placa rompe o chão.
	# O parâmetro `damage` chegava aqui e morria — não era usado em lugar nenhum do
	# Ice Age. Era caminho morto, não decisão de design (a doc do golpe nunca disse
	# "não fere"). Quem está em cima quando o gelo sobe leva o impacto uma vez.
	# O CAMPO de 50 s que fica depois continua sendo CONTROLE PURO: congela e
	# recongela, não tira vida. Essa parte é de propósito — ver relatório.
	var burst := DamageZone.new()
	world.add_child(burst)
	burst.global_position = floor_pos + Vector3.UP * 1.0
	# Raio 5 = o raio BASE da placa (antes de crescer). Vida 1 s: é o impacto da
	# subida, não uma zona de dano permanente.
	burst.setup(spec.parte("impacto", 256.0), 8.0, Vector3.ZERO, 1.0, caster, 5.0)
	spec.marcar(burst)

	var age_zone := Node3D.new()
	world.add_child(age_zone)
	age_zone.global_position = floor_pos
	# CRESCIMENTO GRADUAL: começa pequeno e se espalha até ~o mapa todo (só no plano
	# X/Z -> o efeito é sempre RENTE AO SOLO). O node inteiro é escalado, então a placa,
	# as estacas, as partículas E a área de congelamento crescem juntas.
	age_zone.scale = Vector3(0.35, 1.0, 0.35)
	var grow := age_zone.create_tween()
	grow.tween_property(age_zone, "scale", Vector3(11.0, 1.0, 11.0), 22.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Placa congelada base (raio 5m; escala até ~55m = mapa completo)
	var slab := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 5.0
	cyl.bottom_radius = 5.0
	cyl.height = 0.2
	slab.mesh = cyl
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.65, 0.88, 1.0, 0.65)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.roughness = 0.04
	smat.metallic = 0.3
	smat.emission_enabled = true
	smat.emission = Color(0.4, 0.75, 1.0)
	smat.emission_energy_multiplier = 2.0
	slab.material_override = smat
	age_zone.add_child(slab)

	# Estacas espalhadas no deserto congelado
	for i in 28:
		var rad := randf_range(1.2, 4.7)
		var ang := randf_range(0, TAU)
		var cr := _crystal(randf_range(2.0, 4.8), randf_range(0.6, 1.2))
		cr.position = Vector3(cos(ang) * rad, 0, sin(ang) * rad)
		age_zone.add_child(cr)
		cr.scale = Vector3(0.1, 0.1, 0.1)
		var twc := age_zone.create_tween()
		twc.tween_property(cr, "scale", Vector3.ONE, 0.3 + randf() * 0.3).set_trans(Tween.TRANS_BACK)

	# Partículas de ventania congelante (raio base; cresce com a placa)
	var particles := FxUtil.particles(300, 2.0, false, _frost_proc(4.7, 1.5), FxUtil.grain(0.5), 0.0, "hero")
	age_zone.add_child(particles)

	# Área de verificação contínua do chão (duração: 50 segundos)
	var area := Area3D.new()
	age_zone.add_child(area)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 5.0        # raio base (cresce com o node); altura baixa = só o SOLO
	shape.height = 2.2
	col.shape = shape
	area.add_child(col)

	# Verificação a cada 0.2s dos corpos pisando no chão congelado
	var timer := Timer.new()
	timer.wait_time = 0.2
	timer.autostart = true
	age_zone.add_child(timer)

	# DANO DO CAMPO (pedido do dono do projeto).
	#
	# O campo era controle puro: congelava, dava 2 s de imunidade, recongelava, e
	# não tirava vida nenhuma. Agora ele MORDE — gelo que não fere não pressiona
	# ninguém a sair de cima dele.
	#
	# O valor do tique vem da tabela (`Balance.FRUTAS.hie_hie.V`), não de um
	# `AGE_DPS` local — era mais um número de balanceamento morando longe dos
	# outros. Deliberadamente BAIXO: quem está congelado não pode se mexer, e
	# dano alto em alvo imóvel vira execução, não pressão. O que impede a
	# execução agora não é só o valor ser baixo: é o TETO da conjuração, que o
	# campo compartilha com a erupção de abertura.
	timer.timeout.connect(func():
		for body in area.get_overlapping_bodies():
			if body == caster:
				continue
			# COMBATENTE é quem tem `take_damage` (o mesmo critério de `_congelar_alvo`),
			# não "quem é CharacterBody3D": o inimigo do mapa do Modo História é corpo
			# ESTÁTICO e levava só o impacto, nunca o campo (medido em 05/10/2026).
			if not body.has_method("take_damage"):
				continue
			# ⚠️ ERA `take_damage()` DIRETO, com um `* DamageZone.DAMAGE_SCALE` colado
			# à mão para compensar estar fora do funil. O remendo funcionava e era a
			# prova de que a constante estava no lugar errado. Agora o tique passa pelo
			# `CombatResolver` como todo o resto — e, por passar, respeita o teto: quem
			# ficar no campo chega aos 768 em ~16 tiques e a partir daí o gelo é só
			# controle, congelando e recongelando sem executar.
			CombatResolver.aplicar(body, spec.dano, spec.cast_id, spec.teto, floor_pos)
			if _decide(world):
				congelar(body)
	)

	# Auto-destruição após 50 SEGUNDOS no chão
	FxUtil.autofree(age_zone, 50.0)

## Congela `alvo` (combatente) por `segundos`, com `IMUNIDADE` depois. Quem decide é o
## servidor (o acerto). Jogador remoto: o corpo é do cliente dono, então o servidor
## espalha (`Player.congelar_em_rede`) — o dono trava e todos veem o bloco de gelo.
## Bicho, inimigo e boneco não leem `is_frozen`: a física deles (IA e movimento) pára
## enquanto o gelo dura (ver `_congelar_alvo`).
##
## `imunidade` (10/10/2026, Z da Hie no Modo História): quanto de imunidade o acerto deixa
## ao descongelar — o Z só dá imunidade na 3ª salva (as duas primeiras passam 0).
## `estender`: um acerto em quem JÁ está congelado estica o gelo até o fim deste novo
## (a sequência de salvas prende sem soltar no meio) e a imunidade do fim fica a MAIOR
## pedida. Sem `estender` (arena e o resto), o acerto em congelado é ignorado, como antes.
static func congelar(alvo: Node, segundos: float = CONGELAR, espalhar := true,
		imunidade: float = IMUNIDADE, estender := false) -> void:
	if alvo == null or not is_instance_valid(alvo) or not alvo.has_method("take_damage"):
		return
	if espalhar and alvo.has_method("congelar_em_rede") and alvo.is_inside_tree() \
			and alvo.multiplayer.has_multiplayer_peer() and alvo.multiplayer.is_server():
		alvo.congelar_em_rede(segundos)
	_congelar_alvo(null, alvo as Node3D, segundos, imunidade, estender)


## Este peer decide o congelamento? (o servidor, ou o jogo sem rede)
static func _decide(no: Node) -> bool:
	return no == null or not no.is_inside_tree() or not no.multiplayer.has_multiplayer_peer() or no.multiplayer.is_server()


# ---------- Helper: Congela Alvo com Bloco de Gelo 3D e Imunidade ----------
static func _congelar_alvo(world: Node, target: Node3D, freeze_duration: float, immunity_duration: float,
		estender := false) -> void:
	if not target:
		return

	# Só congela COMBATENTE. Sem esta guarda a investida congelava o cenário: a
	# auditoria imprimia "ALVO CONGELADO ... em: Plataforma" e em "@StaticBody3D@56",
	# pendurando um bloco de gelo de 1,6×2,4 m no meio do mapa por 5 s. `take_damage`
	# é o que define combatente neste projeto (mesmo critério da DamageZone).
	if not target.has_method("take_damage"):
		return

	# Checa se o alvo está imune ao congelamento
	if target.has_meta("ice_immune") and target.get_meta("ice_immune"):
		return

	# Checa se já está congelado no momento
	if target.has_meta("is_frozen") and target.get_meta("is_frozen"):
		if estender:
			var ate := Time.get_ticks_msec() + int(freeze_duration * 1000.0)
			if ate > int(target.get_meta("congelado_ate", 0)):
				target.set_meta("congelado_ate", ate)
			target.set_meta("imunidade_ao_descongelar", maxf(float(target.get_meta("imunidade_ao_descongelar", 0.0)), immunity_duration))
			StatusFX.aplicar(target, StatusFX.CONGELADO, freeze_duration)
		return

	# Marca como congelado
	target.set_meta("is_frozen", true)
	target.set_meta("congelado_ate", Time.get_ticks_msec() + int(freeze_duration * 1000.0))
	target.set_meta("imunidade_ao_descongelar", immunity_duration)
	StatusFX.aplicar(target, StatusFX.CONGELADO, freeze_duration)
	print("❄️ ALVO CONGELADO! Bloco de Gelo gerado por ", freeze_duration, "s em: ", target.name)

	# Bloco de gelo 3D ao redor do alvo
	var ice_block := MeshInstance3D.new()
	ice_block.name = "IceBlockFreeze"
	var box := BoxMesh.new()
	box.size = Vector3(1.6, 2.4, 1.6)
	ice_block.mesh = box
	ice_block.material_override = _crystal_mat()
	target.add_child(ice_block)
	# No MEIO do corpo (07/10/2026, foto): o jogador e o boneco têm a origem no meio da
	# cápsula, e o +0,8 de antes punha o bloco em cima da cabeça. Bicho tem a origem no pé
	# e diz onde é o meio (`centro_do_corpo`).
	if target.has_method("centro_do_corpo"):
		ice_block.global_position = target.call("centro_do_corpo")
	else:
		ice_block.position = Vector3.ZERO

	# Animação de criação do bloco
	ice_block.scale = Vector3(0.2, 0.2, 0.2)
	var tw := target.create_tween()
	tw.tween_property(ice_block, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK)

	# Paralisa velocidade se for CharacterBody3D
	if target is CharacterBody3D:
		(target as CharacterBody3D).velocity = Vector3.ZERO
	# Não-jogador (bicho, inimigo, boneco de duelo) não lê `is_frozen`: pára a física
	# dele — IA, movimento e golpes — enquanto o gelo dura (07/10/2026; antes o bloco de
	# gelo aparecia e o boneco seguia lutando dentro dele).
	var parou := false
	if not target.is_in_group("player") and target.is_physics_processing():
		target.set_physics_process(false)
		parou = true

	# Timer para DESCONGELAR. Referências FRACAS (07/10/2026): o alvo pode sumir congelado
	# (inimigo que morre, boneco removido) e uma função anônima segurando o nó liberado
	# enchia o console de "Lambda capture ... was freed".
	var freeze_timer := target.get_tree().create_timer(freeze_duration)
	freeze_timer.timeout.connect(_descongelar.bind(weakref(target), weakref(ice_block), parou, immunity_duration))


static func _descongelar(alvo_ref: WeakRef, bloco_ref: WeakRef, parou: bool, imunidade: float) -> void:
	var target := alvo_ref.get_ref() as Node
	if target == null or not target.is_inside_tree():
		return
	# Esticado por um acerto novo (`estender`): o gelo fica o que falta.
	var falta := (int(target.get_meta("congelado_ate", 0)) - Time.get_ticks_msec()) / 1000.0
	if falta > 0.01:
		target.get_tree().create_timer(falta).timeout.connect(_descongelar.bind(alvo_ref, bloco_ref, parou, imunidade))
		return
	imunidade = float(target.get_meta("imunidade_ao_descongelar", imunidade))
	if parou:
		target.set_physics_process(true)
	var bloco := bloco_ref.get_ref() as Node3D
	if bloco != null:
		var tw_out := target.create_tween()
		tw_out.tween_property(bloco, "scale", Vector3.ZERO, 0.12)
		tw_out.tween_callback(bloco.queue_free)
	target.set_meta("is_frozen", false)
	if imunidade <= 0.0:
		print("🧊 DESCONGELADO (sem imunidade: pode congelar de novo).")
		return
	target.set_meta("ice_immune", true)
	print("🛡️ DESCONGELADO! Imunidade a gelo ativada por ", imunidade, "s.")
	target.get_tree().create_timer(imunidade).timeout.connect(_fim_da_imunidade.bind(weakref(target)))


static func _fim_da_imunidade(alvo_ref: WeakRef) -> void:
	var target := alvo_ref.get_ref() as Node
	if target == null:
		return
	target.set_meta("ice_immune", false)
	print("⚡ Fim da Imunidade ao Gelo.")
