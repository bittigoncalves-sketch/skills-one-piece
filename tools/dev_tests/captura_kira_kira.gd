extends SceneTree
## Render real do personagem no Modo História: transformação e investida.
var jogador

class Alvo extends Node3D:
	var health := 1000.0
	func _ready() -> void:
		add_to_group(AlvosDeGolpe.GRUPO)
		var forma := CapsuleMesh.new()
		forma.radius = 0.35
		forma.height = 1.6
		var desenho := MeshInstance3D.new()
		desenho.mesh = forma
		add_child(desenho)
	func take_damage(valor: float, _origem: Vector3, _impulso: Vector3, _stun: float) -> void:
		health -= valor

func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		if is_instance_valid(jogador): jogador.capacidades.can_use_fruit = true
		await physics_frame
		await process_frame

func foto(nome: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(900, 650)
	vp.world_3d = jogador.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.49, 0.53)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.85
	camera.environment = env
	var base: Basis = jogador._char_model.global_basis.orthonormalized()
	var centro: Vector3 = jogador._char_model.global_position + Vector3.UP * 0.9
	camera.global_position = centro - base.z * 4.7 + base.x * 2.3 + Vector3.UP * 0.8
	camera.look_at(centro)
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var caminho := "/tmp/kira_" + nome + ".png"
	vp.get_texture().get_image().save_png(caminho)
	print("CAPTURA " + caminho)
	vp.queue_free()

func rodar() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://kira_codex_captura.json")
	root.get_node("GameFlow").start_story()
	await quadros(180)
	jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var prog = current_scene.get("progressao")
	prog.fruta = "kira_kira"
	prog.fruta_ativa = true
	prog.skills["fruta"] = 1
	prog.item_ativo = prog.NENHUM_ITEM
	modo.equipar_fruta(jogador, "kira_kira")
	await quadros(20)
	var c = jogador.get_node("FrutaMinePiece")
	jogador.max_energy = 2000.0
	jogador.energy = 2000.0
	await foto("normal")
	c.transformar(false)
	await quadros(15)
	await foto("transformada")
	c.transformar(false)
	await quadros(15)
	c.usar_tecla("Z", true)
	for i in 80:
		await physics_frame
		await process_frame
		if c.kira_investida.ativo and c.kira_investida.tempo > 0.2:
			break
	Engine.time_scale = 0.0001
	await foto("investida")
	var alvo := Alvo.new()
	current_scene.add_child(alvo)
	alvo.global_position = jogador.global_position + c.kira_investida.direcao * 2.5 + Vector3.UP * 0.9
	Engine.time_scale = 0.25
	for i in 120:
		await physics_frame
		await process_frame
		if not c.kira_investida.ativo: break
	var tempo := 0.0
	while tempo < 0.16:
		await physics_frame
		await process_frame
		tempo += 1.0 / 60.0
	Engine.time_scale = 0.0001
	await foto("explosao")
	Engine.time_scale = 1.0
	quit()
