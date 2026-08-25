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

	# ⚠️ OS BONECOS BATEM SOZINHOS — e este teste lia o estado bem no instante de
	# um soco deles. Medido: o corpo respawnava, a FSM voltava a Idle em 1,11 s
	# (certo), e em 2,49 s o AutoDummy acertava um Jab (−48 de vida, o número
	# exato de `Balance.MELEE`) que jogava o jogador de volta para "Stunned" —
	# 10 ms antes da asserção. O teste também começava com o jogador já
	# machucado, o que sozinho já pode recusar um `begin_charge`.
	#
	# Mesma limpeza de `test_fsm.gd` e `test_charge_up.gd`, mas em TODO o grupo
	# "enemy": desde 2026-08-23 os bonecos são criados pelo servidor por
	# interruptor, então não há um nó fixo na cena para desligar.
	for e in get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.set_meta("damage_immune", true)
		e.global_position = Vector3(0, 1.0, -1000.0)

	p.combat_mode = "fruit"
	p.equip_fruit("goro_goro")
	p.energy = p.max_energy
	p.health = p.max_health
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
	# ⚠️ `_movement_locked_timer` NÃO EXISTE MAIS — e ler um campo inexistente
	# aqui não dava "falha", dava TIMEOUT. O erro de runtime aborta o `_init()`
	# no meio da cadeia de `await`, o `quit()` nunca roda e a bateria matava o
	# processo aos 120 s. Timeout que na verdade é API velha lê como "o teste
	# está lento", e ninguém foi olhar. Ver `docs/erros.md`.
	#
	# Quem governa a trava hoje é a FSM de combate (`Player.gd`:
	# "_movement_locked_timer removido (FSM gerencia)"), e `lock_movement()`
	# virou só o carimbo do `active_skill`. As duas coisas que precisam estar
	# limpas depois da morte são exatamente essas.
	var estado_fsm: String = String(p._fsm.state.name) if p._fsm and p._fsm.state else "<sem estado>"
	_ok(estado_fsm == "Idle", "a FSM de combate voltou para Idle (lido: %s)" % estado_fsm)
	_ok(str(p.get_meta("active_skill", "")) == "",
		"o carimbo `active_skill` foi limpo (lido: '%s')" % str(p.get_meta("active_skill", "")))

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
