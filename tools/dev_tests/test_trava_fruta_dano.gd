extends SceneTree
## Dano real bloqueia apenas skills de fruta por 1 s e expõe o quadrado da HUD.

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(2.0)
	var p: Node3D = get_first_node_in_group("player")
	if p == null:
		print("❌ Trava fruta: jogador ausente")
		quit(1)
		return
	p.take_damage(24.0)
	await process_frame
	var hud := get_first_node_in_group("hud")
	var painel := hud.get_node_or_null("FruitRecoveryHud") if hud else null
	p.call("begin_charge", "Z")
	var bloqueou: bool = float(p.get("_fruit_damage_lock_timer")) > 0.8 \
		and not bool(p.get("_invisivel")) and painel != null and painel.visible \
		and String(painel.get_node("Bloco/Tempo").text).contains("s")
	await _esperar(1.08)
	p.call("begin_charge", "Z")
	var liberou: bool = float(p.get("_fruit_damage_lock_timer")) <= 0.0 and bool(p.get("_invisivel"))
	print("%s dano bloqueia fruta e mostra o quadrado de recuperação" % ("✅" if bloqueou else "❌"))
	print("%s fruta volta a funcionar após 1 segundo" % ("✅" if liberou else "❌"))
	quit(0 if bloqueou and liberou else 1)

func _esperar(segundos: float) -> void:
	var fim := Time.get_ticks_msec() + int(segundos * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
