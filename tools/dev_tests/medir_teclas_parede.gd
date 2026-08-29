extends SceneTree
# ============================================================================
#  PARA ONDE VAI CADA TECLA QUANDO O JOGADOR ANDA NA PAREDE
#
#  Relato do dono (2026-08-28): "as teclas A W S D na parede ficam invertidas —
#  o W e o S passam a ir para os lados e o A e o D para cima e para baixo.
#  Ocorre quando o jogador pula tendo como origem alguma parte próxima à
#  LATERAL do bloco."
#
#  Esta sonda não conserta nada: ela mede. Para cada ângulo de câmera, gruda na
#  parede, segura uma tecla e decompõe o deslocamento em dois eixos do PLANO da
#  parede:
#
#      SUBIDA = ao longo do "para cima" da parede (o UP do mundo projetado)
#      LADO   = ao longo da tangente horizontal
#
#  O que o jogador espera, e que o próprio código diz ser a intenção
#  ("Aí W anda parede acima e A/D andam de lado" — parkour_controller.gd:214):
#  W deve ser SUBIDA em qualquer ângulo de câmera, e A/D devem ser LADO em
#  qualquer ângulo. Se o eixo dominante do W mudar conforme o yaw, está achado.
#
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_teclas_parede.gd
# ============================================================================

# Ângulos de câmera medidos. A parede escolhida é a face −Z do bloco, então
# `yaw = PI` é encarar a parede de frente e `yaw = PI/2` é olhar ao LONGO dela —
# que é a postura de quem passou raspando pela lateral, o caso do relato.
const YAWS := [
	{"yaw": PI,          "nome": "de frente para a parede"},
	{"yaw": PI * 0.75,   "nome": "45 graus"},
	{"yaw": PI * 0.5,    "nome": "ao LONGO da parede (o caso do relato)"},
	{"yaw": PI * 1.25,   "nome": "45 graus para o outro lado"},
]
const QUADROS_DE_MEDIDA := 45

var _falhas := 0
var _linhas: Array[String] = []


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

	var junto := _achar_parede(p)
	if junto == Vector3.ZERO:
		print("❌ nao achei um bloco alto para servir de parede"); quit(1); return

	print("=== PARA ONDE VAI CADA TECLA, POR ANGULO DE CAMERA ===\n")
	for caso in YAWS:
		await _medir_angulo(p, junto, float(caso["yaw"]), str(caso["nome"]))

	print("\n=== VEREDITO ===")
	for l in _linhas:
		print(l)
	print("\n%s" % ("✅ as teclas mantem o mesmo eixo em todos os angulos"
		if _falhas == 0 else "❌ %d angulo(s) com as teclas trocadas" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _medir_angulo(p: Node3D, junto: Vector3, yaw: float, nome: String) -> void:
	print("-- camera %s (yaw %.0f graus) --" % [nome, rad_to_deg(yaw)])
	if not await _grudar(p, junto):
		print("   ⚠️  nao grudou; angulo pulado\n")
		return

	# Gira a câmera DEPOIS de grudar: a base persegue a câmera por slerp, então
	# é assim que o jogador chega neste ângulo sem largar a parede.
	p._yaw = yaw
	p._camera.apontar(yaw, -0.1)
	for i in 40:
		await process_frame
	if not p._parkour.na_parede():
		print("   ⚠️  soltou da parede ao girar a camera; angulo pulado\n")
		return

	var n: Vector3 = p._parkour.normal_da_parede()
	# Os dois eixos do plano da parede, definidos pela GEOMETRIA e não pela
	# câmera — é contra eles que o movimento é julgado.
	var sobe: Vector3 = (Vector3.UP - n * Vector3.UP.dot(n))
	if sobe.length_squared() < 0.001:
		print("   ⚠️  superficie horizontal; angulo pulado\n")
		return
	sobe = sobe.normalized()
	var lado: Vector3 = n.cross(sobe).normalized()

	for t in [{"k": KEY_W, "n": "W"}, {"k": KEY_S, "n": "S"},
			{"k": KEY_A, "n": "A"}, {"k": KEY_D, "n": "D"}]:
		var d := await _deslocamento(p, junto, yaw, int(t["k"]))
		var s: float = d.dot(sobe)
		var l: float = d.dot(lado)
		var dominante := "SUBIDA" if absf(s) > absf(l) else "LADO"
		print("   %s -> subida %+6.2f m | lado %+6.2f m | dominante: %s"
			% [t["n"], s, l, dominante])
		var esperado := "SUBIDA" if t["n"] in ["W", "S"] else "LADO"
		if dominante != esperado:
			_falhas += 1
			_linhas.append("   ✗ camera %s: %s deveria ser %s e virou %s"
				% [nome, t["n"], esperado, dominante])
	print("")


# Gruda e devolve o deslocamento causado por segurar uma tecla.
func _deslocamento(p: Node3D, junto: Vector3, yaw: float, k: int) -> Vector3:
	if not await _grudar(p, junto):
		return Vector3.ZERO
	p._yaw = yaw
	p._camera.apontar(yaw, -0.1)
	for i in 40:
		await process_frame
	if not p._parkour.na_parede():
		return Vector3.ZERO
	var antes: Vector3 = p.global_position
	_tecla(k, true)
	for i in QUADROS_DE_MEDIDA:
		await process_frame
	_tecla(k, false)
	var d: Vector3 = p.global_position - antes
	for i in 5:
		await process_frame
	return d


# ⚠️ DOIS TOQUES DE ESPAÇO, e não é atalho de teste: no chão o espaço é PULO. O
# primeiro tira do chão, o segundo — já no ar e contra a parede — é o que gruda.
func _grudar(p: Node3D, junto: Vector3) -> bool:
	if p._parkour.na_parede():
		p._parkour._soltar_da_parede(false)
	p.global_position = junto
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p._yaw = PI                      # para grudar é preciso ir CONTRA a parede
	p._camera.apontar(PI, -0.1)
	for i in 25:
		await process_frame
	_tecla(KEY_W, true)
	for i in 10:
		await process_frame
	_tecla(KEY_SPACE, true)
	for i in 4:
		await process_frame
	_tecla(KEY_SPACE, false)
	for i in 12:
		await process_frame
	_tecla(KEY_SPACE, true)
	for i in 4:
		await process_frame
	_tecla(KEY_SPACE, false)
	var grudou := false
	for i in 60:
		await process_frame
		if p._parkour.na_parede():
			grudou = true
			break
	_tecla(KEY_W, false)
	for i in 5:
		await process_frame
	return grudou


func _achar_parede(p: Node3D) -> Vector3:
	for n in _todos(get_root()):
		if not (n is StaticBody3D) or n.name == "Plataforma":
			continue
		var b := n as Node3D
		if b.scale.y < 5.0:
			continue
		if Vector2(b.global_position.x, b.global_position.z).length() > 70.0:
			continue
		return b.global_position + Vector3(0, 1.0, -(b.scale.z * 0.5 + 0.45))
	return Vector3.ZERO


func _todos(n: Node) -> Array:
	var r: Array = [n]
	for c in n.get_children():
		r.append_array(_todos(c))
	return r


func _tecla(c: Key, d: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = c
	e.keycode = c
	e.pressed = d
	Input.parse_input_event(e)
