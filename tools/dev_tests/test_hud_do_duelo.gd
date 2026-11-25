extends SceneTree
# HUD do duelo (22/11/2026): teclas 1/2/3 e cliques emitem a jogada UMA vez, bloqueio ignora tudo, corações e texto da revelação. Rodar:
#   godot --headless --path . --script tools/dev_tests/test_hud_do_duelo.gd
var f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: f += 1
func tecla(k: int) -> InputEventKey:
	var e := InputEventKey.new(); e.keycode = k; e.pressed = true; return e

func _init() -> void:
	await process_frame
	var h := HudDoDuelo.new()
	root.add_child(h)
	await process_frame
	var jogadas := []
	h.escolheu.connect(func(j: int) -> void: jogadas.append(j))
	ok("nasce bloqueada (o orquestrador libera)", h.bloqueado)
	h._input(tecla(KEY_1))
	ok("bloqueada: tecla 1 ignorada", jogadas.is_empty())
	h.bloquear(false)
	h._input(tecla(KEY_2))
	ok("tecla 2 = PAPEL, uma vez", jogadas == [1] and h.bloqueado)
	h._input(tecla(KEY_3))
	ok("escolha dupla bloqueada (a tecla 3 logo depois é ignorada)", jogadas == [1])
	h.bloquear(false)
	(h.get_node("Raiz/Botoes/Tesoura") as Button).pressed.emit()
	ok("clique em Tesoura = 2", jogadas == [1, 2])
	h.bloquear(false)
	h._input(tecla(KEY_4))
	ok("tecla fora de 1–3 não faz nada", jogadas == [1, 2] and not h.bloqueado)
	var botoes := [h.get_node("Raiz/Botoes/Pedra"), h.get_node("Raiz/Botoes/Papel"), h.get_node("Raiz/Botoes/Tesoura")]
	ok("3 botões, habilitados quando liberado", botoes.all(func(b): return not (b as Button).disabled))
	h.bloquear(true)
	ok("bloqueado: os 3 botões ficam apagados", botoes.all(func(b): return (b as Button).disabled))
	h.atualizar_vidas(4, 2)
	ok("corações/número atualizam (4/7 e 2/7)", h.vidas_do_jogador == 4 and h.vidas_da_alvida == 2 and (h._numeros["jogador"] as Label).text == "4/7" and (h._numeros["alvida"] as Label).text == "2/7")
	var t: String = h.texto_da_revelacao({"jogador": 0, "alvida": 2, "evento": DueloPpt.ACERTO_DO_JOGADOR})
	ok("revelação: mostra as duas jogadas e o que aconteceu", t.contains("Pedra") and t.contains("Tesoura") and t.contains("acerta a Alvida"))
	ok("empate narra o desvio", h.texto_da_revelacao({"jogador": 1, "alvida": 1, "evento": DueloPpt.EMPATE}).contains("desvia"))
	ok("o jogador só tem 7 corações desenhados", DueloPpt.VIDAS == 7 and h.MASCARA.size() == 6)
	h.queue_free()
	await process_frame
	print("\n" + ("TUDO OK" if f == 0 else "%d FALHA(S)" % f))
	quit(1 if f > 0 else 0)
