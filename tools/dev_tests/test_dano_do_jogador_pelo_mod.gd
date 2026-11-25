extends SceneTree
# ============================================================================
#  ITEM 4: o dano que o JOGADOR recebe passa pelos eventos do mod (LivingAttack/Hurt/Damage). Prova: o Haki de Armamento do mod reduz o dano; sem ele o dano é o
#  de sempre; o evento não entra em laço (reentrada) e a vida baixa o esperado.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_dano_do_jogador_pelo_mod.gd
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

func levar(j, dano: float, de: Node3D) -> float:
	await physics_frame
	j.knockback_minecraft.cancelar() if j.knockback_minecraft != null else null
	j._vida.vida = j.max_health
	j.health = j.max_health
	var antes: float = j.health
	McEntidade.de(j).set_meta("x", 0) if false else null
	j.set_meta("autor_do_dano", de.get_instance_id())
	j.take_damage(dano, de.global_position, Vector3.ZERO, 0.0)
	j.remove_meta("autor_do_dano")
	return antes - j.health

func rodar() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_dano_mod.json"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_dano_mod.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.max_health = 1000.0
	j.health = 1000.0
	var atacante := PersonagemMinePiece.new()
	atacante.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	atacante.position = j.global_position + Vector3(0, 0, -3)
	atacante.ponto_de_origem = atacante.position
	current_scene.add_child(atacante)
	atacante.process_mode = Node.PROCESS_MODE_DISABLED
	await q(10)
	ok(j.get_node_or_null("JogadorDoMod") != null, "o jogador tem o JogadorDoMod")
	var ej := McEntidade.de(j)
	var base := await levar(j, 100.0, atacante)
	ok(base > 0.0, "golpe de 100 sem proteção: a vida baixa (%.1f)" % base)
	# Haki de Armamento do mod (efeito permanente nível alto): o `WhenEntityTakesDamage`/`RatioDamage` do mod reduzem o dano
	ej.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito(&"minepiece:armament_haki"), 2147483647, 5, false, false]))
	await q(3)
	var com_haki := await levar(j, 100.0, atacante)
	print("  ℹ️ dano sem Haki %.2f, com Haki de Armamento nível 5: %.2f" % [base, com_haki])
	ok(com_haki < base, "Haki de Armamento reduz o dano que o jogador recebe (%.1f → %.1f)" % [base, com_haki])
	ej.removeEffect(Mc.efeito("minepiece:armament_haki"))
	await q(3)
	var depois := await levar(j, 100.0, atacante)
	ok(absf(depois - base) < 0.01, "tirando o Haki o dano volta ao normal (%.1f)" % depois)
	# reentrada: 50 golpes seguidos não travam nem acumulam estado
	var soma := 0.0
	for i in 50:
		soma += await levar(j, 10.0, atacante)
	ok(soma > 0.0 and not j.get_node("JogadorDoMod")._em_evento, "50 golpes seguidos: sem laço de eventos (total %.1f)" % soma)
	print("\ndano pelo mod: %d verificações, %d falhas" % [total, falhas])
	quit(1 if falhas > 0 else 0)
