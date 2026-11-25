extends SceneTree
# Captura (com GPU) do `entity_impact` — a entidade INVISÍVEL do mod: o que se vê são só as partículas que a IA dela solta
# (círculo de nuvem + faíscas). Dois impactos: força baixa e alta (a força vem do yRot, como no mod).
#
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_impacto_mine_piece.gd -- <pasta>

var saida := "/tmp/impacto_mp"
var cam: Camera3D


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
	modo.set("progresso_forcado", "user://captura_impacto_mp.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.global_position = Vector3(0, 1, 9)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	var ref := PersonagemMinePiece.new()
	ref.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	ref.position = Vector3(0, 1, 0)
	ref.ponto_de_origem = ref.position
	ref.set_meta("mc_sem_ia", true)
	current_scene.add_child(ref)
	await quadros(10)
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 45
	cam.current = true
	cam.global_position = Vector3(0, 2.4, -6.5)
	cam.look_at(Vector3(0, 0.8, 0), Vector3.UP)
	var mundo := Mc.mundo(self)
	var i := 0
	for forca_yrot in [60.0, 400.0]:             # power = ∛(max(yRot − 50, 0)): 2,2 e 7,0 (teto 10)
		var e: McEntidade = Mc.tipo_entidade(&"minepiece:entity_impact").create(mundo, null, null, McVec3.de(0.0, 1.0 / 0.88, -1.5))
		e.setYRot(forca_yrot)
		for t in [2, 4, 8]:
			await quadros(2 if t == 2 else 3 if t == 4 else 5)
			await foto("%d_t%d" % [i, t])
		await quadros(60)
		i += 1
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
