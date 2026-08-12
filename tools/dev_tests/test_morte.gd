extends SceneTree
# ============================================================================
#  TESTE DE REGRESSÃO DA MORTE — as DUAS portas de morte do jogador.
#
#  O jogo mata o jogador por dois caminhos que convergem em
#  `Player.die_and_respawn()`:
#
#    1. VIDA ZERADA  — `take_damage()` chama a morte quando `_vida` chega a 0;
#    2. QUEDA        — `SkillSystem.process_void_check()` (do `_etapa_vida`) e
#                      o `Scoreboard._watch_falls()` do servidor disparam
#                      quando `global_position.y < Scoreboard.VOID_Y` (−40).
#
#  O que este teste prova, com número medido em cada linha:
#    1. dano até 0 mata           (vida antes / no fundo do poço / depois)
#    2. queda mata SEM dano       (posição antes/depois, 0 eventos de dano)
#    3. o placar contou as duas   (mortes do peer antes e depois)
#    4. o respawn devolve o estado (vida 2048, energia 4096, fruta na árvore)
#    5. a morte por dano credita a kill a quem bateu por último
#
#  ---------------------------------------------------------------- MEDIÇÕES
#  "Fundo do poço" (vida = 0) NÃO é observável de fora: `take_damage` chama
#  `die_and_respawn` -> `net_force_respawn` -> `_vida.restaurar()` dentro da
#  MESMA chamada, no mesmo quadro. Quem enxerga aquele instante é a HUD, que o
#  Player avisa (`hud.on_player_damaged(amount, health, max_health)`) ANTES de
#  morrer. Então o teste pendura uma sonda no grupo "hud" e lê dali o número
#  real — e a mesma sonda serve de prova NEGATIVA na queda: se caísse levando
#  dano, ela seria chamada.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_morte.gd
# ============================================================================

var _falhas := 0

# Sonda que ocupa o lugar da HUD só durante as medições. O Player fala com ela
# pelo grupo "hud" e pelo `has_method`, exatamente como fala com a HUD de verdade.
class SondaHud extends Node:
	var eventos: Array = []      # [dano, vida_no_instante, vida_max]

	func on_player_damaged(amount: float, hp: float, mhp: float) -> void:
		eventos.append([amount, hp, mhp])

	func zerar() -> void:
		eventos = []

	func menor_vida() -> float:
		var m := INF
		for e in eventos:
			m = minf(m, float(e[1]))
		return m


func _init() -> void:
	await process_frame
	# Num script `-s` os autoloads existem na árvore mas NÃO viram identificador
	# de compilação — por isso `GameFlow.x` não compila aqui e o acesso é por nó.
	var game_flow := get_root().get_node("GameFlow")
	game_flow.start_singleplayer()
	for i in 180:
		await process_frame
	# `GameFlow.hit_stop()` põe a escala em 0,06 no impacto; aqui se mede vida e
	# posição em quadros contados, então o tempo tem que andar em 1x.
	Engine.time_scale = 1.0

	var main := current_scene
	print("\n===== MORTE E RESPAWN (%s) =====" % main.name)

	var p = get_root().get_tree().get_first_node_in_group("player")
	var sb = get_root().get_tree().get_first_node_in_group("scoreboard")
	_ok(p != null, "jogador na árvore")
	_ok(sb != null, "placar na árvore")
	if p == null or sb == null:
		print("\n===== %d FALHA(S) =====" % maxi(_falhas, 1))
		quit(1)
		return

	var peer: int = str(p.name).to_int()
	_ok(peer != 0, "o nó do jogador tem nome de peer (%s -> %d)" % [p.name, peer])
	print("     vida cheia=%.0f  energia cheia=%.0f  VOID_Y=%.1f  RESPAWN=%s"
		% [p.max_health, p._vida.energia_max, Scoreboard.VOID_Y, str(Scoreboard.RESPAWN)])

	# A sonda entra no lugar da HUD de verdade (que volta pro grupo no fim).
	var hud_real = get_root().get_tree().get_first_node_in_group("hud")
	var sonda := SondaHud.new()
	sonda.name = "SondaHud"
	main.add_child(sonda)
	sonda.add_to_group("hud")
	if hud_real != null:
		hud_real.remove_from_group("hud")
	await process_frame
	var achou = get_root().get_tree().get_first_node_in_group("hud")
	_ok(achou == sonda, "a sonda de dano está no lugar da HUD (o Player fala com ela)")

	await _morte_por_dano(main, p, sb, peer, sonda)
	await _esperar_clock(sb, 2.5)          # a trava anti-recontagem dura 2 s
	await _morte_por_queda(p, sb, peer, sonda)

	# devolve a HUD de verdade ao grupo
	sonda.remove_from_group("hud")
	sonda.queue_free()
	if hud_real != null:
		hud_real.add_to_group("hud")

	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1

