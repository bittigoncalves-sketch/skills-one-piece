extends SceneTree
## Árvore de conquistas: todas as que o jogador faz estão na árvore, cada nó liga a um pai, nada se sobrepõe, a dificuldade vem da moldura, progresso acende.
##   godot --headless --path . --script tools/dev_tests/test_arvore_de_conquistas.gd
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func _initialize() -> void:
	var prog := ProgressaoDoPersonagem.new()
	var janela := JanelaDeConquistas.new()
	root.add_child(janela)
	janela.ligar(prog)
	await process_frame
	await process_frame
	var arv: ArvoreDeConquistas = janela.arvore
	var visiveis := JanelaDeConquistas.visiveis()
	var ids := {}
	for n in arv.nos:
		ids[n.id] = n
	ok(visiveis.size() > 100, "há mais de 100 conquistas visíveis (%d)" % visiveis.size())
	ok(visiveis.all(func(d): return ids.has(d.id)), "toda conquista que o jogador faz está na árvore")
	ok(arv.nos.all(func(n): return n == arv.raiz or n.pai != null), "todo nó tem pai (nada solto)")
	var raizes := arv.raiz.filhos.size()
	ok(raizes >= 3, "o tronco tem as categorias como raízes (%d)" % raizes)
	var minimo := INF
	for i in arv.nos.size():
		for j in range(i + 1, arv.nos.size()):
			minimo = minf(minimo, arv.nos[i].pos.distance_to(arv.nos[j].pos))
	ok(minimo >= 40.0, "nenhum nó sobreposto (distância mínima %.0f)" % minimo)
	ok(arv.nos.all(func(n): return n == arv.raiz or n.pos.y > n.pai.pos.y), "filho sempre abaixo do pai (as raízes descem)")
	var c := arv.contagem()
	var soma := 0
	for nv in c:
		soma += int(c[nv][1])
	ok(soma == visiveis.size() and c["task"][1] > 0 and c["goal"][1] > 0 and c["challenge"][1] > 0, "contagem por dificuldade fecha com o total (%s)" % str(c))
	ok(ArvoreDeConquistas.nivel_de("challenge") == "challenge" and ArvoreDeConquistas.nivel_de("???") == "task", "moldura desconhecida cai em Fácil")
	ok(c["task"][0] == 0, "sem progresso nada está feito")
	var alvo = visiveis[visiveis.size() - 1]
	prog.conquistas_mod[alvo.id] = alvo.criterios.duplicate()
	arv.atualizar()
	ok(arv.contagem()[ArvoreDeConquistas.nivel_de(alvo.moldura)][0] == 1 and ids[alvo.id].feita, "conquista concluída acende na árvore")
	ok(arv.texto_do(arv.raiz) == "MINE PIECE" and arv.texto_do(ids[alvo.id]) != "", "títulos traduzidos e tronco nomeado")
	print("test_arvore_de_conquistas: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
