extends SceneTree
# ============================================================================
#  O C DA PIKA VIROU ÁREA — estar dentro basta.
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/test_pika_c_area.gd
#
#  Mudança pedida pelo dono em 2026-09-06. Antes o C dependia de um FRAGMENTO EM
#  PARTICULAR conectar: 0,16 m de raio, 92 m/s, 90 deles espalhados por 52 m de
#  frente. O golpe parecia cobrir tudo e cobria quase nada — "o C tende a não
#  acertar", nas palavras dele.
#
#  Agora existe um volume só, traçado do peito do caster até os quatro cantos do
#  leque, e quem estiver dentro leva dano e é paralisado.
#
#  O QUE CADA CHECAGEM DEFENDE:
#    1. a forma é a pirâmide de 5 pontos, e os cantos dela batem com as MESMAS
#       constantes que espalham os fragmentos — se divergirem, a hitbox passa a
#       mentir sobre o que se vê;
#    2. alvo LONGE DO EIXO, no lugar onde nenhum fragmento passaria de propósito,
#       leva dano — é exatamente o caso que estava falhando;
#    3. quem leva fica paralisado;
#    4. quem está FORA não leva nada — área grande não pode virar área infinita;
#    5. o teto da conjuração (384) continua limitando o total, apesar de a zona
#       ticar 20 vezes por segundo;
#    6. o desenho vermelho de conferência existe enquanto `C_MOSTRAR_HITBOX`.
# ============================================================================

const PikaFXGrande = preload("res://src/effects/PikaFXGrande.gd")

var _falhas: Array[String] = []


