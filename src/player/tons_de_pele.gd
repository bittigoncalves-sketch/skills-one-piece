extends RefCounted
## Paleta compartilhada pelo gerador dos atlas, seletor e save.
const PADRAO := "medio"
const CATALOGO := preload("res://assets/textures/skins_historia/tons.json")


static func normalizar(valor: Variant) -> String:
	return valor if valor is String and CATALOGO.data.has(valor) else PADRAO


static func caminho(tipo: String, tom: String) -> String:
	var id := normalizar(tom)
	return "res://assets/textures/skins_historia/" + tipo + ("" if id == PADRAO else "_" + id) + ".svg"
