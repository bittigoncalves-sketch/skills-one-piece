extends SceneTree
## Mede a GUARDA PARADA da Yoru: a lâmina fica horizontal e à frente, as duas
## mãos ficam no cabo, o quadril desce, a pose respira, e nada disso sobrevive
## ao jogador começar a andar.
## godot --path . -s tools/dev_tests/test_yoru_guarda.gd
class Fighter extends CharacterBody3D:
	var health := 2048.0
	var combat_mode := "sword"
	var _char_model: Node3D
	var _yoru: YoruSword
	func lamina_da_espada() -> SwordBlade: return _yoru.lamina

var checks := 0
var failures := 0


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print(("PASS " if condition else "FAIL ") + label)


func _init() -> void:
	await process_frame
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var p := Fighter.new()
	world.add_child(p)
	p.position.y = 0.8
	var shape := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.4, 1.6, 0.4)
	shape.shape = caixa
	p.add_child(shape)
	p._char_model = CharacterBuilder.build_character("base").node
	p.add_child(p._char_model)
	var bb := PlayerModelKit.model_aabb(p._char_model)
	var f := 1.5 / bb.size.y
	p._char_model.scale = Vector3.ONE * f
	p._char_model.position.y = -0.8 - f * bb.position.y
	var mao: Node3D = p._char_model.find_child("Weapon_R", true, false)
	mao.rotation.x = PI
	p._yoru = YoruSword.ligar_na_mao(mao)
	var rig := YoruRig.new()
	rig.setup(p, p._yoru)
	await physics_frame

	print("=== guarda parada da Yoru ===")

	# ---------------------------------------------------------- a pose em si
	# Medida no dicionário, sem árvore: é o contrato que `pose()` consome.
	var solta := YoruRig.guarda_parada(0.0, 0.0)
	var cheia := YoruRig.guarda_parada(0.0, 1.0)
	var eixo_solto: Vector3 = Basis(solta.basis) * Vector3.UP
	var eixo_guarda: Vector3 = Basis(cheia.basis) * Vector3.UP
	var inclinacao_solta := rad_to_deg(asin(clampf(eixo_solto.y, -1.0, 1.0)))
	var inclinacao_guarda := rad_to_deg(asin(clampf(eixo_guarda.y, -1.0, 1.0)))
	print("   lâmina solta: %+.1f° da horizontal | em guarda: %+.1f°"
		% [inclinacao_solta, inclinacao_guarda])
	ok(absf(inclinacao_guarda) < 12.0,
		"em guarda a lâmina fica HORIZONTAL (%+.1f°)" % inclinacao_guarda)
	ok(inclinacao_solta > 25.0,
		"e a pose solta continua apontando para cima (%+.1f°)" % inclinacao_solta)
	# Correção do dono depois de ver no jogo: a guarda é CARREGADA, arma recuada.
	ok(eixo_guarda.z > 0.85,
		"a lâmina aponta para TRÁS do personagem (z=%+.2f)" % eixo_guarda.z)
	ok(eixo_guarda.x > 0.0,
		"e desviada para a DIREITA (x=%+.2f)" % eixo_guarda.x)
	ok(float(cheia.get("corpo", 0.0)) < -0.7,
		"o CORPO vira de lado (%.0f°)" % rad_to_deg(float(cheia.get("corpo", 0.0))))
	ok(float(cheia.get("olhar", 0.0)) > 0.9,
		"e a cabeça é devolvida à frente (olhar %.2f)" % float(cheia.get("olhar", 0.0)))
	ok(is_zero_approx(float(solta.chest)) and is_zero_approx(float(solta.get("corpo", 0.0))),
		"a pose solta não gira o corpo nem torce o tronco")
	ok(float(cheia.handle.y) < float(solta.handle.y),
		"o cabo desce do ombro para o peito (%.2f m contra %.2f m)"
			% [cheia.handle.y, solta.handle.y])
	ok(float(cheia.stance) > 0.5 and float(cheia.get("pes", 0.0)) > 0.0,
		"a guarda baixa o quadril e abre os pés")
	ok(is_equal_approx(float(solta.stance), 0.0) and is_equal_approx(float(solta.get("pes", 0.0)), 0.0),
		"a pose solta NÃO mexe nas pernas (stance 0)")

	# ------------------------------------------------------------ respiração
	var alturas: Array[float] = []
	for i in 24:
		alturas.append(YoruRig.guarda_parada(float(i) * YoruRig.RESPIRO_CICLO / 24.0, 1.0).handle.y)
	var amplitude: float = alturas.max() - alturas.min()
	print("   respiração do cabo: %.1f mm de amplitude" % (amplitude * 1000.0))
	ok(amplitude > 0.008, "a guarda RESPIRA (%.1f mm)" % (amplitude * 1000.0))
	ok(amplitude < 0.06, "e a respiração não vira balanço (%.1f mm)" % (amplitude * 1000.0))

	# ------------------------------------------------- entra parado, sai andando
	p.velocity = Vector3.ZERO
	for i in 30:
		rig.pose("", float(i) / 60.0, Vector3.FORWARD)
		await physics_frame
	var parado_peso := rig._guarda
	print("   peso parado: %.2f" % parado_peso)
	ok(parado_peso > 0.9, "parado no chão a guarda entra (peso %.2f)" % parado_peso)

	var ponta_guarda: Vector3 = p._char_model.global_transform.affine_inverse() \
		* (p._yoru.ponta as Node3D).global_position
	ok(ponta_guarda.z > 1.0,
		"com a guarda montada a ponta está ATRÁS (z=%+.2f m)" % ponta_guarda.z)
	ok(rig.grip_error < 0.05,
		"as DUAS mãos alcançam o cabo (erro da esquerda %.3f m)" % rig.grip_error)

	# ⚠️ MEDIDO NOS NÓS, não no dicionário: o dicionário diz a INTENÇÃO, e o que
	# interessa é para onde o tronco e a cabeça realmente apontam depois da
	# cadeia inteira — corpo, peito, pescoço e cabeça compostos.
	var frente_modelo := -p._char_model.global_basis.orthonormalized().z
	var torso: Node3D = rig.nodes["Torso"]
	var cabeca: Node3D = rig.nodes["Head"] if rig.nodes.has("Head") else null
	var frente_torso := -torso.global_basis.orthonormalized().z
	print("   tronco a %.0f° da frente" % rad_to_deg(frente_torso.angle_to(frente_modelo)))
	ok(frente_torso.angle_to(frente_modelo) > deg_to_rad(35.0),
		"o tronco está DE LADO (%.0f° da frente)"
			% rad_to_deg(frente_torso.angle_to(frente_modelo)))
	if cabeca:
		var frente_cabeca := -cabeca.global_basis.orthonormalized().z
		var desvio := rad_to_deg(frente_cabeca.angle_to(frente_modelo))
		print("   cabeça a %.0f° da frente" % desvio)
		ok(desvio < 18.0, "e a CABEÇA continua olhando para a frente (%.0f°)" % desvio)

	p.velocity = Vector3(0.0, 0.0, -5.0)
	for i in 30:
		rig.pose("", 0.5 + float(i) / 60.0, Vector3.FORWARD)
		await physics_frame
	print("   peso andando: %.2f" % rig._guarda)
	ok(rig._guarda < 0.05, "andando a guarda sai (peso %.2f)" % rig._guarda)

	# No ar a guarda também sai, e sem consultar `is_on_floor()`: o cache de chão
	# mente em Players remotos, onde o servidor não roda `move_and_slide`.
	p.velocity = Vector3(0.0, -9.0, 0.0)
	for i in 30:
		rig.pose("", 1.0 + float(i) / 60.0, Vector3.FORWARD)
		await physics_frame
	ok(rig._guarda < 0.05, "caindo a guarda sai (peso %.2f)" % rig._guarda)

	# Um golpe zera a guarda na hora: quem manda nas pernas volta a ser a ação.
	p.velocity = Vector3.ZERO
	for i in 30:
		rig.pose("", float(i) / 60.0, Vector3.FORWARD)
		await physics_frame
	rig.pose("M1_1", 0.1, Vector3.FORWARD)
	ok(is_equal_approx(rig._guarda, 0.0), "um golpe zera a guarda imediatamente")

	print("GUARDA YORU: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
