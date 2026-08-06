class_name SkeletalAnimator
extends Node
# Animador para personagens SKINNADOS (Skeleton3D + malha skinada, ex.: Meshy AI).
# Toca clipes esqueletais por ESTADO (idle/walk/run/jump) e clipes de golpe.
# Diferente do ProceduralAnimator (que gira nós soltos), aqui o AnimationPlayer
# do próprio modelo dirige os ossos.

var _ap: AnimationPlayer
var _cur := ""
var _locked := false   # golpe/one-shot tocando: locomoção não interrompe

# walk_path = FBX de andar NATIVO deste modelo (bind-pose própria). Vazio = sem walk.
func setup(ap: AnimationPlayer, walk_path: String = "") -> void:
	_ap = ap
	if _ap == null:
		return
	_ap.active = true
	if not _ap.has_animation_library(""):
		_ap.add_animation_library("", AnimationLibrary.new())
	if walk_path != "":
		_merge_from_fbx(walk_path, "walk")
	_ensure_standard_animations()
	# clipes extra retargetados (idle/run/golpes) entram como <nome>.res via add_clip()

func _ensure_standard_animations() -> void:
	if _ap == null:
		return
	var lib := _ap.get_animation_library("")
	if lib == null:
		return
	var root := _ap.get_node_or_null(_ap.root_node) as Node
	if root == null:
		root = _ap.get_parent()
	var skel: Skeleton3D = _find_skel(root)
	if skel == null:
		return
	var skel_path: String = String(root.get_path_to(skel))

	# 0. IDLE (garante retorno à pose nativa de descanso quando parado)
	if not lib.has_animation("idle"):
		var base_anim := ""
		for a in lib.get_animation_list():
			var a_min := String(a).to_lower()
			if "baselayer" in a_min or "clip0" in a_min or "idle" in a_min:
				base_anim = a
				break
		if base_anim != "":
			var idle_anim := lib.get_animation(base_anim).duplicate() as Animation
			idle_anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation("idle", idle_anim)
		else:
			_create_bone_oscillation(lib, "idle", skel, skel_path, 2.0, true, 0.05, 0.05)

	# 1. WALK (se não foi carregado via FBX, cria um walk procedural suave nos ossos)
	if not lib.has_animation("walk"):
		_create_bone_oscillation(lib, "walk", skel, skel_path, 1.0, true, 0.5, 0.4)

	# 2. RUN (baseia no walk nativo para preservar a orientação real dos ossos e evitar inversão de frente/trás)
	if not lib.has_animation("run"):
		if lib.has_animation("walk"):
			var run_anim := lib.get_animation("walk").duplicate() as Animation
			run_anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation("run", run_anim)
		else:
			_create_bone_oscillation(lib, "run", skel, skel_path, 0.45, true, 0.95, 0.75)

	# 3. JUMP (pose de salto contínua e expressiva no ar)
	if not lib.has_animation("jump"):
		_create_jump_anim(lib, "jump", skel, skel_path)

	# 4. CLIMB (escalada com movimento alternado de braços e pernas)
	if not lib.has_animation("climb"):
		_create_bone_oscillation(lib, "climb", skel, skel_path, 0.6, true, 0.7, 0.9)

	# 5. DAMAGE (reação ao impacto: inclinação da espinha)
	if not lib.has_animation("damage"):
		_create_pose_anim(lib, "damage", skel, skel_path, 0.4, false, [
			{"bone": "Spine01", "euler": Vector3(0.35, 0, 0)},
			{"bone": "Spine02", "euler": Vector3(0.25, 0, 0)}
		])

	# 6. DEATH (queda para trás / desmorono dos ossos principais)
	if not lib.has_animation("death"):
		_create_death_anim(lib, "death", skel, skel_path, 1.2)

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skel(c)
		if s:
			return s
	return null

func _get_bone_rest_quat(skel: Skeleton3D, b_name: String) -> Quaternion:
	var idx := skel.find_bone(b_name)
	if idx == -1:
		return Quaternion.IDENTITY
	return skel.get_bone_rest(idx).basis.get_rotation_quaternion()

