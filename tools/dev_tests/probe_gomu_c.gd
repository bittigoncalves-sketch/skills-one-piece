extends SceneTree
## Regressão do bug 2026-08-18: o C da Gomu Gomu (Gatling) nunca disparava,
## nem segurando a tecla pelos ~2,2 s inteiros do golpe.
##
## CAUSA RAIZ: em `CastController.comecar()`, o ramo do C chamava
## `_dono.trigger_skill_cooldown("C")` e, duas linhas depois, `pedir_cast("C")`
## — mas `pedir_cast()` COMEÇA checando `if _skill_cooldowns.get(slot, 0.0) >
## 0.0: return`. O `trigger_skill_cooldown` de cima já tinha acabado de pôr a
## recarga em 10s, então `pedir_cast` se via bloqueado pela PRÓPRIA recarga que
## acabara de nascer, no mesmo quadro, e desistia antes de chegar em
## `pedir_cast_no_servidor`. O Gatling nunca era criado — em quadro nenhum,
## segurando ou não. Conserto: `pedir_cast()` já chama `trigger_skill_cooldown`
## sozinho; a chamada extra em `comecar()` só sobrava para se autossabotar.
##
## Este teste segura C pelos 2,2 s inteiros e cobra os 16 socos completos —
## se a recarga voltar a nascer cedo demais, o Gatling não passa de 0 socos e
## a asserção pega.
##
##   godot --headless --path . --script tools/dev_tests/probe_gomu_c.gd

var _p: Node = null
var _ok_geral := true

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("  ✅ ", msg)
	else:
		print("  ❌ ", msg)
		_ok_geral = false

func _achar_gatling(world: Node) -> Node:
	for c in world.get_children():
		if c is GomuGatling and c._caster == _p:
			return c
	return null

func _achar_braco(world: Node) -> int:
	var n := 0
	for c in world.get_children():
		if c is GomuArm:
			n += 1
	return n

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(4.0)
	for x in get_nodes_in_group("player"):
		if x.is_multiplayer_authority():
			_p = x
	if _p == null:
		print("❌ sem jogador com autoridade")
		quit(1)
		return

	_p.equip_fruit("gomu_gomu")
	_p.energy = _p.max_energy
	for e in get_nodes_in_group("enemy"):
		if e is Node3D:
			e.set_meta("is_frozen", true)
			e.set_meta("damage_immune", true)
			(e as Node3D).global_position = Vector3(0, -1000, 0)
	await _esperar(1.0)
	var world = _p.get_tree().current_scene

	print("-- sanity check: Z (Pistol) prova que o pipeline begin/release -> RPC -> GomuFX funciona --")
	_p.begin_charge("Z")
	await _esperar(0.10)
	_p.release_charge("Z")
	await _esperar(0.05)   # GomuArm vive só ~0,30s (extend+hold+retract); checar logo depois de nascer
	_ok(_achar_braco(world) >= 1, "Z produziu pelo menos um GomuArm")
	await _esperar(0.6)

	print("\n-- C: segurando a tecla pelos ~2,2s inteiros do Gatling --")
	_p.begin_charge("C")
	var existiu := false
	var maxp := 0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 2400:
		await process_frame
		var gg := _achar_gatling(world)
		if gg:
			existiu = true
			maxp = maxi(maxp, gg._punch_count)
	_p.release_charge("C")
	await _esperar(0.3)

	_ok(existiu, "o GomuGatling chegou a nascer (sem isso, C nunca dispara nada)")
	_ok(maxp >= 16, "segurando a tecla, os 16 socos saem (%d/16)" % maxp)

	print("\n" + ("===== TUDO OK =====" if _ok_geral else "===== FALHOU ====="))
	quit(0 if _ok_geral else 1)

func _esperar(secs: float) -> void:
	var fim := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
