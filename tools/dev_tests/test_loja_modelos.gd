extends SceneTree
# ============================================================================
#  TESTE DA LOJA DE MODELOS (.glb) do editor de mapa.
#
#  A. o importador recusa o que não deve entrar, dizendo o motivo;
#  B. importar copia, não duplica o mesmo conteúdo, persiste no catálogo,
#     renomeia, e o catálogo não aceita caminho fora da pasta;
#  C. a peça `modelo` no mapa: esticada para a caixa, centralizada, com colisão
#     de malha; modelo ausente vira marcador rosa em vez de quebrar o mapa;
#  D. a loja dentro do editor, com mouse de verdade: busca, clique insere,
#     arrastar solta no ponto do mapa, soltar em painel não insere, apagar da
#     loja transforma as peças em marcador.
#
#  Tudo acontece em `user://test_loja/` — a loja do projeto não é tocada.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_loja_modelos.gd
# ============================================================================

const RAIZ := "user://test_loja/modelos"
const TEMP := "user://test_loja/origem"
const CHAPEU := "res://assets/models/acessorios/chapeu_palha.glb"
const ARVORE := "res://assets/models/arvore_voxel.glb"

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== LOJA DE MODELOS =====")
	_limpar()
	DirAccess.make_dir_recursive_absolute(_os(TEMP))
	_verificacao()
	var bib := _importacao()
	_montagem(bib)
	_categorias(bib)
	_catalogo_real_antigo()
	await _loja_no_editor(bib)
	MapaMontador.biblioteca = null
	_limpar()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


# ------------------------------------------------------------- A. verificação
func _verificacao() -> void:
	print("\n-- A. o que o importador recusa --")
	var bom := ImportadorDeModelos.verificar(_os(CHAPEU))
	_ok(bom["ok"], "o chapéu de palha (.glb real do projeto) passa %s" % bom["erro"])
	_recusa(ImportadorDeModelos.verificar(_copia(CHAPEU, "chapeu.gltf")), "não é .glb", "extensão errada")
	_recusa(ImportadorDeModelos.verificar(_os(TEMP.path_join("sumiu.glb"))), "não existe", "arquivo inexistente")
	_recusa(ImportadorDeModelos.verificar(_escrever("lixo.glb", "isto nao e um modelo 3d".to_utf8_buffer())), "cabeçalho", "bytes que não são glTF")
	var inteiro := FileAccess.get_file_as_bytes(CHAPEU)
	_recusa(ImportadorDeModelos.verificar(_escrever("cortado.glb", inteiro.slice(0, 200))), "truncado", "arquivo cortado no meio")
	_recusa(ImportadorDeModelos.verificar(_os(CHAPEU), 1000), "teto", "acima do teto de tamanho")
	var externo := _glb_minimo({"asset": {"version": "2.0"}, "buffers": [{"uri": "textura.bin", "byteLength": 4}]})
	_recusa(ImportadorDeModelos.verificar(_escrever("externo.glb", externo)), "externos", "glb que aponta para arquivo de fora")
	var vazio := _glb_minimo({"asset": {"version": "2.0"}})
	var bib_vazia := BibliotecaDeModelos.new(RAIZ + "_vazia")
	var r := ImportadorDeModelos.importar(bib_vazia, _escrever("sem_malha.glb", vazio))
	_ok(not r["ok"] and (r["erro"] as String).contains("malha"), "glb válido sem malha é recusado → %s" % r["erro"])
	_ok(bib_vazia.ids().is_empty() and not DirAccess.dir_exists_absolute(_os(RAIZ + "_vazia")), "nada recusado deixa arquivo na loja")


