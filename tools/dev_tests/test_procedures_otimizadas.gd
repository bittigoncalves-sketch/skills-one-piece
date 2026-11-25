extends SceneTree
# ============================================================================
#  PROCEDURES OTIMIZADAS (09/11/2026): a versão otimizada de `BlockDestroyAllDirection` (`src/minecraft/otimizadas/`) tem de dar o MESMO mundo que a gerada.
#  Cenário: região com blocos de várias durezas (pedra, tronco, vidro, água, ar), chamadas sobrepostas e repetidas no MESMO tick (exercita o cache).
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_procedures_otimizadas.gd
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

const BLOCOS := [&"minecraft:stone", &"minecraft:oak_log", &"minecraft:glass", &"minecraft:water", &"minecraft:oak_planks", &"minecraft:dirt", &"minecraft:obsidian", &"minecraft:bedrock"]

func _montar(mundo: McMundo, base: Vector3i, rng_semente: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_semente
	for x in 14:
		for y in 7:
			for z in 14:
				var c := base + Vector3i(x, y, z)
				var p := McVec3.de(c.x + 0.5, c.y + 0.5, c.z + 0.5)
				var r := rng.randi_range(0, 11)
				mundo.setBlock(p, McBloco.Estado.de(Mc.bloco(&"minecraft:air" if r >= BLOCOS.size() else BLOCOS[r])), 3)

func _foto(mundo: McMundo, base: Vector3i) -> String:
	var ids := PackedStringArray()
	for x in 14:
		for y in 7:
			for z in 14:
				ids.append(str(mundo.getBlockState(McVec3.de(base.x + x + 0.5, base.y + y + 0.5, base.z + z + 0.5)).bloco.id).replace("minecraft:", ""))
	return ",".join(ids)

func _rodar_chamadas(script: GDScript, mundo: McMundo, ent: McEntidade, centro: Vector3, ndanos: Array) -> void:
	var pd = ent.getPersistentData()
	for i in 14:                                           # chamadas sobrepostas e repetidas, como a lâmina faz
		var cx := centro.x + (i % 7) - 3
		var cy := centro.y + (i % 3) - 1
		var cz := centro.z + (i % 5) - 2
		var dano: float = ndanos[i % ndanos.size()]
		for rep in (1 + i % 3):
			pd.putDouble("BlockRange", 1.0 + (i % 4))
			pd.putDouble("BlockDamage", dano)
			pd.putBoolean("noParticle", true)
			pd.putBoolean("noEffect", true)
			pd.putBoolean("ExtinctionBlock", true)
			pd.putDouble("knockback", 0.5)
			script.execute(mundo, cx, cy, cz, ent)

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_otimizadas.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	var mundo: McMundo = Mc.mundo(self)
	var ent := McEntidade.de(j)
	var gerada: GDScript = load("res://src/minecraft/gerado/procedures/BlockDestroyAllDirectionProcedure.gd")
	var otimizada: GDScript = load("res://src/minecraft/otimizadas/BlockDestroyAllDirectionProcedure.gd")
	ok(Mc.proc(&"BlockDestroyAllDirectionProcedure") == otimizada, "Mc.proc entrega a versão otimizada")
	var base := Vector3i(40, 6, 40)
	var centro := Vector3(base.x + 7.0, base.y + 3.0, base.z + 7.0)
	var danos_por_caso := [[0.2], [1.5], [0.5, 3.0, 8.0], [60.0]]
	var caso := 0
	for danos in danos_por_caso:
		caso += 1
		# GERADA
		mundo.tick()
		_montar(mundo, base, 1000 + caso)
		mundo.tick()
		_rodar_chamadas(gerada, mundo, ent, centro, danos)
		var depois_gerada := _foto(mundo, base)
		# OTIMIZADA, mesmo mundo inicial
		mundo.tick()
		_montar(mundo, base, 1000 + caso)
		mundo.tick()
		_rodar_chamadas(otimizada, mundo, ent, centro, danos)
		var depois_otim := _foto(mundo, base)
		var antes_igual := true
		ok(depois_gerada == depois_otim, "caso %d (danos %s): o mundo depois é idêntico (%d células)" % [caso, str(danos), 14 * 7 * 14])
		var destruidas := depois_gerada.count("air") - 0
		ok(destruidas > 0, "caso %d: a técnica de fato mexeu no mundo (%d células de ar)" % [caso, destruidas])
	# ---- BlockToGrass (11/11/2026): varre só as células sobrepostas em vez do cubo; o mundo depois tem de ser o MESMO da gerada
	var grama_gerada: GDScript = load("res://src/minecraft/gerado/procedures/BlockToGrassProcedure.gd")
	var grama_otim: GDScript = load("res://src/minecraft/otimizadas/BlockToGrassProcedure.gd")
	ok(Mc.proc(&"BlockToGrassProcedure") == grama_otim, "Mc.proc entrega a BlockToGrass otimizada")
	var algum_mudou := false
	for alcance in [2.0, 5.0, 9.0]:
		mundo.tick()
		_montar(mundo, base, 4000 + int(alcance))
		mundo.tick()
		var g_antes := _foto(mundo, base)
		for k in 2:
			var pd = ent.getPersistentData()
			pd.putDouble("BlockRange", alcance)
			pd.putDouble("BlockDamage", 3.0)
			grama_gerada.execute(mundo, centro.x + k, centro.y, centro.z, ent)
		var g_gerada := _foto(mundo, base)
		algum_mudou = algum_mudou or g_gerada != g_antes
		mundo.tick()
		_montar(mundo, base, 4000 + int(alcance))
		mundo.tick()
		for k in 2:
			var pd2 = ent.getPersistentData()
			pd2.putDouble("BlockRange", alcance)
			pd2.putDouble("BlockDamage", 3.0)
			grama_otim.execute(mundo, centro.x + k, centro.y, centro.z, ent)
		var g_otim := _foto(mundo, base)
		ok(g_gerada == g_otim, "BlockToGrass (alcance %d): o mundo depois é idêntico à gerada" % int(alcance))
	ok(algum_mudou, "BlockToGrass de fato muda o mundo em algum alcance (o teste exercita o corpo, não só o laço)")
	var t_antes := Time.get_ticks_usec()
	var pdz = ent.getPersistentData()
	pdz.putDouble("BlockRange", 32.0)
	pdz.putDouble("BlockDamage", 3.0)
	grama_otim.execute(mundo, centro.x, centro.y, centro.z, ent)
	var ms_otim := (Time.get_ticks_usec() - t_antes) / 1000.0
	ok(ms_otim < 200.0, "BlockToGrass com alcance 32 (cubo de 64³) leva %.1f ms (a gerada levava ~4000 ms no mapa real)" % ms_otim)
	# ---- ReturnDevilFruitEaten: mesma fruta que a gerada, pela primeira vez (calcula) e pelas seguintes (cache); o jogador nunca é guardado
	var fr_gerada: GDScript = load("res://src/minecraft/gerado/procedures/ReturnDevilFruitEatenProcedure.gd")
	var fr_otim: GDScript = load("res://src/minecraft/otimizadas/ReturnDevilFruitEatenProcedure.gd")
	ok(Mc.proc(&"ReturnDevilFruitEatenProcedure") == fr_otim, "Mc.proc entrega a ReturnDevilFruitEaten otimizada")
	var alvos: Array = [ent]
	for id_ficha in ["arlong", "buggy", "alvida", "luffy_east_blue"]:
		if DadosEastBlue.ficha(id_ficha).is_empty():
			continue
		var pers := PersonagemMinePiece.new()
		pers.montar(DadosEastBlue.ficha(id_ficha), "mp_" + id_ficha)
		pers.position = Vector3(300, 1, 300 + alvos.size() * 3)
		current_scene.add_child(pers)
		alvos.append(McEntidade.de(pers))
	await q(3)
	var proj := Node3D.new()                        # corpo qualquer (não personagem): o caso das lâminas/projéteis
	current_scene.add_child(proj)
	alvos.append(McEntidade.de(proj))
	var iguais := true
	var detalhe := ""
	for a: McEntidade in alvos:
		var esperado: Variant = fr_gerada.execute(a)
		for vez in 3:
			var obtido: Variant = fr_otim.execute(a)
			var e_id := "vazio" if esperado.isEmpty() else str(esperado.getItem().id)
			var o_id := "vazio" if obtido.isEmpty() else str(obtido.getItem().id)
			if e_id != o_id:
				iguais = false
				detalhe += " [%s: esperado %s, obtido %s (vez %d)]" % [a.no.name, e_id, o_id, vez]
	ok(iguais, "ReturnDevilFruitEaten dá a mesma fruta em %d entidades × 3 consultas%s" % [alvos.size(), detalhe])
	# o jogador muda de fruta e a resposta acompanha (nunca guardada)
	ent.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null).PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_gomu_gomu")])
	var r1 = fr_otim.execute(ent)
	ent.getCapability(Mc.campo(&"MinepieceModVariables", &"PLAYER_VARIABLES_CAPABILITY"), null).orElse(null).PlayerDevilFruit = Mc.novo(&"ItemStack", [Mc.item(&"minepiece:item_devil_fruit_mera_mera")])
	var r2 = fr_otim.execute(ent)
	ok(str(r1.getItem().id) != str(r2.getItem().id) and not j.has_meta(&"mc_fruta_cache"), "a fruta do jogador não fica em cache (%s → %s)" % [r1.getItem().id, r2.getItem().id])
	# quem muda de personagem (id_personagem) não herda a resposta antiga
	var p2 := PersonagemMinePiece.new()
	p2.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	p2.position = Vector3(320, 1, 320)
	current_scene.add_child(p2)
	var e2 := McEntidade.de(p2)
	var antes_id: Variant = fr_otim.execute(e2)
	p2.id_personagem = "buggy"
	var depois_esp: Variant = fr_gerada.execute(e2)
	var depois_obt: Variant = fr_otim.execute(e2)
	ok((depois_esp.isEmpty() and depois_obt.isEmpty()) or (not depois_esp.isEmpty() and not depois_obt.isEmpty() and str(depois_esp.getItem().id) == str(depois_obt.getItem().id)), "trocar o id_personagem invalida o cache (antes %s)" % ("vazio" if antes_id.isEmpty() else str(antes_id.getItem().id)))
	print("\notimizadas: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
