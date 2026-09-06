extends SceneTree
# ============================================================================
#  PIKA PIKA — Z (Salva de Luz legada) e X. Teste de UNIDADE.
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/test_pika_yasakani.gd
#
#  ⚠️ NÃO SOBE O JOGO, DE PROPÓSITO. A porta 24565 não paraleliza, e a bateria
#  do `validar.sh` roda em série justamente por causa disso — um teste a mais
#  que hospeda custaria mais meio minuto a toda rodada. Aqui basta uma árvore
#  nua: o que se mede é a salva, não a partida.
#
#  O que ele responde, e por que cada um importa:
#    1. o leque abre para os DOIS lados e continua apontando para frente
#       — leque torto manda metade da salva para trás do jogador;
#    2. a salva cria as 7 hitboxes
#       — foi golpe "rodando" sem hitbox nenhuma que escondeu três frutas
#         quebradas por meses (docs/erros.md, 2026-08-10);
#    3. o rastro nasce e some sozinho
#       — rastro que fica é vazamento de nó, e o `test_frutas` cobra isso;
#    4. a Callable de método ESTÁTICO agendada por timer dispara mesmo
#       — é a linha mais frágil do PikaFX e o compilador não a valida.
# ============================================================================

const ESPERADO_FEIXES := 7


func _init() -> void:
	var falhas: Array[String] = []

	var mundo := Node3D.new()
	get_root().add_child(mundo)
	await process_frame

	# ---------------------------------------------------- 1. o leque
	var fwd := Vector3(0, 0, -1)
	var dirs: Array[Vector3] = []
	for i in ESPERADO_FEIXES:
		dirs.append(PikaFX._direcao_do_leque(fwd, i))

	var para_frente := true
	for d in dirs:
		if d.dot(fwd) < 0.9:
			para_frente = false
	if not para_frente:
		falhas.append("leque abriu demais: algum raio saiu com menos de 0.9 de frente")

	var lado := fwd.cross(Vector3.UP).normalized()
	var esq := 0
	var dir_ := 0
	for d in dirs:
		var proj := d.dot(lado)
		if proj < -0.01: esq += 1
		elif proj > 0.01: dir_ += 1
	if esq == 0 or dir_ == 0:
		falhas.append("leque unilateral: %d à esquerda, %d à direita" % [esq, dir_])
	if esq != dir_:
		falhas.append("leque assimétrico: %d à esquerda, %d à direita" % [esq, dir_])

	var meio := dirs[ESPERADO_FEIXES / 2]
	if absf(meio.dot(lado)) > 0.01:
		falhas.append("o raio do meio não sai reto (desvio lateral %.4f)" % meio.dot(lado))

	# determinístico: duas chamadas dão o mesmo vetor
	if PikaFX._direcao_do_leque(fwd, 0) != dirs[0]:
		falhas.append("o leque não é determinístico entre chamadas")

	print("1. leque ............. %d raios, %d/%d esq/dir, meio reto" % [dirs.size(), esq, dir_])

	# --------------------------------- 2/4. a salva cria as hitboxes de verdade
	var antes := _contar(mundo, "DamageZone")
	var spec := DamageSpec.avulso(30.0)
	PikaFX.cast(mundo, Vector3.ZERO, fwd, 0, 30.0, null, spec)

	# carga (0,22) + 7 x intervalo (0,055) + folga: a salva inteira cabe em ~0,7 s
	var pico := 0
	var pico_rastro := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		pico = maxi(pico, _contar(mundo, "DamageZone"))
		pico_rastro = maxi(pico_rastro, _contar(mundo, "PikaRastro"))
		await process_frame

	var criadas := pico - antes
	if criadas < ESPERADO_FEIXES:
		falhas.append("a salva criou %d hitbox(es), esperado %d — a Callable estática do timer pode não ter disparado"
			% [criadas, ESPERADO_FEIXES])
	print("2/4. salva ........... %d hitboxes (esperado %d)" % [criadas, ESPERADO_FEIXES])

	# O pico, não um instante solto: os primeiros rastros já morreram quando o
	# último nasce, então medir no fim dá zero num golpe correto.
	if pico_rastro < ESPERADO_FEIXES:
		falhas.append("pico de %d rastro(s), esperado %d — cada raio tem que deixar rastro"
			% [pico_rastro, ESPERADO_FEIXES])
	print("3a. rastros .......... pico de %d (esperado %d)" % [pico_rastro, ESPERADO_FEIXES])

	# ------------------------------------------------- 3. nada fica pendurado
	# alcance/velocidade = 0,51 s de voo, + 0,16 s de rastro morrendo
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 2500:
		await process_frame

	var sobrou_zona := _contar(mundo, "DamageZone")
	var sobrou_rastro := _contar(mundo, "PikaRastro")
	if sobrou_zona > antes:
		falhas.append("vazou %d DamageZone depois do golpe" % (sobrou_zona - antes))
	if sobrou_rastro > 0:
		falhas.append("vazou %d rastro depois do golpe" % sobrou_rastro)
	print("3b. depois do golpe .. %d zonas, %d rastros (esperado 0 e 0)" % [sobrou_zona, sobrou_rastro])

	# -------------------------------------- 5. o PESO no acerto dispara mesmo
	# Sem alvo, a captura nunca exercita este caminho: o gravador congela e
	# afasta os inimigos. Aqui um caster de mentira com dublês de animador e
	# camera prova que hitstop, tremor e soco de FOV sao realmente PEDIDOS.
	var caster := _CasterFalso.new()
	caster.name = "CasterFalso"
	mundo.add_child(caster)
	caster.global_position = Vector3(0, 0, 0)

	var alvo := _AlvoFalso.new()
	alvo.add_to_group("enemy")
	var forma := CollisionShape3D.new()
	var esf := SphereShape3D.new()
	esf.radius = 2.0
	forma.shape = esf
	alvo.add_child(forma)
	mundo.add_child(alvo)
	alvo.global_position = Vector3(0, 1.25, -8.0)
	await process_frame

	PikaFX.cast(mundo, Vector3(0, 1.25, 0), fwd, 0, 30.0, caster, DamageSpec.avulso(30.0))
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 1500:
		await process_frame

	if caster.hitstops == 0:
		falhas.append("nenhum hitstop pedido ao acertar um corpo do grupo 'enemy'")
	if caster.shakes == 0:
		falhas.append("nenhum tremor de camera pedido no acerto")
	if caster.hitstops > 1:
		falhas.append("%d hitstops numa salva so — sete seguidos travariam o jogo"
			% caster.hitstops)
	print("5. peso no acerto .... %d hitstop, %d tremor, %d soco de FOV (esperado 1,1,1)"
		% [caster.hitstops, caster.shakes, caster.fovs])

	# ------------------------- 6. o X: ziguezague e o mergulho com explosao
	# O gravador congela e AFASTA os inimigos (z = -900), entao a captura nunca
	# exercita o finalizador. Aqui o alvo e posto no caminho de proposito.
	var caster2 := _CasterFalso.new()
	caster2.name = "CasterX"
	mundo.add_child(caster2)
	caster2.global_position = Vector3(0, 1.0, 0)

	var vitima := _AlvoFalso.new()
	vitima.add_to_group("enemy")
	var f2 := CollisionShape3D.new()
	var e2 := SphereShape3D.new()
	e2.radius = 1.0
	f2.shape = e2
	vitima.add_child(f2)
	mundo.add_child(vitima)
	# dentro do RAIO_DETECCAO da primeira perna (avanco 7 m, lateral -5 m)
	vitima.global_position = Vector3(-4.0, 1.0, -7.0)
	await process_frame

	var partiu := caster2.global_position
	PikaFX.cast(mundo, partiu, fwd, 1, 160.0, caster2, DamageSpec.avulso(160.0))

	var andou_lateral := 0.0
	# ⚠️ PICO, nao posicao final. A primeira versao media onde o jogador PAROU e
	# acusava "avancou so 7 m": o X avanca os 21 m do ziguezague e depois VOLTA
	# para cair sobre o alvo, que estava a 7 m. O codigo estava certo e o teste
	# errado — medir o fim de uma viagem que termina em teleporte nao diz nada.
	var avanco_max := 0.0
	var explodiu := 0
	var t3 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t3 < 2200:
		andou_lateral = maxf(andou_lateral, absf(caster2.global_position.x - partiu.x))
		avanco_max = maxf(avanco_max, absf(caster2.global_position.z - partiu.z))
		for n in mundo.get_children():
			if n is Area3D and n.is_in_group("hitbox") and n.get_parent() == mundo:
				var r := (n as Area3D).global_position
				if r.distance_to(vitima.global_position) < 3.0:
					explodiu = 1
		await process_frame

	if andou_lateral < 2.0:
		falhas.append("o ziguezague nao desviou de lado (max %.1f m, esperado ~5 m)" % andou_lateral)
	if avanco_max < 15.0:
		falhas.append("o ziguezague nao avancou (pico %.1f m, esperado ~21 m)" % avanco_max)
	if explodiu == 0:
		falhas.append("nao houve explosao sobre o alvo proximo — o finalizador nao disparou")
	if caster2.hitstops == 0:
		falhas.append("o mergulho nao pediu hitstop")
	print("6. X ................. lateral %.1f m, avanco pico %.1f m, pousou em z=%.1f, explosao %s, %d hitstop"
		% [andou_lateral, avanco_max, caster2.global_position.z,
		   "SIM" if explodiu == 1 else "NAO", caster2.hitstops])

	# ------------------------------------------------------------- veredito
	print("")
	if falhas.is_empty():
		print("✓ PIKA Z (Salva de Luz) / X: tudo passou")
		quit(0)
	else:
		for f in falhas:
			print("✗ ", f)
		print("XX  %d falha(s)" % falhas.size())
		quit(1)


