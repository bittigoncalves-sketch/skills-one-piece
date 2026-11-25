extends SceneTree
# Captura (com GPU) do relâmpago do Minecraft.  DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_raio_mine_piece.gd -- <pasta>
var saida := "/tmp/raio_mp"

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])

func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_raio.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador = get_first_node_in_group("player")
	jogador.global_position = Vector3(0, 1, 12)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	var ref := PersonagemMinePiece.new()
	ref.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	ref.position = Vector3(0, 1, 0)
	ref.ponto_de_origem = ref.position
	ref.set_meta("mc_sem_ia", true)
	ref.set_meta("damage_immune", true)
	current_scene.add_child(ref)
	await quadros(10)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 55
	cam.current = true
	cam.global_position = Vector3(0, 2.2, -9)
	cam.look_at(Vector3(0, 6.0, 0), Vector3.UP)
	var ent := McEntidade.de(ref)
	var raio = Mc.tipo_entidade(&"minecraft:lightning_bolt").create(ent.level())
	raio.moveTo(ent.position())
	ent.level().addFreshEntity(raio)
	await quadros(1)
	await foto("raio")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
