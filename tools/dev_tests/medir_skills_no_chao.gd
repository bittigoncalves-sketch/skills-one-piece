extends SceneTree
## DESEMPENHO DAS TÉCNICAS DAS FRUTAS DO MOD CONTRA O CHÃO (11/11/2026, o dono: "o bug acontece quando a skill colide com o chão").
## No MAPA REAL (relevo em blocos, ~200 entidades — o mapa plano esconde o custo do terreno), para cada fruta e cada técnica (Z X C V B N):
## aponta a câmera para o chão, segura a tecla ~1 s, solta, espera ~1,5 s e mede o tempo de cada quadro de física.
##   MIRA=chao (padrão) | ceu   — o céu é o controle: mesma técnica sem tocar o terreno.
##   godot --headless --path . --script tools/dev_tests/medir_skills_no_chao.gd -- [fruta ...]    (sem args: todas as do mod)
## Saída: uma linha `SK fruta tecla nome pior=ms media=ms p95=ms nos+N`; resumo ordenado pelo pior quadro no fim.
## Corte de segurança: a técnica que passar de +6000 nós ou de um quadro de 4 s é marcada e a varredura segue.
const SEGURAR := 60
const SOLTA := 90
var resultados: Array = []

func _init() -> void:
	rodar.call_deferred()

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://medir_skills_no_chao.json")
	root.get_node("GameFlow").start_story()
	await quadros(450)                               # o mapa real carrega por distância: espera assentar
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var avancos = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	var inicio: Vector3 = j.global_position
	var mira := OS.get_environment("MIRA") if OS.get_environment("MIRA") != "" else "chao"
	var pitch: float = -1.0 if mira == "chao" else 0.45
	var ids: Array = OS.get_cmdline_user_args()
	if ids.is_empty():
		ids = PerfilDeFrutas.frutas_so_do_mod()
	print("SK_INICIO mira=%s frutas=%d nos=%d" % [mira, ids.size(), int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	for id in ids:
		modo.equipar_fruta(j, "")
		await quadros(5)
		modo.equipar_fruta(j, id)
		await quadros(15)
		var c = j.get_node_or_null("FrutaMinePiece")
		if c == null or not c.fruta_ativa():
			print("SK %s NAO_EQUIPOU" % id)
			continue
		var lista: Array = c.estado_das_tecnicas()
		for i in mini(lista.size(), 6):
			var letra: String = ["Z", "X", "C", "V", "B", "N"][i]
			c = j.get_node_or_null("FrutaMinePiece")
			if not is_instance_valid(c) or not c.fruta_ativa():
				break
			McEntidade.de(j).removeAllEffects()
			j.energy = j.max_energy
			j.global_position = inicio
			j.velocity = Vector3.ZERO
			j._pitch = pitch
			await quadros(20)                        # assenta: relevo refeito, entulho da técnica anterior some
			var nos0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			var tempos: Array = []
			var cortada := false
			# O ganho de XP (matar animal com a técnica) re-equipa a fruta da PROGRESSÃO e LIBERA o controlador que este medidor equipou fora dela:
			# buscar de novo antes de cada chamada e conferir (o jogo real também busca a cada tecla; ver docs/DESEMPENHO_SKILLS_NO_CHAO_2026-11-11.md).
			c = j.get_node_or_null("FrutaMinePiece")
			if not is_instance_valid(c):
				continue
			c.usar_tecla(letra, true)
			for q in SEGURAR + SOLTA:
				if q == SEGURAR:
					c = j.get_node_or_null("FrutaMinePiece")
					if is_instance_valid(c):
						c.usar_tecla(letra, false)
				var t0 := Time.get_ticks_usec()
				await physics_frame
				tempos.append((Time.get_ticks_usec() - t0) / 1000.0)
				if (int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nos0) > 6000 or tempos[-1] > 4000.0:
					cortada = true
					break
			c = j.get_node_or_null("FrutaMinePiece")
			if is_instance_valid(c):
				c.usar_tecla(letra, false)
			var ord := tempos.duplicate()
			ord.sort()
			var soma := 0.0
			for t in tempos:
				soma += t
			var r := {"fruta": id, "tecla": letra, "nome": str(lista[i].nome), "pior": ord[-1], "media": soma / tempos.size(),
				"p95": ord[int(ord.size() * 0.95)], "nos": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)) - nos0, "cortada": cortada}
			resultados.append(r)
			print("SK %s %s %s pior=%.0fms media=%.1fms p95=%.0fms nos%+d%s" % [id, letra, r.nome, r.pior, r.media, r.p95, r.nos, " CORTADA" if cortada else ""])
	resultados.sort_custom(func(a, b): return a.pior > b.pior)
	print("\nSK_RESUMO piores 15 (mira=%s):" % mira)
	for r in resultados.slice(0, 15):
		print("  %-28s %s %-30s pior=%4.0fms media=%5.1fms p95=%4.0fms nos%+d" % [r.fruta, r.tecla, r.nome, r.pior, r.media, r.p95, r.nos])
	quit()
