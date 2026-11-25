extends SceneTree
## Lista todas as Akuma no Mi do jogo (definições da arena + Mine Piece + só-do-mod) e grava
## `art_src/akuma_no_mi/manifesto.json`: id, nome, cores do pickup atual, de onde vem, se há modelo próprio.
##   "$(./find_godot.sh)" --headless --path . --script tools/akuma_no_mi/listar_frutas.gd
func _init() -> void:
	var por_id := {}
	for d in TreeAndFruitGenerator._todas_as_definicoes():
		var id := str(d.get("id", ""))
		if id == "" or id == "sem_fruta":
			continue
		por_id[id] = {"id": id, "origem": "arena", "cor": (d.get("fruit_color", Color.WHITE) as Color).to_html(false),
			"brilho": (d.get("fruit_glow", Color.WHITE) as Color).to_html(false)}
	for d in TreeAndFruitGenerator._DEFINICOES_MINE_PIECE:
		var id := str(d.get("id", ""))
		if not por_id.has(id):
			por_id[id] = {"id": id, "origem": "mine_piece", "cor": (d.get("fruit_color", Color.WHITE) as Color).to_html(false),
				"brilho": (d.get("fruit_glow", Color.WHITE) as Color).to_html(false)}
	for id in PerfilDeFrutas.frutas_so_do_mod():
		if not por_id.has(str(id)):
			por_id[str(id)] = {"id": str(id), "origem": "so_do_mod", "cor": "#ff7f50", "brilho": "#ffffff"}
	for id in SkillSystem.get_fruit_skills():
		if not por_id.has(str(id)):
			por_id[str(id)] = {"id": str(id), "origem": "skills", "cor": "#ff7f50", "brilho": "#ffffff"}
	for id in CatalogoFrutasMinePiece.FICHAS:
		if not por_id.has(str(id)) and str(id) != "estilo_de_combate_base":
			por_id[str(id)] = {"id": str(id), "origem": "catalogo", "cor": "#ff7f50", "brilho": "#ffffff"}
	# variantes viram alias da fruta base (um modelo só por fruta)
	var canonicas := {}
	for id in por_id:
		var base := TreeAndFruitGenerator.id_do_modelo(id)
		if not canonicas.has(base):
			canonicas[base] = por_id.get(base, {"id": base, "origem": "base", "cor": por_id[id]["cor"], "brilho": por_id[id]["brilho"]})
			canonicas[base]["aliases"] = []
		if base != id:
			canonicas[base]["aliases"].append(id)
	por_id = canonicas
	var lista := []
	var ids := por_id.keys()
	ids.sort()
	for id in ids:
		var f: Dictionary = por_id[id]
		f["nome"] = PerfilDeFrutas.nome_da_fruta(id)
		f["modelo_proprio"] = ResourceLoader.exists("res://assets/models/akuma_no_mi/%s.glb" % id)
		lista.append(f)
	var arq := FileAccess.open("res://art_src/akuma_no_mi/manifesto.json", FileAccess.WRITE)
	arq.store_string(JSON.stringify({"frutas": lista}, "  "))
	print("FRUTAS ", lista.size())
	quit(0)
