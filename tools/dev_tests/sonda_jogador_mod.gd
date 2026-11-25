extends SceneTree
# Sonda (nao e teste): fluxo de teclas do mod no JOGADOR real, pelas procedures traduzidas.
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/sonda_jogador_mod.gd -- gomu_gomu [sel_ini sel_fim]
# Para cada golpe (PlayerSelectNumber 21..29): reseta, aperta a tecla do mod, anda 60 ticks e
# imprime "SONDA fruta sel dano pedidos_novos".
func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	var args := OS.get_cmdline_user_args()
	var fruta: String = args[0] if args.size() > 0 else "gomu_gomu"
	var ini := int(args[1]) if args.size() > 2 else 21
	var fim := int(args[2]) if args.size() > 2 else 29
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://sonda_jogador_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -4)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.set_meta("damage_immune", false)
	alvo.max_health = 1000000.0
	alvo.health = alvo.max_health
	await quadros(10)
	var ej := McEntidade.de(jogador)
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	v.PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item("minepiece:item_devil_fruit_" + fruta)])
	v.PlayerSkill1 = 1.0
	for sel in range(ini, fim + 1):
		v.PlayerEnergy = 100000.0
		Mc.proc(&"KeyResetTechniqueOnKeyPressedProcedure").execute(Mc.mundo(self), ej)
		await quadros(3)
		# a seleção real: o mod monta nome/custo/número do golpe `sel` da fruta equipada
		Mc.proc(&"KeyChangeTechniqueDevilFruitProcedure").execute(ej.level(), ej, v.PlayerDevilFruit, float(sel), 1.0)
		alvo.health = alvo.max_health
		var antes := Mc.pedidos_sem_implementacao.duplicate()
		for _i in 4:      # mira da câmera até o peito do alvo (igual test_controlador_fruta_do_mod)
			var mira: Vector3 = alvo.global_position + Vector3.UP - jogador._cam.global_position
			jogador._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
			jogador._pitch = asin(mira.normalized().y)
			jogador._update_pivot()
			await quadros(3)
		Mc.proc(&"KeyStartTechniqueOnKeyPressedProcedure").execute(ej)
		for t in 8:
			await quadros(10)
			if t == 2:
				Mc.proc(&"KeyStartTechniqueOnKeyReleasedProcedure").execute(ej)   # solta a tecla: o golpe sai
			if OS.get_environment("SONDA_DEBUG") != "":
				var corpos := []
				for c in get_nodes_in_group(McCorpoDoMod.GRUPO):
					corpos.append("%s@%s" % [c.name, c.global_position.snapped(Vector3(0.1,0.1,0.1))])
				print("  t=%d cnt1=%s cnt2=%s cnt6=%s skill=%s efeito=%s corpos=%s vida=%.0f" % [t*10+10, ej.getPersistentData().getDouble("cnt1"), ej.getPersistentData().getDouble("cnt2"), ej.getPersistentData().getDouble("cnt6"), ej.getPersistentData().getDouble("skill"), ej.hasEffect(Mc.efeito("minepiece:skill")), corpos, alvo.health])
		var novos := {}
		for k in Mc.pedidos_sem_implementacao:
			var d: int = Mc.pedidos_sem_implementacao[k] - int(antes.get(k, 0))
			if d > 0:
				novos[k] = d
		print("SONDA %s sel=%d nome=%s skill=%s dano=%.0f pedidos=%s" % [fruta, sel, v.PlayerSelectName, ej.getPersistentData().getDouble("skill"), alvo.max_health - alvo.health, novos])
	quit()
