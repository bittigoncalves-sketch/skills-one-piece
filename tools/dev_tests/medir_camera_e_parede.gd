extends SceneTree
# ============================================================================
#  1) A TELA NÃO EMBRANQUECE MAIS  2) A CÂMERA AFASTA EM DEGRAUS
#  3) ANDAR NA SUPERFÍCIE (a mecânica que substituiu a escalada)
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_camera_e_parede.gd
#
#  Pedidos do dono (2026-08-27): tirar o esbranquiçamento/distorção da tela;
#  afastar a câmera ao andar e mais ainda ao correr, voltando ao parar; e trocar
#  a escalada por "andar" sobre o objeto, com custo de energia, cancelando com
#  pulo e sem precisar segurar tecla.
# ============================================================================

var _ok_n := 0
var _falhas := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	p.set_meta("damage_immune", true)

	# ---------- 1. a tela ----------
	print("=== os efeitos de tela por velocidade ===")
	p.global_position = Vector3(0, 2.0, 0)
	p._yaw = 0.0
	p._camera.apontar(0.0, -0.2)
	_tecla(KEY_W, true); _tecla(KEY_SHIFT, true)
	for i in 60:
		await process_frame
	var sfx := _screenfx()
	var vals := {}
	for nome in ["speed_lines", "borrao", "aberracao", "vignette"]:
		vals[nome] = _param(sfx, nome)
	print("   correndo a toda: %s" % str(vals))
	var soma := 0.0
	for k in vals:
		soma += absf(float(vals[k]))
	_ok("nenhum efeito de velocidade na tela (soma %.4f)" % soma, soma < 0.001)
	_tecla(KEY_W, false); _tecla(KEY_SHIFT, false)
	for i in 60:
		await process_frame

	# ---------- 2. a câmera ----------
	print("\n=== distância da câmera por estado ===")
	var d_parado := await _dist(p, [])
	var d_andando := await _dist(p, [KEY_W])
	var d_correndo := await _dist(p, [KEY_W, KEY_SHIFT])
	var d_voltou := await _dist(p, [])
	print("   parado %.2f | andando %.2f | correndo %.2f | parou de novo %.2f" % [
		d_parado, d_andando, d_correndo, d_voltou])
	_ok("andar AFASTA a câmera de forma visível (> 0,5 m)", d_andando - d_parado > 0.5)
	_ok("correr afasta MAIS que andar", d_correndo - d_andando > 0.5)
	_ok("parar traz a câmera de volta", absf(d_voltou - d_parado) < 0.25)

	# ---------- 3. andar na superfície ----------
	print("\n=== andar na superfície ===")
	var parede := _achar_parede(p)
	if parede == Vector3.ZERO:
		print("   ⚠ nenhum bloco alto encontrado — pulando esta parte")
	else:
		await _testar_parede(p, parede)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _testar_parede(p: Node3D, junto: Vector3) -> void:
	p.global_position = junto
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	# ⚠️ VIRAR PARA O BLOCO. O ponto escolhido fica na face −Z dele, ou seja o
	# bloco está em +Z a partir do jogador — e a frente do jogo é −Z, então é
	# `yaw = PI`. Sem isto o W empurrava para LONGE da parede e o teste reprovava
	# uma mecânica que funciona.
	p._yaw = PI
	p._camera.apontar(PI, -0.1)
	for i in 20:
		await process_frame
	# ⚠️ O FLUXO REAL SÃO DOIS TOQUES, e isso não é atalho de teste: no chão o
	# espaço é PULO. O primeiro toque tira o jogador do chão; o segundo, já no
	# ar e contra a parede, é o que gruda. Grudar direto do chão exigiria roubar
	# o pulo, que é a tecla mais usada do jogo.
	_tecla(KEY_W, true)
	for i in 10:
		await process_frame
	# ⚠️ SEGURAR ALGUNS QUADROS. A borda do espaço é amostrada no quadro de
	# FÍSICA; apertar e soltar dentro de um quadro de processo pode não ser vista
	# nenhuma vez, e o teste reprovaria uma mecânica que funciona.
	_tecla(KEY_SPACE, true)     # 1º toque: pula
	for i in 4:
		await process_frame
	_tecla(KEY_SPACE, false)
	for i in 12:
		await process_frame
	_tecla(KEY_SPACE, true)     # 2º toque, no ar: gruda
	for i in 4:
		await process_frame
	_tecla(KEY_SPACE, false)
	var grudou := false
	for i in 60:
		await process_frame
		if p._parkour.na_parede():
			grudou = true
			break
	_ok("um TOQUE de espaço contra a parede gruda", grudou)
	if not grudou:
		_tecla(KEY_W, false)
		return

	# fica SEM segurar nada
	_tecla(KEY_W, false)
	var e0: float = p.energy
	var continuou := true
	for i in 30:
		await process_frame
		if not p._parkour.na_parede():
			continuou = false
			break
	_ok("continua na parede sem segurar tecla", continuou)
	_ok("andar na parede CONSOME energia (%.0f -> %.0f)" % [e0, p.energy], p.energy < e0 - 1.0)

	var up_corpo: Vector3 = p._char_model.global_transform.basis.y
	var n: Vector3 = p._parkour.normal_da_parede()
	print("   'para cima' do corpo %s | normal da parede %s | dot %+.2f" % [
		str(up_corpo.normalized()), str(n.normalized()), up_corpo.normalized().dot(n.normalized())])
	_ok("o 'chão' do corpo virou a superfície", up_corpo.normalized().dot(n.normalized()) > 0.8)

	# cancela PULANDO
	_tecla(KEY_SPACE, true)
	for i in 4:
		await process_frame
	_tecla(KEY_SPACE, false)
	var soltou := false
	for i in 40:
		await process_frame
		if not p._parkour.na_parede():
			soltou = true
			break
	_ok("pular CANCELA e solta da superfície", soltou)
	for i in 90:
		await process_frame
	var up2: Vector3 = p._char_model.global_transform.basis.y
	print("   'para cima' do corpo depois: %s" % str(up2.normalized()))
	_ok("a orientação do chão volta ao normal", up2.normalized().dot(Vector3.UP) > 0.9)


