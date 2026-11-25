extends SceneTree
## V2 (mundo voxel): quanto seria o terreno de cada ilha em blocos? Conta colunas, blocos sólidos (do fundo ao topo) e seções 16³.
##   godot --headless --path . --script tools/dev_tests/medir_tamanho_voxel_das_ilhas.gd   (com MemoryMax)
func frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	_rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_tamanho_voxel.json")
	root.get_node("GameFlow").start_story()
	await frames(240)
	var raiz := current_scene.find_child("Mapa", true, false)
	var tot_blocos := 0
	var tot_sec := 0
	var tot_sup := 0
	for corpo in raiz.get_children():
		if not corpo.has_meta(RelevoEmBlocos.META):
			continue
		var r: RelevoEmBlocos = corpo.get_meta(RelevoEmBlocos.META)
		var colunas := 0
		var blocos := 0
		var topo_max := -99999
		var secoes := {}
		var superficie := 0
		for cj in r.profundidade / 2:
			for ci in r.largura / 2:
				var a := 2 * cj * r.largura + 2 * ci
				var h := 0
				var alguma := false
				for k in [a, a + 1, a + r.largura, a + r.largura + 1]:
					if r.f[k] != RelevoEmBlocos.SEM:
						alguma = true
						h = maxi(h, r.f[k])
				if not alguma:
					continue
				colunas += 1
				var topo := ceili(h / 2.0)                       # em blocos
				var base := floori(r.fundo / 2.0)
				blocos += topo - base
				topo_max = maxi(topo_max, topo)
				var cx := floori(float(r.origem.x / 2 + ci) / 16.0)
				var cz := floori(float(r.origem.y / 2 + cj) / 16.0)
				for cy in range(floori(float(base) / 16.0), floori(float(topo - 1) / 16.0) + 1):
					secoes[Vector3i(cx, cy, cz)] = true
				superficie += 1
		tot_blocos += blocos
		tot_sec += secoes.size()
		tot_sup += superficie
		print("VOXTAM %-26s colunas=%7d blocos_cheios=%9d seções=%4d fundo=%d topo_max=%d (%.1f MB int32)" % [
			corpo.get_meta("ilha"), colunas, blocos, secoes.size(), r.fundo, topo_max, secoes.size() * 16384.0 / 1048576.0])
	print("VOXTAM TOTAL blocos_cheios=%d seções=%d (%.1f MB int32)" % [tot_blocos, tot_sec, tot_sec * 16384.0 / 1048576.0])
	modo.set("progresso_forcado", "")
	quit()
