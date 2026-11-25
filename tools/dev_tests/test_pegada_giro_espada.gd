extends SceneTree
## Mede os encaixes autorais das DUAS palmas no cabo real, durante voltas completas.
const PASTA := "res://art_src/validation/espada_historia_2026-10-07/duas_maos"
var falhas := 0
var total := 0
var tela := false
var antes := false

func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func verificar(sim: bool, msg: String) -> void:
	total += 1
	falhas += 0 if sim else 1
	print(("OK " if sim else "FALHA ") + msg)

func rodar() -> void:
	await process_frame
	tela = OS.get_cmdline_user_args().has("--tela")
	antes = OS.get_cmdline_user_args().has("--antes")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_pegada_giro.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pegada_giro.json"))
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: Node = get_first_node_in_group("player")
	current_scene.progressao.equipamentos["espada"] = 1      # a espada inicial saiu do kit (só as lâminas do Epic Fight)
	current_scene.progressao.equipar_espada(true)
	await quadros(20)
	var arma: Node = jogador.get_node("EspadaDaHistoria")
	var giro: Node = arma.giro
	giro.ligado = true
	var visual: Node3D = arma.get("_visual")
	var modelo: Node3D = jogador.modelo_visual()
	var direita: Node3D = modelo.find_child("Weapon_R", true, false)
	var esquerda: Node3D = modelo.find_child("Weapon_L", true, false)
	verificar(direita != null and esquerda != null, "rig tem encaixes nas duas palmas")
	if direita == null or esquerda == null:
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var camera: Camera3D
	if tela:
		camera = Camera3D.new()
		current_scene.add_child(camera)
		camera.fov = 38
		camera.current = true
	var erro_direita := 0.0
	var erro_esquerda := 0.0
	var raio_max := 0.0
	var amostras := []
	verificar(giro.alternar(), "giro começa")
	await quadros(20)
	for i in 90:
		await quadros(1)
		var r := visual.to_local(direita.global_position)
		var l := visual.to_local(esquerda.global_position)
		erro_direita = maxf(erro_direita, r.length())
		erro_esquerda = maxf(erro_esquerda, l.distance_to(Vector3(0, -.15, 0)))
		raio_max = maxf(raio_max, Vector2(l.x, l.z).length())
		if i in [0, 15, 30, 45]:
			amostras.append({"tick": i, "direita": str(r), "esquerda": str(l)})
			if tela:
				var centro := direita.global_position.lerp(esquerda.global_position, .5)
				camera.global_position = centro + modelo.global_basis.orthonormalized() * Vector3(1.8, 1.1, -3.0)
				camera.look_at(centro + Vector3.UP * .12)
				# Um único quadro físico estável para comparar antes/depois da pegada.
				giro.set_physics_process(false)
				jogador.set_physics_process(false)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(PASTA + ("/antes_" if antes else "/depois_") + str(i) + ".png")
				jogador.set_physics_process(true)
				giro.set_physics_process(true)
	verificar(erro_direita < .015, "mão direita no cabo: erro máximo %.4f m" % erro_direita)
	verificar(erro_esquerda < .02, "mão esquerda 15 cm abaixo da direita: erro máximo %.4f m" % erro_esquerda)
	verificar(raio_max < .02, "mão esquerda alinhada ao eixo do cabo: desvio %.4f m" % raio_max)
	var arquivo := FileAccess.open(PASTA + ("/antes.json" if antes else "/depois.json"), FileAccess.WRITE)
	arquivo.store_string(JSON.stringify({"erro_direita": erro_direita, "erro_esquerda": erro_esquerda, "radial": raio_max, "amostras": amostras}, "\t"))
	arquivo.close()
	giro.encerrar()
	await quadros(20)
	verificar(not jogador.has_meta("giro_espada_ativo"), "encerrar limpa estado da técnica")
	verificar(jogador.combate_direcional.pedir_ataque(0), "ataque normal funciona depois")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_pegada_giro.json"))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	print("PEGADA GIRO: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
