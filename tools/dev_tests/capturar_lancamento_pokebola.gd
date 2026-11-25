extends SceneTree
## Fotografa o lançamento da pokébola (precisa de janela): puxando (braço para cima) e logo depois de soltar (braço à frente).
##   godot --path . --resolution 1280x720 --script res://tools/dev_tests/capturar_lancamento_pokebola.gd
const SAIDA := "/tmp/claude-1000/-home-gabriel-bitti-dev/e6059e18-2962-419b-9059-a5ecd1abfd33/scratchpad/"
func _init() -> void:
	call_deferred("_r")
func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA + nome)
func _r() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://captura_lanc.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_lanc.json"))
	root.get_node("GameFlow").start_story()
	var j: Node3D = null
	var limite := Time.get_ticks_msec() + 150000
	while j == null and Time.get_ticks_msec() < limite:
		await physics_frame
		j = get_first_node_in_group("player")
	for i in 240: await physics_frame
	j.set_meta("damage_immune", true)
	var cena := current_scene
	cena.progressao.ativar_item("pokebola")
	j.set("_yaw", 2.2)      # de lado para a câmera ver o braço
	j.set("_pitch", 0.05); j.call("_update_pivot")
	for i in 10: await physics_frame
	var cap = cena.get_node("CapturaDeInimigos")
	cap.comecar_a_puxar()
	for i in 45: await physics_frame
	await _foto("lancamento_1_puxando.png")
	cap.soltar()
	for i in 6: await physics_frame
	await _foto("lancamento_2_soltou.png")
	modo.set("progresso_forcado", "")
	quit()
