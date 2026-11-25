extends SceneTree
## Quadros do Z (arremesso) e do X (corte lançado) do machado, para olhar a pose e o voo.
##   DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_machado.gd -- x   (ou sem argumento: Z)
const SAIDA := "res://art_src/validation/machado/"  # antes: mkdir -p art_src/validation/machado
var p
func frames(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: _r.call_deferred()
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA + nome + ".png")
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://cap_skills.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cap_skills.json"))
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	var prog = current_scene.progressao
	prog.ganhar_equipamento("machado"); prog.machado_equipado = true
	prog.ativar_item("machado")
	await frames(30)
	var arma = p.get_node("MachadoDaHistoria")
	var modo_x := OS.get_cmdline_user_args().has("x")
	var alvo := BonecoDeDuelo.new()
	alvo.vida_maxima = 30.0
	alvo.position = Vector3(0, 1, -7.5)
	current_scene.add_child(alvo)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.make_current()
	var centro: Vector3 = p.global_position + Vector3.UP * 0.9
	cam.global_position = centro + Vector3(3.2, 1.6, 2.4)
	cam.look_at(centro + Vector3(0, 0, -3.0))
	cam.fov = 55
	await frames(30)
	if modo_x:
		arma.habilidades.cortar()
	else:
		arma.habilidades.lancar()
	for i in 12:
		await frames(5)
		await foto("2_%02d" % i)
	quit()
