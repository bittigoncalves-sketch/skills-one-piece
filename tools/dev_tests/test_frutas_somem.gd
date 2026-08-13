extends SceneTree
## AS FRUTAS SOMEM DO MAPA — regra do dono, 2026-08-12.
##
## "A fruta some ao ser adquirida e só reaparece quando o dono do poder MORRER
##  ou COMER OUTRA fruta."
##
## Justificativa dele: equilibrar o PvP, para que nem todos os jogadores estejam
## com os mesmos poderes.
##
## ⚠️ O QUE ESTE TESTE PEGA, e que passou meses despercebido: equipar tem TRÊS
## entradas, e só uma escondia a fruta. A de NASCENÇA (`Main.gd:114`) não
## escondia — o jogador nascia com `suna_suna` e a `suna_suna` continuava na
## árvore. Em partida de dois, os dois nasciam com ela e o mapa ainda oferecia
## uma terceira.
var _f := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(4.0)
	var p: Node = null
	for x in get_nodes_in_group("player"):
		if x.is_multiplayer_authority(): p = x
	if p == null:
		print("❌ sem jogador — a porta 24565 pode estar ocupada"); quit(1); return

	var mapa: Dictionary = TreeAndFruitGenerator.active_fruits_map
	print("===== AS FRUTAS SOMEM DO MAPA =====")
	print("   frutas registradas: %d | fruta de nascença: '%s'" % [mapa.size(), p.current_fruit_id])

	print("\n-- 1. a fruta de NASCENÇA já sai do mapa --")
	var nasceu: String = str(p.current_fruit_id)
	_ok(nasceu != "", "o jogador nasceu com uma fruta ('%s')" % nasceu)
	_ok(not _visivel(mapa, nasceu), "'%s' NÃO está visível na árvore (o dono já a tem)" % nasceu)
	_ok(_conta_visiveis(mapa) == mapa.size() - 1,
		"exatamente uma fruta sumiu: %d visíveis de %d" % [_conta_visiveis(mapa), mapa.size()])

	print("\n-- 2. comer OUTRA fruta devolve a anterior e some com a nova --")
	var nova := ""
	for id in mapa:
		if id != nasceu and _visivel(mapa, id):
			nova = id; break
	p.equip_fruit(nova)
	await _esperar(0.5)
	_ok(not _visivel(mapa, nova), "a nova ('%s') sumiu da árvore" % nova)
	_ok(_visivel(mapa, nasceu), "a anterior ('%s') VOLTOU para a árvore" % nasceu)
	_ok(_conta_visiveis(mapa) == mapa.size() - 1,
		"continua exatamente uma fora do mapa: %d de %d" % [_conta_visiveis(mapa), mapa.size()])

	print("\n-- 3. MORRER devolve a fruta ao mapa --")
	var antes := _conta_visiveis(mapa)
	p.take_damage(p.max_health + 1.0)
	await _esperar(1.5)
	_ok(str(p.current_fruit_id) == "", "morrer largou o poder ('%s')" % str(p.current_fruit_id))
	_ok(_visivel(mapa, nova), "'%s' voltou para a árvore depois da morte" % nova)
	_ok(_conta_visiveis(mapa) == mapa.size(),
		"o mapa voltou COMPLETO: %d visíveis de %d (era %d)" % [_conta_visiveis(mapa), mapa.size(), antes])

	print("\n===== %s =====" % ("FRUTAS OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func _visivel(mapa: Dictionary, id: String) -> bool:
	if not mapa.has(id): return false
	var n = mapa[id]
	return is_instance_valid(n) and (n as Node3D).visible

func _conta_visiveis(mapa: Dictionary) -> int:
	var n := 0
	for id in mapa:
		if _visivel(mapa, id): n += 1
	return n

func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _f += 1

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0): await process_frame
