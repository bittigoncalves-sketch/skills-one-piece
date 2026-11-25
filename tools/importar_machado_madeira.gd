extends SceneTree
func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	for id in ["machado_lenhador", "tabuas_madeira"]:
		var caminho: String = "res://mapas/modelos/" + id + ".glb"
		var cena := BibliotecaDeModelos.carregar_glb(caminho)
		assert(cena != null)
		var medidas := BibliotecaDeModelos.medir(cena)
		var caixa: AABB = medidas.aabb
		var erro := bib.adicionar({"id": id, "nome": "Machado de lenhador (anime)" if id == "machado_lenhador" else "Tábuas de madeira (anime)", "sha256": FileAccess.get_sha256(caminho), "centro": caixa.get_center(), "tamanho": caixa.size, "triangulos": medidas.triangulos, "categorias": ["itens"]})
		assert(erro == OK)
		bib.definir_tamanho_padrao(id, caixa.size)
		print(id, " triângulos=", medidas.triangulos, " caixa=", caixa)
		cena.free()
	quit()
