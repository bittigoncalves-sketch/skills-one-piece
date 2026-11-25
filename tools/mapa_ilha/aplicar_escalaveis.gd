extends SceneTree
# ============================================================================
#  MODELOS ESCALÁVEIS — marcação inicial na loja (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/aplicar_escalaveis.gd
#
#  Decisão do dono (02/10/2026, fatia 3 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md):
#  campo `escalavel` por modelo na loja; CONSTRUÇÕES, ROCHAS e MUROS marcados de
#  início, o resto não; relevo do terreno não escala. Depois disso quem decide é a
#  loja (clique direito → "Escalável").
#
#  Só mexe no catálogo: o mapa não guarda o campo — o MapaMontador o lê da loja
#  ao montar cada peça. Idempotente. Imprime a lista para conferência.
# ============================================================================

## Construções, rochas, muros e docas — por categoria ou pelo nome.
const PADRAO := "rock|pedra|rocha|boulder|rochedo|muro|wall|house|casa|hut|tower|torre|temple|templo|fortress|forte|castle|barracks|inn|sawmill|stable|blacksmith|mill|building|storage|archery|dock|ponte|bridge|gate"
## Adereços pequenos que casam com o padrão ou estão em "construção" e não escalam.
const FORA := ["barrel", "bench", "bench-7uslzo3n9y", "bonfire", "cart", "cauldron", "crate", "sawmill_saw", "fence",
	"rocks", "rocks_2", "rocks_3", "rock_2", "gold_rocks", "gold_rocks_2", "floresta_rock_09", "floresta_rock_10"]


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var re := RegEx.create_from_string("(?i)" + PADRAO)
	var marcar: Array[String] = []
	for id: String in bib.ids():
		if FORA.has(id):
			continue
		var info := bib.info(id)
		var cats: Array = bib.categorias_do_modelo(id)
		if cats.has("construao") or re.search(id + " " + str(info.get("nome", ""))) != null:
			marcar.append(id)
	var erro := bib.definir_escalavel(marcar, true)
	for id in marcar:
		print("  escalável: %s  (%s)" % [id, bib.info(id).get("nome", "")])
	print("ESCALAVEIS %d modelos marcados, erro=%s" % [marcar.size(), error_string(erro)])
	quit(1 if erro != OK else 0)
