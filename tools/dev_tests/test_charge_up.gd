extends SceneTree
## CHARGE-UP / CHARGED SKILL — mecânica nova (tarefa 5, 2026-08-12).
##
## O que a separa de todas as outras skills:
##   • a execução 3D começa no CLIQUE, não na soltura;
##   • enquanto a tecla fica pressionada a bola CRESCE;
##   • soltar dispara com a carga que houver, na mira DAQUELE instante;
##   • levar dano TAMBÉM dispara (as outras o dano CANCELA).
var _f := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _w(4.0)
	var p: Node = null
	for x in get_nodes_in_group("player"):
		if x.is_multiplayer_authority(): p = x
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.combat_mode = "fruit"; p.equip_fruit("goro_goro"); p.energy = p.max_energy
	# ⚠️ TIRA OS BONECOS DO CAMINHO. O `AutoDummy` persegue e ATACA sozinho, e um
	# golpe dele durante a carga INTERROMPE o cast por dano — que é o
	# comportamento correto do jogo e o falso negativo perfeito para este teste
	# ("o efeito nasceu ainda com a tecla pressionada" falhava sem nada de errado
	# no charge-up). Só apareceu quando o `AutoDummy` voltou a compilar em
	# 2026-08-15 e, portanto, a existir. Mesma limpeza do `test_arena`.
	for e in get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)
	await _w(1.0)
	print("===== CHARGE-UP =====")

	print("\n-- 1. o 3D começa no CLIQUE (não espera soltar) --")
	p.begin_charge("V")
	await _w(0.9)
	var ctrl = p._cast._carregado
	_ok(is_instance_valid(ctrl), "o efeito nasceu ainda com a tecla pressionada")
	_ok(p._cast.carregando_skill(), "o Player sabe que há um golpe carregando")

	print("\n-- 2. segurar faz a bola CRESCER --")
	var c1: float = float(ctrl.carga_atual())
	await _w(1.2)
	var c2: float = float(ctrl.carga_atual())
	_ok(c2 > c1, "a carga subiu: %.2f -> %.2f em 1,2 s" % [c1, c2])
	await _w(1.6)
	var c3: float = float(ctrl.carga_atual())
	_ok(c3 >= 0.99, "segurando até o fim a carga chega ao TETO (%.2f)" % c3)
	_ok(ctrl.segurando, "e ela ESPERA o dedo — não lançou sozinha")

	print("\n-- 3. soltar dispara --")
	p.release_charge("V")
	await _w(0.4)
	# ⚠️ O NÓ DA CARGA PODE TER SIDO LIBERADO (2026-08-22). Desde que o V da Goro
	# passou a ir para a rede, quem o `CastController` segura é um
	# `MamaraganChargeNode` — a CARGA, não o golpe — e ele se destrói na soltura,
	# como o `MeraChargeNode` sempre fez. Um nó liberado é a prova mais forte de
	# que soltou, não uma falha; antes o `MamaraganController` sobrevivia porque
	# ELE era o golpe, e era esse o desenho que impedia o cliente de acertar o
	# servidor. Ver `cast_controller.comecar()`.
	_ok(not is_instance_valid(ctrl) or not ctrl.segurando, "soltar liberou o golpe")
	_ok(not p._cast.carregando_skill(), "o Player não está mais segurando nada")
	await _w(3.0)

	print("\n-- 4. DANO libera com a carga que tiver (o oposto das outras) --")
	p._skill_cooldowns["V"] = 0.0
	p.energy = p.max_energy
	p.begin_charge("V")
	await _w(1.1)
	var ctrl2 = p._cast._carregado
	_ok(is_instance_valid(ctrl2), "segundo golpe carregando")
	var carga_no_dano: float = float(ctrl2.carga_atual())
	p.take_damage(50.0)
	await _w(0.4)
	_ok(not p._cast.carregando_skill(),
		"o dano LIBEROU (não cancelou) com carga %.2f" % carga_no_dano)
	_ok(carga_no_dano > 0.0, "e a carga era real no instante do dano (%.2f)" % carga_no_dano)

	print("\n===== %s =====" % ("CHARGE-UP OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _f += 1

func _w(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0): await process_frame
