extends SceneTree
# ============================================================================
#  PÕE OS PERSONAGENS DO EAST BLUE NA LOJA DO EDITOR (17/10/2026).
#
#    python3 -I tools/mine_piece/geo_para_glb.py            # 1) converte do JAR local
#    "$(./find_godot.sh)" --headless --path . --script tools/mine_piece/registrar_na_loja.gd [-- --forcar]
#
#  Importa cada `build/mine_piece/mp_<id>.glb` pelo MESMO caminho do botão da loja
#  (`ImportadorDeModelos`), na categoria "East Blue (Mine Piece)", com o nome da ficha e
#  o comportamento `mine_piece` — é o que faz o jogo trocar a peça pelo personagem vivo
#  (`PersonagensEastBlue`). O .glb copiado (`mapas/modelos/mp_*.glb`) é arte PROVISÓRIA
#  do mod e fica fora do git; o catálogo (no git) guarda a entrada.
#
#  Idempotente: modelo que já está na loja é pulado; `--forcar` troca pelo .glb novo
#  (depois de reconverter).
# ============================================================================

const ORIGEM := "res://build/mine_piece"
const NOME_CATEGORIA := "East Blue (Mine Piece)"


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var forcar := OS.get_cmdline_user_args().has("--forcar")
	var bib := BibliotecaDeModelos.padrao()
	# A categoria é achada pelo NOME (o id sai do nome na criação); o jogo procura o
	# personagem pelo comportamento, não pela categoria.
	var categoria := _id_da_categoria(bib)
	if categoria.is_empty():
		var c := bib.criar_categoria(NOME_CATEGORIA)
		categoria = str(c.get("id", ""))
		print("categoria criada: %s" % str(c))
	var pasta := ProjectSettings.globalize_path(ORIGEM)
	var arquivos := DirAccess.get_files_at(pasta)
	var falhas := 0
	var feitos := 0
	for arq in arquivos:
		if not arq.begins_with("mp_") or not arq.ends_with(".glb"):
			continue
		var id := arq.get_basename()
		var ficha := DadosEastBlue.ficha_do_modelo(id)
		if ficha.is_empty():
			print("pulado (sem ficha): " + id)
			continue
		if bib.tem(id):
			if not forcar:
				continue
			bib.remover(id)
		var r := ImportadorDeModelos.importar(bib, pasta.path_join(arq))
		if not r["ok"] or str(r["id"]) != id:
			push_error("%s: %s (id %s)" % [arq, str(r.get("erro", "")), str(r.get("id", ""))])
			falhas += 1
			continue
		var nome := str(ficha.get("nome", id))
		if id != str(ficha.get("modelo", "")):
			nome += " (" + id.trim_prefix("mp_pirate_") + ")"
		bib.renomear(id, nome)
		bib.marcar_categoria([id] as Array[String], categoria, true)
		bib.definir_comportamento(id, DadosEastBlue.COMPORTAMENTO)
		feitos += 1
	print("REGISTRADOS %d, falhas %d, categoria %s" % [feitos, falhas, categoria])
	quit(1 if falhas > 0 else 0)


func _id_da_categoria(bib: BibliotecaDeModelos) -> String:
	for c: Dictionary in bib.categorias():
		if str(c.get("nome", "")) == NOME_CATEGORIA:
			return str(c.id)
	return ""
