extends SceneTree
# Sonda: a tecla de TRANSFORMAÇÃO do mod (KeyTransform) no jogador real, por estilo (PlayerSkill1): erros, SIZE e escala.
func _init() -> void:
	rodar.call_deferred()
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sonda_transf.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://sonda_transf.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var ej := McEntidade.de(jogador)
	var v = ej.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null)
	v.PlayerEnergy = 100000.0
	v.PlayerEnergyMAX = 100000.0
	for fruta in ["hito_hito_daibutsu", "inu_inu_wolf", "neko_neko_leopard", "ushi_ushi_giraffe", "ryu_ryu_pteranodon", "gomu_gomu"]:
		var estilo: String = fruta
		v.PlayerSkill1 = 1.0
		v.PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item("minepiece:item_devil_fruit_" + fruta)])
		Mc.pedidos_sem_implementacao.clear()
		var h0 := ej.escala(&"height")
		Mc.proc(&"KeyTransformOnKeyPressedProcedure").execute(ej.level(), ej)
		await quadros(30)
		print("TRANSF fruta=%s: size=%.2f escala=%.2f→%.2f forma=%s pedidos=%s" % [estilo, ej.getAttributeValue(Mc.atributo(&"minepiece:size")), h0, ej.escala(&"height"), str(ej.getAttributeValue(Mc.atributo(&"minepiece:form"))), str(Mc.pedidos_sem_implementacao)])
		Mc.proc(&"KeyTransformOnKeyPressedProcedure").execute(ej.level(), ej)     # desfaz
		await quadros(30)
		print("   desfeita: escala=%.2f" % ej.escala(&"height"))
	quit()
