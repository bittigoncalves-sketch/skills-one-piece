class_name FightingStyles
extends RefCounted
# Estilos de Luta (Karate Tritão, Pacifista, Mink, Boxe, Cyborg).
# Alternados com a tecla R em tempo real pelo jogador.

# ⚠️ O campo "cooldown" daqui NÃO É LIDO por ninguém — confirmado por grep. Quem
# manda na recarga de estilo é `Player.RECARGA_ESTILO` (60 s em qualquer slot,
# pedido do dono em 2026-08-12). Os números continuam aqui só como registro do
# ritmo pretendido de cada golpe; se um dia o estilo voltar a ter recarga por
# skill, é este campo que a `trigger_skill_cooldown` deve passar a consultar.
#
# "desabilitado": a tecla não lança nada e o `CastController` recusa no aperto.
# É uma FLAG DE DADOS, não um `if estilo == "karate_tritao"`: o próximo estilo
# que quiser 3 golpes em vez de 4 não precisa de código novo.
# ⚠️ OS VALORES DE `dano` FORAM REESCALADOS EM 2026-08-21 para a mesma escala das
# frutas. A FONTE usada em jogo é `Balance.ESTILOS` — `Player._fire_skill` lê de
# lá. Os números aqui ficaram como referência de leitura da skill, ao lado do
# nome, da cor e da recarga; `test_balance.gd` confere que as duas batem.
const STYLES := {
	"karate_tritao": {
		"nome": "Karate Tritão",
		"cor": Color(0.15, 0.65, 0.95),
		"skills": {
			# Z e C trocaram de NOME, não de lugar: o pedido do dono é "Z = tiros
			# d'água da mão" e "C = onda empurrada pra frente", e os nomes canônicos
			# estavam invertidos em relação a isso desde sempre. Murasame é o jato
			# de água disparado; Karakusa Kawaragete é a onda.
			"Z": {"nome": "Murasame (Tiros d'Água)", "cor": Color(0.3, 0.8, 1.0), "dano": 88, "cooldown": 2.0},
			"X": {"nome": "Samehada Shotei (Palma de Tubarão)", "cor": Color(0.1, 0.6, 0.9), "dano": 160, "cooldown": 4.0},
			"C": {"nome": "Karakusa Kawaragete (Onda d'Água)", "cor": Color(0.2, 0.7, 1.0), "dano": 224, "cooldown": 5.5},
			"V": {"nome": "— (sem técnica)", "cor": Color(0.05, 0.4, 0.95), "dano": 0, "cooldown": 0.0, "desabilitado": true}
		}
	},
	"pacifista": {
		"nome": "PX Pacifista",
		"cor": Color(1.0, 0.82, 0.08),
		"skills": {
			"Z": {"nome": "PX Laser Blast (Feixe de Luz)", "cor": Color(1.0, 0.88, 0.12), "dano": 92, "cooldown": 2.2},
			"X": {"nome": "PX Iron Punches (Socos de Ferro)", "cor": Color(0.85, 0.85, 0.9), "dano": 176, "cooldown": 4.5},
			"C": {"nome": "Thruster Boost (Propulsor PX)", "cor": Color(1.0, 0.5, 0.2), "dano": 200, "cooldown": 4.0},
			"V": {"nome": "PX Tri-Beam Annihilation (Aniquilacao Tripla)", "cor": Color(1.0, 0.88, 0.12), "dano": 704, "cooldown": 13.0}
		}
	},
	"mink": {
		"nome": "Mink Electro",
		"cor": Color(0.95, 0.95, 0.35),
		"skills": {
			"Z": {"nome": "Electro Claw Jab (Garra Elétrica)", "cor": Color(0.9, 0.9, 0.2), "dano": 84, "cooldown": 1.8},
			"X": {"nome": "Voltage Discharge (Descarga Voltáica)", "cor": Color(1.0, 0.95, 0.4), "dano": 152, "cooldown": 4.0},
			"C": {"nome": "Sulong Dash (Investida Elétrica)", "cor": Color(0.8, 1.0, 0.3), "dano": 208, "cooldown": 4.5},
			"V": {"nome": "Electro Cannon (Canhão Elétrico)", "cor": Color(1.0, 1.0, 0.1), "dano": 672, "cooldown": 12.5}
		}
	},
	"boxe": {
		"nome": "Boxe de Combate",
		"cor": Color(0.95, 0.55, 0.2),
		"skills": {
			"Z": {"nome": "Dempsey Roll (Ganchos Sônicos)", "cor": Color(0.9, 0.4, 0.1), "dano": 88, "cooldown": 1.6},
			"X": {"nome": "Body Blow (Soco no Corpo)", "cor": Color(0.8, 0.3, 0.1), "dano": 168, "cooldown": 3.8},
			"C": {"nome": "Weave Dash (Esquiva de Luta)", "cor": Color(1.0, 0.6, 0.3), "dano": 192, "cooldown": 3.0},
			"V": {"nome": "Megaton Uppercut (Uppercut Devastador)", "cor": Color(1.0, 0.2, 0.0), "dano": 688, "cooldown": 11.0}
		}
	},
	"cyborg": {
		"nome": "Cyborg Tech",
		"cor": Color(0.2, 0.8, 0.75),
		"skills": {
			"Z": {"nome": "Strong Right (Punho de Aço)", "cor": Color(0.3, 0.7, 0.9), "dano": 96, "cooldown": 2.0},
			"X": {"nome": "Weapons Left (Canhão Voxel)", "cor": Color(0.2, 0.8, 0.6), "dano": 176, "cooldown": 4.2},
			"C": {"nome": "Coup de Vent (Sopro de Ar)", "cor": Color(0.4, 0.9, 0.8), "dano": 216, "cooldown": 5.0},
			"V": {"nome": "Radical Beam (Super Feixe Radical)", "cor": Color(0.1, 1.0, 0.9), "dano": 720, "cooldown": 14.0}
		}
	},
	"teste_animacao": {
		"nome": "Teste de Animação",
		"cor": Color(0.4, 0.6, 1.0),
		"skills": {
			"Z": {"nome": "punching (Soco Mixamo)", "cor": Color(0.3, 0.6, 1.0), "dano": 80, "cooldown": 1.2, "anim": "punching"},
			"X": {"nome": "mmakick (Chute Mixamo)", "cor": Color(1.0, 0.6, 0.2), "dano": 128, "cooldown": 2.5, "anim": "mmakick"},
			"C": {"nome": "groundsmash (Impacto Mixamo)", "cor": Color(1.0, 0.2, 0.2), "dano": 192, "cooldown": 5.0, "anim": "groundsmash"},
			"V": {"nome": "groundsmash (Max Smash)", "cor": Color(1.0, 0.1, 0.1), "dano": 512, "cooldown": 10.0, "anim": "groundsmash"}
		}
	}
}

