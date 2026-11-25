extends SceneTree
# ============================================================================
#  CÂMERA NO LEME (18/11/2026): "o jogador tem que ver o mar tranquilamente e o que está na frente; afaste a câmera o suficiente em cada barco".
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_camera_barcos.gd
#  Para CADA navio dirigível: ao assumir o leme a câmera entra no enquadramento do casco (recuo e altura crescem com o barco), o casco não a empurra para perto
#  (o braço da mola vai até onde foi pedido), ela fica acima da água, a linha até o mar à frente da proa não bate no próprio barco, e soltar o leme devolve tudo.
# ============================================================================
const NAVIOS := ["boat", "small_ship", "ship"]
var _ok_n := 0
var _falhas := 0
var p: Node3D
var CR  # `CameraRig`, carregado já com os autoloads (citar a classe aqui quebraria a compilação do teste em --script)
var nav: Node
func _init() -> void:
	_executar.call_deferred()
func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
func _tecla_toque(codigo: Key) -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = codigo
		ev.physical_keycode = codigo
		ev.pressed = pressionada
		Input.parse_input_event(ev)
		await physics_frame
func _executar() -> void:
	await process_frame
	CR = load("res://src/player/camera_rig.gd")
	# a fórmula, sem cena
	var fa = CR.enquadramento_de_barco(Vector3(2, 2, 6))
	var fb = CR.enquadramento_de_barco(Vector3(5, 10, 12))
	var fc = CR.enquadramento_de_barco(Vector3(8, 25, 32))
	_ok("o recuo cresce com o barco (%.1f < %.1f < %.1f m)" % [fa.distancia, fb.distancia, fc.distancia], fa.distancia < fb.distancia and fb.distancia < fc.distancia)
	_ok("a altura cresce com o barco (%.1f < %.1f < %.1f m)" % [fa.altura, fb.altura, fc.altura], fa.altura < fb.altura and fb.altura < fc.altura)
	var g = CR.enquadramento_de_barco(Vector3(30, 80, 400))
	var m = CR.enquadramento_de_barco(Vector3(0.1, 0.1, 0.1))
	_ok("os extremos ficam limitados (recuo %.0f–%.0f, altura %.1f–%.1f)" % [m.distancia, g.distancia, m.altura, g.altura], g.distancia == 36.0 and m.distancia == 8.0 and g.altura == 8.0 and m.altura == 1.5)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_camera_barcos.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	nav = current_scene.get("_navegacao")
	nav.janela = null
	if p == null or nav == null:
		print("❌ sem jogador ou sem navegação")
		quit(1)
		return
	p.set_meta("damage_immune", true)
	var bib := MapaMontador.biblioteca_em_uso()
	var x := 300.0
	var anterior := 0.0
	for id: String in NAVIOS:
		print("\n===== %s =====" % id)
		anterior = await _testar(bib, id, Vector3(x, 0, 0), anterior)
		x += 90.0
	print("\nCAMERA_BARCOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
func _testar(bib: BibliotecaDeModelos, id: String, onde: Vector3, distancia_do_menor: float) -> float:
	var b: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
	if not b.configurar(bib, id, bib.tamanho_padrao(id)):
		_ok("%s: configura" % id, false)
		return distancia_do_menor
	b.position = Vector3(onde.x, AguaDoMundo.superficie_em(onde.x, onde.z) + 0.6, onde.z)
	current_scene.add_child(b)
	nav.barcos.append(b)
	for i in 60:
		await physics_frame
	var cam = p._camera
	var antes = cam.distancia
	var altura_antes = cam.position.y
	var conves: Vector3 = b.ponto_no_conves_livre()
	if is_nan(conves.x):
		conves = b.leme.global_position
	p.global_position = b.leme.global_position + Vector3.UP * 0.85 + b.global_basis.z * 1.0
	p.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	await _tecla_toque(KEY_Y)
	if not nav.ativo():
		_ok("%s: assumiu o leme" % id, false)
		b.queue_free()
		return distancia_do_menor
	var enq = CR.enquadramento_de_barco(b.tamanho_casco)
	for i in 240:
		await physics_frame
	_ok("%s: casco %s → recuo pedido %.1f m, altura extra %.1f m" % [id, str(b.tamanho_casco), enq.distancia, enq.altura], cam.navegando and absf(cam.distancia - enq.distancia) < 0.01)
	_ok("%s: o pivô sobe a altura do barco (y %.2f → %.2f)" % [id, altura_antes, cam.position.y], absf(cam.position.y - (altura_antes + enq.altura)) < 0.01)
	var mola: SpringArm3D = cam._spring
	var alcancou: float = mola.get_hit_length()
	_ok("%s: o casco não empurra a câmera (mola %.1f de %.1f m)" % [id, alcancou, cam.distancia], alcancou >= cam.distancia * 0.9)
	var olho = cam.camera().global_position
	var agua: float = AguaDoMundo.superficie_em(olho.x, olho.z)
	_ok("%s: a câmera fica %.1f m acima da água" % [id, olho.y - agua], olho.y - agua >= 1.5)
	# a linha até o mar à frente da proa (40 m além) não bate no próprio barco
	var proa: Vector3 = b.global_position - b.global_basis.z * (b.tamanho_casco.z * 0.5 + 40.0)
	proa.y = agua
	var consulta := PhysicsRayQueryParameters3D.create(olho, proa, 1, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(consulta)
	var no_barco: bool = not hit.is_empty() and (hit["collider"] == b or b.is_ancestor_of(hit["collider"]))
	_ok("%s: dá para ver o mar à frente da proa (nada do barco na linha de visão)" % id, not no_barco)
	if distancia_do_menor > 0.0:
		_ok("%s: mais longe que o barco menor (%.1f > %.1f)" % [id, cam.distancia, distancia_do_menor], cam.distancia > distancia_do_menor)
	var dist = cam.distancia
	await _tecla_toque(KEY_Y)
	for i in 20:
		await physics_frame
	_ok("%s: soltar o leme devolve a câmera (recuo %.1f, y %.2f, FOV ×%.2f)" % [id, cam.distancia, cam.position.y, cam.fator_fov], not cam.navegando and absf(cam.distancia - antes) < 0.01 and absf(cam.position.y - altura_antes) < 0.01 and is_equal_approx(cam.fator_fov, 1.0))
	nav.barcos.erase(b)
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	b.queue_free()
	for i in 20:
		await physics_frame
	return dist
