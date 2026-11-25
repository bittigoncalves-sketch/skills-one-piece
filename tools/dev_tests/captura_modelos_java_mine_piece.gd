extends SceneTree
# Modelos Java escritos à mão (tree_root, entity_ball): verifica faltas e tira foto.
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_modelos_java_mine_piece.gd -- <pasta>
var saida := "/tmp/java_mp"

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
	modo.set("progresso_forcado", "user://captura_java.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador = get_first_node_in_group("player")
	jogador.global_position = Vector3(0, 1, 12)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	var ref := PersonagemMinePiece.new()
	ref.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	ref.position = Vector3(-3.0, 1, 0)
	ref.ponto_de_origem = ref.position
	ref.set_meta("mc_sem_ia", true)
	ref.set_meta("damage_immune", true)
	current_scene.add_child(ref)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 50
	cam.current = true
	cam.global_position = Vector3(0, 2.2, -7)
	cam.look_at(Vector3(0, 1.2, 0), Vector3.UP)
	var mundo: McMundo = McEntidade.de(ref).level()
	Mc.pedidos_sem_implementacao.clear()
	var x := -1.0
	for id in ["tree_root", "entity_ball"]:
		var e = Mc.tipo_entidade(StringName("minepiece:" + id)).create(mundo)
		e.moveTo(McVec3.de(x / MundoMinePiece.METROS_POR_BLOCO, 1.0 / MundoMinePiece.METROS_POR_BLOCO, 0.0))
		mundo.addFreshEntity(e)
		var d: Node3D = e.no.get_node_or_null("Desenho")
		var aabb := AABB()
		if d is MeshInstance3D:
			aabb = (d as MeshInstance3D).get_aabb()
		print("MODELO %s: desenho=%s tamanho=%s" % [id, d != null, aabb.size])
		x += 2.5
	await quadros(5)
	print("PEDIDOS: ", Mc.pedidos_sem_implementacao)
	await foto("modelos")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
