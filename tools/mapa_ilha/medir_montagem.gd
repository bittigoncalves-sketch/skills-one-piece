extends SceneTree
# ============================================================================
#  MEDIR MONTAGEM — quanto o `MapaMontador` leva para montar um mapa (30/09/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/medir_montagem.gd -- [mapa.json]
#
#  É a medição do GATILHO declarado no `MapaMontador` (montagem > 100 ms ou > 1.500
#  peças → agrupar estáticas). Monta duas vezes: a 1ª com cache frio (o que o jogador
#  sente ao abrir o Modo História), a 2ª com a biblioteca já carregada (editor que
#  remonta). Separa terreno de modelos e lista os modelos que mais custam.
# ============================================================================


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var caminho := args[0] if not args.is_empty() else "res://mapas/historia/baseplate.json"
	var lido := MapaArquivo.carregar(caminho)
	if not lido["ok"]:
		push_error(str(lido["erros"]).left(300))
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var raiz := Node3D.new()
	root.add_child(raiz)
	var por_modelo := {}
	var mats := {}
	for rodada in 2:
		for c in raiz.get_children():
			c.free()
		var tempos := {"terreno": 0, "modelo": 0, "outros": 0}
		for p in mapa["pecas"]:
			var t := Time.get_ticks_usec()
			MapaMontador.montar_peca(raiz, p, mats)
			var dt := Time.get_ticks_usec() - t
			var tipo: String = p["tipo"] if tempos.has(p["tipo"]) else "outros"
			tempos[tipo] += dt
			if tipo == "modelo" and rodada == 1:
				por_modelo[p["modelo"]] = int(por_modelo.get(p["modelo"], 0)) + dt
		var total: float = (tempos["terreno"] + tempos["modelo"] + tempos["outros"]) / 1000.0
		print("MONTAGEM rodada=%d (%s) pecas=%d total=%.0f ms terreno=%.0f ms modelos=%.0f ms outros=%.0f ms" % [
			rodada, "cache frio" if rodada == 0 else "cache quente", (mapa["pecas"] as Array).size(), total,
			tempos["terreno"] / 1000.0, tempos["modelo"] / 1000.0, tempos["outros"] / 1000.0])
	var lista := por_modelo.keys()
	lista.sort_custom(func(a, b): return por_modelo[a] > por_modelo[b])
	for m in lista.slice(0, 8):
		print("  %-30s %.0f ms" % [m, por_modelo[m] / 1000.0])
	raiz.free()
	quit()