# -------------------------------------------------------------- B. importação
func _importacao() -> BibliotecaDeModelos:
	print("\n-- B. importar, repetir, persistir, renomear --")
	var bib := BibliotecaDeModelos.new(RAIZ)
	var r := ImportadorDeModelos.importar(bib, _os(CHAPEU))
	_ok(r["ok"] and r["id"] == "chapeu_palha" and not r["repetido"], "importa o chapéu como \"chapeu_palha\" %s" % r["erro"])
	_ok(FileAccess.file_exists(RAIZ.path_join("chapeu_palha.glb"))
		and FileAccess.get_sha256(RAIZ.path_join("chapeu_palha.glb")) == FileAccess.get_sha256(CHAPEU),
		"a cópia está na loja com o mesmo conteúdo do original")
	var e := bib.info("chapeu_palha")
	_ok(e["triangulos"] == 36 and (e["tamanho"] as Vector3).x > 0.0, "mediu o modelo: 36 triângulos, caixa %s" % e["tamanho"])

	var de_novo := ImportadorDeModelos.importar(bib, _copia(CHAPEU, "outro_nome.glb"))
	_ok(de_novo["ok"] and de_novo["repetido"] and de_novo["id"] == "chapeu_palha" and bib.ids().size() == 1,
		"o mesmo conteúdo com outro nome não duplica")
	var arvore := ImportadorDeModelos.importar(bib, _os(ARVORE))
	_ok(arvore["ok"] and bib.ids() == ["chapeu_palha", "arvore_voxel"], "importa a segunda (árvore)")

	var relida := BibliotecaDeModelos.new(RAIZ)
	_ok(relida.ids() == bib.ids() and relida.info("arvore_voxel")["tamanho"] == bib.info("arvore_voxel")["tamanho"],
		"o catálogo relido de disco tem os mesmos 2 modelos e medidas")
	_ok(bib.renomear("chapeu_palha", "Chapéu do Luffy").is_empty()
		and BibliotecaDeModelos.new(RAIZ).info("chapeu_palha")["nome"] == "Chapéu do Luffy", "renomear troca só o nome exibido e persiste")
	_ok(not bib.renomear("chapeu_palha", "   ").is_empty(), "nome vazio é recusado")
	_ok(bib.novo_id("Árvore Grande!.glb") == "rvore_grande" or bib.novo_id("Árvore Grande!.glb").begins_with("rvore"),
		"id de arquivo com acento e espaço vira só A-Z 0-9 _ (%s)" % bib.novo_id("Árvore Grande!.glb"))

	var pasta := TEMP.path_join("pasta")
	DirAccess.make_dir_recursive_absolute(_os(pasta.path_join("sub")))
	DirAccess.copy_absolute(_os(CHAPEU), _os(pasta.path_join("b.glb")))
	DirAccess.copy_absolute(_os(ARVORE), _os(pasta.path_join("a.GLB")))
	DirAccess.copy_absolute(_os(CHAPEU), _os(pasta.path_join("sub/c.glb")))
	var f := FileAccess.open(pasta.path_join("leia.txt"), FileAccess.WRITE)
	f.store_string("x")
	f.close()
	var achados := ImportadorDeModelos.glbs_da_pasta(_os(pasta))
	_ok(achados.size() == 2 and achados[0].ends_with("a.GLB"), "importar pasta pega os 2 .glb de dentro, sem subpasta nem .txt")

	# Catálogo editado à mão tentando sair da pasta.
	var catalogo := FileAccess.get_file_as_string(RAIZ.path_join(BibliotecaDeModelos.ARQUIVO_CATALOGO))
	var invasor := RAIZ + "_invasor"
	DirAccess.make_dir_recursive_absolute(_os(invasor))
	var g := FileAccess.open(invasor.path_join(BibliotecaDeModelos.ARQUIVO_CATALOGO), FileAccess.WRITE)
	g.store_string(catalogo.replace("\"arquivo\": \"arvore_voxel.glb\"", "\"arquivo\": \"../../segredo.glb\""))
	g.close()
	var com_invasor := BibliotecaDeModelos.new(invasor)
	_ok(com_invasor.ids() == ["chapeu_palha"], "entrada de catálogo apontando para fora da pasta é ignorada")
	return bib


