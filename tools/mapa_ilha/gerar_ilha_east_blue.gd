extends SceneTree
# ============================================================================
#  ILHA DO EAST BLUE — a 3ª ilha do Modo História (17/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/gerar_ilha_east_blue.gd [-- --saida=<caminho>]
#
#  Pedido do dono: os inimigos, personagens e NPCs do East Blue do Mine Piece numa ilha
#  nova, "cada um com o comportamento original"; decisão dele: UMA ilha com ZONAS por bando.
#  Plano e decisões em docs/EAST_BLUE_PLANO.md. Precisa dos personagens na loja
#  (tools/mine_piece/registrar_na_loja.gd): a peça usa o tamanho do modelo.
#
#  O que grava no MAPA VIVO (sem `--saida`):
#    • `baseplate_east_blue`: placa de 384 × 384 m com centro em (3000, 0), a leste da
#      Ilha dos Macacos (1500, 0);
#    • relevo em 6 × 6 blocos de 64 m (as mesmas contas da Ilha dos Macacos), com uma
#      PRAÇA plana de terra em cada zona e trilhas de terra do píer até Loguetown (o
#      centro) e de lá até cada zona;
#    • anel de praia e píer na costa oeste (virado para a Ilha dos Macacos);
#    • construções da loja em cada zona (escaladas pela largura);
#    • os personagens: peças dos modelos `mp_*` (comportamento `mine_piece`), que o jogo
#      troca pelos personagens vivos (`PersonagensEastBlue`).
#  Troca SÓ as peças com prefixo `eb_` e a `baseplate_east_blue`, guarda uma cópia do
#  mapa antes e NÃO grava se o arquivo mudou durante a execução.
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const PREFIXO := "eb_"
const BASE_ID := "baseplate_east_blue"
const GRUPO := "ilha_east_blue"
const SEMENTE := 171026

