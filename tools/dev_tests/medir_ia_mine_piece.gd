extends SceneTree
# ============================================================================
#  MEDIDOR DA IA DO MINE PIECE pela camada Minecraft (E1 → onda 1, 23/10/2026).
#  Para cada personagem com ficha no jogo: o `baseTick` do mod chama `AI<Nome>Procedure` todo
#  tick. Aqui ela roda TRADUZIDA por N ticks, com o jogador perto como alvo, e sai:
#    • quantos ticks rodaram sem erro de script (erro aborta a procedure naquele tick);
#    • o que a camada ainda não tem (`Mc.pedidos_sem_implementacao`).
#  Os erros de script saem no log (SCRIPT ERROR ... at: execute (res://…)).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/medir_ia_mine_piece.gd [-- --ticks=200 --so=arlong]
# ============================================================================

var ticks := 200
var so := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			ticks = int(a.trim_prefix("--ticks="))
		elif a.begins_with("--so="):
			so = a.trim_prefix("--so=")
	rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


## Procedure de IA da ficha: `AI` + nome da classe do mod (`arlong` → AIArlongProcedure).
static func procedure_da_ia(id: String) -> String:
	var classe := ""
	for parte in id.split("_"):
		classe += parte.capitalize().replace(" ", "")
	return "AI%sProcedure" % classe


func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://medir_ia_mine_piece.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	# Vulnerável (vida alta): invulnerável, a EntityActiveProcedure do mod larga o alvo e nenhuma técnica sai.
	jogador.set_meta("damage_immune", false)
	jogador.max_health = 1.0e9
	jogador.health = 1.0e9
	var ids := SpawnNaturalMinePiece.entradas_que_nascem().map(func(e): return str(e["id"]))
	if not so.is_empty():
		ids = [so]
	var resumo := {}
	for id in ids:
		# A IA de verdade: as procedures do `baseTick` da classe (ficha do mod); senão o nome adivinhado.
		var tick: Array = Mc.ficha_do_mod(id).get("tick", [])
		var nome: String = str(tick[0]) if not tick.is_empty() else procedure_da_ia(id)
		if not FileAccess.file_exists(Mc.PROCEDURES + nome + ".gd"):
			print("IA_MP %-16s sem %s" % [id, nome])
			continue
		var pers := PersonagemMinePiece.new()
		pers.montar(DadosEastBlue.ficha(id), str(DadosEastBlue.ficha(id).get("modelo", "")))
		pers.position = jogador.global_position + Vector3(0, 0, -5)
		pers.ponto_de_origem = pers.position
		current_scene.add_child(pers)
		await quadros(3)
		if pers.cerebro != null:
			pers.cerebro.alvo = jogador
		var ent := McEntidade.de(pers)
		var mundo: McMundo = ent.level()
		Mc.pedidos_sem_implementacao.clear()
		# O componente do jogo: baseTick + LivingTickEvent (as técnicas); golpes do jogador a cada
		# 40 ticks exercitam LivingAttack/Hurt/Damage.
		IaDoMod.ligada = true
		for t in ticks:
			jogador.health = jogador.max_health
			pers.ia_do_mod.um_tick()
			mundo.tick()
			if t % 40 == 20 and pers.vivo():
				pers.take_damage(1.0, jogador.global_position)
			if t % 4 == 0:
				await physics_frame
		IaDoMod.ligada = false
		var faltas: Dictionary = Mc.pedidos_sem_implementacao.duplicate()
		resumo[id] = faltas
		print("IA_MP %-16s %s  faltas: %s" % [id, nome, faltas])
		pers.queue_free()
		await quadros(2)
	var total := {}
	for id in resumo:
		for k in resumo[id]:
			total[k] = int(total.get(k, 0)) + 1
	var ordem := total.keys()
	ordem.sort_custom(func(a, b): return total[a] > total[b])
	print("\nIA_MP_TOTAL (em quantos personagens cada falta aparece):")
	for k in ordem:
		print("  %3d  %s" % [total[k], k])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
