extends SceneTree
# Jogo dos copos (21/11/2026): lógica pura + animação por fases com semente fixa. Rodar:
#   godot --headless --path . --script tools/dev_tests/test_jogo_dos_copos.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _init() -> void:
	await process_frame
	print("\n===== JOGO DOS COPOS =====")
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var tr := JogoDosCopos.gerar_trocas(rng, 10)
	ok("10 trocas entre slots diferentes", tr.size() == 10 and tr.all(func(t): return t.x != t.y and t.x < t.y))
	var sem_repetir := true
	for i in range(1, tr.size()): sem_repetir = sem_repetir and tr[i] != tr[i - 1]
	ok("sem repetir a troca anterior", sem_repetir)
	var o := JogoDosCopos.aplicar_trocas([0, 1, 2], [Vector2i(0, 1)])
	ok("aplicar_trocas troca os slots", o == [1, 0, 2])
	var o2 := JogoDosCopos.aplicar_trocas([0, 1, 2], tr)
	ok("é permutação (sem copo perdido)", o2.size() == 3 and 0 in o2 and 1 in o2 and 2 in o2)
	# mesma semente → mesmo jogo
	var a := JogoDosCopos.new(); root.add_child(a); a.preparar(42)
	var b := JogoDosCopos.new(); root.add_child(b); b.preparar(42)
	ok("mesma semente = mesma pedra e mesmo caminho", a.pedra_no_copo() == b.pedra_no_copo() and a.slot_final_da_pedra() == b.slot_final_da_pedra())
	var dist := {}
	for s in 60:
		var g := JogoDosCopos.new(); root.add_child(g); g.preparar(s); dist[g.pedra_no_copo()] = true; g.queue_free()
	ok("a pedra cai em copos diferentes conforme a semente (3 copos usados)", dist.size() == 3)
	# fases
	ok("antes de iniciar não aceita escolha", not a.escolher(0))
	a.iniciar()
	for i in 60: a.step(0.05)
	ok("MOSTRA → EMBARALHA", a.fase == JogoDosCopos.Fase.EMBARALHA or a.fase == JogoDosCopos.Fase.ESCOLHA)
	ok("durante o embaralho não aceita escolha", a.fase != JogoDosCopos.Fase.EMBARALHA or not a.escolher(0))
	for i in 400:
		a.step(0.05)
		if a.fase == JogoDosCopos.Fase.ESCOLHA: break
	ok("chega à ESCOLHA e esconde a pedra", a.fase == JogoDosCopos.Fase.ESCOLHA and not a._pedra.visible)
	# posição física dos copos bate com a lógica
	var pos_ok := true
	for slot in 3:
		var id: int = a._ordem[slot]
		pos_ok = pos_ok and a._copos[id].position.is_equal_approx(a._slot(slot))
	ok("depois do embaralho cada copo está no seu slot", pos_ok)
	ok("a pedra está sob o copo que a lógica diz (slot final)", a._ordem.find(a.pedra_no_copo()) == a.slot_final_da_pedra())
	# mira: copo 'a._ordem[slot 0]' fica em x = -0,9
	var alvo_id: int = a._ordem[0]
	ok("copo_da_mira acha o copo sob o raio", a.copo_da_mira(Vector3(-0.9, 1.0, 3.0), Vector3(0, -0.15, -1)) == alvo_id)
	ok("raio longe de todos → -1", a.copo_da_mira(Vector3(5.0, 1.0, 3.0), Vector3(0, 0, -1)) == -1)
	var resultado := [null]
	a.escolheu.connect(func(x): resultado[0] = x)
	var certo: int = a.pedra_no_copo()
	ok("escolher o copo da pedra = acerto", a.escolher(certo) and resultado[0] == true and a.acertou)
	ok("só uma escolha (2ª ignorada)", not a.escolher(certo))
	var fim := [false]
	a.terminou.connect(func(): fim[0] = true)
	for i in 80: a.step(0.05)
	ok("revela e termina", fim[0] and a.fase == JogoDosCopos.Fase.FIM and a._pedra.visible)
	# erro
	var e := JogoDosCopos.new(); root.add_child(e); e.preparar(5); e.iniciar()
	for i in 600:
		e.step(0.05)
		if e.fase == JogoDosCopos.Fase.ESCOLHA: break
	var errado := (e.pedra_no_copo() + 1) % 3
	e.escolher(errado)
	ok("copo errado = erro", not e.acertou)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
