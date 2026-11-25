extends SceneTree
# ============================================================================
#  VENDEDOR DE BARCOS NO PORTO + MAPA SEM BARCOS (10/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colocar_vendedor_de_barcos.gd
#
#  Pedido do dono: "adicionar um npc que vende barcos, 1 moeda cada barco e retirar os
#  barcos que estão no mapa atualmente". Escolha dele: retirar TODOS (os 5 dirigíveis e
#  os 2 barcos-casa). Barco agora só existe comprado (`loja_de_barcos.gd`), atracado
#  numa vaga perto do vendedor (`navios/cais.gd`).
#
#  Grava no MAPA VIVO, como as outras ferramentas da ilha:
#    • apaga toda peça cujo modelo é da categoria "navios" (e o grupo "navios" vazio);
#    • põe o vendedor na areia, no pé do píer largo (`dock_wide_1`), virado para a vila.
#  Lugar medido em 10/10/2026: chão seco a 0,11 m; a água (−0,65) começa em x = 256.
#  Troca SÓ a própria peça (rodar de novo não duplica), guarda uma cópia do mapa antes
#  (uma por versão) e NÃO grava se o arquivo mudou durante a execução.
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const ID := "porto_vendedor_de_barcos"
const MODELO := "npc_vendedor_barcos"
const ONDE := Vector2(248.0, 40.0)
const OLHA_PARA := Vector2(230.0, 40.0)      # a vila fica a oeste


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	var bib := BibliotecaDeModelos.padrao()
	if not bib.tem(MODELO):
		push_error("falta na loja: %s (rode tools/importar_npcs_na_loja.gd)" % MODELO)
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
	var copia := BACKUPS.path_join("baseplate_antes_vendedor_barcos_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)

	var pecas: Array = []
	var terrenos: Array[Dictionary] = []
	var retirados := 0
	for p: Dictionary in mapa["pecas"]:
		if p["id"] == ID:
			continue
		if p["tipo"] == "modelo" and bib.tem(str(p["modelo"])) and bib.categorias_do_modelo(str(p["modelo"])).has("navios"):
			print("RETIRA %-24s %s" % [p["id"], p["modelo"]])
			retirados += 1
			continue
		if p["tipo"] == "terreno":
			terrenos.append(p)
		pecas.append(p)
	if not pecas.any(func(p: Dictionary) -> bool: return str(p.get("grupo", "")) == "navios"):
		mapa["grupos"] = (mapa["grupos"] as Array).filter(func(g: Dictionary) -> bool: return g["id"] != "navios")

	var chao := _chao(terrenos, ONDE)
	if is_nan(chao):
		print("VENDEDOR recusado: fora do relevo (mapa NÃO gravado)")
		quit(1)
		return
	var tam := bib.tamanho_padrao(MODELO)
	var para := OLHA_PARA - ONDE
	var giro := rad_to_deg(atan2(-para.x, -para.y))       # −Z do modelo olhando para a vila
	pecas.append({"id": ID, "tipo": "modelo", "modelo": MODELO, "grupo": "porto",
		"posicao": Vector3(ONDE.x, chao + tam.y * 0.5, ONDE.y), "rotacao_graus": Vector3(0, giro, 0),
		"tamanho": tam, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true})
	print("PECA %s em (%.1f, %.2f, %.1f) giro %.0f°" % [ID, ONDE.x, chao + tam.y * 0.5, ONDE.y, giro])
	if FileAccess.get_file_as_string(MAPA) != original:
		print("VENDEDOR recusado: o mapa mudou durante a execução (outra frente?) — mapa NÃO gravado")
		quit(1)
		return
	mapa["pecas"] = pecas
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("VENDEDOR_BARCOS retirados=%d grava=%s" % [retirados, error_string(err)])
	quit(0 if err == OK else 1)


## Y do chão do relevo em (x, z). NAN = fora.
func _chao(terrenos: Array[Dictionary], c: Vector2) -> float:
	for p in terrenos:
		var pos: Vector3 = p["posicao"]
		var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], c.x - pos.x, c.y - pos.z)
		if not is_nan(y):
			return pos.y + y
	return NAN
