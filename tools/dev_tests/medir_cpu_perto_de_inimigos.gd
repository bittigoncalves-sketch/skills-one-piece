extends SceneTree
## MEDIDOR de CPU (docs/DESEMPENHO_PASSOS_DE_FISICA.md): custo de script por quadro perto de inimigos, no MAPA REAL (10/11/2026). Variantes por argumento:
##   base | sem_clique_rapido | sem_estamina_hud | sem_ef_dados
const SAVE := "user://sonda_fps_progresso.json"
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
var _acum := {}
var _pico := {}
func medir(rotulo: String, n := 150) -> void:
	_acum.clear(); _pico.clear()
	Cronometro.ligado = true
	var proc := 0.0
	var fis := 0.0
	var pior := 0.0
	var t0 := Time.get_ticks_usec()
	for i in n:
		await physics_frame
		var p := Performance.get_monitor(Performance.TIME_PROCESS)
		var f := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		var q := Cronometro.fechar_quadro()
		if (Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0 > 60.0:
			var ks := q.keys()
			ks.sort_custom(func(a, b): return q[a][0] > q[b][0])
			var txt := []
			for k in ks.slice(0, 4): txt.append("%s=%.0fms(%d)" % [k, q[k][0] / 1000.0, q[k][1]])
			print("SONDA   PICO quadro ", i, ": proc=%.0f fis=%.0f ms | " % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0], " | ".join(txt))
		for k in q:
			var a: Array = _acum.get(k, [0, 0])
			_acum[k] = [a[0] + q[k][0], a[1] + q[k][1]]
			_pico[k] = maxi(int(_pico.get(k, 0)), int(q[k][0]))
		proc += p
		fis += f
		pior = maxf(pior, p + f)
	var dt := float(Time.get_ticks_usec() - t0) / 1.0e6 / n
	var ordem := _acum.keys()
	ordem.sort_custom(func(a, b): return _acum[a][0] > _acum[b][0])
	var topo := []
	for k in ordem.slice(0, 7):
		topo.append("%s=%.1fms/q (pico %.0f, %d ch/q)" % [k, _acum[k][0] / 1000.0 / n, _pico[k] / 1000.0, _acum[k][1] / n])
	print("SONDA   top: ", " | ".join(topo))
	print("SONDA %-28s process=%.2f ms  physics=%.2f ms  soma=%.2f ms  pior=%.1f ms  quadro_real=%.2f ms  nos=%d" % [
		rotulo, proc / n * 1000.0, fis / n * 1000.0, (proc + fis) / n * 1000.0, pior * 1000.0, dt * 1000.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
func rodar() -> void:
	await physics_frame
	var variante := "base"
	for a in OS.get_cmdline_user_args(): variante = a
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if variante == "sem_clique_rapido": Melee.clique_rapido = false
	# antes_10_11: como era (IA individual + todas as ilhas povoadas) · so_ia: IA unificada, sem restrição de ilha · novo: ambos, carga por distância
	if variante == "antes_10_11":
		IaUnificada.ligada = false
		modo.set("povoamento_por_ilha", false)
	if variante == "novo":
		modo.set("carregar_tudo_forcado", 0)
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var j: Node3D = get_first_node_in_group("player")
	if variante == "sem_estamina_hud":
		for n in current_scene.find_children("BarraDeEstamina", "", true, false): n.queue_free()
	if variante == "novo":
		# viaja para a primeira ilha com personagens do East Blue e mede a CHEGADA (ativação + IA acordando)
		const Ilhas = preload("res://src/historia/ilhas/ilhas.gd")
		var caixas: Dictionary = current_scene.get("_streaming").caixas
		for id in caixas:
			if id == current_scene.ilha_povoada(): continue
			await current_scene.garantir_ilha(id)
			var r: Rect2 = caixas[id]
			j.global_position = Vector3(r.get_center().x, 6.0, r.get_center().y)
			await quadros(150)
			if get_nodes_in_group("personagens_east_blue").size() >= 5:
				print("SONDA chegou em ", id, " com ", get_nodes_in_group("personagens_east_blue").size(), " personagens east_blue ativos")
				break
	var inimigos := get_nodes_in_group("enemy")
	print("SONDA variante=", variante, " inimigos(grupo enemy)=", inimigos.size(), " chefes=", get_nodes_in_group("chefes").size(), " vivos no mapa")
	await medir("longe dos inimigos")
	print("SONDA  (FPS = 1000 / quadro_real)")
	if inimigos.is_empty():
		print("SONDA sem inimigos no mapa"); quit(); return
	var candidatos: Array = []
	for n in inimigos:
		var sc = n.get_script()
		var tipo := "outro"
		if n.is_in_group("personagens_east_blue"): tipo = "east_blue"
		elif sc != null and str(sc.resource_path).ends_with("boneco_de_duelo.gd"): tipo = "boneco"
		elif str(n.name).begins_with("Animal"): tipo = "animal"
		candidatos.append([tipo, n])
	var contagem := {}
	for c in candidatos: contagem[c[0]] = int(contagem.get(c[0], 0)) + 1
	print("SONDA tipos de inimigo no mapa: ", contagem)
	for tipo in ["boneco", "east_blue"]:
		var alvo: Node3D = null
		for c in candidatos:
			if c[0] == tipo and (alvo == null or (c[1] as Node3D).global_position.distance_to(j.global_position) < alvo.global_position.distance_to(j.global_position)):
				alvo = c[1]
		if alvo == null: continue
		j.global_position = alvo.global_position + Vector3(2.5, 1.5, 0)
		j._vida.vida_max = 1.0e6
		j._vida.vida = 1.0e6
		await quadros(120)
		await medir("luta %s (%s)" % [alvo.name, tipo], 150)
		await medir("luta %s (de novo)" % tipo, 150)
	quit()
