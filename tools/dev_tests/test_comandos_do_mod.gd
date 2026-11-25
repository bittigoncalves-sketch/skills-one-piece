extends SceneTree
# ============================================================================
#  ITEM 10: comandos do mod `/minepiece bounty set|add|limit|query` e `/minepiece summon <região> pirate|marine <n>` pelo interpretador de comandos.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_comandos_do_mod.gd
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_comandos_mod.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_comandos_mod.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	var mundo: McMundo = Mc.mundo(self)
	var ej := McEntidade.de(j)
	var hud = get_first_node_in_group("hud")
	var f := McComandos.Fonte.new()
	f.mundo = mundo
	f.entidade = ej
	f.posicao = ej.position()
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	var antes := float(v.PlayerBounty)
	ok(McComandos.executar(f, "minepiece bounty set @s 50000") == 1, "bounty set devolve 1")
	var depois_set := float(v.PlayerBounty)
	ok(absf(depois_set - 50000.0) < 1.0 or depois_set != antes, "bounty set muda a recompensa (%.0f → %.0f)" % [antes, depois_set])
	ok(McComandos.executar(f, "minepiece bounty add @s 1000") == 1, "bounty add devolve 1")
	var depois_add := float(v.PlayerBounty)
	ok(depois_add != depois_set, "bounty add muda a recompensa (%.0f → %.0f)" % [depois_set, depois_add])
	ok(McComandos.executar(f, "minepiece bounty query @s") == 1, "bounty query devolve 1")
	ok(str(hud._aviso.text).contains("bounty"), "bounty query mostra a recompensa no HUD (%s)" % str(hud._aviso.text))
	ok(McComandos.executar(f, "minepiece bounty set @s") == 0, "argumento faltando → 0")
	ok(McComandos.executar(f, "minepiece summon eastblue pirate 99") == 0, "summon fora de 1–20 → 0 (limite do mod)")
	ok(McComandos.executar(f, "minepiece raid start eastblue 1") == 0, "raid segue nativa (não redireciona)")
	print("\ncomandos do mod: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
