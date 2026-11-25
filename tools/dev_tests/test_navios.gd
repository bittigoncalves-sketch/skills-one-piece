extends SceneTree
# ============================================================================
#  NAVIOS — flutuar, embarcar com Y e dirigir (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_navios.gd
#
#  Pedido do dono: "no modo história, ao pressionar Y é possível subir no navio e
#  dirigi-lo; fazer também a interação dos navios com a água para que flutuem".
#  Continua a frente de barcos (docs/BARCOS_CHECKPOINT.md): Y assume/solta o leme,
#  W/S acelera/freia/ré, A/D vira. Para CADA navio dirigível, no mar aberto do
#  mapa plano do Modo História, com teclas de verdade:
#    • flutua: a origem (linha d'água) fica na superfície, sem afundar nem quicar,
#      e o casco balança com as ondas;
#    • Y perto do leme assume o comando; o piloto fica no leme enquanto o barco anda;
#    • W acelera para a FRENTE (−Z do barco); D vira para a DIREITA; S freia e dá ré;
#    • Y solta o leme: o jogador fica de pé no convés, fora da água.
# ============================================================================

const NAVIOS := ["boat", "small_ship", "ship"]
## Os três "barcos-casa" da categoria navios são CASAS na água (portas, fachada, o
## "casco" é o telhado) — decisão da frente de barcos (perfil_barco.gd): cenário.
const CASAS := ["house", "house-2kytqgs4rh", "house-g7esjlfi4v"]
var _ok_n := 0
var _falhas := 0
var p: Node3D
var nav: Node


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_navios.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	nav = current_scene.get("_navegacao")
	nav.janela = null   # 15/10/2026: sem a pergunta "Navegar?" — estes testes são da física do barco (a tripulação tem o test_tripulacao)
	if p == null or nav == null:
		print("❌ sem jogador ou sem navegação"); quit(1); return
	p.set_meta("damage_immune", true)
	var bib := MapaMontador.biblioteca_em_uso()
	var x := 300.0
	for id: String in NAVIOS:
		print("\n===== %s =====" % id)
		await _testar(bib, id, Vector3(x, 0, 0))
		x += 90.0
	print("\n===== barcos-casa =====")
	for id: String in CASAS:
		var casa: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
		_ok("%s continua cenário (não vira navio dirigível)" % id, not casa.configurar(bib, id, bib.tamanho_padrao(id)))
		casa.free()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nNAVIOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _testar(bib: BibliotecaDeModelos, id: String, onde: Vector3) -> void:
	var b: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
	var configurou: bool = b.configurar(bib, id, bib.tamanho_padrao(id))
	_ok("%s: configura (ficha e modelo)" % id, configurou)
	if not configurou:
		return
	var h0 := AguaDoMundo.superficie_em(onde.x, onde.z)
	# Posição ANTES de entrar na cena (como `ligar_no_mapa` faz): nascendo na origem
	# por um instante, o casco pegava o jogador parado ali e o levava junto como
	# plataforma ao ser movido para o mar.
	b.position = Vector3(onde.x, h0 + 0.6, onde.z)
	current_scene.add_child(b)
	nav.barcos.append(b)
	var parado := b.global_transform
	for i in 60:
		await physics_frame
	_ok("%s: sem piloto fica parado e sem simulação" % id,
		not b.is_physics_processing() and b.global_transform.is_equal_approx(parado))

	# EMBARCAR: jogador no convés, Y.
	var conves: Vector3 = b.ponto_no_conves_livre()
	if is_nan(conves.x):
		conves = b.leme.global_position
	p.global_position = conves + Vector3.UP * 0.9
	p.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	# Aproxima do leme se o convés livre ficou longe dele.
	if p.global_position.distance_to(b.leme.global_position + Vector3.UP * 0.85) > 2.5:
		p.global_position = b.leme.global_position + Vector3.UP * 0.85 + b.global_basis.z * 1.0
		for i in 20:
			await physics_frame
	await _tecla_toque(KEY_Y)
	_ok("%s: Y assume o leme (pilotando: %s)" % [id, p.get_meta("pilotando", false)], nav.ativo() and p.get_meta("pilotando", false))
	if not nav.ativo():
		await _limpar(b)
		return

	# FLUTUAR: só após assumir o leme; piloto não pode segurar o casco.
	var ys := []
	var rot := []
	for i in 330:
		await physics_frame
		if i >= 90:
			ys.append(b.global_position.y - AguaDoMundo.superficie_em(b.global_position.x, b.global_position.z))
			rot.append(Vector2(b.visual.rotation.x, b.visual.rotation.z))
	var media := 0.0
	var pior := 0.0
	for y in ys:
		media += y
		pior = maxf(pior, absf(y))
	media /= ys.size()
	var amp_rot := 0.0
	for r in rot:
		amp_rot = maxf(amp_rot, maxf(absf(r.x), absf(r.y)))
	_ok("%s: flutua na linha d'água em 4 s de ondas (desvio médio %+.2f m, pior %.2f m)" % [id, media, pior],
		b.esta_na_agua() and absf(media) < 0.2 and pior < 0.45)
	_ok("%s: o casco balança com as ondas (até %.1f°)" % [id, rad_to_deg(amp_rot)], amp_rot > deg_to_rad(0.3))


	# W: acelera para a frente.
	var frente0: Vector3 = -b.global_basis.z
	var direita0: Vector3 = b.global_basis.x
	var pos0: Vector3 = b.global_position
	var max_vel: float = float(b.ficha["velocidade"])
	var dist_leme := 0.0
	_tecla(KEY_W, true)
	for i in 240:
		await physics_frame
		dist_leme = maxf(dist_leme, p.global_position.distance_to(b.leme.global_position + Vector3.UP * 0.85))
	var v_frente: float = b.velocidade_atual()
	var andou: float = (b.global_position - pos0).dot(frente0)
	_ok("%s: W acelera para a FRENTE (%.2f m/s de %.1f; andou %.1f m)" % [id, v_frente, max_vel, andou], v_frente > max_vel * 0.5 and andou > 3.0)
	_ok("%s: o piloto fica no leme (afastou no máx. %.2f m)" % [id, dist_leme], dist_leme < 0.15)
	_ok("%s: segue flutuando andando (desvio %+.2f m)" % [id, b.global_position.y - AguaDoMundo.superficie_em(b.global_position.x, b.global_position.z)],
		absf(b.global_position.y - AguaDoMundo.superficie_em(b.global_position.x, b.global_position.z)) < 0.5)

	# D: vira para a direita.
	_tecla(KEY_D, true)
	for i in 120:
		await physics_frame
	_tecla(KEY_D, false)
	var frente1: Vector3 = -b.global_basis.z
	_ok("%s: D vira para a DIREITA (proa %.2f para a direita inicial)" % [id, frente1.dot(direita0)], frente1.dot(direita0) > 0.08)
	_tecla(KEY_W, false)

	# S: freia e dá ré.
	_tecla(KEY_S, true)
	var freou := false
	var re := false
	for i in 360:
		await physics_frame
		freou = freou or b.velocidade_atual() < v_frente * 0.5
		re = re or b.velocidade_atual() < -0.3
		if re:
			break
	_tecla(KEY_S, false)
	_ok("%s: S freia e depois dá ré (%s, %s)" % [id, freou, re], freou and re)
	for i in 120:
		await physics_frame

	# Y: solta o leme, de pé no convés.
	await _tecla_toque(KEY_Y)
	for i in 40:
		await physics_frame
	var agua := AguaDoMundo.superficie_em(p.global_position.x, p.global_position.z)
	_ok("%s: Y solta o leme e o jogador fica no convés (no chão %s, %.2f m acima da água)" % [id, p.is_on_floor(), p.global_position.y - agua],
		not nav.ativo() and not p.get_meta("pilotando", false) and p.is_on_floor() and p.global_position.y - agua > 0.5)
	# Sem piloto não há ondas, inércia, espuma ou deslocamento da plataforma.
	parado = b.global_transform
	var pose: Transform3D = b.visual.transform
	var caiu := false
	for i in 180:
		await physics_frame
		caiu = caiu or not p.is_on_floor()
	_ok("%s: leme solto estaciona e conserva o jogador sobre o convés" % id,
		not b.is_physics_processing() and b.global_transform.is_equal_approx(parado)
		and b.visual.transform.is_equal_approx(pose) and b.velocity.is_zero_approx() and not caiu)
	_ok("%s: espuma removida ao estacionar" % id,
		b._esteira._marcas.is_empty() and b._esteira._malha.get_surface_count() == 0)

	await _limpar(b)


func _limpar(b: CharacterBody3D) -> void:
	if nav.ativo():
		nav.sair(true)
	nav.barcos.erase(b)
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	b.queue_free()
	for i in 30:
		await physics_frame


func _tecla_toque(codigo: Key) -> void:
	_tecla(codigo, true)
	await physics_frame
	_tecla(codigo, false)
	await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)
