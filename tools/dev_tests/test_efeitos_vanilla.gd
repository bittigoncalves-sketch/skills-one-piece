extends SceneTree
# ============================================================================
#  EFEITOS VANILLA NA CAMADA MINECRAFT (27/10/2026, B4 da auditoria de fidelidade).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_efeitos_vanilla.gd
#
#  O mod pede efeitos pelo nome do CAMPO (`MobEffects.DAMAGE_BOOST`) e por comando pelo nome do REGISTRO (`strength`):
#  têm de ser o mesmo efeito. E os efeitos que mexem em atributo no Minecraft 1.20.1 (Força +3, Fraqueza −4, Aumento de
#  Vida +4, Velocidade +20 %, Lentidão −15 %...) têm de mexer aqui, senão a técnica de um mob que se dá Força no
#  `finalizeSpawn` sai com o dano do corpo nu.
# ============================================================================

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func perto(a: float, b: float, tol := 0.001) -> bool:
	return absf(a - b) <= tol


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	print("\n-- alias campo ↔ registro --")
	for par: Array in [[&"minecraft:damage_boost", &"minecraft:strength"], [&"minecraft:damage_resistance", &"minecraft:resistance"],
			[&"minecraft:movement_speed", &"minecraft:speed"], [&"minecraft:movement_slowdown", &"minecraft:slowness"],
			[&"minecraft:jump", &"minecraft:jump_boost"], [&"minecraft:dig_slowdown", &"minecraft:mining_fatigue"]]:
		ok(Mc.efeito(par[0]) == Mc.efeito(par[1]), "%s = %s" % [par[0], par[1]])
	ok(Mc.efeito(&"minecraft:regeneration") != Mc.efeito(&"minecraft:strength"), "efeitos diferentes continuam diferentes")

	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_efeitos_vanilla.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var pers := PersonagemMinePiece.new()
	pers.montar(DadosEastBlue.ficha("marine"), "mp_marine")
	pers.position = jogador.global_position + Vector3(0, 0, -30)
	pers.ponto_de_origem = pers.position
	current_scene.add_child(pers)
	await quadros(5)
	var e := McEntidade.de(pers)
	e.setNoAi(true)

	print("\n-- modificadores de atributo (Minecraft 1.20.1) --")
	var dano := Mc.atributo(&"minecraft:attack_damage")
	var vel := Mc.atributo(&"minecraft:movement_speed")
	var vida := Mc.atributo(&"minecraft:max_health")
	var base_dano := e.getAttributeValue(dano)
	var base_vel := e.getAttributeValue(vel)
	var base_vida := e.getAttributeValue(vida)
	e.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:damage_boost"), -1, 1))
	ok(perto(e.getAttributeValue(dano), base_dano + 6.0), "Força II: +6 de dano (%.2f → %.2f)" % [base_dano, e.getAttributeValue(dano)])
	e.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:strength"), -1, 3))
	ok(perto(e.getAttributeValue(dano), base_dano + 12.0), "Força IV pelo outro nome: o mesmo efeito sobe para +12")
	e.removeEffect(Mc.efeito(&"minecraft:strength"))
	ok(perto(e.getAttributeValue(dano), base_dano), "sem o efeito o dano volta ao do corpo")
	e.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:weakness"), -1, 0))
	ok(perto(e.getAttributeValue(dano), maxf(base_dano - 4.0, 0.0)), "Fraqueza I: −4 (piso 0)")
	e.removeEffect(Mc.efeito(&"minecraft:weakness"))
	e.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:speed"), -1, 1))
	ok(perto(e.getAttributeValue(vel), base_vel * 1.4, 0.0001), "Velocidade II: +40 %% (×1,4)")
	e.removeEffect(Mc.efeito(&"minecraft:speed"))
	e.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:movement_slowdown"), -1, 2))
	ok(perto(e.getAttributeValue(vel), base_vel * 0.55, 0.0001), "Lentidão III: −45 %% (×0,55)")
	e.removeEffect(Mc.efeito(&"minecraft:slowness"))
	ok(perto(e.getAttributeValue(vel), base_vel, 0.0001), "removida a lentidão a velocidade volta")
	e.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:health_boost"), -1, 2))
	ok(perto(e.getAttributeValue(vida), base_vida + 12.0) and perto(pers.max_health, base_vida + 12.0),
		"Aumento de Vida III: +12 HP no atributo E no corpo (%.0f)" % pers.max_health)
	e.removeEffect(Mc.efeito(&"minecraft:health_boost"))
	ok(perto(pers.max_health, base_vida), "sem o efeito a vida máxima volta (%.0f)" % pers.max_health)

	print("\n-- o comando effect e a procedure falam do mesmo efeito --")
	var fonte := McComandos.Fonte.new()
	fonte.mundo = e.level()
	fonte.entidade = e
	var feitos := McComandos.executar(fonte, "effect give @s minecraft:strength infinite 2 true")
	ok(feitos == 1 and e.hasEffect(Mc.efeito(&"minecraft:damage_boost")) and e.getEffect(Mc.efeito(&"minecraft:damage_boost")).amplificador == 2,
		"efeito dado por comando (strength III) é visto pela procedure (DAMAGE_BOOST)")
	ok(perto(e.getAttributeValue(dano), base_dano + 9.0), "e já vale +9 de dano")

	print("\n-- o que o finalizeSpawn e a IA do mod dão de verdade (sorteado por nascimento) --")
	pers.queue_free()
	var com_forca := 0
	var incoerentes: Array = []
	for id in DadosEastBlue.ids():
		var ficha := DadosEastBlue.ficha(str(id))
		if ficha.is_empty() or str(ficha.get("modelo", "")).is_empty():
			continue
		var c := PersonagemMinePiece.new()
		c.montar(ficha, str(ficha.modelo))
		c.position = jogador.global_position + Vector3(0, 0, -60)
		c.ponto_de_origem = c.position
		current_scene.add_child(c)
		await quadros(45)
		var ent := McEntidade.de(c)
		var f_ef = ent.getEffect(Mc.efeito(&"minecraft:strength"))
		if f_ef != null:
			com_forca += 1
			var esperado: float = float(ficha.get("dano_corpo", 1.0)) + 3.0 * (f_ef.amplificador + 1)
			var fraq = ent.getEffect(Mc.efeito(&"minecraft:weakness"))
			if fraq == null and not perto(ent.getAttributeValue(Mc.atributo(&"minecraft:attack_damage")), esperado, 0.01):
				incoerentes.append(str(id))
		c.queue_free()
	print("  personagens que nasceram com Força: %d de %d" % [com_forca, DadosEastBlue.ids().size()])
	ok(incoerentes.is_empty(), "quem tem o efeito Força ataca com dano do corpo + 3 × (amplificador + 1) (%s)" % str(incoerentes))

	print("\n-- efeito permanente (Integer.MAX_VALUE) sobrevive --")
	ok(Mc.campo(&"Integer", &"MAX_VALUE") == 2147483647 and Mc.campo(&"Long", &"MAX_VALUE") == 9223372036854775807,
		"Integer.MAX_VALUE e Long.MAX_VALUE são números (antes viravam o texto \"MAX_VALUE\" = 0 e o efeito morria no 1º tick)")
	var buggy := PersonagemMinePiece.new()
	buggy.montar(DadosEastBlue.ficha("buggy"), "mp_buggy")
	buggy.position = jogador.global_position + Vector3(0, 0, -60)
	buggy.ponto_de_origem = buggy.position
	current_scene.add_child(buggy)
	await quadros(240)
	var eb := McEntidade.de(buggy)
	var forca_b = eb.getEffect(Mc.efeito(&"minecraft:strength"))
	ok(forca_b != null and forca_b.amplificador == 2 and forca_b.duracao > 1000000000,
		"o Buggy (AIBuggy → SetStatus 2) tem Força III depois de ~4 s e ela segue lá (%s)" % (str(forca_b.amplificador) if forca_b != null else "sem"))
	ok(perto(eb.getAttributeValue(Mc.atributo(&"minecraft:attack_damage")), float(DadosEastBlue.ficha("buggy").get("dano_corpo", 1.0)) + 9.0, 0.01),
		"e o ataque do corpo inclui +9 da Força III")
	buggy.queue_free()

	print("\n-- recompensa lida da vítima viva (WhenEntityDie) --")
	var vitima := PersonagemMinePiece.new()
	vitima.montar(DadosEastBlue.ficha("marine"), "mp_marine")
	vitima.position = jogador.global_position + Vector3(0, 0, -60)
	vitima.ponto_de_origem = vitima.position
	current_scene.add_child(vitima)
	await quadros(20)
	var ev := McEntidade.de(vitima)
	var sem := preload("res://src/historia/recompensa_mine_piece.gd").xp_do_personagem(vitima)
	ev.addEffect(McEfeito.instancia(Mc.efeito(&"minecraft:strength"), -1, 4))
	var com := preload("res://src/historia/recompensa_mine_piece.gd").xp_do_personagem(vitima)
	ok(com > sem, "a mesma vítima vale mais com Força V (%d → %d): a recompensa lê o efeito, não a ficha" % [sem, com])
	vitima.queue_free()

	print("\n-- empurrão do Minecraft nos inimigos (0,4 bloco/tick, pulinho, resistência) --")
	var recuos := {}
	for id in ["marine", "arlong"]:
		var c := PersonagemMinePiece.new()
		c.montar(DadosEastBlue.ficha(id), "mp_" + id)
		c.position = jogador.global_position + Vector3(0, 0, -60)
		c.ponto_de_origem = c.position
		current_scene.add_child(c)
		McEntidade.de(c).setNoAi(true)
		c.max_health = 100000.0
		c.health = 100000.0
		await quadros(20)
		var p0: Vector3 = c.global_position
		c.take_damage(5.0, p0 + Vector3(0, 0, 3.0), Vector3.ZERO, 0.0)         # golpe CRU, vindo do +Z
		var maximo := 0.0
		var subiu := false
		for i in 60:
			await physics_frame
			maximo = maxf(maximo, c.global_position.distance_to(p0))
			subiu = subiu or c.global_position.y > p0.y + 0.05
		recuos[id] = maximo
		ok(maximo > 0.3 * (1.0 - float(c.ficha.get("resistencia_a_empurrao", 0.0))) and c.global_position.z < p0.z + 0.01,
			"%s sai do lugar com um golpe cru, para LONGE de quem bateu (%.2f m, resistência a empurrão %.1f)" % [id, maximo, float(c.ficha.get("resistencia_a_empurrao", 0.0))])
		ok(subiu, "%s dá o pulinho do Minecraft ao ser empurrado no chão" % id)
		# O segundo golpe dentro de 0,5 s NÃO empurra de novo (a janela só limita o empurrão).
		var antes: float = c.health
		var pos2: Vector3 = c.global_position
		c.take_damage(5.0, pos2 + Vector3(0, 0, 3.0), Vector3.ZERO, 0.0)
		await quadros(3)
		c.take_damage(5.0, c.global_position + Vector3(0, 0, 3.0), Vector3.ZERO, 0.0)
		var esperado_dano: float = 2.0 * DadosEastBlue.dano_recebido(c._defesa_viva(), 5.0)
		ok(absf((antes - c.health) - esperado_dano) < 0.2, "%s: o dano de golpes seguidos continua inteiro, só com a defesa dele (%.2f de %.2f)" % [id, antes - c.health, esperado_dano])
		c.queue_free()
	ok(recuos["marine"] > recuos["arlong"], "quem tem resistência a empurrão (Arlong 0,5) recua menos que o marinheiro (%.2f > %.2f)" % [recuos["marine"], recuos["arlong"]])

	print("\n-- o mesmo empurrão nos outros inimigos (boneco de duelo / bandidos) --")
	var boneco := BonecoDeDuelo.new()
	boneco.position = jogador.global_position + Vector3(0, 0, -80)
	current_scene.add_child(boneco)
	await quadros(20)
	boneco.health = 100000.0
	var pb: Vector3 = boneco.global_position
	boneco.take_damage(5.0, pb + Vector3(0, 0, 3.0), Vector3.ZERO, 0.0)
	var recuo := 0.0
	for i in 60:
		await physics_frame
		recuo = maxf(recuo, boneco.global_position.distance_to(pb))
	ok(recuo > 0.3 and boneco.global_position.z < pb.z + 0.01, "o boneco de duelo também sai do lugar com um golpe cru, para longe de quem bateu (%.2f m)" % recuo)
	var antes_b: Vector3 = boneco.global_position
	boneco.take_damage(5.0, antes_b + Vector3(0, 0, 3.0), Vector3.ZERO, 0.0)
	boneco.take_damage(5.0, antes_b + Vector3(0, 0, 3.0), Vector3(0, 0, -6.0), 0.0)
	await quadros(30)
	ok(boneco.global_position.distance_to(antes_b) > 0.0, "e o golpe com empurrão próprio continua valendo")
	boneco.queue_free()

	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
