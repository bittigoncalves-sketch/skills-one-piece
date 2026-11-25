extends SceneTree
const Tons := preload("res://src/player/tons_de_pele.gd")
const Corpo := preload("res://src/player/corpo_historia.gd")
const Tela := preload("res://src/ui/escolha_corpo_historia.gd")
const PASTA := "res://art_src/validation/tons_de_pele/"
var falhas := 0
var checks := 0


func _init() -> void:
	executar.call_deferred()


func executar() -> void:
	var antigo := ProgressaoDoPersonagem.new().para_dict()
	antigo.erase("tom_de_pele")
	antigo["nivel"] = 17
	antigo["corpo"] = "feminino"
	var migrado := ProgressaoDoPersonagem.de_dict(antigo)
	ok(migrado.tom_de_pele == "medio" and migrado.nivel == 17 and migrado.corpo == "feminino", "save antigo mantém aparência e progresso")
	for invalido: Variant in [null, [], {}, 5, "outro", "../fora"]:
		antigo["tom_de_pele"] = invalido
		ok(ProgressaoDoPersonagem.de_dict(antigo).tom_de_pele == "medio", "tom inválido tem fallback seguro")
	var tela := Tela.new()
	root.add_child(tela)
	# Inclui a normalização global da GUI, que roda após três quadros.
	for i in 5: await process_frame
	ok(tela._entrar.disabled, "editor novo exige escolher sexo")
	for id: String in Tons.CATALOGO.data:
		(tela.find_child("Tom_" + id, true, false) as Button).pressed.emit()
		ok(tela.tom_de_pele == id, id + ": tom selecionado")
		var botao := tela.find_child("Tom_" + id, true, false) as Button
		var amostra := botao.get_node("BordaTom/Amostra") as ColorRect
		ok(amostra.color.is_equal_approx(Color(Tons.CATALOGO.data[id].pele)) and amostra.mouse_filter == Control.MOUSE_FILTER_IGNORE, "amostra mantém cor e permite clique após normalização")
		for tipo: String in Corpo.TIPOS:
			(tela.find_child(tipo.capitalize(), true, false) as Button).pressed.emit()
			var modelo: Node3D = tela._previa.modelo
			ok(modelo.get_meta("tom_de_pele") == id, tipo + "/" + id + ": prévia troca o tom")
			var cabeca := modelo.find_child("Cabeca", true, false) as MeshInstance3D
			var tex: Texture2D = cabeca.material_override.albedo_texture
			ok(tex != null and tex.get_size() == Vector2(384, 512), "atlas importado com tamanho correto")
			if tex:
				var img := tex.get_image()
				ok(img.get_pixel(32, 470).is_equal_approx(Color(Tons.CATALOGO.data[id].pele)), "paleta aplicada na pele")
				ok(img.get_pixel(32, 280).is_equal_approx(Color("2d475f")), "calça não foi tingida")
			for parte: String in ["Peito", "Abdomen", "Braco", "Geo_Palm_R_Runtime"]:
				var mesh := modelo.find_child(parte, true, false) as MeshInstance3D
				ok(mesh.material_override.albedo_texture == tex, parte + ": mesmo atlas do rosto")
			var prog := ProgressaoDoPersonagem.new()
			prog.corpo = tipo
			prog.tom_de_pele = id
			var salvo := ProgressaoDoPersonagem.de_dict(prog.para_dict())
			ok(salvo.corpo == tipo and salvo.tom_de_pele == id, "roundtrip de " + tipo + "/" + id)
		await process_frame
		if "--capturar" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			ok(root.get_texture().get_image().save_png(PASTA + "selecao_" + id + ".png") == OK, "captura " + id)
	tela.queue_free()
	await process_frame
	print("TONS DE PELE: %d/%d verificações passaram" % [checks - falhas, checks])
	quit(1 if falhas else 0)


func ok(sim: bool, texto: String) -> void:
	checks += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + texto)
