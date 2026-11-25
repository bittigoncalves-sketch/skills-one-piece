class_name CatalogoDePets
extends RefCounted
# ============================================================================
#  AS ESPÉCIES DE PET DO MODO HISTÓRIA — um lugar só (30/09/2026).
#
#  Quem lê: a progressão (valida o que vem do arquivo salvo), a `Companhia` (monta o
#  corpo) e o inventário N (nome e descrição). Id é o que fica gravado no progresso:
#  não renomear. `cena` é carregada só quando o pet sai do inventário.
#
#  Decisão do dono (30/09/2026): o personagem já começa com as duas no inventário; um
#  vendedor vai vender outras depois.
# ============================================================================

const ESPECIES := {
	"gaivota": {
		"nome": "Gaivota",
		"cena": "res://src/historia/pets/gaivota.gd",
		# Pedido do dono: ela vive por conta própria e só segue quando mandada.
		"modo_inicial": &"livre",
		"descricao": "Voa, pousa e vive por conta própria. Mergulha em quem ameaçar você.",
	},
	"caranguejo": {
		"nome": "Caranguejo grande",
		"cena": "res://src/historia/pets/caranguejo.gd",
		# Era o que ele fazia antes dos modos existirem: seguir o dono.
		"modo_inicial": &"seguir",
		"descricao": "Anda de lado atrás de você e belisca com as pinças.",
	},
}


static func existe(id: String) -> bool:
	return ESPECIES.has(id)


static func ids() -> Array[String]:
	var saida: Array[String] = []
	for id in ESPECIES:
		saida.append(id)
	return saida


static func nome(id: String) -> String:
	return String(ESPECIES[id]["nome"]) if existe(id) else id


static func modo_inicial(id: String) -> StringName:
	return ESPECIES[id]["modo_inicial"] if existe(id) else ModoDoPet.SEGUIR
