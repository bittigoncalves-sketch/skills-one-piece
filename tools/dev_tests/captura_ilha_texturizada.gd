extends SceneTree
## Fotos da ilha inicial do Modo História com blocos texturizados:
##   DISPLAY=:1 godot --path . -s tools/dev_tests/captura_ilha_texturizada.gd -- <pasta>
var saida := "/tmp/ilha_tex"

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
	modo.set("progresso_forcado", "user://captura_ilha_tex.json")
	root.get_node("GameFlow").start_story()
	await quadros(1600)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var base := jogador.global_position
	for gr in get_nodes_in_group(GradeVoxel.GRUPO):
		var gv := gr as GradeVoxel
		print("grade ", gv.name, " secoes_nos=", gv._nos.size(), " pronto=", gv.pronto(), " gerador=", gv.gerador != null, " alvo=", not gv.alvo_de.is_null(), " tex=", gv.material is ShaderMaterial)
		if gv._nos.size() > 0:
			var vis := 0
			for sc in gv._malhas:
				if (gv._malhas[sc] as MeshInstance3D).visible:
					vis += 1
			print("  visiveis=", vis, " furo_ativo=", gv._furo_ativo, " furo=", gv.material_longe.get_shader_parameter("furo_caixa") if gv.material_longe else "-", " raio=", gv.raio_secoes, " pos grade=", gv.global_position)
			var scp := GradeVoxel.secao_de(GradeVoxel.celula_em(base))
			for dy in range(-1, 2):
				var sc2 := scp + Vector3i(0, dy, 0)
				var dd := gv.gerador.gerar(sc2)
				if dd.is_empty():
					continue
				var r := GradeVoxel.malhar(dd, [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()])
				var caps := {}
				for u in r["uv2"]:
					caps[u.x] = true
				print("  secao ", sc2, " tris=", r["vertices"].size() / 3, " camadas=", caps.keys(), " nos=", gv._nos.has(sc2))
			var amostra: MeshInstance3D = gv._malhas.values()[0]
			print("  amostra pos=", amostra.global_position, " surf=", amostra.mesh.get_surface_count(), " mat=", amostra.mesh.surface_get_material(0))
	print("jogador ", base)
	await foto("00_jogo")
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 65
	cam.current = true
	var vistas := {"01_chao": [Vector3(0, 2.2, 5), Vector3(0, 0.5, -3)], "02_alto": [Vector3(0, 14, 16), Vector3(0, 0, -8)],
		"03_lado": [Vector3(12, 3, 0), Vector3(-6, 0, 0)]}
	for n in vistas:
		cam.global_position = base + vistas[n][0]
		cam.look_at(base + vistas[n][1], Vector3.UP)
		await quadros(12)
		await foto(n)
	quit()
