extends SceneTree
# Duas perguntas sobre o walk:
#  1) PROPORÇÃO — coxa e canela de cada modelo (o Barba Negra parece anão).
#  2) PISADA — ao longo do ciclo, o pé mais baixo chega ao chão? Numa caminhada
#     boa sempre há um pé plantado (altura ~0); se o mínimo nunca zera, o
#     personagem flutua.
# Uso: godot --headless --path . -s tools/dev_tests/debug_pisada.gd

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	print("%-12s %7s %7s %7s | %8s %8s %8s" % [
		"modelo", "coxa", "canela", "perna", "pe_min", "pe_max", "variacao"])
	print("-".repeat(72))
	for cid in ["blackbeard", "nami", "ace", "crocodile"]:
		var data := CharacterBuilder.build_character(cid)
		var modelo: Node3D = data["node"]
		get_root().add_child(modelo)
		var prof := BodyScanner.scan(modelo)
		var drv = prof.get("driver")
		var skel: Skeleton3D = _skel(modelo)
		if drv == null or skel == null:
			modelo.queue_free()
			continue
		var anim := ProceduralAnimator.new()
		modelo.add_child(anim)
		anim.setup(prof)
		var A: Basis = drv._axis

		# proporções em repouso
		skel.force_update_all_bone_transforms()
		var quadril: Vector3 = A * _p(skel, "RightUpLeg")
		var joelho: Vector3 = A * _p(skel, "RightLeg")
		var pe0: Vector3 = A * _p(skel, "RightFoot")
		var coxa := quadril.distance_to(joelho)
		var canela := joelho.distance_to(pe0)

		# ciclo de caminhada: altura do pé MAIS BAIXO, relativa ao quadril
		for i in 40:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
		var lo := 99.0
		var hi := -99.0
		for i in 120:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
			skel.force_update_all_bone_transforms()
			var q: Vector3 = A * _p(skel, "Hips")
			var pd: Vector3 = A * _p(skel, "RightFoot")
			var pe: Vector3 = A * _p(skel, "LeftFoot")
			# quanto o pé mais baixo está ABAIXO do quadril (maior = mais esticado)
			var mais_baixo: float = q.y - maxf(pd.y, pe.y)
			lo = minf(lo, mais_baixo)
			hi = maxf(hi, mais_baixo)
		print("%-12s %7.3f %7.3f %7.3f | %8.3f %8.3f %8.3f" % [
			cid, coxa, canela, coxa + canela, lo, hi, hi - lo])
		modelo.queue_free()

	print("\ncoxa/canela: numa perna humana são ~iguais. Muito diferente = modelo desproporcional.")
	print("pe_min/pe_max: o quanto o pé mais baixo fica ABAIXO do quadril ao longo do ciclo.")
	print("Se pe_min for MUITO menor que o comprimento da perna, o pé nunca estica -> flutua.")
	quit()

func _p(skel: Skeleton3D, nome: String) -> Vector3:
	var i := skel.find_bone(nome)
	return skel.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO

func _skel(n):
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r = _skel(c)
		if r:
			return r
	return null
