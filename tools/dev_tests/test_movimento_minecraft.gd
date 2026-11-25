extends SceneTree
# ============================================================================
#  MOVIMENTAÇÃO DO MINECRAFT (31/10/2026) — `McMovimento` contra os números do jogo original:
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_movimento_minecraft.gd
#
#  Mundo de teste: chão plano em y = 0 (bloco comum, atrito 0,6). O "corpo" faz o que o
#  `Entity.move` faz: barra o deslocamento no chão e avisa no tick seguinte.
#  Referências (wiki do Minecraft Java, 1.20): andar 4,317 b/s, correr 5,612 b/s, pulo 1,2522
#  bloco em 12 ticks, velocidade terminal de queda 3,92 b/tick, gelo mais rápido que pedra.
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func perto(a: float, b: float, tol := 0.001) -> bool:
	return absf(a - b) <= tol


## CorpoDeTeste mínimo: posição, e a conversão deslocamento → feedback do próximo tick.
class CorpoDeTeste:
	extends RefCounted
	var m := McMovimento.new()
	var pos := Vector3.ZERO
	var amb := McMovimento.Ambiente.new()
	var atrito := McMovimento.ATRITO_PADRAO
	var piso := 0.0

	func tick() -> void:
		amb.atrito_bloco = atrito
		var pedido := m.avancar(amb)
		var real := pedido
		amb.colisao_x = false
		amb.colisao_z = false
		amb.colisao_vertical = false
		if pos.y + pedido.y < piso:
			real.y = piso - pos.y
			amb.colisao_vertical = true
		pos += real
		amb.no_chao = absf(pos.y - piso) < 1.0e-9 and pedido.y <= 0.0


