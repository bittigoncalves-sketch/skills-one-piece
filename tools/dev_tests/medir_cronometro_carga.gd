extends SceneTree
## Cronômetro por script sob carga (04/11/2026). Pedido do dono: o FPS cai com muitas ações juntas e com muitos inimigos.
## Cenário: acampamento dos marinheiros do East Blue (≈81 personagens, ≈65 inimigos), jogador parado perto deles.
## Mede POR QUADRO cada rótulo do `Cronometro` (média, p95, máximo, chamadas por quadro) e faz o teste da hipótese do
## `while _acumulado >= TICK` da IaDoMod: uma pausa de 100 ms e quantos ticks da IA rodam no quadro seguinte.
##   godot --path . --resolution 960x540 --disable-vsync --fixed-fps 60 --script res://tools/dev_tests/medir_cronometro_carga.gd -- [rotulo]
## Grava em user://desempenho/<rotulo>.txt. Rótulos aninhados se sobrepõem (o do corpo contém move_and_slide): não somar.
var AMOSTRAS := 360
var _j: Node3D
var _linhas: Array[String] = []

func _init() -> void:
	call_deferred("_r")

func _p(v: Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	var c := v.duplicate()
	c.sort()
	return float(c[clampi(int(c.size() * q), 0, c.size() - 1)])

func _dizer(s: String) -> void:
	print(s)
	_linhas.append(s)

## Amostra AMOSTRAS quadros: tempo de cada rótulo por quadro, tempo do quadro e a física do motor.
func _amostrar(titulo: String) -> Dictionary:
	var por_rotulo := {}
	var quadro := []
	var fis := []
	var passos := []
	var f_ant := Engine.get_physics_frames()
	var t_ant := Time.get_ticks_usec()
	Cronometro.fechar_quadro()
	for i in AMOSTRAS:
		await process_frame
		var agora := Time.get_ticks_usec()
		quadro.append((agora - t_ant) / 1000.0)
		t_ant = agora
		fis.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		passos.append(Engine.get_physics_frames() - f_ant)
		f_ant = Engine.get_physics_frames()
		var q := Cronometro.fechar_quadro()
		for k in q:
			if not por_rotulo.has(k):
				por_rotulo[k] = {"ms": [], "n": []}
			por_rotulo[k].ms.append(q[k][0] / 1000.0)
			if not por_rotulo[k].has("q"):
				por_rotulo[k]["q"] = []
			por_rotulo[k]["q"].append(i)
			por_rotulo[k].n.append(q[k][1])
	_dizer("\n== %s ==" % titulo)
	_dizer("quadro_ms     p50=%6.2f  p95=%6.2f  max=%7.2f      fisica_motor_ms p50=%6.2f p95=%6.2f max=%6.2f" % [
		_p(quadro, 0.5), _p(quadro, 0.95), _p(quadro, 1.0), _p(fis, 0.5), _p(fis, 0.95), _p(fis, 1.0)])
	_dizer("passos de física por quadro: p50=%d p95=%d max=%d" % [_p(passos, 0.5), _p(passos, 0.95), _p(passos, 1.0)])
	_dizer("%-26s %8s %8s %8s   %8s %8s" % ["rotulo", "ms_med", "ms_p95", "ms_max", "n/quad", "n_max"])
	var chaves := por_rotulo.keys()
	chaves.sort_custom(func(a, b): return _media(por_rotulo[a].ms) > _media(por_rotulo[b].ms))
	for k in chaves:
		var d: Dictionary = por_rotulo[k]
		_dizer("%-26s %8.2f %8.2f %8.2f   %8.1f %8d" % [k, _media(d.ms), _p(d.ms, 0.95), _p(d.ms, 1.0), _media(d.n), int(_p(d.n, 1.0))])
	# Em que quadros o tick de eventos passou de 5 ms: se o espaçamento for regular, o custo é PERIÓDICO (04/11/2026).
	if por_rotulo.has(&"IaDoMod.evento_tick"):
		var d: Dictionary = por_rotulo[&"IaDoMod.evento_tick"]
		var picos := []
		for j in d.ms.size():
			if float(d.ms[j]) > 5.0:
				picos.append(int(d.q[j]))
		_dizer("quadros em que IaDoMod.evento_tick > 5 ms: %s" % str(picos))
	return por_rotulo

func _media(v: Array) -> float:
	var s := 0.0
	for x in v:
		s += float(x)
	return s / maxf(1.0, float(v.size()))

func _r() -> void:
	var rotulo := "cronometro"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		rotulo = args[0]
	IaDoMod.espalhar_fases = not ("sem_espalhar" in args)   # A/B no mesmo build
	IaDoMod.faixa_de_ativacao = not ("sem_faixa" in args)
	NpcDaIlha.economia_fora_da_tela = not ("sem_fora_da_tela" in args)
	Mc.aquecimento_ligado = not ("sem_aquecer" in args)
	PersonagemMinePiece.economia_de_parado = not ("sem_parado" in args)
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_cronometro.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://medir_cronometro.json"))
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
	current_scene.ir_a_ilha("ilha_east_blue")
	var todos := []
	limite = Time.get_ticks_msec() + 120000
	while todos.size() < 5 and Time.get_ticks_msec() < limite:
		await process_frame
		todos = get_nodes_in_group("personagens_east_blue")
	for i in 150: await process_frame
	todos = get_nodes_in_group("personagens_east_blue")
	var marinheiros := todos.filter(func(p): return str(p.ficha.get("id", "")) == "marine")
	if marinheiros.is_empty():
		print("sem marinheiros: nada a medir")
		quit(1)
		return
	_j.global_position = marinheiros[0].global_position + Vector3(0, 0.5, 12.0)
	_j.set("velocity", Vector3.ZERO)
	# Distâncias dos personagens ao jogador (faixas do ServerCore: mob = 20 blocos): quanto uma faixa de ativação alcançaria.
	var faixas := {"<20 m": 0, "20-40 m": 0, "40-80 m": 0, ">80 m": 0}
	for p in todos:
		var d: float = _j.global_position.distance_to(p.global_position)
		faixas["<20 m" if d < 20.0 else "20-40 m" if d < 40.0 else "40-80 m" if d < 80.0 else ">80 m"] += 1
	_dizer("distância ao jogador: " + str(faixas))
	# O cronômetro liga ANTES de a ilha acordar: os primeiros ticks (ao_nascer) acontecem logo depois do teleporte.
	Cronometro.ligado = true
	AMOSTRAS = 240
	await _amostrar("A0. os primeiros 240 quadros após chegar ao acampamento (o LOD acorda os personagens)")
	_dizer("rotulo=%s  motor=%s  personagens=%d  inimigos(enemy)=%d  nos=%d" % [rotulo, Engine.get_version_info().string, todos.size(),
		get_nodes_in_group("enemy").size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])

	# Daqui em diante o LOD é TRAVADO e os personagens são devolvidos à mão, para medir o regime estável sem a ilha voltar a dormir.
	for no in current_scene.find_children("*", "Node", true, false):
		var sc: Script = no.get_script()
		if sc != null and str(sc.resource_path).ends_with("lod_das_ilhas.gd"):
			no.process_mode = Node.PROCESS_MODE_DISABLED
	for p in todos:
		if is_instance_valid(p):
			p.process_mode = Node.PROCESS_MODE_INHERIT
			p.visible = true
	for i in 120: await process_frame
	var vivos := 0
	for p in todos:
		if is_instance_valid(p) and p.is_physics_processing() and p.is_inside_tree():
			vivos += 1
	_dizer("personagens processando no regime estável: %d de %d" % [vivos, todos.size()])
	AMOSTRAS = 360
	var antes := await _amostrar("A. regime estável: acampamento, LOD travado, IAs ativas")

	# B. A ESPIRAL DO MOTOR: se o passo de física custa mais que 1/60 s, o Godot roda VÁRIOS passos no quadro seguinte
	#    (até max_physics_steps_per_frame), cada um com todos os personagens. Rodar SEM --fixed-fps para o tempo ser o real.
	#    Pausa de 100 ms e, nos 12 quadros seguintes, tempo do quadro e passos de física.
	_dizer("\n== B. depois de uma pausa de 100 ms: quadro_ms / passos de física por quadro, 12 quadros seguidos (física=%d Hz, máx %d passos) ==" % [
		Engine.physics_ticks_per_second, int(ProjectSettings.get_setting("physics/common/max_physics_steps_per_frame", 8))])
	for rep in 4:
		for i in 60: await process_frame
		var f0 := Engine.get_physics_frames()
		OS.delay_msec(100)
		var t_ant := Time.get_ticks_usec()
		var linha := []
		for i in 12:
			await process_frame
			var agora := Time.get_ticks_usec()
			var f1 := Engine.get_physics_frames()
			linha.append("%5.1fms/%dp" % [(agora - t_ant) / 1000.0, f1 - f0])
			t_ant = agora
			f0 = f1
		_dizer("   " + "  ".join(linha))
	_dizer("\njogador ao fim: vida=%.0f/%.0f  imortal=%s" % [_j.health, _j.max_health, str(_j.get_meta("damage_immune", false))])
	Cronometro.ligado = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://desempenho"))
	var f := FileAccess.open("user://desempenho/%s.txt" % rotulo, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_linhas) + "\n")
		f.close()
	modo.set("progresso_forcado", "")
	quit(0)