## Um ponto colado num bloco alto — o candidato natural a "andar na parede".
func _achar_parede(p: Node3D) -> Vector3:
	for n in _todos(get_root()):
		if not (n is StaticBody3D) or n.name == "Plataforma":
			continue
		var b := n as Node3D
		if b.scale.y < 5.0:
			continue
		if Vector2(b.global_position.x, b.global_position.z).length() > 70.0:
			continue
		# fica na frente da face −Z do bloco, encostado
		return b.global_position + Vector3(0, 1.0, -(b.scale.z * 0.5 + 0.45))
	return Vector3.ZERO


func _dist(p: Node3D, teclas: Array) -> float:
	for k in teclas:
		_tecla(k, true)
	for i in 75:
		await process_frame
	var d: float = p._camera._spring.spring_length
	for k in teclas:
		_tecla(k, false)
	return d


func _screenfx() -> Node:
	for n in _todos(get_root()):
		if n.get_class() == "CanvasLayer" and String(n.name).findn("screen") >= 0:
			return n
	return null


func _param(sfx: Node, nome: String):
	if sfx == null:
		return 0.0
	for f in _todos(sfx):
		if f is ColorRect and (f as ColorRect).material is ShaderMaterial:
			var v = ((f as ColorRect).material as ShaderMaterial).get_shader_parameter(nome)
			if v != null:
				return v
	return 0.0


func _todos(n: Node) -> Array:
	var o: Array = [n]
	for f in n.get_children():
		o.append_array(_todos(f))
	return o


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tecla(c: Key, d: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = c
	e.keycode = c
	e.pressed = d
	Input.parse_input_event(e)
