class_name CatalogoDeConstrucoes
extends RefCounted
## Quais modelos da biblioteca são CONSTRUÇÕES (08/11/2026, pedido do dono: "dividir as estruturas em pequenos bloquinhos
## que quando interagem com skill ou ataque são destruídos"). Uma regra só, usada pela voxelização
## (tools/voxelizar_construcoes.gd) e pelo jogo (DestruicaoDeEstruturas): modelo que o catálogo não reconhece aqui não vira bloco.
## Entram: categorias "construao" e "estruturas_mine_piece" e, entre os sem categoria, os de nome de prédio (casa, cabana,
## torre, castelo, porto, mercado, moinho...). Ficam fora o que é chão (estrada, campo, terra, rochas, montanha), planta,
## madeira solta e peças pequenas (barril, caixa...) — destruir um barril em cubos é ruído.

const CATEGORIAS := ["construao", "estruturas_mine_piece"]
const NOME_DE_PREDIO := "house|hut|shack|shed|tower|castle|fortress|encampment|temple|windmill|farm|port|dock|market|town_center|coliseu|inn|barracks|stable|sawmill|blacksmith|branch|dojo|tent(_|$)|building|gazebo|wall|monument|wonder|well$|mill"
const NAO_E_PREDIO := "road|field|graveyard|dirt|crops|ranch[0-9]|rock|mountain|tree|trunk|logs|crate|barrel|bench|cart|bonfire|package|hay|saw$|bell|cauldron|tentacle|crossroad"
const CATEGORIAS_FORA := ["navios", "arvores", "floresta", "animais", "pesca", "itens", "npcs", "inimigos", "pets", "frutas",
	"montarias", "bestas_do_mar", "boss", "naufragios", "east_blue_mine_piece"]

static var _predio: RegEx
static var _nao: RegEx


static func e_construcao(id: String, categorias: Array) -> bool:
	for c in categorias:
		if CATEGORIAS_FORA.has(str(c)):
			return false
	if _predio == null:
		_predio = RegEx.create_from_string("(" + NOME_DE_PREDIO + ")")
		_nao = RegEx.create_from_string("(" + NAO_E_PREDIO + ")")
	var nome := id.to_lower()
	if _nao.search(nome) != null:
		return false
	for c in categorias:
		if CATEGORIAS.has(str(c)):
			return true
	return _predio.search(nome) != null


## Ids da biblioteca que são construções.
static func ids(bib: BibliotecaDeModelos) -> Array[String]:
	var saida: Array[String] = []
	for id in bib.ids():
		if e_construcao(id, bib.categorias_do_modelo(id)):
			saida.append(id)
	return saida
