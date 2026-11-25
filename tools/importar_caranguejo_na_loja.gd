extends SceneTree
## Registra/atualiza só o caranguejo, preservando todos os outros modelos e categorias.
const ORIGEM := "res://assets/models/pets/caranguejo_grande.glb"
const ID := "caranguejo_grande"
func _init() -> void:
	var bib := BibliotecaDeModelos.padrao()
	if not bib.tem_categoria("pets"):
		var resultado := bib.criar_categoria("pets")
		if not resultado.ok:
			push_error(str(resultado.erro))
			quit(1)
			return
	var modelo := BibliotecaDeModelos.carregar_glb(ORIGEM)
	if modelo == null:
		quit(1)
		return
	var medidas := BibliotecaDeModelos.medir(modelo)
	modelo.free()
	var erro := DirAccess.copy_absolute(ProjectSettings.globalize_path(ORIGEM), ProjectSettings.globalize_path(bib.caminho_do_arquivo(ID)))
	if erro != OK:
		push_error(error_string(erro))
		quit(1)
		return
	var entrada := {"id": ID, "nome": "Caranguejo grande", "sha256": FileAccess.get_sha256(ORIGEM),
		"centro": (medidas["aabb"] as AABB).get_center(), "tamanho": (medidas["aabb"] as AABB).size, "triangulos": medidas["triangulos"],
		"categorias": ["pets"], "comportamento": "pet_caranguejo"}
	erro = bib.adicionar(entrada)
	print("Caranguejo na loja: ", error_string(erro), "  ", entrada)
	quit(0 if erro == OK else 1)
