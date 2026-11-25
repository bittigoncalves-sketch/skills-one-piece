extends SceneTree
## Registra somente este asset; preserva modelos/categorias existentes.
const ORIGEM := "res://art_src/praia/areia_praia_low_poly.glb"
const ID := "areia_praia_low_poly"

func _initialize() -> void:
	var biblioteca := BibliotecaDeModelos.padrao()
	if not biblioteca.tem_categoria("praia_mapa"):
		var categoria := biblioteca.criar_categoria("praia mapa")
		if not categoria["ok"]:
			push_error(str(categoria))
			quit(1)
			return
	var cena := BibliotecaDeModelos.carregar_glb(ORIGEM)
	if cena == null:
		quit(1)
		return
	var medidas := BibliotecaDeModelos.medir(cena)
	var caixa: AABB = medidas["aabb"]
	cena.free()
	var erro := DirAccess.copy_absolute(ProjectSettings.globalize_path(ORIGEM),
		ProjectSettings.globalize_path(biblioteca.caminho_do_arquivo(ID)))
	if erro != OK:
		push_error(error_string(erro))
		quit(1)
		return
	erro = biblioteca.adicionar({"id": ID, "nome": "Areia de praia — low poly",
		"sha256": FileAccess.get_sha256(ORIGEM), "centro": caixa.get_center(),
		"tamanho": caixa.size, "triangulos": medidas["triangulos"], "categorias": ["praia_mapa"]})
	print("AREIA_IMPORTADA tamanho=", caixa.size, " triangulos=", medidas["triangulos"], " erro=", erro)
	quit(0 if erro == OK else 1)
