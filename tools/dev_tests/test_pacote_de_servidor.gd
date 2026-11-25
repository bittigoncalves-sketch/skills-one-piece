extends SceneTree
# ============================================================================
#  PACOTE DE SERVIDOR (09/11/2026, item 6): métodos que 67+ procedures chamam e que não existiam (`getPlayerList().broadcastSystemMessage`, `players`,
#  modo de jogo, `getFoodData`, `tame`, `getBlockEntity`…) respondem de forma coerente com o jogo.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pacote_de_servidor.gd
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
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_pacote_servidor.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	var mundo: McMundo = Mc.mundo(self)
	var ent := McEntidade.de(j)
	var hud = get_first_node_in_group("hud")
	ok(mundo.players().size() == 1 and mundo.players()[0] == ent, "world.players() devolve o jogador local")
	ok(mundo.getServer().getPlayerList().getPlayerCount() == 1, "getPlayerList().getPlayerCount() = 1")
	mundo.getServer().getPlayerList().broadcastSystemMessage(Mc.estatico(&"Component", &"literal", ["Aviso global do servidor"]), false)
	ok(hud != null and str(hud._aviso.text).contains("Aviso global do servidor"), "broadcastSystemMessage aparece no aviso do HUD (%s)" % (str(hud._aviso.text) if hud != null else "sem HUD"))
	# procedure REAL que antes abortava: ramo de erro do Batto Batto manda mensagem global
	ent.getPersistentData().putDouble("skill", 99.0)
	Mc.proc(&"SkillBattoBattoProcedure").execute(mundo, 0.0, 0.0, 0.0, ent)
	ok(str(hud._aviso.text).contains("Error Batto Batto"), "SkillBattoBatto (ramo de erro) executa até o fim e avisa (%s)" % str(hud._aviso.text))
	ent.getPersistentData().putDouble("skill", 0.0)
	ok(Mc.estatico(&"Minecraft", &"getInstance", []).getConnection().getPlayerInfo(ent.getStringUUID()).getGameMode() == &"SURVIVAL", "Minecraft.getInstance().getConnection().getPlayerInfo().getGameMode() = SURVIVAL")
	ok(ent.getGameMode() == &"SURVIVAL", "modo de jogo padrão: SURVIVAL")
	ent.setGameMode(Mc.campo(&"GameType", &"CREATIVE"))
	ok(ent.getGameMode() == &"CREATIVE", "setGameMode guarda o modo pedido (arena PVP do mod)")
	ent.setGameMode(Mc.campo(&"GameType", &"SURVIVAL"))
	var fome := ent.getFoodData()
	fome.setFoodLevel(30)
	fome.setSaturation(5.0)
	ok(fome.getFoodLevel() == 20 and is_equal_approx(fome.getSaturationLevel(), 5.0), "getFoodData().setFoodLevel(30) limita a 20, saturação 5")
	ok(not ent.isTame(), "não domesticado por padrão")
	ent.tame(ent)
	ok(ent.isTame(), "tame() marca a entidade")
	ok(mundo.getBlockEntity(McVec3.de(0, 0, 0)) == null, "getBlockEntity devolve null (o jogo não tem entidades de bloco)")
	ok(mundo.getDifficulty() == &"NORMAL", "getDifficulty = NORMAL")
	ent.closeContainer()
	ok(true, "closeContainer não aborta")
	# uma procedure de comando que usa players/getFoodData/setGameMode: não pode abortar
	ok(Mc.proc(&"GetDifficultyLevelProcedure").execute(mundo) is float, "GetDifficultyLevel responde (%s)" % str(Mc.proc(&"GetDifficultyLevelProcedure").execute(mundo)))
	print("\npacote de servidor: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
