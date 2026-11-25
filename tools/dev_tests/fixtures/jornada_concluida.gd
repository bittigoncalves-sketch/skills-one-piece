extends RefCounted
## Fixture para regressões posteriores ao tutorial; a sequência real é testada em
## test_sobrevivencia_jornada e test_sobrevivencia_integracao.
static func preparar(p: ProgressaoDoPersonagem) -> void:
	var tabela := preload("res://src/historia/missoes/missoes.gd")
	for id in ["vara_inicial", "peixe_raro", "ferraria", "faccao_inicial"]:
		p.missoes[id] = {"estado": "entregue", "abates": int(tabela.dados(id).meta)}
	p.equipamentos["vara_de_pesca"] = true
	p.sistemas["faccao"] = {"id":"pirata"}
	p.mudou.emit()
