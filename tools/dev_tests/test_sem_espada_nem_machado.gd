extends SceneTree
## 10/11/2026 (pedido do dono): o jogador não começa com a espada antiga, o machado e as missões de cortar
## madeira saíram do jogo. Save antigo é migrado sem perder o resto do progresso.
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func _init() -> void:
	var M := preload("res://src/historia/missoes/missoes.gd")
	var p := ProgressaoDoPersonagem.new()
	ok(not p.equipamentos.has("espada") and not p.equipamentos.has("machado"), "jogador novo sem espada nem machado")
	ok(not p.itens_da_barra().has("espada") and not p.itens_da_barra().has("machado"), "barra sem espada nem machado")
	ok(not ProgressaoDoPersonagem.ITENS_DA_BARRA.has("machado"), "machado fora dos itens da barra")
	ok(not M.TABELA.has("madeira") and not M.TABELA.has("cortar_arvores"), "missões de madeira fora da tabela")
	ok(M.TABELA.size() == 1 and M.TABELA.has("treino") and not M.TABELA["treino"].has("equipamento"), "a única missão é o treino e não dá equipamento (cadeia da vara retirada em 20/11/2026)")
	for id in M.TABELA:   # nenhuma missão depende de uma que não existe
		var antes := str(M.TABELA[id].get("depois_de", ""))
		ok(antes.is_empty() or M.TABELA.has(antes), "depois_de de %s existe" % id)
	# save antigo: espada e machado equipados, missões de madeira, item ativo = machado
	var antigo := {"formato": ProgressaoDoPersonagem.FORMATO, "versao": 2, "equipamentos": {"espada": true, "machado": true, "vara_de_pesca": true},
		"espada_equipada": true, "machado_equipado": true, "item_ativo": "machado", "madeira": 4,
		"missoes": {"vara_inicial": {"estado": "entregue", "abates": 1}, "ferraria": {"estado": "entregue", "abates": 1},
			"cortar_arvores": {"estado": "aceita", "abates": 1}, "madeira": {"estado": "aceita", "abates": 2}}}
	var q := ProgressaoDoPersonagem.de_dict(antigo)
	ok(not q.equipamentos.has("espada") and not q.equipamentos.has("machado") and q.equipamentos.has("vara_de_pesca"), "save antigo: só a vara fica")
	ok(not q.espada_equipada and not q.machado_equipado and q.item_ativo == "luta", "save antigo: nada equipado, item ativo volta à luta")
	ok(not q.missoes.has("madeira") and not q.missoes.has("cortar_arvores"), "save antigo: missões de madeira descartadas")
	ok(q.madeira == 4, "save antigo: madeira já coletada é preservada")
	print("test_sem_espada_nem_machado: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
