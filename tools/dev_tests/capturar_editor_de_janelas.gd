extends SceneTree
# ============================================================================
#  EDITOR DE JANELAS — fotos (05/10/2026): o modo janelas com o inventário
#  escolhido e um elemento selecionado, e a loja dos NPCs.
#
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_editor_de_janelas.gd -- <pasta>
#
#  Mapa de TESTE e layout de TESTE (nunca os do projeto).
# ============================================================================

const MAPA := "user://capturar_editor_de_janelas_mapa.json"
const LAYOUT := "user://capturar_layout_janelas.json"


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(LAYOUT))
	LayoutDeJanelas.caminho_forcado = LAYOUT
	LayoutDeJanelas.recarregar()
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tools/dev_tests/fixtures/mapa_baseplate.json"),
		ProjectSettings.globalize_path(MAPA))
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = MAPA
	get_root().add_child(ed)
	current_scene = ed
	for i in 12:
		await process_frame
	ed.alternar_janelas()
	var je: EditorDeJanelas = ed.get("_janelas")
	je.escolher_janela("inventario")
	for i in 8:
		await process_frame
	var rotulo: Control = null
	for l in je.janela.find_children("*", "Label", true, false):
		if (l as Label).is_visible_in_tree() and (l as Label).text == "INVENTÁRIO":
			rotulo = l
	if rotulo != null:
		je.selecionar(rotulo)
	await _foto(saida, "editor_janelas_inventario")
	je.escolher_janela("loja")
	for i in 8:
		await process_frame
	je.selecionar(je.janela)
	await _foto(saida, "editor_janelas_loja")
	print("fotos em ", saida)
	LayoutDeJanelas.caminho_forcado = ""
	quit(0)


func _foto(saida: String, nome: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))
