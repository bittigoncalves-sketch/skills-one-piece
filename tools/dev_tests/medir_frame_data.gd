extends SceneTree
# ============================================================================
#  FRAME DATA DO COMBO — a vantagem no acerto é positiva?
#
#  Esta sonda existe para responder UMA pergunta, e ela é aritmética, não gosto
#  (§2.3 de docs/PLANO_COMBATE_BATTLEGROUNDS.md):
#
#      vantagem_no_acerto = hitstun − (ativo + recuperacao)
#      o combo encadeia  ⟺  vantagem ≥ startup do próximo golpe
#
#  Vantagem negativa quer dizer que ACERTAR É JOGADA PERDEDORA: o atacante
#  ainda está preso quando o alvo já pode responder, e a resposta ótima de quem
#  apanha é levar o golpe e punir. Era o estado do jogo até 2026-08-25, em
#  todos os quatro golpes (−49 quadros no primeiro soco).
#
#  A segunda pergunta é sobre o CLIPE: onde a janela abre e fecha, e se o pico
#  medido do membro (punho/pé) cai mesmo no fim do startup. Se não cair, a
#  hitbox nasce fora do quadro do soco e o golpe "não bate onde bate".
#
#  Uso:
#    godot --headless --path . --script tools/dev_tests/medir_frame_data.gd
#
#  Ela NÃO sobe o jogo — lê a tabela e os clipes. É de propósito: dá para rodar
#  em paralelo com qualquer outra coisa (o `test_frutas.gd`, por exemplo, não
#  pode, porque hospeda numa porta fixa).
# ============================================================================

func _init() -> void:
	await process_frame
	var falhas := 0

	print("")
	print("╔═══════════════════════════════════════════════════════════════════════════════╗")
	print("║  FRAME DATA — COMBO DE MÃO LIVRE                                              ║")
	print("╚═══════════════════════════════════════════════════════════════════════════════╝")
	print("  %-16s %7s %6s %7s | %6s | %8s | %9s" % [
		"golpe", "startup", "ativo", "recup.", "TRAVA", "hitstun", "VANTAGEM"])
	print("  " + "─".repeat(79))

	var trava_total := 0.0
	for i in Melee.COMBO.size():
		var g := Melee.passo(i)
		var su := Melee.startup(i)
		var at := Melee.ativo(i)
		var rec := Melee.recuperacao(i)
		var tr := Melee.recuo(i)
		var hs := Melee.hitstun(i)
		var van := Melee.vantagem(i)
		trava_total += tr
		print("  %-16s %6.2fs %5.2fs %6.2fs | %5.2fs | %7.2fs | %+8.2fs" % [
			g["nome"], su, at, rec, tr, hs, van])

	print("  " + "─".repeat(79))
	print("  COMBO COMPLETO: %.2fs  (alvo do plano: 1,6-1,9s; antes de 2026-08-25: 4,8-5,0s)"
		% trava_total)

	# ------------------------------------------------------- o combo encadeia?
	print("")
	print("  ── O COMBO TRAVA? vantagem do golpe N ≥ startup do golpe N+1 ──")
	for i in Melee.COMBO.size() - 1:
		var van := Melee.vantagem(i)
		var su_prox := Melee.startup(i + 1)
		var folga := van - su_prox
		var passou := folga >= 0.0
		if not passou:
			falhas += 1
		print("     %s %-16s vantagem %+.2fs  vs startup de %-16s %.2fs   folga %+.2fs" % [
			"✅" if passou else "❌", Melee.passo(i)["nome"], van,
			Melee.passo(i + 1)["nome"], su_prox, folga])

	# O último golpe não encadeia em nada, mas a vantagem dele ainda tem que ser
	# positiva — senão o finalizador entrega o turno ao alvo que acabou de cair.
	var ult := Melee.COMBO.size() - 1
	var van_ult := Melee.vantagem(ult)
	if van_ult < 0.0:
		falhas += 1
	print("     %s %-16s vantagem %+.2fs (fecha o combo — só precisa ser positiva)" % [
		"✅" if van_ult >= 0.0 else "❌", Melee.passo(ult)["nome"], van_ult])

	# --------------------------------------------------------- janela do clipe
	print("")
	print("╔═══════════════════════════════════════════════════════════════════════════════╗")
	print("║  JANELA DO CLIPE — o pico medido cai no fim do startup?                       ║")
	print("╚═══════════════════════════════════════════════════════════════════════════════╝")
	print("  %-16s %-26s %6s %7s %6s %7s | %8s" % [
		"golpe", "clipe", "vel", "inicio", "fim", "clipe", "EM TELA"])
	print("  " + "─".repeat(79))
	for i in Melee.COMBO.size():
		var g := Melee.passo(i)
		var a := Melee.clipe(i)
		var comp: float = a.length if a else 0.0
		var ini := Melee.inicio(i)
		var fim := Melee.fim_da_janela(i)
		print("  %-16s %-26s %5.2fx %6.3fs %5.3fs %6.2fs | %7.3fs" % [
			g["nome"], g["anim"], float(g["vel"]), ini, fim, comp, Melee.duracao_tocada(i)])

		# O clipe é longo o bastante para a janela caber nele?
		if a == null:
			print("       ❌ clipe ausente")
			falhas += 1
			continue
		if fim > comp + 0.0005:
			print("       ❌ a janela passa do fim do clipe (%.3fs > %.3fs): a trava mostraria"
				% [fim, comp])
			print("          boneco parado no rabo do golpe.")
			falhas += 1
		# O pico medido tem que cair exatamente no fim do startup, em tela.
		var pico_em_tela: float = (float(g["pico"]) - ini) / float(g["vel"])
		var erro: float = absf(pico_em_tela - Melee.startup(i))
		if erro > 0.002:
			print("       ❌ o pico do membro cai a %.3fs de tela, mas o startup é %.3fs"
				% [pico_em_tela, Melee.startup(i)])
			falhas += 1
		# E o `inicio` derivado não pode ter sido cortado no 0 pelo clamp: se
		# `pico − startup*vel` for negativo, o clipe não tem preparação suficiente
		# e o impacto sairia ATRASADO em relação à hitbox.
		var bruto: float = float(g["pico"]) - Melee.startup(i) * float(g["vel"])
		if bruto < -0.0005:
			print("       ❌ clipe curto demais na abertura: precisaria começar em %.3fs" % bruto)
			falhas += 1

	# ------------------------------------------------------- punição de whiff
	print("")
	print("  ── PUNIÇÃO DE WHIFF (×%.2f na recuperação) ──" % Melee.WHIFF_MULT)
	for i in Melee.COMBO.size():
		var acertou := Melee.recuo(i, "", false)
		var errou := Melee.recuo(i, "", true)
		print("     %-16s acertou %.2fs   errou %.2fs   (+%.0f ms de exposição)" % [
			Melee.passo(i)["nome"], acertou, errou, 1000.0 * (errou - acertou)])

	print("")
	if falhas == 0:
		print("  ✅ FRAME DATA COERENTE — %d verificações, nenhuma falha." % Melee.COMBO.size())
	else:
		print("  ❌ %d FALHA(S). Ver as linhas marcadas acima." % falhas)
	print("")
	quit(1 if falhas > 0 else 0)