static func cast(world: Node, style_id: String, variant: int, origin: Vector3, dir: Vector3, damage: float,
		caster: Node, spec: DamageSpec = null, cast_token: int = 0) -> void:
	var fwd := dir.normalized()
	if spec == null:
		spec = DamageSpec.avulso(damage)
	match style_id:
		"karate_tritao": _cast_water(world, origin, fwd, variant, damage, caster, spec)
		"pacifista":     _cast_laser(world, origin, fwd, variant, damage, caster, spec, cast_token)
		"mink":          _cast_electro(world, origin, fwd, variant, damage, caster, spec)
		"boxe":          _cast_boxe(world, origin, fwd, variant, damage, caster, spec)
		"cyborg":        _cast_cyborg(world, origin, fwd, variant, damage, caster, spec)
		"teste_animacao": _cast_teste_anim(world, origin, fwd, variant, damage, caster, spec)
		_:               _cast_water(world, origin, fwd, variant, damage, caster, spec)

# ---------- Karate Tritão ----------
# ⚠️ ATÉ 2026-08-13 ESTA FUNÇÃO IGNORAVA O `variant`: os quatro slots do estilo
# caíam no MESMO esguicho de partículas. O estilo tinha quatro nomes na HUD e um
# golpe só. Agora o `variant` é o que ele sempre deveria ter sido — o índice do
# slot (0=Z, 1=X, 2=C, 3=V) — e cada tecla tem forma própria.
#
# O corpo dos efeitos mora no `WaterFX`, seguindo os vizinhos (IceFX, FireFX,
# GoroFX): este arquivo é a TABELA de estilos, não a oficina de VFX. Ele já gasta
# ~270 linhas só com 6 estilos genéricos; enfiar três golpes de água aqui dentro
# o levaria ao teto de 900 linhas (docs/LIMITE_DE_TAMANHO.md) no SEGUNDO estilo
# que ganhasse tratamento de verdade.
#
# O `_` cobre dois casos ao mesmo tempo, e por isso é o esguicho e não "nada":
#   • V do Karate Tritão — desabilitado nos DADOS (o `CastController` recusa a
#     tecla no aperto), então em jogo ele não chega aqui;
#   • estilo SEM tratamento próprio — o `cast()` acima manda o desconhecido para
#     cá, e ele tem que continuar saindo com o mesmo golpe genérico de sempre.
static func _cast_water(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	match variant:
		0: WaterFX.tiros_da_mao(world, origin, fwd, damage, caster, spec)   # Z — tiros d'água da mão
		1: WaterFX.esguicho(world, origin, fwd, damage, caster, spec)       # X — INTACTO (pedido do dono)
		2: WaterFX.onda(world, origin, fwd, damage, caster, spec)           # C — onda empurrada pra frente
		_: WaterFX.esguicho(world, origin, fwd, damage, caster, spec)       # V / estilo desconhecido

# ---------- Pacifista Laser ----------
static func _iniciar_estado_px(caster: Node, slot: String, cast_token: int) -> bool:
	var atual := int(caster.get_meta("px_token_%s" % slot, 0))
	var cancelado := int(caster.get_meta("px_cancel_token_%s" % slot, 0))
	# Protege tanto contra presentation velha quanto contra a corrida tap rapido:
	# se CANCEL(token) ja chegou, START(token) nao pode ressuscitar o ataque.
	if cast_token > 0 and (cast_token < atual or cast_token <= cancelado):
		return false
	if cast_token > 0:
		caster.set_meta("px_token_%s" % slot, cast_token)
	caster.set_meta("px_skill_ativa", slot)
	caster.set_meta("active_skill", slot)
	caster.set_meta("is_casting", true)
	match slot:
		"Z":
			caster.set_meta("px_laser_ativo", true)
			caster.set_meta("px_laser_cancelado", false)
		"X":
			caster.set_meta("px_iron_rush_ativo", true)
			caster.set_meta("px_iron_rush_cancelado", false)
		"C":
			caster.set_meta("px_lance_ativo", true)
			caster.set_meta("px_lance_cancelado", false)
		"V":
			caster.set_meta("px_tri_beam_ativo", true)
			caster.set_meta("px_tri_beam_cancelado", false)
	return true


static func _cast_laser(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null, cast_token: int = 0) -> void:
	if not caster is Node3D:
		return
	var slot: String = ["Z", "X", "C", "V"][clampi(variant, 0, 3)]
	if not _iniciar_estado_px(caster, slot, cast_token):
		return
	# Z = PX LASER BEAM: feixe SUSTENTADO (segura a tecla, até 3 s), com nó
	# próprio. `_net_play_cast` é a confirmação AUTORITATIVA e roda em todos os
	# peers; por isso a marca também sobe aqui. Antes ela só existia no jogador
	# local que apertou Z: o servidor recebia o broadcast com a marca falsa,
	# recusava criar LaserPX e o cliente via luz sem causar dano.
	if variant == 0:
		LaserPX.criar(world, caster as Node3D, origin, fwd, damage, spec, cast_token)
		return

	# X = PX IRON PUNCHES: a sequência de braços clonados voando 2 m à frente.
	if variant == 1:
		SocosDeFerro.criar(world, caster as Node3D, fwd, damage, spec, cast_token)
		return

	# C preserva o cilindro amarelo de 15 m e o mesmo voo de 35 m/s, mas agora a
	# colisao ocupa exatamente o segmento visivel e para no primeiro obstaculo.
	if variant == 2:
		PXThrusterLance.criar(world, caster as Node3D, origin, fwd, damage, spec,
			cast_token)
		return

	# V = os tres canhoes canonicos (boca + duas palmas) convergem no alvo.
	if variant == 3:
		PXTriBeam.criar(world, caster as Node3D, origin, fwd, damage, spec, cast_token)
		return

# ---------- Mink Electro ----------
static func _cast_electro(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 45.0
	pm.initial_velocity_min = 10.0
	pm.initial_velocity_max = 20.0
	pm.scale_min = 0.4
	pm.scale_max = 1.4
	pm.color_ramp = FxUtil.gradient([Color(1.0, 1.0, 0.8), Color(0.9, 0.9, 0.2), Color(0, 0, 0, 0)])

	var sparks := FxUtil.particles(300, 0.5, true, pm, FxUtil.grain(0.4))
	zone.add_child(sparks)

	zone.setup(damage, 14.0, fwd * 28.0, 1.3, caster, 1.0)
	if spec != null:
		spec.marcar(zone)

# ---------- Boxe ----------
static func _cast_boxe(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 20.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 24.0
	pm.scale_min = 0.5
	pm.scale_max = 1.5
	pm.color_ramp = FxUtil.gradient([Color(1.0, 0.6, 0.2), Color(0.8, 0.3, 0.1), Color(0, 0, 0, 0)])

	var punches := FxUtil.particles(220, 0.4, true, pm, FxUtil.grain(0.4))
	zone.add_child(punches)

	zone.setup(damage, 15.0, fwd * 30.0, 1.4, caster, 1.0)
	if spec != null:
		spec.marcar(zone)

# ---------- Cyborg ----------
static func _cast_cyborg(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 50.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 22.0
	pm.scale_min = 0.8
	pm.scale_max = 2.2
	pm.color_ramp = FxUtil.gradient([Color(0.2, 0.8, 0.75), Color(0.1, 0.5, 0.7), Color(0, 0, 0, 0)])

	var blast := FxUtil.particles(350, 0.8, true, pm, FxUtil.grain(0.6))
	zone.add_child(blast)

	zone.setup(damage, 18.0, fwd * 32.0, 1.8, caster, 1.2)
	if spec != null:
		spec.marcar(zone)

# ---------- Teste de Animação (Mixamo) ----------
static func _cast_teste_anim(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float,
		caster: Node, spec: DamageSpec = null) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	# CICLA por todas as animações Mixamo bakeadas: Z=próxima, X=anterior, C=repetir.
	if caster and is_instance_valid(caster) and caster.has_method("cycle_style_anim"):
		var d := 1
		if variant == 1: d = -1
		elif variant >= 2: d = 0
		caster.cycle_style_anim(d)

	# Sem VFX de partículas conforme solicitado - foco total na reprodução e teste das animações.
	zone.setup(damage, 15.0 if variant < 2 else 20.0, fwd * 25.0, 1.3, caster, 1.0)
	if spec != null:
		spec.marcar(zone)


# Carrega dinamicamente os arquivos FBX/GLB da pasta assets/animations/ e injeta na biblioteca do AnimationPlayer
static func _ensure_mixamo_animation(anim: AnimationPlayer, anim_name: String) -> bool:
	if anim == null:
		return false
	if anim.has_animation(anim_name):
		return true
	var paths := [
		"res://assets/animations/" + anim_name.capitalize() + ".fbx",
		"res://assets/animations/" + anim_name + ".fbx",
		"res://assets/animations/" + anim_name.capitalize() + ".glb",
		"res://assets/animations/" + anim_name + ".glb",
		"res://assets/animations/" + anim_name.capitalize() + ".res",
		"res://assets/animations/" + anim_name + ".res",
		"res://assets/animations/" + anim_name.capitalize() + ".tres",
		"res://assets/animations/" + anim_name + ".tres"
	]
	for p in paths:
		if ResourceLoader.exists(p):
			var res = load(p)
			if res is Animation:
				var lib := anim.get_animation_library("") if anim.has_animation_library("") else null
				if lib == null:
					lib = AnimationLibrary.new()
					anim.add_animation_library("", lib)
				lib.add_animation(anim_name, res)
				print("✅ [Mixamo Loader] Animação do arquivo '", p, "' importada na memória com sucesso!")
				return true
			elif res is PackedScene:
				var scene: Node = res.instantiate()
				var f_anim := _find_anim_player(scene)
				if f_anim != null and f_anim.get_animation_list().size() > 0:
					var target_anim_name := f_anim.get_animation_list()[0]
					for a_name in f_anim.get_animation_list():
						if not a_name.to_lower().contains("reset"):
							target_anim_name = a_name
							break
					var animation: Animation = f_anim.get_animation(target_anim_name)
					if animation:
						var lib := anim.get_animation_library("") if anim.has_animation_library("") else null
						if lib == null:
							lib = AnimationLibrary.new()
							anim.add_animation_library("", lib)
						lib.add_animation(anim_name, animation)
						print("✅ [Mixamo Loader] Animação '", target_anim_name, "' do arquivo '", p, "' carregada dinamicamente no player como '", anim_name, "'!")
						scene.free()
						return true
				scene.free()
	return anim.has_animation(anim_name)


static func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found:
			return found
	return null
