extends SceneTree
## Sonda: com as grades liberadas, cada tecla da Zushi Zushi inicia o golpe? (lista, energia gasta, efeito de skill)
func _init() -> void:
	rodar.call_deferred()
func q(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://sonda_zushi.json"))
	modo.set("progresso_forcado", "user://sonda_zushi.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.max_health = 1.0e7
	j.health = 1.0e7
	j.max_energy = 3000.0
	var ej := McEntidade.de(j)
	await q(10)
	modo.equipar_fruta(j, "")
	await q(3)
	modo.equipar_fruta(j, "zushi_zushi")
	await q(10)
	var c = j.get_node("FrutaMinePiece")
	print("LISTA ", c._lista.map(func(g): return "%d:%s:%.0f" % [g.numero, g.chave, g.custo]))
	print("MAPA ", c.mapa_de_teclas(), " emax ", j.max_energy)
	j.global_position = Vector3(0, 1.0, 0)
	await q(30)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	alvo.position = j.global_position + (-j.global_basis.z) * 5.0
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 100000.0
	alvo.health = 100000.0
	await q(30)
	var _c = Vector3(0, 0, 0)
	var mundo = ej.level()
	var centro = Mc.novo(&"Vec3", [alvo.global_position.x, alvo.global_position.y + 1.0, alvo.global_position.z])
	var achados = mundo.getEntitiesOfClass(&"Entity", Mc.novo(&"AABB", [centro, centro]).inflate(6.0), func(e): return true)
	print("ACHADOS ", achados.size(), " ", achados.map(func(e): return str(e.getType()) if e.has_method("getType") else "?"))
	for e in achados:
		print("  LogicAttack ", Mc.proc(&"LogicAttackProcedure").execute(mundo, ej, e), " tipo ", e.getType())
	var rg = Mc.proc(&"ReturnEntitySizeProcedure").execute(ej)
	print("RANGE_ ", rg, " olho ", ej.getEyePosition(1.0), " vista ", ej.getViewVector(1.0))
	for k in 4:
		var dis: float = 6.0 * float(rg) * (k + 1)
		var r = ej.level().clip(Mc.novo(&"ClipContext", [ej.getEyePosition(1.0), Mc.adicionar(ej.getEyePosition(1.0), ej.getViewVector(1.0).scale(dis)), Mc.campo(&"Block", &"VISUAL"), Mc.campo(&"Fluid", &"NONE"), ej]))
		print("CLIP dis=%.1f -> bloco (%s,%s,%s)" % [dis, r.getBlockPos().getX(), r.getBlockPos().getY(), r.getBlockPos().getZ()])
	for e in achados:
		print("TAG ranged_ammo para ", e.getType(), " = ", e.getType().is_(Mc.estatico(&"TagKey", &"create", [Mc.campo(&"Registries", &"ENTITY_TYPE"), Mc.novo(&"ResourceLocation", ["forge:ranged_ammo"])])), " igual_ao_jogador=", e == ej)
	var pd0 = ej.getPersistentData()
	pd0.putDouble("cnt1", 0.0)
	pd0.putDouble("cnt2", 0.0)
	Mc.proc(&"FujitoraRubbleProcedure").execute(ej.level(), ej)
	print("DIRETO xz_pos=(%.1f,%.1f) y=%.1f alvo=(%.1f,%.1f,%.1f)" % [pd0.getDouble("x_pos"), pd0.getDouble("z_pos"), pd0.getDouble("y_pos"), alvo.global_position.x, alvo.global_position.y, alvo.global_position.z])
	for t in ["V"]:
		j.energy = j.max_energy
		c._recargas.clear()
		await q(5)
		var v0: float = alvo.health
		c._tecla_do_mod(t, true)
		var serie := []
		for i in 24:
			for n in current_scene.find_children("*", "McCorpoDoMod", true, false):
				var pdn = McEntidade.de(n).getPersistentData()
				if str(n.get("id_personagem")) == "rubble":
					pdn.putDouble("x_pos_fix", pdn.getDouble("x_pos_fix") * 0.05)
					pdn.putDouble("z_pos_fix", pdn.getDouble("z_pos_fix") * 0.05)
			await q(10)
			serie.append("%.0f" % (v0 - alvo.health))
		c._tecla_do_mod(t, false)
		print("SERIE_V dano=", serie)
	quit(0)
	for t in c.mapa_de_teclas():
		j.energy = j.max_energy
		c._recargas.clear()
		await q(5)
		var e0: float = j.energy
		c._tecla_do_mod(t, true)
		var visto := false
		var skill := -1.0
		for i in 12:
			await physics_frame
			if ej.hasEffect(Mc.efeito("minepiece:skill")):
				visto = true
				skill = float(ej.getPersistentData().getDouble("skill"))
		print("TECLA %s num=%d gastou=%.0f efeito_skill=%s skill=%s ativo=%s" % [t, c.mapa_de_teclas()[t], e0 - j.energy, visto, skill, c.ativo])
		c._tecla_do_mod(t, false)
		await q(200)
	quit(0)
