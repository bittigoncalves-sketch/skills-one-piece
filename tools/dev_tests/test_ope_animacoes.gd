extends SceneTree
## Mede poses depois do filtro real e, no bluebuddy, depois do SkeletonDriver.
## Usa o PlayerRig de produção sem arena/ENet; a integração de cast é testada
## por test_ope_ope.gd. Régua em metros locais do jogador, nunca da câmera.

const OpePoses = preload("res://src/anim/OpePoses.gd")
const OpeWeapon = preload("res://src/player/OpeWeapon.gd")
const DT := 1.0 / 120.0
var failures := 0
var skipped := 0

class RigSubject extends Node3D:
	var rig: PlayerRig
	var current_fruit_id := "ope_ope"
	var equipped_weapon := ""
	var _char_model: Node3D:
		get: return rig.modelo()
	var _proc_anim: ProceduralAnimator:
		get: return rig.procedural()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for cid in ["base", "bluebuddy"]:
		if cid == "bluebuddy" and not FileAccess.file_exists(CharacterBuilder.SKINNED_MODELS[cid]):
			print("PULADO bluebuddy: fonte assets/models/meshy_bluebuddy/bluebuddy.glb ausente")
			skipped += 1
			continue
		var p := RigSubject.new()
		get_root().add_child(p)
		p.rig = PlayerRig.new()
		p.add_child(p.rig)
		p.rig.montar_em(p)
		p.rig.montar(cid)
		if not p._proc_anim._n.has("ForeArm_R"):
			_check(false, cid + ": asset/rig não disponível; não é possível validar animação")
			p.queue_free()
			await process_frame
			continue
		var sword := OpeWeapon.new()
		sword.setup(p)
		p.add_child(sword)
		sword.set_process(false)
		for i in 120:
			_advance(p, sword)
		_check_weapon(p, sword, cid, "idle")
		for state in OpePoses.DURATIONS:
			_measure_cast(p, sword, cid, state)
		p.current_fruit_id = "gomu_gomu"
		sword._process(DT)
		_check(not sword.visible, cid + ": arma desaparece ao trocar de fruta")
		p.queue_free()
		await process_frame
	print("OPE ANIMAÇÕES: %d falhas, %d modelo(s) pulado(s)" % [failures, skipped])
	quit(0 if failures == 0 else 1)

func _advance(p: RigSubject, sword: Node3D) -> void:
	p._proc_anim.update(Vector3.ZERO, true, false, DT, 0.0)
	sword._process(DT)

func _measure_cast(p: RigSubject, sword: Node3D, cid: String, state: String) -> void:
	var duration: float = OpePoses.DURATIONS[state]
	var samples: Array[Dictionary] = []
	p.set_meta("custom_pose", state)
	for i in int(ceil(duration / DT)) + 1:
		var phase := minf(i * DT, duration)
		p.set_meta("ope_pose_t", phase)
		_advance(p, sword)
		var a := _sample(p)
		a["t"] = phase
		samples.append(a)
	var amp_r := _amplitude(samples, "hand_R")
	var amp_l := _amplitude(samples, "hand_L")
	var leg_amp := _amplitude(samples, "foot_R") + _amplitude(samples, "foot_L")
	var hand_error := 0.0
	var roll := 0.0
	var weapon_lowest := INF
	var foot_lowest := INF
	var foot_highest := -INF
	for a in samples:
		hand_error = maxf(hand_error, float(a["hand_error"]))
		roll = maxf(roll, absf(float(a["roll"])))
		weapon_lowest = minf(weapon_lowest, float(a["weapon_y"]))
		var lower_foot := minf((a["foot_R"] as Vector3).y, (a["foot_L"] as Vector3).y)
		foot_lowest = minf(foot_lowest, lower_foot)
		foot_highest = maxf(foot_highest, lower_foot)
	print("%s %s: mão R %.3fm L %.3fm, pés %.3fm, roll %.1f°, erro mão %.4fm" % [cid, state, amp_r, amp_l, leg_amp, roll, hand_error])
	print("  mínimo lâmina %.3f, apoio tornozelo %.3f..%.3f" % [weapon_lowest, foot_lowest, foot_highest])
	_check(weapon_lowest > -0.78, cid + " " + state + ": lâmina mantém folga do chão em todos os quadros")
	_check(amp_r > 0.20 and amp_l > 0.08, cid + " " + state + ": mãos percorrem arco real")
	_check(leg_amp > 0.04, cid + " " + state + ": apoio das pernas participa")
	_check(roll < 20.0, cid + " " + state + ": tronco permanece em pé")
	_check(hand_error < 0.035, cid + " " + state + ": VFX permanece no punho real")
	if state == OpePoses.GAMMA:
		var coil := _at(samples, 0.23)
		var thrust := _at(samples, 0.36)
		var reach: float = (coil["hand_R"] as Vector3).z - (thrust["hand_R"] as Vector3).z
		print("  GAMMA extensão no impacto: %.3fm" % reach)
		_check(reach > 0.15, cid + ": Gamma estoca para a frente no dano (.35s)")
	if state == OpePoses.TAKT:
		var low := _at(samples, 0.18)
		var high := _at(samples, 0.53)
		var lift: float = (high["hand_R"] as Vector3).y - (low["hand_R"] as Vector3).y
		print("  TAKT elevação: %.3fm" % lift)
		_check(lift > 0.20, cid + ": Takt levanta o braço antes dos disparos")
	_check_weapon(p, sword, cid, state)
	p.remove_meta("custom_pose")
	p.remove_meta("ope_pose_t")
	for i in 90:
		_advance(p, sword)
	_check(p._proc_anim._ope_golpe_w < 0.0001, cid + " " + state + ": retorna ao idle")

