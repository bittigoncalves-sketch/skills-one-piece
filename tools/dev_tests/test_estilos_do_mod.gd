extends SceneTree
# ============================================================================
#  ITEM 1 (fatia): as 23 classes/estilos do mod são escolhíveis pelo fluxo do mod (`Select*`), cada uma com seu `PlayerSkill1`, sem erro de script.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_estilos_do_mod.gd
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_estilos_mod.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_estilos_mod.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	var valores := {}
	for id in EstilosDoMod.ids():
		var r := EstilosDoMod.escolher(j, id)
		valores[id] = r
		await q(2)
	ok(EstilosDoMod.ids().size() == 24, "24 entradas (23 classes + 'sem estilo'): %d" % EstilosDoMod.ids().size())
	ok(valores.values().all(func(v): return v >= 0.0), "todas as escolhas respondem um modo (PlayerSkill1) ≥ 0")
	var unicos := {}
	for v in valores.values():
		unicos[v] = true
	ok(unicos.size() >= 22, "modos distintos para os estilos (%d valores distintos em 24; 'general' e outro podem coincidir com 0)" % unicos.size())
	ok(valores["swordsman"] == 30.0 and valores["fighter"] == 31.0 and valores["gunman"] == 32.0 and valores["zoro"] == 1.0 and valores["rokushiki"] == 4.0, "valores conhecidos: Espadachim 30, Lutador 31, Pistoleiro 32, Zoro 1, Rokushiki 4")
	ok(EstilosDoMod.escolher(j, "nao_existe") == -1.0, "id inexistente → -1")
	EstilosDoMod.voltar_as_frutas(j)
	var v = McEntidade.de(j).getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	ok(float(v.PlayerSkill1) == 1.0, "voltar_as_frutas repõe PlayerSkill1 = 1")
	print("\nestilos do mod: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
