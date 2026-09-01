class_name ContextualMeleeFX
extends RefCounted
## Apresentação leve para W/A/S/D. O nó fica preso ao atacante, portanto a
## direção congelada continua coerente enquanto ele se desloca. Não cria dano:
## a DamageZone nasce exclusivamente em contextual_melee.gd no servidor.

const ContextualMeleeData = preload("res://src/combat/contextual_melee.gd")

static func apresentar(caster: Node3D, id: String, yaw: float) -> void:
	if caster == null or not is_instance_valid(caster) or not ContextualMeleeData.e_id_valido(id):
		return
	var raiz := Node3D.new()
	raiz.name = "ContextualMeleeFX_" + id
	caster.add_child(raiz)
	raiz.position = Vector3(0.0, 0.92, 0.0)
	raiz.rotation.y = yaw
	var tipo := str(ContextualMeleeData.especificacao(id).get("vfx", ""))
	match tipo:
		"cotovelo": _cotovelo(raiz)
		"recuo": _recuo(raiz)
		"esquiva_l": _esquiva(raiz, -1.0)
		"esquiva_r": _esquiva(raiz, 1.0)
		_: _cotovelo(raiz)
	var atraso := ContextualMeleeData.startup(id)
	var timer := raiz.get_tree().create_timer(atraso)
	timer.timeout.connect(func():
		if is_instance_valid(raiz):
			_arco_de_acao(raiz, tipo))
	FxUtil.autofree(raiz, ContextualMeleeData.duracao(id) + 0.14)

static func _material(cor: Color, alfa: float = 0.72) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	mat.no_depth_test = false
	return mat

static func _cotovelo(raiz: Node3D) -> void:
	# Três linhas comprimidas atrás do ombro: antecipam o avanço, sem parecer
	# projétil ou efeito elemental de fruta.
	for i in range(3):
		var linha := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.045, 0.52 + i * 0.10)
		linha.mesh = mesh
		var mat := _material(Color(0.82, 0.93, 1.0), 0.44 - i * 0.08)
		linha.material_override = mat
		linha.position = Vector3((i - 1) * 0.12, 0.06 + i * 0.08, 0.44 + i * 0.14)
		raiz.add_child(linha)
		var tw := raiz.create_tween()
		tw.set_parallel(true)
		tw.tween_property(linha, "position:z", linha.position.z + 0.34, 0.14)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)

static func _recuo(raiz: Node3D) -> void:
	# Poeira curta na saída, orientada para frente: o corpo viaja para trás e o
	# olho entende que o pé empurrou o chão.
	for i in range(2):
		var poeira := MeshInstance3D.new()
		var disco := CylinderMesh.new()
		disco.top_radius = 0.20 + i * 0.08
		disco.bottom_radius = 0.28 + i * 0.10
		disco.height = 0.025
		poeira.mesh = disco
		var mat := _material(Color(0.72, 0.79, 0.84), 0.36 - i * 0.08)
		poeira.material_override = mat
		poeira.position = Vector3((i - 0.5) * 0.26, -0.82, -0.20)
		raiz.add_child(poeira)
		var tw := raiz.create_tween()
		tw.set_parallel(true)
		tw.tween_property(poeira, "scale", Vector3(3.1, 1.0, 2.2), 0.22)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)

static func _esquiva(raiz: Node3D, sinal: float) -> void:
	# Pós-imagens abstratas e transparentes — placas de silhueta, não clones
	# físicos. Não têm colisão e jamais recebem cor dourada.
	for i in range(3):
		var eco := MeshInstance3D.new()
		var placa := BoxMesh.new()
		placa.size = Vector3(0.26, 1.42, 0.12)
		eco.mesh = placa
		var mat := _material(Color(0.78, 0.89, 1.0), 0.26 - i * 0.07)
		eco.material_override = mat
		eco.position = Vector3(-sinal * (0.14 + i * 0.20), 0.0, 0.18 + i * 0.04)
		eco.rotation.z = sinal * 0.12
		raiz.add_child(eco)
		var tw := raiz.create_tween()
		tw.set_parallel(true)
		tw.tween_property(eco, "position:x", eco.position.x - sinal * 0.36, 0.22)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.22)

static func _arco_de_acao(raiz: Node3D, tipo: String) -> void:
	var arco := MeshInstance3D.new()
	var toro := TorusMesh.new()
	toro.inner_radius = 0.52
	toro.outer_radius = 0.61
	arco.mesh = toro
	var cor := Color(0.94, 0.98, 1.0) if tipo != "recuo" else Color(0.72, 0.88, 1.0)
	var mat := _material(cor, 0.72)
	arco.material_override = mat
	arco.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	arco.position = Vector3(0.0, 0.04, -0.72)
	arco.scale = Vector3(0.15, 0.15, 0.15)
	raiz.add_child(arco)
	var tw := raiz.create_tween()
	tw.set_parallel(true)
	tw.tween_property(arco, "scale", Vector3(1.45, 1.45, 1.45), 0.16)
	tw.tween_property(arco, "position:z", -1.24, 0.16)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.16)
	tw.tween_callback(arco.queue_free).set_delay(0.18)
