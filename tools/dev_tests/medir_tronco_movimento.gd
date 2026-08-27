extends SceneTree
# ============================================================================
#  QUANTO O TRONCO TOMBA EM CADA ESTADO DE MOVIMENTO.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_tronco_movimento.gd
#
#  POR QUE: o vídeo do dono (2026-08-27) mostra o boneco DESMONTANDO em
#  movimento — tronco tombado para a frente e pernas dobradas dentro do corpo —
#  enquanto parado ele fica correto. Recortando 8 instantes, o padrão é limpo:
#  parado OK, andando/correndo colapsado.
#
#  ⚠️ E NÃO É O PROBLEMA DOS CLIPES TOMBADOS. Aquele (11 dos 29 clipes do Mixamo
#  com `Torso.z` até −81°, em `docs/ESQUELETO.md`) é de clipe ASSADO. A
#  locomoção deste jogo é PROCEDURAL (`ProceduralAnimator.update`), então o
#  tombamento em movimento nasce em outro lugar — provavelmente no `lean` da
#  corrida, `ProceduralAnimator.gd:511`.
#
#  MEDIDA: o ângulo entre o "para cima" do Torso e a vertical do mundo. Parado
#  deve ser ~0°. É o mesmo número que o `ESQUELETO.md` usa para os clipes
#  ("o vetor para cima do torso fica a 51,4° da vertical"), então os dois casos
#  ficam comparáveis — que é o ponto de usar a MESMA medida para os dois.
# ============================================================================

const LIMITE := 25.0   # acima disto o corpo lê como "tombado" na tela

var _p: Node3D
var _torso: Node3D

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9

	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			_p = n
			break
	if _p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)

	_torso = _achar(_p, "Torso")
	if _torso == null:
		print("❌ não achei o nó Torso no modelo"); quit(1); return

	print("=== ângulo do tronco com a vertical (limite de leitura: %.0f°) ===" % LIMITE)
	print("estado           | médio | MÁXIMO | veredito")
	await _medir("parado",          [],                    70)
	await _medir("andando",         [KEY_W],               70)
	await _medir("correndo",        [KEY_W, KEY_SHIFT],    70)
	await _medir("andando de lado", [KEY_D],               70)
	await _medir("andando de re",   [KEY_S],               70)
	await _medir("pulando",         [KEY_SPACE],           70)
	await _medir("correndo+pulo",   [KEY_W, KEY_SHIFT, KEY_SPACE], 70)
	await _medir("dash (Q)",        [KEY_Q],               70)

	# --- acoes que trocam o corpo inteiro: corpo a corpo e as 4 skills ---
	# O corpo a corpo usa `play_baked`, e `play_baked` SOBREPOE O CORPO INTEIRO
	# (ver GuraPoses.gd:17). Ou seja, e por aqui que um clipe tombado entraria na
	# tela mesmo com a locomocao procedural comportada.
	_p.equip_fruit("mera_mera")
	await _medir_acao("soco (M1)", true, "")
	for slot in ["Z", "X", "C", "V"]:
		await _medir_acao("skill %s" % slot, false, slot)
	quit()

func _medir_acao(nome: String, mouse: bool, slot: String) -> void:
	_p.global_position = Vector3(0, 2.0, 0)
	_p.velocity = Vector3.ZERO
	_p._yaw = 0.0
	_p._pitch = -0.25
	_p._camera.apontar(0.0, -0.25)
	for i in 10:
		await process_frame
	if mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		Input.parse_input_event(ev)
	else:
		_p._skill_cooldowns[slot] = 0.0
		_p.energy = _p.max_energy
		_p._fire_skill(slot, Vector3(0, 0, -1), _p.global_position + Vector3.UP * 1.2)
	var soma := 0.0
	var maior := 0.0
	var n := 0
	for q in 80:
		await process_frame
		var cima: Vector3 = _torso.global_transform.basis.y.normalized()
		var ang := rad_to_deg(acos(clampf(cima.dot(Vector3.UP), -1.0, 1.0)))
		soma += ang
		maior = maxf(maior, ang)
		n += 1
	if mouse:
		var ev2 := InputEventMouseButton.new()
		ev2.button_index = MOUSE_BUTTON_LEFT
		ev2.pressed = false
		Input.parse_input_event(ev2)
	for i in 40:
		await process_frame
	var media := soma / float(maxi(n, 1))
	var veredito := "ok" if maior <= LIMITE else "❌ TOMBADO"
	print("%-16s | %5.1f | %6.1f | %s" % [nome, media, maior, veredito])

func _medir(nome: String, teclas: Array, quadros: int) -> void:
	_p.global_position = Vector3(0, 2.0, 0)
	_p.velocity = Vector3.ZERO
	_p._yaw = 0.0
	_p._pitch = -0.25
	_p._camera.apontar(0.0, -0.25)
	for k in teclas:
		_tecla(k, true)
	var soma := 0.0
	var maior := 0.0
	var n := 0
	for q in quadros:
		await process_frame
		if q < 15:
			continue   # deixa o estado assentar antes de contar
		var cima: Vector3 = _torso.global_transform.basis.y.normalized()
		var ang := rad_to_deg(acos(clampf(cima.dot(Vector3.UP), -1.0, 1.0)))
		soma += ang
		maior = maxf(maior, ang)
		n += 1
	for k in teclas:
		_tecla(k, false)
	# solta e deixa voltar ao repouso antes do proximo caso
	for i in 20:
		await process_frame
	var media := soma / float(maxi(n, 1))
	var veredito := "ok" if maior <= LIMITE else "❌ TOMBADO"
	print("%-16s | %5.1f | %6.1f | %s" % [nome, media, maior, veredito])

func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)

func _achar(raiz: Node, nome: String) -> Node3D:
	if raiz.name == nome and raiz is Node3D:
		return raiz
	for f in raiz.get_children():
		var r := _achar(f, nome)
		if r:
			return r
	return null
