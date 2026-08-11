extends SceneTree
## CAMERA RIG (Fase 2) — prova que o componente funciona no jogo de verdade.
##
## O que nenhum outro teste cobre: a camera existe, aponta pra onde a mira
## manda, o tremor decai, o FOV reage a velocidade e a luneta, e a troca de
## perspectiva mexe na cadeia. Sao justamente as coisas que o headless nao ve
## "na tela" — entao a gente MEDE os numeros por tras delas.
var _f := 0
func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _w(3.0)
	var p: Node = null
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority(): p = x
	var rig = p.get_node_or_null("CameraRig")
	_ok(rig != null, "o CameraRig esta na arvore do player")
	_ok(rig != null and rig.esta_montado(), "a cadeia foi montada (Camera3D existe)")
	var cam = rig.camera()
	_ok(cam != null and cam.current, "a camera do player local esta ativa")
	_ok(p._cam == cam, "o atalho _cam do Player aponta pra camera do rig")

	print("\n-- aponta pra onde a mira manda --")
	p._yaw = 1.2; p._pitch = -0.3; p._update_pivot()
	await process_frame
	_ok(absf(rig.rotation.y - 1.2) < 0.01 and absf(rig.rotation.x + 0.3) < 0.01,
		"apontar(yaw,pitch) girou o rig (y=%.2f x=%.2f)" % [rig.rotation.y, rig.rotation.x])

	print("\n-- tremor: pedido e decaimento --")
	rig.pedir_shake(1.0)
	var s0: float = rig._shake
	await _w(0.5)
	var s1: float = rig._shake
	_ok(s0 >= 0.99, "pedir_shake(1.0) armou o tremor (%.2f)" % s0)
	_ok(s1 < s0, "o tremor DECAI sozinho (%.2f -> %.2f)" % [s0, s1])

	print("\n-- soco de FOV: pedido de fora, decaimento dentro --")
	rig.pedir_fov_punch(8.0)
	var f0: float = rig._fov_punch
	await _w(0.5)
	_ok(f0 >= 7.9, "pedir_fov_punch(8) armou (%.1f)" % f0)
	_ok(rig._fov_punch < f0, "o soco de FOV decai (%.1f -> %.1f)" % [f0, rig._fov_punch])

	print("\n-- luneta da sniper sobrescreve o FOV de velocidade --")
	var fov_normal: float = cam.fov
	p._buki_scope = true
	await _w(1.2)
	var fov_luneta: float = cam.fov
	p._buki_scope = false
	await _w(1.2)
	_ok(fov_luneta < fov_normal - 10.0, "a luneta FECHA o FOV (%.0f -> %.0f)" % [fov_normal, fov_luneta])
	_ok(cam.fov > fov_luneta + 10.0, "e ele volta ao soltar (%.0f)" % cam.fov)

	print("\n-- troca de perspectiva mexe na cadeia --")
	var y3: float = rig.position.y
	rig.alternar_perspectiva()
	var y1: float = rig.position.y
	_ok(rig.em_primeira_pessoa(), "alternou para 1a pessoa")
	_ok(absf(y1 - y3) > 1.0, "a altura do pivo mudou (%.2f -> %.2f)" % [y3, y1])
	rig.alternar_perspectiva()
	_ok(absf(rig.position.y - y3) < 0.01, "e volta ao alternar de novo")

	print("\n===== %s =====" % ("CAMERA RIG OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)

func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c: _f += 1
func _w(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec()-t < int(s*1000.0): await process_frame
