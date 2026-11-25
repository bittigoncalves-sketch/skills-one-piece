extends "res://tools/dev_tests/test_navios.gd"
## Contatos reais via Y/W/D, com cascos completos e ondas. Timeout externo detecta
## travamento; cada cenário mantém entrada pressionada durante 600 quadros.

func _executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_navios_colisao.json")
	get_root().get_node("GameFlow").start_story()
	for i in 100:
		await physics_frame
	p = get_first_node_in_group("player")
	nav = current_scene.get("_navegacao")
	nav.janela = null   # 15/10/2026: sem a pergunta "Navegar?" — estes testes são da física do barco (a tripulação tem o test_tripulacao)
	if p == null or nav == null:
		_ok("cena de história carregou", false)
		quit(1)
		return
	p.set_meta("damage_immune", true)
	var bib := MapaMontador.biblioteca_em_uso()
	for id: String in NAVIOS:
		if not OS.get_cmdline_user_args().is_empty() and id != OS.get_cmdline_user_args()[0]:
			continue
		for lateral: bool in [false, true]:
			await _contato(bib, id, lateral)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("COLISAO_NAVIOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas else 0)

func _contato(bib: BibliotecaDeModelos, id: String, lateral: bool) -> void:
	var b: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
	var outro: CharacterBody3D = load("res://src/historia/navios/barco.gd").new()
	var alvo_id: String = {"boat": "ship", "small_ship": "small_ship", "ship": "boat"}[id]
	var rotulo := "%s → %s / %s" % [id, alvo_id, "lateral" if lateral else "frontal"]
	if not b.configurar(bib, id, bib.tamanho_padrao(id)) or not outro.configurar(bib, alvo_id, bib.tamanho_padrao(alvo_id)):
		_ok(rotulo + ": configurou", false)
		b.free()
		outro.free()
		return
	b.position = Vector3(400, AguaDoMundo.nivel_em(400, 0), 0)
	var distancia: float = (b.tamanho_casco.z + (outro.tamanho_casco.x if lateral else outro.tamanho_casco.z)) * .5 + 2.0
	outro.position = b.position + Vector3.FORWARD * distancia
	outro.rotation.y = PI * .5 if lateral else PI
	current_scene.add_child(b)
	current_scene.add_child(outro)
	nav.barcos.append(b)
	nav.barcos.append(outro)
	var parado := outro.global_transform
	var pose: Transform3D = outro.visual.transform
	p.global_position = b.leme.global_position + Vector3.UP * .85
	p.velocity = Vector3.ZERO
	for i in 10:
		await physics_frame
	await _tecla_toque(KEY_Y)
	_ok(rotulo + ": Y ativa só um barco", nav.barco == b and b.is_physics_processing() and not outro.is_physics_processing())
	if nav.barco != b:
		await _limpar(b)
		nav.barcos.erase(outro)
		outro.queue_free()
		return
	var contatos := 0
	var finito := true
	var maior_vel := 0.0
	var tempos: Array[float] = []
	var passo := 0.0
	var anterior := b.position
	_tecla(KEY_W, true)
	for i in 600:
		# Primeiro contato frontal, depois tentar virar ainda pressionando o casco.
		if i == 400:
			_tecla(KEY_D, true)
		await physics_frame
		passo = maxf(passo, Vector2(b.position.x - anterior.x, b.position.z - anterior.z).length())
		anterior = b.position
		tempos.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		for c in b.get_slide_collision_count():
			if b.get_slide_collision(c).get_collider() == outro:
				contatos += 1
		finito = finito and b.global_position.is_finite() and b.velocity.is_finite()
		maior_vel = maxf(maior_vel, Vector2(b.velocity.x, b.velocity.z).length())
	_tecla(KEY_W, false)
	_tecla(KEY_D, false)
	tempos.sort()
	print("MEDICAO %s: contatos=%d, física p95=%.2f ms, max=%.2f ms, velocidade=%.2f, maior passo=%.3f m" % [rotulo, contatos, tempos[569], tempos.back(), maior_vel, passo])
	_ok(rotulo + ": 600 quadros completados com contato entre cascos", contatos > 10)
	_ok(rotulo + ": mantém velocidade e deslocamento limitados", finito and maior_vel <= float(b.ficha["velocidade"]) * 1.1 and passo < .5)
	_ok(rotulo + ": outro barco conserva posição, pose e espuma vazia", outro.global_transform.is_equal_approx(parado) and outro.visual.transform.is_equal_approx(pose) and outro._esteira._marcas.is_empty())
	# Primeiro freia; só então medimos o deslocamento em ré (a soma dos dois
	# percursos pode ser quase zero mesmo quando o barco já se afastou do casco).
	_tecla(KEY_S, true)
	for i in 240:
		await physics_frame
	var antes := b.position
	var para_tras := b.global_basis.z
	for i in 90:
		await physics_frame
	_tecla(KEY_S, false)
	var afastou := (b.position - antes).dot(para_tras)
	_ok(rotulo + ": ré permite sair do contato (%.2f m)" % afastou, afastou > .5)

	await _tecla_toque(KEY_Y)
	_ok(rotulo + ": Y desativa simulação após colisão", not nav.ativo() and not b.is_physics_processing() and b.velocity.is_zero_approx())
	await _limpar(b)
	nav.barcos.erase(outro)
	outro.queue_free()
	await physics_frame
