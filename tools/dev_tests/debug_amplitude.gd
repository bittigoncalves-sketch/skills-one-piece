extends SceneTree
# Compara a AMPLITUDE do ciclo de caminhada entre um personagem voxel (rig por
# nós, referência correta) e um skinnado (via SkeletonDriver). Mede o ângulo que
# a coxa e o braço varrem ao longo do ciclo, no espaço do personagem.
# Uso: godot --headless --path . -s tools/dev_tests/debug_amplitude.gd

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	for cid in ["base", "nami"]:
		print("\n========== ", cid.to_upper(), " ==========")
		var data := CharacterBuilder.build_character(cid)
		var modelo: Node3D = data["node"]
		get_root().add_child(modelo)
		var skinnado: bool = data.get("skinned", false)
		var prof := BodyScanner.scan(modelo)
		var anim := ProceduralAnimator.new()
		modelo.add_child(anim)
		anim.setup(prof)
		var nodes: Dictionary = prof["nodes"]
		print("  skinnado=", skinnado)

		# assenta
		for i in 30:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)

		# varre o ciclo medindo a rotação LOCAL escrita no papel (o que o
		# animador manda) e a direção resultante da coxa no mundo.
		var min_rot := 999.0
		var max_rot := -999.0
		var min_dir := 999.0
		var max_dir := -999.0
		for i in 120:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
			var coxa: Node3D = nodes["Thigh_R"]
			var joelho: Node3D = nodes["Shin_R"]
			# 1) o que o animador ESCREVEU (igual nos dois tipos)
			var rx: float = coxa.rotation.x
			min_rot = minf(min_rot, rx)
			max_rot = maxf(max_rot, rx)
			# 2) o que RESULTOU no CORPO. Nos proxies a posição nunca muda (eles
			# só carregam rotação), então no skinnado é preciso ler os OSSOS.
			var d: Vector3
			if skinnado:
				var skel: Skeleton3D = _skel(modelo)
				skel.force_update_all_bone_transforms()
				var drv = prof["driver"]
				var A: Basis = drv._axis
				var q: Vector3 = A * skel.get_bone_global_pose(skel.find_bone("RightUpLeg")).origin
				var j: Vector3 = A * skel.get_bone_global_pose(skel.find_bone("RightLeg")).origin
				d = (j - q).normalized()
			else:
				d = (joelho.global_position - coxa.global_position).normalized()
			var ang := atan2(d.z, -d.y)   # inclinação frente/trás da coxa
			min_dir = minf(min_dir, ang)
			max_dir = maxf(max_dir, ang)

		print("  rotação ESCRITA no papel Thigh_R: %.1f° a %.1f°  (varre %.1f°)" % [
			rad_to_deg(min_rot), rad_to_deg(max_rot), rad_to_deg(max_rot - min_rot)])
		print("  direção RESULTANTE da coxa:       %.1f° a %.1f°  (varre %.1f°)" % [
			rad_to_deg(min_dir), rad_to_deg(max_dir), rad_to_deg(max_dir - min_dir)])

		# --- BRAÇO: onde ele APONTA? (queixa do usuário: "braços para cima") ---
		# elevação: +90° = braço apontando pra CIMA, -90° = pendurado pra baixo.
		var elev_min := 999.0
		var elev_max := -999.0
		for i in 120:
			anim.update(Vector3(0, 0, -4.2), true, false, 1.0 / 60.0, 0.0, false)
			var b := _dir_membro(modelo, prof, skinnado, "UpperArm_R", "ForeArm_R", "RightArm", "RightForeArm")
			var elev := asin(clampf(b.y, -1.0, 1.0))
			elev_min = minf(elev_min, elev)
			elev_max = maxf(elev_max, elev)
		print("  ELEVAÇÃO do braço: %.1f° a %.1f°   (-90 = pendurado, +90 = pra cima)" % [
			rad_to_deg(elev_min), rad_to_deg(elev_max)])
		modelo.queue_free()
	quit()

func _skel(n):
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r = _skel(c)
		if r:
			return r
	return null

# Direção de um membro no espaço do PERSONAGEM, nos dois tipos de rig.
func _dir_membro(modelo, prof, skinnado, papel_a, papel_b, osso_a, osso_b) -> Vector3:
	if skinnado:
		var skel: Skeleton3D = _skel(modelo)
		skel.force_update_all_bone_transforms()
		var A: Basis = prof["driver"]._axis
		var a: Vector3 = A * skel.get_bone_global_pose(skel.find_bone(osso_a)).origin
		var b: Vector3 = A * skel.get_bone_global_pose(skel.find_bone(osso_b)).origin
		return (b - a).normalized()
	var na: Node3D = prof["nodes"][papel_a]
	var nb: Node3D = prof["nodes"][papel_b]
	return (nb.global_position - na.global_position).normalized()
