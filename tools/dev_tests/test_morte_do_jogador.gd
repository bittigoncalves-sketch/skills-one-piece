extends SceneTree
# ============================================================================
#  MORTE DO JOGADOR NO MODO HISTÓRIA (27/10/2026): "passar a emoção da morte" — estilo Souls.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_morte_do_jogador.gd
#
#  Confere a SEQUÊNCIA (tempo real ≈ 5 s): câmera lenta e som abafado no golpe fatal, controles travados, tela com
#  "VOCÊ MORREU" e quem matou, e o mundo devolvido ao normal no fim (tempo, áudio, vida, posição). Headless não
#  renderiza: o DESENHO (vinheta, dessaturação, tipografia) e o som real NÃO foram vistos nem ouvidos aqui.
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func real(s: float) -> void:
	await create_timer(s, true, false, true).timeout


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_morte_do_jogador.json")
	root.get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	var j: CharacterBody3D = get_first_node_in_group("player")
	ok(j.ao_morrer.is_valid(), "a história instala o gancho da morte")
	ReanimacaoDoCoracao.habilitada = false          # esta bateria mede a morte de sempre (o coração tem teste próprio)
	var casa: Vector3 = j.ponto_de_renascimento
	j.global_position = casa + Vector3(7, 0, 3)
	var inimigo := PersonagemMinePiece.new()
	inimigo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	inimigo.position = casa + Vector3(0, 0, -40)
	current_scene.add_child(inimigo)
	j.set_meta("autor_do_dano", inimigo.get_instance_id())
	var audio0 := AudioServer.get_bus_effect_count(0)

	j.health = 1.0                                   # a defesa do nível (armadura, Resistência) reduz o golpe: sobra 1 de vida
	j.take_damage(60.0, inimigo.global_position, Vector3.ZERO, 0.0)
	for i in 6:
		await physics_frame
	var morte := current_scene.get_node_or_null("MorteDoJogador")
	ok(morte != null and j.morrendo, "o golpe fatal inicia a sequência (e não o teleporte imediato)")
	ok(is_equal_approx(Engine.time_scale, MorteDoJogador.ESCALA_DO_TEMPO), "câmera lenta (×%.2f)" % Engine.time_scale)
	ok(AudioServer.playback_speed_scale < 1.0 and AudioServer.get_bus_effect_count(0) == audio0 + 1, "o som desacelera e abafa (filtro passa-baixa)")
	ok(j.global_position.distance_to(casa) > 3.0, "o corpo fica onde morreu, não vai para o ponto de renascimento ainda")
	ok(bool(j.get_meta("damage_immune", false)), "durante a sequência o jogador não morre de novo")
	await real(2.0)
	var titulo: Label = morte.find_child("Titulo", true, false) if morte != null else null
	var causa: Label = morte.find_child("Causa", true, false) if morte != null else null
	ok(titulo != null and titulo.text == "VOCÊ MORREU" and titulo.modulate.a > 0.3, "aparece \"VOCÊ MORREU\" (opacidade %.2f)" % (titulo.modulate.a if titulo else -1.0))
	ok(causa != null and causa.text == "derrotado por %s" % inimigo.nome_de_exibicao(), "diz quem te derrotou: \"%s\"" % (causa.text if causa else "?"))
	await real(3.4)
	ok(is_equal_approx(Engine.time_scale, 1.0) and is_equal_approx(AudioServer.playback_speed_scale, 1.0) and AudioServer.get_bus_effect_count(0) == audio0,
		"tempo e som voltam ao normal")
	var longe := Vector2(j.global_position.x - casa.x, j.global_position.z - casa.z).length()
	ok(longe < 1.0, "renasceu no ponto de renascimento (%.2f m na horizontal)" % longe)
	ok(j.health > 0.0 and not j.morrendo and not j.has_meta("damage_immune"), "vida cheia (%.0f), livre de novo e vulnerável" % j.health)
	await real(1.2)
	ok(current_scene.get_node_or_null("MorteDoJogador") == null, "a camada da tela é removida no fim")

	# Morrer outra vez funciona (nada ficou preso).
	j.health = 1.0                                   # a defesa do nível (armadura, Resistência) reduz o golpe: sobra 1 de vida
	j.take_damage(60.0, inimigo.global_position, Vector3.ZERO, 0.0)
	for i in 6:
		await physics_frame
	ok(current_scene.get_node_or_null("MorteDoJogador") != null, "uma segunda morte repete a sequência")
	await real(6.0)
	ok(is_equal_approx(Engine.time_scale, 1.0) and j.health > 0.0 and not j.morrendo, "e termina limpa")

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
