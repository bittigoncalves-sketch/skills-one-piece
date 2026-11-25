extends Node3D
## Spatial surgery has a precise silhouette: brackets, interrupted arcs and
## filaments. No fullscreen flash, dynamic lights or free-running hit effects.
const GEO := preload("res://src/effects/OpeGeometry.gd")

var mode := "shambles"
var destination := Vector3.ZERO
var direction := Vector3.FORWARD
var reach := 3.2
var _age := 0.0
var _duration := 0.75
var _primary: StandardMaterial3D
var _secondary: StandardMaterial3D
var _white: StandardMaterial3D
var _frames: Array[Node3D] = []
var _rings: Array[Node3D] = []
var _motes: Array[MeshInstance3D] = []
var _motifs: Node3D
var _blade: Node3D
var _link: MeshInstance3D


func _ready() -> void:
	name = "OpeVisual_" + mode
	add_to_group("ope_visual")
	var color := GEO.GREEN if mode.begins_with("gamma") else GEO.CYAN
	_primary = GEO.luminous(color, 1.8)
	_secondary = GEO.luminous(Color(color.r, color.g, color.b, 0.45), 1.25)
	_white = GEO.luminous(Color(0.74, 1.0, 0.89), 2.0)
	match mode:
		"shambles": _build_shambles()
		"gamma": _build_charge()
		"gamma_strike": _build_strike()
		_: _build_impact()
	_update_visual()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
		return
	_update_visual()


func _build_shambles() -> void:
	_duration = 0.72
	for endpoint: Vector3 in [Vector3.ZERO, destination]:
		var frame := Node3D.new()
		add_child(frame)
		frame.position = endpoint
		_frames.append(frame)
		# Three split slice planes and four corner brackets frame the actual body.
		for slice: int in range(3):
			var ring_root := Node3D.new()
			frame.add_child(ring_root)
			ring_root.position.y = -0.65 + float(slice) * 0.68
			ring_root.rotation.y = float(slice) * 0.4
			GEO.arc(ring_root, 0.93, 0.0, PI * 0.72, 0.018, _primary)
			GEO.arc(ring_root, 0.93, PI, PI * 1.72, 0.018, _primary)
			_rings.append(ring_root)
		for corner: int in range(4):
			var angle := PI * 0.25 + PI * 0.5 * float(corner)
			var radial := Vector3(cos(angle), 0.0, sin(angle))
			var points := PackedVector3Array([radial * 0.9 + Vector3.DOWN * 0.85,
				radial * 1.12 + Vector3.DOWN * 0.85, radial * 1.12 + Vector3.DOWN * 0.52])
			GEO.line(frame, points, 0.02, _white)
			for height: float in [-0.3, 0.2, 0.6]:
				GEO.line(frame, PackedVector3Array([radial * 1.13 + Vector3.UP * height,
					radial * 1.13 + Vector3.UP * (height + 0.09)]), 0.009, _secondary)
	# The link only exists at the resolved swap, so it never promises a blocked move.
	var points := PackedVector3Array()
	for i: int in range(25):
		var t := float(i) / 24.0
		points.append(destination * t + Vector3.UP * sin(t * PI) * 0.5)
	_link = GEO.line(self, points, 0.018, _secondary)
	for i: int in range(10):
		_motes.append(GEO.mote(self, 0.028, _white))


func _oriented_root() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var forward := direction.normalized()
	if forward.length_squared() < 0.001:
		forward = Vector3.FORWARD
	var up := Vector3.RIGHT if absf(forward.dot(Vector3.UP)) > 0.98 else Vector3.UP
	root.basis = Basis.looking_at(forward, up)
	return root


func _build_charge() -> void:
	_duration = 0.41
	_blade = _oriented_root()
	# Held pre-strike energy remains short: damage does not exist during startup.
	GEO.needle(_blade, 0.95, 0.11, _primary)
	GEO.needle(_blade, 0.88, 0.028, _white)
	for i: int in range(3):
		var ring_root := Node3D.new()
		_blade.add_child(ring_root)
		ring_root.position.z = -0.12 - float(i) * 0.24
		ring_root.rotation.x = PI * 0.5
		GEO.arc(ring_root, 0.25 - float(i) * 0.04, 0.0, PI * 1.45, 0.014, _secondary)
		_rings.append(ring_root)
	for i: int in range(8):
		_motes.append(GEO.mote(_blade, 0.021, _white))


