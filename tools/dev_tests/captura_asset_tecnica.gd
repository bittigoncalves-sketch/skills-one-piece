extends SceneTree
## Fotografa o asset 3D de uma técnica em voo (24/11/2026): equipa a fruta, solta a tecla e tira um quadro a cada `passo` quadros de física.
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . -s tools/dev_tests/captura_asset_tecnica.gd -- <pasta> <fruta> <tecla> [carga_quadros] [alvo_m]
var saida := "/tmp/asset_tecnica"
func q(n: int) -> void:
	for i in n: await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
func tecla(codigo: Key, apertou: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = apertou
	Input.parse_input_event(e)
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	saida = a[0]
	var fruta: String = a[1]
	var letra: String = a[2]
	var carga := int(a[3]) if a.size() > 3 else 12
	var dist := float(a[4]) if a.size() > 4 else 16.0
	DirAccess.make_dir_recursive_absolute(saida)
	MundoMinePiece.FATOR_DE_PROJETIL = 0.5   # o do jogo (projéteis a meia velocidade)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_asset_tecnica.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_asset_tecnica.json"))
	root.get_node("GameFlow").start_story()
	await q(150)
	var p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = p.global_position + Vector3(0, 0, -dist)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await q(10)
	var prog: ProgressaoDoPersonagem = current_scene.progressao
	prog.dar_fruta_de_teste(fruta, 1)
	prog.comer_fruta(fruta)
	await q(20)
	var avancos = McEntidade.de(p).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await q(10)
	p.max_energy = 100000.0
	p.energy = p.max_energy
	for _i in 4:
		var mira: Vector3 = alvo.global_position + Vector3.UP - p._cam.global_position
		p._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
		p._pitch = asin(mira.normalized().y)
		p._update_pivot()
		await q(3)
	var k := OS.find_keycode_from_string(letra)
	tecla(k, true)
	await q(carga)
	tecla(k, false)
	for i in 16:
		await q(3)
		await foto("%s_%s_%02d" % [fruta, letra, i])
	print("capturas em ", saida)
	quit()
