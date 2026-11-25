extends SceneTree
# ============================================================================
#  ITEM 5: habilidade das 14 armas do mod (`WeaponAbility` + recarga por item). Cada arma começa a técnica, registra a recarga e não deixa usar de novo antes.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_armas_do_mod.gd
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func q(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_armas_mod.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_armas_mod.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.max_health = 1.0e7
	j.health = 1.0e7
	var e := McEntidade.de(j)
	for id in ArmasDoMod.IDS:
		e.removeEffect(Mc.efeito("minepiece:skill"))
		e.getPersistentData().putDouble("skill", 0.0)
		await q(2)
		var comecou := ArmasDoMod.usar(j, id)
		var skill := e.getPersistentData().getDouble("skill")
		ok(comecou and skill > 0.0, "%s: a habilidade começa (skill %.0f)" % [id, skill])
		var item := Mc.item(StringName("minepiece:" + id))
		ok(e.getCooldowns().isOnCooldown(item), "%s: a arma entra em recarga" % id)
		e.removeEffect(Mc.efeito("minepiece:skill"))
		e.getPersistentData().putDouble("skill", 0.0)
		ok(not ArmasDoMod.usar(j, id), "%s: não usa de novo durante a recarga" % id)
		e.getCooldowns()._ate_ms.clear()
	ok(not ArmasDoMod.usar(j, "espada_que_nao_existe"), "arma sem habilidade → falso")
	print("\narmas do mod: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
