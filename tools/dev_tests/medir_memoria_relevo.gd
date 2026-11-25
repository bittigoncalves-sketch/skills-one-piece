extends SceneTree
## Memória e fusão do relevo em blocos (23/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E5).
## Pedido do dono: "medir a renderização e a união de blocos; ilha oca: manter o interior
## da ilha oco para menos gasto de memória".
##
## Por ilha: faces sem fusão (uma por meio bloco exposto) × depois da fusão, vértices da
## malha, triângulos da colisão, bytes dos dados na CPU; e o que as peças `terreno` lisas
## ainda seguram (tem de ser zero: malha, forma e a meta da seleção do editor são soltas
## em `relevo_das_ilhas.gd`). Por fim, memória estática e de vídeo.
## Com janela (memória de vídeo só existe com placa de vídeo):
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/medir_memoria_relevo.gd

const MB := 1048576.0


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await process_frame


## Faces se cada meio bloco exposto fosse uma face (topo por meio, parede por meio×meio).
static func faces_sem_fusao(r: RelevoEmBlocos) -> int:
	var n := 0
	for j in r.profundidade:
		for i in r.largura:
			var h := r._f(i, j)
			if h != RelevoEmBlocos.SEM:
				n += 1
			# Paredes com o vizinho de −x e de −z (e as bordas de fora, até o fundo).
			for viz in [Vector2i(i - 1, j), Vector2i(i, j - 1)]:
				var g := r._f(viz.x, viz.y)
				if h == RelevoEmBlocos.SEM and g == RelevoEmBlocos.SEM:
					continue
				n += absi((h if h != RelevoEmBlocos.SEM else r.fundo) - (g if g != RelevoEmBlocos.SEM else r.fundo))
		# borda de +x
		var ult := r._f(r.largura - 1, j)
		if ult != RelevoEmBlocos.SEM:
			n += ult - r.fundo
	for i in r.largura:
		var ult := r._f(i, r.profundidade - 1)
		if ult != RelevoEmBlocos.SEM:
			n += ult - r.fundo
	return n


func _memoria() -> String:
	return "estática %.1f MB  vídeo %.1f MB  buffers %.1f MB" % [
		Performance.get_monitor(Performance.MEMORY_STATIC) / MB,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / MB]


func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_memoria_relevo.json")
	root.get_node("GameFlow").start_story()
	await frames(240)
	var raiz := current_scene.find_child("Mapa", true, false)
	if raiz == null:
		push_error("sem o nó Mapa")
		quit(1)
		return

	var tot := {"sem": 0, "com": 0, "vert": 0, "col": 0, "cpu": 0, "liso_vert": 0, "liso_col": 0, "pecas": 0}
	print("\nMEMRELEVO ilha                         sem fusão  fundidas  redução  vértices  tri colisão  CPU(f,cor,tipos)")
	for corpo in raiz.get_children():
		if not corpo.has_meta(RelevoEmBlocos.META):
			continue
		var r: RelevoEmBlocos = corpo.get_meta(RelevoEmBlocos.META)
		var sem := faces_sem_fusao(r)
		var malha := (corpo.get_node("Malha") as MeshInstance3D).mesh as ArrayMesh
		var vert := malha.surface_get_array_len(0) if malha.get_surface_count() > 0 else 0
		var col := ((corpo.get_node("Colisao") as CollisionShape3D).shape as ConcavePolygonShape3D).get_faces().size() / 3
		var cpu := r.f.size() * 4 + r.cor.size() + r.tipos.size()
		print("MEMRELEVO %-28s %9d %9d %7.1f×  %8d  %11d  %6.2f MB" % [corpo.get_meta("ilha"), sem, r.faces,
			float(sem) / maxf(r.faces, 1), vert, col, cpu / MB])
		tot["sem"] += sem
		tot["com"] += r.faces
		tot["vert"] += vert
		tot["col"] += col
		tot["cpu"] += cpu
	# As peças `terreno` lisas que o relevo em blocos substituiu: não podem segurar malha,
	# forma nem a meta da seleção do editor (as três seguravam memória até 23/10/2026).
	for no in raiz.get_children():
		var m := no.get_node_or_null("Malha") as MeshInstance3D
		var c := no.get_node_or_null("Colisao") as CollisionShape3D
		if m == null or m.visible or c == null or not c.disabled:
			continue
		tot["pecas"] += 1
		if m.mesh is ArrayMesh:
			for s in (m.mesh as ArrayMesh).get_surface_count():
				tot["liso_vert"] += (m.mesh as ArrayMesh).surface_get_array_len(s)
		for forma in [c.shape, no.get_meta("terreno_forma", null)]:
			if forma is ConcavePolygonShape3D:
				tot["liso_col"] += (forma as ConcavePolygonShape3D).get_faces().size() / 3
	print("MEMRELEVO TOTAL blocos: %d faces sem fusão → %d fundidas (%.1f×), %d vértices, %d tri de colisão, CPU %.2f MB" % [
		tot["sem"], tot["com"], float(tot["sem"]) / maxf(tot["com"], 1), tot["vert"], tot["col"], tot["cpu"] / MB])
	print("MEMRELEVO TOTAL lisas substituídas: %d peças, ainda seguram %d vértices e %d tri de colisão" % [
		tot["pecas"], tot["liso_vert"], tot["liso_col"]])
	await frames(60)
	print("MEMRELEVO memória: " + _memoria())
	modo.set("progresso_forcado", "")
	quit()
