extends SceneTree
## Contrato novo da Pika: C sustentado/teleporte/alvo e V vindo do céu.

const PikaFXGrande = preload("res://src/effects/PikaFXGrande.gd")

var _falhas: Array[String] = []


func _init() -> void:
	var mundo := Node3D.new()
	get_root().add_child(mundo)
	await process_frame

	var caster := CasterFalso.new()
	caster.name = "CasterPika"
	mundo.add_child(caster)
	caster.global_position = Vector3.ZERO

	var alvo := StaticBody3D.new()
	alvo.name = "AlvoMaisProximo"
	alvo.add_to_group("enemy")
	var forma := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 1.0
	forma.shape = esfera
	alvo.add_child(forma)
	mundo.add_child(alvo)
	alvo.global_position = Vector3(0, 0, -12)
	await process_frame

	# C: o primeiro quadro já sobe o corpo e fixa o vetor no alvo próximo.
	PikaFXGrande.yasakani(mundo, Vector3(0, 1, 0), Vector3.RIGHT, 8.0,
		caster, DamageSpec.avulso(8.0), 77)
	await process_frame
	_ok(absf(caster.global_position.y - PikaFXGrande.C_TELEPORTE_ALTURA) < 0.05,
		"C teleporta %.1f m para cima (saiu y=%.2f)" % [
			PikaFXGrande.C_TELEPORTE_ALTURA, caster.global_position.y])
	var ctrl_c := mundo.get_node_or_null("PikaCYasakani")
	_ok(ctrl_c != null, "controlador C nasceu no press")
	if ctrl_c != null:
		var esperado := (alvo.global_position + Vector3.UP * 0.8 - caster.global_position).normalized()
		_ok((ctrl_c.fwd as Vector3).dot(esperado) > 0.995,
			"C ignora a mira lateral e aponta ao inimigo mais próximo")

	# Mantido pressionado: atravessa preparação e começa a criar os fragmentos.
	await create_timer(1.18).timeout
	var pico_fragmentos := _contar_nome(mundo, "PikaFragmentoC")
	_ok(pico_fragmentos >= 3,
		"C pressionado chegou à barragem (%d fragmentos vivos)" % pico_fragmentos)

	# Soltar: a meta replicada encerra o controlador e nenhuma nova salva nasce.
	caster.set_meta("pika_c_active", false)
	await process_frame
	await process_frame
	_ok(mundo.get_node_or_null("PikaCYasakani") == null,
		"soltar C encerra a barragem antes do limite")
	var depois_soltar := _contar_nome(mundo, "PikaFragmentoC")
	await create_timer(0.18).timeout
	_ok(_contar_nome(mundo, "PikaFragmentoC") <= depois_soltar,
		"soltar C não cria fragmentos novos")

	# V: fica no centro; o campo de GPU e impactos só ligam depois dos 2 s.
	PikaFXGrande.chuva_de_luz(mundo, Vector3.ZERO, 32.0, caster,
		DamageSpec.avulso(32.0))
	await create_timer(2.08).timeout
	var ctrl_v := mundo.get_node_or_null("PikaVChuvaDeLuz")
	_ok(ctrl_v != null, "controlador V persiste durante a chuva")
	var campo_ligado := false
	if ctrl_v != null:
		for n in _todos(ctrl_v):
			if n is GPUParticles3D and (n as GPUParticles3D).emitting:
				campo_ligado = true
	_ok(campo_ligado, "V liga o campo de feixes descendentes após 2 s")

	var pico_v := 0
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 550:
		pico_v = maxi(pico_v, _contar_nome(mundo, "PikaFeixeV"))
		await process_frame
	_ok(pico_v > 0, "V cria feixes independentes do céu (pico %d)" % pico_v)

	print("")
	if _falhas.is_empty():
		print("✓ PIKA C/V: teleporte, sustentação, mira e chuva passaram")
		quit(0)
	else:
		for falha in _falhas:
			print("✗ ", falha)
		print("XX %d falha(s)" % _falhas.size())
		quit(1)


func _ok(condicao: bool, mensagem: String) -> void:
	print(("✓ " if condicao else "✗ ") + mensagem)
	if not condicao:
		_falhas.append(mensagem)


func _contar_nome(raiz: Node, prefixo: String) -> int:
	var total := 0
	for n in _todos(raiz):
		if n.name.begins_with(prefixo):
			total += 1
	return total


func _todos(raiz: Node) -> Array:
	var saida: Array = [raiz]
	for filho in raiz.get_children():
		saida.append_array(_todos(filho))
	return saida


class CasterFalso extends CharacterBody3D:
	var _is_authority := true
	var finalizacoes := 0
	func lock_movement(_duracao: float, _slot: String = "") -> void:
		pass
	func finalizar_skill_pika_c(_token: int = 0) -> void:
		finalizacoes += 1
		set_meta("pika_c_active", false)
