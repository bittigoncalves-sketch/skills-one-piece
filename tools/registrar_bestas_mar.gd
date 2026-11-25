extends SceneTree
## Registra/reimporta as quatro bestas com IDs estáveis e tamanho nativo.
## godot --headless --path . --script tools/registrar_bestas_mar.gd
## Atualiza clipes e liga a IA marinha; não cria ficha de animal terrestre.

const ORIGEM := "res://mapas/modelos"
const CATEGORIA := "Bestas do mar"
const MODELOS := {
	"besta_mar_bovina": "Besta do mar — Bovina",
	"besta_mar_girafa": "Besta do mar — Girafa",
	"besta_mar_javali": "Besta do mar — Javali",
	"besta_mar_serpente": "Besta do mar — Serpente",
}


func _init() -> void:
	var resultado := registrar(BibliotecaDeModelos.padrao())
	if not resultado["ok"]:
		push_error(resultado["erro"])
	else:
		print("Bestas do mar registradas: ", resultado["ids"])
	quit(0 if resultado["ok"] else 1)


static func registrar(bib: BibliotecaDeModelos, origem: String = ORIGEM) -> Dictionary:
	# Preflight de TODOS os assets antes de tocar no catálogo. O importador normal
	# copiaria para <id>_2 porque os GLBs já estão na pasta final; usamos sua mesma
	# verificação e a medição da biblioteca, com os IDs conhecidos da entrega.
	var entradas: Array[Dictionary] = []
	for id: String in MODELOS:
		var caminho := origem.path_join(id + ".glb")
		var verificacao := ImportadorDeModelos.verificar(caminho)
		if not verificacao["ok"]:
			return _falha("%s: %s" % [id, verificacao["erro"]])
		var cena := BibliotecaDeModelos.carregar_glb(caminho)
		if cena == null:
			return _falha("%s: não foi possível carregar o GLB" % id)
		var medida := BibliotecaDeModelos.medir(cena)
		var esqueletos := cena.find_children("*", "Skeleton3D", true, false)
		var articulado := not esqueletos.is_empty() and (esqueletos[0] as Skeleton3D).get_bone_count() >= 14
		cena.free()
		var caixa: AABB = medida["aabb"]
		if not articulado or medida["malhas"] == 0 or not caixa.size.is_finite() or caixa.size.y < 10.0:
			return _falha("%s: requer malha, esqueleto articulado e escala gigante nativa" % id)
		var entrada := bib.info(id) if bib.tem(id) else {}
		entrada.merge({"id": id, "nome": MODELOS[id], "sha256": FileAccess.get_sha256(caminho),
			"centro": caixa.get_center(), "tamanho": caixa.size,
			"triangulos": medida["triangulos"], "comportamento": "besta_do_mar"}, true)
		entradas.append(entrada)
	var categoria_id := ""
	for categoria in bib.categorias():
		if str(categoria["nome"]).to_lower() == CATEGORIA.to_lower():
			categoria_id = categoria["id"]
			break
	if categoria_id.is_empty():
		var criada := bib.criar_categoria(CATEGORIA)
		if not criada["ok"]:
			return _falha(criada["erro"])
		categoria_id = criada["id"]
	for entrada in entradas:
		var id: String = entrada["id"]
		var categorias: Array = entrada.get("categorias", []).duplicate()
		if not categorias.has(categoria_id):
			categorias.append(categoria_id)
		entrada["categorias"] = categorias
		var fonte := ProjectSettings.globalize_path(origem.path_join(id + ".glb"))
		var destino := ProjectSettings.globalize_path(bib.caminho_do_arquivo(id))
		if fonte != destino:
			var copia := DirAccess.copy_absolute(fonte, destino)
			if copia != OK or FileAccess.get_sha256(destino) != entrada["sha256"]:
				return _falha("%s: falha ao copiar GLB (%s)" % [id, error_string(copia)])
		if bib.tem(id) and bib.info(id) == entrada:
			continue
		var erro := bib.adicionar(entrada)
		if erro != OK:
			return _falha("%s: falha ao gravar catálogo (%s)" % [id, error_string(erro)])
	return {"ok": true, "erro": "", "ids": MODELOS.keys(), "categoria": categoria_id}


static func _falha(erro: String) -> Dictionary:
	return {"ok": false, "erro": erro, "ids": []}
