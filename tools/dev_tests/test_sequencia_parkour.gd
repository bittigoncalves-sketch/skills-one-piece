extends SceneTree
# ============================================================================
#  SEQUÊNCIA COMPLETA — o objetivo do pedido de 02/10/2026 (fatia 4 de
#  docs/PARKOUR_MIRRORS_EDGE_PLANO.md):
#
#     Corrida → curva → salto → Wall Run → salto → escalada → subir borda → corrida
#
#  "deve parecer um único movimento contínuo". Teclas de verdade e a câmera girando
#  (a curva é dirigida pela câmera, como no pedido). Mede:
#    • os estados aparecem NESSA ordem, sem "parado" entre eles;
#    • nenhum teleporte (maior passo por quadro);
#    • o corpo nunca para fora da escalada (velocidade horizontal mínima);
#    • a curva inclina o corpo; termina correndo em cima da construção.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_sequencia_parkour.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0
var p: Node3D
var dt := 1.0 / 60.0
var _trilha: Array[String] = []
var _passo_max := 0.0
var _vel_min_fora := INF
var _antes := Vector3.ZERO
var _registrando := false
var _embalou := false        # a velocidade mínima só conta depois da arrancada


func _init() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_sequencia_parkour.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	_registrar()

	# 1. CORRIDA para −Z.
	p.global_position = Vector3(-30, 0.81, 6)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	for i in 40:
		await physics_frame
	_antes = p.global_position
	_registrando = true
	_tecla(KEY_W, true)
	for i in 36:
		await physics_frame

	# 2. CURVA pela câmera: de −Z para +X em 0,5 s.
	var incl_pico := 0.0
	for i in 30:
		p._yaw = lerpf(0.0, -PI / 2.0, float(i + 1) / 30.0)
		await physics_frame
		incl_pico = maxf(incl_pico, absf(p._loco_chao.inclinacao))
	for i in 12:
		await physics_frame
	# A raia saiu da curva: a parede do wall run nasce à frente, rente a ela.
	var raia_z: float = p.global_position.z
	var x_agora: float = p.global_position.x
	var parede_z := raia_z - 0.6
	_caixa(Vector3(x_agora + 1.5 + 15.0, 5, parede_z - 0.5), Vector3(30, 10, 1), false)
	# A construção escalável fica do outro lado, onde o salto da parede leva.
	var x_salto := x_agora + 4.5
	_caixa(Vector3(x_salto + 2.0, 3, raia_z + 3.6 + 2.0), Vector3(10, 6, 4), true)
	while p.global_position.x < x_agora + 2.0:
		await physics_frame

	# 3. SALTO → WALL RUN (o Espaço rente à parede).
	await _espaco()
	for i in 22:
		await physics_frame
	# 4. SALTO para longe, e a câmera vira para a construção (+Z).
	await _espaco()
	for i in 12:
		p._yaw = lerp_angle(-PI / 2.0, PI, float(i + 1) / 12.0)
		await physics_frame
	# 5. ESCALADA (agarra sozinho) → BORDA → SUBIR → CORRIDA em cima.
	var topo_ok := false
	for i in 420:
		await physics_frame
		if p.global_position.y > 6.5 and p.is_on_floor() and not p._parkour.assumiu():
			topo_ok = true
			break
	var v_topo := 0.0
	for i in 30:
		await physics_frame
		v_topo = Vector2(p.velocity.x, p.velocity.z).length()
	_registrando = false
	_tecla(KEY_W, false)

	var ordem := ["correndo", "wall_run", "ar", "escalando", "subindo", "correndo"]
	print("   trilha: %s" % " → ".join(_trilha))
	_ok("a curva inclina o corpo (%.1f°)" % rad_to_deg(incl_pico), incl_pico > deg_to_rad(3.0))
	_ok("os estados aparecem na ordem do pedido", _em_ordem(_trilha, ordem))
	_ok("nenhum \"parado\" no meio da sequência", not _trilha.has("parado"))
	_ok("sem teleporte: maior passo por quadro %.3f m (≤ 0,30)" % _passo_max, _passo_max <= 0.30)
	_ok("depois da arrancada, fora da escalada, o corpo nunca para (menor velocidade horizontal %.2f m/s ≥ 1,0)" % _vel_min_fora, _vel_min_fora >= 1.0)
	_ok("termina correndo em cima da construção (y %.2f, %.2f m/s)" % [p.global_position.y, v_topo], topo_ok and v_topo >= 3.5)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nSEQUENCIA_PARKOUR %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Uma etiqueta por quadro, sem repetir a anterior.
func _registrar() -> void:
	while true:
		await physics_frame
		if not _registrando or p == null:
			continue
		var d: float = (p.global_position - _antes).length()
		_passo_max = maxf(_passo_max, d)
		_antes = p.global_position
		var e := _estado()
		var v := Vector2(p.velocity.x, p.velocity.z).length()
		_embalou = _embalou or v >= 3.0
		if _embalou and e != "escalando" and e != "subindo" and e != "borda":
			_vel_min_fora = minf(_vel_min_fora, v)
		if _trilha.is_empty() or _trilha[_trilha.size() - 1] != e:
			_trilha.append(e)


func _estado() -> String:
	if p._parkour.correndo_na_parede():
		return "wall_run"
	if p._parkour.escalando():
		var e: String = p._parkour.escalada.estado
		return "subindo" if e == "subindo" else ("borda" if e == "borda" else "escalando")
	if not p.is_on_floor():
		return "ar"
	var loco: String = p._loco_chao.estado
	return "parado" if loco == "parado" else "correndo"


## `ordem` aparece em `trilha` como subsequência (outros estados podem intercalar,
## como "borda" entre escalando e subindo).
func _em_ordem(trilha: Array[String], ordem: Array) -> bool:
	var k := 0
	for e in trilha:
		if k < ordem.size() and e == ordem[k]:
			k += 1
	return k == ordem.size()


func _caixa(centro: Vector3, tamanho: Vector3, escalavel: bool) -> void:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	col.shape = caixa
	corpo.add_child(col)
	if escalavel:
		corpo.set_meta("escalavel", true)
	current_scene.add_child(corpo)
	corpo.global_position = centro


func _espaco() -> void:
	_tecla(KEY_SPACE, true)
	await physics_frame
	_tecla(KEY_SPACE, false)
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
