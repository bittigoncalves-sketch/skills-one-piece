extends SceneTree
# ============================================================================
#  TESTE DO CORTE DE ESPADA — o golpe pega o TRONCO, não as PERNAS.
#
#  Rodar:
#    godot --headless --path . --script src/tests/test_anim.gd
#
#  ------------------------------------------------------- POR QUE FOI REESCRITO
#  (2026-08-21) A versão anterior herdava de `src/tests/BaseTest.gd`, que fazia
#  `load("res://Player.gd").new()` na primeira linha do `_init()`. Num script
#  `-s` o MainLoop nasce ANTES de os autoloads entrarem na árvore, e o
#  `Player.gd` cita `FruitNet` — o script não compila, `new()` devolve `null` e
#  todo `player.x` do teste estourava. Ver o cabeçalho de `test_physics.gd`.
#  ⚠️ A cura é a de `tools/dev_tests/test_arena.gd`: `await process_frame` ANTES
#  de tocar em qualquer coisa, e subir o jogo de verdade pelo `GameFlow`.
#
#  E a asserção antiga ("`player.velocity.x > 0` 5 quadros depois do golpe") não
#  mediria o que promete nem com o cenário montado: `_etapa_locomocao` faz
#  `velocity.x = q.dir.x * effective_speed` — ATRIBUIÇÃO a partir do teclado, todo
#  quadro. Sem tecla pressionada a velocidade volta a zero em 1 quadro, com ou sem
#  ataque. O teste estaria medindo a ausência de teclado, não o golpe.
#
#  ------------------------------------------------------------- O QUE PRENDE
#  Quem trava as pernas é o CLIPE ASSADO: `ProceduralAnimator.update()` começa com
#      if _baked != null: _apply_baked(delta); return
#  ou seja, enquanto um clipe do Mixamo toca, a locomoção procedural inteira morre
#  (marcha, idle, ar). O combo desarmado usa `play_baked` e por isso planta o
#  corpo; o corte de espada usa `play_procedural_slash`, que zera `_baked` de
#  propósito ("Cancela baked clip para liberar as pernas") e só soma braços/tronco.
#
#  O QUE ESTE TESTE MEDE, com número em cada linha:
#    1. o cenário montou (jogador na árvore, com rig procedural) — se não, FALHA;
#    2. com espada, `_net_play_melee(0)` liga o corte procedural e NÃO liga clipe;
#    3. a chamada do golpe não zera a velocidade horizontal no mesmo quadro;
#    4. MEDIDO: a amplitude da marcha nas PERNAS durante o corte continua
#       comparável à da locomoção livre (o corte não travou as pernas);
#    5. CONTRAPROVA: sem espada o golpe é clipe assado e a mesma medição desaba —
#       sem ela o item 4 poderia passar sozinho e não provaria nada.
#
#  ⚠️ A amplitude é medida chamando `ProceduralAnimator.update()` na mão, com
#  velocidade sintética e delta fixo, sem esperar quadro: dentro do jogo a
#  locomoção manda `velocity` = 0 (sem teclado) e as pernas ficariam paradas nas
#  TRÊS medições, empatando tudo em zero.
#
#  ⚠️ POR QUE NÃO HERDA MAIS DE `BaseTest.gd`: mede-se o rig do jogador REAL, no
#  jogo subido pelo GameFlow (mesmo caminho de `tools/dev_tests/test_arena.gd`),
#  e não um Player montado na mão numa arena de teste. Se um dia valer a pena
#  unificar, o caminho é portar estas asserções para os ganchos do `BaseTest`.
# ============================================================================

var _falhas := 0

# Papéis das pernas no rig procedural (mesma nomenclatura de `test_arena.gd`).
const PERNAS := ["Thigh_R", "Shin_R", "Thigh_L", "Shin_L"]
# Velocidade sintética da medição: `SPEED` do Player (4,2 m/s) = marcha cheia.
const VEL_MARCHA := Vector3(4.2, 0.0, 0.0)
const QUADROS := 40          # ~0,66 s a 60 fps: mais de um ciclo de passada
const DT := 1.0 / 60.0


