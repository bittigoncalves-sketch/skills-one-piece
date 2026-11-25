extends SceneTree
## Onde está o lag com MUITOS inimigos (30/10/2026). Com janela. Mede, no acampamento dos marinheiros do East Blue:
##   A) tempo de processo e de física por quadro com os inimigos ATIVOS (perto do jogador);  B) o mesmo com os personagens DESLIGADOS
##   (process_mode = DISABLED): a diferença é o que a IA/corpos custam;  C) micro-custo de cada peça por inimigo, em microssegundos:
##   tick da IA do mod, `_physics_process` do corpo, cérebro, barras de vida.
##   godot --path . --resolution 960x540 --disable-vsync --script res://tools/dev_tests/medir_lag_inimigos.gd
const AMOSTRAS := 90
var _j: Node3D

func _init() -> void:
	call_deferred("_r")

func _mediana(v: Array) -> float:
	var c := v.duplicate()
	c.sort()
	return float(c[c.size() / 2]) if not c.is_empty() else 0.0

func _amostrar(rotulo: String) -> void:
	var proc := []
	var fis := []
	var draw := []
	var cpu_r := []
	var vp := root.get_viewport().get_viewport_rid()
	var t0 := Time.get_ticks_usec()
	for i in AMOSTRAS:
		await process_frame
		proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		fis.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		cpu_r.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
	var seg := (Time.get_ticks_usec() - t0) / 1000000.0
	print("LAG %-34s process=%6.2f ms  fisica=%6.2f ms  render_cpu=%5.2f ms  draw=%5d  fps=%5.1f  nos=%d" % [rotulo, _mediana(proc), _mediana(fis),
		_mediana(cpu_r), int(_mediana(draw)), AMOSTRAS / seg, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])

func _micro(rotulo: String, f: Callable, n: int) -> void:
	var t0 := Time.get_ticks_usec()
	for i in n:
		f.call()
	print("LAG   micro %-40s %8.1f us por chamada" % [rotulo, float(Time.get_ticks_usec() - t0) / float(n)])

func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_lag.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://medir_lag.json"))
	root.get_node("GameFlow").start_story()
	var limite := Time.get_ticks_msec() + 150000
	while _j == null and Time.get_ticks_msec() < limite:
		await process_frame
		_j = get_first_node_in_group("player")
	for i in 300: await process_frame
	_j.max_health = 100000.0
	_j.health = 100000.0
	# IMORTAL de verdade (04/11/2026): só vida alta não bastava, o jogador morria ao chegar à ilha e a medição seguia sem ele.
	# `damage_immune` faz o Player.take_damage ignorar o golpe; o dash apaga a marca ao terminar, então é reafirmada a CADA quadro.
	process_frame.connect(func():
		if is_instance_valid(_j):
			_j.set_meta("damage_immune", true)
			_j.health = _j.max_health)
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	await _amostrar("A0 no spawn (ilha inicial)")
	var grupos0 := {}
	for g in ["enemy", "animais", "npc", "pets_historia", "personagens_east_blue", "bestas_do_mar"]:
		grupos0[g] = get_nodes_in_group(g).size()
	print("LAG nos grupos do spawn: ", grupos0)
	current_scene.ir_a_ilha("ilha_east_blue")
	var todos := []
	limite = Time.get_ticks_msec() + 120000
	while todos.size() < 5 and Time.get_ticks_msec() < limite:
		await process_frame
		todos = get_nodes_in_group("personagens_east_blue")
	for i in 150: await process_frame
	todos = get_nodes_in_group("personagens_east_blue")
	var marinheiros := todos.filter(func(p): return str(p.ficha.get("id", "")) == "marine")
	print("LAG personagens do East Blue carregados: %d (marinheiros %d)" % [todos.size(), marinheiros.size()])
	if marinheiros.is_empty():
		print("LAG sem marinheiros: nada a medir")
		modo.set("progresso_forcado", "")
		quit()
		return
	_j.global_position = marinheiros[0].global_position + Vector3(0, 0.5, 12.0)
	_j.set("velocity", Vector3.ZERO)
	for i in 240: await process_frame
	var vivos := 0
	for p in todos:
		if p.process_mode != Node.PROCESS_MODE_DISABLED and p.is_physics_processing():
			vivos += 1
	print("LAG com o jogador no acampamento: %d de %d personagens processando; inimigos no grupo enemy: %d" % [vivos, todos.size(), get_nodes_in_group("enemy").size()])
	await _amostrar("A1 no acampamento, IAs ativas")
	for p in todos:
		p.process_mode = Node.PROCESS_MODE_DISABLED
	await _amostrar("B  no acampamento, personagens OFF")
	for p in todos:
		p.process_mode = Node.PROCESS_MODE_INHERIT
	for i in 120: await process_frame
	var m = marinheiros[0]
	print("LAG --- custo por inimigo (marinheiro) ---")
	_micro("IaDoMod.um_tick (20 por s)", func(): m.ia_do_mod.um_tick(), 300)
	_micro("corpo._physics_process", func(): m._physics_process(0.016), 300)
	_micro("cerebro._physics_process", func(): m.cerebro._physics_process(0.016), 300)
	var barras = current_scene.get_node("HistoriaHud").find_child("BarrasDeCriaturas", true, false)
	if barras != null:
		_micro("BarrasDeCriaturas._process (todas)", func(): barras._process(0.016), 120)

	print("LAG --- ranking: quanto o quadro melhora desligando cada grupo de scripts (acampamento) ---")
	var por_script := {}
	var pilha: Array[Node] = [current_scene]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if no.get_script() == null or not (no.is_processing() or no.is_physics_processing()):
			continue
		var caminho := str((no.get_script() as Script).resource_path)
		if not por_script.has(caminho):
			por_script[caminho] = []
		por_script[caminho].append(no)
	# Quadro fixo (rodar com --fixed-fps 60): todo quadro roda 1 passo de física, então process+física por quadro são comparáveis. Cada grupo
	# é comparado com uma linha de base medida LOGO ANTES dele; média aparada (sem os 20 % piores) para não pegar pico de coleta de lixo.
	var amostrar := func() -> float:
		var v := []
		for i in 36:
			await process_frame
			v.append((Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		v.sort()
		var soma := 0.0
		var n := int(v.size() * 0.8)
		for i in n:
			soma += float(v[i])
		return soma / float(n)
	var ranking := []
	for caminho in por_script:
		var nos: Array = por_script[caminho]
		if "HistoriaHud" in caminho or "ModoHistoria" in caminho or nos.is_empty():
			continue
		var antes: float = await amostrar.call()
		var estado := []
		for no in nos:
			estado.append([no, no.is_processing(), no.is_physics_processing()])
			no.set_process(false)
			no.set_physics_process(false)
		var durante: float = await amostrar.call()
		for e in estado:
			if is_instance_valid(e[0]):
				e[0].set_process(e[1])
				e[0].set_physics_process(e[2])
		ranking.append([caminho, nos.size(), antes - durante, antes])
	ranking.sort_custom(func(x, y): return x[2] > y[2])
	print("LAG --- ranking (process + física, ms por quadro que o grupo custa; ruído ≈ ±0,3 ms) ---")
	for r in ranking.slice(0, 16):
		print("LAG   %-46s x%-4d  custa %.2f ms/quadro  (linha de base %.1f ms)" % [str(r[0]).get_file(), r[1], r[2], r[3]])
	modo.set("progresso_forcado", "")
	quit()
