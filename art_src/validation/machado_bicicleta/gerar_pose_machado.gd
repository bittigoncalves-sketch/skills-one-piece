extends SceneTree
## Fonte reproduzível da animação: corte pesado de cima, com pega e arco próprios.
func _init() -> void:
	var estilo := (load("res://src/combat/direcional/estilos/espada.tres") as EstiloCorpoACorpo).duplicate(true) as EstiloCorpoACorpo
	estilo.id = &"machado"
	estilo.nome = "Machado de lenhador"
	var alto := estilo.golpes[3]
	estilo.golpes.clear()
	for direcao in 4:
		var g := alto.duplicate(true) as GolpeDirecional
		g.id = StringName("machado_corte_%d" % direcao)
		g.nome = "Lenhar"
		g.direcao = direcao as GolpeDirecional.Direcao
		g.preparo = 0.36
		g.ativo = 0.26
		g.recuperacao = 0.40
		g.avanco = 0.0
		g.efetor = &"MachadoFio"
		g.efetor_base = &""
		# Coleta tem seu próprio contato; não causa dano de espada aos NPCs.
		g.dano = 0.0
		for i in g.chaves.size():
			var c := g.chaves[i]
			c.rotacoes["Wrist_R"] = [Vector3(205, 0, 0), Vector3(175, 0, 0), Vector3(90, 0, 0), Vector3(40, 0, 0), Vector3(140, 0, 0)][i]
			c.mao_direita = [Vector3(.24,1.65,-.06), Vector3(.22,1.55,-.18), Vector3(.15,1.15,-.53), Vector3(.18,.85,-.55), Vector3(.26,1.02,-.26)][i]
			c.mao_esquerda = Vector3(-.24, 1.05, -.12)
			c.rotacoes["Torso"] = Vector3([ -8, -4, 10, 15, 0 ][i], [ -16, -10, 10, 16, 0 ][i], 0)
		estilo.golpes.append(g)
	estilo.guarda.rotacoes["Wrist_R"] = Vector3(150, 0, -15)
	assert(ResourceSaver.save(estilo, "res://src/combat/direcional/estilos/machado.tres") == OK)
	quit()
