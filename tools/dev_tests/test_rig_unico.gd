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

		# Agora um clipe do Mixamo.
		#
		# Antes isto media REPOUSO -> POSE DO CLIPE, o que é fraco: um clipe
		# TOTALMENTE CONGELADO passa, porque a pose congelada é diferente do
		# repouso. Agora mede MOVIMENTO AO LONGO DO TEMPO, e o clipe passou a
		# ser o `kicking` (o `hurricane_kick` que estava aqui está com os
		# membros congelados — ver docs/erros.md, 2026-08-10).
		#
		# ⚠️ MESMO ASSIM, este teste NÃO detecta clipe congelado, e não é o
		# lugar de detectar. `get_bone_pose_rotation` devolve a pose composta:
		# o `SkeletonDriver.push()` acumula o delta descendo a hierarquia, então
		# a perna se mexe quando o TORSO gira acima dela. Medido: com o
		# `hurricane_kick` (membros com 0° de amplitude própria, mas 380° no
		# Torso) este trecho ainda acusa 157° de giro na perna.
		#
		# Quem detecta congelamento é `tools/dev_tests/medir_amplitude_res.gd`,
		# que lê as faixas do .res por papel, sem a interferência do pai.
		#
		# O que ESTE teste garante é o que ele se propõe: que um clipe
		# retargetado chega aos ossos do modelo skinnado — ou seja, que os
		# skinnados falam o rig A.
		var clip = load("res://assets/animations/kicking.res")
		if clip is Animation:
			anim.play_baked(clip)
			var amostras: Array[Quaternion] = []
			for passo in 6:
				for i in 12:
					anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0, false)
				amostras.append(skel.get_bone_pose_rotation(b_leg))
			var d2 := 0.0
			for i in range(1, amostras.size()):
				d2 = maxf(d2, amostras[0].angle_to(amostras[i]))
			print("  clipe Mixamo (kicking) -> giro do RightUpLeg ao longo do clipe: %.1f°" % rad_to_deg(d2))
			if d2 < 0.05:
				print("  ✗ o clipe do Mixamo NÃO moveu o osso AO LONGO DO TEMPO (clipe congelado?)")
				falhas += 1
		else:
			print("  ⚠ kicking.res não carregou")

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
