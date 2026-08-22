extends SceneTree
# ============================================================================
#  TESTE DE FÍSICA DO KNOCKBACK — o boneco tem que VOAR DE VERDADE.
#
#  Rodar:
#    godot --headless --path . --script src/tests/test_physics.gd
#
#  ------------------------------------------------------- POR QUE FOI REESCRITO
#  (2026-08-21) A versão anterior herdava de `src/tests/BaseTest.gd` e NUNCA
#  testou nada. Duas falhas somadas:
#
#   1. CENÁRIO NÃO MONTAVA. O `_init()` do `BaseTest` fazia `load("res://Player.gd")`
#      na PRIMEIRA linha, antes de qualquer `await`. Num script `-s` o MainLoop
#      nasce ANTES de os autoloads entrarem na árvore, e o `Player.gd` cita
#      `FruitNet` (linha 1464) — o script não compila, `load(...).new()` devolve
#      `null` e o `player` fica Nil. Daí "Identifier not found: FruitNet" seguido
#      de "Nonexistent function 'new'".
#      ⚠️ A cura é a mesma de `tools/dev_tests/test_arena.gd`: `await process_frame`
#      ANTES de tocar em qualquer coisa do jogo, e subir o jogo de verdade pelo
#      `GameFlow` (que já está na árvore) em vez de instanciar o Player na mão.
#
#   2. FALSO POSITIVO. A asserção era `distance_to(CENTER) > 1.0`. Como o
#      `take_damage` estourava (player Nil), o boneco NUNCA levava knockback —
#      mas ele nascia em (0,0,-8) e o CENTER é (0,4,-8), 4 m de distância. O teste
#      media a distância até um ponto onde o boneco nunca esteve e imprimia
#      "SUCESSO: O Dummy foi empurrado pela física!" sem nada ter se movido.
#      Falso positivo é pior que falha: o teste virou um carimbo.
#
#  O QUE ESTE TESTE MEDE AGORA, com número em cada linha:
#    1. o cenário montou (jogador e boneco na árvore) — se não, FALHA e sai != 0;
#    2. o golpe chegou: vida ANTES − vida DEPOIS = o dano pedido;
#    3. o "impact frame hold": no quadro do golpe a velocidade é ZERADA de
#       propósito (`TrainingDummy.take_damage`), o empurrão só entra no fim do
#       hitstop — medir velocidade cedo demais leria 0 e acusaria bug que não há;
#    4. o boneco GANHOU velocidade (pico medido quadro a quadro);
#    5. o boneco SAIU DO LUGAR, e saiu PARA O LADO CERTO (−Z, o do empurrão),
#       comparando posição antes × depois.
#
#  ⚠️ ARMADILHA DA MEDIÇÃO: o pico de deslocamento é medido a CADA quadro, não
#  só no fim. A 30 m/s o boneco sai da plataforma, cai, cruza o VOID_Y e o
#  próprio `TrainingDummy._reset()` o teleporta de volta pro CENTER — quem
#  olhasse só a posição final poderia lê-lo de volta na origem e acusar
#  "não se moveu" depois de ele ter voado 20 m.
#
#  ⚠️ `Engine.time_scale` é forçado em 1.0 dentro dos laços de espera: o
#  `GameFlow.hit_stop()` põe o tempo em 0,06 no impacto, e aqui se mede
#  velocidade e distância em tempo real.
#
#  ⚠️ POR QUE NÃO HERDA MAIS DE `BaseTest.gd`: este teste passou a subir o JOGO
#  DE VERDADE (Main.tscn pelo GameFlow), como `tools/dev_tests/test_arena.gd` e
#  `test_morte.gd`. A arena mínima do `BaseTest` monta um Player na mão numa cena
#  de teste; o knockback aqui é medido no mesmo cenário em que o jogador joga.
#  Se um dia valer a pena unificar, o caminho é portar estas asserções para os
#  ganchos do `BaseTest` — o que NÃO pode voltar é a asserção sem medição.
# ============================================================================

var _falhas := 0

# Dano e empurrão do golpe de teste. São os mesmos números da versão antiga do
# teste — o que mudou foi a MEDIÇÃO, não o estímulo.
const DANO := 50.0
const KB := Vector3(0, 10, -30)
const HITSTUN := 0.8


