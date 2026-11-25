extends SceneTree
# ============================================================================
#  BARBA NEGRA NA CIDADE INICIAL (15/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colocar_barba_negra.gd
#
#  Pedido do dono: pegar o Barba Negra da arena e pô-lo na cidade inicial, com a opção
#  de retirar a fruta e a venda de pulo no ar e dash no ar (1000 moedas cada).
#  Pré-requisito: `tools/importar_npcs_na_loja.gd` (põe `npc_barba_negra` na loja).
#
#  Fica a 7 m do ponto de nascimento, no chão do relevo, virado para ele — o jogador o
#  vê ao abrir os olhos. Grava no MAPA VIVO como as outras ferramentas da ilha: troca SÓ
#  a própria peça, guarda uma cópia do mapa antes e NÃO grava se o arquivo mudou durante
#  a execução.
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const ID := "cidade_barba_negra"
const MODELO := "npc_barba_negra"
const ONDE := Vector2(159.0, 20.0)
const OLHA_PARA := Vector2(152.0, 20.0)      # o ponto de nascimento


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
	var copia := BACKUPS.path_join("baseplate_antes_barba_negra_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)

	var pecas: Array = []
	var terrenos: Array[Dictionary] = []
	for p: Dictionary in mapa["pecas"]:
		if p["id"] == ID:
			continue
		if p["tipo"] == "terreno":
			terrenos.append(p)
		pecas.append(p)
	var chao := _chao(terrenos, ONDE)
	if is_nan(chao):
		print("BARBA_NEGRA recusado: fora do relevo (mapa NÃO gravado)")
		quit(1)
		return
	var tam := bib.tamanho_padrao(MODELO)
	var para := OLHA_PARA - ONDE
	var giro := rad_to_deg(atan2(-para.x, -para.y))       # −Z do modelo olhando para o spawn
	pecas.append({"id": ID, "tipo": "modelo", "modelo": MODELO,
		"posicao": Vector3(ONDE.x, chao + tam.y * 0.5, ONDE.y), "rotacao_graus": Vector3(0, giro, 0),
		"tamanho": tam, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true})
	print("PECA %s em (%.1f, %.2f, %.1f) giro %.0f°  chão=%.2f" % [ID, ONDE.x, chao + tam.y * 0.5, ONDE.y, giro, chao])
	if FileAccess.get_file_as_string(MAPA) != original:
		print("BARBA_NEGRA recusado: o mapa mudou durante a execução (outra frente?) — mapa NÃO gravado")
		quit(1)
		return
	mapa["pecas"] = pecas
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("BARBA_NEGRA grava=%s" % error_string(err))
	quit(0 if err == OK else 1)


## Y do chão do relevo em (x, z). NAN = fora.
func _chao(terrenos: Array[Dictionary], c: Vector2) -> float:
	for p in terrenos:
		var pos: Vector3 = p["posicao"]
		var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], c.x - pos.x, c.y - pos.z)
		if not is_nan(y):
			return pos.y + y
	return NAN
