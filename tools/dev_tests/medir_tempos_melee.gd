extends SceneTree
# ============================================================================
#  OS TEMPOS DO CORPO A CORPO — a animação e o próximo clique estão casados?
#
#  Três relógios convivem em cada golpe e até 2026-08-15 nenhum deles conhecia
#  o outro:
#
#    ANIMAÇÃO  `(comprimento − inicio) / vel` — o que a tela mostra.
#    IMPACTO   `atraso` — quando a hitbox nasce, contado do clique.
#    PRÓXIMO   `recuo` — quando o clique seguinte é aceito.
#
#  O `recuo` era um número escrito à mão. Esta sonda põe os três lado a lado e
#  mostra a SOBRA: quanto tempo de animação ainda está correndo quando o jogador
#  já pode clicar de novo (e, antes desta tarefa, já podia andar).
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/medir_tempos_melee.gd
# ============================================================================

func _init() -> void:
	await process_frame
	for arma in ["", "sword"]:
		var combo: Array = Melee.COMBO_SWORD if arma == "sword" else Melee.COMBO
		print("")
		print("╔══════════════════════════════════════════════════════════════════════════╗")
		print("║  COMBO %-66s║" % ("COM ESPADA" if arma == "sword" else "DE MÃO LIVRE"))
		print("╚══════════════════════════════════════════════════════════════════════════╝")
		print("  %-22s %7s %6s %5s | %7s %7s %7s %8s | %7s %7s" % [
			"golpe", "clipe", "inicio", "vel", "ANIM", "impacto", "próx.", "SOBRA", "ÚTIL", "ENCADEAR"])
		print("  " + "─".repeat(90))
		for i in combo.size():
			var g := Melee.passo(i, arma)
			var a := Melee.clipe(i, arma)
			var bruto: float = a.length if a else 0.0
			var anim := Melee.duracao_tocada(i, arma)
			var atraso := float(g["atraso"])
			var recuo := Melee.recuo(i, arma)
			var parada := _fim_do_movimento(a)
			var util: float = maxf(parada - float(g.get("inicio", 0.0)), 0.0) / float(g["vel"])
			print("  %-22s %6.2fs %6.2f %5.2f | %6.2fs %6.2fs %6.2fs %+7.2fs | %6.2fs %6.2fs" % [
				g["nome"], bruto, float(g.get("inicio", 0.0)), float(g["vel"]),
				anim, atraso, recuo, recuo - anim, util,
				Melee.JANELA - recuo + MeleeController.BUFFER])
		print("")
		print("  SOBRA negativa = o clique seguinte abre com a animação AINDA correndo.")
		print("  ÚTIL = até o corpo PARAR de se mexer.")
		print("  ENCADEAR = quanto sobra da JANELA (%.1fs) para o próximo clique, já com o buffer" % Melee.JANELA)
		print("             de %.2fs. Negativo ou perto de zero = o combo fica impossível de ligar." % MeleeController.BUFFER)
	quit()

# QUANDO O CORPO PARA. Percorre as faixas do clipe somando a velocidade angular
# de todos os papéis e devolve o último instante em que ela passa do limiar.
#
# ⚠️ O cabeçalho do `Melee.gd` avisa que o desvio ANGULAR erra o PICO do chute em
# 0,22 s — verdade, e por isso o `atraso` não é medido assim. Aqui a pergunta é
# outra: não "onde bate", e sim "quando para". Para o FIM, a retração é parte do
# movimento e a velocidade angular é justamente o sinal certo.
func _fim_do_movimento(a: Animation, limiar: float = 0.35) -> float:
	if a == null:
		return 0.0
	var passo := 1.0 / 60.0
	var ultimo := 0.0
	var t := passo
	while t <= a.length:
		var vel := 0.0
		for i in a.get_track_count():
			if a.track_get_type(i) != Animation.TYPE_VALUE:
				continue
			var v0 = a.value_track_interpolate(i, t - passo)
			var v1 = a.value_track_interpolate(i, t)
			if v0 is Vector3 and v1 is Vector3:
				vel += (v1 - v0).length() / passo
		if vel > limiar:
			ultimo = t
		t += passo
	return ultimo