func _build_strike() -> void:
	_duration = 0.55
	_blade = _oriented_root()
	GEO.needle(_blade, reach, 0.14, _primary)
	GEO.needle(_blade, reach * 0.985, 0.035, _white)
	for side: int in [-1, 1]:
		var points := PackedVector3Array()
		for i: int in range(24):
			var t := float(i) / 23.0
			var angle := t * TAU * 1.6 + float(side) * PI * 0.5
			var r := sin(t * PI) * 0.13
			points.append(Vector3(cos(angle) * r, sin(angle) * r, -reach * t))
		GEO.line(_blade, points, 0.009, _secondary)
	# Directional ripples collapse onto the needle; they never cover the target.
	for i: int in range(3):
		var ripple := Node3D.new()
		_blade.add_child(ripple)
		ripple.position.z = -float(i) * reach / 3.0
		ripple.rotation.x = PI * 0.5
		GEO.arc(ripple, 0.36, 0.0, PI * 1.5, 0.018, _secondary)
		_rings.append(ripple)


func _build_impact() -> void:
	_duration = 0.65
	_motifs = Node3D.new()
	add_child(_motifs)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		# Global placement is assigned by the API after _ready; basis is enough.
		_motifs.global_basis = camera.global_basis
	var ring_root := Node3D.new()
	_motifs.add_child(ring_root)
	ring_root.rotation.x = PI * 0.5
	GEO.arc(ring_root, 0.58, 0.1, PI * 0.75, 0.02, _primary)
	GEO.arc(ring_root, 0.58, PI + 0.1, PI * 1.75, 0.02, _primary)
	_rings.append(ring_root)
	if mode == "gamma_impact":
		var ecg := PackedVector3Array([Vector3(-1.25, 0, 0), Vector3(-0.55, 0, 0),
			Vector3(-0.35, 0.12, 0), Vector3(-0.17, -0.26, 0), Vector3(0.02, 0.67, 0),
			Vector3(0.22, -0.37, 0), Vector3(0.38, 0, 0), Vector3(1.25, 0, 0)])
		GEO.line(_motifs, ecg, 0.021, _white)
		GEO.line(_motifs, ecg, 0.047, _secondary)
	for i: int in range(12):
		var mote := GEO.mote(_motifs, 0.024 if i % 3 == 0 else 0.016, _primary)
		_motes.append(mote)


func _update_visual() -> void:
	var t := clampf(_age / _duration, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.35, 1.0, t)
	GEO.fade(_primary, fade * 0.9)
	GEO.fade(_secondary, fade * 0.36)
	GEO.fade(_white, fade)
	match mode:
		"shambles":
			for i: int in range(_frames.size()):
				var local_t := clampf(t + float(i) * 0.05, 0.0, 1.0)
				var open := 1.0 - pow(1.0 - clampf(local_t * 5.0, 0.0, 1.0), 3.0)
				_frames[i].scale = Vector3(lerpf(0.55, 1.14, open), lerpf(0.72, 1.0, open), lerpf(0.55, 1.14, open))
			for i: int in range(_rings.size()):
				_rings[i].rotation.y = float(i) * 0.4 + t * (1.2 if i % 2 == 0 else -1.2)
			for i: int in range(_motes.size()):
				var travel := clampf(t * 2.1 - float(i) * 0.048, 0.0, 1.0)
				_motes[i].position = destination * travel + Vector3.UP * sin(travel * PI) * 0.5
		"gamma":
			_blade.scale = Vector3.ONE * lerpf(0.35, 1.0, smoothstep(0.0, 0.85, t))
			for i: int in range(_rings.size()):
				_rings[i].rotation.y = t * TAU * 0.8 + float(i)
			for i: int in range(_motes.size()):
				var angle := TAU * float(i) / 8.0 + t * 4.0
				var r := (1.0 - t) * 0.55
				_motes[i].position = Vector3(cos(angle) * r, sin(angle) * r, -0.5 * t)
		"gamma_strike":
			_blade.scale.z = maxf(0.01, minf(t * 9.0, 1.0))
			for i: int in range(_rings.size()):
				_rings[i].scale = Vector3.ONE * lerpf(1.25, 0.3, t)
				_rings[i].rotation.y = float(i) + t * 2.0
		_:
			_motifs.scale = Vector3.ONE * lerpf(0.45, 1.35, 1.0 - pow(1.0 - t, 3.0))
			for i: int in range(_motes.size()):
				var angle := TAU * float(i) / float(_motes.size())
				var r := 0.3 + (1.0 - pow(1.0 - t, 2.0)) * (0.6 + float(i % 3) * 0.15)
				_motes[i].position = Vector3(cos(angle) * r, sin(angle) * r, 0.0)