const CENTRO := Vector2(3000, 0)
const MEIA := 192.0
const BLOCO := 64.0
const CELULAS := 32
const PASSO := BLOCO / CELULAS
const BASE_DOS_BLOCOS := -1.5
const ACIMA_DA_BASE := 0.04
const LARGURA_PRAIA := 24.0
const COSTA := 30.0
const LARGURA_TRILHA := 3.0
const PIER := "dock_long"
const DECK := 0.6
## Morros entre as zonas: centro local, raio, altura.
const MORROS := [
	[Vector2(60, -55), 40.0, 9.0], [Vector2(55, 75), 36.0, 7.0], [Vector2(-60, 55), 34.0, 6.0],
	[Vector2(-55, -120), 30.0, 8.0], [Vector2(170, -170), 26.0, 5.0],
]
const HUB := "loguetown"
## Zonas: centro local, raio da praça, construções [modelo, largura (m), deslocamento, giro],
## personagens [modelo da loja, quantidade] (o primeiro na frente: o chefe).
const ZONAS := {
	"loguetown": {"centro": Vector2(0, 0), "raio": 26.0,
		"construcoes": [["town_center", 18.0, Vector2(0, -24), 0.0], ["village_market", 15.0, Vector2(24, 8), -90.0],
			["watch_tower", 4.5, Vector2(-22, -16), 0.0]],
		"personagens": [["mp_smoker", 1], ["mp_tashigi", 1], ["mp_alvida_2", 1], ["mp_girl_icecream", 1], ["mp_marine", 3]]},
	"porto": {"centro": Vector2(-150, 0), "raio": 18.0,
		"construcoes": [["port", 15.0, Vector2(4, -20), 0.0], ["hut", 7.0, Vector2(4, 18), 180.0]],
		"personagens": [["mp_luffy_east_blue", 1], ["mp_zoro_east_blue", 1], ["mp_yosaku", 1], ["mp_jonny", 1]]},
	"ruivo": {"centro": Vector2(-105, -65), "raio": 20.0,
		"construcoes": [["wooden_encampment", 16.0, Vector2(0, -20), 0.0]],
		"personagens": [["mp_shanks", 1], ["mp_benn_beckman", 1], ["mp_lucky_roux", 1], ["mp_yasopp", 1], ["mp_lime_juice", 1],
			["mp_hongo", 1], ["mp_gab", 1], ["mp_bonk_punch", 1], ["mp_building_snake", 1], ["mp_monster_1", 1]]},
	"bandidos": {"centro": Vector2(-125, -140), "raio": 18.0,
		"construcoes": [["shack", 8.0, Vector2(-6, -18), 0.0], ["huts", 10.0, Vector2(16, 6), -90.0]],
		"personagens": [["mp_higuma", 1], ["mp_bandit", 3]]},
	"alvida": {"centro": Vector2(-5, -150), "raio": 18.0,
		"construcoes": [["shack", 8.0, Vector2(0, -18), 0.0]],
		"personagens": [["mp_alvida", 1], ["mp_pirate_pirate1", 1], ["mp_pirate_pirate2", 1], ["mp_pirate_pirate3", 1]]},
	"shells_town": {"centro": Vector2(120, -110), "raio": 22.0,
		"construcoes": [["castle", 22.0, Vector2(8, -24), 0.0], ["watch_tower", 4.5, Vector2(-20, -10), 0.0]],
		"personagens": [["mp_morgan", 1], ["mp_helmeppo", 1], ["mp_coby", 1], ["mp_marine", 4]]},
	"orange_town": {"centro": Vector2(150, 25), "raio": 22.0,
		"construcoes": [["houses", 14.0, Vector2(20, -6), -90.0], ["tower_house", 11.0, Vector2(4, -22), 0.0]],
		"personagens": [["mp_buggy", 1], ["mp_cabaji", 1], ["mp_richie", 1], ["mp_pirate_pirate4", 1], ["mp_pirate_pirate5", 1],
			["mp_pirate_pirate6", 1]]},
	"vila_syrup": {"centro": Vector2(105, 140), "raio": 22.0,
		"construcoes": [["fantasy_house", 11.0, Vector2(18, 10), -90.0], ["fantasy_inn", 11.0, Vector2(-4, 22), 180.0]],
		"personagens": [["mp_kuro", 1], ["mp_jango", 1], ["mp_sham", 1], ["mp_buchi", 1], ["mp_pirate_pirate7", 1],
			["mp_pirate_pirate8", 1]]},
	"baratie": {"centro": Vector2(-25, 155), "raio": 20.0,
		"construcoes": [["fantasy_inn", 13.0, Vector2(0, 20), 180.0]],
		"personagens": [["mp_krieg", 1], ["mp_gin", 1], ["mp_sanji_east_blue", 1], ["mp_fullbody", 1], ["mp_pirate_pirate1", 1],
			["mp_pirate_pirate3", 1], ["mp_pirate_pirate5", 1]]},
	"arlong_park": {"centro": Vector2(-135, 120), "raio": 22.0,
		"construcoes": [["wooden_fortress", 22.0, Vector2(-6, 22), 180.0]],
		"personagens": [["mp_arlong", 1], ["mp_kuroobi", 1], ["mp_hatchan", 1], ["mp_chu", 1], ["mp_pirate_fishman1", 1],
			["mp_pirate_fishman2", 1], ["mp_pirate_fishman3", 1], ["mp_pirate_fishman4", 1]]},
}

