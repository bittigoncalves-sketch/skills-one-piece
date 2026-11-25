extends SceneTree
# ============================================================================
#  IA DO MOD NOS PERSONAGENS (23/10/2026, src/minecraft/ia_do_mod.gd; decisão do dono: junto com
#  o cérebro, atrás de chave):
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ia_do_mod.gd
#
#    • todo personagem do Mine Piece ganha o nó `IaDoMod` com a IA do `baseTick` do mod;
#    • DESLIGADA (padrão): nada roda — o Arlong ferido não saca a arma;
#    • LIGADA: o comportamento do mod acontece — `AIArlongProcedure` põe a Kiribachi na mão do
#      Arlong ferido (< 50 %) que tem alvo; e o `finalizeSpawn` (SetTagPirate) roda ao nascer.
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
	modo.set("progresso_forcado", "user://test_ia_do_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	ok(IaDoMod.ligada, "a IA do mod começa ligada (as habilidades dos inimigos são as do mod)")
	IaDoMod.ligada = false                                       # a seção seguinte mede o "desligado"

	var arlong := PersonagemMinePiece.new()
	arlong.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	arlong.position = jogador.global_position + Vector3(0, 0, -6)
	arlong.ponto_de_origem = arlong.position
	current_scene.add_child(arlong)
	await quadros(5)
	ok(arlong.ia_do_mod != null and arlong.ia_do_mod.tem_ia(), "o Arlong ganhou a IA do mod (AIArlongProcedure)")
	var ent := McEntidade.de(arlong)
	arlong.health = arlong.max_health * 0.4                      # ferido: abaixo de 50 %
	await quadros(30)
	ok(ent.getMainHandItem().isEmpty(), "desligada: nada roda (mão vazia)")

	# A Kiribachi sai com ALVO e a cada 11 ticks (`cnt_x > 10` na AIArlongProcedure): alvo no jogador.
	# O jogador NÃO pode estar invulnerável: a EntityActiveProcedure (LivingTickEvent) larga alvo que
	# a LogicAttackProcedure diz não poder atacar (como um jogador no criativo). Vida alta no lugar.
	jogador.set_meta("damage_immune", false)
	jogador.max_health = 100000.0
	jogador.health = 100000.0
	arlong.cerebro.alvo = jogador
	IaDoMod.ligada = true
	await quadros(60)                                            # ~20 ticks do mod
	var mao := ent.getMainHandItem()
	ok(not mao.isEmpty() and mao.getItem() == Mc.item(&"minepiece:kiribachi"),
		"ligada: abaixo de 50 %% o Arlong saca a Kiribachi (%s)" % (str(mao.getItem()) if not mao.isEmpty() else "vazia"))
	# Visual: a arma sacada aparece NA MÃO do modelo (mpi_kiribachi.glb no osso itemMainHand) e a técnica toca o clipe.
	var osso_mao := arlong.find_child("itemMainHand", true, false)
	ok(osso_mao != null and osso_mao.get_node_or_null("Arma_MAINHAND") != null, "a Kiribachi foi desenhada no osso da mão")
	arlong._clipe_atual = ""
	ent.triggerAnim("procedure", "punch_right")
	ok(arlong._clipe_atual == "punch_right" and arlong._clipe_trava > 0.0, "triggerAnim toca o clipe punch_right (%s)" % arlong._clipe_atual)
	ok(Mc.e(ent, &"GeoEntity") and str(arlong.get_meta("mc_animacao", "")) == "punch_right", "o nome da animação fica em mc_animacao")
	ent.triggerAnim("procedure", "empty")
	ok(arlong._clipe_trava == 0.0, "'empty' devolve ao ciclo base")
	# SetTagPirate grava 1 e depois sorteia o número do bando: basta ser ≠ 0.
	ok(ent.getPersistentData().getDouble("Pirate") != 0.0,
		"ligada: o finalizeSpawn (SetTagPirateProcedure) marcou o Arlong como pirata (bando %d)" % ent.getPersistentData().getDouble("Pirate"))
	var vivo_antes := arlong.vivo()
	await quadros(120)
	ok(arlong.vivo() == vivo_antes and is_instance_valid(arlong), "2 s de IA do mod sem derrubar o personagem")

	print("\n-- eventos do Forge --")
	# RatioDamageProcedure (LivingDamageEvent): afogamento soma 25 % da vida máxima ao dano.
	var ev := McEvento.disparar(&"LivingDamageEvent", ent, McFonteDeDano.de(&"minecraft:drown"), 10.0)
	ok(absf(ev.getAmount() - (10.0 + arlong.max_health * 0.25)) < 0.01,
		"LivingDamageEvent: afogamento 10 → %.1f (10 + 25 %% de %.0f), pelo handler do mod" % [ev.getAmount(), arlong.max_health])
	var ev2 := McEvento.disparar(&"LivingDamageEvent", ent, McFonteDeDano.de(&"minecraft:generic"), 10.0)
	ok(is_equal_approx(ev2.getAmount(), 10.0), "LivingDamageEvent: dano comum não muda (%.1f)" % ev2.getAmount())
	# Deixa o Arlong OCIOSO antes do golpe: no meio de uma técnica (`skill` ≠ 0) o handler do mod cancela o dano (armadura de técnica — fiel ao mod), e depois de
	# 2 s de IA ele cai numa técnica em ~metade das execuções (09/11/2026: era a intermitência deste teste, não regressão — medido com diagnóstico).
	ent.removeEffect(Mc.efeito("minepiece:skill"))
	ent.getPersistentData().putDouble("skill", 0.0)
	ent.getPersistentData().putDouble("Damage", 0.0)
	var vida_antes := arlong.health
	arlong.take_damage(5.0, jogador.global_position)
	ok(arlong.health < vida_antes and arlong.health > vida_antes - 5.01,
		"golpe do jogador com a IA ligada passa pelos eventos e tira vida (%.1f → %.1f)" % [vida_antes, arlong.health])

	print("\n-- combate do mod de ponta a ponta --")
	# Só a IA do mod ataca: o cérebro parado (NoAI); o teste faz o papel da MeleeAttackGoal (encarar o
	# alvo — o golpe sai na direção do olhar). Queda de vida medida ENTRE ticks (a regeneração do jogador
	# devolveria o total) e os golpes contados pela camada.
	arlong.set_meta("mc_sem_ia", true)
	arlong.cerebro.alvo = jogador
	# Parado (NoAI não anda, como no Minecraft): perto o bastante para o golpe corpo a corpo.
	arlong.global_position = jogador.global_position + Vector3(0, 0, -2.5)
	# Em TEMPO REAL (a IaDoMod tica sozinha, 20/s): acelerar os ticks do mod deixaria quase todo golpe
	# dentro da invulnerabilidade de 0,5 s (tempo real) do knockback Minecraft do jogador.
	Mc.contadores.clear()
	var quedas := 0
	var ponto_do_jogador: Vector3 = jogador.global_position
	for f in 600:                                                # 10 s
		# O jogador agora é empurrado de verdade (23/10 e 27/10): sem isto o golpe o joga para fora do alcance do Arlong parado.
		if f % 30 == 29:
			jogador.global_position = ponto_do_jogador
		var d: Vector3 = jogador.global_position - arlong.global_position
		arlong.rotation.y = atan2(-d.x, -d.z)
		var antes_q: float = jogador.health
		await physics_frame
		if jogador.health < antes_q - 0.5:
			quedas += 1
	var golpes := 0
	for k: String in Mc.contadores:
		if k.begins_with("hurt:jogador:vivo:"):
			golpes += int(Mc.contadores[k])
	ok(golpes > 0 and quedas > 0, "as técnicas do Arlong ferem o jogador pelo funil do jogo (%d golpes, %d quedas de vida)" % [golpes, quedas])
	var animacoes := Mc.contadores.keys().filter(func(k: String) -> bool: return k.begins_with("anim:") and k != "anim:empty")
	print("   animações disparadas pela IA no combate: ", animacoes)
	ok(not animacoes.is_empty(), "as técnicas disparam animações do modelo (triggerAnim) — %d tipos" % animacoes.size())
	arlong.set_meta("mc_sem_ia", false)

	IaDoMod.ligada = false
	print("\n%d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
