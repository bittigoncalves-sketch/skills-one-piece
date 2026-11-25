extends SceneTree
# ============================================================================
#  PÕE AS ESTRUTURAS DO MINE PIECE NA LOJA DO EDITOR (18/10/2026).
#
#    python3 -I tools/mine_piece/estrutura_para_glb.py      # 1) converte do JAR local
#    "$(./find_godot.sh)" --headless --path . --script tools/mine_piece/registrar_estruturas.gd [-- --forcar | --so-navios]
#
#  Importa cada `build/mine_piece/estruturas/mpe_<nome>.glb` pelo MESMO caminho do botão da
#  loja (`ImportadorDeModelos`), na categoria "Estruturas (Mine Piece)", com nome em
#  português e o número de triângulos da malha `Colisao` (o catálogo usa a colisão própria
#  mesmo quando o desenho passa do teto — o Baratie). O .glb copiado
#  (`mapas/modelos/mpe_*.glb`) é arte PROVISÓRIA e fica fora do git.
#  Plano: docs/ESTRUTURAS_MINE_PIECE_PLANO.md. Idempotente; `--forcar` troca pelo .glb novo.
# ============================================================================

const ORIGEM := "res://build/mine_piece/estruturas"
const NOME_CATEGORIA := "Estruturas (Mine Piece)"
## Pedaços de mundo do mod (mar, fundo, Red Line) e a de só barreira: não são construções.
const FORA := ["mpe_ocean", "mpe_ocean_bottom", "mpe_red_line", "mpe_barrier"]
const NOMES := {
	"branch_153rd": "Base da Marinha 153", "ship_alvida": "Navio da Alvida", "ship_baratie": "Baratie",
	"ship_going_merry": "Going Merry", "ship_marine_large_1": "Navio grande da Marinha",
	"ship_mihawk": "Barco do Mihawk", "ship_moby_dick": "Moby Dick", "ship_oro_jackson": "Oro Jackson",
	"ship_pirate_mini_1": "Navio pirata pequeno", "ship_red_force": "Red Force",
	"ship_saber_of_xebec_1": "Saber of Xebec (1)", "ship_saber_of_xebec_2": "Saber of Xebec (2)",
	"ship_thousand_sunny": "Thousand Sunny", "shop_clothes": "Loja de roupas", "shop_weapon": "Loja de armas",
	"tent_bandit": "Acampamento bandido", "tent_marine": "Acampamento da Marinha", "tent_pirates": "Acampamento pirata",
	"village_foosha_house1": "Foosha: casa 1", "village_foosha_house2": "Foosha: casa 2",
	"village_foosha_house3": "Foosha: casa 3", "village_foosha_house4": "Foosha: casa 4",
	"village_foosha_ranch1": "Foosha: rancho", "village_foosha_road_cross": "Foosha: cruzamento",
	"village_foosha_road_street": "Foosha: rua", "village_foosha_windmill1": "Foosha: moinho 1",
	"village_foosha_windmill2": "Foosha: moinho 2", "village_heian_crossroad": "Wano (Heian): cruzamento",
	"village_heian_garage": "Wano (Heian): galpão", "village_heian_graveyard": "Wano (Heian): cemitério",
	"village_heian_house1": "Wano (Heian): casa 1", "village_heian_house2": "Wano (Heian): casa 2",
	"village_heian_house3": "Wano (Heian): casa 3", "village_heian_house4": "Wano (Heian): casa 4",
	"village_heian_prizon": "Wano (Heian): prisão", "village_heian_road": "Wano (Heian): rua",
	"village_heian_temple": "Wano (Heian): templo", "village_heian_watchtower": "Wano (Heian): torre de vigia",
	"village_shandora_bell": "Shandora: sino de ouro", "village_shandora_house1": "Shandora: casa 1",
	"village_shandora_house2": "Shandora: casa 2", "village_shandora_house3": "Shandora: casa 3",
	"village_shandora_road_cross": "Shandora: cruzamento", "village_shandora_road_street": "Shandora: rua",
	"village_shimotsuki_dojo": "Shimotsuki: dojo", "village_shimotsuki_field": "Shimotsuki: campo",
	"village_shimotsuki_road": "Shimotsuki: rua", "village_yukaku_crossroad": "Wano (Yukaku): cruzamento",
	"village_yukaku_house_1": "Wano (Yukaku): casa 1", "village_yukaku_house_2": "Wano (Yukaku): casa 2",
	"village_yukaku_house_3": "Wano (Yukaku): casa 3", "village_yukaku_house_4": "Wano (Yukaku): casa 4",
	"village_yukaku_house_5": "Wano (Yukaku): casa 5", "village_yukaku_road": "Wano (Yukaku): rua",
	"water_seven_house_1": "Water Seven: casa 1", "water_seven_house_2": "Water Seven: casa 2",
	"water_seven_house_3": "Water Seven: casa 3", "water_seven_house_4": "Water Seven: casa 4",
	"water_seven_road": "Water Seven: canal 1", "water_seven_road_2": "Water Seven: canal 2",
	"water_seven_road_cross": "Water Seven: cruzamento de canais",
}


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var forcar := OS.get_cmdline_user_args().has("--forcar")
	var so_navios := OS.get_cmdline_user_args().has("--so-navios")
	var bib := BibliotecaDeModelos.padrao()
	var categoria := _id_da_categoria(bib)
	if categoria.is_empty():
		categoria = str(bib.criar_categoria(NOME_CATEGORIA).get("id", ""))
	var pasta := ProjectSettings.globalize_path(ORIGEM)
	var feitos := 0
	var falhas := 0
	for arq in DirAccess.get_files_at(pasta) if not so_navios else PackedStringArray():
		var id := arq.get_basename()
		if not arq.begins_with("mpe_") or not arq.ends_with(".glb") or id in FORA:
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
		bib.renomear(id, str(NOMES.get(id.trim_prefix("mpe_"), id)))
		bib.marcar_categoria([id] as Array[String], categoria, true)
		var cena := BibliotecaDeModelos.carregar_glb(pasta.path_join(arq))
		var medida := BibliotecaDeModelos.medir(cena)
		cena.free()
		bib.definir_triangulos_colisao(id, (medida["faces_colisao"] as PackedVector3Array).size() / 3)
		feitos += 1
		print("%-34s %s  desenho %d tri, colisão %d tri" % [id, str(bib.info(id)["tamanho"]), medida["triangulos"],
			(medida["faces_colisao"] as PackedVector3Array).size() / 3])
	print("REGISTRADAS %d, falhas %d, categoria %s" % [feitos, falhas, categoria])
	falhas += _navios(bib)
	quit(1 if falhas > 0 else 0)


