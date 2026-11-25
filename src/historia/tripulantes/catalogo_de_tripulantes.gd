class_name CatalogoDeTripulantes
extends RefCounted
# ============================================================================
#  OS TRIPULANTES HUMANOS (15/10/2026) — quem se consegue na roleta do Barba Negra.
#
#  Decisão do dono: girar a roleta custa 100 moedas; Nami é COMUM, Crocodile INCOMUM e
#  Barba Negra LENDÁRIO. Só dados e a regra do sorteio; o pagamento e o registro são da
#  `ProgressaoDoPersonagem.recrutar_por_sorteio`, a tela é a `RoletaHud`.
#
#  15/10/2026 (2): Sanji e os quatro cozinheiros da cidade (Beto, Iara, Ravi, Otto) entram na
#  roleta, todos COMUNS — o comum passa a ter 6 nomes, então cada um sai menos que a Nami.
#
#  Os pesos de cada raridade NÃO vieram do dono (ele só definiu as três raridades):
#  70 / 25 / 5 é a escolha inicial, e vive aqui, num lugar só, para ajustar.
#  Sem repetição: quem já foi recrutado sai do sorteio; com todos recrutados a roleta
#  não cobra (a loja desliga o botão).
#
#  `ajuda` = o que o tripulante faz a bordo (15/10/2026, decisão do dono):
#    "navegar"  Nami — diz o rumo da ilha mais próxima;
#    "pistola"  Barba Negra — atira de pistola em qualquer inimigo, de dentro do barco;
#    "areia"    Crocodile — voa em volta do barco (pernas viram areia) e dispara o Z da Suna Suna.
# ============================================================================

const PRECO_DA_ROLETA := 100

const COMUM := &"comum"
const INCOMUM := &"incomum"
const LENDARIO := &"lendario"
const ORDEM_DAS_RARIDADES: Array[StringName] = [COMUM, INCOMUM, LENDARIO]
const RARIDADES := {
	COMUM: {"nome": "Comum", "peso": 70, "cor": Color(0.72, 0.78, 0.84)},
	INCOMUM: {"nome": "Incomum", "peso": 25, "cor": Color(0.35, 0.78, 0.45)},
	LENDARIO: {"nome": "Lendário", "peso": 5, "cor": Color(0.98, 0.72, 0.18)},
}

## `rig` = o personagem do elenco (`CharacterBuilder`) que o representa em 3D; `modelo` = o
## modelo da BIBLIOTECA do mapa (os cozinheiros, com os clipes `descanso` e `caminhada` no GLB).
const TRIPULANTES := {
	"nami": {"nome": "Nami", "raridade": COMUM, "rig": "nami", "ajuda": "navegar",
		"descricao": "Navegadora: aponta o rumo da ilha mais próxima."},
	"sanji": {"nome": "Sanji", "raridade": COMUM, "modelo": "cozinheiro_sanji", "ajuda": "",
		"descricao": "Cozinheiro do bando. Passeia pelo convés."},
	"beto": {"nome": "Beto", "raridade": COMUM, "modelo": "cozinheiro_beto", "ajuda": "",
		"descricao": "Mestre do fogão. Passeia pelo convés."},
	"iara": {"nome": "Iara", "raridade": COMUM, "modelo": "cozinheiro_iara", "ajuda": "",
		"descricao": "Confeiteira. Passeia pelo convés."},
	"ravi": {"nome": "Ravi", "raridade": COMUM, "modelo": "cozinheiro_ravi", "ajuda": "",
		"descricao": "Cozinha do mar. Passeia pelo convés."},
	"otto": {"nome": "Otto", "raridade": COMUM, "modelo": "cozinheiro_otto", "ajuda": "",
		"descricao": "Padeiro. Passeia pelo convés."},
	"crocodile": {"nome": "Crocodile", "raridade": INCOMUM, "rig": "crocodile", "ajuda": "areia",
		"descricao": "Voa em volta do barco, com as pernas em areia, e dispara o Z da Suna Suna."},
	"barba_negra": {"nome": "Barba Negra", "raridade": LENDARIO, "rig": "blackbeard", "ajuda": "pistola",
		"descricao": "Atira de pistola, de dentro do barco, em qualquer inimigo."},
}


static func existe(id: String) -> bool:
	return TRIPULANTES.has(id)


static func ids() -> Array[String]:
	var saida: Array[String] = []
	for id in TRIPULANTES:
		saida.append(id)
	return saida


## O modelo da biblioteca do mapa ("" = o tripulante usa um rig do elenco).
static func modelo_da_biblioteca(id: String) -> String:
	return str(TRIPULANTES[id].get("modelo", "")) if existe(id) else ""


static func nome(id: String) -> String:
	return str(TRIPULANTES[id]["nome"]) if existe(id) else id


static func raridade(id: String) -> StringName:
	return TRIPULANTES[id]["raridade"] if existe(id) else COMUM


static func nome_da_raridade(r: StringName) -> String:
	return str(RARIDADES[r]["nome"]) if RARIDADES.has(r) else str(r)


static func cor_da_raridade(r: StringName) -> Color:
	return RARIDADES[r]["cor"] if RARIDADES.has(r) else Color.WHITE


## O que ainda dá para ganhar: todos menos os já recrutados.
static func restantes(recrutados: Dictionary) -> Array[String]:
	var saida: Array[String] = []
	for id in TRIPULANTES:
		if not recrutados.has(id):
			saida.append(id)
	return saida


## Sorteia um tripulante que ainda não é do jogador (`""` se já tem todos). Primeiro a
## raridade, entre as que ainda têm alguém (pelo peso), depois um dos dela. `rng` vem de
## fora para o teste fixar o resultado.
static func sortear(recrutados: Dictionary, rng: RandomNumberGenerator) -> String:
	var restam := restantes(recrutados)
	if restam.is_empty():
		return ""
	var total := 0
	for r in ORDEM_DAS_RARIDADES:
		if _da_raridade(restam, r).size() > 0:
			total += int(RARIDADES[r]["peso"])
	var ponto := rng.randi_range(0, total - 1)
	for r in ORDEM_DAS_RARIDADES:
		if _da_raridade(restam, r).is_empty():
			continue
		ponto -= int(RARIDADES[r]["peso"])
		if ponto < 0:
			var candidatos := _da_raridade(restam, r)
			return candidatos[rng.randi_range(0, candidatos.size() - 1)]
	return restam[0]


static func _da_raridade(lista: Array[String], r: StringName) -> Array[String]:
	var saida: Array[String] = []
	for id in lista:
		if raridade(id) == r:
			saida.append(id)
	return saida
