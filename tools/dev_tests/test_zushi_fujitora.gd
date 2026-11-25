extends SceneTree
## Zushi Zushi — Jigoku Tabi (K) e Abare Himatsuri (L) (12/11/2026).
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_zushi_fujitora.gd
var total := 0
var falhas := 0
func _init() -> void:
	rodar.call_deferred()
func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)
func q(n: int) -> void:
	for i in n:
		await physics_frame
func rodar() -> void:
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_zushi_fujitora.json"))
	modo.set("progresso_forcado", "user://test_zushi_fujitora.json")
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.max_health = 1.0e7
	j.health = 1.0e7
	j.max_energy = 3000.0
	modo.equipar_fruta(j, "zushi_zushi")
	await q(10)
	var c = j.get_node("FrutaMinePiece")
	var z = c.zushi_fujitora
	ok(z != null, "a Zushi Zushi tem a extensão do Fujitora")
	var nomes: Array = c.estado_das_tecnicas().map(func(g): return str(g.nome))
	ok(nomes.has("Jigoku Tabi") and nomes.has("Abare Himatsuri"), "o HUD lista os 2 poderes novos (%s)" % str(nomes))
	var boneco := BonecoDeDuelo.new()
	current_scene.add_child(boneco)
	boneco.call("parar")
	# --- Jigoku Tabi: dano em área + recarga só dele
	j.global_position = Vector3(0, 1.0, 0)
	await q(30)
	boneco.global_position = j.global_position + Vector3(5, 0.5, 0)
	await q(5)
	boneco.set("health", float(boneco.get("vida_maxima")))
	j.energy = j.max_energy
	var antes: float = j.energy
	c._executar("tecla_k", true)
	await q(5)
	ok(z.ativo and c.ativo, "Jigoku Tabi: o poder começa (%s)" % str(z.ativo))
	ok(j.energy < antes - 400.0, "Jigoku Tabi: gastou energia (%.0f → %.0f)" % [antes, j.energy])
	await q(int((z.J_DURACAO + 0.3) * 60.0))
	ok(not z.ativo and not c.ativo, "Jigoku Tabi: terminou e soltou o controlador")
	ok(float(boneco.get("health")) < float(boneco.get("vida_maxima")), "Jigoku Tabi: o alvo a 5 m levou dano (%.1f/%.1f)" % [float(boneco.get("health")), float(boneco.get("vida_maxima"))])
	ok(c.recarga_da_tecnica(z.JIGOKU) > 0.0, "Jigoku Tabi: tem o próprio cronômetro (%.1f s)" % c.recarga_da_tecnica(z.JIGOKU))
	ok(c.recarga_da_tecnica(z.ABARE) == 0.0, "Abare Himatsuri: segue livre enquanto o Jigoku recarrega")
	c._executar("tecla_k", true)
	await q(3)
	ok(not z.ativo, "Jigoku Tabi: recusa enquanto recarrega")
	# --- Abare Himatsuri: voa e chove meteoros atrás
	j.energy = j.max_energy
	j.global_position = Vector3(0, 1.0, 0)
	await q(20)
	var y0: float = j.global_position.y
	var x0: Vector3 = j.global_position
	c._executar("tecla_l", true)
	await q(60)
	ok(z.ativo and z.poder == z.ABARE, "Abare Himatsuri: começou")
	ok(j.global_position.y > y0 + 1.0, "Abare Himatsuri: subiu na pedra (%.2f → %.2f)" % [y0, j.global_position.y])
	ok(j.global_position.distance_to(x0) > 5.0, "Abare Himatsuri: avança pelo campo (%.1f m)" % j.global_position.distance_to(x0))
	ok(j.get_node_or_null("PedraDoFujitora") != null, "Abare Himatsuri: a pedra está sob os pés")
	ok(z._meteoros.size() > 0, "Abare Himatsuri: há meteoros caindo (%d)" % z._meteoros.size())
	await q(int(z.A_DURACAO * 60.0))
	await q(60)
	ok(not z.ativo and j.get_node_or_null("PedraDoFujitora") == null, "Abare Himatsuri: acabou e a pedra sumiu")
	ok(z._meteoros.is_empty() and z._spec == null, "Abare Himatsuri: os meteoros pousaram e o spec foi solto")
	ok(c.recarga_da_tecnica(z.ABARE) > 0.0, "Abare Himatsuri: tem o próprio cronômetro (%.1f s)" % c.recarga_da_tecnica(z.ABARE))
	# --- Rubble (V): sem grade nenhuma; chuva de rochas sobre o inimigo mirado causa dano
	j.energy = j.max_energy
	j.global_position = Vector3(0, 1.0, 0)
	await q(20)
	var nomes2: Array = c.estado_das_tecnicas().map(func(g): return str(g.tecla))
	ok(nomes2.has("C") and nomes2.has("V"), "C (Moko) e V (Rubble) aparecem SEM grade de recompensa (%s)" % str(nomes2))
	var bandido := PersonagemMinePiece.new()
	bandido.montar(DadosEastBlue.ficha("bandit"), "mp_bandit")
	bandido.position = j.global_position + (-j.global_basis.z) * 8.0
	bandido.ponto_de_origem = bandido.position
	current_scene.add_child(bandido)
	bandido.max_health = 100000.0
	bandido.health = 100000.0
	await q(30)
	var v0: float = bandido.health
	var e0: float = j.energy
	c._tecla_do_mod("V", true)
	await q(5)
	ok(z.ativo and z.poder == z.RUBBLE, "Rubble: a extensão assumiu o V")
	ok(e0 - j.energy >= 590.0, "Rubble: gastou %.0f de energia" % (e0 - j.energy))
	await q(int((z.R_DURACAO + 1.2) * 60.0))
	c._tecla_do_mod("V", false)
	ok(v0 - bandido.health > 0.0, "Rubble: o inimigo mirado levou dano (%.1f)" % (v0 - bandido.health))
	ok(not z.ativo and c.recarga_da_tecnica(z.RUBBLE) > 0.0, "Rubble: terminou e tem o próprio cronômetro (%.1f s)" % c.recarga_da_tecnica(z.RUBBLE))
	ok(c.recarga_da_tecnica(24) == 0.0, "Rubble: a Moko (C) segue livre")
	print("test_zushi_fujitora: %d ok, %d falhas" % [total - falhas, falhas])
	quit(1 if falhas > 0 else 0)
