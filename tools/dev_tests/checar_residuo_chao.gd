extends SceneTree
# O que sobra depois da correção é DEFEITO ou é SOMBRA DE VERDADE?
# A métrica conta qualquer pixel de chão abaixo de 92% da média — e sombra de
# bloco cai nisso legitimamente. Se o resíduo sumir ao desligar a sombra do sol,
# ele é sombra, não artefato.
const LINHA_Y := 430
var _p: Node3D
var _cam: Camera3D
func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000: await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar: placar.time_left = 1.0e9
	_esconder_2d(get_root())
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority(): _p = n; break
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true); e.global_position = Vector3(0, 1, -900)
	_cam = _p._camera.camera()
	var sol: DirectionalLight3D = null
	for n in _todos(get_root()):
		if n is DirectionalLight3D and (n as DirectionalLight3D).shadow_enabled: sol = n; break
	print("=== casos que sobraram: com e sem a sombra do sol ===")
	print("caso                          | com sombra | sem sombra | conclusão")
	for caso in [[Vector3(0,2,0), 270, -0.25], [Vector3(0,2,0), 45, -0.70],
			[Vector3(40,2,-25), 135, -0.25], [Vector3(40,2,-25), 0, -0.25],
			[Vector3(0,2,0), 90, -0.25]]:
		sol.shadow_enabled = true
		var a := await _medir(caso[0], deg_to_rad(float(caso[1])), caso[2])
		sol.shadow_enabled = false
		var b := await _medir(caso[0], deg_to_rad(float(caso[1])), caso[2])
		sol.shadow_enabled = true
		var conc := "SOMBRA (legítima)" if (a - b) > 5.0 else ("limpo" if a < 5.0 else "❌ artefato resta")
		print("rumo %3d° pitch %.2f %-14s | %8.1f%% | %8.1f%% | %s" % [
			caso[1], caso[2], str(caso[0]), a, b, conc])
	quit()
func _medir(pos: Vector3, yaw: float, pitch: float) -> float:
	_p.global_position = pos; _p.velocity = Vector3.ZERO
	_p._yaw = yaw; _p._pitch = pitch; _p._camera.apontar(yaw, pitch)
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 400: await process_frame
	var img := get_root().get_texture().get_image()
	var espaco := (get_root().world_3d as World3D).direct_space_state
	var pior := 0.0
	for m in [[60, 620], [660, 1220]]:
		var lum: Array[float] = []
		var chao: Array[bool] = []
		for x in range(m[0], m[1], 2):
			var c := img.get_pixel(x, LINHA_Y)
			lum.append(0.2126*c.r + 0.7152*c.g + 0.0722*c.b)
			var de := _cam.project_ray_origin(Vector2(x, LINHA_Y))
			var dir := _cam.project_ray_normal(Vector2(x, LINHA_Y))
			var h := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(de, de + dir*500.0))
			chao.append(not h.is_empty() and (h["collider"] as Node).name == "Plataforma")
		var soma := 0.0; var n := 0
		for i in lum.size():
			if chao[i]: soma += lum[i]; n += 1
		if n < 20: continue
		var media := soma/float(n); var esc := 0
		for i in lum.size():
			if chao[i] and lum[i] < media*0.92: esc += 1
		pior = maxf(pior, 100.0*esc/float(n))
	return pior
func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children(): out.append_array(_todos(f))
	return out
func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem: f.visible = false
		else: _esconder_2d(f)
