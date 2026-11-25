extends SceneTree
## Renderiza os modelos já usados no jogo. Fonte das imagens da loja (128 px).
## Godot --path . --script tools/gerar_imagens_frutas.gd [-- <id> ...] (precisa de renderização).
## Com ids, refaz só esses (17/10/2026: as frutas "(Mine Piece)" sem mexer nas outras).
func _init() -> void: gerar.call_deferred()

func gerar() -> void:
	await process_frame
	var gerador := GeradorDeMiniaturas.new()
	root.add_child(gerador)
	var definicoes := {}
	for d in TreeAndFruitGenerator._todas_as_definicoes(): definicoes[d.id] = d
	var ids := PerfilDeFrutas.frutas_a_venda()
	var pedidos := OS.get_cmdline_user_args()
	if not pedidos.is_empty():
		ids = ids.filter(func(i: String) -> bool: return pedidos.has(i))
	ids.sort()
	for id in ids:
		if id == KitDoBuilder.ID: continue
		# Fruta "(Mine Piece)" (17/10/2026): o desenho da fruta original que ela estuda.
		var def: Dictionary = definicoes.get(id, definicoes.get(id.trim_suffix("_no_mi_mine_piece"), {}))
		if def.is_empty():
			var cor := Color(str(SkillsPublicadas.fruta(id).get("cor", "#b073d9")))
			def = {"id": id, "fruit_color": cor, "fruit_glow": cor.lightened(0.15)}
		var modelo := TreeAndFruitGenerator.create_fruit_3d(def)
		root.add_child(modelo)
		modelo.process_mode = Node.PROCESS_MODE_DISABLED
		var caixa := AABB()
		var achou := false
		for malha: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
			if malha.mesh == null: continue
			var t: Transform3D = modelo.global_transform.affine_inverse() * malha.global_transform
			var parte: AABB = t * malha.get_aabb()
			caixa = caixa.merge(parte) if achou else parte
			achou = true
		root.remove_child(modelo)
		var foto := await gerador.fotografar_cena(modelo, caixa.get_center(), caixa.size.length() * 0.5,
			"res://assets/ui/frutas/%s.png" % id, Vector3(1, 0.6, 1))
		if foto == null:
			push_error("Sem imagem para " + id)
			quit(1)
			return
		if id.ends_with("_no_mi_mine_piece"):
			_selo_mine_piece("res://assets/ui/frutas/%s.png" % id)
		print("IMAGEM: " + id)
	quit()


## Selo das frutas "(Mine Piece)": losango vermelho de borda branca no canto inferior
## direito, para não ficarem iguais à fruta original na loja.
func _selo_mine_piece(caminho: String) -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(caminho))
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	var centro := Vector2i(img.get_width() - 22, img.get_height() - 22)
	for y in range(-17, 18):
		for x in range(-17, 18):
			var d := absi(x) + absi(y)
			if d <= 17:
				img.set_pixel(centro.x + x, centro.y + y, Color("#ffffff") if d > 13 else Color("#e0182d"))
	img.save_png(ProjectSettings.globalize_path(caminho))
