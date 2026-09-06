extends SceneTree
# ============================================================================
#  A YORU E O COMBATE DE ESPADA — pedido do dono em 2026-09-06.
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/test_espada_yoru.gd
#
#  O que cada bloco defende:
#    1. o modelo entra virado certo — no `.glb` a lâmina aponta para -Y, e sem
#       a rotação de 180° a Yoru nasce apontando para o chão;
#    2. `handle` e `Hand_R` são nós NOMEADOS e o primeiro é filho do segundo —
#       era isso que o dono pediu para ter "referência de onde será segurada";
#    3. as bolinhas cobrem a lâmina inteira, da guarda à ponta, sem buraco
#       entre uma e outra (buraco = golpe que atravessa o alvo sem contar);
#    4. o combo é o PAR pedido: horizontal e depois vertical — e o segundo
#       clique pede mesmo a pose vertical, que era o bug escondido em usar o
#       índice do passo como tipo de corte;
#    5. bolinha encostando em corpo => dano, uma vez por golpe;
#    6. bolinha encostando na bolinha da OUTRA espada => choque, e os dois
#       golpes são anulados;
#    7. espada parada (desarmada) não causa choque — senão andar perto de
#       alguém já anularia o golpe dele.
# ============================================================================

var _falhas: Array[String] = []


func _init() -> void:
	var mundo := Node3D.new()
	get_root().add_child(mundo)
	await process_frame

	_t1_modelo(mundo)
	_t2_pega(mundo)
	_t3_bolinhas(mundo)
	_t4_combo()
	await _t5_dano(mundo)
	await _t6_choque(mundo)

	print("")
	if _falhas.is_empty():
		print("✓ ESPADA YORU: modelo, pega, zonas do fio, combo e choque")
		quit(0)
		return
	for f in _falhas:
		print("✗ ", f)
	print("XX  %d falha(s)" % _falhas.size())
	quit(1)


func _ok(c: bool, t: String) -> void:
	print(("✓ " if c else "✗ ") + t)
	if not c:
		_falhas.append(t)


# --------------------------------------------------------------- 1. o modelo
func _t1_modelo(mundo: Node3D) -> void:
	print("\n1. O MODELO ENTRA VIRADO CERTO")
	var e := YoruSword.new()
	mundo.add_child(e)
	var modelo := e.get_node_or_null("modelo") as Node3D
	_ok(modelo != null, "o .glb da Yoru carregou")
	if modelo == null:
		return
	# 180° em X: a lâmina do modelo (-Y) passa a apontar para +Y, que é o lado
	# em que a espada empunhada cresce a partir da mão.
	_ok(absf(modelo.rotation.x - PI) < 0.001,
		"girado 180° em X (lâmina -Y do modelo vira +Y da espada)")
	_ok(absf(modelo.position.y - YoruSword.CRU_PEGA_Y * YoruSword.ESCALA) < 0.001,
		"subido %.3f m para o cabo cair na origem" % (YoruSword.CRU_PEGA_Y * YoruSword.ESCALA))
	_ok(YoruSword.LAMINA_PONTA > YoruSword.LAMINA_BASE,
		"a lâmina vai de %.2f m a %.2f m acima da mão"
			% [YoruSword.LAMINA_BASE, YoruSword.LAMINA_PONTA])
	e.queue_free()


# ------------------------------------------------------------- 2. `handle`
func _t2_pega(mundo: Node3D) -> void:
	print("\n2. `handle` LIGADO À `Hand_R`")
	# A mão como o rig a monta: um Node3D nomeado no fim do antebraço.
	var mao := Node3D.new()
	mao.name = "Hand_R"
	mundo.add_child(mao)
	mao.position = Vector3(0.4, 1.2, 0.0)

	var espada := YoruSword.ligar_na_mao(mao)
	_ok(espada != null, "a espada foi ligada à mão")
	if espada == null:
		return
	var pega := espada.get_node_or_null("handle")
	_ok(pega != null, "existe um nó chamado `handle` na espada")
	_ok(espada.get_parent() == mao,
		"a espada é filha de `%s` — a pega não é offset, é parentesco" % mao.name)
	if pega != null:
		_ok(pega.global_position.distance_to(mao.global_position) < 0.001,
			"`handle` e `Hand_R` ocupam o MESMO ponto (%.4f m de folga)"
				% pega.global_position.distance_to(mao.global_position))
	mao.queue_free()