var pontos := int(2.0 * MEIA / PASSO) + 1
var H := PackedFloat32Array()
var S := PackedByteArray()
var D_trilha := PackedFloat32Array()
var ruido := FastNoiseLite.new()
var ruido_fino := FastNoiseLite.new()
var trilhas: Array = []                  # [[a: Vector2, b: Vector2], ...] segmentos locais
var tamanho_y := 0.0
var blocos := {}
var contagem := {}


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var saida := MAPA
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--saida="):
			saida = a.trim_prefix("--saida=")
	var original := FileAccess.get_file_as_string(MAPA)
	var lido := MapaArquivo.carregar(MAPA)
	if not lido["ok"]:
		push_error("mapa inválido: " + "; ".join(lido["erros"]))
		quit(1)
		return
	var bib := BibliotecaDeModelos.padrao()
	var faltam: Array = []
	for z: Dictionary in ZONAS.values():
		for c in z["construcoes"]:
			if not bib.tem(str(c[0])): faltam.append(c[0])
		for p in z["personagens"]:
			if not bib.tem(str(p[0])): faltam.append(p[0])
	if not bib.tem(PIER): faltam.append(PIER)
	if not faltam.is_empty():
		push_error("falta na loja: %s (rode tools/mine_piece/registrar_na_loja.gd)" % str(faltam))
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var pecas: Array = []
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		if String(p["id"]).begins_with(PREFIXO) or p["id"] == BASE_ID:
			trocadas += 1
			continue
		pecas.append(p)
	for p: Dictionary in pecas:
		if p["tipo"] != "terreno":
			continue
		var t: Vector3 = p["tamanho"]
		if tamanho_y == 0.0:
			tamanho_y = t.y
		if not is_equal_approx(t.y, tamanho_y) or not is_equal_approx(p["posicao"].y - t.y * 0.5, BASE_DOS_BLOCOS):
			push_error("blocos de terreno com fundo/altura diferentes (%s)" % p["id"])
			quit(1)
			return
	if tamanho_y == 0.0:
		push_error("o mapa não tem relevo: gere a ilha inicial antes")
		quit(1)
		return

	var t0 := Time.get_ticks_msec()
	_preparar()
	_relevo()
	var novas: Array[Dictionary] = []
	novas.append({"id": BASE_ID, "tipo": "caixa", "grupo": GRUPO, "posicao": Vector3(CENTRO.x, -1.0, CENTRO.y),
		"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(MEIA * 2.0, 2.0, MEIA * 2.0), "cor": Color("#41a05d"),
		"material": "grade", "grade_celula": 4.0, "colisao": true})
	novas.append_array(_blocos_de_terreno())
	novas.append_array(_anel_de_praia())
	novas.append(_pier(bib))
	novas.append_array(_construcoes(bib))
	novas.append_array(_personagens(bib))
	pecas.append_array(novas)

	var grupos: Array = []
	var meus := {GRUPO: "", "eb_relevo": GRUPO, "eb_praia": GRUPO, "eb_porto": GRUPO, "eb_construcoes": GRUPO,
		"eb_personagens": GRUPO}
	for g: Dictionary in mapa["grupos"]:
		if not meus.has(g["id"]):
			grupos.append(g)
	for id in meus:
		grupos.append({"id": id, "pai": meus[id]})
	mapa["grupos"] = grupos
	mapa["pecas"] = pecas
	var validado := MapaArquivo.validar(_cru(mapa))
	if not validado["ok"]:
		push_error("mapa gerado não valida: %s" % str(validado["erros"]).left(600))
		quit(1)
		return
	if saida == MAPA:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BACKUPS))
		var copia := BACKUPS.path_join("baseplate_antes_east_blue_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			print("EAST_BLUE recusado: o mapa mudou durante a execução — mapa NÃO gravado")
			quit(1)
			return
	var err := MapaArquivo.salvar(saida, validado["mapa"])
	print("EAST_BLUE %d peças (trocadas %d) ms=%d -> %s (%s)" % [novas.size(), trocadas, Time.get_ticks_msec() - t0, saida, error_string(err)])
	for k in contagem:
		print("  %-16s %s" % [k, str(contagem[k])])
	quit(0 if err == OK else 1)


# =================================================================== RELEVO
func _preparar() -> void:
	ruido.seed = SEMENTE
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 1.0 / 70.0
	ruido_fino.seed = SEMENTE + 1
	ruido_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_fino.frequency = 1.0 / 24.0
	# Trilhas: píer → porto → Loguetown; Loguetown → cada zona.
	var porto: Vector2 = ZONAS["porto"]["centro"]
	var hub: Vector2 = ZONAS[HUB]["centro"]
	trilhas.append([Vector2(-MEIA, 0), porto])
	trilhas.append([porto, hub])
	for id in ZONAS:
		if id != HUB and id != "porto":
			trilhas.append([hub, ZONAS[id]["centro"]])


func _relevo() -> void:
	H.resize(pontos * pontos)
	D_trilha.resize(pontos * pontos)
	for j in pontos:
		for i in pontos:
			var l := _local(i, j)
			var idx := j * pontos + i
			var h := _altura_bruta(l)
			# Praças planas: a altura do chão no centro da zona, com borda suave.
			for z: Dictionary in ZONAS.values():
				var c: Vector2 = z["centro"]
				var r: float = z["raio"]
				var alvo_h := maxf(_altura_bruta(c), 1.0) * smoothstep(0.0, COSTA, _borda(c))
				h = lerpf(alvo_h, h, smoothstep(r * 1.05, r * 1.6, l.distance_to(c)))
			var d := INF
			for s in trilhas:
				d = minf(d, _dist_segmento(l, s[0], s[1]))
			D_trilha[idx] = d
			H[idx] = maxf(h, ACIMA_DA_BASE)
	_pintar_solo()


func _dist_segmento(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _local(i: int, j: int) -> Vector2:
	return Vector2(-MEIA + i * PASSO, -MEIA + j * PASSO)


func _borda(l: Vector2) -> float:
	return minf(MEIA - absf(l.x), MEIA - absf(l.y))


func _altura_bruta(l: Vector2) -> float:
	var h := 1.2 + 1.6 * (ruido.get_noise_2dv(l) * 0.5 + 0.5)
	for m in MORROS:
		var d := l.distance_to(m[0]) * (1.0 + 0.2 * ruido_fino.get_noise_2dv(l))
		h += float(m[2]) * (1.0 - smoothstep(0.0, float(m[1]), d))
	return h * smoothstep(0.0, COSTA, _borda(l))


## Solo: 0 grama, 2 terra (praças e trilhas), 3 areia (costa).
func _pintar_solo() -> void:
	var n := pontos - 1
	S.resize(n * n)
	var conta := {0: 0, 2: 0, 3: 0}
	for j in n:
		for i in n:
			var l := _local(i, j) + Vector2(PASSO, PASSO) * 0.5
			var d_trilha := (D_trilha[j * pontos + i] + D_trilha[(j + 1) * pontos + i + 1]) * 0.5
			var na_praca := false
			for z: Dictionary in ZONAS.values():
				if l.distance_to(z["centro"]) < float(z["raio"]):
					na_praca = true
			var codigo := 0
			if _borda(l) < 5.0 + 3.0 * (ruido_fino.get_noise_2dv(l) * 0.5 + 0.5):
				codigo = 3
			elif d_trilha < LARGURA_TRILHA or na_praca:
				codigo = 2
			S[j * n + i] = codigo
			conta[codigo] += 1
	contagem["solo (células)"] = "grama %d · terra %d · areia %d" % [conta[0], conta[2], conta[3]]


func _fracao(h: float) -> int:
	return clampi(int(round((h - BASE_DOS_BLOCOS) / tamanho_y * TerrenoDoMapa.ESCALA)), 0, TerrenoDoMapa.ESCALA)


# =================================================================== BLOCOS
func _blocos_de_terreno() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var por_lado := int(2.0 * MEIA / BLOCO)
	for tj in por_lado:
		for ti in por_lado:
			var alturas := PackedInt32Array()
			alturas.resize((CELULAS + 1) * (CELULAS + 1))
			for j in CELULAS + 1:
				for i in CELULAS + 1:
					alturas[j * (CELULAS + 1) + i] = _fracao(H[(tj * CELULAS + j) * pontos + (ti * CELULAS + i)])
			var solo := PackedByteArray()
			solo.resize(CELULAS * CELULAS)
			for j in CELULAS:
				for i in CELULAS:
					solo[j * CELULAS + i] = S[(tj * CELULAS + j) * (pontos - 1) + ti * CELULAS + i]
			var p := {"id": "%srelevo_%d_%d" % [PREFIXO, ti, tj], "tipo": "terreno", "grupo": "eb_relevo",
				"posicao": Vector3(CENTRO.x - MEIA + (ti + 0.5) * BLOCO, BASE_DOS_BLOCOS + tamanho_y * 0.5,
					CENTRO.y - MEIA + (tj + 0.5) * BLOCO),
				"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(BLOCO, tamanho_y, BLOCO),
				"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true,
				"relevo": {"celulas": CELULAS, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}}
			lista.append(p)
			blocos["%d_%d" % [ti, tj]] = p
	contagem["blocos"] = lista.size()
	return lista


## Y do mundo do chão como a MALHA desenha.
func _chao(l: Vector2) -> float:
	var ti := clampi(int(floor((l.x + MEIA) / BLOCO)), 0, int(2.0 * MEIA / BLOCO) - 1)
	var tj := clampi(int(floor((l.y + MEIA) / BLOCO)), 0, int(2.0 * MEIA / BLOCO) - 1)
	var p: Dictionary = blocos["%d_%d" % [ti, tj]]
	var pos: Vector3 = p["posicao"]
	var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], clampf(CENTRO.x + l.x - pos.x, -BLOCO * 0.5, BLOCO * 0.5),
		clampf(CENTRO.y + l.y - pos.z, -BLOCO * 0.5, BLOCO * 0.5))
	return pos.y + y


