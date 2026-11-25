extends SceneTree
# ============================================================================
#  FLUXO DO JOGADOR PELO MOD (E2, 03/11/2026) — sem skill builder nem executor próprio:
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_jogador_mod.gd
#  O jogador real recebe a fruta pelas variáveis do mod (PlayerDevilFruit), o mod monta o golpe
#  (KeyChangeTechniqueDevilFruit), a tecla Z é apertada/solta (KeyStartTechnique…) e quem executa é o efeito
#  `minepiece:skill` → CursedTechniqueOnPotionActiveTick → Skill<Fruta> → golpe do mod.
#  Mede o DANO no alvo. Varredura das 40 frutas: tools/dev_tests/sonda_jogador_mod.gd.
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_jogador_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -4)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	var ej := McEntidade.de(jogador)
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	v.PlayerSkill1 = 1.0
	ok(Mc.proc(&"ReturnDevilFruitEatenProcedure").execute(ej).isEmpty(), "sem fruta: o mod não vê fruta no jogador")
	var inv = ej.getCapability(Mc.campo(&"ForgeCapabilities", &"ITEM_HANDLER"), null).orElse(null)
	ok(inv != null and inv.getSlots() >= 6 and inv.getStackInSlot(0).isEmpty(), "ITEM_HANDLER: o inventário do jogador é o equipamento (6 espaços) + a mochila do jogo (desde 10/11), não as variáveis do mod")
	for caso in [["gomu_gomu", 21], ["mera_mera", 21], ["hie_hie", 21], ["pika_pika", 21], ["yami_yami", 21]]:
		var fruta: String = caso[0]
		v.PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item("minepiece:item_devil_fruit_" + fruta)])
		v.PlayerEnergy = 100000.0
		ej.removeAllEffects()                  # recarga da fruta anterior (cooldown_time…) bloquearia esta
		Mc.proc(&"KeyResetTechniqueOnKeyPressedProcedure").execute(ej.level(), ej)
		await quadros(3)
		alvo.health = alvo.max_health
		Mc.proc(&"KeyChangeTechniqueDevilFruitProcedure").execute(ej.level(), ej, v.PlayerDevilFruit, float(caso[1]), 1.0)
		var nome: String = str(v.PlayerSelectName)
		jogador.global_position = alvo.global_position + Vector3(0, 0.8, 4.0)     # a fruta anterior pode ter levado o jogador para longe
		jogador.velocity = Vector3.ZERO
		await quadros(5)
		for _i in 4:      # mira da câmera até o peito do alvo (igual test_controlador_fruta_do_mod)
			var mira: Vector3 = alvo.global_position + Vector3.UP - jogador._cam.global_position
			jogador._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
			jogador._pitch = asin(mira.normalized().y)
			jogador._update_pivot()
			await quadros(3)
		Mc.proc(&"KeyStartTechniqueOnKeyPressedProcedure").execute(ej)
		await quadros(3 if fruta == "mera_mera" else 30)      # Mera voa para onde a mira aponta enquanto segura: solta cedo
		Mc.proc(&"KeyStartTechniqueOnKeyReleasedProcedure").execute(ej)
		await quadros(70)
		var dano := alvo.max_health - alvo.health
		ok(nome.begins_with("minepiece.technique.") and not nome.contains("attack"), "%s: o mod escolheu o golpe (%s)" % [fruta, nome])
		ok(dano > 0.0, "%s: o golpe do mod feriu o alvo (%.0f)" % [fruta, dano])
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
