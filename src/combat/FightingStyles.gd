class_name FightingStyles
extends RefCounted
# Estilos de Luta (Karate Tritão, Pacifista, Mink, Boxe, Cyborg).
# Alternados com a tecla R em tempo real pelo jogador.

const STYLES := {
	"karate_tritao": {
		"nome": "Karate Tritão",
		"cor": Color(0.15, 0.65, 0.95),
		"skills": {
			"Z": {"nome": "Karakusa Kawaragete (Onda d'Água)", "cor": Color(0.2, 0.7, 1.0), "dano": 28, "cooldown": 2.0},
			"X": {"nome": "Samehada Shotei (Palma de Tubarão)", "cor": Color(0.1, 0.6, 0.9), "dano": 42, "cooldown": 4.0},
			"C": {"nome": "Murasame (Projéteis de Água)", "cor": Color(0.3, 0.8, 1.0), "dano": 36, "cooldown": 5.5},
			"V": {"nome": "Gokushou Shichiseiken (Explosão Oceânica)", "cor": Color(0.05, 0.4, 0.95), "dano": 85, "cooldown": 12.0}
		}
	},
	"pacifista": {
		"nome": "PX Pacifista",
		"cor": Color(1.0, 0.25, 0.25),
		"skills": {
			"Z": {"nome": "PX Laser Blast (Feixe de Luz)", "cor": Color(1.0, 0.3, 0.3), "dano": 32, "cooldown": 2.2},
			"X": {"nome": "Targeting Dual Laser (Disparo Duplo)", "cor": Color(1.0, 0.1, 0.1), "dano": 48, "cooldown": 4.5},
			"C": {"nome": "Thruster Boost (Propulsor PX)", "cor": Color(1.0, 0.5, 0.2), "dano": 25, "cooldown": 4.0},
			"V": {"nome": "PX Orbital Laser (Bombardeio Orbital)", "cor": Color(1.0, 0.05, 0.05), "dano": 92, "cooldown": 13.0}
		}
	},
	"mink": {
		"nome": "Mink Electro",
		"cor": Color(0.95, 0.95, 0.35),
		"skills": {
			"Z": {"nome": "Electro Claw Jab (Garra Elétrica)", "cor": Color(0.9, 0.9, 0.2), "dano": 26, "cooldown": 1.8},
			"X": {"nome": "Voltage Discharge (Descarga Voltáica)", "cor": Color(1.0, 0.95, 0.4), "dano": 40, "cooldown": 4.0},
			"C": {"nome": "Sulong Dash (Investida Elétrica)", "cor": Color(0.8, 1.0, 0.3), "dano": 30, "cooldown": 4.5},
			"V": {"nome": "Electro Cannon (Canhão Elétrico)", "cor": Color(1.0, 1.0, 0.1), "dano": 88, "cooldown": 12.5}
		}
	},
	"boxe": {
		"nome": "Boxe de Combate",
		"cor": Color(0.95, 0.55, 0.2),
		"skills": {
			"Z": {"nome": "Dempsey Roll (Ganchos Sônicos)", "cor": Color(0.9, 0.4, 0.1), "dano": 30, "cooldown": 1.6},
			"X": {"nome": "Body Blow (Soco no Corpo)", "cor": Color(0.8, 0.3, 0.1), "dano": 45, "cooldown": 3.8},
			"C": {"nome": "Weave Dash (Esquiva de Luta)", "cor": Color(1.0, 0.6, 0.3), "dano": 20, "cooldown": 3.0},
			"V": {"nome": "Megaton Uppercut (Uppercut Devastador)", "cor": Color(1.0, 0.2, 0.0), "dano": 90, "cooldown": 11.0}
		}
	},
	"cyborg": {
		"nome": "Cyborg Tech",
		"cor": Color(0.2, 0.8, 0.75),
		"skills": {
			"Z": {"nome": "Strong Right (Punho de Aço)", "cor": Color(0.3, 0.7, 0.9), "dano": 34, "cooldown": 2.0},
			"X": {"nome": "Weapons Left (Canhão Voxel)", "cor": Color(0.2, 0.8, 0.6), "dano": 46, "cooldown": 4.2},
			"C": {"nome": "Coup de Vent (Sopro de Ar)", "cor": Color(0.4, 0.9, 0.8), "dano": 35, "cooldown": 5.0},
			"V": {"nome": "Radical Beam (Super Feixe Radical)", "cor": Color(0.1, 1.0, 0.9), "dano": 95, "cooldown": 14.0}
		}
	},
	"teste_animacao": {
		"nome": "Teste de Animação",
		"cor": Color(0.4, 0.6, 1.0),
		"skills": {
			"Z": {"nome": "punching (Soco Mixamo)", "cor": Color(0.3, 0.6, 1.0), "dano": 25, "cooldown": 1.2, "anim": "punching"},
			"X": {"nome": "mmakick (Chute Mixamo)", "cor": Color(1.0, 0.6, 0.2), "dano": 35, "cooldown": 2.5, "anim": "mmakick"},
			"C": {"nome": "groundsmash (Impacto Mixamo)", "cor": Color(1.0, 0.2, 0.2), "dano": 50, "cooldown": 5.0, "anim": "groundsmash"},
			"V": {"nome": "groundsmash (Max Smash)", "cor": Color(1.0, 0.1, 0.1), "dano": 85, "cooldown": 10.0, "anim": "groundsmash"}
		}
	}
}

