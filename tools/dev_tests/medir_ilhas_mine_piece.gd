extends SceneTree
## Custo das ilhas das estruturas do Mine Piece (18/10/2026, E6): quadro (média e p95),
## chamadas de desenho, primitivas e memória de vídeo em pontos de vista fixos, para
## comparar o mapa de ANTES (cópia em art_src/backups) com o de agora. Vsync desligado.
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/medir_ilhas_mine_piece.gd [-- --mapa=<arq>]

const PONTOS := {
	"inicial_spawn": [Vector3(152, 6, 20), Vector3(260, 4, 20)],
	"east_blue_chegada": [Vector3(2790, 8, 30), Vector3(3000, 4, 150)],
	"east_blue_alto": [Vector3(2700, 120, 300), Vector3(3000, 0, -200)],
	"shandora": [Vector3(7760, 20, 60), Vector3(8000, 20, -30)],
	# 22/10/2026: construções espalhadas + árvores — do chão, olhando a ilha toda.
	"wano_chao": [Vector3(6370, 8, 0), Vector3(6500, 4, 0)],
	"foosha_chao": [Vector3(2140, 8, 600), Vector3(2250, 4, 600)],
	"wano_alto": [Vector3(6500, 240, 216), Vector3(6500, 0, 0)],
}


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await process_frame


func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var modo = load("res://src/historia/ModoHistoria.gd")
	var mapa := "vivo"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mapa="):
			mapa = a.trim_prefix("--mapa=")
			modo.set("mapa_forcado", mapa)
		elif a == "--relevo-liso":
			load("res://src/historia/ilhas/relevo_das_ilhas.gd").set("desligado", true)
			mapa += " (relevo liso)"
	modo.set("progresso_forcado", "user://medir_ilhas_mine_piece.json")
	var t0 := Time.get_ticks_msec()
	root.get_node("GameFlow").start_story()
	await frames(5)
	await frames(240)
	print("MEDIR mapa=%s abrir≈%d ms memoria_estatica=%.0f MB" % [mapa, Time.get_ticks_msec() - t0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	var p: Node3D = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.far = 2500.0
	for nome in PONTOS:
		var de: Vector3 = PONTOS[nome][0]
		var para: Vector3 = PONTOS[nome][1]
		p.global_position = de + Vector3(0, 2, 0)
		cam.global_position = de
		cam.look_at(para)
		await frames(120)
		var tempos: Array[float] = []
		var antes := Time.get_ticks_usec()
		for i in 300:
			await process_frame
			var agora := Time.get_ticks_usec()
			tempos.append((agora - antes) / 1000.0)
			antes = agora
		tempos.sort()
		var media := 0.0
		for t in tempos:
			media += t
		media /= tempos.size()
		print("MEDIR %-18s quadro %.2f ms (p95 %.2f)  desenho %d  primitivas %d  video %.0f MB" % [nome, media,
			tempos[int(tempos.size() * 0.95)], Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
