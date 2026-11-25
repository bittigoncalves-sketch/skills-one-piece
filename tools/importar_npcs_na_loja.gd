extends SceneTree
# ============================================================================
#  PÕE OS NPCs NA LOJA DO EDITOR, na aba "NPCs" (03/10/2026).
#
#  Pedido do dono: o pescador (vara de graça, compra peixe), o domador (vende pets)
#  e o vendedor de frutas (vende Akuma no Mi), no catálogo do editor. Decisão dele:
#  o corpo é o personagem Base do elenco com outra cor. A loja só conhece .glb, então
#  cada entrada é o `base_v2_runtime.glb` (o mesmo que o `PlayerRig` monta) PINTADO
#  por `NpcDaIlha.tingir` com a ficha do NPC (a mesma função que pinta o NPC no
#  jogo), exportado e importado pelo MESMO caminho do botão da loja, mais:
#    • categoria "npcs" (criada se não existir);
#    • comportamento = a chave da ficha (`npc_pescador`…) — é o que faz o jogo
#      trocar a peça pelo NPC vivo (`NpcsDaIlha`), que abre a loja no E.
#
#  Idempotente por NPC: comportamento que já está na loja é pulado.
#
#  Rodar:  godot --headless --path . --script tools/importar_npcs_na_loja.gd
# ============================================================================

const ORIGEM := "res://assets/models/base_v2/base_v2_runtime.glb"
const CATEGORIA := "npcs"
const NOME_CATEGORIA := "NPCs"


func _init() -> void:
	var falhou := false
	for r: Dictionary in importar_todos(BibliotecaDeModelos.padrao()):
		if not r["ok"]:
			push_error(r["erro"])
			falhou = true
		else:
			print(r["mensagem"])
	quit(1 if falhou else 0)


static func importar_todos(bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for tipo: String in NpcDaIlha.FICHAS:
		saida.append(importar(bib, tipo))
	return saida


## Põe o NPC `tipo` em `bib` (a loja do dono, ou a de um teste). {ok, id, erro, mensagem}.
static func importar(bib: BibliotecaDeModelos, tipo: String) -> Dictionary:
	var ficha := NpcDaIlha.ficha(tipo)
	if ficha.is_empty():
		return {"ok": false, "id": "", "erro": "NPC sem ficha: %s" % tipo, "mensagem": ""}
	for id in bib.ids():
		if bib.comportamento_do_modelo(id) == tipo:
			return {"ok": true, "id": id, "erro": "", "mensagem": "já está na loja: %s (\"%s\")" % [id, bib.info(id)["nome"]]}
	if not bib.tem_categoria(CATEGORIA):
		var c := bib.criar_categoria(NOME_CATEGORIA)
		if not c["ok"] or c["id"] != CATEGORIA:
			return {"ok": false, "id": "", "erro": "não deu para criar a categoria %s: %s" % [NOME_CATEGORIA, c["erro"]], "mensagem": ""}
	# Exportado com o nome final antes de importar: o id sai do nome do arquivo.
	var temporario := OS.get_user_data_dir().path_join("%s.glb" % tipo)
	var erro := exportar_pintado(temporario, ficha)
	if erro != OK:
		return {"ok": false, "id": "", "erro": "exportar o .glb pintado falhou (%s)" % error_string(erro), "mensagem": ""}
	var r := ImportadorDeModelos.importar(bib, temporario)
	DirAccess.remove_absolute(temporario)
	if not r["ok"]:
		return {"ok": false, "id": "", "erro": r["erro"], "mensagem": ""}
	var id: String = r["id"]
	bib.renomear(id, str(ficha["nome"]))
	bib.marcar_categoria([id] as Array[String], CATEGORIA, true)
	bib.definir_comportamento(id, tipo)
	var info := bib.info(id)
	return {"ok": true, "id": id, "erro": "", "mensagem": "importado: %s  nome=\"%s\"  categorias=%s  comportamento=%s  tamanho=%s" % [
		id, info["nome"], str(info["categorias"]), info["comportamento"], str(info["tamanho"])]}


## O Base pintado com a `ficha`, gravado como .glb em `destino` (caminho do SO).
static func exportar_pintado(destino: String, ficha: Dictionary) -> Error:
	var cena := load(ORIGEM) as PackedScene
	if cena == null:
		return ERR_FILE_NOT_FOUND
	var raiz := cena.instantiate()
	NpcDaIlha.tingir(raiz, ficha)
	_gravar_cores_na_malha(raiz)
	var doc := GLTFDocument.new()
	var estado := GLTFState.new()
	var erro := doc.append_from_scene(raiz, estado)
	if erro == OK:
		erro = doc.write_to_filesystem(estado, destino)
	raiz.free()
	return erro


## O exportador de glTF lê o material da MALHA: a pintura (override) desce para
## uma cópia dela.
static func _gravar_cores_na_malha(no: Node) -> void:
	if no is MeshInstance3D and (no as MeshInstance3D).mesh is ArrayMesh:
		var mi := no as MeshInstance3D
		var malha := mi.mesh.duplicate() as ArrayMesh
		for s in malha.get_surface_count():
			var mat := mi.get_surface_override_material(s)
			if mat != null:
				malha.surface_set_material(s, mat)
				mi.set_surface_override_material(s, null)
		mi.mesh = malha
	for f in no.get_children():
		_gravar_cores_na_malha(f)