# Espera o relógio do placar andar. É ele que governa o `_dead_until` (2 s de
# trava anti-recontagem): sem esta espera a SEGUNDA morte simplesmente não é
# contada, e o teste acusaria um bug que não existe.
func _esperar_clock(sb, segundos: float) -> void:
	var alvo: float = float(sb._clock) + segundos
	var teto := 6000
	while float(sb._clock) < alvo and teto > 0:
		Engine.time_scale = 1.0
		await process_frame
		teto -= 1

func _mortes(sb, peer: int) -> int:
	for linha in sb.ranking():
		if int(linha[0]) == peer:
			return int(linha[2])
	return 0

func _kills(sb, peer: int) -> int:
	for linha in sb.ranking():
		if int(linha[0]) == peer:
			return int(linha[1])
	return 0

# ------------------------------------------------------- 1. morte por DANO
# Inclui o crédito de kill (item 5): o agressor é um corpo separado, no grupo
# "player" e com nome de peer — o mesmo contrato de um jogador remoto. O aviso
# `register_hit` é o que a `DamageZone` faz no servidor a cada acerto
# (src/effects/DamageZone.gd:52), então o caminho testado é o de produção.
func _morte_por_dano(main: Node, p, sb, peer: int, sonda) -> void:
	print("\n-- 1. morte por DANO (vida chega a 0) + crédito de kill --")

	var vilao := Node3D.new()
	vilao.name = "99"
	vilao.add_to_group("player")
	main.add_child(vilao)
	await process_frame

	var mortes_antes := _mortes(sb, peer)
	var kills_antes := _kills(sb, 99)

	p.health = p.max_health
	p.global_position = Vector3(12, 3, 12)     # longe do ponto de respawn
	await process_frame
	var pos_antes: Vector3 = p.global_position
	var vida_antes: float = p.health
	sonda.zerar()

	sb.register_hit(p, vilao)                  # "quem bateu por último foi o 99"

	p.take_damage(2000.0)
	var vida_meio: float = p.health
	p.take_damage(vida_meio)                   # golpe fatal: leva a vida a 0
	for i in 8:
		await process_frame

	var vida_depois: float = p.health
	var pos_depois: Vector3 = p.global_position
	var fundo: float = sonda.menor_vida()
	var dist: float = pos_depois.distance_to(Scoreboard.RESPAWN)

	print("     vida: antes=%.0f  ->  parcial=%.0f  ->  FUNDO DO POÇO=%.0f  ->  depois=%.0f"
		% [vida_antes, vida_meio, fundo, vida_depois])
	print("     posição: antes=%s  depois=%s  (distância do RESPAWN=%.2f m)"
		% [str(pos_antes), str(pos_depois), dist])
	print("     eventos de dano vistos pela sonda: %d" % sonda.eventos.size())

	_ok(vida_antes == 2048.0, "vida cheia antes do golpe = %.0f" % vida_antes)
	_ok(sonda.eventos.size() == 2, "os 2 golpes chegaram ao Player (%d eventos)" % sonda.eventos.size())
	_ok(fundo == 0.0, "a vida chegou a ZERO no golpe fatal (fundo medido=%.0f)" % fundo)
	_ok(vida_depois == 2048.0, "depois da morte a vida voltou cheia (%.0f)" % vida_depois)
	_ok(dist < 3.0, "o corpo foi parar no RESPAWN %s (a %.2f m, veio de %.1f m)"
		% [str(Scoreboard.RESPAWN), dist, pos_antes.distance_to(Scoreboard.RESPAWN)])

	# ---- 3. o placar contou / 5. a kill foi creditada ----
	var mortes_depois := _mortes(sb, peer)
	var kills_depois := _kills(sb, 99)
	print("     placar — mortes do peer %d: %d -> %d | kills do agressor 99: %d -> %d"
		% [peer, mortes_antes, mortes_depois, kills_antes, kills_depois])
	_ok(mortes_depois == mortes_antes + 1,
		"o placar contou a morte por dano (%d -> %d)" % [mortes_antes, mortes_depois])
	_ok(kills_depois == kills_antes + 1,
		"a kill foi creditada a quem bateu por último (%d -> %d)" % [kills_antes, kills_depois])

	vilao.queue_free()

