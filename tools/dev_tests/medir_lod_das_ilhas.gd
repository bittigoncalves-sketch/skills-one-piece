extends SceneTree
# ============================================================================
#  MEDIÇÃO — custo de desenho das ilhas por distância (08/10/2026, Ilha dos Macacos,
#  docs/ILHA_DOS_MACACOS_PLANO.md, etapa 4). Precisa de GPU (sem --headless).
#
#    "$(./find_godot.sh)" --path . --script tools/dev_tests/medir_lod_das_ilhas.gd -- --rotulo=antes
#
#  Abre o Modo História com o MAPA VIVO (só leitura) e um progresso de TESTE, põe o
#  jogador em pontos fixos (vila, porto olhando para os macacos, meio do mar olhando
#  para cada lado, Ilha dos Macacos olhando para cada lado) e mede, com o v-sync
#  desligado: objetos e chamadas de desenho no quadro, primitivas, tempo de CPU e de
#  GPU do desenho e o tempo do quadro pelo relógio. Foto de cada ponto em
#  art_src/validation/ilha_dos_macacos/lod_<rotulo>_<ponto>.png. Rodar antes e depois
#  da mudança nas mesmas condições.
#  ⚠️ Não usar `Performance.TIME_PROCESS` como tempo de quadro: ele é amostrado e pegou
#  o pico do teleporte e da foto do ponto anterior (deu 33–88 ms com quadros de 7–8 ms).
# ============================================================================

const PROGRESSO := "user://medir_lod_das_ilhas_progresso.json"
const PASTA := "res://art_src/validation/ilha_dos_macacos"
const LESTE := -PI / 2.0
const OESTE := PI / 2.0
## nome, posição (x, z), "terra" ou "mar", para onde a câmera olha
const PONTOS := [
	["vila", Vector2(152, 20), "terra", OESTE],
	["porto_olhando_macacos", Vector2(250, 10), "terra", LESTE],
	["fronteira_384m_perto", Vector2(640, 10), "mar", OESTE],
	["fronteira_424m_longe", Vector2(680, 10), "mar", OESTE],
	["mar_meio_olhando_inicial", Vector2(814, 0), "mar", OESTE],
	["mar_meio_olhando_macacos", Vector2(814, 0), "mar", LESTE],
	["macacos_olhando_inicial", Vector2(1488, 4), "terra", OESTE],
	["macacos_olhando_leste", Vector2(1488, 4), "terra", LESTE],
]
const QUADROS := 90

var rotulo := "antes"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A medição exige renderer real (rode sem --headless).")
		quit(1)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rotulo="):
			rotulo = a.trim_prefix("--rotulo=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 200:
		await process_frame
	var jogador: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	if jogador == null:
		push_error("sem jogador")
		quit(1)
		return
	jogador.set_meta("damage_immune", true)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var espaco := jogador.get_world_3d().direct_space_state
	print("LOD_MEDICAO rotulo=%s" % rotulo)
	print("%-28s %8s %8s %10s %8s %8s %9s %7s" % ["ponto", "objetos", "draws", "primitivas", "cpu_ms", "gpu_ms", "quadro_ms", "pecas"])
	for ponto in PONTOS:
		var xz: Vector2 = ponto[1]
		var y := 0.0
		if ponto[2] == "mar":
			y = AguaDoMundo.nivel_em(xz.x, xz.y) - 0.3
		else:
			var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x, 120, xz.y), Vector3(xz.x, -40, xz.y), 1))
			y = (float(hit["position"].y) if not hit.is_empty() else 0.0) + 1.2
		jogador.global_position = Vector3(xz.x, y, xz.y)
		jogador.velocity = Vector3.ZERO
		jogador.set("_yaw", float(ponto[3]))
		jogador.call("_update_pivot")
		for i in 90:                       # assenta: detalhe dos bichos, LOD, física
			await process_frame
		var soma := {"obj": 0.0, "draw": 0.0, "prim": 0.0, "cpu": 0.0, "gpu": 0.0}
		var t0 := Time.get_ticks_usec()
		for i in QUADROS:
			await process_frame
			soma.obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			soma.draw += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			soma.prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			soma.cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			soma.gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		var quadro := (Time.get_ticks_usec() - t0) / 1000.0 / QUADROS
		for k in soma:
			soma[k] /= QUADROS
		print("%-28s %8.0f %8.0f %10.0f %8.2f %8.2f %9.2f %7d" % [ponto[0], soma.obj, soma.draw, soma.prim, soma.cpu, soma.gpu,
			quadro, _pecas_visiveis()])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join("lod_%s_%s.png" % [rotulo, ponto[0]])))
	# Custo da TROCA (esconder/mostrar as peças da ilha inicial de uma vez), se houver
	# o desenho por distância.
	var lod: Node = current_scene.get_node_or_null("LodDasIlhas")
	if lod != null:
		var ini: Dictionary = lod.get("_ilhas")["ilha_inicial"]
		for par in [[1, "PERTO→LONGE"], [0, "LONGE→PERTO"], [2, "PERTO→OCULTA"], [0, "OCULTA→PERTO"]]:
			var t0 := Time.get_ticks_usec()
			lod.call("_aplicar", ini, par[0])
			var gasto := (Time.get_ticks_usec() - t0) / 1000.0
			var q0 := Time.get_ticks_usec()
			await process_frame
			print("TROCA %-14s %.2f ms na chamada, quadro seguinte %.2f ms" % [par[1], gasto, (Time.get_ticks_usec() - q0) / 1000.0])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	quit()


## Peças do mapa visíveis (o nó da peça e o pai dela visíveis).
func _pecas_visiveis() -> int:
	var mapa := current_scene.get_node_or_null(NodePath(MapaMontador.NOME_RAIZ)) as Node3D
	if mapa == null:
		return -1
	var n := 0
	for filho in mapa.get_children():
		if filho is Node3D and (filho as Node3D).is_visible_in_tree():
			n += 1
	return n
