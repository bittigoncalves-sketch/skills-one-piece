extends LojaDeNpc
# ============================================================================
#  MESTRE DO GEPPO (18/11/2026) — o macaco-mestre da Ilha dos Macacos, que ensina a técnica Geppo.
#
#  Geppo: chutar o ar. Vários pulos no ar por voo (`ProgressaoDoPersonagem.SALTOS_DO_GEPPO`, recarregam no chão) e dash no ar SEM recarga e sem gastar
#  energia (pedido do dono). Aprende-se uma vez, por `PRECO_DO_GEPPO` moedas. Só regras: o desbloqueio e o preço moram na progressão
#  (`aprender_geppo`); as capacidades que o Player lê saem de `ProgressaoDoPersonagem.capacidades`.
# ============================================================================
const ID := "geppo"
const COR := Color(0.55, 0.85, 0.95)


func fala() -> String:
	return "Uhh-aah! Chutar o ar é coisa de macaco velho. Por %s eu te ensino o Geppo: %d pulos no ar e dash sem esperar." \
		% [moedas(ProgressaoDoPersonagem.PRECO_DO_GEPPO), ProgressaoDoPersonagem.SALTOS_DO_GEPPO]


func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var sabe := bool(prog.desbloqueios["geppo"])
	var detalhe := "%d pulos no ar por voo  ·  dash no ar sem recarga  ·  sem gastar energia" % ProgressaoDoPersonagem.SALTOS_DO_GEPPO
	return [linha(ID, "Técnica Geppo", ("já aprendida  ·  " if sabe else "uma vez só  ·  ") + detalhe,
		[botao("Aprendida" if sabe else "Aprender", "comprar", not sabe and prog.ouro >= ProgressaoDoPersonagem.PRECO_DO_GEPPO)],
		ProgressaoDoPersonagem.PRECO_DO_GEPPO, COR, "pulo")]


func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao != "comprar" or id != ID:
		return ""
	if bool(prog.desbloqueios["geppo"]):
		return "Você já sabe chutar o ar"
	if prog.ouro < ProgressaoDoPersonagem.PRECO_DO_GEPPO:
		return "Sem moedas  ·  o Geppo custa %s" % moedas(ProgressaoDoPersonagem.PRECO_DO_GEPPO)
	return "Geppo aprendido  ·  pule no ar e use Q para dash" if prog.aprender_geppo() else ""
