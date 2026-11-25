extends SceneTree
## Despeja em user://tecnicas_do_mod.json: fruta → lista de {tecla, numero, nome, custo} das frutas só-do-mod (base da documentação gerada).
func quadros(n: int) -> void:
	for i in n:
		await physics_frame
func _init() -> void:
	rodar.call_deferred()
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://dump_tecnicas.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var j = get_first_node_in_group("player")
	var avancos = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	var saida := {}
	for id in PerfilDeFrutas.frutas_so_do_mod():
		modo.equipar_fruta(j, "")
		await quadros(4)
		modo.equipar_fruta(j, id)
		await quadros(15)
		var c = j.get_node_or_null("FrutaMinePiece")
		if c == null or not c.fruta_ativa():
			continue
		var linhas := []
		var mapa: Dictionary = c.mapa_de_teclas()
		var por_numero := {}
		for t in mapa:
			por_numero[int(mapa[t])] = t
		for e in c.estado_das_tecnicas():
			var n := int(e.get("numero", -1)) if e.has("numero") else -1
			linhas.append({"nome": str(e.nome), "custo": float(e.get("custo", 0.0)), "tecla": str(e.get("tecla", "")), "numero": n})
		saida[id] = {"tecnicas": linhas, "mapa": mapa}
	var f := FileAccess.open("user://tecnicas_do_mod.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(saida, "\t"))
	f.close()
	print("DUMP ", saida.size(), " frutas em ", ProjectSettings.globalize_path("user://tecnicas_do_mod.json"))
	quit()
