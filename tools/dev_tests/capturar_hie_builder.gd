extends SceneTree
# ============================================================================
#  HIE REFEITA — o Z novo ("Espinhos de Gelo") em fotos com GPU (07/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_hie_builder.gd -- <pasta>
#
#    z_1_cristais   os cristais se juntando entre as mãos, antes da 1ª salva
#    z_2_salva      o leque de 8 estacas saindo entre as mãos
#    z_3_congelado  o boneco preso no bloco de gelo
#    z_4_recuo      o recuo, com o anel de gelo no chão onde começou
#  Câmera do JOGO e uma lateral. Mapa e progresso de TESTE; a Hie é a publicada.
# ============================================================================

var saida := ""
var p: Node3D
var lateral: Camera3D
var cam_jogo: Camera3D


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	saida = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1600, 900)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://capturar_hie_builder.json"))
	modo.set("progresso_forcado", "user://capturar_hie_builder.json")
	root.get_node("GameFlow").start_story()
	await _quadros(150)
	p = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("hie_hie")
	await _quadros(30)
	cam_jogo = p.get("_cam")
	lateral = Camera3D.new()
	current_scene.add_child(lateral)
	var b := BonecoDeDuelo.new()
	b.position = Vector3(0, 1, -9)
	current_scene.add_child(b)
	p.global_position = Vector3(0, 0.8, 0)
	await _quadros(20)
	b.call("parar")
	for i in 30:
		var d := (b.global_position + Vector3.UP * 0.4 - cam_jogo.global_position).normalized()
		p.set("_yaw", atan2(-d.x, -d.z))
		p.set("_pitch", asin(clampf(d.y, -1.0, 1.0)))
		p.call("_update_pivot")
		await process_frame
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	await _quadros(18)
	_olhar(p.global_position + Vector3(2.6, 1.6, -1.6), p.global_position + Vector3(0, 1.3, -0.6))
	await _duas("z_1_cristais")
	await _quadros(8)
	_olhar(Vector3(7.0, 3.0, -3.0), Vector3(0.0, 1.2, -5.0))
	await _duas("z_2_salva")
	for i in 30:
		await physics_frame
		if b.get_meta("is_frozen", false):
			break
	await _quadros(16)                 # o bloco cresce em 0,15 s e o estouro apaga
	_olhar(b.global_position + Vector3(3.5, 1.2, 3.0), b.global_position)
	await _duas("z_3_congelado")
	await _quadros(20)
	_olhar(Vector3(9.0, 4.0, 3.0), Vector3(0.0, 0.5, 3.5))
	await _duas("z_4_recuo")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("fotos em ", saida)
	quit(0)


func _olhar(de: Vector3, para: Vector3) -> void:
	lateral.global_position = de
	lateral.look_at(para)


func _duas(nome: String) -> void:
	await _foto(cam_jogo, nome + "_jogo")
	await _foto(lateral, nome + "_lado")


func _foto(cam: Camera3D, nome: String) -> void:
	cam.make_current()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
