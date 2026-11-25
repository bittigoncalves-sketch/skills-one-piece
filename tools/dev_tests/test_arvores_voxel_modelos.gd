extends SceneTree
## Árvores do Modo História em voxel (tools/trocar_arvores_por_voxel.gd): cada .glb trocado
## mantém a caixa, as malhas `Colisao*`, os pontos `Fruta_*`, bate com o catálogo e é voxel
## de fato (só faces alinhadas aos eixos). Compara com os originais em art_src/backups/.
## godot --headless --path . --script tools/dev_tests/test_arvores_voxel_modelos.gd

const BACKUP := "res://art_src/backups/arvores_antes_voxel_2026-11-04/%s.glb"
const MAX_TRIANGULOS := 6000

func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var falhas := 0
	var n := 0
	var tri_max := 0
	for id in bib.ids():
		if not FileAccess.file_exists(BACKUP % id):
			continue
		n += 1
		var antes := BibliotecaDeModelos.carregar_glb(BACKUP % id)
		var depois := BibliotecaDeModelos.carregar_glb(bib.caminho_do_arquivo(id))
		var erros: Array[String] = []
		if depois == null:
			erros.append("não abre")
		else:
			var ma := BibliotecaDeModelos.medir(antes)
			var md := BibliotecaDeModelos.medir(depois)
			var ca: AABB = ma["aabb"]
			var cd: AABB = md["aabb"]
			if not (ca.size - cd.size).abs().is_zero_approx() and (ca.size - cd.size).length() > ca.size.length() * 0.01:
				erros.append("caixa mudou %s -> %s" % [ca.size, cd.size])
			if (ca.position - cd.position).length() > ca.size.length() * 0.01:
				erros.append("base mudou")
			if antes.find_children("Colisao*", "MeshInstance3D", true, false).size() != depois.find_children("Colisao*", "MeshInstance3D", true, false).size():
				erros.append("malhas de colisão diferentes")
			if antes.find_children("Fruta_*", "Node3D", true, false).size() != depois.find_children("Fruta_*", "Node3D", true, false).size():
				erros.append("pontos de fruta diferentes")
			if FileAccess.get_sha256(bib.caminho_do_arquivo(id)) != str(bib.info(id)["sha256"]):
				erros.append("sha do catálogo não bate")
			if int(md["triangulos"]) != int(bib.info(id)["triangulos"]) or int(md["triangulos"]) > MAX_TRIANGULOS:
				erros.append("triângulos %d (catálogo %d)" % [md["triangulos"], bib.info(id)["triangulos"]])
			tri_max = maxi(tri_max, int(md["triangulos"]))
			var tem_voxel := false
			for mi in depois.find_children("*", "MeshInstance3D", true, false):
				if not BibliotecaDeModelos.e_malha_de_colisao(mi) and (mi as MeshInstance3D).mesh.get_surface_count() >= 1:
					tem_voxel = true
					var m: Mesh = (mi as MeshInstance3D).mesh
					# Face frontal no Godot = ordem horária: o produto vetorial contra a normal.
					var ruins := ArvoreVoxel.faces_invertidas(m)
					if ruins > 0:
						erros.append("%d triângulos com a face para dentro" % ruins)
					for s in m.get_surface_count():
						if not (m.surface_get_material(s) is StandardMaterial3D):
							erros.append("superfície %d sem material" % s)
			if not tem_voxel:
				erros.append("sem malha visual")
			if bib.modo_de_colisao(id) == "partes" and bib.partes_de_colisao(id).is_empty():
				erros.append("colisão em partes inválida (sha)")
		if antes != null: antes.free()
		if depois != null: depois.free()
		if not erros.is_empty():
			falhas += 1
			print("FALHA ", id, ": ", "; ".join(erros))
	if n < 50:
		falhas += 1
		print("FALHA: só %d modelos com backup (esperava ~58)" % n)
	print("%d modelos | maior malha %d triângulos | %s" % [n, tri_max, "OK" if falhas == 0 else "%d falhas" % falhas])
	quit(falhas)