func _contar(raiz: Node, tipo: String) -> int:
	var n := 0
	for filho in _todos(raiz):
		# Classe interna não tem `class_name`: contar por NOME é o único jeito
		# honesto. A primeira versão procurava por tipo e achava zero rastro num
		# golpe que tinha sete — o teste passava mentindo.
		if tipo == "PikaRastro":
			# `begins_with`, não igualdade: o Godot renomeia irmãos de mesmo nome
			# para PikaRastro2, PikaRastro3… A primeira versão comparava exato,
			# via só o primeiro rastro — que já tinha morrido na hora da contagem
			# — e imprimia "0 rastros" num golpe que tinha sete. Teste que erra
			# para o lado de "está tudo bem" é o pior tipo de teste.
			if filho.name.begins_with("PikaRastro"):
				n += 1
		elif tipo == "DamageZone":
			if filho is Area3D and filho.is_in_group("hitbox"):
				n += 1
	return n


func _todos(n: Node) -> Array:
	var saida: Array = [n]
	for f in n.get_children():
		saida.append_array(_todos(f))
	return saida


# ⚠️ ALVO COM `take_damage`, e isto e correcao de 2026-09-06. O dubl e era um
# `StaticBody3D` cru no grupo "enemy" — algo que NAO EXISTE neste jogo: Player,
# TrainingDummy, AutoDummy e Enemy implementam `take_damage`, todos. Enquanto o
# peso do acerto vinha de `body_entered`, o dubl e irreal passava; quando passou a
# vir de `hit_landed` (o unico sinal que a `DamageZone` emite nos DOIS caminhos
# de deteccao), o dubl e reprovou um codigo certo. Alvo de teste que nao sabe
# receber dano nao prova nada sobre um golpe que aplica dano.
class _AlvoFalso extends StaticBody3D:
	var levou := 0.0
	func take_damage(v: float, _de: Vector3 = Vector3.ZERO,
			_kb: Vector3 = Vector3.ZERO, _hs: float = 0.3) -> void:
		levou += v


# Dublês: só contam quantas vezes foram chamados.
# ⚠️ O NOME DA PROPRIEDADE IMPORTA E JÁ MORDEU. A primeira versão chamava o dublê
# de `_animator`, que é o nome de um `CharacterAnimator` no Player — classe que
# NÃO tem `trigger_hitstop`. O teste passava e o jogo quebrava. O dublê agora se
# chama `_proc_anim`, como o `ProceduralAnimator` de verdade (Player.gd:509).
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

class _CasterFalso extends Node3D:
	var hitstops := 0
	var shakes := 0
	var fovs := 0
	var _proc_anim: _AnimadorFalso = null
	var _camera: _CameraFalsa = null
	func _init() -> void:
		_proc_anim = _AnimadorFalso.new()
		_proc_anim.dono = self
		add_child(_proc_anim)
		_camera = _CameraFalsa.new()
		_camera.dono = self
		add_child(_camera)
