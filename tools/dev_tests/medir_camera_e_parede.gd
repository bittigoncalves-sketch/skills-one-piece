extends SceneTree
# ============================================================================
#  1) A TELA NÃO EMBRANQUECE MAIS  2) A CÂMERA AFASTA EM DEGRAUS
#  (A parte 3, "andar na superfície", saiu em 03/10/2026 junto com a mecânica —
#  fatia 2 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md. O wall run novo é medido em
#  tools/dev_tests/test_corrida_na_parede.gd.)
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
	# 90 quadros: tempo de sobra para qualquer interpolação assentar antes de
	# medir. Medir cedo é medir a rampa, não o resultado.
	for i in 90:
		await process_frame
	var sfx := _screenfx()
	var vals := {}
	for nome in ["speed_lines", "borrao", "aberracao", "vignette"]:
		vals[nome] = _param(sfx, nome)
	print("   correndo a toda: %s" % str(vals))
	var soma := 0.0
	for k in vals:
		soma += absf(float(vals[k]))
	# ⚠️ LIMIAR, NÃO ZERO EXATO. Os parâmetros do ScreenFX chegam a zero por
	# interpolação, e alguns quadros depois ainda há um resíduo de milésimos —
	# exigir 0,000000 tornava a asserção INSTÁVEL (passava numa rodada e
	# reprovava na outra por 0,0018). O que importa é não haver efeito VISÍVEL:
	# 0,01 está uma ordem de grandeza abaixo do que o olho pega, e não oscila.
	_ok("nenhum efeito de velocidade na tela (soma %.4f)" % soma, soma < 0.01)
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

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


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
