extends SceneTree
# Captura (com GPU) dos modelos GeckoLib das entidades de efeito do mod (tornado, zeus, bola de gelo…), em fila, sem a IA
# (parados no ciclo base). Uma foto com todos de frente e uma com os 4 primeiros em animação (0,5 s depois).
#
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_modelos_efeito_mine_piece.gd -- <pasta>

const IDS := ["tornado", "entity_bird", "entity_ice_ball", "entity_zeus", "entity_negative_hollow", "entity_haoshoku_haki_2",
		"entity_partisan", "entity_prometheus"]
var saida := "/tmp/modelos_efeito_mp"
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
	modo.set("progresso_forcado", "user://captura_modelos_mp.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.global_position = Vector3(0, 1, 30)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 60
	cam.current = true
	var mundo := Mc.mundo(self)
	var corpos := []
	for i in IDS.size():
		var x := (i - (IDS.size() - 1) / 2.0) * 7.0
		var e: McEntidade = Mc.tipo_entidade(StringName("minepiece:" + IDS[i])).create(mundo, null, null, McVec3.de(x / 0.88, 1.0 / 0.88, 0.0))
		var c := e.no as Node3D
		var ia := c.get_node_or_null("IaDoMod")
		if ia != null:
			ia.process_mode = Node.PROCESS_MODE_DISABLED
		c.set_physics_process(false)
		corpos.append(c)
		print("%-24s desenho=%s  clipes=%s" % [IDS[i], c.get("_desenho"), _clipes(c)])
	cam.global_position = Vector3(0, 4.5, -26)
	cam.look_at(Vector3(0, 2.0, 0), Vector3.UP)
	await quadros(30)
	await foto("fila_t0")
	await quadros(15)
	await foto("fila_t1")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()


func _clipes(c: Node) -> Array:
	var ap := c.find_child("AnimationPlayer", true, false) as AnimationPlayer
	return Array(ap.get_animation_list()) if ap != null else []
