extends SceneTree
# ============================================================================
#  ITEM 9 (dados): receitas, loot tables e os 64 modelos Java do mod extraídos para JSON; loot sorteável pelo caminho das procedures.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_dados_do_mod.gd
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

func json(caminho: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(caminho))

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_dados_mod.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_dados_mod.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var receitas: Dictionary = json("res://mapas/east_blue/receitas_do_mod.json")
	var loot: Dictionary = json("res://mapas/east_blue/loot_do_mod.json")
	var modelos: Dictionary = json("res://mapas/east_blue/modelos_java_todos.json")
	ok(receitas.size() == 31, "31 receitas do mod (%d)" % receitas.size())
	ok(loot.size() == 15, "15 loot tables do mod (%d)" % loot.size())
	ok(modelos.size() == 64, "64 modelos Java (%d)" % modelos.size())
	var sem_caixa := modelos.keys().filter(func(k): return int(modelos[k].caixas) == 0)
	ok(sem_caixa.size() <= 6, "quase todos os modelos têm caixas (sem caixa: %s)" % str(sem_caixa))
	var mundo: McMundo = Mc.mundo(self)
	# o caminho exato das procedures
	var itens: Array = mundo.getServer().getLootData().getLootTable(Mc.novo(&"ResourceLocation", ["minepiece:chests/loot_treasure"])).getRandomItems(Mc.novo(&"Builder", [mundo]).create(Mc.campo(&"LootContextParamSets", &"EMPTY")))
	ok(itens.size() >= 2 and itens.size() <= 8, "loot_treasure sorteia de 2 a 8 itens (%d)" % itens.size())
	ok(itens.all(func(i): return not i.isEmpty() and i.getCount() >= 1), "todos os itens sorteados são válidos")
	# a fruta aleatória do mod (GetRandomItem) funciona de ponta a ponta
	var fruta = Mc.proc(&"GetRandomItemProcedure").execute(mundo)
	ok(fruta != null, "GetRandomItem (fruta aleatória) executa (%s)" % (str(fruta.getItem().id) if fruta != null and not fruta.isEmpty() else "vazio"))
	# distribuição: 500 sorteios do loot_devil_fruit só dão frutas do mod
	var invalidos := 0
	for i in 500:
		for it in mundo.getLootData().getLootTable("minepiece:loot_devil_fruit").getRandomItems():
			if not str(it.getItem().id).begins_with("minepiece:item_devil_fruit_"):
				invalidos += 1
	ok(invalidos == 0, "500 sorteios de loot_devil_fruit: só frutas do mod (%d inválidos)" % invalidos)
	ok(mundo.getLootData().getLootTable("minepiece:nao_existe").getRandomItems().is_empty(), "tabela inexistente → vazio (e contada como falta)")
	print("\ndados do mod: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
