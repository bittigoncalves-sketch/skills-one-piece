class_name BomuFX
extends RefCounted

## Bomu Bomu no Mi — dois golpes explosivos, ambos carregáveis em 0,5 s.
## Paleta inspirada no fruto: núcleo âmbar/amarelo, fumaça grafite e brasas
## coral. O dano vem exclusivamente de Balance/DamageSpec.

const AMBAR := Color(1.0, 0.52, 0.08)
const AMARELO := Color(1.0, 0.84, 0.20)
const FUMACA := Color(0.16, 0.12, 0.18)

static func cast(world: Node, origin: Vector3, dir: Vector3, variant: int, damage: float,
		caster: Node, charge: float = 0.0, spec: DamageSpec = null) -> void:
	if spec == null:
		spec = DamageSpec.avulso(damage)
	var frente := Vector3(dir.x, 0.0, dir.z)
	if frente.length_squared() < 0.001:
		frente = Vector3.FORWARD
	frente = frente.normalized()
	match variant:
		0: _impacto_detonador(world, origin + frente * 1.55, frente, caster, charge, spec)
		1: _detonacao_corporal(world, origin + frente * 5.0, frente, caster, charge, spec)

static func salto_explosivo(world: Node, pos: Vector3, dir: Vector3 = Vector3.ZERO) -> void:
	if not is_instance_valid(world): return
	var fx := Node3D.new()
	world.add_child(fx)
	fx.global_position = pos + Vector3(0.0, -0.75, 0.0)
	_explosao_visual(fx, 1.15, 0.28)
	AudioFX.whoosh(world, fx.global_position, 1.05)
	FxUtil.autofree(fx, 0.45)

static func _impacto_detonador(world: Node, pos: Vector3, frente: Vector3, caster: Node,
		charge: float, spec: DamageSpec) -> void:
	_pose(caster, "bomu_z_strike", 0.36)
	_explodir(world, pos + Vector3.UP * 1.0, frente, caster, spec.valor_do_hit(charge), 3.6, 17.0, spec)

static func _detonacao_corporal(world: Node, pos: Vector3, frente: Vector3, caster: Node,
		charge: float, spec: DamageSpec) -> void:
	_pose(caster, "bomu_x_burst", 0.46)
	_explodir(world, pos + Vector3.UP * 1.0, frente, caster, spec.valor_do_hit(charge), 5.0, 25.0, spec)

static func _explodir(world: Node, pos: Vector3, frente: Vector3, caster: Node, dano: float,
		raio: float, kb: float, spec: DamageSpec) -> void:
	var mundo := _mundo_ativo(world, caster)
	if not is_instance_valid(mundo): return
	var zone := DamageZone.new()
	mundo.add_child(zone)
	zone.global_position = pos
	_explosao_visual(zone, raio, 0.42)
	zone.setup(dano, kb, frente * kb, 0.38, caster, raio, null, 0.42)
	zone.override_kb_dir = frente
	spec.marcar(zone)
	AudioFX.impact(mundo, pos, 0.72)

# Player cria o contêiner de efeitos com call_deferred. O primeiro cast de um
# teste pode acontecer antes do próximo quadro; inserir uma Area nesse nó ainda
# fora da árvore impede a agenda de vida e vaza VFX. Nessa janela curta, use a
# cena já ativa; os casts seguintes voltam ao contêiner do jogador.
static func _mundo_ativo(preferido: Node, caster: Node) -> Node:
	if is_instance_valid(preferido) and preferido.is_inside_tree():
		return preferido
	if is_instance_valid(caster) and caster.get_tree() != null:
		return caster.get_tree().current_scene
	return preferido