# ---------------------------------------------------------------- C. montagem
func _montagem(bib: BibliotecaDeModelos) -> void:
	print("\n-- C. peça modelo no mapa --")
	MapaMontador.biblioteca = bib
	var original: Vector3 = bib.info("arvore_voxel")["tamanho"]
	var pedido := original * Vector3(2, 1, 2)
	var mapa := {"formato": MapaArquivo.FORMATO, "versao": 1, "nome": "t", "spawn": {"posicao": [0, 1, 0]},
		"pecas": [
			{"id": "arvore", "tipo": "modelo", "modelo": "arvore_voxel", "posicao": [5, 3, 0],
				"tamanho": [pedido.x, pedido.y, pedido.z]},
			{"id": "sumido", "tipo": "modelo", "modelo": "nao_existe", "posicao": [0, 1, 0], "tamanho": [1, 2, 3]},
		]}
	var lido := MapaArquivo.validar(mapa)
	_ok(lido["ok"], "mapa com peças modelo é válido %s" % str(lido["erros"]))
	var sem_id := mapa.duplicate(true)
	sem_id["pecas"][0].erase("modelo")
	_ok(not MapaArquivo.validar(sem_id)["ok"], "peça modelo sem id da loja é recusada")
	if not lido["ok"]:
		return
	var relido := MapaArquivo.ler_texto(MapaArquivo.para_texto(lido["mapa"]))
	_ok(relido["ok"] and relido["mapa"] == lido["mapa"], "o campo \"modelo\" sobrevive a gravar e ler")

	var raiz := Node3D.new()
	get_root().add_child(raiz)
	MapaMontador.montar(raiz, lido["mapa"])
	var corpo := raiz.get_node("Mapa/arvore") as Node3D
	var modelo := corpo.get_node_or_null("Modelo") as Node3D
	_ok(modelo != null and modelo.scale.is_equal_approx(Vector3(2, 1, 2)), "o modelo foi esticado 2× em X e Z (%s)" % (modelo.scale if modelo else null))
	var caixa := _caixa_global(modelo)
	_ok(caixa.size.is_equal_approx(pedido) and caixa.get_center().is_equal_approx(Vector3(5, 3, 0)),
		"a caixa desenhada tem o tamanho pedido e o centro na posição da peça (%s, %s)" % [caixa.size, caixa.get_center()])
	var colisao := corpo.get_node("Colisao") as CollisionShape3D
	_ok(colisao.shape is ConcavePolygonShape3D and (colisao.shape as ConcavePolygonShape3D).get_faces().size() == bib.info("arvore_voxel")["triangulos"] * 3,
		"colisão de malha com os %d triângulos do modelo" % bib.info("arvore_voxel")["triangulos"])
	var sumido := raiz.get_node("Mapa/sumido") as Node3D
	_ok(sumido.get_node("Modelo").get_meta("marcador", false) and (sumido.get_node("Colisao") as CollisionShape3D).shape is BoxShape3D,
		"modelo que não está na loja vira marcador com colisão de caixa (o mapa abre)")
	raiz.free()


# ------------------------------------------------------------- E. categorias
func _categorias(bib: BibliotecaDeModelos) -> void:
	print("\n-- E. categorias (etiquetas) --")
	var animal := bib.criar_categoria("Animal")
	var inimigo := bib.criar_categoria("Inimigo")
	_ok(animal["ok"] and inimigo["ok"] and bib.categorias().size() == 2, "cria as categorias Animal e Inimigo (%s, %s)" % [animal["id"], inimigo["id"]])
	_ok(not bib.criar_categoria("animal")["ok"], "nome repetido (ignorando maiúscula) é recusado")
	_ok(not bib.criar_categoria("   ")["ok"], "nome vazio é recusado")
	var os_dois: Array[String] = ["chapeu_palha", "arvore_voxel"]
	bib.marcar_categoria(os_dois, animal["id"], true)
	var so_arvore: Array[String] = ["arvore_voxel"]
	bib.marcar_categoria(so_arvore, inimigo["id"], true)
	_ok(bib.categorias_do_modelo("arvore_voxel") == [animal["id"], inimigo["id"]], "um modelo pode ter VÁRIAS categorias")
	_ok(bib.contar_na_categoria(animal["id"]) == 2 and bib.contar_na_categoria(inimigo["id"]) == 1 and bib.contar_na_categoria("") == 0,
		"contagem por categoria e \"sem categoria\"")
	var relida := BibliotecaDeModelos.new(RAIZ)
	_ok(relida.categorias().size() == 2 and relida.categorias_do_modelo("arvore_voxel").size() == 2, "categorias persistem no catálogo")
	_ok(bib.renomear_categoria(inimigo["id"], "Inimigos").is_empty() and bib.nome_da_categoria(inimigo["id"]) == "Inimigos",
		"renomear categoria troca só o nome (o id fica)")
	bib.marcar_categoria(so_arvore, inimigo["id"], false)
	_ok(bib.categorias_do_modelo("arvore_voxel") == [animal["id"]], "tirar um modelo da categoria")
	var extra := bib.criar_categoria("Temporária")
	bib.marcar_categoria(os_dois, extra["id"], true)
	bib.apagar_categoria(extra["id"])
	_ok(not bib.tem_categoria(extra["id"]) and bib.ids().size() == 2 and not bib.categorias_do_modelo("chapeu_palha").has(extra["id"]),
		"apagar categoria tira a etiqueta e mantém os modelos")


