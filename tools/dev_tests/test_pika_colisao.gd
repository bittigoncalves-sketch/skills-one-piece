extends SceneTree
# ============================================================================
#  COLISÃO DA PIKA PIKA — o que estava quebrado em 2026-09-06.
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/test_pika_colisao.gd
#
#  Árvore nua com chão de verdade: o `test_pika_yasakani` prova a FORMA do
#  golpe (leque, rastros, vazamento) e não precisa de mapa. Aqui o assunto é
#  colisão, e colisão sem chão e sem parede não se testa.
#
#  Cada checagem existe porque a coisa correspondente ESTAVA ERRADA:
#
#    1. o raspão — a varredura era um `intersect_ray`, e raio não tem
#       espessura: entre dois quadros a hitbox virava a linha do centro dela.
#       Alvo a 0,45 m do eixo saía ileso de um raio anunciado com 0,32 m.
#    2. o raio parava? — a cabeça seguia viagem depois de acertar, e o clarão
#       de impacto nascia 40 m adiante do corpo atravessado.
#    3. parede — mesma causa: o Yasakani atravessava cenário.
#    4. o X e a gente — o clamp do ziguezague travava 1 m antes de QUALQUER
#       personagem, porque neste projeto gente e mapa moram na mesma camada.
#    5. o X e o buraco — a perna viaja em altura fixa e esta arena mata quem
#       cai (`Scoreboard.VOID_Y`). Nada olhava para baixo.
#    6. linha de visão — a explosão do mergulho tem 4,5 m de esfera e
#       atravessava muro.
# ============================================================================

var _falhas: Array[String] = []


func _init() -> void:
	var mundo := Node3D.new()
	get_root().add_child(mundo)
	await process_frame

	_piso(mundo, Vector3(0, -0.5, -25), Vector3(60, 1, 90))
	await process_frame
	await process_frame

	await _t1_raspao(mundo)
	await _t2_para_no_acerto(mundo)
	await _t3_para_na_parede(mundo)
	await _t4_x_ignora_gente(mundo)
	await _t5_x_evita_buraco(mundo)
	await _t6_explosao_com_cobertura(mundo)

	print("")
	if _falhas.is_empty():
		print("✓ COLISÃO DA PIKA: tudo passou")
		quit(0)
		return                 # `quit` agenda a saída; sem isto o resto ainda roda
	for f in _falhas:
		print("✗ ", f)
	print("XX  %d falha(s)" % _falhas.size())
	quit(1)


func _ok(condicao: bool, texto: String) -> void:
	print(("✓ " if condicao else "✗ ") + texto)
	if not condicao:
		_falhas.append(texto)


# ------------------------------------------------------------------ 1. raspão
# A fronteira geométrica é raio da cápsula (0,40) + raio da hitbox (0,32) =
# 0,72 m. Acerta ATÉ ali e erra depois — se errasse antes, a hitbox estaria
# mentindo de novo, só que para o outro lado.
func _t1_raspao(mundo: Node3D) -> void:
	print("\n1. RASPÃO — o alvo fora do eixo central")
	for desvio in [0.0, 0.45, 0.60]:
		var levou := await _tiro_em(mundo, desvio)
		_ok(levou > 0.0, "desvio de %.2f m: acertou (dano %.0f)" % [desvio, levou])
	var longe := await _tiro_em(mundo, 0.95)
	_ok(longe == 0.0, "desvio de 0.95 m: erra, como manda a geometria (dano %.0f)" % longe)


func _tiro_em(mundo: Node3D, desvio: float) -> float:
	var alvo := _Alvo.new()
	mundo.add_child(alvo)
	alvo.global_position = Vector3(desvio, 1.25, -14.0)
	await process_frame
	await process_frame

	var zona := DamageZone.new()
	mundo.add_child(zona)
	zona.global_position = Vector3(0, 1.25, -2.0)
	zona.setup(10.0, 5.0, Vector3(0, 0, -PikaFX.VELOCIDADE),
		PikaFX.ALCANCE / PikaFX.VELOCIDADE, null, PikaFX.RAIO_HITBOX)
	await create_timer(0.30).timeout
	var levou: float = alvo.levou
	alvo.queue_free()
	if is_instance_valid(zona):
		zona.set("vel", Vector3.ZERO)
	await process_frame
	return levou


