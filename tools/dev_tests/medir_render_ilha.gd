extends SceneTree
## Diagnóstico de RENDER da ilha inicial (12/11/2026, análise do pack "Simply Optimized Continued"): chamadas de desenho, objetos, vértices, memória de vídeo e
## tempo de CPU/GPU por quadro, com e sem os grupos de nós mais numerosos.   DISPLAY=:1 godot --path . -s tools/dev_tests/medir_render_ilha.gd
func _init() -> void:
	_rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:
		await process_frame
func info() -> Dictionary:
	var rs := RenderingServer
	return {
		"draw_calls": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"objetos": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"primitivas": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"mem_textura_mb": rs.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0,
		"mem_buffer_mb": rs.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0,
		"mem_video_mb": rs.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
	}
func custos(n: int) -> Dictionary:
	# vsync do sistema trava o quadro em ~17 ms; aqui o que importa é o CUSTO de cada parte: script (process), física, render na CPU e na GPU.
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var ac := {"process": 0.0, "fisica": 0.0, "render_cpu": 0.0, "render_gpu": 0.0}
	for i in n:
		await process_frame
		ac.process += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		ac.fisica += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		ac.render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		ac.render_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	for k in ac:
		ac[k] /= float(n)
	return ac
func tempo_de_quadro(n: int) -> Array:
	var v := []
	for i in n:
		var t0 := Time.get_ticks_usec()
		await process_frame
		v.append((Time.get_ticks_usec() - t0) / 1000.0)
	v.sort()
	return [v[v.size() / 2], v[int(v.size() * 0.95)], v[-1]]
func contar_nos(no: Node, por_classe: Dictionary, por_pai: Dictionary, prof := 0) -> void:
	por_classe[no.get_class()] = int(por_classe.get(no.get_class(), 0)) + 1
	for f in no.get_children():
		contar_nos(f, por_classe, por_pai, prof + 1)
func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_render.json")
	root.get_node("GameFlow").start_story()
	for i in 900:
		await physics_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await quadros(30)
	print("== RENDER ", info())
	var t := await tempo_de_quadro(120)
	print("== quadro (ms) p50 %.2f · p95 %.2f · máx %.2f" % [t[0], t[1], t[2]])
	var classes := {}
	contar_nos(root, classes, {})
	var lista := classes.keys()
	lista.sort_custom(func(a, b): return classes[a] > classes[b])
	print("== NÓS ", root.get_tree().get_node_count(), " · mais numerosos: ", lista.slice(0, 10).map(func(k): return "%s=%d" % [k, classes[k]]))
	# MeshInstance3D por tamanho de malha e sombra
	var mis := root.find_children("*", "MeshInstance3D", true, false)
	var com_sombra := 0
	var visiveis := 0
	var tri := 0
	var sem_lod := 0
	for m in mis:
		var mi := m as MeshInstance3D
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			com_sombra += 1
		if mi.is_visible_in_tree():
			visiveis += 1
		if mi.mesh != null:
			tri += mi.mesh.get_faces().size() / 3 if mi.mesh.get_surface_count() > 0 and mi.mesh.get_faces().size() < 3000000 else 0
		if mi.visibility_range_end <= 0.0:
			sem_lod += 1
	print("== MeshInstance3D: %d (visíveis %d, com sombra %d, sem visibility_range %d), triângulos somados %d" % [mis.size(), visiveis, com_sombra, sem_lod, tri])
	var mm := root.find_children("*", "MultiMeshInstance3D", true, false)
	print("== MultiMeshInstance3D: %d" % mm.size())
	var luzes := root.find_children("*", "Light3D", true, false)
	print("== Luzes: %d · sombras ligadas: %d" % [luzes.size(), luzes.filter(func(l): return l.shadow_enabled).size()])
	print("== Viewport: msaa3d=%s scaling3d=%s taa=%s" % [root.msaa_3d, root.scaling_3d_mode, root.use_taa])
	# agrupa os MeshInstance3D por ancestral de 2º nível (nome sem dígitos) para achar quem concentra nós e triângulos
	var grupos := {}
	for m in mis:
		var mi := m as MeshInstance3D
		var a: Node = mi
		var cadeia := []
		while a != null and a != root:
			cadeia.push_front(a)
			a = a.get_parent()
		var chave := ""
		for k in mini(cadeia.size(), 4):
			var nome: String = (cadeia[k] as Node).name
			var limpo := ""
			for c in nome:
				limpo += "#" if c >= "0" and c <= "9" else c
			chave += "/" + limpo.substr(0, 28)
		var g: Dictionary = grupos.get(chave, {"n": 0, "tri": 0})
		g["n"] += 1
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			g["tri"] += mi.mesh.get_faces().size() / 3
		grupos[chave] = g
	var ch := grupos.keys()
	ch.sort_custom(func(a, b): return grupos[a]["n"] > grupos[b]["n"])
	for k in ch.slice(0, 12):
		print("== GRUPO %-90s n=%5d tri=%9d" % [k, grupos[k]["n"], grupos[k]["tri"]])
	var mapa := root.find_child("Mapa", true, false)
	var b := await custos(90)
	print("== CUSTO BASE (ms): script %.2f · física %.2f · render CPU %.2f · render GPU %.2f" % [b.process, b.fisica, b.render_cpu, b.render_gpu])
	for prefixo in ["floresta_loja", "natureza_", "Ninho_bandidos", "Npc_", "RelevoEmBlocos"]:
		var grupo := []
		for f in mapa.get_children():
			if str(f.name).begins_with(prefixo) and f is Node3D:
				grupo.append(f)
		if grupo.is_empty():
			continue
		await quadros(20)
		b = await custos(90)                 # base medida logo antes (A/B/A): o aquecimento do início inflava o primeiro número
		for f in grupo:
			f.visible = false
		await quadros(10)
		var c := await custos(90)
		for f in grupo:
			f.visible = true
		await quadros(5)
		print("== ABLAÇÃO %-16s (%3d nós): script %.2f→%.2f · física %.2f→%.2f · render CPU %.2f→%.2f · GPU %.2f→%.2f" % [prefixo, grupo.size(), b.process, c.process, b.fisica, c.fisica, b.render_cpu, c.render_cpu, b.render_gpu, c.render_gpu])
	var sol: DirectionalLight3D = null
	for l in luzes:
		if l is DirectionalLight3D and l.shadow_enabled:
			sol = l
	if sol != null:
		sol.shadow_enabled = false
		await quadros(10)
		var c2 := await custos(90)
		sol.shadow_enabled = true
		print("== SEM SOMBRA direcional: render CPU %.2f→%.2f · GPU %.2f→%.2f" % [b.render_cpu, c2.render_cpu, b.render_gpu, c2.render_gpu])
	quit()
