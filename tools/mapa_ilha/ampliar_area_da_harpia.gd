extends SceneTree
# ============================================================================
#  TERRITÓRIO DA HARPIA MAIOR (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/ampliar_area_da_harpia.gd
#
#  Pedido do dono: "aumento da área de atuação da águia" (a Harpia dos morros, a do
#  tornado). Era 80 × 70 m em volta do morro; passa a 150 × 130 m, cobrindo os dois picos
#  (`mountains` e `mountain-xy4ej3zg3i`) e as pedras em volta, de onde ela ronda e investe.
#  Encosta 20 m no território do gorila (o outro chefe dos morros) — escolha minha.
#  Troca SÓ o tamanho/centro da peça `animais_morros_harpia`, guarda uma cópia do mapa
#  antes (uma por versão) e NÃO grava se o arquivo mudou durante a execução.
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const ID := "animais_morros_harpia"
const CENTRO := Vector2(-142.0, -152.0)
const TAMANHO := Vector2(150.0, 130.0)
const ALTURA := 60.0


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var achou := false
	for p: Dictionary in mapa["pecas"]:
		if p["id"] != ID:
			continue
		achou = true
		var antes: Vector3 = p["tamanho"]
		var pos: Vector3 = p["posicao"]
		p["posicao"] = Vector3(CENTRO.x, pos.y, CENTRO.y)
		p["tamanho"] = Vector3(TAMANHO.x, ALTURA, TAMANHO.y)
		print("AREA %s: %s → %s, centro (%.0f, %.0f)" % [ID, str(antes), str(p["tamanho"]), CENTRO.x, CENTRO.y])
	if not achou:
		print("HARPIA recusado: a peça %s não está no mapa (mapa NÃO gravado)" % ID)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
	var copia := BACKUPS.path_join("baseplate_antes_area_harpia_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)
	if FileAccess.get_file_as_string(MAPA) != original:
		print("HARPIA recusado: o mapa mudou durante a execução (outra frente?) — mapa NÃO gravado")
		quit(1)
		return
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("AREA_HARPIA grava=%s" % error_string(err))
	quit(0 if err == OK else 1)
