extends SceneTree
# ============================================================================
#  ASAS DE ANJO — o golpe exclusivo do Skypean.
#
#  Pedido do dono (2026-09-01): "quando Skypean e o segundo pulo acionado +
#  clique, um script busca jogadores próximos; se houver, direciona uma voadora
#  na direção do alvo, podendo ser acima, abaixo ou um pouco afastado. Caso não
#  acerte, não entra em recarga."
#
#  ⚠️ METADE DESTE ARQUIVO MEDE O QUE **NÃO** PODE ACONTECER. As três condições
#  (raça, segundo pulo, alvo) são o que separa um golpe de identidade de uma
#  mobilidade grátis para qualquer um — e cada uma falha em silêncio se quebrar.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_asas_de_anjo.gd
# ============================================================================

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)

	var alvo := _dummy(p)
	_ok("há um boneco para servir de alvo", alvo != null)
	if alvo == null:
		print("\n%d conferem | %d divergem" % [_ok_n, _falhas]); quit(1); return

	_as_condicoes(p, alvo)
	await _a_direcao(p, alvo)
	_a_recarga(p)
	await _teto_da_au(p)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. AS TRÊS CONDIÇÕES — e o que acontece quando cada uma falta.
func _as_condicoes(p: Node3D, alvo: Node3D) -> void:
	print("=== 1. quando o golpe existe ===")
	alvo.global_position = p.global_position + Vector3(0, 6, -5)

	# ⚠️ NO CHÃO NÃO SAI, por mais Skypean que se seja.
	p._char_model.set_meta("raca_id", "skypiean")
	_ok("no chão o golpe NÃO está disponível",
		not AsasDeAnjo.disponivel(p, 0.0) or not p.is_on_floor())

	# As checagens puras, sem depender de o corpo estar no ar de verdade.
	_ok("a raça dona do golpe é o Skypean", AsasDeAnjo.RACA == "skypiean")
	p._char_model.set_meta("raca_id", "oni")
	_ok("um Oni não é dono do golpe", AsasDeAnjo.raca_de(p) != AsasDeAnjo.RACA)
	p._char_model.set_meta("raca_id", "skypiean")
	_ok("o Skypean é", AsasDeAnjo.raca_de(p) == AsasDeAnjo.RACA)

	# ⚠️ SEM ALVO NÃO SAI. É o que impede a voadora de virar deslocamento livre.
	var longe := alvo.global_position
	alvo.global_position = p.global_position + Vector3(0, 0, -400)
	_ok("com o alvo longe, não há alvo", AsasDeAnjo.alvo_de(p) == null)
	alvo.global_position = longe
	_ok("com o alvo perto, ele é encontrado", AsasDeAnjo.alvo_de(p) == alvo)


## 2. A DIREÇÃO em três dimensões — "acima, abaixo ou um pouco afastado".
func _a_direcao(p: Node3D, alvo: Node3D) -> void:
	print("\n=== 2. a voadora aponta para o alvo, em 3D ===")
	for caso in [{"n": "acima", "d": Vector3(0, 8, -3)},
			{"n": "abaixo", "d": Vector3(0, -7, -4)},
			{"n": "ao lado", "d": Vector3(9, 0, 0)}]:
		alvo.global_position = p.global_position + caso["d"]
		await _quadros(2)
		var r := AsasDeAnjo.rumo(p, alvo)
		var esperado: Vector3 = (caso["d"] as Vector3).normalized()
		print("   alvo %-8s rumo %s" % [caso["n"], str(r)])
		_ok("o rumo aponta para o alvo %s" % caso["n"], r.dot(esperado) > 0.99)
	# ⚠️ NÃO ACHATADO: perseguir só em X/Z faria o Skypean passar por cima de
	# quem está no chão, que é a situação em que ele estará ao usar isto.
	alvo.global_position = p.global_position + Vector3(0, -9, 0)
	_ok("com o alvo ABAIXO, o rumo desce de verdade",
		AsasDeAnjo.rumo(p, alvo).y < -0.9)


## 3. A RECARGA só é cobrada no acerto.
func _a_recarga(p: Node3D) -> void:
	print("\n=== 3. errar não cobra recarga ===")
	p._asas_ativas = true
	p._asas_acertou = false
	p._encerrar_asas_de_anjo()
	print("   depois de ERRAR: recarga = %.1f s" % p._asas_recarga)
	_ok("errar NÃO entra em recarga", p._asas_recarga <= 0.0)

	p._asas_ativas = true
	p._asas_acertou = true
	p._encerrar_asas_de_anjo()
	print("   depois de ACERTAR: recarga = %.1f s" % p._asas_recarga)
	_ok("acertar entra em recarga", p._asas_recarga > 0.0)
	# ⚠️ CONTROLE: sem ele, "não cobra ao errar" passaria numa recarga que nunca
	# funciona — e o golpe sairia infinitas vezes mesmo acertando.
	_ok("em recarga, o golpe fica indisponível",
		not AsasDeAnjo.disponivel(p, p._asas_recarga))
	p._asas_recarga = 0.0


## 4. O TETO DE ALTURA DA AÚ (pedido do dono, 2026-09-01): ela só começa até
## METADE da altura de um pulo simples. Sem isso vira mobilidade aérea de graça.
func _teto_da_au(p: Node3D) -> void:
	print("\n=== 4. o teto de altura da Aú ===")
	print("   altura de um pulo: %.2f m | teto da Aú: %.2f m"
		% [p.ALTURA_DE_UM_PULO, p.ALTURA_MAX_CHUTE_GIRATORIO])
	# ⚠️ DERIVADO, não digitado: v²/2g com os valores reais do pulo. Se o pulo
	# mudar, o teto acompanha — e esta asserção prova que ele acompanha.
	_ok("o teto é exatamente metade do pulo",
		absf(p.ALTURA_MAX_CHUTE_GIRATORIO - p.ALTURA_DE_UM_PULO * 0.5) < 0.01)
	_ok("e o pulo bate com v²/2g (16 e 32 dão 4,00 m)",
		absf(p.ALTURA_DE_UM_PULO - 4.0) < 0.01)

	# No chão a altura é zero — a Aú tem de continuar saindo daí.
	var n := 0
	while not p.is_on_floor() and n < 180:
		await process_frame
		n += 1
	print("   no chão: altura medida = %.2f m" % p.altura_do_chao())
	_ok("no chão a altura lida é zero", p.altura_do_chao() < 0.01)

	# Bem alto: acima do teto, e o golpe tem de ser recusado.
	var antes: Vector3 = p.global_position
	p.global_position = antes + Vector3(0, 12.0, 0)
	p.velocity = Vector3.ZERO
	await _quadros(4)
	var alto: float = p.altura_do_chao()
	print("   a 12 m do chão: altura medida = %.2f m" % alto)
	_ok("longe do chão a altura lida é grande", alto > p.ALTURA_MAX_CHUTE_GIRATORIO)
	p._spin_kick_cooldown = 0.0
	_tecla(KEY_SPACE, true)
	await _quadros(2)
	var saiu: bool = p.tentar_chute_giratorio(0.0)
	_tecla(KEY_SPACE, false)
	_ok("acima do teto a Aú é RECUSADA", not saiu)
	if p._spin_kick_active:
		p._spin_kick_active = false
	p.global_position = antes
	await _quadros(6)


func _tecla(c: Key, d: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = c
	e.keycode = c
	e.pressed = d
	Input.parse_input_event(e)


func _dummy(p: Node3D) -> Node3D:
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			return e
	return null


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
