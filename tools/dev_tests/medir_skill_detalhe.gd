extends SceneTree
## ONDE VAI O TEMPO de uma técnica do mod no pior quadro (11/11/2026, "a skill trava ao colidir com o chão"): no MAPA REAL, câmera para o chão
## (MIRA=ceu = controle), para cada `fruta:tecla[:forma]` de ALVOS, liga o `Cronometro` e imprime os rótulos `McMundo.*` do pior quadro.
##   ALVOS="mori_mori:V,uo_uo_seiryu:Z:forma" godot --headless --path . --script tools/dev_tests/medir_skill_detalhe.gd
## Saída: `DET fruta tecla pior=ms getBlockState_total=N | rotulo=ms/chamadas ...`
func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_skill_detalhe.json")
	root.get_node("GameFlow").start_story()
	await quadros(450)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var avancos = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	var inicio: Vector3 = j.global_position
	for alvo in OS.get_environment("ALVOS").split(","):
		var p: PackedStringArray = alvo.split(":")
		var fruta := p[0]
		var letra := p[1]
		var forma := p.size() > 2
		modo.equipar_fruta(j, "")
		await quadros(5)
		modo.equipar_fruta(j, fruta)
		await quadros(15)
		var c = j.get_node_or_null("FrutaMinePiece")
		if c == null:
			print("DET %s NAO_EQUIPOU" % fruta)
			continue
		if forma:
			c.transformar(false)
			await quadros(20)
		McEntidade.de(j).removeAllEffects()
		j.energy = j.max_energy
		j.global_position = inicio
		j.velocity = Vector3.ZERO
		j._pitch = -1.0 if OS.get_environment("MIRA") != "ceu" else 0.45
		await quadros(25)
		Cronometro.ligado = true
		Cronometro.fechar_quadro()
		Cronometro.fechar_perfil()
		c.usar_tecla(letra, true)
		var pior := 0.0
		var rot_pior := {}
		var soma_bs := 0
		for q in 150:
			if q == 60:
				# O ganho de XP (ex.: matar um animal com a técnica) faz o jogo re-equipar a fruta da PROGRESSÃO e LIBERAR o controlador que este medidor
				# equipou fora dela: nunca guardar `c` para depois — buscar de novo e conferir (o jogo real também busca a cada tecla).
				c = j.get_node_or_null("FrutaMinePiece")
				if is_instance_valid(c):
					c.usar_tecla(letra, false)
			var t0 := Time.get_ticks_usec()
			await physics_frame
			var ms := (Time.get_ticks_usec() - t0) / 1000.0
			var rot: Dictionary = Cronometro.fechar_quadro()
			soma_bs += int(rot.get(&"McMundo.getBlockState", [0, 0])[1])
			if ms > pior:
				pior = ms
				rot_pior = rot
		Cronometro.ligado = false
		var perfil: Dictionary = Cronometro.fechar_perfil()
		var quem := []
		var chaves := perfil.keys()
		chaves.sort_custom(func(a, b): return perfil[a] > perfil[b])
		for k in chaves.slice(0, 4):
			quem.append("%s:%d" % [k, perfil[k]])
		var partes := []
		for k in rot_pior:
			if String(k).begins_with("McMundo"):
				partes.append("%s=%.0fms/%dx" % [String(k).replace("McMundo.", ""), rot_pior[k][0] / 1000.0, rot_pior[k][1]])
		print("DET %s %s%s pior=%.0fms getBlockState_total=%d | %s | QUEM(amostras): %s" % [fruta, letra, " (forma)" if forma else "", pior, soma_bs, ", ".join(partes), ", ".join(quem)])
	print("DET_FIM")
	quit()
