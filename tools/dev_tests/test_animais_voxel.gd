extends SceneTree
## Animais voxel (tools/voxelizar_animais.gd): `instanciar` entrega a malha de cubos (cor por
## vértice, osso por vértice quando o original tinha esqueleto), com o MESMO esqueleto/Skin/
## AnimationPlayer do .glb, caixa próxima da original, sem as bestas do mar.
## godot --headless --path . --script tools/dev_tests/test_animais_voxel.gd

const MAX_TRIANGULOS := 60000
const EXTRAS := ["animals__farm__horse_1__base", "cavalo_da_vila_leve"]

func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var falhas := 0
	var n := 0
	var tri_max := 0
	for id in bib.ids():
		var info := bib.info(id)
		var e_animal: bool = info.has("animal") or EXTRAS.has(id)
		var e_besta: bool = (info.get("categorias", []) as Array).has("bestas_do_mar")
		var arquivo := ProjectSettings.globalize_path(bib.caminho_do_arquivo(id)).get_basename() + ".voxel.scn"
		# 18/11/2026: as bestas do mar também são voxel (antes ficavam de fora); passam pelas mesmas checagens dos animais.
		if not (e_animal or e_besta):
			continue
		n += 1
		var erros: Array[String] = []
		if not FileAccess.file_exists(arquivo):
			erros.append("sem .voxel.scn")
		else:
			var orig := BibliotecaDeModelos.carregar_glb(bib.caminho_do_arquivo(id))
			var vox := bib.instanciar(id)
			var ca: AABB = BibliotecaDeModelos.medir(orig)["aabb"]
			var cv: AABB = BibliotecaDeModelos.medir(vox)["aabb"]
			if (ca.size - cv.size).length() > ca.size.length() * 0.15:
				erros.append("caixa %s -> %s" % [ca.size, cv.size])
			var esq_o := orig.find_children("*", "Skeleton3D", true, false).size()
			var esq_v := vox.find_children("*", "Skeleton3D", true, false).size()
			var ap_o := orig.find_children("*", "AnimationPlayer", true, false).size()
			var ap_v := vox.find_children("*", "AnimationPlayer", true, false).size()
			if esq_o != esq_v or ap_o != ap_v:
				erros.append("esqueleto/animação mudaram")
			for mi: MeshInstance3D in vox.find_children("*", "MeshInstance3D", true, false):
				if BibliotecaDeModelos.e_malha_de_colisao(mi) or mi.mesh == null:
					continue
				var arr := mi.mesh.surface_get_arrays(0)
				if arr[Mesh.ARRAY_COLOR] == null:
					erros.append("%s sem cor por vértice" % mi.name)
				if mi.skin != null and arr[Mesh.ARRAY_BONES] == null:
					erros.append("%s tinha esqueleto e perdeu os ossos" % mi.name)
				var tri: int = mi.mesh.get_faces().size() / 3
				tri_max = maxi(tri_max, tri)
				if tri > MAX_TRIANGULOS:
					erros.append("%s com %d triângulos" % [mi.name, tri])
			orig.free()
			vox.free()
		if not erros.is_empty():
			falhas += 1
			print("FALHA ", id, ": ", "; ".join(erros))
	if n < 30:
		falhas += 1
		print("FALHA: só %d animais (esperava 32)" % n)
	print("%d animais | maior malha %d triângulos | %s" % [n, tri_max, "OK" if falhas == 0 else "%d falhas" % falhas])
	quit(falhas)
