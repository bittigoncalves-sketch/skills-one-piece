extends SceneTree
## Inventário do que existe para desenhar no Modo História (30/10/2026): por grupo (filho direto da cena e, dentro dele,
## o nome do pai do MeshInstance3D/MultiMesh): quantos nós, triângulos, quantos projetam sombra e quantos têm alcance de visibilidade.
## Só leitura. Precisa do renderizador? Não: lê as malhas. Pode rodar em headless.
##   godot --headless --path . --script res://tools/dev_tests/medir_inventario_visual.gd
const PROGRESSO := "user://medir_inventario_progresso.json"
func _init() -> void:
	call_deferred("_rodar")

func _tris(no: Node) -> int:
	var malha: Mesh = null
	var copias := 1
	if no is MeshInstance3D:
		malha = (no as MeshInstance3D).mesh
	elif no is MultiMeshInstance3D and (no as MultiMeshInstance3D).multimesh != null:
		malha = (no as MultiMeshInstance3D).multimesh.mesh
		copias = (no as MultiMeshInstance3D).multimesh.visible_instance_count
		if copias < 0:
			copias = (no as MultiMeshInstance3D).multimesh.instance_count
	if malha == null:
		return 0
	var n := 0
	for s in malha.get_surface_count():
		var arr := malha.surface_get_arrays(s)
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx != null and idx.size() > 0:
			n += idx.size() / 3
		else:
			var vtx = arr[Mesh.ARRAY_VERTEX]
			n += (vtx.size() / 3) if vtx != null else 0
	return n * copias

func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.progresso_forcado = PROGRESSO
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	root.get_node("GameFlow").start_story()
	var p = null
	var limite := Time.get_ticks_msec() + 150000
	while p == null and Time.get_ticks_msec() < limite:
		await process_frame
		p = get_first_node_in_group("player")
	for i in 60:
		await process_frame
	var grupos := {}
	var total := {"nos": 0, "tris": 0, "sombra": 0, "alcance": 0, "multimesh": 0}
	var pilha: Array[Node] = [current_scene]
	var raiz := current_scene
	while not pilha.is_empty():
		var no: Node = pilha.pop_back()
		for f in no.get_children():
			pilha.append(f)
		if not (no is MeshInstance3D or no is MultiMeshInstance3D):
			continue
		var gi := no as GeometryInstance3D
		var t := _tris(no)
		# Chave: filho direto da cena › filho seguinte (a categoria que o autor deu).
		var caminho := raiz.get_path_to(no)
		var chave := str(caminho.get_name(0)) if caminho.get_name_count() > 0 else "?"
		if caminho.get_name_count() > 2:
			chave += "/" + str(caminho.get_name(1))
		var g: Dictionary = grupos.get(chave, {"nos": 0, "tris": 0, "sombra": 0, "alcance": 0, "multimesh": 0})
		g.nos += 1
		g.tris += t
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			g.sombra += t
			total.sombra += t
		if gi.visibility_range_end > 0.0:
			g.alcance += 1
			total.alcance += 1
		if no is MultiMeshInstance3D:
			g.multimesh += 1
			total.multimesh += 1
		grupos[chave] = g
		total.nos += 1
		total.tris += t
	var chaves := grupos.keys()
	chaves.sort_custom(func(a, b): return grupos[a].tris > grupos[b].tris)
	print("\n===== INVENTARIO VISUAL =====")
	print("%-46s %7s %11s %11s %7s %6s" % ["grupo", "nos", "triangulos", "tri_sombra", "alcance", "multim"])
	for k in chaves.slice(0, 22):
		var g: Dictionary = grupos[k]
		print("%-46s %7d %11d %11d %7d %6d" % [str(k).left(46), g.nos, g.tris, g.sombra, g.alcance, g.multimesh])
	print("%-46s %7d %11d %11d %7d %6d" % ["TOTAL", total.nos, total.tris, total.sombra, total.alcance, total.multimesh])

	# ---- O que a câmera realmente pode ver, por vista (cone de visão + alcance de visibilidade) ----
	var cam: Camera3D = p._cam if p != null and "_cam" in p else null
	if cam != null:
		var base_yaw: float = p._yaw
		for v in [["frente", 0.0], ["tras", 180.0]]:
			p._yaw = base_yaw + deg_to_rad(v[1])
			p._pitch = 0.0
			p._update_pivot()
			for i in 5:
				await process_frame
			var planos := cam.get_frustum()
			var origem := cam.global_position
			var por: Dictionary = {}
			var tot := {"nos": 0, "dentro": 0, "superf_dentro": 0, "tris_dentro": 0, "pequenos_dentro": 0}
			var pil: Array[Node] = [current_scene]
			while not pil.is_empty():
				var no: Node = pil.pop_back()
				for f in no.get_children():
					pil.append(f)
				if not (no is MeshInstance3D or no is MultiMeshInstance3D):
					continue
				var gi := no as GeometryInstance3D
				if not gi.is_visible_in_tree():
					continue
				tot.nos += 1
				var caixa: AABB = gi.global_transform * gi.get_aabb()
				var fora := false
				for pl in planos:
					var pt := Vector3(caixa.position.x + (caixa.size.x if pl.normal.x > 0.0 else 0.0),
						caixa.position.y + (caixa.size.y if pl.normal.y > 0.0 else 0.0),
						caixa.position.z + (caixa.size.z if pl.normal.z > 0.0 else 0.0))
					if pl.distance_to(pt) > 0.0:
						fora = true
						break
				if fora:
					continue
				if gi.visibility_range_end > 0.0 and origem.distance_to(caixa.get_center()) > gi.visibility_range_end + caixa.size.length() * 0.5:
					continue
				var nome := str(current_scene.get_path_to(no)).get_slice("/", 0)
				if str(current_scene.get_path_to(no)).begins_with("Mapa/"):
					nome = "Mapa/" + ("relevo" if "Relevo" in str(no.name) else ("navio" if "navio" in str(no.name) else "pecas"))
				var d: Dictionary = por.get(nome, {"nos": 0, "superf": 0, "tris": 0, "pequenos": 0})
				d.nos += 1
				d.superf += (no.mesh.get_surface_count() if no is MeshInstance3D and no.mesh != null else 1)
				d.tris += _tris(no)
				var dist := origem.distance_to(caixa.get_center())
				if caixa.size.length() * 164.0 < dist:    # menor que ~0,35 grau na tela
					d.pequenos += 1
					tot.pequenos_dentro += 1
				por[nome] = d
				tot.dentro += 1
				tot.superf_dentro += d.superf if false else 0
			print("\n-- no cone de visao: %s (de %d nos visiveis na arvore, %d dentro do cone; %d seriam sub-0,35 grau) --" % [v[0], tot.nos, tot.dentro, tot.pequenos_dentro])
			print("%-30s %7s %8s %11s %9s" % ["categoria", "nos", "superf", "triangulos", "pequenos"])
			var ks := por.keys()
			ks.sort_custom(func(a, b): return por[a].superf > por[b].superf)
			for k in ks.slice(0, 12):
				print("%-30s %7d %8d %11d %9d" % [str(k).left(30), por[k].nos, por[k].superf, por[k].tris, por[k].pequenos])
	modo.progresso_forcado = ""
	quit(0)