static func _explosao_visual(parent: Node3D, raio: float, vida: float) -> void:
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 1.0; esfera.height = 2.0
	bola.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = FxUtil.brilho(Color(AMARELO.r, AMARELO.g, AMARELO.b, 0.82), 2.0)
	bola.material_override = mat
	bola.scale = Vector3.ONE * 0.12
	parent.add_child(bola)
	# Fogo em camadas: núcleo brilhante e lobos laranja que crescem em ritmos
	# distintos. Lê como explosão volumétrica, não como uma única esfera.
	for i in range(5):
		var lobo := MeshInstance3D.new()
		lobo.mesh = esfera
		var lm := mat.duplicate() as StandardMaterial3D
		lm.albedo_color = FxUtil.brilho(AMARELO.lerp(AMBAR, float(i) / 5.0), 1.5)
		lobo.material_override = lm
		lobo.position = Vector3(randf_range(-0.35, 0.35), randf_range(-0.15, 0.45), randf_range(-0.35, 0.35))
		lobo.scale = Vector3.ONE * 0.10
		parent.add_child(lobo)
		parent.create_tween().tween_property(lobo, "scale", Vector3.ONE * raio * randf_range(0.48, 0.82), vida * 0.78)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new(); torus.inner_radius = 0.72; torus.outer_radius = 0.95
	ring.mesh = torus
	ring.material_override = mat.duplicate()
	ring.scale = Vector3.ONE * 0.35
	parent.add_child(ring)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP; pm.spread = 72.0
	pm.initial_velocity_min = 5.0; pm.initial_velocity_max = 12.0
	pm.gravity = Vector3(0, -13, 0); pm.scale_min = 0.16; pm.scale_max = 0.42
	pm.color_ramp = FxUtil.gradient([AMARELO, AMBAR, FUMACA, Color(FUMACA.r, FUMACA.g, FUMACA.b, 0.0)])
	parent.add_child(FxUtil.particles(64, vida, true, pm, FxUtil.grain(0.35), 0.7, "padrao"))
	var tw := parent.create_tween().set_parallel(true)
	tw.tween_property(bola, "scale", Vector3.ONE * raio, vida).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(raio, 0.45, raio), vida)
	tw.tween_property(mat, "albedo_color:a", 0.0, vida)

static func criar_carga_na_mao(caster: Node3D) -> Node3D:
	var carga := Node3D.new()
	carga.name = "BomuChargeHand"
	var modelo: Node = caster.get("_char_model")
	var mao := modelo.find_child("*ForeArm_R*", true, false) as Node3D if is_instance_valid(modelo) else null
	if is_instance_valid(mao):
		mao.add_child(carga)
		carga.position = Vector3(-0.2, 0.0, 0.0)
	else:
		caster.add_child(carga)
		carga.position = Vector3(0.45, 1.25, 0.0)
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new(); sphere.radius = 0.22; sphere.height = 0.44
	core.mesh = sphere
	var mat := StandardMaterial3D.new(); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = FxUtil.brilho(AMARELO, 2.4)
	core.material_override = mat
	carga.add_child(core)
	var tw := carga.create_tween().set_loops()
	tw.tween_property(core, "scale", Vector3.ONE * 1.65, 0.12)
	tw.tween_property(core, "scale", Vector3.ONE * 0.85, 0.12)
	return carga

static func _pose(caster: Node, pose: String, duracao: float) -> void:
	if not is_instance_valid(caster) or caster.get_tree() == null: return
	caster.set_meta("custom_pose", pose)
	caster.get_tree().create_timer(duracao).timeout.connect(func() -> void:
		if is_instance_valid(caster) and caster.get_meta("custom_pose", "") == pose:
			caster.remove_meta("custom_pose"))

class ChargeNode extends Node3D:
	var _dono: Node3D
	var _slot: String
	var _spec: DamageSpec
	var _tempo := 0.0
	var _nucleo: MeshInstance3D

	func _init(dono: Node3D, slot: String, spec: DamageSpec) -> void:
		_dono = dono; _slot = slot; _spec = spec

	func _ready() -> void:
		_nucleo = MeshInstance3D.new()
		var esfera := SphereMesh.new(); esfera.radius = 0.24; esfera.height = 0.48
		_nucleo.mesh = esfera
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = FxUtil.brilho(AMARELO, 1.8)
		_nucleo.material_override = mat
		add_child(_nucleo)

	func _process(delta: float) -> void:
		if not is_instance_valid(_dono): queue_free(); return
		var limite := _spec.tempo_de_carga if _spec != null else 0.5
		_tempo = minf(_tempo + delta, limite)
		global_position = _dono.global_position + Vector3.UP * 1.35
		var p := clampf(_tempo / maxf(limite, 0.01), 0.0, 1.0)
		_nucleo.scale = Vector3.ONE * lerpf(0.7, 2.1, p)
		rotation.y += delta * (5.0 + p * 8.0)

	func soltar(aim: Vector3) -> void:
		if is_instance_valid(_dono):
			var mira: Dictionary = _dono.mira_do_cast()
			if _slot == "Z" and _dono.has_method("start_bomu_rush"):
				_dono.start_bomu_rush(aim, _tempo)
			else:
				_dono.pedir_cast_no_servidor(_slot, aim, mira["origem"], _tempo)
		queue_free()

	func _exit_tree() -> void:
		if is_instance_valid(_dono):
			# Ao soltar Z, a mesma pose continua durante a investida até o agarrão.
			if _slot == "Z" and bool(_dono.get("_bomu_rush_active")):
				return
			var pose := "bomu_%s_charge" % _slot.to_lower()
			if _dono.get_meta("custom_pose", "") == pose: _dono.remove_meta("custom_pose")
