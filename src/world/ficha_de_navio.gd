class_name FichaDeNavio
extends RefCounted
# ============================================================================
#  FICHA DE NAVIO — as propriedades de um barco da loja (30/09/2026).
#
#  Pedido do dono: separar todos os navios numa classificação "onde serão feitas as
#  propriedades dos barcos", já com uma ficha inicial. A classificação é a categoria
#  `navios` da loja; a ficha mora no próprio catálogo (`mapas/modelos/catalogo.json`,
#  campo "navio" do modelo), ao lado do nome e das medidas — um lugar só por barco.
#
#  Ainda NÃO existe navegação: nada no jogo lê estes números por enquanto. Eles são o
#  ponto de partida do balanceamento, por CLASSE, e cada barco pode ter os seus.
#  Unidades: metros, m/s, graus por segundo; vida em pontos (a do jogador é 2048 na
#  arena e 20+ no Modo História); carga em "volumes" (unidade de inventário, a definir
#  com a pesca/comércio).
#
#  GATILHO: quando a navegação começar, esta ficha passa a ser lida por ela — revisar
#  as unidades de carga e se `vida` vira casco + velas.
# ============================================================================

## Campos da ficha, na ordem em que aparecem (loja, arquivo).
const CAMPOS: Array[String] = ["classe", "comprimento", "velocidade", "curva", "vida",
	"tripulacao", "carga", "canhoes"]

## Valores de partida por classe. `comprimento` também decide o TAMANHO PADRÃO do
## modelo na loja (o barco é escalado para ter esse comprimento).
const CLASSES := {
	"bote": {"nome": "Bote", "comprimento": 6.0, "velocidade": 5.0, "curva": 70.0,
		"vida": 150, "tripulacao": 2, "carga": 2, "canhoes": 0},
	"chalupa": {"nome": "Chalupa", "comprimento": 12.0, "velocidade": 8.0, "curva": 45.0,
		"vida": 400, "tripulacao": 6, "carga": 10, "canhoes": 2},
	"barco_casa": {"nome": "Barco-casa", "comprimento": 18.0, "velocidade": 3.5, "curva": 25.0,
		"vida": 900, "tripulacao": 8, "carga": 30, "canhoes": 0},
	"galeao": {"nome": "Galeão", "comprimento": 32.0, "velocidade": 6.5, "curva": 20.0,
		"vida": 1500, "tripulacao": 30, "carga": 60, "canhoes": 12},
}

const LIMITES := {
	"comprimento": [1.0, 200.0], "velocidade": [0.0, 60.0], "curva": [1.0, 360.0],
	"vida": [1, 100000], "tripulacao": [1, 500], "carga": [0, 10000], "canhoes": [0, 200],
}


## Ficha nova com os valores da classe.
static func da_classe(classe: String) -> Dictionary:
	var base: Dictionary = CLASSES[classe]
	var ficha := {"classe": classe}
	for campo in CAMPOS:
		if campo != "classe":
			ficha[campo] = base[campo]
	return ficha


## Valida e normaliza o que veio do catálogo. {} = sem ficha (ou ficha inválida:
## um número fora do limite não pode virar barco com vida negativa no jogo).
static func normalizar(bruto: Variant) -> Dictionary:
	if not (bruto is Dictionary):
		return {}
	var d: Dictionary = bruto
	var classe := str(d.get("classe", ""))
	if not CLASSES.has(classe):
		return {}
	var ficha := da_classe(classe)
	for campo in LIMITES:
		if not d.has(campo):
			continue
		var v: Variant = d[campo]
		if not ((v is float and is_finite(v)) or v is int):
			return {}
		var faixa: Array = LIMITES[campo]
		if float(v) < float(faixa[0]) or float(v) > float(faixa[1]):
			return {}
		ficha[campo] = float(v) if faixa[0] is float else int(v)
	return ficha


## Uma linha legível (dica da loja, painel do editor).
static func resumo(ficha: Dictionary) -> String:
	if ficha.is_empty():
		return ""
	return "%s · %.0f m · %.1f m/s · curva %.0f°/s · vida %d · tripulação %d · carga %d · canhões %d" % [
		CLASSES[ficha["classe"]]["nome"], ficha["comprimento"], ficha["velocidade"], ficha["curva"],
		ficha["vida"], ficha["tripulacao"], ficha["carga"], ficha["canhoes"]]
