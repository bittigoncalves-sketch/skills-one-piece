extends SceneTree
# ============================================================================
#  MEDIÇÃO — custo de desenho do MAR (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E0/E7).
#  Precisa de GPU (sem --headless). Abre uma janela; o mouse é solto logo após nascer.
#
#    "$(./find_godot.sh)" --path . --script tools/dev_tests/medir_mar.gd -- --rotulo=antes
#
#  Mesma metodologia do `medir_lod_das_ilhas.gd`: MAPA VIVO (só leitura), progresso de
#  TESTE, v-sync desligado, 90 quadros de assentamento e 90 medidos por ponto. Pontos na
#  superfície, na plataforma, no talude e no meio do mar, acima e abaixo d'água. Foto de
#  cada ponto em art_src/validation/mar/medir_<rotulo>_<ponto>.png. Rodar antes e depois
#  de cada etapa nas mesmas condições.
# ============================================================================

const PROGRESSO := "user://medir_mar_progresso.json"
const PASTA := "res://art_src/validation/mar"
const LESTE := -PI / 2.0
const OESTE := PI / 2.0
const NORTE := 0.0
## Médias de QUADROS quadros.
func _medir(vp: RID) -> Dictionary:
	var soma := {"obj": 0.0, "draw": 0.0, "prim": 0.0, "cpu": 0.0, "gpu": 0.0}
	var t0 := Time.get_ticks_usec()
	for i in QUADROS:
		await process_frame
		soma.obj += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		soma.draw += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		soma.prim += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		soma.cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		soma.gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	for k in soma:
		soma[k] /= QUADROS
	soma["quadro"] = (Time.get_ticks_usec() - t0) / 1000.0 / QUADROS
	return soma


## nome, (x, z), altura ("superficie", "fundo+N" ou "nivel-N"), yaw, pitch
const PONTOS := [
	["porto_superficie", Vector2(300, 40), "superficie", LESTE, -0.25],
	["plataforma_submersa", Vector2(340, 0), "fundo+3", LESTE, -0.30],
	["talude_submerso", Vector2(430, 0), "nivel-20", LESTE, -0.45],
	["norte_submerso", Vector2(0, -330), "fundo+3", NORTE, -0.30],
	["mar_meio_navegando", Vector2(814, 0), "superficie", LESTE, -0.25],
	["mar_meio_submerso", Vector2(814, 0), "nivel-15", LESTE, -0.45],
	["macacos_submerso", Vector2(1312, 20), "fundo+3", OESTE, -0.30],
	# E2 (14/10): miolo de recife mais denso perto do porto (achado pelo capturar_recifes).
	["recife_denso", Vector2(372, 90), "nivel-4", LESTE, -0.30],
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	jogador.set_meta("damage_immune", true)
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var espaco := jogador.get_world_3d().direct_space_state
	print("MAR_MEDICAO rotulo=%s" % rotulo)
	print("%-22s %8s %8s %10s %8s %8s %9s %8s" % ["ponto", "objetos", "draws", "primitivas", "cpu_ms", "gpu_ms", "quadro_ms", "fundo_m"])
	for ponto in PONTOS:
		var xz: Vector2 = ponto[1]
		var nivel := AguaDoMundo.nivel_em(xz.x, xz.y)
		var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(xz.x, nivel, xz.y), Vector3(xz.x, -300, xz.y), 1))
		var fundo := float(hit["position"].y) if not hit.is_empty() else NAN
		var regra: String = ponto[2]
		var y := nivel - 0.3
		if regra.begins_with("fundo+"):
			y = fundo + float(regra.trim_prefix("fundo+"))
		elif regra.begins_with("nivel-"):
			y = nivel - float(regra.trim_prefix("nivel-"))
			if not is_nan(fundo):
				y = maxf(y, fundo + 2.0)
		jogador.global_position = Vector3(xz.x, y, xz.y)
		jogador.velocity = Vector3.ZERO
		jogador.set("_yaw", float(ponto[3]))
		jogador.set("_pitch", float(ponto[4]))
		jogador.call("_update_pivot")
		for i in 90:                       # assenta: LOD, física, detalhe
			await process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
		print("%-22s %8.0f %8.0f %10.0f %8.2f %8.2f %9.2f %8.1f" % [ponto[0], soma.obj, soma.draw, soma.prim, soma.cpu, soma.gpu,
			quadro, fundo])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join("medir_%s_%s.png" % [rotulo, ponto[0]])))
		# A/B no mesmo ponto: o que o `Mar` (recifes, naufrágios, peixes...) custa.
		var mar := current_scene.get_node_or_null("Mar") as Node3D
		if mar != null:
			mar.visible = false
			mar.process_mode = Node.PROCESS_MODE_DISABLED
			for i in 30:
				await process_frame
			var sem := await _medir(vp)
			print("%-22s %8.0f %8.0f %10.0f %8.2f %8.2f %9.2f" % ["  (sem Mar)", sem.obj, sem.draw, sem.prim, sem.cpu, sem.gpu, sem.quadro])
			mar.visible = true
			mar.process_mode = Node.PROCESS_MODE_INHERIT
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	quit()
