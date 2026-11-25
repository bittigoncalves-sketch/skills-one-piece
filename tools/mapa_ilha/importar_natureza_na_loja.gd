extends SceneTree
# ============================================================================
#  NATUREZA NA LOJA — árvores, frutas e complementos de floresta (01/10/2026).
#
#    ~/opt/blender/blender -b --python tools/blender/preparar_natureza.py -- <pacote.glb> <Free Forest> art_src/natureza
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/importar_natureza_na_loja.gd
#    "$(./find_godot.sh)" --headless --path . --import       (gera os .import novos)
#    (o próprio script, rodado de novo, liga force_disable_compression nos .import)
#
#  Lê art_src/natureza/manifesto.json e registra cada modelo na loja:
#    • categorias "arvores" (árvores e tocos), "frutas" (as 6 frutas), "floresta"
#      (arbustos, grama, flores, cogumelos, pedras, tronco caído, chão);
#    • tamanho padrão = tamanho do arquivo × fator do manifesto (escala do jogador);
#    • atravessável: o que não colide (frutas, grama, flores, cogumelos, arbustos);
#    • frutífera: as frutas que a árvore adulta dá (uma sorteada por árvore no jogo).
#  Idempotente: arquivo com o mesmo SHA não é copiado de novo; campos são regravados.
# ============================================================================

const ORIGEM := "res://art_src/natureza"
const CATEGORIAS := {"arvores": "Árvores", "frutas": "Frutas", "floresta": "Floresta"}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	for id: String in CATEGORIAS:
		if not bib.tem_categoria(id):
			# O id nasce do nome e perde acento ("Árvores" viraria "rvores"): cria pelo id e
			# só depois põe o nome de exibição.
			var r := bib.criar_categoria(id)
			if not r["ok"] or r["id"] != id:
				push_error("categoria %s: %s" % [id, str(r)])
				quit(1)
				return
		if bib.nome_da_categoria(id) != CATEGORIAS[id]:
			bib.renomear_categoria(id, CATEGORIAS[id])
	var manifesto: Variant = JSON.parse_string(FileAccess.get_file_as_string(ORIGEM.path_join("manifesto.json")))
	if not (manifesto is Dictionary):
		push_error("manifesto ilegível — rode tools/blender/preparar_natureza.py")
		quit(1)
		return
	var erros := 0
	var novos := 0
	for m: Dictionary in manifesto["modelos"]:
		var id: String = m["id"]
		var origem := ORIGEM.path_join(id + ".glb")
		var destino := bib.caminho_do_arquivo(id)
		var sha := FileAccess.get_sha256(origem)
		if not FileAccess.file_exists(destino) or FileAccess.get_sha256(destino) != sha:
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(origem), ProjectSettings.globalize_path(destino)) != OK:
				push_error("não copiou " + id)
				erros += 1
				continue
			novos += 1
		var cena := BibliotecaDeModelos.carregar_glb(destino)
		if cena == null:
			erros += 1
			continue
		var medidas := BibliotecaDeModelos.medir(cena)
		cena.free()
		var caixa: AABB = medidas["aabb"]
		var tipo: String = m["tipo"]
		var categoria := "frutas" if tipo == "fruta" else ("arvores" if tipo in ["arvore", "toco"] else "floresta")
		erros += int(bib.adicionar({"id": id, "nome": m["nome"], "sha256": sha, "centro": caixa.get_center(),
			"tamanho": caixa.size, "triangulos": medidas["triangulos"], "categorias": [categoria]}) != OK)
		erros += int(bib.definir_tamanho_padrao(id, caixa.size * float(m["fator"])) != OK)
		erros += int(bib.definir_atravessavel(id, m["colisao"] == "nenhuma") != OK)
		erros += int(bib.definir_frutifera(id, m["frutas"]) != OK)
		_sem_compressao(destino)
	print("NATUREZA_NA_LOJA %d modelos (%d arquivos novos), erros=%d" % [(manifesto["modelos"] as Array).size(), novos, erros])
	quit(1 if erros else 0)


## GLB com várias superfícies: a compressão de vértices do Godot quantiza cada uma pelo
## próprio AABB e abre frestas (pontinhos pretos — a areia, 30/09/2026).
func _sem_compressao(destino: String) -> void:
	var caminho := destino + ".import"
	if not FileAccess.file_exists(caminho):
		return                      # ainda não importado: rodar --import e este script de novo
	var texto := FileAccess.get_file_as_string(caminho)
	if texto.contains("meshes/force_disable_compression=false"):
		var f := FileAccess.open(caminho, FileAccess.WRITE)
		f.store_string(texto.replace("meshes/force_disable_compression=false", "meshes/force_disable_compression=true"))
		f.close()