func _init() -> void:
	var mundo := Node3D.new()
	get_root().add_child(mundo)
	await process_frame

	var caster := _CasterFalso.new()
	caster.add_to_group("player")
	mundo.add_child(caster)
	caster.global_position = Vector3.ZERO

	# Alvo de MIRA: o C trava a direção no mais próximo. Ele fixa o `fwd` para o
	# resto do teste, e é o caso fácil (bem no meio do leque).
	var mira := _Alvo.new()
	mundo.add_child(mira)
	mira.global_position = Vector3(0, PikaFXGrande.C_TELEPORTE_ALTURA, -12.0)
	await process_frame
	await process_frame

	var spec := Balance.spec("pika_pika", "C").para_cast()
	PikaFXGrande.yasakani(mundo, Vector3(0, 1, 0), Vector3(0, 0, -1),
		spec.dano, caster, spec, 91)
	await process_frame

	var ctrl = mundo.get_node_or_null("PikaCYasakani")
	if ctrl == null:
		_ok(false, "o controlador do C nasceu")
		_fim()
		return

	# A barragem (e a zona) começam em C_RAJA_INICIO.
	await create_timer(PikaFXGrande.C_RAJA_INICIO + 0.12).timeout
	var zona = ctrl.get_node_or_null("PikaZonaBarragemC")
	_ok(zona != null, "a zona de área nasceu junto com a barragem")
	if zona == null:
		_fim()
		return
	_ok(zona is DamageZone,
		"a zona é uma DamageZone (o `test_frutas` conta hitbox por esse tipo)")

	# ------------------------------------------------ 1. a forma e os cantos
	var forma: Shape3D = null
	for f in zona.get_children():
		if f is CollisionShape3D:
			forma = (f as CollisionShape3D).shape
	var convexa := forma as ConvexPolygonShape3D
	_ok(convexa != null, "a colisão é uma ConvexPolygonShape3D")
	if convexa == null:
		_fim()
		return
	var pts := convexa.points
	_ok(pts.size() == 5, "a pirâmide tem 5 pontos: o ápice e 4 cantos (tem %d)" % pts.size())
	_ok(pts[0].is_equal_approx(Vector3.ZERO),
		"o ápice está no peito do caster (origem local)")

	var fwd: Vector3 = ctrl.fwd
	var lado := fwd.cross(Vector3.UP).normalized()
	var cima := lado.cross(fwd).normalized()
	# ⚠️ OS PONTOS SÃO LOCAIS À ZONA, e desde 2026-09-06 a zona GIRA (é o que
	# deixa o C ser mirado durante a rajada). Comparar `pts[i]` direto com
	# vetores de mundo só dava certo enquanto a forma nascia já rotacionada.
	var cantos_ok := 0
	for i in range(1, pts.size()):
		var d: Vector3 = (zona.basis * pts[i]).normalized()
		var h: float = d.dot(lado) / maxf(d.dot(fwd), 0.0001)
		var v: float = d.dot(cima) / maxf(d.dot(fwd), 0.0001)
		var comprimento: float = pts[i].length()
		if absf(absf(h) - PikaFXGrande.C_ABERTURA_H) < 0.02 \
				and absf(absf(v) - PikaFXGrande.C_ABERTURA_V) < 0.02 \
				and absf(comprimento - PikaFXGrande.C_ALCANCE) < 0.5:
			cantos_ok += 1
	_ok(cantos_ok == 4,
		"os 4 cantos usam a abertura do leque (±%.2f h, ±%.2f v) a %.0f m — %d/4"
			% [PikaFXGrande.C_ABERTURA_H, PikaFXGrande.C_ABERTURA_V,
			   PikaFXGrande.C_ALCANCE, cantos_ok])

	# ------------------------------------------------ 6. o desenho vermelho
	_ok(zona.get_node_or_null("PikaHitboxVisivel") != null,
		"o desenho vermelho de conferência está na cena (C_MOSTRAR_HITBOX)")

	# ------------------------- 2/3. o alvo LONGE DO EIXO leva dano e paralisa
	# 80% de um canto + 20% da frente: bem dentro da envoltória, e a ~14 m de
	# lado do eixo — onde a chance de um fragmento de 0,16 m passar era mínima.
	var canto: Vector3 = pts[1].normalized()
	var dir_lateral := (canto * 0.8 + fwd * 0.2).normalized()
	var lateral := _Alvo.new()
	mundo.add_child(lateral)
	lateral.global_position = zona.global_position + dir_lateral * 18.0
	var desvio_do_eixo: float = (lateral.global_position - zona.global_position) \
		.cross(fwd).length()

	# --------------------------------------------- 4. e um alvo claramente FORA
	var fora := _Alvo.new()
	mundo.add_child(fora)
	fora.global_position = zona.global_position - fwd * 16.0   # atrás do caster
	await process_frame
	await process_frame
	await create_timer(0.30).timeout

	_ok(lateral.levou > 0.0,
		"alvo a %.1f m do eixo, dentro do volume, LEVOU dano (%.0f)"
			% [desvio_do_eixo, lateral.levou])
	_ok(bool(lateral.get_meta("is_frozen", false)),
		"e ficou paralisado")
	_ok(fora.levou == 0.0,
		"alvo atrás do caster, fora do volume, não levou nada (%.0f)" % fora.levou)

	# ------------------------------------- 4b. MIRAR ENQUANTO DESFERE (2026-09-06)
	# "é possível mover o efeito e a área de dano enquanto o desfere". Girar o
	# CORPO do caster tem de girar `fwd` e a zona junto.
	var fwd_antes: Vector3 = ctrl.fwd
	var base_antes: Basis = zona.basis
	caster.rotation.y += PI * 0.5          # meia-volta para a direita
	await create_timer(0.12).timeout
	var fwd_depois: Vector3 = ctrl.fwd
	_ok(fwd_antes.angle_to(fwd_depois) > 0.5,
		"girar o corpo gira a barragem (%.0f° de mudança no fwd)"
			% rad_to_deg(fwd_antes.angle_to(fwd_depois)))
	_ok(not zona.basis.is_equal_approx(base_antes),
		"a ZONA DE DANO girou junto com o efeito")
	# ⚠️ A inclinação vertical é PRESERVADA: o C mira para baixo (teleportou 7 m
	# para cima) e girar o corpo não pode levantar a barragem para o horizonte.
	_ok(absf(fwd_antes.y - fwd_depois.y) < 0.02,
		"a inclinação vertical sobreviveu ao giro (%.3f -> %.3f)"
			% [fwd_antes.y, fwd_depois.y])
	caster.rotation.y -= PI * 0.5

	# ------------------------------------------------------ 5. o teto de 384
	# Deixa a barragem inteira correr por cima de quem já está preso.
	await create_timer(PikaFXGrande.C_RAJA_FIM - PikaFXGrande.C_RAJA_INICIO).timeout
	var teto: float = Balance.spec("pika_pika", "C").teto
	_ok(lateral.levou <= teto + 0.01,
		"o total (%.0f) respeita o teto da conjuração (%.0f), mesmo ticando 20x/s"
			% [lateral.levou, teto])
	_ok(lateral.levou >= teto * 0.9,
		"e quem foi preso a barragem inteira chega perto do teto (%.0f de %.0f)"
			% [lateral.levou, teto])

	_fim()


func _fim() -> void:
	print("")
	if _falhas.is_empty():
		print("✓ C DA PIKA EM ÁREA: estar dentro do volume basta")
		quit(0)
		return
	for f in _falhas:
		print("✗ ", f)
	print("XX  %d falha(s)" % _falhas.size())
	quit(1)


func _ok(condicao: bool, texto: String) -> void:
	print(("✓ " if condicao else "✗ ") + texto)
	if not condicao:
		_falhas.append(texto)


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


class _AnimadorFalso extends Node:
	func trigger_hitstop(_d: float, _s: float = 0.04) -> void:
		pass


class _CasterFalso extends CharacterBody3D:
	var _proc_anim: _AnimadorFalso = null
	var _is_authority := true

	func _ready() -> void:
		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		cs.shape = cap
		add_child(cs)
		_proc_anim = _AnimadorFalso.new()
		add_child(_proc_anim)

	func lock_movement(_d: float, _t: String = "") -> void:
		pass

	func finalizar_skill_pika_c(_token: int) -> void:
		pass