# ------------------------------------------------------------ 3. as bolinhas
func _t3_bolinhas(mundo: Node3D) -> void:
	print("\n3. AS ZONAS COBREM O FIO INTEIRO")
	var e := YoruSword.new()
	mundo.add_child(e)
	var fio := e.lamina
	_ok(fio != null, "a lâmina tem o nó de zonas")
	if fio == null:
		return
	var bolas: Array[Area3D] = []
	for n in fio.get_children():
		if n is Area3D:
			bolas.append(n as Area3D)
	_ok(bolas.size() == SwordBlade.QUANTAS,
		"%d bolinhas (esperado %d)" % [bolas.size(), SwordBlade.QUANTAS])

	var ys: Array[float] = []
	for b in bolas:
		ys.append(b.position.y)
	ys.sort()
	_ok(absf(ys[0] - YoruSword.LAMINA_BASE) < 0.01,
		"a primeira nasce na guarda (y=%.2f)" % ys[0])
	_ok(absf(ys[ys.size() - 1] - YoruSword.LAMINA_PONTA) < 0.01,
		"a última nasce na ponta (y=%.2f)" % ys[ys.size() - 1])

	# ⚠️ SEM BURACO ENTRE ELAS. Se o passo for maior que dois raios, sobra um
	# vão no meio da lâmina por onde o alvo passa sem levar nada — e o defeito
	# seria invisível, porque o golpe continuaria acertando às vezes.
	var maior_vao := 0.0
	for i in range(1, ys.size()):
		maior_vao = maxf(maior_vao, ys[i] - ys[i - 1])
	_ok(maior_vao <= SwordBlade.RAIO * 2.0,
		"sem vão entre as zonas: maior passo %.3f m, diâmetro %.3f m"
			% [maior_vao, SwordBlade.RAIO * 2.0])
	e.queue_free()


# ----------------------------------------------------------------- 4. o combo
func _t4_combo() -> void:
	print("\n4. O COMBO É HORIZONTAL, DEPOIS VERTICAL")
	_ok(Melee.COMBO_SWORD.size() == 2,
		"o combo tem 2 passos (tem %d)" % Melee.COMBO_SWORD.size())
	_ok(Melee.slash_type(0, "sword") == 0,
		"1º clique = corte HORIZONTAL (tipo %d)" % Melee.slash_type(0, "sword"))
	# ⚠️ O CASO QUE ESTAVA ESCONDIDO. O tipo do corte era o ÍNDICE do passo, e
	# funcionava por coincidência com três passos. Com dois, o índice 1 pediria
	# o segundo corte HORIZONTAL e o vertical nunca sairia.
	_ok(Melee.slash_type(1, "sword") == 2,
		"2º clique = corte VERTICAL (tipo %d, não o índice 1)"
			% Melee.slash_type(1, "sword"))
	_ok(Melee.tem_frame_data(0, "sword") and Melee.tem_frame_data(1, "sword"),
		"os dois passos têm frame data (startup/ativo/recuperação)")
	_ok(Balance.MELEE["espada"].size() == 2,
		"o Balance acompanha: %d valores de dano" % Balance.MELEE["espada"].size())

	# ⚠️ O CORTE PRECISA DURAR O QUE O FRAME DATA DIZ (bug relatado 2026-09-06).
	# Os cortes são procedurais e não têm clipe assado, e `duracao_tocada`
	# devolvia 0,0 nesse caso. O Player faz `speed = 1/max(dur, 0.1)`, ou seja
	# 10x: o corte inteiro passava em 0,1 s, o jogador clicava e nada de espada
	# aparecia — e o que sobrava em tela era a pose de repouso, indistinguível
	# de "o combo de punho continua no lugar da espada", que foi como o defeito
	# chegou. Aqui se cobra que a duração venha do frame data.
	for i in 2:
		var esperado := Melee.startup(i, "sword") + Melee.ativo(i, "sword") \
			+ Melee.recuperacao(i, "sword")
		var real := Melee.duracao_tocada(i, "sword")
		_ok(absf(real - esperado) < 0.001,
			"passo %d dura %.3f s (frame data diz %.3f) — velocidade %.1fx"
				% [i, real, esperado, 1.0 / maxf(real, 0.1)])


