extends SceneTree
## Mede o custo de DESENHAR o Modo História (30/10/2026), para decidir e provar cortes por visibilidade.
## Precisa de janela (renderizador real): headless não desenha. Usa o mapa vivo SÓ para leitura e um progresso isolado.
##   godot --path . --resolution 960x540 --disable-vsync --script res://tools/dev_tests/medir_desempenho_historia.gd -- [rotulo]
## Por vista (jogador parado, câmera virada para um rumo): chamadas de desenho, objetos e primitivas desenhados no quadro,
## tempo de CPU e de GPU de renderização por quadro (mediana de AMOSTRAS quadros), nós na árvore e memória de vídeo.
## Grava em user://desempenho/<rotulo>.txt (e imprime) para comparar antes/depois.
const PROGRESSO := "user://medir_desempenho_progresso.json"
const AQUECER := 90
const AMOSTRAS := 120
var _rotulo := "medicao"
var _linhas: Array[String] = []

func _init() -> void:
	call_deferred("_rodar")

## Alavancas EXPERIMENTAIS, uma por rodada, só para medir o efeito (nada disso fica no jogo):
##   base · sombra_off · sombra_120 (alcance 120 m) · sombra_2 (2 cascatas) · msaa_off · escala_075 · pequenos (sub-0,35°) · pequenos_1 (sub-1°)
func _aplicar_variante(nome: String) -> void:
	var sois: Array = []
	var pilha: Array[Node] = [current_scene]
	var ciclo: Node = null
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		if no is CicloDiaNoite:
			ciclo = no
	# O ciclo reescreve a sombra do sol e da lua a cada quadro e a hora do jogo muda o resultado:
	# fixa o MEIO-DIA e pausa, para a medição ser a mesma em todas as rodadas.
	if ciclo != null:
		ciclo.pausado = true
		ciclo.definir_hora(12.0)
	var sol := current_scene.get_node_or_null("Sol") as DirectionalLight3D
	if sol != null:
		sois.append(sol)
	_linhas.append("variante=%s  hora=%s  sol com sombra=%s  cascatas=%d  alcance=%.0f" % [nome,
		ciclo.texto_da_hora() if ciclo != null else "?", str(sol.shadow_enabled) if sol != null else "?",
		(2 if sol.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS else (4 if sol.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS else 1)) if sol != null else 0,
		sol.directional_shadow_max_distance if sol != null else 0.0])
	for parte in nome.split("+"):
		_uma_variante(parte, sois)


func _uma_variante(nome: String, sois: Array) -> void:
	match nome:
		"economia_real":
			# O código do jogo (PerfilGrafico), sem gravar nada no aparelho: só a variável estática.
			PerfilGrafico.modo = PerfilGrafico.Modo.ECONOMIA
			for n in get_nodes_in_group(PerfilGrafico.GRUPO):
				(n as PerfilGrafico).reavaliar()
			_linhas.append("economia_real: economia=%s, controladores=%d" % [str((get_nodes_in_group(PerfilGrafico.GRUPO)[0] as PerfilGrafico).economia),
				get_nodes_in_group(PerfilGrafico.GRUPO).size()])
		"sombra_60":
			for l in sois: l.directional_shadow_max_distance = 60.0
		"sombra_off":
			for l in sois: l.shadow_enabled = false
		"sombra_120":
			for l in sois: l.directional_shadow_max_distance = 120.0
		"sombra_2":
			for l in sois: l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		"sombra_1":
			for l in sois: l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"msaa_off":
			root.msaa_3d = Viewport.MSAA_DISABLED
		"escala_075":
			root.scaling_3d_scale = 0.75
		"pequenos", "pequenos_1":
			var fator := 164.0 if nome == "pequenos" else 57.0
			var n := 0
			var mapa := current_scene.get_node_or_null("Mapa")
			var raiz: Node = mapa if mapa != null else current_scene
			var st: Array[Node] = [raiz]
			while not st.is_empty():
				var no: Node = st.pop_back()
				st.append_array(no.get_children())
				if (no is MeshInstance3D or no is MultiMeshInstance3D) and (no as GeometryInstance3D).visibility_range_end <= 0.0:
					var d := ((no as GeometryInstance3D).get_aabb().size * (no as Node3D).global_transform.basis.get_scale()).length()
					(no as GeometryInstance3D).visibility_range_end = maxf(d * fator, 30.0)
					(no as GeometryInstance3D).visibility_range_end_margin = 5.0
					n += 1
			_linhas.append("pequenos: %d objetos ganharam alcance" % n)


