extends SceneTree
# ============================================================================
#  CAPTURA DA ILHA DOS MACACOS v2 — fotos com GPU de verdade (22/11/2026): vila plana, estradas, construções, sítios. Weston isolado (docs/MODO_HISTORIA.md).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_ilha_macacos_v2.gd -- \
#        [--mapa=<caminho>] [--saida=<pasta>]
#
#  Só LÊ o mapa: monta como o Modo História monta (MapaMontador + oceano + fundo do mar
#  por ilha + ambiente), sem jogador e sem bichos (eles nascem no jogo), e fotografa de
#  pontos fixos: do alto, chegando pelo mar, o píer, a trilha, os morros e a ilha vista
#  do porto da ilha inicial e do meio do caminho (a névoa decide o quanto aparece).
# ============================================================================

const C := Vector3(1500, 0, 0)
## nome, posição da câmera, para onde olha
const VISTAS := [
	["01_aerea", C + Vector3(0, 250, 190), C + Vector3(0, 0, 0)],
	["02_cais", C + Vector3(-182, 9, 16), C + Vector3(-134, 2, 0)],
	["03_portal_e_estrada", C + Vector3(-84, 7, 12), C + Vector3(-46, 4, 0)],
	["04_vila", C + Vector3(-52, 10, 34), C + Vector3(-12, 3, 2)],
	["05_cabana_do_mestre", C + Vector3(-4, 6, 8), C + Vector3(-4, 4, -18)],
	["06_torre", C + Vector3(44, 10, 30), C + Vector3(24, 9, 16)],
	["07_estrada_ao_trono", C + Vector3(8, 12, 14), C + Vector3(40, 8, -34)],
	["08_trono", C + Vector3(62, 16, -30), C + Vector3(62, 10, -72)],
	["09_totens", C + Vector3(36, 9, 100), C + Vector3(42, 5, 78)],
	["10_bananal", C + Vector3(-42, 11, -18), C + Vector3(-62, 4, -40)],
	["11_curandeiro", C + Vector3(-36, 10, 42), C + Vector3(-58, 4, 56)],
	["12_floresta_e_vila_de_longe", C + Vector3(-150, 70, 140), C + Vector3(0, 10, -10)],
]

var saida := "res://art_src/validation/ilha_macacos_v2"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	var caminho := "res://mapas/historia/baseplate.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mapa="):
			caminho = a.trim_prefix("--mapa=")
		elif a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
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
	var raiz := MapaMontador.montar(mundo, lido["mapa"])
	# As áreas de animais são do editor: o jogo as esconde (`PopulacaoDeAnimais`).
	for p: Dictionary in lido["mapa"]["pecas"]:
		if p["tipo"] == "area_animais" and raiz.get_node_or_null(NodePath(String(p["id"]))):
			(raiz.get_node(NodePath(String(p["id"]))) as Node3D).visible = false
	var oceano: Node3D = load("res://src/world/oceano_historia.gd").new()
	oceano.name = "Oceano"
	mundo.add_child(oceano)
	oceano.configurar(lido["mapa"])
	var fundos := FundoDoMar.montar_por_ilha(mundo, lido["mapa"], oceano.get("bases"))
	print("FUNDOS %s" % ", ".join(fundos.map(func(f: FundoDoMar) -> String:
		return "%s em (%.0f, %.0f)" % [f.name, f.position.x, f.position.z])))
	var camera := Camera3D.new()
	camera.far = 4000.0
	mundo.add_child(camera)
	camera.make_current()
	for i in 4:
		await physics_frame
	for v in VISTAS:
		camera.position = v[1]
		camera.look_at(v[2])
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(v[0] + ".png")))
	print("CAPTURA_MACACOS fotos=%d -> %s" % [VISTAS.size(), saida])
	quit()