func _anel_de_praia() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var por_lado := int(2.0 * MEIA / BLOCO)
	var w := LARGURA_PRAIA
	var faixas: Array = []
	for k in por_lado:
		var ao_longo := -MEIA + (k + 0.5) * BLOCO
		faixas.append([Vector2(MEIA + w * 0.5, ao_longo), Vector2(w, BLOCO)])
		faixas.append([Vector2(-MEIA - w * 0.5, ao_longo), Vector2(w, BLOCO)])
		faixas.append([Vector2(ao_longo, -MEIA - w * 0.5), Vector2(BLOCO, w)])
		faixas.append([Vector2(ao_longo, MEIA + w * 0.5), Vector2(BLOCO, w)])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			faixas.append([Vector2(sx * (MEIA + w * 0.5), sz * (MEIA + w * 0.5)), Vector2(w, w)])
	for f in faixas:
		var c: Vector2 = f[0]
		var t: Vector2 = f[1]
		var alturas := PackedInt32Array()
		alturas.resize((CELULAS + 1) * (CELULAS + 1))
		for j in CELULAS + 1:
			for i in CELULAS + 1:
				var l := Vector2(c.x + (float(i) / CELULAS - 0.5) * t.x, c.y + (float(j) / CELULAS - 0.5) * t.y)
				alturas[j * (CELULAS + 1) + i] = _fracao(_altura_praia(l))
		var solo := PackedByteArray()
		solo.resize(CELULAS * CELULAS)
		solo.fill(3)
		lista.append({"id": "%spraia_%d" % [PREFIXO, lista.size()], "tipo": "terreno", "grupo": "eb_praia",
			"posicao": Vector3(CENTRO.x + c.x, BASE_DOS_BLOCOS + tamanho_y * 0.5, CENTRO.y + c.y),
			"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(t.x, tamanho_y, t.y), "cor": Color.WHITE,
			"material": "liso", "grade_celula": 4.0, "colisao": true,
			"relevo": {"celulas": CELULAS, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}})
	contagem["praia"] = lista.size()
	return lista


