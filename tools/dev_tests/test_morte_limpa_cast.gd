extends SceneTree
## MORRER LIMPA O ESTADO DE COMBATE.
##
## ⚠️ Este teste existe por causa de um bug que TRAVAVA O JOGO, relatado jogando
## em 2026-08-12: quem morria **segurando** a tecla de uma skill ficava com
## `_charging` e `is_casting` verdadeiros PARA SEMPRE. Duas consequências, as
## duas permanentes:
##
##   • `_slot_em_uso()` devolvia aquele slot eternamente, e o laço de recarga
##     congelava todos os outros — "o contador trava e nunca recarrega";
##   • `CastController.comecar()` saía no `if _carregando: return`, ou seja
##     NENHUM poder funcionava mais pelo resto da partida.
##
## O respawn devolvia vida, fruta e recarga — e deixava o cast pendurado.
var _f := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _w(4.0)
	var p: Node = null
	for x in get_nodes_in_group("player"):
		if x.is_multiplayer_authority(): p = x
	if p == null:
		print("❌ sem jogador — a porta 24565 pode estar ocupada"); quit(1); return

	p.combat_mode = "fruit"
	p.equip_fruit("goro_goro")
	p.energy = p.max_energy
	await _w(1.0)

	print("===== MORRER LIMPA O ESTADO DE COMBATE =====")
	print("\n-- 1. morre SEGURANDO a tecla (o caso que travava) --")
	p.begin_charge("V")            # segura e nunca solta
	await _w(0.6)
	_ok(p._charging, "o cast começou (carregando=%s, slot='%s')" % [p._charging, p._slot_em_uso()])
	p.global_position = Vector3(0, -80, 0)    # cai do mapa
	await _w(2.5)
	_ok(not p._charging, "depois de morrer NÃO está mais carregando")
	_ok(not bool(p.get_meta("is_casting", false)), "a marca `is_casting` foi limpa")
	_ok(p._slot_em_uso() == "", "nenhum slot ficou 'em uso' (era o que congelava a recarga)")
	_ok(float(p._movement_locked_timer) <= 0.0, "o travamento de movimento foi solto")

	print("\n-- 2. e os poderes VOLTAM a funcionar --")
	p.equip_fruit("goro_goro")     # pega a fruta de novo (a morte devolveu ao mapa)
	p.energy = p.max_energy
	await _w(0.5)
	p.begin_charge("X")
	await _w(0.3)
	_ok(p._charging or p._skill_cooldowns.get("X", 0.0) > 0.0,
		"conjurar de novo funciona (carregando=%s, recarga X=%.1f)" % [p._charging, p._skill_cooldowns.get("X", 0.0)])
	p.release_charge("X")
	await _w(0.5)

	print("\n-- 3. a recarga volta a ANDAR --")
	var antes: float = float(p._skill_cooldowns.get("X", 0.0))
	await _w(1.5)
	var depois: float = float(p._skill_cooldowns.get("X", 0.0))
	_ok(antes > 0.0, "o X entrou em recarga (%.1f s)" % antes)
	_ok(depois < antes, "e ela ANDOU: %.2f -> %.2f em 1,5 s" % [antes, depois])

	print("\n===== %s =====" % ("ESTADO LIMPO" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _f += 1

func _w(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0): await process_frame