## Os 12 navios do mod À VENDA (pedido do dono, 18/10/2026: "todos os 12 do mod à venda e
## retire os 3 atuais"): categoria `navios`, ficha pelo tamanho real (mesma escala das
## classes: vida ≈ 45 × comprimento; velocidade e curva caem com o tamanho) e o perfil de
## navegação do conversor em `<id>.perfil_navio.json` (lido pelo `PerfilBarco`).
func _navios(bib: BibliotecaDeModelos) -> int:
	var caminho := ORIGEM.path_join("relatorio.json")
	if not FileAccess.file_exists(caminho):
		push_error("falta %s" % caminho)
		return 1
	var falhas := 0
	for r: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(caminho)):
		var id := "mpe_" + str(r["estrutura"])
		if not r.has("navio") or not bib.tem(id):
			continue
		var t: Vector3 = bib.info(id)["tamanho"]
		var comprimento := maxf(t.x, t.z)
		var ficha := {"classe": "bote" if comprimento < 12.0 else ("chalupa" if comprimento < 30.0 else "galeao"),
			"comprimento": snappedf(comprimento, 0.1), "velocidade": snappedf(clampf(9.0 - comprimento * 0.04, 4.5, 8.5), 0.1),
			"curva": snappedf(clampf(900.0 / comprimento, 10.0, 70.0), 0.1), "vida": roundi(45.0 * comprimento),
			"tripulacao": clampi(roundi(comprimento / 1.6), 2, 60), "carga": roundi(comprimento * 2.0),
			"canhoes": roundi(comprimento / 4.0)}
		bib.marcar_categoria([id] as Array[String], "navios", true)
		if bib.definir_ficha_de_navio(id, ficha) != OK:
			push_error("%s: ficha de navio recusada %s" % [id, str(ficha)])
			falhas += 1
			continue
		var f := FileAccess.open(bib.raiz.path_join(id + ".perfil_navio.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(r["navio"]) + "\n")
		f.close()
		print("NAVIO %-28s %s" % [id, str(ficha)])
	return falhas


func _id_da_categoria(bib: BibliotecaDeModelos) -> String:
	for c: Dictionary in bib.categorias():
		if str(c.get("nome", "")) == NOME_CATEGORIA:
			return str(c.id)
	return ""
