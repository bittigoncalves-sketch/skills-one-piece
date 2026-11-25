extends SceneTree
# ============================================================================
#  SERPENTE ANIME x REFERÊNCIA — prova visual lado a lado (02/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/capturar_serpente_anime.gd -- [<referencia.webp|png>]
#
#  Pedido do dono: a cabeça da besta do mar serpente refeita no estilo do anime, o mais
#  parecida possível com ~/Downloads/seaserpent.webp. Monta o modelo da LOJA (o mesmo que
#  o jogo usa, com o toon + contorno da importação), céu azul e luz de frente como no
#  quadro do anime, e grava em art_src/validation/bestas_mar/anime/:
#    • comparacao.png — referência | Godot no mesmo enquadramento 3/4 | lado | corpo;
#    • ameaca.png     — boca fechada e aberta (clipe "ameaca").
#  Só lê a loja; não grava mapa nem catálogo.
# ============================================================================

const SAIDA := "res://art_src/validation/bestas_mar/anime"
const REF_PADRAO := "~/Downloads/seaserpent.webp"
const ALTURA := 664              # altura da referência (359 x 664)

var _cam: Camera3D
var _modelo: Node3D


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	var args := OS.get_cmdline_user_args()
	var ref := _carregar_ref(args[0] if not args.is_empty() else REF_PADRAO)
	if ref == null:
		push_error("referência não encontrada")
		quit(1)
		return
	_palco()
	_modelo = BibliotecaDeModelos.padrao().instanciar("besta_mar_serpente")
	root.add_child(_modelo)
	var ap := _modelo.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	_pose(ap, "repouso", 0.0)
	# Mesmo ângulo do quadro do anime: a cabeça vista ~30° de frente, um pouco de cima.
	var quadro := await _foto(Vector2i(ref.get_width(), ref.get_height()), Vector3(-0.85, 0.32, -1.0), 23.0, Vector3(0, 14.4, -2.5))
	var lado := await _foto(Vector2i(ALTURA / 2, ALTURA / 2), Vector3(-1, 0.05, 0), 26.0, Vector3(0, 12.6, -0.5))
	var corpo := await _foto(Vector2i(ALTURA / 2, ALTURA / 2), Vector3(-0.8, 0.25, -1.0), 48.0, Vector3(0, 8.0, 1.0))
	var folha := Image.create(ref.get_width() * 2 + ALTURA / 2, ALTURA, false, Image.FORMAT_RGBA8)
	folha.fill(Color.WHITE)
	folha.blit_rect(ref, Rect2i(Vector2i.ZERO, ref.get_size()), Vector2i.ZERO)
	folha.blit_rect(quadro, Rect2i(Vector2i.ZERO, quadro.get_size()), Vector2i(ref.get_width(), 0))
	folha.blit_rect(lado, Rect2i(Vector2i.ZERO, lado.get_size()), Vector2i(ref.get_width() * 2, 0))
	folha.blit_rect(corpo, Rect2i(Vector2i.ZERO, corpo.get_size()), Vector2i(ref.get_width() * 2, ALTURA / 2))
	folha.save_png(ProjectSettings.globalize_path(SAIDA.path_join("comparacao.png")))
	var fechada := await _foto(Vector2i(ALTURA / 2, ALTURA / 2), Vector3(-1, 0.05, 0), 26.0, Vector3(0, 12.6, -0.5))
	_pose(ap, "ameaca", 1.7)
	var aberta := await _foto(Vector2i(ALTURA / 2, ALTURA / 2), Vector3(-1, 0.05, 0), 26.0, Vector3(0, 12.6, -0.5))
	var dupla := Image.create(ALTURA, ALTURA / 2, false, Image.FORMAT_RGBA8)
	dupla.blit_rect(fechada, Rect2i(Vector2i.ZERO, fechada.get_size()), Vector2i.ZERO)
	dupla.blit_rect(aberta, Rect2i(Vector2i.ZERO, aberta.get_size()), Vector2i(ALTURA / 2, 0))
	dupla.save_png(ProjectSettings.globalize_path(SAIDA.path_join("ameaca.png")))
	print("SERPENTE_ANIME fotos em ", SAIDA)
	quit()


func _carregar_ref(caminho: String) -> Image:
	caminho = caminho.replace("~", OS.get_environment("HOME"))
	var dados := FileAccess.get_file_as_bytes(caminho)
	if dados.is_empty():
		return null
	var img := Image.new()
	var erro := img.load_webp_from_buffer(dados) if caminho.get_extension().to_lower() == "webp" else img.load_png_from_buffer(dados)
	if erro != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


func _palco() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.55, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-35, -40, 0)
	sol.light_energy = 1.3
	sol.shadow_enabled = true
	root.add_child(sol)
	_cam = Camera3D.new()
	_cam.fov = 40
	root.add_child(_cam)
	_cam.make_current()


func _pose(ap: AnimationPlayer, clipe: String, t: float) -> void:
	for nome in ap.get_animation_list():
		if String(nome).ends_with(clipe):
			ap.play(nome)
			ap.seek(t, true)
			ap.pause()


## Câmera em `alvo + dir * dist` olhando o alvo; devolve a imagem do tamanho pedido.
func _foto(tam: Vector2i, dir: Vector3, dist: float, alvo: Vector3) -> Image:
	root.size = tam
	_cam.position = alvo + dir.normalized() * dist
	_cam.look_at(alvo)
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img