# O catálogo que o dono já tem (263 modelos em 16/09/2026) não tinha categorias.
# Copiado para user://, lido e regravado: nenhum modelo pode se perder.
func _catalogo_real_antigo() -> void:
	print("\n-- E2. catálogo real, formato antigo --")
	var real := "res://mapas/modelos/catalogo.json"
	if not FileAccess.file_exists(real):
		print("     (projeto sem catálogo real — pulado)")
		return
	var copia := "user://test_loja/catalogo_real"
	DirAccess.make_dir_recursive_absolute(_os(copia))
	DirAccess.copy_absolute(_os(real), _os(copia.path_join(BibliotecaDeModelos.ARQUIVO_CATALOGO)))
	var antes: Array = JSON.parse_string(FileAccess.get_file_as_string(real))["modelos"]
	var bib := BibliotecaDeModelos.new(copia)
	_ok(bib.ids().size() == antes.size(), "abre os %d modelos do catálogo real sem categorias" % antes.size())
	bib.criar_categoria("Teste")
	var relida := BibliotecaDeModelos.new(copia)
	var mesmas := relida.ids().size() == antes.size()
	for m in antes:
		if not relida.tem(m["id"]) or relida.info(m["id"])["sha256"] != m["sha256"]:
			mesmas = false
	_ok(mesmas, "regravado com categoria nova, continua com os mesmos %d modelos e SHAs" % antes.size())


