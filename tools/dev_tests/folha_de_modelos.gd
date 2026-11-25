extends SceneTree
## Folha de contato dos modelos (auditoria visual): enfileira os `ids` num fundo neutro, câmera de frente, e grava o PNG.
##   MODELOS=mp_buggy,mp_alvida SAIDA=/tmp/folha.png godot --path . --resolution 1600x500 --script tools/dev_tests/folha_de_modelos.gd
## Mostra o modelo como a biblioteca o instancia (inclui a troca por malha voxel dos animais). Só serve para olhar; não valida nada.
func _init() -> void: _r.call_deferred()
func _r() -> void:
	await process_frame
	var ids := OS.get_environment("MODELOS").split(",", false)
	var bib := BibliotecaDeModelos.padrao()
	var raiz := Node3D.new()
	root.add_child(raiz)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-35, 25, 0)
	raiz.add_child(luz)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.45, 0.5)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.75)
	amb.environment = env
	raiz.add_child(amb)
	var x := 0.0
	var alt := 0.0
	var colunas := int(OS.get_environment("COLUNAS")) if OS.get_environment("COLUNAS") != "" else ids.size()
	var i := 0
	var passo := 0.0
	var instancias: Array = []
	for id in ids:
		var m: Node3D = bib.instanciar(id) if bib.tem(id) else null
		if m == null:
			print("sem modelo: ", id)
			continue
		load("res://src/historia/east_blue/uniformes_faccoes.gd").aplicar(m, id)     # a mesma pele/uniforme que o jogo põe
		instancias.append(m)
		var tam := bib.tamanho_padrao(id) if bib.tem(id) else Vector3.ONE
		passo = maxf(passo, maxf(tam.x, tam.z) * 1.25)
		alt = maxf(alt, tam.y)
	for m in instancias:
		raiz.add_child(m)
		m.position = Vector3((i % colunas) * passo, -(i / colunas) * (alt * 1.15), 0)
		m.rotation.y = PI if OS.get_environment("COSTAS") == "" else 0.0
		i += 1
	var linhas := int(ceil(float(instancias.size()) / colunas))
	var cam := Camera3D.new()
	raiz.add_child(cam)
	var larg := (colunas - 1) * passo
	var cx := larg * 0.5
	var cy := alt * 0.5 - (linhas - 1) * alt * 0.575
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(larg + passo, (alt * 1.15 * linhas) * (float(get_root().size.x) / get_root().size.y))
	cam.size = maxf((larg + passo) / (float(get_root().size.x) / get_root().size.y), alt * 1.15 * linhas)
	cam.position = Vector3(cx, cy, 20)
	cam.make_current()
	for k in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("SAIDA"))
	quit()
