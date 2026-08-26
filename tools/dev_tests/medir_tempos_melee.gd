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
			# ⚠️ ACESSORES, NÃO CAMPOS (2026-08-25). `atraso` e `inicio` deixaram
			# de ser chaves do dicionário no combo de mão livre: o primeiro virou
			# `startup` e o segundo é derivado do `pico` medido. Ler o dicionário
			# direto aqui estourava — e a espada, que não foi convertida, continua
			# atendida pelos mesmos acessores.
			var atraso := Melee.startup(i, arma)
			var ini := Melee.inicio(i, arma)
			var recuo := Melee.recuo(i, arma)
			var parada := _fim_do_movimento(a)
			var util: float = maxf(parada - ini, 0.0) / float(g["vel"])
			print("  %-22s %6.2fs %6.2f %5.2f | %6.2fs %6.2fs %6.2fs %+7.2fs | %6.2fs %6.2fs" % [
				g["nome"], bruto, ini, float(g["vel"]),
				anim, atraso, recuo, recuo - anim, util,
				Melee.JANELA - recuo + MeleeController.BUFFER])
		print("")
		print("  ⚠️ Desde 2026-08-25 a SOBRA do combo de mão livre é ZERO por construção:")
		print("     a trava saiu do frame data e o CLIPE é janelado por ela (ver")
		print("     `Melee.fim_da_janela`). Esta sonda passou a medir a espada, que ainda")
		print("     roda no modelo antigo. Para o frame data novo use medir_frame_data.gd.")
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