# ------------------------------------------------------------------ 5. o dano
func _t5_dano(mundo: Node3D) -> void:
	print("\n5. A BOLINHA ENCOSTA NO INIMIGO E ELE LEVA DANO")
	var dono := _Boneco.new()
	mundo.add_child(dono)
	dono.global_position = Vector3.ZERO
	var espada := YoruSword.new()
	dono.add_child(espada)
	await process_frame
	espada.lamina.dono = dono

	var alvo := _Alvo.new()
	mundo.add_child(alvo)
	# na altura do meio da lâmina, encostado nela
	alvo.global_position = Vector3(0, (YoruSword.LAMINA_BASE + YoruSword.LAMINA_PONTA) * 0.5, 0)
	await process_frame
	await process_frame

	_ok(alvo.levou == 0.0, "espada DESARMADA não machuca (%.0f)" % alvo.levou)

	espada.lamina.armar(64.0, 15.0, 0.75, 0, 0.0)
	# ⚠️ ESPERA DE TEMPO, NÃO DE QUADROS. `armar()` usa `set_deferred` no
	# `monitoring` (mexer nele durante a física é erro de "flushing queries"),
	# então ligar a zona custa um quadro E a sobreposição só é avaliada no
	# quadro de física seguinte. Contar `process_frame` na mão media cedo demais
	# e a primeira versão deste teste acusou "levou 0" numa espada que acertou.
	await create_timer(0.15).timeout
	_ok(alvo.levou > 0.0, "espada armada: o alvo levou %.0f" % alvo.levou)
	var primeiro := alvo.levou
	await create_timer(0.2).timeout
	_ok(alvo.levou == primeiro,
		"UM acerto por golpe, mesmo com 7 bolinhas em cima (%.0f)" % alvo.levou)

	dono.queue_free()
	alvo.queue_free()
	await process_frame


# ---------------------------------------------------------------- 6. o choque
func _t6_choque(mundo: Node3D) -> void:
	print("\n6. ESPADA CONTRA ESPADA ANULA OS DOIS GOLPES")
	var a := _Boneco.new()
	var b := _Boneco.new()
	mundo.add_child(a)
	mundo.add_child(b)
	a.global_position = Vector3(0, 0, 0)
	b.global_position = Vector3(0, 0, 0)      # as duas lâminas se cruzam
	var ea := YoruSword.new()
	var eb := YoruSword.new()
	a.add_child(ea)
	b.add_child(eb)
	await process_frame
	ea.lamina.dono = a
	eb.lamina.dono = b

	# 7. desarmada não choca
	ea.lamina.armar(64.0, 15.0, 0.75, 0, 0.0)
	await create_timer(0.15).timeout
	_ok(not a._melee.cancelado and not b._melee.cancelado,
		"espada armada contra espada PARADA não é choque")

	# agora as duas golpeando
	eb.lamina.armar(64.0, 15.0, 0.75, 0, 0.0)
	await create_timer(0.15).timeout

	_ok(a._melee.cancelado, "o golpe de quem atacou foi anulado")
	_ok(b._melee.cancelado, "o golpe do outro também foi anulado")
	_ok(not ea.lamina.esta_armada() and not eb.lamina.esta_armada(),
		"as duas lâminas ficaram desarmadas pelo choque")
	_ok(a._melee.cancelamentos == 1 and b._melee.cancelamentos == 1,
		"o choque resolveu UMA vez, não duas (%d e %d) — `area_entered` dispara nos dois lados"
			% [a._melee.cancelamentos, b._melee.cancelamentos])

	a.queue_free()
	b.queue_free()
	await process_frame


# ------------------------------------------------------------------- dublês
class _MeleeFalso extends Node:
	var cancelado := false
	var cancelamentos := 0
	func cancelar_golpe(_avisar: bool = true) -> void:
		cancelado = true
		cancelamentos += 1


class _Boneco extends CharacterBody3D:
	var _melee := _MeleeFalso.new()
	func _ready() -> void:
		add_to_group("player")
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		cs.shape = cap
		add_child(cs)
	func lock_movement(_d: float, _t: String = "") -> void:
		pass


class _Alvo extends CharacterBody3D:
	var levou := 0.0
	func _ready() -> void:
		add_to_group("enemy")
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		cs.shape = cap
		add_child(cs)
	func take_damage(v: float, _de: Vector3 = Vector3.ZERO,
			_kb: Vector3 = Vector3.ZERO, _hs: float = 0.3) -> void:
		levou += v
