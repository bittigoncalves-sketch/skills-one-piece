extends SceneTree
# ============================================================================
#  ENGASGO DA PRÉVIA DO SKILLS BUILDER — medição (07/10/2026). Não conserta: mede.
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/medir_engasgo_da_previa.gd
#
#  Relato do dono: "no momento que a skill roda no editor existe um travamento na
#  execução onde a tela trava temporariamente e retorna de onde travou" — toda vez, em
#  qualquer skill. Abre o editor de verdade (com GPU, tempo real), roda cada skill 3×
#  pelo botão (`executar`) e mede, por execução:
#    • quanto a chamada `executar` leva (o que trava ANTES do primeiro quadro);
#    • o pior intervalo entre quadros nos 2 s seguintes e em que quadro ele cai;
#    • o mesmo pior intervalo com a prévia PARADA (a linha de base).
# ============================================================================

const Dados := preload("res://src/skills_builder/dados_skill.gd")

var ed: Node


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	root.size = Vector2i(1600, 900)
	root.get_node("GameFlow").start_skills_builder()
	await _quadros(90)
	ed = current_scene
	var base := await _pior_intervalo(120)
	print("linha de base (prévia parada, 2 s): pior quadro %.1f ms" % base.pior)
	var skills := {"nova (padrão)": Dados.novo()}
	for id in ["noro_noro_beam", "pika_raio_z", "pika_yata_x", "pika_yasakani_c"]:
		var s: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/skills/%s.json" % id))
		if s is Dictionary:
			skills[id] = s
	# `-- <s>`: pausa em silêncio antes de cada execução (o PipeWire suspende a saída
	# de som parada depois de alguns segundos; o 1º som a acorda).
	var args := OS.get_cmdline_user_args()
	var pausa := float(args[0]) if args.size() > 0 else 0.0
	print("pausa em silêncio antes de cada execução: %.0f s; driver de áudio: %s" % [pausa, AudioServer.get_driver_name()])
	for nome: String in skills:
		ed._documento(skills[nome])
		await _quadros(30)
		for vez in 3:
			var arena: Node = ed.get("arena")
			arena.call("reiniciar")
			arena.set("_recarga", 0.0)
			await _quadros(10)
			if pausa > 0.0:
				await create_timer(pausa).timeout
			var t0 := Time.get_ticks_usec()
			ed.call("executar", false)
			var chamada := (Time.get_ticks_usec() - t0) / 1000.0
			var r := await _pior_intervalo(120)
			print("%-16s execução %d: executar() %.1f ms | pior quadro %.1f ms no quadro %d | %s" % [nome, vez + 1,
				chamada, r.pior, r.onde, str(r.picos)])
			arena.call("parar")
			await _quadros(20)
	await _por_partes()
	await _decompor()
	print("FIM")
	quit(0)


## Quanto custa cada passo da prévia (1/120 s) e cada parte dele, na skill nova padrão.
func _por_partes() -> void:
	ed._documento(Dados.novo())
	await _quadros(20)
	var arena: Node = ed.get("arena")
	arena.call("reiniciar")
	arena.set("_recarga", 0.0)
	await _quadros(5)
	ed.call("executar", false)
	arena.set_process(false)                 # o teste anda a prévia, passo a passo
	var passos: Array[float] = []
	var eventos: Array[float] = []
	var pose: Array[float] = []
	var passo: float = arena.get("PASSO") if arena.get("PASSO") != null else 1.0 / 120.0
	for i in 100:
		var t0 := Time.get_ticks_usec()
		arena.call("_avancar", 1.0 / 120.0, true)
		passos.append((Time.get_ticks_usec() - t0) / 1000.0)
		t0 = Time.get_ticks_usec()
		arena.call("_atualizar_eventos", true)
		eventos.append((Time.get_ticks_usec() - t0) / 1000.0)
		t0 = Time.get_ticks_usec()
		arena.call("_passo_de_pose", 1.0 / 120.0)
		pose.append((Time.get_ticks_usec() - t0) / 1000.0)
	print("por passo (100 passos = 0,83 s da skill): _avancar média %.2f / pior %.2f ms | _atualizar_eventos média %.2f / pior %.2f | _passo_de_pose média %.2f / pior %.2f" % [
		_media(passos), passos.max(), _media(eventos), eventos.max(), _media(pose), pose.max()])
	var t1 := Time.get_ticks_usec()
	for i in 30:
		ed.call("_process", 1.0 / 60.0)
	print("editor._process (timeline + métricas): %.2f ms por quadro" % ((Time.get_ticks_usec() - t1) / 1000.0 / 30.0))
	arena.set_process(true)
	arena.call("parar")


## Os quadros lentos de uma execução, decompostos: processamento × desenho (CPU/GPU) da
## janela e da prévia (SubViewport), chamadas de desenho e objetos.
func _decompor() -> void:
	var arena: Node = ed.get("arena")
	var sub: SubViewport = ed.get("_subviewport")
	var rid_raiz := root.get_viewport_rid()
	var rid_sub := sub.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid_raiz, true)
	RenderingServer.viewport_set_measure_render_time(rid_sub, true)
	for nome in ["nova", "pika_yasakani_c"]:
		var s: Dictionary = Dados.novo() if nome == "nova" else JSON.parse_string(FileAccess.get_file_as_string("res://mapas/skills/%s.json" % nome))
		ed._documento(s)
		await _quadros(30)
		arena.call("reiniciar")
		arena.set("_recarga", 0.0)
		await _quadros(10)
		ed.call("executar", false)
		var antes := Time.get_ticks_usec()
		var linhas: Array[String] = []
		for i in 150:
			await process_frame
			var agora := Time.get_ticks_usec()
			var ms := (agora - antes) / 1000.0
			antes = agora
			if ms > 34.0:
				linhas.append("q%d %.0f ms: process %.1f | física %.1f | janela cpu %.1f gpu %.1f | prévia cpu %.1f gpu %.1f | setup %.1f | draw calls %d | objetos %d" % [i, ms,
					Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					RenderingServer.viewport_get_measured_render_time_cpu(rid_raiz),
					RenderingServer.viewport_get_measured_render_time_gpu(rid_raiz),
					RenderingServer.viewport_get_measured_render_time_cpu(rid_sub),
					RenderingServer.viewport_get_measured_render_time_gpu(rid_sub),
					RenderingServer.get_frame_setup_time_cpu(),
					Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		print("— %s: %d quadros lentos" % [nome, linhas.size()])
		for l in linhas.slice(0, 8):
			print("   ", l)
		arena.call("parar")
		await _quadros(20)


func _media(a: Array[float]) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxf(1.0, a.size())


## O pior intervalo entre quadros (ms) nos próximos `n` quadros, onde caiu e os picos > 34 ms.
func _pior_intervalo(n: int) -> Dictionary:
	var pior := 0.0
	var onde := -1
	var picos: Array[String] = []
	var antes := Time.get_ticks_usec()
	for i in n:
		await process_frame
		var agora := Time.get_ticks_usec()
		var ms := (agora - antes) / 1000.0
		antes = agora
		if ms > pior:
			pior = ms
			onde = i
		if ms > 34.0:
			picos.append("q%d=%.0f" % [i, ms])
	return {"pior": pior, "onde": onde, "picos": picos}


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