# ------------------------------------------------------- D. loja no editor
func _loja_no_editor(bib: BibliotecaDeModelos) -> void:
	print("\n-- D. a loja dentro do editor --")
	var mapa := "user://test_loja/mapa.json"
	DirAccess.copy_absolute(_os("res://tools/dev_tests/fixtures/mapa_baseplate.json"), _os(mapa))
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = mapa
	ed.biblioteca = bib
	get_root().add_child(ed)
	current_scene = ed
	await _quadros(8)
	var loja: LojaDoEditor = ed._loja
	var cam: CameraLivre = ed._camera
	cam.posicionar(Vector3(0, 14, 16), Vector3(0, 0, 0))
	await _quadros(3)
	_ok(loja.quantidade_visivel() == 2, "a loja lista os 2 modelos importados")
	_ok(loja.get_global_rect().position.x < 20 and loja.get_global_rect().end.x < get_root().get_visible_rect().size.x * 0.3,
		"a loja fica no lado esquerdo da tela (%s)" % loja.get_global_rect())
	loja._busca.text = "árvore"
	loja._busca.text_changed.emit("árvore")
	_ok(loja.quantidade_visivel() == 0, "busca sem acerto esvazia a lista")
	loja._busca.text = "arvore"
	loja._busca.text_changed.emit("arvore")
	_ok(loja.quantidade_visivel() == 1 and loja.id_do_indice(0) == "arvore_voxel", "buscar \"arvore\" deixa só a árvore (acha pelo id)")
	loja._busca.text = ""
	loja._busca.text_changed.emit("")
	# ⚠️ O ItemList só recalcula a posição dos itens no quadro seguinte: medir o
	# item logo depois de reconstruir a lista dá um retângulo velho e o clique cai
	# fora dele (foi o que este teste pegou na primeira rodada).
	await _quadros(2)

	var doc: DocumentoMapa = ed.doc
	var item := _centro_do_item(loja, 0)
	await _clicar(item)
	var inseridos := doc.ids().filter(func(i): return doc.peca(i)["tipo"] == "modelo")
	_ok(inseridos.size() == 1 and doc.peca(inseridos[0])["modelo"] == "chapeu_palha" and ed.selecao.ids() == [inseridos[0]],
		"clique na loja insere o modelo e já seleciona (%s)" % str(inseridos))

	var alvo := cam.unproject_position(Vector3(6, 0, -3))
	await _arrastar(item, alvo)
	var depois := doc.ids().filter(func(i): return doc.peca(i)["tipo"] == "modelo")
	_ok(depois.size() == 2, "arrastar da loja para o mapa insere mais um")
	if depois.size() == 2:
		var p := doc.peca(depois[1])
		var altura: float = (p["tamanho"] as Vector3).y
		_ok(is_equal_approx(p["posicao"].x, 6.0) and is_equal_approx(p["posicao"].z, -3.0) and is_equal_approx(p["posicao"].y, altura * 0.5),
			"soltou no ponto do mapa, pousado no chão (%s, altura %.3f)" % [p["posicao"], altura])
	await _arrastar(item, ed._interface.get_node("Lateral").get_global_rect().get_center())
	_ok(doc.ids().filter(func(i): return doc.peca(i)["tipo"] == "modelo").size() == 2 and ed._status.text.contains("não sobre um painel"),
		"soltar em cima de um painel não insere e explica")

	var um: String = depois[0]
	ed.selecao.definir([um] as Array[String])
	await _quadros(1)
	var campos: Dictionary = ed._propriedades._campos
	_ok(not campos.has("tipo") and not campos.has("cor") and campos.has("tamanho") and campos.has("colisao"),
		"Propriedades de modelo: sem forma/cor/material, com tamanho e colisão")
	ed._propriedades.alterar_pedido.emit("tamanho", (bib.info("chapeu_palha")["tamanho"] as Vector3) * 3.0)
	var modelo := ed.get_node("Vista/Mapa/%s/Modelo" % um) as Node3D
	_ok(modelo.scale.is_equal_approx(Vector3(3, 3, 3)), "mudar o tamanho estica o modelo na cena (%s)" % modelo.scale)
	_ok(ed.salvar() == OK and MapaArquivo.carregar(mapa)["mapa"]["pecas"].any(func(pp): return pp.get("modelo", "") == "chapeu_palha"),
		"salvar grava as peças modelo no arquivo do mapa")

	# Categorias na interface da loja.
	loja.filtrar(bib.categorias()[0]["id"])
	await _quadros(2)
	_ok(loja.quantidade_visivel() == 2, "filtrar por Animal mostra os 2 modelos dela")
	loja.filtrar(LojaDoEditor.FILTRO_SEM)
	await _quadros(2)
	_ok(loja.quantidade_visivel() == 0, "\"Sem categoria\" fica vazio quando todos têm")
	loja.filtrar(LojaDoEditor.FILTRO_TODAS)
	await _quadros(2)
	var pecas_antes := doc.quantidade()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.ctrl_pressed = true
	for i in 2:
		ev.position = _centro_do_item(loja, i)
		ev.global_position = ev.position
		for apertado in [true, false]:
			var e := ev.duplicate() as InputEventMouseButton
			e.pressed = apertado
			get_root().push_input(e, true)
			await process_frame
	await _quadros(2)
	_ok(doc.quantidade() == pecas_antes and loja.ids_selecionados().size() == 2, "Ctrl+clique seleciona 2 modelos SEM inserir no mapa")
	var nova := bib.criar_categoria("Cenário")
	loja.marcar(loja.ids_selecionados(), nova["id"], true)
	_ok(bib.contar_na_categoria(nova["id"]) == 2, "marcar categoria nos 2 selecionados de uma vez")
	loja._alvos_do_menu = loja.ids_selecionados()
	loja._montar_submenu_categorias()
	var sub: PopupMenu = loja._submenu_categorias
	var i_cenario := sub.get_item_index(bib.categorias().size() - 1)
	_ok(sub.is_item_checkable(i_cenario) and sub.is_item_checked(i_cenario), "o submenu mostra \"Cenário\" marcada para a seleção")

	_ok(loja.contar_uso.call("chapeu_palha") == 2, "a loja sabe que 2 peças usam o chapéu antes de apagar")
	loja.apagar("chapeu_palha")
	await _quadros(1)
	var agora := ed.get_node("Vista/Mapa/%s/Modelo" % um) as Node3D
	_ok(not bib.tem("chapeu_palha") and not FileAccess.file_exists(RAIZ.path_join("chapeu_palha.glb")) and loja.quantidade_visivel() == 1,
		"apagar da loja remove o arquivo e a entrada")
	_ok(agora != null and agora.get_meta("marcador", false), "as peças que usavam viram marcador na hora, sem reabrir")
	# A foto pode já existir no cache de uma sessão com tela (é por SHA, vale para
	# qualquer biblioteca). O que se prova é que sem tela nenhuma foto NOVA é gerada.
	var foto: String = ed._miniaturas.caminho_da_foto("arvore_voxel")
	DirAccess.remove_absolute(_os(foto))
	ed._miniaturas._texturas.clear()
	ed._miniaturas.pedir("arvore_voxel")
	await _quadros(4)
	_ok(ed._miniaturas.sem_tela() and not FileAccess.file_exists(foto) and loja.quantidade_visivel() == 1,
		"sem tela, pedir miniatura não gera foto e a loja segue funcionando")
	ed.queue_free()
	await _quadros(2)


