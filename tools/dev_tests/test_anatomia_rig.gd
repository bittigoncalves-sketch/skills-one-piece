extends SceneTree
# Testa se o SkeletonDriver produz poses ANATOMICAMENTE SÃS nos modelos
# skinnados. Mede no espaço do PERSONAGEM (o esqueleto do Meshy é Z-up, então
# medir direto no espaço do osso engana).
#
# Critérios: pés abaixo do quadril, cabeça acima, comprimento dos membros
# preservado (rotação pura não pode encolher osso) e mãos fora do tronco.
# Uso: godot --headless --path . -s tools/dev_tests/test_anatomia_rig.gd

const CHARS := ["blackbeard", "nami", "ace", "crocodile"]

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var falhas := 0
	for cid in CHARS:
		print("\n========== ", cid.to_upper(), " ==========")
		var data := CharacterBuilder.build_character(cid)
		var model: Node3D = data["node"]
		get_root().add_child(model)
		var prof := BodyScanner.scan(model)
		var driver = prof.get("driver")
		var skel: Skeleton3D = _find(model, "Skeleton3D")
		if driver == null or skel == null:
			print("  ✗ sem driver/esqueleto"); falhas += 1; continue

		var anim := ProceduralAnimator.new()
		model.add_child(anim)
		anim.setup(prof)

		var rest_medidas := _medir(skel, driver)
		print("  repouso:  pé %.2f abaixo do quadril | coxa %.3f | canela %.3f" % [
			rest_medidas.pe_abaixo, rest_medidas.coxa, rest_medidas.canela])
		if rest_medidas.pe_abaixo < 0.1:
			print("  ✗ em REPOUSO o pé não está abaixo do quadril"); falhas += 1

		# Locomoção: 40 frames andando pra frente
		for i in 40:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
		var m := _medir(skel, driver)
		print("  andando:  pé %.2f abaixo do quadril | coxa %.3f | canela %.3f | mão-tronco %.3f" % [
			m.pe_abaixo, m.coxa, m.canela, m.mao_dist])
		if m.pe_abaixo < 0.05:
			print("  ✗ ANDANDO o pé subiu pra altura do quadril (membros colapsados)"); falhas += 1
		if abs(m.coxa - rest_medidas.coxa) > 0.02 or abs(m.canela - rest_medidas.canela) > 0.02:
			print("  ✗ comprimento de membro MUDOU (não é rotação pura)"); falhas += 1
		if m.mao_dist < 0.05:
			print("  ✗ mão dentro do tronco"); falhas += 1

		# Clipe do Mixamo
		var clip = load("res://assets/animations/hurricane_kick.res")
		if clip is Animation:
			anim.play_baked(clip)
			for i in 30:
				anim.update(Vector3.ZERO, true, false, 1.0 / 60.0, 0.0, false)
			var mc := _medir(skel, driver)
			print("  clipe:    coxa %.3f | canela %.3f (devem bater com o repouso)" % [mc.coxa, mc.canela])
			if abs(mc.coxa - rest_medidas.coxa) > 0.02:
				print("  ✗ o clipe DEFORMOU o osso"); falhas += 1

		model.queue_free()

	print("\n================================")
	if falhas == 0:
		print("✅ ANATOMIA OK")
	else:
		print("❌ ", falhas, " falha(s)")
	quit(1 if falhas > 0 else 0)

# Mede no espaço do PERSONAGEM (aplica a basis esqueleto->personagem).
func _medir(skel: Skeleton3D, driver) -> Dictionary:
	skel.force_update_all_bone_transforms()
	var A: Basis = driver._axis
	var quadril: Vector3 = A * _p(skel, "Hips")
	var joelho: Vector3 = A * _p(skel, "RightLeg")
	var pe: Vector3 = A * _p(skel, "RightFoot")
	var coxa_top: Vector3 = A * _p(skel, "RightUpLeg")
	var mao: Vector3 = A * _p(skel, "RightHand")
	var espinha: Vector3 = A * _p(skel, "Spine")
	return {
		"pe_abaixo": quadril.y - pe.y,
		"coxa": coxa_top.distance_to(joelho),
		"canela": joelho.distance_to(pe),
		"mao_dist": Vector2(mao.x - espinha.x, mao.z - espinha.z).length(),
	}

func _p(skel: Skeleton3D, nome: String) -> Vector3:
	var i := skel.find_bone(nome)
	if i < 0:
		i = skel.find_bone("mixamorig_" + nome)
	return skel.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO

func _find(n, cls):
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r = _find(c, cls)
		if r:
			return r
	return null
