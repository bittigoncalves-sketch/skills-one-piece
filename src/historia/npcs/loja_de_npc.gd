class_name LojaDeNpc
extends RefCounted
# ============================================================================
#  LOJA DE NPC — o que um NPC compra, vende ou dá (03/10/2026). Só regras: quem
#  desenha é a `JanelaDeLoja`, que pede as `linhas` e chama `executar` no clique.
#
#  A moeda é o OURO da campanha (`ProgressaoDoPersonagem.ouro`). Cada operação passa
#  por uma função tudo-ou-nada da progressão (um `mudou`, um save).
#
#  Uma linha: {id, nome, detalhe, botoes: [{texto, acao, ativo}]}. `executar` devolve
#  o aviso para a HUD ("" = nada a dizer).
# ============================================================================

## Preço padrão das lojas: 1 moeda (decisão do dono, 03/10/2026, "por enquanto").
## GATILHO: preço por item/raridade → coluna na tabela do item, não aqui.
const PRECO := 1


func fala() -> String:
	return ""


func linhas(_progressao: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos) -> Array[Dictionary]:
	return []


func executar(_progressao: ProgressaoDoPersonagem, _bib: BibliotecaDeModelos, _acao: String, _id: String) -> String:
	return ""


## A janela fecha depois do último `executar`? (a corrida de caranguejos, 06/10/2026,
## leva o jogador para longe: a janela não pode ficar aberta por cima da largada).
func fecha_a_janela() -> bool:
	return false


## Quanto a janela cresce para esta loja (1 = o tamanho de sempre).
func escala_da_ui() -> float:
	return 1.0


## Roleta (15/10/2026): o que a última ação sorteou, para a janela animar — `{}` = nada.
## Quem lê chama `consumir_giro` (devolve e zera), para a animação não repetir.
func consumir_giro() -> Dictionary:
	return {}


## Campos opcionais da linha, lidos pela `JanelaDeLoja`: `preco` (-1 = sem etiqueta, 0 =
## "Grátis"), `cor` (o destaque da linha) e `simbolo` (um tipo do `SimboloDeLoja`).
static func linha(id: String, nome: String, detalhe: String, botoes: Array,
		preco := -1, cor := Color.TRANSPARENT, simbolo := "") -> Dictionary:
	return {"id": id, "nome": nome, "detalhe": detalhe, "botoes": botoes,
		"preco": preco, "cor": cor, "simbolo": simbolo}


static func botao(texto: String, acao: String, ativo := true) -> Dictionary:
	return {"texto": texto, "acao": acao, "ativo": ativo}


static func moedas(n: int) -> String:
	return "%d moeda%s" % [n, "" if n == 1 else "s"]
