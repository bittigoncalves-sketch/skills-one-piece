extends LojaDeNpc
## Vendedor de provisões (18/10/2026, pedido do dono): abastece a missão "Provisões para a viagem" (pão e água).
## 18/11/2026 (pedido do dono: "mais tipos de alimentos e um NPC que os vende"): a banca ganhou maçã, peixe, sopa, refeição, carne, leite e suco
## (`Provisoes.VENDIDOS`). O NPC já existia (`npc_comida`, nas ilhas com banca de mercado); ele só vendia pão e água.
const Provisoes := preload("res://src/historia/tripulantes/provisoes.gd")
const VENDE := Provisoes.VENDIDOS
func fala() -> String:
	return "Pão, peixe, carne, sopa, frutas, leite, suco e água para a viagem. Coma e beba pelos slots da barra ou pelo menu B → Provisões."
func linhas(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var r: Array[Dictionary] = []
	var d := Provisoes.estado(prog)
	for id in VENDE:
		var f: Dictionary = Provisoes.ITENS[id]
		r.append(linha(id, f.nome, "+%d fome / +%d sede · estoque %d" % [f.fome, f.sede, int(d.estoque.get(id, 0))], [botao("Comprar 1", "comprar"), botao("Comprar 10", "dez")], int(f.preco)))
	return r
func executar(prog: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, acao: String, id: String) -> String:
	if acao not in ["comprar", "dez"] or id not in VENDE: return ""
	return "Provisões guardadas no B." if Provisoes.comprar(prog, id, 10 if acao == "dez" else 1) else "Moedas insuficientes."