func _mediana(v: Array) -> float:
	if v.is_empty():
		return 0.0
	var c := v.duplicate()
	c.sort()
	return float(c[c.size() / 2])

func _rodar() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_rotulo = args[0]
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.progresso_forcado = PROGRESSO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	root.get_node("GameFlow").start_story()
	# A carga leva ~19 s e a cena não processa até acabar: espera o jogador, no máximo 150 s.
	var p = null
	var limite := Time.get_ticks_msec() + 150000
	while p == null and Time.get_ticks_msec() < limite:
		await process_frame
		p = get_first_node_in_group("player")
	for i in 120:
		await process_frame
	if p == null:
		print("MEDIR: sem jogador")
		quit(1)
		return
	_aplicar_variante(args[1] if args.size() > 1 else "base")
	for i in 60:
		await process_frame
	var vp := root.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	_linhas.append("rotulo=%s  motor=%s  gpu=%s  janela=%s" % [_rotulo, Engine.get_version_info().string,
		RenderingServer.get_video_adapter_name(), str(root.size)])
	_linhas.append("nos=%d  objetos=%d  memoria_estatica=%.0f MB" % [int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_COUNT)), Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])
	_linhas.append("%-14s %9s %9s %11s %8s %8s %8s %8s %8s" % ["vista", "draw", "objetos", "primitivas", "cpu_ms", "gpu_ms", "fps", "quad_ms", "fis_ms"])
	p.set_meta("damage_immune", true)
	var base_yaw: float = p._yaw
	for v in [["frente", 0.0, 0.0], ["direita", 90.0, 0.0], ["tras", 180.0, 0.0], ["esquerda", 270.0, 0.0],
			["ceu", 0.0, 60.0], ["chao", 0.0, -60.0]]:
		p._yaw = base_yaw + deg_to_rad(v[1])
		p._pitch = deg_to_rad(v[2])
		p._update_pivot()
		for i in AQUECER:
			await process_frame
		var draws := []
		var objs := []
		var prims := []
		var cpu := []
		var gpu := []
		var proc := []   # TIME_PROCESS = o QUADRO INTEIRO (não só scripts); TIME_PHYSICS_PROCESS = o passo de física. Em ms (04/11/2026)
		var fis := []
		var t0 := Time.get_ticks_usec()
		for i in AMOSTRAS:
			await process_frame
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			objs.append(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
			prims.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
			cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			proc.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			fis.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var fps := AMOSTRAS / ((Time.get_ticks_usec() - t0) / 1000000.0)
		_linhas.append("%-14s %9d %9d %11d %8.2f %8.2f %8.1f %8.2f %8.2f" % [v[0], _mediana(draws), _mediana(objs), _mediana(prims),
			_mediana(cpu), _mediana(gpu), fps, _mediana(proc), _mediana(fis)])
	_linhas.append_array(_censo_de_processamento())
	var texto := "\n".join(_linhas)
	print("\n===== MEDIR DESEMPENHO =====\n" + texto)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://desempenho"))
	var f := FileAccess.open("user://desempenho/%s.txt" % _rotulo, FileAccess.WRITE)
	if f != null:
		f.store_string(texto + "\n")
		f.close()
	modo.progresso_forcado = ""
	quit(0)


## Censo (04/11/2026): quantos nós têm _process / _physics_process ligados, por script. Aponta onde procurar o custo
## que não é desenho, sem tempo por script (isso exige o perfilador do editor). Mais nós = mais candidatos, não mais lento.
func _censo_de_processamento() -> Array[String]:
	var proc := {}
	var fis := {}
	var pilha: Array[Node] = [root]
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		pilha.append_array(no.get_children())
		var sc: Script = no.get_script()
		var chave: String = sc.resource_path.get_file() if sc != null else "(" + no.get_class() + ")"
		if no.is_processing():
			proc[chave] = int(proc.get(chave, 0)) + 1
		if no.is_physics_processing():
			fis[chave] = int(fis.get(chave, 0)) + 1
	var saida: Array[String] = []
	for par in [["_process", proc], ["_physics_process", fis]]:
		var d: Dictionary = par[1]
		var chaves := d.keys()
		chaves.sort_custom(func(a, b): return d[a] > d[b])
		var total := 0
		for k in chaves:
			total += d[k]
		saida.append("censo %s: %d nos ligados" % [par[0], total])
		for k in chaves.slice(0, 12):
			saida.append("  %5d  %s" % [d[k], k])
	return saida
