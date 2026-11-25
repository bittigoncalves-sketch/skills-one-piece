extends SceneTree
## Captura GPU do mapa real (só leitura) e areia em instâncias temporárias.
## Não nasce jogador, não captura mouse e não grava mapa nem progresso.
const SAIDA := "res://art_src/validation/praia"
var oceano: Node3D
var mundo: Node3D
var camera: Camera3D

func _initialize() -> void:
	_executar.call_deferred()

func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Preview exige renderer real.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	mundo = Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var mapa: Dictionary = MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]
	MapaMontador.montar(mundo, mapa)
	camera = Camera3D.new()
	camera.far = 12000.0
	mundo.add_child(camera)
	camera.make_current()
	camera.position = Vector3(345, 75, -10)
	camera.look_at(Vector3(248, 0, -70))
	await _foto("01_antes.png")
	oceano = load("res://src/world/oceano_historia.gd").new()
	mundo.add_child(oceano)
	oceano.configurar(mapa)
	oceano.material.set_shader_parameter("tempo_fixo", 0.0)
	# Demonstra encaixe lateral de 3 módulos sem modificar o mapa do dono.
	for i in 3:
		var dados := {"id": "amostra_areia_%d" % i, "tipo": "modelo", "modelo": "areia_praia_low_poly",
			"posicao": Vector3(260, -0.3, -88 + i*32), "rotacao_graus": Vector3(0, 90, 0),
			"tamanho": Vector3(32, 1.8, 24), "cor": Color.WHITE, "material": "liso",
			"grade_celula": 4.0, "colisao": true}
		MapaMontador.montar_peca(mundo, dados)
	await _foto("02_praia_oceano.png")
	camera.position = Vector3(283, 9, -10)
	camera.look_at(Vector3(263, -0.4, -55))
	await _foto("03_areia_perto.png")
	camera.position = Vector3(268, 5, -70)
	camera.look_at(Vector3(370, -0.65, -105))
	await _foto("04_ondas_t0.png")
	oceano.material.set_shader_parameter("tempo_fixo", 2.0)
	await _foto("05_ondas_t2.png")
	if "--ondas" in OS.get_cmdline_user_args():
		await _filmar_ondas()
	print("PRAIA_PREVIEW_OK")
	quit()

func _foto(nome: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var imagem := root.get_texture().get_image()
	var erro := imagem.save_png(SAIDA.path_join(nome))
	print("FOTO ", nome, " erro=", erro)


func _filmar_ondas() -> void:
	var pasta := OS.get_environment("SOP_PRAIA_QUADROS")
	if pasta.is_empty():
		push_error("Defina SOP_PRAIA_QUADROS para a pasta temporária da animação.")
		return
	DirAccess.make_dir_recursive_absolute(pasta)
	root.size = Vector2i(960, 540)
	camera.position = Vector3(283, 5, -10)
	camera.look_at(Vector3(276, -0.4, -70))
	for i in 36:
		oceano.material.set_shader_parameter("tempo_fixo", float(i) / 12.0)
		for quadro in 2:
			await process_frame
		await RenderingServer.frame_post_draw
		var erro := root.get_texture().get_image().save_png(pasta.path_join("%03d.png" % i))
		if erro != OK:
			push_error("Falha ao gravar quadro %d" % i)
	print("ONDAS_36_QUADROS_OK")
