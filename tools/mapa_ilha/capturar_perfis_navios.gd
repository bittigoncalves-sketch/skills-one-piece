extends SceneTree
## Inspeção dos seis GLBs existentes; não altera catálogo nem mapa.
const IDS := ["boat", "small_ship", "ship", "house", "house-2kytqgs4rh", "house-g7esjlfi4v"]
var camera: Camera3D
var saida := "res://art_src/validation/navios"

func _initialize() -> void:
	_executar.call_deferred()

func _executar() -> void:
	root.size = Vector2i(1280, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	camera = Camera3D.new()
	mundo.add_child(camera)
	camera.make_current()
	var bib := BibliotecaDeModelos.padrao()
	for id: String in IDS:
		var corpo := Node3D.new()
		mundo.add_child(corpo)
		var tam := bib.tamanho_padrao(id)
		bib.aplicar_em(corpo, {"id": id, "modelo": id, "tamanho": tam})
		corpo.position.y = tam.y * .5
		var alvo := Vector3(0, tam.y * .4, 0)
		var escala := maxf(tam.x, maxf(tam.y, tam.z))
		var vistas := {"34": Vector3(.9,.65,1), "lado_x": Vector3(1,.25,0), "lado_z": Vector3(0,.3,1), "cima": Vector3(.05,1,.01)}
		for vista: String in vistas:
			camera.position = alvo + (vistas[vista] as Vector3).normalized() * escala * 1.5
			camera.look_at(alvo)
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(id + "_" + vista + ".png")))
		corpo.queue_free()
		await process_frame
	print("CAPTURA_PERFIS_NAVIOS_OK")
	quit()