func _sample(p: RigSubject) -> Dictionary:
	var inv := p.global_transform.affine_inverse()
	var d := {"hand_error": 0.0, "roll": rad_to_deg(p._proc_anim._n["Torso"].rotation.z)}
	var sword := p.get_node("OpeKikoku") as Node3D
	d["weapon_y"] = _bounds(sword, inv).position.y
	for side in ["R", "L"]:
		var hand := OpeWeapon.hand_transform(p, side).origin
		d["hand_" + side] = inv * hand
		var actual := hand
		var anim := p._proc_anim
		if anim._driver:
			var skel: Skeleton3D = anim._driver._skel
			var bone := skel.find_bone("RightHand" if side == "R" else "LeftHand")
			actual = skel.global_transform * skel.get_bone_global_pose(bone).origin
			var foot_idx: int = anim._driver._bone["Foot_" + side]
			d["foot_" + side] = inv * skel.global_transform * skel.get_bone_global_pose(foot_idx).origin
		else:
			var forearm: Node3D = anim._n["ForeArm_" + side]
			actual = forearm.global_transform * Vector3(0.0, -0.36, 0.02)
			d["foot_" + side] = inv * anim._n["Foot_" + side].global_position
		d["hand_error"] = maxf(float(d["hand_error"]), hand.distance_to(actual))
	return d

func _check_weapon(p: RigSubject, sword: Node3D, cid: String, state: String) -> void:
	_check(is_instance_valid(sword._weapon), cid + ": Kikoku asset carregado")
	if sword._weapon == null:
		return
	var bounds := _bounds(sword._weapon, p.global_transform.affine_inverse())
	print("  %s %s Kikoku: minY %.3f maxY %.3f z %.3f..%.3f" % [cid, state, bounds.position.y, bounds.end.y, bounds.position.z, bounds.end.z])
	_check(bounds.position.y > -0.78, cid + " " + state + ": lâmina não entra no chão")
	_check(bounds.size.y < 2.20 and bounds.end.y < 1.65, cid + " " + state + ": porte da espada controlado")

func _bounds(n: Node, inv: Transform3D) -> AABB:
	var initialized := false
	var result := AABB()
	var nodes: Array[Node] = [n]
	while not nodes.is_empty():
		var item := nodes.pop_back() as Node
		nodes.append_array(item.get_children())
		if item is MeshInstance3D and (item as MeshInstance3D).mesh:
			var b: AABB = inv * (item as Node3D).global_transform * (item as MeshInstance3D).mesh.get_aabb()
			result = result.merge(b) if initialized else b
			initialized = true
	return result

func _amplitude(samples: Array[Dictionary], key: String) -> float:
	var biggest := 0.0
	for a in samples:
		for b in samples:
			biggest = maxf(biggest, (a[key] as Vector3).distance_to(b[key]))
	return biggest

func _at(samples: Array[Dictionary], time: float) -> Dictionary:
	var closest := samples[0]
	for a in samples:
		if absf(float(a["t"]) - time) < absf(float(closest["t"]) - time):
			closest = a
	return closest

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FALHA: " + message)
