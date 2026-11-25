extends SceneTree
## Animação de captura (10/11/2026): a bola cai, chacoalha de um lado para o outro e, no sucesso, solta TRÊS estrelas (sem texto de "capturado");
## no escape a bola abre e a criatura volta. Também: fruta do jogador não fere tripulação/pet/aliado (fogo amigo).
##   godot --headless --path . --script tools/dev_tests/test_animacao_de_captura.gd
const MAPA := "user://test_anim_captura.json"
const SAVE := "user://test_anim_captura_p.json"
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void: rodar.call_deferred()
func rodar() -> void:
	await process_frame
	# ---- a animação sozinha: sucesso com 3 chacoalhadas
	var resultados := []
	var a := AnimacaoDeCaptura.new()
	a.chacoalhadas = 3
	a.capturou = true
	a.ao_terminar = func(c: bool): resultados.append(c)
	root.add_child(a)
	var zmin := 0.0
	var zmax := 0.0
	var fases := {}
	var feitas := 0
	var estrelas := 0
	for i in 400:
		await physics_frame
		if not is_instance_valid(a): break
		fases[a.fase] = true
		feitas = a.chacoalhadas_feitas
		estrelas = a.estrelas_criadas
		var bola := a.get_node_or_null("Bola") as Node3D
		if bola != null:
			zmin = minf(zmin, bola.rotation.z)
			zmax = maxf(zmax, bola.rotation.z)
	ok(fases.has("cair") and fases.has("chacoalhar") and fases.has("clique") and fases.has("estrelas"), "fases: cair → chacoalhar → clique → estrelas (%s)" % str(fases.keys()))
	ok(zmin < -0.2 and zmax > 0.2, "a bola balança de um lado para o outro (rotação z %.2f … %.2f)" % [zmin, zmax])
	ok(feitas == 3, "3 chacoalhadas feitas (%d)" % feitas)
	ok(estrelas == 3, "TRÊS estrelas no sucesso (%d)" % estrelas)
	ok(resultados == [true], "o callback de sucesso vem uma vez (%s)" % str(resultados))
	await quadros(10)
	ok(not is_instance_valid(a), "a animação se apaga sozinha")
	# ---- falha: abre e devolve, sem estrelas
	var res2 := []
	var b := AnimacaoDeCaptura.new()
	b.chacoalhadas = 2
	b.capturou = false
	b.ao_terminar = func(c: bool): res2.append(c)
	root.add_child(b)
	var estrelas_b := 0
	for i in 300:
		await physics_frame
		if not is_instance_valid(b): break
		estrelas_b = b.estrelas_criadas
	ok(res2 == [false] and estrelas_b == 0, "escape: callback falso e nenhuma estrela")
	# ---- cena real: arremesso acerta, anima, captura sem texto
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	mapa.pecas[0].tamanho = Vector3(160, 2, 160)
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var m = current_scene
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var captura: CapturaDeInimigos = m.get_node("CapturaDeInimigos")
	var hud = get_first_node_in_group("hud")
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	alvo.position = j.global_position + Vector3(4, 0, 0)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 100.0
	alvo.health = 10.0
	await quadros(10)
	ProbabilidadeDeCaptura.sorteio_fixo = 0.0            # o sorteio sempre acerta
	hud.avisar("")
	captura.acertou(alvo)
	ok(not alvo.visible and alvo.process_mode == Node.PROCESS_MODE_DISABLED, "a criatura some para dentro da bola durante a animação")
	var anim := current_scene.get_node_or_null("AnimacaoDeCaptura") as AnimacaoDeCaptura
	ok(anim != null, "a animação nasce no chão da criatura")
	var estrelas_vistas := 0
	for i in 500:
		await physics_frame
		if is_instance_valid(anim):
			estrelas_vistas = maxi(estrelas_vistas, anim.estrelas_criadas)
		else:
			break
	ok(estrelas_vistas == 3, "arremesso com sucesso solta 3 estrelas (%d)" % estrelas_vistas)
	ok(not is_instance_valid(alvo) or alvo.get_meta("capturado", false) == true, "a criatura foi capturada")
	ok(not str(hud.get("_aviso").text).contains("capturado"), "sem o texto 'capturado' (\"%s\")" % str(hud.get("_aviso").text))
	# ---- escape na cena real
	var alvo2 := PersonagemMinePiece.new()
	alvo2.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	alvo2.position = j.global_position + Vector3(4, 0, 3)
	alvo2.ponto_de_origem = alvo2.position
	current_scene.add_child(alvo2)
	alvo2.max_health = 100.0
	alvo2.health = 10.0
	await quadros(10)
	ProbabilidadeDeCaptura.sorteio_fixo = 0.9999         # nunca passa
	captura.acertou(alvo2)
	await quadros(400)
	ok(is_instance_valid(alvo2) and alvo2.visible and alvo2.process_mode != Node.PROCESS_MODE_DISABLED and not alvo2.has_meta("em_captura"), "no escape a criatura volta, visível e ativa")
	ProbabilidadeDeCaptura.sorteio_fixo = -1.0
	# ---- fogo amigo: poder do jogador não fere membro da tripulação nem pet
	var membro := PersonagemMinePiece.new()
	membro.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	membro.position = j.global_position + Vector3(-4, 0, 0)
	current_scene.add_child(membro)
	membro.set_meta("membro_tripulacao", "recruta_1")
	await quadros(5)
	var v0 := membro.health
	CombatResolver.aplicar(membro, 50.0, 0, 0.0, j.global_position, Vector3.ZERO, 0.0, 0.0, false, null, j)
	ok(is_equal_approx(membro.health, v0), "CombatResolver: ataque do jogador não fere o membro da tripulação")
	McEntidade.de(membro).hurt(McFonteDeDano.de(&"minecraft:player_attack", McEntidade.de(j)), 50.0)
	ok(is_equal_approx(membro.health, v0), "fruta do mod (hurt): também não fere")
	var inimigo := PersonagemMinePiece.new()
	inimigo.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	inimigo.position = j.global_position + Vector3(-8, 0, 0)
	current_scene.add_child(inimigo)
	await quadros(5)
	var vi := inimigo.health
	CombatResolver.aplicar(inimigo, 5.0, 0, 0.0, j.global_position, Vector3.ZERO, 0.0, 0.0, false, null, j)
	ok(inimigo.health < vi, "o inimigo comum segue levando dano do jogador")
	print("test_animacao_de_captura: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
