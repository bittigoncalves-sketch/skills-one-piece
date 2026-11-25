extends SceneTree
# ============================================================================
#  CAPTURA DA ILHA — fotos com GPU de verdade do mapa montado (30/09/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_ilha.gd -- \
#        [--mapa res://mapas/historia/baseplate.json] [--saida res://art_src/validation/mapa_ilha]
#
#  Só LÊ o mapa: monta como o Modo História monta (MapaMontador + oceano + ambiente),
#  sem jogador, e fotografa de pontos fixos. Mede também quanto a montagem levou.
#  Uma cápsula de 1,6 m (o colisor do jogador) aparece nas fotos de perto, como régua.
# ============================================================================

## nome, posição da câmera, para onde olha, mostrar régua (posição XZ da régua ou null)
const VISTAS := [
	["01_aerea", Vector3(0, 520, 330), Vector3(0, 0, 10), null],
	["02_vila", Vector3(118, 30, 78), Vector3(140, 4, 20), Vector2(146, 34)],
	["03_vila_chao", Vector3(158, 6.5, 40), Vector3(140, 5, 18), Vector2(152, 32)],
	["04_rio_ponte_sul", Vector3(80, 22, 110), Vector3(46, 1, 68), null],
	["05_floresta_morros", Vector3(-40, 40, -10), Vector3(-160, 18, -140), null],
	["06_porto", Vector3(200, 28, 120), Vector3(262, 0, 40), null],
	["07_coliseu", Vector3(-95, 30, 200), Vector3(-150, 6, 150), null],
	["08_fazendas", Vector3(170, 30, -90), Vector3(120, 4, -150), null],
	["09_rio_norte", Vector3(-20, 18, -60), Vector3(-62, 1, -119), null],
	["10_dentro_da_mata", Vector3(-120, 9, 30), Vector3(-160, 6, 0), Vector2(-124, 22)],
]

var saida := "res://art_src/validation/mapa_ilha"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var caminho := "res://mapas/historia/baseplate.json"
	if args.find("--mapa") >= 0:
		caminho = args[args.find("--mapa") + 1]
	if args.find("--saida") >= 0:
		saida = args[args.find("--saida") + 1]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = Vector2i(1600, 900)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var lido := MapaArquivo.carregar(caminho)
	if not lido["ok"]:
		push_error("mapa inválido: %s" % str(lido["erros"]).left(400))
		quit(1)
		return
	var t0 := Time.get_ticks_usec()
	MapaMontador.montar(mundo, lido["mapa"])
	var montagem_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var oceano: Node3D = load("res://src/world/oceano_historia.gd").new()
	oceano.name = "Oceano"
	mundo.add_child(oceano)
	oceano.configurar(lido["mapa"])
	var regua := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.35
	capsula.height = 1.6
	regua.mesh = capsula
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.6)
	regua.material_override = mat
	mundo.add_child(regua)
	var camera := Camera3D.new()
	camera.far = 4000.0
	mundo.add_child(camera)
	camera.make_current()
	var espaco := mundo.get_world_3d().direct_space_state
	for i in 4:
		await physics_frame
	var quadros: Array[float] = []
	var vistas: Array = VISTAS.filter(func(v): return v[0] in ["05_floresta_morros", "10_dentro_da_mata"]) if args.has("--floresta") else VISTAS
	for v in vistas:
		camera.position = v[1]
		camera.look_at(v[2])
		regua.visible = v[3] != null
		if v[3] != null:
			var p: Vector2 = v[3]
			var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 200, p.y), Vector3(p.x, -50, p.y)))
			regua.position = Vector3(p.x, (hit["position"].y if not hit.is_empty() else 0.0) + 0.8, p.y)
		for i in 10:
			await process_frame
		var a := Time.get_ticks_usec()
		for i in 20:
			await process_frame
		quadros.append((Time.get_ticks_usec() - a) / 20000.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(v[0] + ".png")))
	var pior := 0.0
	var soma := 0.0
	for q in quadros:
		pior = maxf(pior, q)
		soma += q
	print("CAPTURA_ILHA montagem_ms=%.0f pecas=%d quadro_medio_ms=%.1f pior_vista_ms=%.1f fotos=%d" % [
		montagem_ms, (lido["mapa"]["pecas"] as Array).size(), soma / quadros.size(), pior, quadros.size()])
	quit()
