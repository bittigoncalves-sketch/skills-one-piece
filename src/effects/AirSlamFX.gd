class_name AirSlamFX
extends RefCounted
## Chute aéreo: pressão comprimida abre em anéis baixos e poeira, enquanto a
## DamageZone dá o impacto uma vez no pouso. Não usa elementos de fruta.

static func impactar(mundo: Node, pos: Vector3, caster: Node) -> void:
	if mundo == null:
		return
	var zona := DamageZone.new()
	zona.name = "ExplosaoArQueda"
	mundo.add_child(zona)
	zona.global_position = pos + Vector3.UP * 0.18
	zona.setup(140.0, 38.0, Vector3.UP * 38.0, 0.30, caster, 5.6, null, 0.34)
	_visual(zona, 5.6)
	AudioFX.impact(mundo, pos, 1.15)

static func _visual(pai: Node3D, raio: float) -> void:
	var cor := Color(0.72, 0.91, 1.0, 0.78)
	for i in range(2):
		var anel := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.72 + i * 0.25
		toro.outer_radius = 0.92 + i * 0.25
		anel.mesh = toro
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = FxUtil.brilho(cor.lightened(i * 0.12), 2.2)
		anel.material_override = mat
		anel.scale = Vector3(0.18, 0.12, 0.18)
		pai.add_child(anel)
		var tw := pai.create_tween()
		tw.set_parallel(true)
		tw.tween_property(anel, "scale", Vector3(raio, 0.16, raio), 0.34 + i * 0.06)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.36 + i * 0.06)
		tw.tween_callback(anel.queue_free).set_delay(0.42 + i * 0.06)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, -13, 0)
	pm.scale_min = 0.16
	pm.scale_max = 0.46
	pm.color_ramp = FxUtil.gradient([Color(0.82, 0.92, 1.0, 0.82), Color(0.55, 0.66, 0.74, 0)])
	var poeira := FxUtil.particles(54, 0.62, true, pm, FxUtil.grain(0.22), 1.0)
	pai.add_child(poeira)
	FxUtil.autofree(pai, 0.85)