func _init() -> void:
	# ⚠️ PRIMEIRA linha, sempre — sem este quadro de folga os autoloads não
	# existem e nada do jogo compila.
	await process_frame
	# Num script `-s` os autoloads existem na ÁRVORE mas NÃO viram identificador
	# de compilação — por isso o acesso ao `GameFlow` é por nó.
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(4.0)
	Engine.time_scale = 1.0

	print("\n===== CORTE DE ESPADA x LOCOMOÇÃO =====")

	var p := _jogador()
	_ok(p != null, "jogador na árvore")
	if p == null:
		print("\n===== %d FALHA(S): o cenário NÃO montou =====" % maxi(_falhas, 1))
		quit(1)
		return

	var pa = p._proc_anim
	_ok(pa != null, "o jogador usa o rig PROCEDURAL (é ele que este teste mede)")
	if pa == null:
		# Personagem skinnado usa `_skel_anim` e `_net_play_melee` sai fora logo
		# no `if not _proc_anim: return` — não há o que medir aqui.
		print("\n===== %d FALHA(S): sem rig procedural =====" % maxi(_falhas, 1))
		quit(1)
		return
	_ok(_tem_pernas(pa), "o rig expõe as pernas medidas (%s)" % str(PERNAS))

	# ---- linha de base: locomoção LIVRE, sem golpe nenhum -------------------
	pa._baked = null
	pa._sword_slash_type = -1
	var amp_livre := _amplitude_pernas(pa)
	print("     amplitude das pernas na locomoção livre: %.1f°" % amp_livre)
	_ok(amp_livre > 5.0, "a marcha procedural anda de verdade na linha de base (%.1f°)" % amp_livre)

	# ---- 1. com ESPADA: corte procedural ------------------------------------
	print("\n-- 1. com espada o golpe é PROCEDURAL (braços/tronco) --")
	p.equipped_weapon = "sword"
	p.velocity.x = 5.0
	p._net_play_melee(0)
	var vel_pos_golpe: float = p.velocity.x
	_ok(vel_pos_golpe == 5.0,
		"a chamada do golpe não zerou a velocidade horizontal no mesmo quadro (%.1f m/s)" % vel_pos_golpe)
	_ok(int(pa._sword_slash_type) == 0, "o corte procedural 0 entrou (tipo=%d)" % int(pa._sword_slash_type))
	_ok(not pa.is_playing_baked(),
		"e NÃO ligou clipe assado — é ele que faria `update()` sair fora e travar as pernas")

	var amp_espada := _amplitude_pernas(pa)
	print("     amplitude das pernas DURANTE o corte: %.1f° (livre: %.1f°)" % [amp_espada, amp_livre])
	_ok(amp_espada > amp_livre * 0.5,
		"as pernas continuam marchando durante o corte (%.1f° = %.0f%% da livre)"
			% [amp_espada, 100.0 * amp_espada / maxf(amp_livre, 0.001)])

	# ---- 2. CONTRAPROVA: sem espada o golpe é clipe assado -------------------
	# Sem este bloco o item anterior passaria mesmo que a medição estivesse
	# quebrada (medindo sempre a mesma amplitude, por exemplo).
	print("\n-- 2. contraprova: sem espada o golpe TOMA o corpo --")
	p.equipped_weapon = ""
	p._net_play_melee(0)
	_ok(pa.is_playing_baked(), "sem espada o golpe é clipe assado (Mixamo retargetado)")
	# A janela é a TRAVA do golpe, lida do frame data — não um número escrito à
	# mão que envelhece junto com a tabela.
	var quadros_golpe: int = int(ceil(Melee.recuo(0) / DT))
	var amp_punho := _amplitude_pernas(pa, quadros_golpe)
	# Referência justa: a mesma régua, mas sem golpe nenhum. Comparar uma amostra
	# de 24 quadros com outra de 40 compararia réguas, não comportamentos.
	pa._baked = null
	pa._sword_slash_type = -1
	var amp_livre_curta := _amplitude_pernas(pa, quadros_golpe)
	print("     amplitude das pernas DURANTE o soco assado: %.1f° (livre na mesma janela de %d quadros: %.1f°)"
		% [amp_punho, quadros_golpe, amp_livre_curta])
	_ok(amp_punho < amp_livre_curta * 0.9,
		"o clipe assado PRENDE as pernas: %.1f° contra %.1f° livres na mesma janela (%.0f%%)"
			% [amp_punho, amp_livre_curta, 100.0 * amp_punho / maxf(amp_livre_curta, 0.001)])

	# devolve o rig ao estado neutro (o jogo segue rodando até o quit)
	pa._baked = null
	pa._sword_slash_type = -1
	p.equipped_weapon = "sword"

	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


# ------------------------------------------------------------------ medição
# Amplitude (max − min) somada das juntas das pernas, em graus, ao longo de
# `QUADROS` chamadas de `update()` com velocidade de marcha.
#
# ⚠️ Roda SEM `await`: cada chamada de `update()` é uma função pura sobre os nós
# do rig, e esperar quadro deixaria a locomoção do jogo (velocity = 0, sem
# teclado) escrever por cima entre as amostras.
# `quadros` = tamanho da amostra. O padrão (`QUADROS`, 40) serve para a
# locomoção livre e para o corte de espada, que são contínuos.
#
# ⚠️ O CLIPE ASSADO PRECISA DE JANELA PRÓPRIA DESDE 2026-08-25. Com frame data
# ele toma o corpo por 0,40 s — 24 quadros — e não mais pelos 2,23 s do clipe
# inteiro. Amostrar 40 quadros mede 24 de golpe e 16 de MARCHA LIVRE, e a média
# resultante (338,8°) empatava com a do corte de espada (338,6°): a contraprova
# deixava de contrastar por causa do tamanho da régua, não do comportamento.
func _amplitude_pernas(pa, quadros: int = QUADROS) -> float:
	var lo := {}
	var hi := {}
	for i in quadros:
		pa.update(VEL_MARCHA, true, false, DT, 0.0)
		for papel in PERNAS:
			var n = pa._n.get(papel)
			if n == null:
				continue
			var r: Vector3 = (n as Node3D).rotation
			if not lo.has(papel):
				lo[papel] = r
				hi[papel] = r
			lo[papel] = Vector3(minf(lo[papel].x, r.x), minf(lo[papel].y, r.y), minf(lo[papel].z, r.z))
			hi[papel] = Vector3(maxf(hi[papel].x, r.x), maxf(hi[papel].y, r.y), maxf(hi[papel].z, r.z))
	var total := 0.0
	for papel in lo.keys():
		total += rad_to_deg((hi[papel] - lo[papel]).length())
	return total

func _tem_pernas(pa) -> bool:
	for papel in PERNAS:
		if not pa._n.has(papel):
			return false
	return true


# ------------------------------------------------------------------ utilidades
func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1

func _jogador() -> Node3D:
	for x in get_nodes_in_group("player"):
		if x is Node3D and x.is_multiplayer_authority():
			return x
	return null

# Espera em tempo REAL (no headless não são 60 fps) forçando `time_scale` em 1.0:
# o `GameFlow.hit_stop()` põe o tempo em 0,06 no impacto.
func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		Engine.time_scale = 1.0
		await process_frame