# --------------------------------------------------- 2. a cabeça para no alvo
func _t2_para_no_acerto(mundo: Node3D) -> void:
	print("\n2. A CABEÇA PARA ONDE ACERTA")
	var alvo := _Alvo.new()
	mundo.add_child(alvo)
	alvo.global_position = Vector3(0, 1.25, -12.0)
	await process_frame
	await process_frame

	var caster := _CasterFalso.new()
	mundo.add_child(caster)
	caster.global_position = Vector3(0, 0, 0)
	await process_frame

	var por_hit: float = DamageSpec.avulso(30.0).valor_do_hit()
	PikaFX.cast(mundo, Vector3(0, 1.25, 0), Vector3(0, 0, -1), 0, 30.0,
		caster, DamageSpec.avulso(30.0))

	# ⚠️ AMOSTRA DURANTE O VOO, e a primeira versão amostrava DEPOIS — errado, e
	# de um jeito que passaria despercebido. A vida de cada cabeça é
	# ALCANCE/VELOCIDADE = 0,51 s a partir do nascimento dela, então quando a
	# salva inteira termina o `autofree` já recolheu as primeiras: contar no fim
	# achava 1 cabeça parada num golpe que parou 3. Cada uma é registrada por
	# `instance_id` no quadro em que é marcada, e o registro sobrevive à coleta.
	var paradas: Dictionary = {}
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 1300:
		for n in mundo.get_children():
			if n is Area3D and n.is_in_group("hitbox") \
					and bool(n.get_meta("pika_encerrado", false)) \
					and not paradas.has(n.get_instance_id()):
				paradas[n.get_instance_id()] = (n as Area3D).global_position.z
		await process_frame

	# ⚠️ NÃO se exige que NENHUM raio passe do alvo. O leque abre 9,7°
	# (`ESPALHAMENTO`), então a 12 m os raios das pontas estão ~2 m de lado e
	# passam longe de um alvo de 0,8 m de largura — eles DEVEM seguir viagem. O
	# que se cobra é o par: toda cabeça que parou parou JUNTO DO ALVO, e o
	# número de cabeças paradas bate com o de acertos que o alvo contabilizou.
	var parou_perto := 0
	var parou_longe := 0
	for z in paradas.values():
		if absf(float(z) + 12.0) < 2.5:
			parou_perto += 1
		else:
			parou_longe += 1
	var acertos := int(round(alvo.levou / por_hit))
	_ok(parou_perto > 0,
		"%d cabeça(s) pararam junto do alvo (z≈-12)" % parou_perto)
	_ok(parou_longe == 0,
		"nenhuma cabeça parou longe do que acertou (%d pararam)" % parou_longe)
	_ok(parou_perto == acertos,
		"cabeças paradas (%d) = acertos contabilizados (%d)" % [parou_perto, acertos])
	_ok(alvo.levou > 0.0, "o alvo levou dano (%.0f)" % alvo.levou)
	_ok(caster.hitstops == 1,
		"o peso do acerto disparou uma vez (%d hitstop)" % caster.hitstops)
	_limpar(mundo)


# ------------------------------------------------------------- 3. parede
func _t3_para_na_parede(mundo: Node3D) -> void:
	print("\n3. A CABEÇA PARA NA PAREDE")
	var muro := _piso(mundo, Vector3(0, 2, -10), Vector3(12, 6, 1))
	await process_frame
	await process_frame

	PikaFX.cast(mundo, Vector3(0, 1.25, 0), Vector3(0, 0, -1), 0, 30.0,
		null, DamageSpec.avulso(30.0))
	await create_timer(0.95).timeout

	var atravessou := 0
	for n in mundo.get_children():
		if n is Area3D and n.is_in_group("hitbox"):
			if (n as Area3D).global_position.z < -11.5:
				atravessou += 1
	_ok(atravessou == 0, "nenhum raio atravessou o muro (%d atravessaram)" % atravessou)
	muro.queue_free()
	_limpar(mundo)


# ------------------------------------------- 4. o X não trava em personagem
func _t4_x_ignora_gente(mundo: Node3D) -> void:
	print("\n4. O ZIGUEZAGUE DO X NÃO TRAVA EM GENTE")
	var caster := _CasterFalso.new()
	caster.add_to_group("player")
	mundo.add_child(caster)
	caster.global_position = Vector3(0, 1.0, 0)

	# Um transeunte bem no meio da primeira perna, longe o bastante do
	# RAIO_DETECCAO para não virar alvo do mergulho e encurtar a viagem.
	var gente := _Alvo.new()
	gente.add_to_group("player")
	mundo.add_child(gente)
	gente.global_position = Vector3(-2.5, 1.0, -3.5)
	await process_frame
	await process_frame

	PikaFX.cast(mundo, caster.global_position, Vector3(0, 0, -1), 1, 160.0,
		caster, DamageSpec.avulso(160.0))
	var avanco := 0.0
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 1200:
		avanco = maxf(avanco, absf(caster.global_position.z))
		await process_frame
	_ok(avanco > 15.0,
		"a viagem avançou %.1f m com um personagem no caminho (esperado ~21)" % avanco)
	_limpar(mundo)


