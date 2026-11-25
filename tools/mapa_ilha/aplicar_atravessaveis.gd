extends SceneTree
# ============================================================================
#  MODELOS ATRAVESSÁVEIS — loja e mapa vivo (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/aplicar_atravessaveis.gd
#
#  Decisão do dono: a plantação `crops` é ATRAVESSÁVEL. A colisão dela era a malha
#  inteira (35 mil triângulos de folha) e quem encostava — bicho ou jogador — pagava
#  2–5 ms por quadro (medido 01/10/2026, ovelha raspando a plantação).
#
#  Marca os modelos de ATRAVESSAVEIS na loja (o editor passa a inseri-los sem
#  colisão) e desliga a colisão das peças deles que JÁ estão no mapa vivo — só
#  dessas peças; cópia do mapa antes. Idempotente.
# ============================================================================

const ATRAVESSAVEIS := ["crops"]
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var erros := 0
	for id: String in ATRAVESSAVEIS:
		if not bib.tem(id):
			push_error("fora da loja: " + id)
			erros += 1
			continue
		erros += int(bib.definir_atravessavel(id, true) != OK)
	var lido := MapaArquivo.carregar(MAPA)
	if erros or not lido["ok"]:
		push_error("nada gravado no mapa (erros=%d, mapa ok=%s)" % [erros, lido["ok"]])
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var trocadas: Array[String] = []
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] == "modelo" and ATRAVESSAVEIS.has(p["modelo"]) and p["colisao"]:
			p["colisao"] = false
			trocadas.append(p["id"])
	if not trocadas.is_empty():
		var original := FileAccess.get_file_as_string(MAPA)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_atravessaveis_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		erros += int(MapaArquivo.salvar(MAPA, mapa) != OK)
	print("ATRAVESSAVEIS loja=%s pecas_sem_colisao=%s erros=%d" % [str(ATRAVESSAVEIS), str(trocadas), erros])
	quit(1 if erros else 0)