func _altura_praia(l: Vector2) -> float:
	var b := Vector2(clampf(l.x, -MEIA, MEIA), clampf(l.y, -MEIA, MEIA))
	var borda := H[int(round((b.y + MEIA) / PASSO)) * pontos + int(round((b.x + MEIA) / PASSO))]
	var d := l.distance_to(b)
	if d <= 0.0:
		return borda
	var alcance := LARGURA_PRAIA * (0.75 + 0.35 * (ruido.get_noise_2d(l.x * 2.0, l.y * 2.0) * 0.5 + 0.5))
	return lerpf(borda, -1.3, smoothstep(0.0, alcance, d))


## Píer na costa oeste, na ponta da trilha, virado para a Ilha dos Macacos.
func _pier(bib: BibliotecaDeModelos) -> Dictionary:
	var t := bib.tamanho_padrao(PIER)
	var topo_deck := t.y - 2.14
	var x := CENTRO.x - MEIA - t.z * 0.5 - 2.0
	return {"id": PREFIXO + "pier", "tipo": "modelo", "modelo": PIER, "grupo": "eb_porto",
		"posicao": Vector3(x, DECK - topo_deck + t.y * 0.5, CENTRO.y), "rotacao_graus": Vector3(0, -90, 0),
		"tamanho": t, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true}