func rodar() -> void:
	print("\n-- A. andar e correr no chão --")
	var c := CorpoDeTeste.new()
	c.amb.no_chao = true
	c.m.frente = 1.0
	c.m.yaw = 0.0
	for i in 60:
		c.tick()
	var antes := c.pos.z
	for i in 20:
		c.tick()
	ok(perto(c.pos.z - antes, 4.317, 0.02), "andar: %.3f blocos/s (Minecraft: 4,317)" % (c.pos.z - antes))
	ok(not c.m.correndo, "andar sem pedir corrida não corre")

	var r := CorpoDeTeste.new()
	r.amb.no_chao = true
	r.m.frente = 1.0
	r.m.correr_pedido = true
	for i in 60:
		r.tick()
	var antes_r := r.pos.z
	for i in 20:
		r.tick()
	ok(r.m.correndo and perto(r.pos.z - antes_r, 5.612, 0.03), "correr: %.3f blocos/s (Minecraft: 5,612)" % (r.pos.z - antes_r))

	var ag := CorpoDeTeste.new()
	ag.amb.no_chao = true
	ag.m.frente = 1.0
	ag.m.agachar = true
	for i in 60:
		ag.tick()
	var antes_a := ag.pos.z
	for i in 20:
		ag.tick()
	ok(perto(ag.pos.z - antes_a, 1.295, 0.02), "agachar: %.3f blocos/s (Minecraft: 1,295)" % (ag.pos.z - antes_a))

	var d := CorpoDeTeste.new()
	d.amb.no_chao = true
	d.m.frente = 1.0
	d.m.lado = 1.0
	for i in 80:
		d.tick()
	var vel_diag := Vector3(d.m.delta.x, 0.0, d.m.delta.z).length()
	var vel_reta := Vector3(c.m.delta.x, 0.0, c.m.delta.z).length()
	# Quirk do original: (0,98; 0,98) tem comprimento > 1 e é normalizado para 1,0 — 1/0,98 da reta.
	ok(perto(vel_diag / vel_reta, 1.0 / 0.98, 0.002), "diagonal (W+A) = reta ÷ 0,98, como no original: %.4f vs %.4f" % [vel_diag, vel_reta])
	ok(d.pos.x > 0.0 and d.pos.z > 0.0, "esquerda é +X quando se olha para +Z (yaw 0)")

	print("\n-- B. pulo --")
	var p := CorpoDeTeste.new()
	p.amb.no_chao = true
	p.m.pulo = true
	var pico := 0.0
	var ticks_no_ar := 0
	var saiu := false
	for i in 40:
		p.tick()
		pico = maxf(pico, p.pos.y)
		if p.pos.y > 0.0:
			saiu = true
			ticks_no_ar += 1
		elif saiu:
			break
	ok(perto(pico, 1.2522, 0.002), "altura do pulo: %.4f blocos (Minecraft: 1,2522)" % pico)
	ok(ticks_no_ar == 11 or ticks_no_ar == 12, "tempo no ar: %d ticks (Minecraft: 12)" % ticks_no_ar)

	var s := CorpoDeTeste.new()
	s.amb.no_chao = true
	s.m.frente = 1.0
	s.m.correr_pedido = true
	for i in 60:
		s.tick()
	s.m.pulo = true
	var z0 := s.pos.z
	saiu = false
	for i in 40:
		s.tick()
		if s.pos.y > 0.0:
			saiu = true
		elif saiu:
			break
	ok(s.pos.z - z0 > 3.5 and s.pos.z - z0 < 4.8, "pulo correndo: %.2f blocos de alcance (Minecraft ≈ 4)" % (s.pos.z - z0))

	var atraso := CorpoDeTeste.new()
	atraso.amb.no_chao = true
	atraso.m.pulo = true
	var pulos := 0
	var vy_antes := 0.0
	for i in 60:
		atraso.tick()
		if atraso.m.delta.y > 0.3 and vy_antes <= 0.3:
			pulos += 1
		vy_antes = atraso.m.delta.y
	ok(pulos >= 3 and pulos <= 6, "segurar pulo repete com atraso de 10 ticks (%d pulos em 60 ticks)" % pulos)

	print("\n-- C. queda --")
	var q := CorpoDeTeste.new()
	q.pos = Vector3(0, 400, 0)
	q.piso = -100000.0
	var vmax := 0.0
	for i in 600:
		q.tick()
		vmax = minf(vmax, q.m.delta.y)
	ok(perto(vmax, -3.92, 0.01), "velocidade terminal: %.3f b/tick (Minecraft: 3,92)" % vmax)
	q = CorpoDeTeste.new()
	q.pos = Vector3(0, 100, 0)
	q.piso = -1000.0
	q.amb.queda_lenta = true
	for i in 120:
		q.tick()
	ok(perto(q.m.delta.y, -0.49, 0.1) or q.m.delta.y > -0.6, "queda lenta usa gravidade 0,01 (vy = %.3f)" % q.m.delta.y)

	print("\n-- D. blocos --")
	var gelo := CorpoDeTeste.new()
	gelo.amb.no_chao = true
	gelo.atrito = McMovimento.atrito_do_bloco(&"minecraft:ice")
	gelo.m.frente = 1.0
	for i in 200:
		gelo.tick()
	# Chão: impulso = 0,1·0,216/atrito³ (menor no gelo), arrasto 0,91·atrito (maior no gelo).
	ok(perto(gelo.m.delta.z, 0.2078, 0.002), "gelo: velocidade de regime %.4f b/tick (fórmula do original: 0,2078)" % gelo.m.delta.z)
	var gelo_cedo := CorpoDeTeste.new()
	gelo_cedo.amb.no_chao = true
	gelo_cedo.atrito = McMovimento.ATRITO_GELO
	gelo_cedo.m.frente = 1.0
	var pedra_cedo := CorpoDeTeste.new()
	pedra_cedo.amb.no_chao = true
	pedra_cedo.m.frente = 1.0
	for i in 5:
		gelo_cedo.tick()
		pedra_cedo.tick()
	ok(gelo_cedo.m.delta.z < pedra_cedo.m.delta.z, "gelo arranca mais devagar que pedra (%.3f vs %.3f em 5 ticks)" % [gelo_cedo.m.delta.z, pedra_cedo.m.delta.z])
	var gelo_solta := CorpoDeTeste.new()
	gelo_solta.amb.no_chao = true
	gelo_solta.atrito = McMovimento.ATRITO_GELO
	gelo_solta.m.delta = Vector3(0, 0, 0.2)
	gelo_solta.m.frente = 0.0
	for i in 40:
		gelo_solta.tick()
	var pedra_solta := CorpoDeTeste.new()
	pedra_solta.amb.no_chao = true
	pedra_solta.m.delta = Vector3(0, 0, 0.2)
	for i in 40:
		pedra_solta.tick()
	ok(gelo_solta.pos.z > pedra_solta.pos.z * 3.0, "no gelo o corpo desliza muito mais ao soltar a tecla (%.2f vs %.2f blocos)" % [gelo_solta.pos.z, pedra_solta.pos.z])

	var alma := CorpoDeTeste.new()
	alma.amb.no_chao = true
	alma.amb.fator_velocidade_bloco = McMovimento.fator_velocidade_do_bloco(&"minecraft:soul_sand")
	alma.m.frente = 1.0
	for i in 100:
		alma.tick()
	ok(alma.m.delta.z < c.m.delta.z * 0.6, "alma de areia reduz a velocidade (%.3f vs %.3f)" % [alma.m.delta.z, c.m.delta.z])

	var mel := CorpoDeTeste.new()
	mel.amb.no_chao = true
	mel.amb.fator_pulo_bloco = McMovimento.fator_pulo_do_bloco(&"minecraft:honey_block")
	mel.m.pulo = true
	var pico_mel := 0.0
	for i in 20:
		mel.tick()
		pico_mel = maxf(pico_mel, mel.pos.y)
	ok(pico_mel < 0.5, "mel corta o pulo (pico %.2f blocos)" % pico_mel)

	print("\n-- E. água e escada --")
	var ag2 := CorpoDeTeste.new()
	ag2.pos = Vector3(0, 10, 0)
	ag2.piso = -1000.0
	ag2.amb.na_agua = true
	for i in 200:
		ag2.tick()
	ok(ag2.m.delta.y > -0.1 and ag2.m.delta.y < 0.0, "afunda devagar na água (vy = %.4f b/tick)" % ag2.m.delta.y)
	var nada := CorpoDeTeste.new()
	nada.piso = -1000.0
	nada.amb.na_agua = true
	nada.m.pulo = true
	nada.amb.altura_fluido = 1.0
	for i in 40:
		nada.tick()
	ok(nada.m.delta.y > 0.0 and nada.pos.y > 0.5, "segurar pulo na água sobe (y = %.2f)" % nada.pos.y)

	var esc := CorpoDeTeste.new()
	esc.piso = -1000.0
	esc.amb.escalavel = true
	esc.amb.colisao_x = true
	esc.m.frente = 1.0
	for i in 30:
		esc.tick()
		esc.amb.colisao_x = true
	ok(esc.m.delta.y > 0.0 or esc.pos.y > 2.0, "encostado numa escada, andar para a frente sobe (y = %.2f)" % esc.pos.y)
	var desce := CorpoDeTeste.new()
	desce.pos = Vector3(0, 50, 0)
	desce.piso = -1000.0
	desce.amb.escalavel = true
	for i in 60:
		desce.tick()
	ok(desce.m.delta.y >= -0.2, "na escada a queda é limitada a 0,15 b/tick (vy = %.3f)" % desce.m.delta.y)

	print("\n-- F. conversões --")
	ok(perto(McMovimento.yaw_do_godot(0.0), 180.0), "Godot olhando −Z = yaw 180° do Minecraft")
	var v := McMovimento.para_metros_por_segundo(Vector3(0, 0.42, 0))
	ok(perto(v.y, 0.42 * 20.0 * MundoMinePiece.METROS_POR_BLOCO, 1.0e-6), "bloco/tick → m/s respeita a escala do mundo")

	print("\n%d/%d ok" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
