extends SceneTree
# Smoke test do RIG ÚNICO: confirma que um personagem SKINNADO (Meshy) resolve
# os 13 papéis do rig A e que os ossos realmente se mexem quando o
# ProceduralAnimator roda e quando um clipe do Mixamo toca.
# Uso: godot --headless --path . -s tools/dev_tests/test_rig_unico.gd

const CHARS := ["nami", "ace", "blackbeard", "crocodile"]

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame   # a árvore precisa estar viva p/ global_position valer
	var falhas := 0
	for cid in CHARS:
		print("\n========== ", cid.to_upper(), " ==========")
		var data := CharacterBuilder.build_character(cid)
		var model: Node3D = data["node"]
		get_root().add_child(model)
		if not data.get("skinned", false):
			print("  ⚠ não é skinnado — pulando")
			continue

		var prof := BodyScanner.scan(model)
		var nodes: Dictionary = prof["nodes"]
		var driver = prof.get("driver")
		print("  papéis resolvidos: ", nodes.size(), "/13")
		if nodes.size() < 13:
			var faltam: Array = []
			for r in BodyScanner.ROLES:
				if not nodes.has(r):
					faltam.append(r)
			print("  ✗ faltam: ", faltam)
			falhas += 1
		if driver == null or not driver.is_valid():
			print("  ✗ SkeletonDriver inválido")
			falhas += 1
			model.queue_free()
			continue

		var skel: Skeleton3D = _find_skel(model)
		var b_arm := skel.find_bone("LeftArm")
		var b_leg := skel.find_bone("RightUpLeg")
		var antes: Quaternion = skel.get_bone_pose_rotation(b_arm)
		var antes_leg: Quaternion = skel.get_bone_pose_rotation(b_leg)

		# roda o animador procedural andando pra frente por ~1s
		var anim := ProceduralAnimator.new()
		model.add_child(anim)
		anim.setup(prof)
		for i in 60:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
		var depois: Quaternion = skel.get_bone_pose_rotation(b_arm)
		var d1 := antes.angle_to(depois)
		print("  locomoção -> giro do LeftArm: %.1f°" % rad_to_deg(d1))
		if d1 < 0.02:
			print("  ✗ o osso NÃO se mexeu com a locomoção")
			falhas += 1

		# agora um clipe do Mixamo
		var clip = load("res://assets/animations/hurricane_kick.res")
		if clip is Animation:
			anim.play_baked(clip)
			for i in 20:
				anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0, false)
			var pos_clip: Quaternion = skel.get_bone_pose_rotation(b_leg)
			var d2 := antes_leg.angle_to(pos_clip)   # mesmo osso, antes x depois
			print("  clipe Mixamo -> giro do RightUpLeg: %.1f°" % rad_to_deg(d2))
			if d2 < 0.02:
				print("  ✗ o clipe do Mixamo NÃO moveu o osso")
				falhas += 1
		else:
			print("  ⚠ hurricane_kick.res não carregou")

		model.queue_free()

	print("\n================================")
	if falhas == 0:
		print("✅ RIG ÚNICO OK — skinnados falam o rig A")
	else:
		print("❌ ", falhas, " falha(s)")
	quit(1 if falhas > 0 else 0)

func _find_skel(n):
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r = _find_skel(c)
		if r:
			return r
	return null
