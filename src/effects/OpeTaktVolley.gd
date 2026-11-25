extends Node3D
## Five rocks are staged here, but gameplay alone launches/stops them. World
## coordinates, speed and origin are supplied by the authoritative cast.
const GEO := preload("res://src/effects/OpeGeometry.gd")
const BURST := preload("res://src/effects/OpeSurgicalBurst.gd")
const ROCK_SHADER := preload("res://src/fx/shaders/ope_rock.gdshader")
const AUDIO := preload("res://src/effects/OpeAudio.gd")

var target := Vector3.ZERO
var _age := 0.0
var _rocks: Array[Node3D] = []
var _states: Array[Dictionary] = []
var _halos: Array[Node3D] = []
var _rock_materials: Array[ShaderMaterial] = []
var _energy: StandardMaterial3D
var _subtle: StandardMaterial3D
var _reticle: Node3D


func _ready() -> void:
	name = "OpeTaktVisual"
	add_to_group("ope_visual")
	_energy = GEO.luminous(GEO.CYAN, 1.65)
	_subtle = GEO.luminous(Color(0.13, 0.86, 1.0, 0.32), 1.25)
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 0.67
	rock_mesh.height = 1.34
	rock_mesh.radial_segments = 24
	rock_mesh.rings = 16
	for i: int in range(5):
		var rock := Node3D.new()
		rock.name = "SurgicalRock_%d" % i
		add_child(rock)
		_rocks.append(rock)
		var material := ShaderMaterial.new()
		material.shader = ROCK_SHADER
		material.set_shader_parameter("variant", float(i) * 2.47)
		_rock_materials.append(material)
		var body := GEO.instance(rock, rock_mesh, material)
		body.rotation = Vector3(float(i) * 0.57, float(i) * 1.3, float(i) * 0.27)
		var halo := Node3D.new()
		rock.add_child(halo)
		_halos.append(halo)
		halo.rotation = Vector3(0.45, float(i), 0.25)
		GEO.arc(halo, 0.81, 0.0, PI * 0.73, 0.017, _energy)
		GEO.arc(halo, 0.81, PI, PI * 1.73, 0.017, _energy)
		var trail := MeshInstance3D.new()
		trail.mesh = ImmediateMesh.new()
		trail.material_override = _subtle
		trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(trail)
		_states.append({"phase": "held", "velocity": Vector3.ZERO,
			"flight": 0.0, "life": 0.0, "trail": trail, "samples": PackedVector3Array()})
	_reticle = Node3D.new()
	add_child(_reticle)
	_reticle.position = target + Vector3.DOWN * 0.65
	GEO.crosshair(_reticle, 1.0, _subtle)
	_update_held()


func launch_rock(index: int, start: Vector3, endpoint: Vector3, speed: float = 30.0) -> void:
	if index < 0 or index >= _rocks.size() or _states[index]["phase"] != "held":
		return
	var rock := _rocks[index]
	rock.global_position = start
	var trajectory := endpoint - start
	var state := _states[index]
	state["phase"] = "flight"
	state["velocity"] = trajectory.normalized() * speed
	state["life"] = trajectory.length() / maxf(speed, 0.01) + 0.12
	state["flight"] = 0.0
	state["samples"] = PackedVector3Array([rock.position])
	_rock_materials[index].set_shader_parameter("held", 0.0)
	_halos[index].visible = false
	if index == 4:
		_reticle.visible = false


func impact_rock(index: int, at: Vector3) -> void:
	if index < 0 or index >= _rocks.size() or _states[index]["phase"] == "done":
		return
	_states[index]["phase"] = "done"
	_rocks[index].visible = false
	_states[index]["trail"].visible = false
	var burst := BURST.new()
	burst.mode = "impact"
	add_child(burst)
	burst.global_position = at
	AUDIO.play(self, at, "impact")
	_create_chips(at, index)


func _process(delta: float) -> void:
	_age += delta
	if _age >= 3.5:
		queue_free()
		return
	_update_held()
	for i: int in range(_rocks.size()):
		if _states[i]["phase"] != "flight":
			continue
		var state := _states[i]
		state["flight"] = float(state["flight"]) + delta
		# Deliberately linear: identical to the damage zone's 30 m/s trajectory.
		_rocks[i].global_position += (state["velocity"] as Vector3) * delta
		_rocks[i].rotate_x(delta * 4.0)
		_rocks[i].rotate_z(delta * 2.3)
		_draw_trail(i)
		if float(state["flight"]) >= float(state["life"]):
			# A server impact may still be in transit. Stop the mesh without inventing
			# a successful hit; impact_rock remains able to show the verified burst.
			_rocks[i].visible = false
			state["trail"].visible = false
			state["phase"] = "expired"


func _update_held() -> void:
	for i: int in range(_rocks.size()):
		if _states[i]["phase"] != "held":
			continue
		var progress := clampf((_age - float(i) * 0.035) / 0.48, 0.0, 1.0)
		var lift := 1.0 - pow(1.0 - progress, 3.0)
		var angle := TAU * float(i) / 5.0 - (1.0 - lift) * 0.55
		_rocks[i].position = Vector3(cos(angle) * 3.2,
			lerpf(-0.3, 2.6 + float(i % 2) * 0.45, lift), sin(angle) * 3.2)
		_rocks[i].scale = Vector3.ONE * maxf(0.01, smoothstep(0.0, 0.2, progress))
		_rocks[i].rotation = Vector3(_age * 0.4, float(i) + _age * 0.35, _age * 0.23)
		_halos[i].rotation.y = float(i) + _age * 1.8
	if is_instance_valid(_reticle):
		_reticle.rotation.y = _age * 0.35
		_reticle.scale = Vector3.ONE * lerpf(1.45, 1.0, smoothstep(0.0, 0.6, _age))


func _draw_trail(index: int) -> void:
	var state := _states[index]
	var points: PackedVector3Array = state["samples"]
	points.append(_rocks[index].position)
	if points.size() > 7:
		points.remove_at(0)
	state["samples"] = points
	var mesh: ImmediateMesh = state["trail"].mesh
	mesh.clear_surfaces()
	if points.size() < 2:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var velocity: Vector3 = state["velocity"]
	var side := velocity.normalized().cross(Vector3.UP).normalized()
	if side.length_squared() < 0.01:
		side = Vector3.RIGHT
	for i: int in range(points.size()):
		var width := 0.095 * float(i + 1) / float(points.size())
		mesh.surface_add_vertex(points[i] + side * width)
		mesh.surface_add_vertex(points[i] - side * width)
	mesh.surface_end()


func _create_chips(at: Vector3, index: int) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.11, 0.18, 0.22)
	material.roughness = 1.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.14, 0.13)
	for i: int in range(5):
		var chip := GEO.instance(self, mesh, material)
		chip.global_position = at
		chip.rotation = Vector3(float(i), float(index), float(i) * 1.7)
		var angle := TAU * float(i) / 5.0 + float(index)
		var endpoint := chip.position + Vector3(cos(angle), 0.6 + float(i % 3) * 0.3, sin(angle)) * 1.05
		var tween := create_tween().set_parallel(true)
		tween.tween_property(chip, "position", endpoint, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(chip, "scale", Vector3.ONE * 0.01, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(chip.queue_free)
