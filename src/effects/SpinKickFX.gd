class_name SpinKickFX
extends RefCounted
## Rastro preto e branco do chute giratório: duas faixas em sentidos opostos,
## com um flash sem saturação no impacto para a leitura de golpe especial.

static func disparar(mundo: Node, pos: Vector3, frente: Vector3, caster: Node) -> void:
	if mundo == null:
		return
	var zona := DamageZone.new()
	zona.name = "ChuteGiratorio"
	mundo.add_child(zona)
	# O salto da aú levanta o centro do jogador, mas o calcanhar passa baixo no
	# meio da roda. A zona fica nessa faixa para ainda conectar em alvo no chão.
	zona.global_position = pos + frente * 0.95 + Vector3.UP * 0.22
	zona.setup(104.0, 26.0, frente * 26.0 + Vector3.UP * 5.0, 0.24, caster, 2.85, null, 0.24)
	# A área de dano fica no mundo, mas os rastros são filhos do lutador: o
	# giro continua abraçado ao corpo mesmo avançando durante os 0,42 s.
	var rastro := Node3D.new()
	rastro.name = "RastroChuteGiratorio"
	if is_instance_valid(caster) and caster is Node3D:
		(caster as Node3D).add_child(rastro)
		rastro.position = Vector3(0, 0.9, 0)
	else:
		mundo.add_child(rastro)
		rastro.global_position = pos + Vector3.UP * 0.9
	_visual(rastro)
	AudioFX.whoosh(mundo, zona.global_position, 1.05)
	ScreenFX.flash(Color(0.92, 0.92, 0.92), 0.18)

static func _visual(pai: Node3D) -> void:
	# Três aros altos e inclinados, preto/branco alternado. A escala grande dá
	# leitura da aú de longe, e os planos diferentes evitam a aparência de uma
	# única rosquinha mecânica ao redor do personagem.
	for i in range(3):
		var arco := MeshInstance3D.new()
		var toro := TorusMesh.new()
		toro.inner_radius = 0.62 + i * 0.19
		toro.outer_radius = 0.76 + i * 0.19
		arco.mesh = toro
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.96, 0.98, 1.0, 0.96) if i % 2 == 0 else Color(0.008, 0.008, 0.014, 0.96)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.no_depth_test = true
		mat.render_priority = 8 + i
		arco.material_override = mat
		arco.rotation = Vector3(PI * 0.5 + (i - 1) * 0.20, 0.0, (i - 1) * 0.34)
		arco.position.y = (i - 1) * 0.30
		arco.scale = Vector3(0.24, 0.24, 0.24)
		pai.add_child(arco)
		var tw := pai.create_tween()
		tw.set_parallel(true)
		tw.tween_property(arco, "rotation:z", (-TAU * 1.35 if i % 2 == 0 else TAU * 1.35), 0.36)
		tw.tween_property(arco, "scale", Vector3.ONE * (3.45 + i * 0.30), 0.36)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.36)
		tw.tween_callback(arco.queue_free).set_delay(0.39)
	FxUtil.autofree(pai, 0.54)
