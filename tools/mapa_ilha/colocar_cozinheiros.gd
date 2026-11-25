extends SceneTree
## Registra os GLBs e coloca exatamente cinco peças, sem mudar outras peças.
## Só executar explicitamente: nunca é chamado pelo jogo ou pelos testes.
const APRESENTACAO = preload("res://src/historia/npcs/exposicao_cozinheiros.gd")
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUP := "res://art_src/backups/cozinheiros"

func _initialize() -> void:
	_executar.call_deferred()

func _executar() -> void:
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("Mapa inválido: " + str(lido["erros"]))
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUP))
	var copia := FileAccess.open(BACKUP.path_join("mapa_%s.json" % original.sha256_text().left(12)), FileAccess.WRITE)
	copia.store_string(original)
	copia.close()
	var catalogo := FileAccess.get_file_as_string("res://mapas/modelos/catalogo.json")
	copia = FileAccess.open(BACKUP.path_join("catalogo_%s.json" % catalogo.sha256_text().left(12)), FileAccess.WRITE)
	copia.store_string(catalogo)
	copia.close()
	var bib := BibliotecaDeModelos.padrao()
	if not bib.tem_categoria("npcs"):
		bib.criar_categoria("NPCs")
	var mapa: Dictionary = lido["mapa"]
	var novas: Array = []
	for id: String in APRESENTACAO.NOMES:
		var caminho := "res://mapas/modelos/%s.glb" % id
		var cena := BibliotecaDeModelos.carregar_glb(caminho)
		if cena == null:
			push_error("GLB ausente ou inválido: " + caminho)
			quit(1)
			return
		var medida := BibliotecaDeModelos.medir(cena)
		var caixa: AABB = medida["aabb"]
		cena.free()
		var erro := bib.adicionar({"id": id, "nome": APRESENTACAO.NOMES[id],
			"centro": caixa.get_center(), "tamanho": caixa.size, "tamanho_padrao": caixa.size,
			"triangulos": (medida["faces"] as PackedVector3Array).size() / 3,
			"sha256": FileAccess.get_sha256(caminho), "categorias": ["npcs"],
			"comportamento": "exposicao_cozinheiro"})
		if erro != OK:
			push_error("Erro no catálogo: " + error_string(erro))
			quit(1)
			return
		# Fileira em frente ao spawn, fora do prédio central e dos NPCs existentes.
		var x := 150.0 + novas.size() * 2.1
		var z := 26.5
		var y := NAN
		for terreno: Dictionary in mapa["pecas"]:
			if terreno["tipo"] != "terreno":
				continue
			var pos: Vector3 = terreno["posicao"]
			var altura := TerrenoDoMapa.altura_local(terreno["relevo"], terreno["tamanho"], x - pos.x, z - pos.z)
			if not is_nan(altura):
				y = pos.y + altura
				break
		if is_nan(y):
			push_error("Cozinheiro fora do terreno: " + id)
			quit(1)
			return
		novas.append({"id": "cidade_" + id, "tipo": "modelo", "modelo": id,
			"posicao": Vector3(x, y + caixa.size.y * 0.5, z),
			"rotacao_graus": Vector3.ZERO, "tamanho": caixa.size, "cor": Color.WHITE,
			"material": "liso", "grade_celula": 4.0, "colisao": true})
		print("COZINHEIRO %s chão=%.3f tamanho=%s" % [id, y, caixa.size])
	var pecas: Array = []
	for p: Dictionary in mapa["pecas"]:
		if not str(p["id"]).begins_with("cidade_cozinheiro_"):
			pecas.append(p)
	pecas.append_array(novas)
	if FileAccess.get_file_as_string(MAPA) != original:
		push_error("Mapa alterado por outra frente; nenhuma peça gravada")
		quit(1)
		return
	mapa["pecas"] = pecas
	var erro := MapaArquivo.salvar(MAPA, mapa)
	print("COZINHEIROS_MAPA ", error_string(erro), " peças=", novas.size())
	quit(0 if erro == OK else 1)
