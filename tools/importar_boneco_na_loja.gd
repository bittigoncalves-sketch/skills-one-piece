extends SceneTree
# ============================================================================
#  PÕE O BONECO DE DUELO NA LOJA DO EDITOR, na aba "inimigos" (30/09/2026).
#
#  Pedido do dono: o boneco de testes do Modo História — o que luta com o MESMO
#  executor do jogador — vira inimigo que se coloca no mapa pelo editor. A loja só
#  conhece .glb, então a entrada é o corpo dele (`base_v2_runtime.glb`, o mesmo que
#  o `PlayerRig` monta) importado pelo MESMO caminho do botão da loja
#  (`ImportadorDeModelos.importar`), mais:
#    • categoria "inimigos"  — é o que faz do modelo um inimigo no jogo;
#    • comportamento "boneco_de_duelo" — é o que faz o jogo trocar a peça pelo
#      boneco que luta (`InimigoDoMapa`), em vez de um alvo parado.
#
#  Idempotente: se já houver um modelo com esse comportamento, não faz nada.
#
#  Rodar:  godot --headless --path . --script tools/importar_boneco_na_loja.gd
# ============================================================================

const ORIGEM := "res://assets/models/base_v2/base_v2_runtime.glb"
const NOME := "Boneco de duelo"
const COMPORTAMENTO := "boneco_de_duelo"
const CATEGORIA := "inimigos"


func _init() -> void:
	var r := importar(BibliotecaDeModelos.padrao())
	if not r["ok"]:
		push_error(r["erro"])
		quit(1)
		return
	print(r["mensagem"])
	quit(0)


## Põe o boneco em `bib` (a loja do dono, ou a de um teste). {ok, id, erro, mensagem}.
static func importar(bib: BibliotecaDeModelos) -> Dictionary:
	for id in bib.ids():
		if bib.comportamento_do_modelo(id) == COMPORTAMENTO:
			return {"ok": true, "id": id, "erro": "", "mensagem": "já está na loja: %s (\"%s\")" % [id, bib.info(id)["nome"]]}
	if not bib.tem_categoria(CATEGORIA):
		return {"ok": false, "id": "", "erro": "a loja não tem a categoria \"%s\"" % CATEGORIA, "mensagem": ""}
	# Copiado com o nome final antes de importar: o id sai do nome do arquivo.
	var temporario := OS.get_user_data_dir().path_join("%s.glb" % COMPORTAMENTO)
	DirAccess.copy_absolute(ProjectSettings.globalize_path(ORIGEM), temporario)
	var r := ImportadorDeModelos.importar(bib, temporario)
	DirAccess.remove_absolute(temporario)
	if not r["ok"]:
		return {"ok": false, "id": "", "erro": r["erro"], "mensagem": ""}
	var id: String = r["id"]
	bib.renomear(id, NOME)
	bib.marcar_categoria([id] as Array[String], CATEGORIA, true)
	bib.definir_comportamento(id, COMPORTAMENTO)
	var info := bib.info(id)
	return {"ok": true, "id": id, "erro": "", "mensagem": "importado: %s  nome=\"%s\"  categorias=%s  comportamento=%s  tamanho=%s" % [
		id, info["nome"], str(info["categorias"]), info["comportamento"], str(info["tamanho"])]}
