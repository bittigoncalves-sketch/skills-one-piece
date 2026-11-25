extends SceneTree
## Roda do mouse: aproxima/afasta a câmera, MAS NÃO com um menu aberto (M, N, B...).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_zoom_com_menu.gd
var falhas := 0
func _init() -> void: _rodar.call_deferred()
func ok(nome: String, c: bool) -> void:
	print("%s %s" % ["OK" if c else "FALHA", nome])
	if not c: falhas += 1
func _roda(baixo: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_DOWN if baixo else MOUSE_BUTTON_WHEEL_UP
	e.pressed = true
	Input.parse_input_event(e)
	await physics_frame
func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_zoom_menu.json")
	root.get_node("GameFlow").start_story()
	for i in 120: await physics_frame
	var p = get_first_node_in_group("player")
	var cam = p._camera
	p.zoom_por_teclas = false      # este teste é do zoom PELA RODA (arena/legado); no Modo História a roda é da hotbar e o zoom é I/O
	var d0: float = cam.distancia
	await _roda(true)
	ok("sem menu a roda afasta a câmera (%.1f -> %.1f)" % [d0, cam.distancia], cam.distancia > d0)
	var hud = get_first_node_in_group("hud")
	hud.alternar_inventario()
	await physics_frame
	ok("o inventário (N) está aberto", hud.is_menu_open())
	var d1: float = cam.distancia
	await _roda(true)
	await _roda(false)
	await _roda(false)
	ok("com o menu aberto a roda não mexe na câmera (%.1f)" % cam.distancia, is_equal_approx(cam.distancia, d1))
	hud.alternar_inventario()
	await physics_frame
	await _roda(false)
	ok("fechado o menu, a roda volta a aproximar (%.1f -> %.1f)" % [d1, cam.distancia], cam.distancia < d1)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("ZOOM_MENU falhas=%d" % falhas)
	quit(1 if falhas > 0 else 0)