# =================================================================== ZONAS
## O menor chão sob a pegada (a construção não flutua na encosta da borda da praça).
func _chao_minimo(c: Vector2, meia: Vector2) -> float:
	var y := INF
	for dx in [-1.0, 0.0, 1.0]:
		for dz in [-1.0, 0.0, 1.0]:
			y = minf(y, _chao(c + Vector2(dx * meia.x, dz * meia.y)))
	return y


func _construcoes(bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	for zid in ZONAS:
		var z: Dictionary = ZONAS[zid]
		for k in z["construcoes"].size():
			var c: Array = z["construcoes"][k]
			var base := bib.tamanho_padrao(str(c[0]))
			var escala := float(c[1]) / maxf(base.x, 0.01)
			var t := base * escala
			var l: Vector2 = z["centro"] + (c[2] as Vector2)
			var y := _chao_minimo(l, Vector2(t.x, t.z) * 0.4) - 0.15
			lista.append({"id": "%sconstrucao_%s_%d" % [PREFIXO, zid, k], "tipo": "modelo", "modelo": str(c[0]),
				"grupo": "eb_construcoes", "posicao": Vector3(CENTRO.x + l.x, y + t.y * 0.5, CENTRO.y + l.y),
				"rotacao_graus": Vector3(0, float(c[3]), 0), "tamanho": t, "cor": Color.WHITE, "material": "liso",
				"grade_celula": 4.0, "colisao": true})
	contagem["construções"] = lista.size()
	return lista


## Personagens em leque na praça, de frente para a trilha que chega do centro (o chefe
## no meio, à frente; os outros atrás, em arco).
func _personagens(bib: BibliotecaDeModelos) -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var hub: Vector2 = ZONAS[HUB]["centro"]
	for zid in ZONAS:
		var z: Dictionary = ZONAS[zid]
		var c: Vector2 = z["centro"]
		var chegada := (hub - c).normalized() if zid != HUB else Vector2(-1, 0)
		if zid == "porto":
			chegada = Vector2(-1, 0)              # os aliados olham para o píer
		var lado := Vector2(-chegada.y, chegada.x)
		var yaw := rad_to_deg(atan2(-chegada.x, -chegada.y))
		var todos: Array[String] = []
		for p in z["personagens"]:
			for n in int(p[1]):
				todos.append(str(p[0]))
		for k in todos.size():
			var modelo := todos[k]
			var l: Vector2
			if k == 0:
				l = c + chegada * 4.0
			else:
				var fila := int((k - 1) / 5)
				var pos_na_fila := (k - 1) % 5 - 2
				l = c - chegada * (2.0 + 3.5 * fila) + lado * (pos_na_fila * 3.0)
			var t := bib.tamanho_padrao(modelo)
			var y := _chao(l)
			lista.append({"id": "%spersonagem_%s_%d" % [PREFIXO, zid, k], "tipo": "modelo", "modelo": modelo,
				"grupo": "eb_personagens", "posicao": Vector3(CENTRO.x + l.x, y + t.y * 0.5 + 0.02, CENTRO.y + l.y),
				"rotacao_graus": Vector3(0, yaw, 0), "tamanho": t, "cor": Color.WHITE, "material": "liso",
				"grade_celula": 4.0, "colisao": false})
	contagem["personagens"] = lista.size()
	return lista


func _cru(mapa: Dictionary) -> Dictionary:
	return JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"],
		"pecas": mapa["pecas"], "grupos": mapa["grupos"]}))