static func cast(world: Node, style_id: String, variant: int, origin: Vector3, dir: Vector3, damage: float, caster: Node) -> void:
	var fwd := dir.normalized()
	match style_id:
		"karate_tritao": _cast_water(world, origin, fwd, variant, damage, caster)
		"pacifista":     _cast_laser(world, origin, fwd, variant, damage, caster)
		"mink":          _cast_electro(world, origin, fwd, variant, damage, caster)
		"boxe":          _cast_boxe(world, origin, fwd, variant, damage, caster)
		"cyborg":        _cast_cyborg(world, origin, fwd, variant, damage, caster)
		"teste_animacao": _cast_teste_anim(world, origin, fwd, variant, damage, caster)
		_:               _cast_water(world, origin, fwd, variant, damage, caster)

# ---------- Karate Tritão ----------
static func _cast_water(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var pm := ParticleProcessMaterial.new()
	pm.direction = fwd
	pm.spread = 35.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 18.0
	pm.scale_min = 0.6
	pm.scale_max = 2.0
	pm.color_ramp = FxUtil.gradient([Color(0.2, 0.7, 1.0, 0.9), Color(0.05, 0.4, 0.9, 0.7), Color(1, 1, 1, 0)])

	var water := FxUtil.particles(260, 0.7, true, pm, FxUtil.grain(0.5))
	zone.add_child(water)

	zone.setup(damage, 14.0, fwd * 25.0, 1.2, caster, 1.2)

# ---------- Pacifista Laser ----------
static func _cast_laser(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float, caster: Node) -> void:
	var zone := DamageZone.new()
	world.add_child(zone)
	zone.global_position = origin

	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 0.3
	cyl.height = 15.0
	beam.mesh = cyl
	beam.material_override = FxUtil.particle_material(Color(1.0, 0.15, 0.15), 6.0, true)

	if abs(fwd.y) < 0.99:
		beam.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), Vector3.ZERO)
		beam.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	zone.add_child(beam)

	zone.setup(damage, 16.0, fwd * 35.0, 1.5, caster, 1.0)

# ---------- Mink Electro ----------
static func _cast_electro(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float, caster: Node) -> void:
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

# ---------- Boxe ----------
static func _cast_boxe(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float, caster: Node) -> void:
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

# ---------- Cyborg ----------
static func _cast_cyborg(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float, caster: Node) -> void:
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

# ---------- Teste de Animação (Mixamo) ----------
static func _cast_teste_anim(world: Node, origin: Vector3, fwd: Vector3, variant: int, damage: float, caster: Node) -> void:
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

