extends SceneTree
# ============================================================================
#  CAPTURA DA ILHA DOS MACACOS — fotos com GPU de verdade (08/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_ilha_dos_macacos.gd -- \
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
	["01_aerea", C + Vector3(0, 330, 250), C + Vector3(0, 0, 10)],
	["02_chegando_pelo_mar", C + Vector3(-230, 7, 40), C + Vector3(-120, 3, 0)],
	["03_pier", C + Vector3(-162, 5, 22), C + Vector3(-128, 1, 0)],
	["04_trilha_clareira", C + Vector3(-80, 9, 26), C + Vector3(-14, 3, 4)],
	["05_morros", C + Vector3(-40, 34, 110), C + Vector3(40, 14, -38)],
	["06_do_porto_inicial", Vector3(278, 4, 10), C + Vector3(0, 6, 0)],
	["07_meio_do_caminho", Vector3(814, 4, 10), C + Vector3(0, 6, 0)],
	["08_praia_sul", C + Vector3(30, 6, 175), C + Vector3(10, 1, 128)],
	["09_pier_de_perto", C + Vector3(-146, 7, 16), C + Vector3(-140, 0, 0)],
	["10_pier_do_porto_de_perto", Vector3(274, 7, -6), Vector3(268, 0, 10)],
	# Floresta gigante (18/11/2026)
	["11_floresta_gigante", C + Vector3(-150, 60, 140), C + Vector3(10, 25, -10)],
	["12_sob_as_copas", C + Vector3(-70, 4, 30), C + Vector3(-20, 26, -10)],
	["13_clareira_do_mestre", C + Vector3(-30, 4, 14), C + Vector3(-12, 3, 4)],
]

var saida := "res://art_src/validation/ilha_dos_macacos"


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