func _init() -> void:
	# ⚠️ PRIMEIRA linha, sempre. Ver item 1 do cabeçalho: sem este quadro de
	# folga os autoloads não existem e nada do jogo compila.
	await process_frame
	# Num script `-s` os autoloads existem na ÁRVORE mas NÃO viram identificador
	# de compilação — por isso `GameFlow.x` não compila aqui e o acesso é por nó.
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(4.0)
	Engine.time_scale = 1.0

	print("\n===== FÍSICA DO KNOCKBACK =====")

	var p := _jogador()
	var d = get_first_node_in_group("dummy")
	_ok(p != null, "jogador na árvore")
	_ok(d != null, "boneco de treino na árvore")
	if p == null or d == null:
		# Sem cenário não há teste. Sair com 0 aqui é justamente o falso positivo
		# que este arquivo existe para matar.
		print("\n===== %d FALHA(S): o cenário NÃO montou =====" % maxi(_falhas, 1))
		quit(1)
		return

	# ⚠️ TIRA OS OUTROS BONECOS DO CAMINHO. O `AutoDummy` persegue e ATACA
	# sozinho; um golpe dele no meio da medição empurraria o alvo e o teste
	# passaria (ou falharia) por motivo errado. Mesma limpeza do `test_arena`.
	for e in get_nodes_in_group("enemy"):
		if e != d and e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)

	await _knockback(p, d)

	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ o teste
func _knockback(p: Node3D, d: Node3D) -> void:
	print("\n-- 1. o golpe empurra o boneco (medido) --")

	# ⚠️ 1000 -> 2048 em 2026-08-21 (`TrainingDummy.MAX_HP`). Qualquer conta de
	# "quantos golpes para matar" feita contra o boneco estava errada por 2x, e
	# um teste que ainda esperasse 1000 passaria a mentir. Por isso a vida cheia
	# é CONFERIDA aqui, e só depois usada como linha de base.
	var vida_max: float = float(d.MAX_HP)
	_ok(vida_max == 2048.0, "vida cheia do boneco = %.0f (era 1000 antes de 2026-08-21)" % vida_max)

	# Cenário limpo: boneco no chão, parado, sem pose de golpe pendurada.
	d.global_position = Vector3(0, 1.0, -8.0)
	d.velocity = Vector3.ZERO
	d.health = vida_max
	d.set_meta("damage_immune", false)
	d.set_meta("is_frozen", false)
	await _esperar(0.5)                       # deixa assentar no chão
	d.velocity = Vector3.ZERO
	await process_frame

	var pos0: Vector3 = d.global_position
	var vida0: float = d.health
	print("     antes: pos=%s vida=%.0f" % [str(pos0), vida0])

	d.take_damage(DANO, p.global_position, KB, HITSTUN)

	# Lido no MESMO quadro da chamada, de propósito (item 3 do cabeçalho).
	var vel_no_golpe: Vector3 = d.velocity
	var vida1: float = d.health

	# ---- janela de medição: pico de velocidade e pico de deslocamento --------
	var t0 := Time.get_ticks_msec()
	var pico_vel := 0.0
	var pico_dist := 0.0
	var desloc := Vector3.ZERO
	while Time.get_ticks_msec() - t0 < 700:
		Engine.time_scale = 1.0
		await process_frame
		if not is_instance_valid(d):
			break
		pico_vel = maxf(pico_vel, Vector2(d.velocity.x, d.velocity.z).length())
		var dd: Vector3 = d.global_position - pos0
		if dd.length() > pico_dist:
			pico_dist = dd.length()
			desloc = dd

	print("     dano: vida %.0f -> %.0f (pedido %.0f)" % [vida0, vida1, DANO])
	print("     velocidade: no quadro do golpe=%s | pico planar medido=%.1f m/s" % [str(vel_no_golpe), pico_vel])
	print("     deslocamento no pico: %s (%.2f m)" % [str(desloc), pico_dist])

	_ok(absf((vida0 - vida1) - DANO) < 0.01,
		"o golpe CHEGOU no boneco: tirou %.0f de vida (pedido %.0f)" % [vida0 - vida1, DANO])
	_ok(vel_no_golpe == Vector3.ZERO,
		"impact frame hold: no quadro do golpe a velocidade é zerada (lido %s)" % str(vel_no_golpe))
	_ok(pico_vel > 5.0,
		"o empurrão VIROU velocidade depois do hitstop (pico %.1f m/s, empurrão pedido %.0f m/s)"
			% [pico_vel, Vector2(KB.x, KB.z).length()])
	_ok(pico_dist > 1.0,
		"o boneco SAIU DO LUGAR: %.2f m de %s (não é a distância até um ponto qualquer)" % [pico_dist, str(pos0)])
	_ok(desloc.z < -0.5,
		"e voou para o lado CERTO — o empurrão era −Z e ele andou %.2f m em Z" % desloc.z)


# ------------------------------------------------------------------ utilidades
func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1

# O jogador local é o que tem autoridade — no singleplayer é um só, mas pedir a
# autoridade evita pegar um boneco de rede se um dia houver outro na árvore.
func _jogador() -> Node3D:
	for x in get_nodes_in_group("player"):
		if x is Node3D and x.is_multiplayer_authority():
			return x
	return null

# Espera em tempo REAL. No headless o número de quadros por segundo não é 60, e
# o `hit_stop` do GameFlow mexe no `time_scale` — por isso as duas coisas aqui.
func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		Engine.time_scale = 1.0
		await process_frame
