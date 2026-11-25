extends SceneTree
# ============================================================================
#  ITENS 2 e 3: Haki do Rei (H) e modo de batalha (G) pela HUD, com a semântica do mod.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_teclas_do_mod.gd
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

func tecla(cod: Key) -> void:
	for pressionada in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = cod
		ev.keycode = cod
		ev.pressed = pressionada
		Input.parse_input_event(ev)

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_teclas_mod.json"))
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_teclas_mod.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.max_health = 1.0e7
	j.health = 1.0e7
	var hud = get_first_node_in_group("hud")
	var ej := McEntidade.de(j)
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	# ---- Haki do Rei sem a conquista: o mod avisa que não pode usar, nada começa
	hud._aviso.text = ""
	tecla(KEY_H)
	await q(5)
	ok(str(hud._aviso.text) != "" and not ej.hasEffect(Mc.efeito("minepiece:skill")), "H sem a conquista skill_haoshoku_haki: aviso do mod (%s) e nenhuma técnica" % str(hud._aviso.text))
	# ---- com a conquista: a técnica passiva do Haki do Rei começa
	var d = ej.server.getAdvancements().getAdvancement("minepiece:skill_haoshoku_haki")
	ok(d != null, "a conquista skill_haoshoku_haki existe")
	for c in d.criterios:
		ej.getAdvancements().award(d, c)
	await q(5)
	tecla(KEY_H)
	await q(3)
	ok(ej.hasEffect(Mc.efeito("minepiece:skill")) and ej.getPersistentData().getDouble("skill") != 0.0, "H com a conquista: a técnica do Haki do Rei começa (skill = %s)" % str(ej.getPersistentData().getDouble("skill")))
	await q(60)
	var viu_haki := ej.hasEffect(Mc.efeito("minepiece:sovereign_haki")) or ej.hasEffect(Mc.efeito("minepiece:armament_haki")) or ej.hasEffect(Mc.efeito("minepiece:observation_haki"))
	print("  ℹ️ depois de 1 s: efeito de Haki ativo = %s, skill = %s" % [str(viu_haki), str(ej.getPersistentData().getDouble("skill"))])
	# ---- modo de batalha
	await q(120)
	ej.removeEffect(Mc.efeito("minepiece:skill"))
	ej.getPersistentData().putDouble("skill", 0.0)
	v.PlayerSkill1 = 1.0
	modo.equipar_fruta(j, "gomu_gomu")
	await q(10)
	ok(bool(v.PlayerBattleMode), "modo de batalha começa LIGADO (padrão do mod)")
	tecla(KEY_G)
	await q(3)
	ok(not bool(v.PlayerBattleMode), "G desliga o modo de batalha")
	ok(str(hud._aviso.text).contains("DESLIGADO"), "e avisa na tela (%s)" % str(hud._aviso.text))
	var c = j.get_node("FrutaMinePiece")
	j.energy = j.max_energy
	var antes: float = j.energy
	c.usar_tecla("Z", true)
	await q(4)
	c.usar_tecla("Z", false)
	await q(10)
	ok(absf(antes - j.energy) < 1.0 + 8.0, "com o modo desligado a técnica NÃO começa (energia %.0f → %.0f)" % [antes, j.energy])
	tecla(KEY_G)
	await q(3)
	ok(bool(v.PlayerBattleMode), "G de novo liga")
	print("\nteclas do mod: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
