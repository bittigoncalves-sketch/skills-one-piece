class_name FallImpactController
extends RefCounted

## Queda que ultrapassa a altura do pulo normal: poeira, pedrinhas e rachaduras
## efêmeras. É puramente apresentação e não cria corpos de física.
# Um pulo comum alcança ~4 m; 5,5 m exige uma queda deliberadamente mais alta.
# Esta é também a porta do chute aéreo em Player.gd.
const ALTURA_MINIMA := 5.5
var _estava_no_chao := true
var _pico_y := 0.0

func atualizar(dono: CharacterBody3D, no_chao: bool, velocidade_y: float) -> void:
	if dono == null or not is_instance_valid(dono):
		return
	if not no_chao:
		if _estava_no_chao:
			_pico_y = dono.global_position.y
		_pico_y = maxf(_pico_y, dono.global_position.y)
	elif not _estava_no_chao:
		var altura := _pico_y - dono.global_position.y
		if altura > ALTURA_MINIMA and velocidade_y < -2.0:
			_criar_impacto(dono, clampf((altura - ALTURA_MINIMA) / 8.0, 0.0, 1.0))
	_estava_no_chao = no_chao

func _criar_impacto(dono: CharacterBody3D, intensidade: float) -> void:
	var mundo := dono.get_tree().current_scene
	if mundo == null:
		return
	var ponto := dono.global_position + Vector3(0, -0.72, 0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.2
	pm.initial_velocity_max = 5.0 + intensidade * 4.0
	pm.gravity = Vector3(0, -10, 0)
	pm.scale_min = 0.18
	pm.scale_max = 0.5
	pm.color_ramp = FxUtil.gradient([Color(0.42, 0.35, 0.27, 0.85), Color(0.30, 0.24, 0.18, 0)])
	var poeira := FxUtil.particles(26 + int(intensidade * 18.0), 0.55, true, pm, FxUtil.grain(0.28), 1.0)
	mundo.add_child(poeira)
	poeira.global_position = ponto
	FxUtil.autofree(poeira, 0.85)
	var rachaduras := Node3D.new()
	rachaduras.name = "RachadurasQueda"
	mundo.add_child(rachaduras)
	rachaduras.global_position = ponto + Vector3(0, 0.012, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.09, 0.055, 0.025, 0.78)
	# Cada veio nasce torto e ganha bifurcações; não é uma estrela de linhas retas.
	for i in range(11):
		var angulo := TAU * float(i) / 11.0 + randf_range(-0.16, 0.16)
		var ponta := Vector3.ZERO
		for segmento in range(3):
			var tamanho := 0.72 + randf() * 0.48 + intensidade * 0.42
			angulo += randf_range(-0.30, 0.30)
			var direcao := Vector3(sin(angulo), 0, cos(angulo))
			_adicionar_veio(rachaduras, mat, ponta + direcao * tamanho * 0.5, angulo, tamanho)
			ponta += direcao * tamanho
			if segmento == 1 and randf() > 0.28:
				var ramo_angulo := angulo + randf_range(-0.95, 0.95)
				var ramo_tamanho := tamanho * randf_range(0.42, 0.66)
				var ramo_dir := Vector3(sin(ramo_angulo), 0, cos(ramo_angulo))
				_adicionar_veio(rachaduras, mat, ponta + ramo_dir * ramo_tamanho * 0.5, ramo_angulo, ramo_tamanho)
	var tw := rachaduras.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.tween_callback(rachaduras.queue_free)

func _adicionar_veio(pai: Node3D, material: Material, centro: Vector3, angulo: float, tamanho: float) -> void:
	var risco := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = Vector3(0.045, 0.012, tamanho)
	risco.mesh = caixa
	risco.material_override = material
	risco.rotation.y = angulo
	risco.position = centro
	pai.add_child(risco)