# Converte uma rotação desejada no espaço do personagem (ex: inclinação frontal/traseira é em torno
# do eixo X do personagem, Vector3(1, 0, 0)) para o espaço do osso pai, evitando distorções de eixo no rig.
func _get_parent_space_rot(skel: Skeleton3D, b_name: String, char_axis: Vector3, angle_rad: float) -> Quaternion:
	var idx := skel.find_bone(b_name)
	if idx == -1:
		return Quaternion.IDENTITY
	var rest_q := skel.get_bone_rest(idx).basis.get_rotation_quaternion()
	var parent_idx := skel.get_bone_parent(idx)
	var axis_parent := char_axis.normalized()
	if parent_idx != -1:
		var parent_global_basis := skel.get_bone_global_pose(parent_idx).basis
		axis_parent = (parent_global_basis.inverse() * char_axis).normalized()
	return Quaternion(axis_parent, angle_rad) * rest_q

func _create_bone_oscillation(lib: AnimationLibrary, nm: String, skel: Skeleton3D, skel_path: String, dur: float, loop: bool, leg_ang: float, arm_ang: float) -> void:
	var anim := Animation.new()
	anim.length = dur
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	var bones_rot = {
		"LeftUpLeg": [-leg_ang, leg_ang, -leg_ang],
		"RightUpLeg": [leg_ang, -leg_ang, leg_ang],
		"LeftArm": [arm_ang, -arm_ang, arm_ang],
		"RightArm": [-arm_ang, arm_ang, -arm_ang]
	}
	for b_name in bones_rot:
		if skel.find_bone(b_name) == -1:
			continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(skel_path + ":" + b_name))
		var angles: Array = bones_rot[b_name]
		anim.rotation_track_insert_key(track, 0.0, _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), angles[0]))
		anim.rotation_track_insert_key(track, dur * 0.5, _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), angles[1]))
		anim.rotation_track_insert_key(track, dur, _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), angles[2]))
	lib.add_animation(nm, anim)

func _create_pose_anim(lib: AnimationLibrary, nm: String, skel: Skeleton3D, skel_path: String, dur: float, loop: bool, poses: Array) -> void:
	var anim := Animation.new()
	anim.length = dur
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR
	for p in poses:
		var b_name: String = p["bone"]
		var ang: float = p["euler"].x
		if skel.find_bone(b_name) == -1:
			continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(skel_path + ":" + b_name))
		var rest_q := _get_bone_rest_quat(skel, b_name)
		anim.rotation_track_insert_key(track, 0.0, rest_q)
		anim.rotation_track_insert_key(track, dur * 0.4, _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), ang))
		anim.rotation_track_insert_key(track, dur, rest_q)
	lib.add_animation(nm, anim)

func _create_jump_anim(lib: AnimationLibrary, nm: String, skel: Skeleton3D, skel_path: String) -> void:
	var anim := Animation.new()
	anim.length = 1.0
	anim.loop_mode = Animation.LOOP_LINEAR # Em ciclo para manter a pose aérea durante todo o salto e queda!
	
	var poses_start = [
		{"bone": "LeftUpLeg", "ang": -0.5},
		{"bone": "RightUpLeg", "ang": -0.5},
		{"bone": "LeftLeg", "ang": 0.6},
		{"bone": "RightLeg", "ang": 0.6},
		{"bone": "LeftArm", "ang": -0.4},
		{"bone": "RightArm", "ang": -0.4},
		{"bone": "LeftForeArm", "ang": -0.4},
		{"bone": "RightForeArm", "ang": -0.4},
		{"bone": "Spine01", "ang": -0.15}
	]
	var poses_mid = [
		{"bone": "LeftUpLeg", "ang": -0.6},
		{"bone": "RightUpLeg", "ang": -0.6},
		{"bone": "LeftLeg", "ang": 0.7},
		{"bone": "RightLeg", "ang": 0.7},
		{"bone": "LeftArm", "ang": -0.45},
		{"bone": "RightArm", "ang": -0.45},
		{"bone": "LeftForeArm", "ang": -0.45},
		{"bone": "RightForeArm", "ang": -0.45},
		{"bone": "Spine01", "ang": -0.2}
	]
	
	for i in range(poses_start.size()):
		var b_name: String = poses_start[i]["bone"]
		if skel.find_bone(b_name) == -1:
			continue
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(skel_path + ":" + b_name))
		var q1 := _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), poses_start[i]["ang"])
		var q2 := _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), poses_mid[i]["ang"])
		anim.rotation_track_insert_key(track, 0.0, q1)
		anim.rotation_track_insert_key(track, 0.5, q2)
		anim.rotation_track_insert_key(track, 1.0, q1)
	lib.add_animation(nm, anim)

