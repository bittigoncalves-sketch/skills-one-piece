extends SceneTree
const SAIDA := "res://art_src/validation/skills_builder"
func _init() -> void:
	rodar.call_deferred()
func rodar() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(SAIDA)
	root.get_node("GameFlow").start_skills_builder()
	for i in 8: await process_frame
	var editor: Control = current_scene
	await foto("01_editor")
	editor.selecionar_evento("hitbox_1")
	editor.arena.buscar(.48)
	await foto("02_hitbox")
	editor._novo(1)
	editor._mostrar_secao("projeteis")
	editor.arena.buscar(.5)
	await foto("03_projetil")
	editor._novo(2)
	editor._mostrar_secao("vfx")
	editor.arena.buscar(.8)
	await foto("04_harpia")
	root.size = Vector2i(1060, 680)
	await foto("05_janela_compacta")
	editor._voltar()
	for i in 8: await process_frame
	root.size = Vector2i(1280, 720)
	await foto("06_menu")
	print("SKILLS_BUILDER_CAPTURAS ", SAIDA)
	quit()
func foto(nome: String) -> void:
	for i in 5: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SAIDA.path_join(nome + ".png"))
