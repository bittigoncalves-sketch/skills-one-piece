extends SceneTree
# ============================================================================
#  NADO NO JOGO — o corpo nada para onde vai? (03/10/2026)
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_nado_frente.gd -- <pasta>
#
#  Relato do dono: "direção incorreta dos braços na animação de nadar". A braçada
#  isolada no animador está certa (medir_direcao_bracos.gd); aqui é o jogo inteiro:
#  física, teclas, água do mapa. Mede a frente do modelo contra a direção do nado
#  (W e D) e fotografa de lado. dot ≥ 0,95 = o corpo nada de frente.
# ============================================================================

var p: Node3D
var camera: Camera3D
var saida := ""
var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else ""
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_nado_frente.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	camera = Camera3D.new()
	current_scene.add_child(camera)
	camera.fov = 45
	for caso in [["W", KEY_W, Vector3.FORWARD], ["D", KEY_D, Vector3.RIGHT], ["S", KEY_S, Vector3.BACK]]:
		var nivel := AguaDoMundo.nivel_em(300, 0)
		p.global_position = Vector3(300, nivel - 0.4, 0)
		p.velocity = Vector3.ZERO
		p._yaw = 0.0
		for i in 90:
			await physics_frame
		# Chega à água vindo de OUTRA direção (o corpo olhando para trás): é o caso
		# que o rumo congelado da fatia 1 (02/10) estragava.
		p._loco_chao.rumo = PI
		p._char_model.rotation.y = PI
		_tecla(caso[1], true)
		for i in 60:
			await physics_frame
		var dir: Vector3 = caso[2]
		var frente: Vector3 = (-p._char_model.global_basis.z)
		frente = Vector3(frente.x, 0, frente.z).normalized()
		var v: Vector3 = Vector3(p.velocity.x, 0, p.velocity.z)
		print("   %s: modo=%s vel=%s frente do corpo=%s" % [caso[0], p.modo_na_agua, v, frente])
		_ok("nadando com %s o corpo olha para onde nada (dot %.3f)" % [caso[0], frente.dot(v.normalized())],
			p.modo_na_agua == "nadando" and frente.dot(v.normalized()) >= 0.95)
		if not saida.is_empty():
			camera.make_current()
			for k in 4:
				for i in 10:
					await physics_frame
				# De lado em relação ao NADO: a direção do nado fica à direita da foto.
				var lado := dir.cross(Vector3.UP).normalized()
				camera.global_position = p.global_position - lado * 3.4 + Vector3.UP * 1.2
				camera.look_at(p.global_position)
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(saida.path_join("jogo_%s_%d.png" % [caso[0], k]))
		_tecla(caso[1], false)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nNADO_JOGO %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)