# ------------------------------------------------------ 2. morte por QUEDA
# O ponto: a queda mata por POSIÇÃO, não por vida. Então o jogador vai pro
# buraco com a vida PROPOSITALMENTE parcial (1000) — se a morte viesse de dano,
# a sonda registraria evento e a vida passaria por 0 antes de restaurar.
# Aproveita a mesma morte para checar o item 4 (respawn devolve o estado).
func _morte_por_queda(p, sb, peer: int, sonda) -> void:
	print("\n-- 2. morte por QUEDA (y < VOID_Y) sem dano nenhum --")

	var mortes_antes := _mortes(sb, peer)
	var kills_antes := _kills(sb, 99)

	p.health = 1000.0
	p.energy = 100.0
	p.equip_fruit("hie_hie")                   # some da árvore ao ser equipada
	await process_frame

	var vida_antes: float = p.health
	var energia_antes: float = p.energy
	var fruta_antes: String = p.current_fruit_id
	sonda.zerar()

	var alvo := Vector3(0, Scoreboard.VOID_Y - 40.0, 0)
	p.velocity = Vector3.ZERO
	p.global_position = alvo
	var pos_antes: Vector3 = p.global_position

	var menor_vida := vida_antes
	for i in 20:
		await process_frame
		menor_vida = minf(menor_vida, float(p.health))

	var pos_depois: Vector3 = p.global_position
	var vida_depois: float = p.health
	var energia_depois: float = p.energy
	var fruta_depois: String = p.current_fruit_id
	var dist: float = pos_depois.distance_to(Scoreboard.RESPAWN)

	print("     posição: antes=%s (%.1f abaixo do VOID_Y=%.1f)  depois=%s  (distância do RESPAWN=%.2f m)"
		% [str(pos_antes), Scoreboard.VOID_Y - pos_antes.y, Scoreboard.VOID_Y, str(pos_depois), dist])
	print("     vida: antes=%.0f  menor lida durante a queda=%.0f  depois=%.0f"
		% [vida_antes, menor_vida, vida_depois])
	print("     eventos de dano vistos pela sonda durante a queda: %d" % sonda.eventos.size())

	_ok(pos_antes.y < Scoreboard.VOID_Y, "o jogador estava abaixo do VOID_Y (y=%.1f < %.1f)"
		% [pos_antes.y, Scoreboard.VOID_Y])
	_ok(dist < 3.0, "a queda respawnou no RESPAWN %s (a %.2f m, veio de y=%.1f)"
		% [str(Scoreboard.RESPAWN), dist, pos_antes.y])
	_ok(pos_depois.y > Scoreboard.VOID_Y, "o corpo voltou pra cima do vazio (y=%.2f)" % pos_depois.y)
	_ok(sonda.eventos.size() == 0,
		"a queda matou SEM aplicar dano (%d eventos de dano)" % sonda.eventos.size())
	_ok(menor_vida >= vida_antes,
		"a vida nunca caiu durante a queda (mínimo lido=%.0f, entrou com %.0f)" % [menor_vida, vida_antes])

	# ---- 3. o placar contou ----
	var mortes_depois := _mortes(sb, peer)
	var kills_depois := _kills(sb, 99)
	print("     placar — mortes do peer %d: %d -> %d | kills do 99 (sem bater desta vez): %d -> %d"
		% [peer, mortes_antes, mortes_depois, kills_antes, kills_depois])
	_ok(mortes_depois == mortes_antes + 1,
		"o placar contou a morte por queda (%d -> %d)" % [mortes_antes, mortes_depois])
	_ok(kills_depois == kills_antes,
		"queda sem agressor recente não deu kill a ninguém (%d -> %d)" % [kills_antes, kills_depois])

	# ---- 4. o respawn devolve o estado ----
	print("\n-- 3. o respawn devolve o estado --")
	print("     vida %.0f -> %.0f | energia %.0f -> %.0f | fruta '%s' -> '%s'"
		% [vida_antes, vida_depois, energia_antes, energia_depois, fruta_antes, fruta_depois])
	_ok(vida_depois == 2048.0, "vida cheia depois do respawn (%.0f de %.0f)" % [vida_depois, p.max_health])
	_ok(energia_depois == 4096.0, "energia cheia depois do respawn (%.0f, entrou com %.0f)"
		% [energia_depois, energia_antes])
	_ok(fruta_antes != "" and fruta_depois == "",
		"a fruta voltou pra árvore ('%s' -> '%s')" % [fruta_antes, fruta_depois])
