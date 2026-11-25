extends SceneTree
# ============================================================================
#  PÕE O BANDIDO NA LOJA DO EDITOR, aba "inimigos" (08/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/importar_bandido_na_loja.gd
#
#  Pedido do dono: "adicionar no mapa bandidos com base no dummy que é capaz de lutar";
#  escolha dele: "Base com roupa de bandido". A loja só conhece .glb: a entrada é o
#  `base_v2_runtime.glb` (o mesmo que o rig monta) VESTIDO por `RoupaDeBandido.vestir`
#  (a mesma função que veste o bandido no jogo), exportado e importado pelo caminho do
#  botão da loja, com:
#    • categoria "inimigos" (a do boneco de duelo);
#    • comportamento "bandido" — é o que faz o jogo trocar a peça por um ninho que
#      cria o boneco que luta, vestido de bandido (`NinhoDeInimigo`).
# ============================================================================

const ORIGEM := "res://assets/models/base_v2/base_v2_runtime.glb"
const COMPORTAMENTO := "bandido"
const CATEGORIA := "inimigos"
const RoupaDeBandido := preload("res://src/historia/bandidos/roupa_de_bandido.gd")
const ImportarNpcs := preload("res://tools/importar_npcs_na_loja.gd")


func _init() -> void:
	var r := importar(BibliotecaDeModelos.padrao())
	if not r["ok"]:
		push_error(r["erro"])
	else:
		print(r["mensagem"])
	quit(0 if r["ok"] else 1)


static func importar(bib: BibliotecaDeModelos) -> Dictionary:
	for id in bib.ids():
		if bib.comportamento_do_modelo(id) == COMPORTAMENTO:
			return {"ok": true, "id": id, "erro": "", "mensagem": "já está na loja: %s (\"%s\")" % [id, bib.info(id)["nome"]]}
	if not bib.tem_categoria(CATEGORIA):
		return {"ok": false, "id": "", "erro": "a categoria \"inimigos\" não existe na loja", "mensagem": ""}
	var temporario := OS.get_user_data_dir().path_join("bandido.glb")
	var cena := load(ORIGEM) as PackedScene
	if cena == null:
		return {"ok": false, "id": "", "erro": "sem o modelo Base", "mensagem": ""}
	var raiz := cena.instantiate()
	RoupaDeBandido.vestir(raiz, 0)
	ImportarNpcs._gravar_cores_na_malha(raiz)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var erro := doc.append_from_scene(raiz, estado)
	if erro == OK:
		erro = doc.write_to_filesystem(estado, temporario)
	raiz.free()
	if erro != OK:
		return {"ok": false, "id": "", "erro": "exportar o .glb do bandido falhou (%s)" % error_string(erro), "mensagem": ""}
	var r := ImportadorDeModelos.importar(bib, temporario)
	DirAccess.remove_absolute(temporario)
	if not r["ok"]:
		return {"ok": false, "id": "", "erro": r["erro"], "mensagem": ""}
	var id: String = r["id"]
	bib.renomear(id, "Bandido")
	bib.marcar_categoria([id] as Array[String], CATEGORIA, true)
	bib.definir_comportamento(id, COMPORTAMENTO)
	var info := bib.info(id)
	return {"ok": true, "id": id, "erro": "", "mensagem": "importado: %s  nome=\"%s\"  categorias=%s  comportamento=%s  tamanho=%s" % [
		id, info["nome"], str(info["categorias"]), info["comportamento"], str(info["tamanho"])]}