func _create_death_anim(lib: AnimationLibrary, nm: String, skel: Skeleton3D, skel_path: String, dur: float) -> void:
	var anim := Animation.new()
	anim.length = dur
	anim.loop_mode = Animation.LOOP_NONE
	var b_name := "Spine"
	if skel.find_bone(b_name) != -1:
		var track := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(track, NodePath(skel_path + ":" + b_name))
		var rest_q := _get_bone_rest_quat(skel, b_name)
		anim.rotation_track_insert_key(track, 0.0, rest_q)
		anim.rotation_track_insert_key(track, dur * 0.5, _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), -1.2))
		anim.rotation_track_insert_key(track, dur, _get_parent_space_rot(skel, b_name, Vector3(1, 0, 0), -1.57))
	lib.add_animation(nm, anim)

# Funde a animação mais longa de um FBX (mesmo esqueleto) na biblioteca, com nome dado.
func _merge_from_fbx(path: String, as_name: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene = load(path).instantiate()
	var wap := _find_ap(scene)
	if wap:
		var best := ""
		var bl := 0.0
		for a in wap.get_animation_list():
			if a.to_lower().contains("reset"):
				continue
			if wap.get_animation(a).length >= bl:
				bl = wap.get_animation(a).length
				best = a
		if best != "":
			var lib := _ap.get_animation_library("")
			var anim: Animation = wap.get_animation(best).duplicate()
			anim.loop_mode = Animation.LOOP_LINEAR
			lib.add_animation(as_name, anim)
	scene.queue_free()

# Adiciona um clipe já pronto (Animation) à biblioteca.
func add_clip(nm: String, anim: Animation) -> void:
	if _ap == null or anim == null:
		return
	var lib := _ap.get_animation_library("")
	lib.add_animation(nm, anim)

func has_clip(nm: String) -> bool:
	return _ap != null and _ap.has_animation(nm)

# Locomoção por estado (chamado todo frame pelo Player).
func update(velocity: Vector3, on_floor: bool, is_climbing: bool, delta: float, is_sprinting: bool = false) -> void:
	if _ap == null or _locked:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	var want := "idle"
	if is_climbing and has_clip("climb"):
		want = "climb"
	elif not on_floor and has_clip("jump"):
		want = "jump"
	elif (is_sprinting and spd > 0.3) or spd > 5.0:
		if has_clip("run"):
			want = "run"
		elif has_clip("walk"):
			want = "walk"
	elif spd > 0.2:
		want = "walk"
	# IDLE sem clipe próprio: PARA a animação -> volta pra BIND-POSE do modelo (correta
	# p/ cada personagem). NÃO forçar o walk de outro rig aqui (distorce).
	if want == "idle" and not has_clip("idle"):
		if _cur != "idle":
			_ap.stop()
			_cur = "idle"
		return
	# ANDAR sem walk próprio (ex.: crocodile) -> fica no bind (não distorce).
	if want == "walk" and not has_clip("walk"):
		if _cur != "idle":
			_ap.stop()
			_cur = "idle"
		return
	if want == "run":
		_ap.speed_scale = 1.8 if is_sprinting else 1.45
	else:
		_ap.speed_scale = 1.0
	if want != _cur and has_clip(want):
		_ap.play(want)
		_cur = want

# Toca um golpe/one-shot; trava a locomoção pela duração.
func play_one_shot(nm: String) -> void:
	if _ap == null or not has_clip(nm):
		return
	_locked = true
	_ap.speed_scale = 1.0
	_ap.play(nm)
	_cur = nm
	var dur := _ap.get_animation(nm).length
	get_tree().create_timer(dur).timeout.connect(func(): _locked = false; _cur = "")

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null
