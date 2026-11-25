extends SceneTree
# ============================================================================
#  V DA HIE NO MODO HISTÓRIA: O LUGAR VIRA GELO, COM LIMITE (10/10/2026,
#  docs/PEDIDO_2026-10-10_HISTORIA.md).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_hie_v_gelo.gd
#    DISPLAY=:1 "$(./find_godot.sh)" --path . --script tools/dev_tests/test_hie_v_gelo.gd -- --tela
#
#  Pedido do dono: "habilidade V fazer com que transforme o terreno ao redor em gelo
#  trocando a cor do relevo, casas, árvores em branco azulado; ela não irá mais se
#  expandir, nascerá com limite definido".
#  No MAPA VIVO (a vila de verdade), save de TESTE, Hie comida:
#    • o V cria a `EraDoGelo`; o gelo chega ao raio em ~0,35 s e NÃO cresce mais (5 s);
#    • o decal só pinta a camada do cenário: o mapa está nela, o jogador não;
#    • boneco parado DENTRO do raio congela; FORA, não;
#    • com tela: a cena fica mais clara e mais azul (média de cor medida) — fotos
#      antes/depois em art_src/validation/hie_v_gelo/;
#    • fim: some sozinho (tempo acelerado);
#    • controle positivo: fora do Modo História (= arena), o V é o antigo (placa que cresce).
# ============================================================================

const SAVE := "user://test_hie_v_gelo_progresso.json"
const PASTA := "res://art_src/validation/hie_v_gelo"

var total := 0
var falhas := 0
var tela := false
var p: Node3D       # sem tipo Player: tipar compila o Player.gd antes dos autoloads


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	if tela:
		root.size = Vector2i(1280, 720)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var cena := current_scene
	var prog: ProgressaoDoPersonagem = cena.get("progressao")
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	ok(prog.comer_fruta("hie_hie"), "come a Hie")
	await quadros(30)
	var raiz := cena.get_node("Mapa")
	var marcadas := 0
	for no in raiz.find_children("*", "VisualInstance3D", true, false):
		if (no as VisualInstance3D).layers & MapaMontador.CAMADA_CENARIO:
			marcadas += 1
	ok(marcadas > 500, "o cenário do mapa está na camada do gelo (%d desenhos)" % marcadas)
	var modelo_do_jogador := (p.find_children("*", "VisualInstance3D", true, false))
	ok(not modelo_do_jogador.is_empty() and modelo_do_jogador.all(func(v): return not (v.layers & MapaMontador.CAMADA_CENARIO)),
		"o jogador NÃO está na camada do gelo (%d desenhos)" % modelo_do_jogador.size())

	# Boneco dentro (8 m) e fora (RAIO + 6 m) do gelo, parados.
	var centro: Vector3 = p.global_position
	var dentro := await _boneco(centro + Vector3(8, 0, 0))
	var fora := await _boneco(centro + Vector3(-(EraDoGelo.RAIO + 6.0), 0, 0))
	var cam := get_root().get_viewport().get_camera_3d()
	p.set("_pitch", deg_to_rad(-28.0))
	p.call("_update_pivot")
	await quadros(30)
	var antes := await _foto("antes")

	print("\n-- V --")
	await _apertar_v()
	await quadros(int(EraDoGelo.NASCER * 60.0) + 6)
	var era := cena.find_child("EraDoGelo", true, false) as EraDoGelo
	ok(era != null, "o V criou a Era do Gelo (Modo História)")
	if era == null:
		return _fim()
	var geada := era.get_node("Geada") as Decal
	ok(is_equal_approx(geada.size.x, EraDoGelo.RAIO * 2.0), "em %.2f s o gelo já está no limite (%.1f m de lado)" % [EraDoGelo.NASCER, geada.size.x])
	ok(geada.cull_mask == MapaMontador.CAMADA_CENARIO, "o decal só pinta o cenário")
	await quadros(300)
	ok(is_equal_approx(geada.size.x, EraDoGelo.RAIO * 2.0), "5 s depois: não cresceu (%.1f m)" % geada.size.x)
	ok(bool(dentro.get_meta("is_frozen", false)) or bool(dentro.get_meta("ice_immune", false)) or dentro.health < dentro.max_health,
		"boneco dentro do gelo foi pego (congelado/imune/ferido)")
	ok(not bool(fora.get_meta("is_frozen", false)) and not bool(fora.get_meta("ice_immune", false)) and is_equal_approx(fora.health, fora.max_health),
		"boneco fora do limite: intocado")
	var depois := await _foto("depois")
	if tela:
		print("     cor média antes %s  ·  depois %s" % [str(antes), str(depois)])
		ok(depois.get_luminance() > antes.get_luminance() + 0.03 and (depois.b - depois.r) > (antes.b - antes.r),
			"a cena ficou mais clara e mais azul (luz %.3f → %.3f)" % [antes.get_luminance(), depois.get_luminance()])
		var cima := Camera3D.new()
		current_scene.add_child(cima)
		cima.global_position = centro + Vector3(0, 38, 30)
		cima.look_at(centro)
		cima.make_current()
		await _foto("de_cima")
		cima.queue_free()
		cam.make_current()

	print("\n-- fim --")
	Engine.time_scale = 8.0
	await quadros(int((EraDoGelo.DURACAO - 5.0) * 60.0 / 8.0) + 60)
	Engine.time_scale = 1.0
	await quadros(30)
	ok(not is_instance_valid(era), "acabou: a Era do Gelo some sozinha")

	print("\n-- controle positivo: fora do Modo História (arena) --")
	cena.remove_from_group("modo_historia")
	await _apertar_v()
	await quadros(30)
	ok(cena.find_child("EraDoGelo", true, false) == null, "na arena o V é o antigo (sem Era do Gelo)")
	cena.add_to_group("modo_historia")
	p.call("clear_spawned_skills")
	_fim()


func _boneco(onde: Vector3) -> BonecoDeDuelo:
	var b := BonecoDeDuelo.new()
	var q := PhysicsRayQueryParameters3D.create(onde + Vector3.UP * 30.0, onde + Vector3.DOWN * 40.0, 1)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	b.position = (hit["position"] if not hit.is_empty() else onde) + Vector3.UP * 1.0
	current_scene.add_child(b)
	await quadros(30)
	return b


func _apertar_v() -> void:
	(p.get("_fruit_cooldowns") as Dictionary)["V"] = 0.0
	p.energy = p.max_energy
	await quadros(40)
	p.begin_charge("V")
	await quadros(2)
	p.release_charge("V")


## Foto (com tela) e a cor média da metade de baixo (onde está o chão).
func _foto(nome: String) -> Color:
	if not tela:
		return Color.BLACK
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(PASTA.path_join(nome + ".png")))
	print("     foto: ", PASTA.path_join(nome + ".png"))
	var soma := Color(0, 0, 0, 0)
	var n := 0
	for y in range(img.get_height() / 2, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			soma += img.get_pixel(x, y)
			n += 1
	return Color(soma.r / n, soma.g / n, soma.b / n)


func _fim() -> void:
	Engine.time_scale = 1.0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nHIE_V_GELO %d/%d" % [total - falhas, total])
	quit(1 if falhas else 0)
