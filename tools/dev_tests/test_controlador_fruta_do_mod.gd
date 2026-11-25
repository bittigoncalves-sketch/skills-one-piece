extends SceneTree
# ============================================================================
#  CONTROLADOR DA FRUTA DO MOD (03/11/2026): o jogador equipa a fruta pelo ponto único do ModoHistoria e a usa
#  pela interface do controlador (R troca, Z segura/solta) — quem executa é o mod (sem skill builder).
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_controlador_fruta_do_mod.gd
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
	# Estes testes medem a duração em TICKS do mod: rodam no relógio do mod (1.0). A velocidade reduzida dos projéteis (0,5) tem teste próprio.
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_controlador_fruta_do_mod.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -4)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)

	var hud = get_first_node_in_group("hud")
	McEntidade.de(jogador).displayClientMessage(Mc.estatico(&"Component", &"translatable", ["minepiece.message.dont_use"]), true)
	ok(hud != null and str(hud._aviso.text) != "" and not str(hud._aviso.text).begins_with("minepiece."),
		"a mensagem do mod aparece no HUD, traduzida (%s)" % (str(hud._aviso.text) if hud != null else "sem HUD"))
	for id in ["gomu_gomu", "mera_mera"]:
		modo.equipar_fruta(jogador, "")
		await quadros(5)
		modo.equipar_fruta(jogador, id)
		await quadros(10)
		var c = jogador.get_node_or_null("FrutaMinePiece")   # tipos que dependem do Player só em runtime (autoloads)
		ok(c != null and c.get_script().get_global_name() == &"ControladorFrutaDoMod", "%s: o controlador é o do mod" % id)
		ok(c != null and c.fruta_ativa(), "%s: fruta ativa no jogador" % id)
		var lista: Array = c.estado_das_tecnicas()
		ok(lista.size() >= 2, "%s: o mod oferece %d golpes (%s)" % [id, lista.size(), ", ".join(lista.map(func(g): return g.nome))])
		ok(lista.size() > 0 and not str(lista[0].nome).begins_with("minepiece."), "%s: nomes traduzidos para o HUD" % id)
		jogador.energy = jogador.max_energy
		alvo.health = alvo.max_health
		var e0: float = jogador.energy
		# A mira (câmera) manda na direção do golpe do mod: aponta para o alvo (antes valia a rotação do corpo, sempre a mesma).
		jogador.global_position = alvo.global_position + Vector3(0, 0.8, 4.0)     # a fruta anterior pode ter levado o jogador para longe
		jogador.velocity = Vector3.ZERO
		await quadros(5)
		for _i in 4:      # a câmera orbita o jogador: refaz a conta até o raio dela passar pelo alvo
			var mira: Vector3 = alvo.global_position + Vector3.UP - jogador._cam.global_position
			var dir_mira := mira.normalized()
			jogador._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
			jogador._pitch = asin(dir_mira.y)       # o raio da câmera passa pelo peito do alvo
			jogador._update_pivot()
			await quadros(3)
		c.usar(true)
		# Mera (Sun Flare/Kagero) VOA para onde a mira aponta enquanto segura e explode 2 blocos à frente ao soltar: apontando de verdade
		# para o alvo, segurar 30 quadros passa direto por ele. Solta cedo (o alvo está a 4 m).
		await quadros(3 if id == "mera_mera" else 30)
		c.usar(false)
		await quadros(80)
		var dano: float = alvo.max_health - alvo.health
		ok(dano > 0.0, "%s: Z segurado e solto feriu o alvo (%.0f)" % [id, dano])
		ok(jogador.energy < e0, "%s: a energia do jogo foi gasta (%.0f → %.0f)" % [id, e0, jogador.energy])
		# lentidão do mod: a técnica em curso com movement_slowdown prende o corpo; sem a técnica, não
		var mc := McEntidade.de(jogador)
		ok(not c.controla_movimento(), "%s: parado, o controlador não controla o movimento" % id)
		mc.getPersistentData().putDouble("skill", -999.0)   # ramo inerte do mod: só recarga
		mc.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito("minepiece:skill"), 100, 0, false, false]))
		mc.addEffect(Mc.novo(&"MobEffectInstance", [Mc.efeito("minecraft:movement_slowdown"), 40, 2, false, false]))
		await quadros(4)
		ok(c.controla_movimento(), "%s: técnica em curso com lentidão 2 prende o corpo" % id)
		var q = load("res://src/player/move_frame.gd").new()
		q.dir = Vector3(1, 0, 0)
		var vel: Vector3 = c.velocidade(0.016, Vector3.ZERO, q)
		ok(absf(vel.x - jogador.SPEED * jogador.speed_multiplier * (1.0 - 0.15 * 3.0)) < 0.001, "%s: velocidade = −45 %% (lentidão 2): %.2f" % [id, vel.x])
		mc.removeAllEffects()
		await quadros(4)
		ok(not c.controla_movimento(), "%s: sem a técnica volta a andar livre" % id)
		var antes: int = c.selecao
		c.trocar(false)
		ok(c.selecao != antes, "%s: R trocou de golpe (%d → %d)" % [id, antes, c.selecao])
		McEntidade.de(jogador).removeAllEffects()
		await quadros(4)
		var mapa: Dictionary = c.mapa_de_teclas()
		ok(c.tem_teclas_diretas() and mapa.size() == mini(lista.size(), 6) and lista[0].tecla == "Z" and lista[1].tecla == "X",
			"%s: cada golpe na sua tecla, na ordem do mod (%s)" % [id, str(mapa)])
		c.usar_tecla("X", true)
		ok(c.selecao == int(mapa["X"]), "%s: a tecla X escolhe o 2º golpe (%d)" % [id, c.selecao])
		c.usar_tecla("X", false)
		await quadros(60)
		McEntidade.de(jogador).removeAllEffects()
	# transformação (Zoan): J no HUD → controlador → KeyTransform do mod → escala do corpo pelo Pehkui
	modo.equipar_fruta(jogador, "")
	await quadros(5)
	modo.equipar_fruta(jogador, "hito_hito_daibutsu")
	await quadros(10)
	var z = jogador.get_node_or_null("FrutaMinePiece")
	var cap_antes: float = jogador._colisor.shape.height
	ok(z.pode_transformar() and z.avisos() == "J transforma", "Zoan: o HUD anuncia a tecla de transformar (%s)" % z.avisos())
	z.transformar(false)
	await quadros(30)
	ok(z.forma_atual() == 1 and jogador._colisor.shape.height > cap_antes * 3.0, "B: forma 1 do mod, corpo gigante (cápsula %.2f → %.2f)" % [cap_antes, jogador._colisor.shape.height])
	modo.equipar_fruta(jogador, "gomu_gomu")
	await quadros(10)
	ok(absf(jogador._colisor.shape.height - cap_antes) < 0.05 and McEntidade.de(jogador).escala(&"height") == 1.0, "trocar de fruta desfaz a forma (cápsula %.2f)" % jogador._colisor.shape.height)
	var g = jogador.get_node_or_null("FrutaMinePiece")
	ok(not g.pode_transformar() and g.avisos() == "", "fruta sem transformação: sem o aviso")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