# ------------------------------------------------------------------ apoio
func _recusa(r: Dictionary, palavra: String, caso: String) -> void:
	_ok(not r["ok"] and (r["erro"] as String).contains(palavra), "recusa %s → %s" % [caso, r["erro"]])


func _os(caminho: String) -> String:
	return ProjectSettings.globalize_path(caminho)


func _copia(origem: String, nome: String) -> String:
	var destino := _os(TEMP.path_join(nome))
	DirAccess.copy_absolute(_os(origem), destino)
	return destino


func _escrever(nome: String, bytes: PackedByteArray) -> String:
	var f := FileAccess.open(TEMP.path_join(nome), FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()
	return _os(TEMP.path_join(nome))


## GLB só com o bloco JSON — o suficiente para testar cabeçalho e "uri".
func _glb_minimo(gltf: Dictionary) -> PackedByteArray:
	var json := JSON.stringify(gltf).to_utf8_buffer()
	while json.size() % 4 != 0:
		json.append(0x20)
	var saida := PackedByteArray()
	saida.resize(20)
	saida.encode_u32(0, ImportadorDeModelos.MAGICO_GLTF)
	saida.encode_u32(4, 2)
	saida.encode_u32(8, 20 + json.size())
	saida.encode_u32(12, json.size())
	saida.encode_u32(16, ImportadorDeModelos.CHUNK_JSON)
	saida.append_array(json)
	return saida


func _caixa_global(no: Node3D) -> AABB:
	var caixa := AABB()
	var primeira := true
	for mi in no.find_children("*", "MeshInstance3D", true, false):
		var c := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		caixa = c if primeira else caixa.merge(c)
		primeira = false
	return caixa


func _centro_do_item(loja: LojaDoEditor, i: int) -> Vector2:
	var lista: ItemList = loja._lista
	return lista.get_global_rect().position + lista.get_item_rect(i).get_center()


func _limpar() -> void:
	_apagar_pasta(_os("user://test_loja"))


func _apagar_pasta(caminho: String) -> void:
	var dir := DirAccess.open(caminho)
	if dir == null:
		return
	for sub in dir.get_directories():
		_apagar_pasta(caminho.path_join(sub))
	for arquivo in dir.get_files():
		DirAccess.remove_absolute(caminho.path_join(arquivo))
	DirAccess.remove_absolute(caminho)


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _botao(pos: Vector2, apertado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = apertado
	get_root().push_input(ev, true)


func _mover(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_root().push_input(ev, true)


func _clicar(pos: Vector2) -> void:
	_botao(pos, true)
	await process_frame
	_botao(pos, false)
	await _quadros(2)


func _arrastar(de: Vector2, para: Vector2) -> void:
	_botao(de, true)
	await process_frame
	for i in range(1, 11):
		_mover(de.lerp(para, i / 10.0))
		await process_frame
	_botao(para, false)
	await _quadros(2)
