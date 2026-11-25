extends SceneTree
## Os personagens do Mine Piece convertidos (`tools/mine_piece/geo_para_glb.py`), lado a lado,
## para conferir UV, frente, escala, roupa e arma (17/10/2026).
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_mine_piece_modelos.gd -- <id> ...
## Saída: art_src/validation/east_blue/modelos_<frente|costas|anim>.png

const PASTA := "res://art_src/validation/east_blue"
var _lote := ""

func _init() -> void: _rodar.call_deferred()

func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1600, 700)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var cena := Node3D.new()
	root.add_child(cena)
	var amb := WorldEnvironment.new()
	amb.environment = Environment.new()
	amb.environment.background_mode = Environment.BG_COLOR
	amb.environment.background_color = Color(0.55, 0.7, 0.85)
	amb.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	amb.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	cena.add_child(amb)
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-40, 30, 0)
	cena.add_child(sol)
	var chao := MeshInstance3D.new()
	chao.mesh = PlaneMesh.new()
	(chao.mesh as PlaneMesh).size = Vector2(40, 20)
	cena.add_child(chao)
	var ids := OS.get_cmdline_user_args()
	# "lote:<nome>" como primeiro argumento muda o nome das fotos (vários lotes do elenco).
	if not ids.is_empty() and ids[0].begins_with("lote:"):
		_lote = ids[0].trim_prefix("lote:") + "_"
		ids = ids.slice(1)
	var modelos: Array[Node3D] = []
	for i in ids.size():
		var cena_glb := load("res://mapas/modelos/mp_%s.glb" % ids[i]) as PackedScene
		if cena_glb == null:
			push_error("sem modelo " + ids[i])
			continue
		var m := cena_glb.instantiate() as Node3D
		cena.add_child(m)
		m.position = Vector3((i - (ids.size() - 1) * 0.5) * 2.4, 0, 0)
		modelos.append(m)
	var cam := Camera3D.new()
	cena.add_child(cam)
	cam.current = true
	cam.fov = 40
	var larg := maxf(ids.size() * 2.4, 6.0)
	# Frente: os modelos olham para −Z, então a câmera fica em −Z olhando para +Z.
	cam.position = Vector3(0, 1.4, -larg * 1.25)
	cam.look_at(Vector3(0, 1.0, 0))
	await _foto("modelos_frente")
	cam.position = Vector3(0, 1.4, larg * 1.25)
	cam.look_at(Vector3(0, 1.0, 0))
	await _foto("modelos_costas")
	cam.position = Vector3(-larg * 0.9, 1.6, -larg * 0.9)
	cam.look_at(Vector3(0, 1.0, 0))
	for m in modelos:
		var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if ap == null: continue
		for nome in ["walk_loop", "walk", "punch_right"]:
			if ap.has_animation(nome):
				ap.play(nome)
				ap.seek(0.35, true)
				ap.pause()
				break
	await _foto("modelos_anim")
	quit()

func _foto(nome: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s%s.png" % [PASTA, _lote, nome])
