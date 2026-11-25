extends SceneTree
# ============================================================================
#  CAPTURA — encontro com besta navegando (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E5).
#  Precisa de GPU. Modo História, MAPA VIVO (só leitura), progresso de TESTE: bote no mar
#  aberto, leme assumido, encontro forçado. Fotos: aviso (redemoinho) e besta atacando.
#    "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_encontro.gd -- --rotulo=e5
# ============================================================================
const PROGRESSO := "user://capturar_encontro_progresso.json"
const PASTA := "res://art_src/validation/mar"
var rotulo := "e5"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rotulo="):
			rotulo = a.trim_prefix("--rotulo=")
	root.size = Vector2i(1280, 720)
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 200:
		await process_frame
	var j: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			j = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	j.set_meta("damage_immune", true)
	var nav: Node = current_scene.get("_navegacao")
	var prog: ProgressaoDoPersonagem = current_scene.get("progressao")
	var enc: Node3D = current_scene.get_node("Mar").get("encontros")
	enc.rng.seed = 5
	prog.ouro += 2
	prog.comprar_barco("small_ship", 1)
	nav.lancar("small_ship")
	var b: CharacterBody3D = nav.barco_do_jogador("small_ship")
	b.global_position = Vector3(700, AguaDoMundo.superficie_em(700, 30), 30)
	PhysicsServer3D.body_set_state(b.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, b.global_transform)
	j.global_position = (b.get("leme") as Node3D).global_position + Vector3.UP * 0.9
	for i in 5:
		await physics_frame
	nav.assumir(b)
	j.set("_yaw", b.global_rotation.y)
	j.set("_pitch", -0.18)
	enc.forcar()
	var ponto: Vector3 = enc.get("_ponto")
	var ate := ponto - j.global_position
	j.set("_yaw", atan2(-ate.x, -ate.z))
	j.set("_pitch", -0.32)
	j.call("_update_pivot")
	for i in 110:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _foto("aviso")
	for i in 400:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var besta: Node3D = enc.besta
	if is_instance_valid(besta):
		var para := besta.global_position - j.global_position
		j.set("_yaw", atan2(-para.x, -para.z))
		j.call("_update_pivot")
	for i in 30:
		await process_frame
	await _foto("ataque")
	print("ENCONTRO casco %.0f/%.0f besta %s" % [float(b.get("health")), float(b.get("max_health")), besta.get("especie") if is_instance_valid(besta) else "-"])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	quit()


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join("encontro_%s_%s.png" % [rotulo, nome])))
	print("ENCONTRO foto %s" % nome)