# --------------------------------------------------- 5. o X recua do buraco
func _t5_x_evita_buraco(mundo: Node3D) -> void:
	print("\n5. O X NÃO É LARGADO SOBRE O VAZIO")
	# Piso curto: acaba em z = -10. Além dali é buraco, e cair mata.
	var curto := _piso(mundo, Vector3(0, -0.5, -5), Vector3(60, 1, 10))
	var chao_grande := mundo.get_node_or_null("PisoPrincipal")
	if chao_grande != null:
		chao_grande.process_mode = Node.PROCESS_MODE_DISABLED
		(chao_grande as StaticBody3D).collision_layer = 0
	await process_frame
	await process_frame

	var caster := _CasterFalso.new()
	mundo.add_child(caster)
	caster.global_position = Vector3(0, 1.0, 0)
	await process_frame

	PikaFX.cast(mundo, caster.global_position, Vector3(0, 0, -1), 1, 160.0,
		caster, DamageSpec.avulso(160.0))
	var mais_longe := 0.0
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 1200:
		mais_longe = maxf(mais_longe, absf(caster.global_position.z))
		await process_frame
	_ok(mais_longe <= 11.0,
		"a viagem parou em %.1f m, dentro do piso que acaba em 10 m" % mais_longe)

	curto.queue_free()
	if chao_grande != null:
		chao_grande.process_mode = Node.PROCESS_MODE_INHERIT
		(chao_grande as StaticBody3D).collision_layer = 1
	_limpar(mundo)


# ------------------------------------------------ 6. explosão e a cobertura
func _t6_explosao_com_cobertura(mundo: Node3D) -> void:
	print("\n6. A EXPLOSÃO DO MERGULHO RESPEITA COBERTURA")
	var zona := DamageZone.new()
	mundo.add_child(zona)
	zona.global_position = Vector3(0, 0.5, -20)
	zona.exige_linha_de_visao = true
	zona.origem_linha_de_visao = Vector3(0, 0.7, -20)

	var muro := _piso(mundo, Vector3(0, 1.5, -21.5), Vector3(10, 4, 0.6))
	var atras := _Alvo.new()
	mundo.add_child(atras)
	atras.global_position = Vector3(0, 0.9, -23.0)
	var na_frente := _Alvo.new()
	mundo.add_child(na_frente)
	na_frente.global_position = Vector3(0, 0.9, -18.0)
	await process_frame

	zona.setup(50.0, 26.0, Vector3.ZERO, 0.30, null, PikaFX.RAIO_EXPLOSAO)
	await create_timer(0.35).timeout

	_ok(na_frente.levou > 0.0,
		"quem estava exposto levou a explosão (%.0f)" % na_frente.levou)
	_ok(atras.levou == 0.0,
		"quem estava atrás do muro NÃO levou (%.0f)" % atras.levou)
	muro.queue_free()
	_limpar(mundo)


# ------------------------------------------------------------------- apoio
func _piso(mundo: Node3D, centro: Vector3, tamanho: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	if mundo.get_node_or_null("PisoPrincipal") == null:
		corpo.name = "PisoPrincipal"
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	cs.shape = caixa
	corpo.add_child(cs)
	mundo.add_child(corpo)
	corpo.global_position = centro
	return corpo


# ⚠️ AS HITBOXES NÃO SÃO LIBERADAS À MÃO, e isso é de propósito. Quem é dono do
# ciclo de vida delas é o `FxUtil.autofree`, que agenda um temporizador com o nó
# CAPTURADO numa lambda. Liberar por fora funciona (o `autofree` checa
# `is_instance_valid`), mas a cada uma o Godot cospe "Lambda capture at index 0
# was freed" — ruído que, num teste, esconde o erro de verdade na próxima vez.
# Então aqui só somem os nós que ninguém mais governa, e as zonas expiram no
# tempo delas: a vida de uma cabeça é ALCANCE/VELOCIDADE = 0,51 s.
func _limpar(mundo: Node3D) -> void:
	for n in mundo.get_children():
		if n is _Alvo or n is _CasterFalso:
			n.queue_free()
	await create_timer(0.75).timeout


class _Alvo extends CharacterBody3D:
	var levou := 0.0
	func _ready() -> void:
		if not is_in_group("enemy") and not is_in_group("player"):
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


class _AnimadorFalso extends Node:
	var dono = null
	func trigger_hitstop(_d: float, _s: float = 0.04) -> void:
		if dono: dono.hitstops += 1


class _CameraFalsa extends Node:
	var dono = null
	func pedir_shake(_q: float) -> void:
		if dono: dono.shakes += 1
	func pedir_fov_punch(_q: float) -> void:
		if dono: dono.fovs += 1


class _CasterFalso extends CharacterBody3D:
	var hitstops := 0
	var shakes := 0
	var fovs := 0
	var _proc_anim: _AnimadorFalso = null
	var _camera: _CameraFalsa = null

	func _ready() -> void:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		cs.shape = cap
		add_child(cs)
		_proc_anim = _AnimadorFalso.new()
		_proc_anim.dono = self
		add_child(_proc_anim)
		_camera = _CameraFalsa.new()
		_camera.dono = self
		add_child(_camera)

	func lock_movement(_d: float, _t: String = "") -> void:
		pass
