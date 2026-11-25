extends SceneTree
## Aro Aro, golpe Arrow (08/11/2026): a flecha de carga (DATA_move 1) SEGUE o jogador e SOME quando a técnica acaba — é o `tick()` da classe
## (`AIArrowBarrierProcedure`), que o extrator só passou a rodar para entidades que não são projétil. Antes ela ficava girando no ponto
## onde nasceu para sempre ("a seta roda ao redor do jogador mas não é disparada"). Soltar a tecla dispara outra flecha, que voa.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_aro_aro_seta.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _flechas() -> Array:
	return current_scene.get_children().filter(func(n): return str(n.name).begins_with("MC_entity_arrow"))

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_aro_aro_seta.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = j.global_position + Vector3(0, 0, -4)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	modo.equipar_fruta(j, "aro_aro")
	await quadros(15)
	var c = j.get_node("FrutaMinePiece")
	j.energy = j.max_energy
	var vida0: float = alvo.health
	c.usar_tecla("Z", true)
	await quadros(30)
	var carga := _flechas()
	ok(is_equal_approx(McEntidade.de(j).getPersistentData().fator_de_alcance, FrutasDoMod.ALCANCE_DO_ARO_ARO), "hitbox do Aro Aro: o dono lê o Range ×%.1f" % FrutasDoMod.ALCANCE_DO_ARO_ARO)
	ok(carga.size() == 1 and is_equal_approx(McEntidade.de(carga[0]).getPersistentData().fator_de_alcance, FrutasDoMod.ALCANCE_DO_ARO_ARO), "e a flecha também")
	var nbt := McEntidade.de(j).getPersistentData()
	nbt.putDouble("Range", 6.0)
	ok(is_equal_approx(nbt.getDouble("Range"), 6.0 * FrutasDoMod.ALCANCE_DO_ARO_ARO) and is_equal_approx(nbt.getDouble("cnt1"), 0.0 + nbt.getDouble("cnt1")), "o RangeAttack enxerga o cubo maior (6 → %.0f)" % nbt.getDouble("Range"))
	ok(carga.size() == 1, "segurando Z: uma flecha de carga (%d)" % carga.size())
	j.global_position += Vector3(5, 0, 0)
	await quadros(8)
	ok(carga.size() == 1 and is_instance_valid(carga[0]) and (carga[0] as Node3D).global_position.distance_to(j.global_position + Vector3(0, 0.9, 0)) < 1.5,
		"a flecha de carga ACOMPANHA o jogador quando ele anda")
	c.usar_tecla("Z", false)
	await quadros(20)       # o relógio dos projéteis anda a metade (FATOR_DE_PROJETIL): a flecha de carga leva ~2× mais quadros para sumir
	var disparada := _flechas()
	ok(disparada.size() == 1 and (disparada[0] as Node3D).global_position.distance_to(j.global_position) > 3.0, "soltou: a flecha de carga some e uma flecha DISPARADA voa (%d)" % disparada.size())
	await quadros(260)
	ok(_flechas().is_empty(), "depois da técnica não sobra flecha girando (%d)" % _flechas().size())
	print("\n-- a direção segue a mira --")
	var dir1 := await _disparar_e_medir(j, c, 0.0)
	var dir2 := await _disparar_e_medir(j, c, PI * 0.5)
	var dir3 := await _disparar_e_medir(j, c, PI)
	print("     direções: ", dir1, dir2, dir3)
	ok(dir1.length() > 0.5 and dir2.length() > 0.5 and dir3.length() > 0.5, "as três flechas voaram")
	ok(dir1.dot(dir2) < 0.3 and dir1.dot(dir3) < -0.5, "virar a câmera 90° e 180° vira a direção do tiro (%.2f / %.2f)" % [dir1.dot(dir2), dir1.dot(dir3)])
	print("\nARO_ARO_SETA %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)


## Vira a câmera para `yaw`, dispara Z e devolve a direção (plano XZ, normalizada) em que a flecha disparada andou.
func _disparar_e_medir(j, c, yaw: float) -> Vector3:
	await quadros(60)
	j._yaw = yaw
	j._update_pivot()
	await quadros(20)
	j.energy = j.max_energy
	c.recarga = 0.0
	c._recargas.clear()      # a recarga real é por técnica (`recarga` é recalculada a partir dela a cada tick)
	McEntidade.de(j).removeAllEffects()
	c.usar_tecla("Z", true)
	await quadros(30)
	c.usar_tecla("Z", false)
	var voo: Node3D = null
	for i in 40:
		await quadros(1)
		for f in _flechas():
			if (f as Node3D).global_position.distance_to(j.global_position + Vector3(0, 0.9, 0)) > 2.5:
				voo = f
				break
		if voo != null:
			break
	if voo == null:
		return Vector3.ZERO
	var p0 := voo.global_position
	await quadros(3)
	if not is_instance_valid(voo):
		return Vector3.ZERO
	var d := voo.global_position - p0
	d.y = 0
	return d.normalized()
