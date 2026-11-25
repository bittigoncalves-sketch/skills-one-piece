extends SceneTree
# ============================================================================
#  ÁREAS DE ANIMAIS no mapa vivo da Ilha Inicial (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colocar_areas_de_animais.gd
#
#  Lê `areas_de_animais.json` (a fonte: espécie, quantidade, centro e tamanho de cada
#  área) e SOMA as peças `area_animais` ao mapa que o dono edita — NUNCA regenera a
#  ilha (o gerador apaga as edições dele). Antes de gravar, guarda uma cópia do mapa
#  em art_src/backups/mapa_historia/ com o sha do arquivo no nome.
#
#  Idempotente: as peças desta ferramenta têm id "animais_<id da área>"; rodar de
#  novo troca SÓ elas (outra área que o dono criar no editor fica). Uma área com o
#  mesmo id que o dono moveu no editor volta para a posição da fonte — mude a fonte.
#
#  A altura e o Y de cada volume saem do RELEVO sob a área (o volume abraça o chão,
#  do mais baixo ao mais alto, +6 m; voador ganha a altura de voo da espécie).
# ============================================================================

const FONTE := "res://tools/mapa_ilha/areas_de_animais.json"
const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const GRUPO := "animais"
const PREFIXO := "animais_"
const AMOSTRAS := 7      # por lado, para achar o chão mais baixo e o mais alto


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	var fonte: Variant = JSON.parse_string(FileAccess.get_file_as_string(FONTE))
	if not (fonte is Dictionary and (fonte as Dictionary).get("areas") is Array):
		push_error("fonte ilegível: " + FONTE)
		quit(1)
		return
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = lido["mapa"]

	# Cópia do mapa como está agora (uma por versão do arquivo).
	var original := FileAccess.get_file_as_string(MAPA)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
	var copia := BACKUPS.path_join("baseplate_antes_animais_%s.json" % original.sha256_text().left(12))
	if not FileAccess.file_exists(copia):
		var f := FileAccess.open(copia, FileAccess.WRITE)
		f.store_string(original)
		f.close()
	print("COPIA ", copia)

	var pecas: Array = []
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		if p["tipo"] == "area_animais" and String(p["id"]).begins_with(PREFIXO):
			trocadas += 1
			continue
		pecas.append(p)
	var terrenos: Array[Dictionary] = []
	for p: Dictionary in pecas:
		if p["tipo"] == "terreno":
			terrenos.append(p)
	var grupos: Array = mapa["grupos"]
	if not grupos.any(func(g: Dictionary) -> bool: return g["id"] == GRUPO):
		grupos.append({"id": GRUPO, "pai": ""})

	var erros := 0
	var total := 0
	for a: Dictionary in fonte["areas"]:
		var esp := str(a["especie"])
		var ficha := bib.ficha_de_animal(esp)
		if ficha.is_empty():
			push_error("%s: \"%s\" não é animal da loja (sem ficha)" % [a["id"], esp])
			erros += 1
			continue
		if bool(a.get("boss", false)) != bool(ficha.get("boss", false)):
			push_error("%s: a fonte e a ficha discordam sobre ser chefe" % a["id"])
			erros += 1
		var c := Vector2(a["centro"][0], a["centro"][1])
		var t := Vector2(a["tamanho"][0], a["tamanho"][1])
		var faixa := _faixa_do_chao(terrenos, c, t)
		if is_nan(faixa.x):
			push_error("%s: fora do relevo" % a["id"])
			erros += 1
			continue
		var voo := float(ficha.get("altura_voo", 0.0)) if FichaDeAnimal.voa(ficha) else 0.0
		var altura := (faixa.y - faixa.x) + 6.0 + voo
		var y := faixa.x - 1.0 + altura * 0.5
		pecas.append({"id": PREFIXO + str(a["id"]), "tipo": "area_animais", "grupo": GRUPO,
			"posicao": Vector3(c.x, y, c.y), "rotacao_graus": Vector3.ZERO,
			"tamanho": Vector3(t.x, altura, t.y), "cor": Color("#40f0a8"), "material": "liso",
			"grade_celula": 4.0, "colisao": false, "especie": esp, "quantidade": int(a["quantidade"])})
		total += int(a["quantidade"])
		print("AREA %-22s %-28s ×%d  chão %.1f..%.1f m" % [a["id"], esp, a["quantidade"], faixa.x, faixa.y])
	if erros:
		print("AREAS_ANIMAIS recusado: %d erros (mapa NÃO gravado)" % erros)
		quit(1)
		return
	mapa["pecas"] = pecas
	var err := MapaArquivo.salvar(MAPA, mapa)
	print("AREAS_ANIMAIS %d áreas, %d animais (trocadas %d), grava=%s" % [
		(fonte["areas"] as Array).size(), total, trocadas, error_string(err)])
	quit(0 if err == OK else 1)


## Chão mais baixo e mais alto (Y do mundo) sob o retângulo. NAN = fora do relevo.
func _faixa_do_chao(terrenos: Array[Dictionary], c: Vector2, t: Vector2) -> Vector2:
	var lo := INF
	var hi := -INF
	for i in AMOSTRAS:
		for j in AMOSTRAS:
			var x := c.x + (float(i) / (AMOSTRAS - 1) - 0.5) * t.x
			var z := c.y + (float(j) / (AMOSTRAS - 1) - 0.5) * t.y
			for p in terrenos:
				var pos: Vector3 = p["posicao"]
				var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], x - pos.x, z - pos.z)
				if not is_nan(y):
					lo = minf(lo, pos.y + y)
					hi = maxf(hi, pos.y + y)
					break
	return Vector2(lo, hi) if lo < INF else Vector2(NAN, NAN)
