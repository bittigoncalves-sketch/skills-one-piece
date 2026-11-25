extends LojaDeNpc
# ============================================================================
#  ORGANIZADOR DA CORRIDA — a "loja" que inscreve na corrida de caranguejos (06/10/2026).
#
#  Pedido do dono: "adicionar um npc para iniciar a corrida; o prêmio será 10 moedas;
#  a requisição para participar é ter um caranguejo". Não vende nada: uma linha com a
#  regra e o botão Correr (apagado, com o motivo, quando não dá). Quem corre é a
#  `CorridaDeCaranguejos` da cena; ao largar, a janela fecha.
# ============================================================================

var _fechar := false


func fala() -> String:
	return "Corrida de caranguejos! Uma volta na pista grande: quem completar em até 5 minutos leva %s." \
		% LojaDeNpc.moedas(CorridaDeCaranguejos.PREMIO)


func linhas(_progressao: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var corrida := _corrida()
	var motivo := corrida.motivo_para_nao_correr() if corrida != null else "A corrida não está pronta."
	var detalhe := "Prêmio: %s ao completar em até 5:00  ·  exige um caranguejo  ·  não dá para descer até o fim" \
		% LojaDeNpc.moedas(CorridaDeCaranguejos.PREMIO)
	if not motivo.is_empty():
		detalhe += "\n" + motivo
	return [LojaDeNpc.linha("corrida", "Corrida de caranguejos", detalhe, [LojaDeNpc.botao("Correr", "correr", motivo.is_empty())])]


func executar(_progressao: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, _id: String) -> String:
	_fechar = false
	if acao != "correr":
		return ""
	var corrida := _corrida()
	if corrida == null:
		return "A corrida não está pronta."
	var r := corrida.pedir_largada()
	_fechar = r.is_empty()
	return "Valendo! Não dá para descer do caranguejo até o fim da corrida." if r.is_empty() else r


func fecha_a_janela() -> bool:
	return _fechar


static func _corrida() -> CorridaDeCaranguejos:
	var arvore := Engine.get_main_loop() as SceneTree
	return arvore.get_first_node_in_group("corrida_de_caranguejos") as CorridaDeCaranguejos if arvore != null else null
