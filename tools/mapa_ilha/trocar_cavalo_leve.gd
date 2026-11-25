extends SceneTree
# ============================================================================
#  CAVALO LEVE na loja e na vila (01/10/2026).
#
#    ~/opt/blender/blender -b --python tools/blender/simplificar_cavalo.py -- \
#        mapas/modelos/animals__farm__horse_1__base.glb art_src/cavalo/cavalo_leve.glb
#    cp art_src/cavalo/cavalo_leve.glb mapas/modelos/cavalo_da_vila_leve.glb
#    "$(./find_godot.sh)" --headless --path . --import      # depois: force_disable_compression=true
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/trocar_cavalo_leve.gd [-- --sem-mapa]
#
#  Decisão do dono: simplificar o cavalo de 751 mil triângulos posto na vila, mantendo
#  a aparência, num arquivo NOVO da loja (o original continua lá). Registra o arquivo
#  na loja (mesma categoria "pets") e troca o modelo da peça da vila — só dela, mesmo
#  lugar e mesmo tamanho; cópia do mapa antes. `--sem-mapa` só registra na loja.
# ============================================================================

const ID := "cavalo_da_vila_leve"
const ORIGINAL := "animals__farm__horse_1__base"
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var caminho := bib.caminho_do_arquivo(ID)
	var cena := BibliotecaDeModelos.carregar_glb(caminho)
	if cena == null or not bib.tem(ORIGINAL):
		push_error("falta o .glb novo (%s) ou o original na loja" % caminho)
		quit(1)
		return
	var medidas := BibliotecaDeModelos.medir(cena)
	cena.free()
	var caixa: AABB = medidas["aabb"]
	var erro := bib.adicionar({"id": ID, "nome": "Cavalo da vila (leve)", "sha256": FileAccess.get_sha256(caminho),
		"centro": caixa.get_center(), "tamanho": caixa.size, "triangulos": medidas["triangulos"],
		"categorias": bib.categorias_do_modelo(ORIGINAL)})
	var o: Dictionary = bib.info(ORIGINAL)
	print("LOJA %s: %d triângulos (original %d), caixa %s (original %s), colisão própria %d faces" % [
		ID, medidas["triangulos"], o["triangulos"], caixa.size, o["tamanho"],
		(medidas["faces_colisao"] as PackedVector3Array).size() / 3])
	if erro != OK or OS.get_cmdline_user_args().has("--sem-mapa"):
		quit(0 if erro == OK else 1)
		return
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var trocadas: Array[String] = []
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] == "modelo" and p["modelo"] == ORIGINAL:
			p["modelo"] = ID
			trocadas.append(p["id"])
	if not trocadas.is_empty():
		var original := FileAccess.get_file_as_string(MAPA)
		var copia := BACKUPS.path_join("baseplate_antes_cavalo_leve_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		erro = MapaArquivo.salvar(MAPA, mapa)
	print("CAVALO_LEVE pecas_trocadas=%s erro=%s" % [str(trocadas), error_string(erro)])
	quit(0 if erro == OK else 1)
