extends SceneTree
# ============================================================================
#  ILHA DOS MACACOS — a 2ª ilha do Modo História (08/10/2026). Idempotente.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/gerar_ilha_dos_macacos.gd [-- --saida=<caminho>]
#
#  Pedido do dono: "adicionar mais uma ilha a ilha dos macacos, está ilha ficará
#  afastada da ilha atual e será repleta de arvores gigantes". Escolhas dele: ~1,5 km
#  (3 a 5 min de barco) e, POR ENQUANTO, sem as árvores. Plano e decisões em
#  docs/ILHA_DOS_MACACOS_PLANO.md.
#
#  O que grava no MAPA VIVO (sem `--saida`):
#    • `baseplate_macacos`: placa de 256 × 256 m com centro em (1500, 0), a leste do
#      porto (o `Oceano` e o `FundoDoMar` tratam cada placa como ilha);
#    • relevo em 4 × 4 blocos de 64 m (32 células, 2 m) com o MESMO fundo (−1,5) e a
#      MESMA altura de bloco da ilha inicial — o pincel de relevo do editor exige isso;
#      morros até ~24 m, uma clareira no meio e uma trilha de terra do píer até ela;
#      chão de mata onde as árvores gigantes vão entrar depois;
#    • o anel de praia (a mesma conta da ilha inicial: `gerar_ilha.gd`, `_anel_de_praia`);
#    • um píer (dock_long) na costa oeste, virado para a ilha inicial, na mesma altura
#      do píer do porto;
#    • 4 bandos de macacos (`area_animais`).
#  Grupos: "ilha_dos_macacos" e, dentro dele, relevo, praia, porto e animais.
#  Troca SÓ as peças com prefixo `macacos_` e a `baseplate_macacos` (rodar de novo não
#  duplica), guarda uma cópia do mapa antes (uma por versão) e NÃO grava se o arquivo
#  mudou durante a execução (outra frente editando o mapa).
#
#  ⚠️ `gerar_ilha.gd` (a ilha inicial) regrava o mapa INTEIRO só com o que ele gera:
#  rodá-lo apaga esta ilha (e os bandidos, a natureza...). Depois dele, rode esta de novo.
# ============================================================================

const MAPA := "res://mapas/historia/baseplate.json"
const BACKUPS := "res://art_src/backups/mapa_historia"
const PREFIXO := "macacos_"
const BASE_ID := "baseplate_macacos"
const GRUPO := "ilha_dos_macacos"
const SEMENTE := 81026

const Layout := preload("res://tools/mapa_ilha/layout_macacos.gd")
## 22/11/2026 (v2, docs/ILHA_DOS_MACACOS_V2_PLANO.md): vila plana, sítios planos e 5 estradas (`layout_macacos.gd`); sem píer, lojas ou plataformas.
const PREFIXO_LOJAS_ANTIGAS := "mpi_ilha_dos_macacos_"
const CENTRO := Vector2(1500, 0)
const MEIA := 128.0
const BLOCO := 64.0
const CELULAS := 32
const PASSO := BLOCO / CELULAS
## Mesmos números da ilha inicial (`gerar_ilha.gd`).
const BASE_DOS_BLOCOS := -1.5
const ACIMA_DA_BASE := 0.04
const LARGURA_PRAIA := 24.0
const COSTA := 34.0                    # o relevo desce até a borda nesta faixa

## Morros: centro (local à ilha), raio e altura. O maior a nordeste, longe do píer.
const MORROS := [
	[Vector2(40, -38), 62.0, 21.0],
	[Vector2(50, 52), 46.0, 13.0],
	[Vector2(-60, -62), 38.0, 8.0],
	[Vector2(-52, 64), 34.0, 6.0],
]
## Bandos de macacos (o "Macaco" da loja, territorial).
const ESPECIE := "monkey_-_animated_low_poly"
const BANDOS := [
	{"id": "noroeste", "centro": Vector2(-62, -40), "quantidade": 3},
	{"id": "nordeste", "centro": Vector2(78, -70), "quantidade": 3},
	{"id": "sudeste", "centro": Vector2(42, 78), "quantidade": 3},
	{"id": "sudoeste", "centro": Vector2(-58, 56), "quantidade": 3},
]
const TAMANHO_BANDO := Vector2(46, 46)

var pontos := int(2.0 * MEIA / PASSO) + 1
var H := PackedFloat32Array()          # altura (m acima da baseplate) por ponto
var S := PackedByteArray()             # solo por célula
var D_trilha := PackedFloat32Array()   # distância à trilha por ponto
var ruido := FastNoiseLite.new()
var ruido_fino := FastNoiseLite.new()
var ruido_mata := FastNoiseLite.new()
var estradas: Array[PackedVector2Array] = []
var perfis: Array[PackedFloat32Array] = []
var tamanho_y := 0.0
var blocos := {}                       # "i_j" -> peça de terreno
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
	if bib.ficha_de_animal(ESPECIE).is_empty():
		push_error("falta na loja a ficha de %s" % ESPECIE)
		quit(1)
		return
	var mapa: Dictionary = lido["mapa"]
	var pecas: Array = []
	var trocadas := 0
	for p: Dictionary in mapa["pecas"]:
		if String(p["id"]).begins_with(PREFIXO) or p["id"] == BASE_ID or String(p["id"]).begins_with(PREFIXO_LOJAS_ANTIGAS):
			trocadas += 1
			continue
		pecas.append(p)
	# Altura de bloco: a MESMA de todos os blocos do mapa (emenda e pincel de relevo).
	for p: Dictionary in pecas:
		if p["tipo"] != "terreno":
			continue
		var t: Vector3 = p["tamanho"]
		var fundo: float = p["posicao"].y - t.y * 0.5
		if tamanho_y == 0.0:
			tamanho_y = t.y
		if not is_equal_approx(t.y, tamanho_y) or not is_equal_approx(fundo, BASE_DOS_BLOCOS):
			push_error("blocos de terreno com fundo/altura diferentes (%s): a conta da emenda não fecha" % p["id"])
			quit(1)
			return
	if tamanho_y == 0.0:
		push_error("o mapa não tem relevo: gere a ilha inicial antes")
		quit(1)
		return

	var t0 := Time.get_ticks_msec()
	_preparar_ruido()
	_relevo()
	var maior := 0.0
	for h in H:
		maior = maxf(maior, h)
	if maior > BASE_DOS_BLOCOS + tamanho_y - 1.0:
		push_error("morro de %.1f m não cabe no bloco (%.1f m)" % [maior, tamanho_y])
		quit(1)
		return
	var novas: Array[Dictionary] = []
	novas.append({"id": BASE_ID, "tipo": "caixa", "grupo": GRUPO, "posicao": Vector3(CENTRO.x, -1.0, CENTRO.y),
		"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(MEIA * 2.0, 2.0, MEIA * 2.0), "cor": Color("#41a05d"),
		"material": "grade", "grade_celula": 4.0, "colisao": true})
	novas.append_array(_blocos_de_terreno())
	novas.append_array(_anel_de_praia())
	for b: Dictionary in BANDOS:
		var area := _bando(b)
		if area.is_empty():
			print("MACACOS recusado: bando %s fora do relevo (mapa NÃO gravado)" % b["id"])
			quit(1)
			return
		novas.append(area)
	pecas.append_array(novas)

	var grupos: Array = []
	var meus := {GRUPO: "", "macacos_relevo": GRUPO, "macacos_praia": GRUPO, "macacos_porto": GRUPO,
		"macacos_animais": GRUPO}
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
		var copia := BACKUPS.path_join("baseplate_antes_macacos_%s.json" % original.sha256_text().left(12))
		if not FileAccess.file_exists(copia):
			var f := FileAccess.open(copia, FileAccess.WRITE)
			f.store_string(original)
			f.close()
		print("COPIA ", copia)
		if FileAccess.get_file_as_string(MAPA) != original:
			print("MACACOS recusado: o mapa mudou durante a execução (outra frente?) — mapa NÃO gravado")
			quit(1)
			return
	var err := MapaArquivo.salvar(saida, validado["mapa"])
	print("MACACOS %d peças (trocadas %d) altura_max=%.1f m tamanho_y=%.1f ms=%d -> %s (%s)" % [
		novas.size(), trocadas, maior, tamanho_y, Time.get_ticks_msec() - t0, saida, error_string(err)])
	for k in contagem:
		print("  %-14s %s" % [k, str(contagem[k])])
	quit(0 if err == OK else 1)


# =================================================================== RELEVO
func _preparar_ruido() -> void:
	ruido.seed = SEMENTE
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 1.0 / 70.0
	ruido_fino.seed = SEMENTE + 1
	ruido_fino.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_fino.frequency = 1.0 / 24.0
	ruido_mata.seed = SEMENTE + 2
	ruido_mata.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido_mata.frequency = 1.0 / 60.0
	# Estradas suaves: uma curva por estrada, amostrada a cada passo da grade.
	estradas.clear()
	for nome in Layout.ESTRADAS:
		var pts: Array = Layout.ESTRADAS[nome]
		var curva := Curve2D.new()
		for k in pts.size():
			var antes: Vector2 = pts[maxi(k - 1, 0)]
			var depois: Vector2 = pts[mini(k + 1, pts.size() - 1)]
			var alca := (depois - antes) * 0.25
			curva.add_point(pts[k], -alca, alca)
		estradas.append(curva.tessellate_even_length(6, PASSO))


func _relevo() -> void:
	H.resize(pontos * pontos)
	D_trilha.resize(pontos * pontos)
	for j in pontos:
		for i in pontos:
			H[j * pontos + i] = _altura_bruta(_local(i, j))
	# Estradas: perfil suavizado ao longo de cada uma, e o chão perto puxado para esse perfil
	# (a mesma ideia das estradas da ilha inicial). Cada estrada parte da altura que o relevo tem lá; as pontas
	# (vila, sítios) já são planas, então o perfil emenda sem degrau.
	perfis.clear()
	var nomes: Array = Layout.ESTRADAS.keys()
	for r in estradas.size():
		var e: PackedVector2Array = estradas[r]
		var perfil := PackedFloat32Array()
		if Layout.SITIOS.has(nomes[r]):
			# Estrada da vila a um sítio: RAMPA contínua entre a borda do disco da vila e a do sítio (inclinação limitada), em vez de subir o morro e despencar.
			perfil = _perfil_em_rampa(e, Layout.SITIOS[nomes[r]])
		else:
			for p in e:
				perfil.append(_amostra(p))
			for passada in 4:
				var suave := perfil.duplicate()
				for k in perfil.size():
					var soma := 0.0
					var n := 0
					for o in range(maxi(k - 6, 0), mini(k + 7, perfil.size())):
						soma += perfil[o]
						n += 1
					suave[k] = soma / n
				perfil = suave
		# A suavização mistura a altura de fora da vila/sítio para dentro: prende o perfil de volta ao disco plano.
		for k in perfil.size():
			perfil[k] = _prender_ao_plano(e[k], perfil[k])
		perfis.append(perfil)
	for j in pontos:
		for i in pontos:
			var l := _local(i, j)
			var melhor := INF
			var h_trilha := 0.0
			for r in estradas.size():
				var e: PackedVector2Array = estradas[r]
				for k in e.size():
					var d := l.distance_squared_to(e[k])
					if d < melhor:
						melhor = d
						h_trilha = perfis[r][k]
			var d := sqrt(melhor)
			var idx := j * pontos + i
			D_trilha[idx] = d
			if d < 9.0:
				H[idx] = lerpf(H[idx], h_trilha, 1.0 - smoothstep(Layout.LARGURA_ESTRADA + 0.6, 9.0, d))
			H[idx] = maxf(_prender_ao_plano(l, H[idx]), ACIMA_DA_BASE)
	_pintar_solo()


## Altura (m) do disco plano de um sítio.
func _altura_do_sitio(sitio: Dictionary) -> float:
	var a: float = float(sitio["altura"])
	return a if a >= 0.0 else _relevo_natural(sitio["centro"]) * smoothstep(0.0, COSTA, _borda(sitio["centro"]))


## Perfil de uma estrada vila→sítio: plano até o raio plano da vila, rampa suave (smoothstep) até o raio plano do sítio, plano depois.
func _perfil_em_rampa(e: PackedVector2Array, sitio: Dictionary) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	var total := 0.0
	for k in e.size():
		if k > 0:
			total += e[k].distance_to(e[k - 1])
		dist.append(total)
	var h0 := Layout.VILA_ALTURA
	var h1 := _altura_do_sitio(sitio)
	var a := Layout.VILA_RAIO_PLANO
	var b := total - float(sitio["plano"])
	var perfil := PackedFloat32Array()
	for k in e.size():
		perfil.append(lerpf(h0, h1, smoothstep(0.0, 1.0, clampf((dist[k] - a) / maxf(b - a, 1.0), 0.0, 1.0))))
	return perfil


func _local(i: int, j: int) -> Vector2:
	return Vector2(-MEIA + i * PASSO, -MEIA + j * PASSO)


func _borda(l: Vector2) -> float:
	return minf(MEIA - absf(l.x), MEIA - absf(l.y))


## Altura antes das estradas: chão ondulado + morros (bordas irregulares pelo ruído fino) + vila e sítios aplainados;
## desce a 0 na faixa da costa.
func _altura_bruta(l: Vector2) -> float:
	var h := _relevo_natural(l)
	var dv := l.distance_to(Layout.VILA)
	h = lerpf(Layout.VILA_ALTURA, h, smoothstep(Layout.VILA_RAIO_PLANO, Layout.VILA_RAIO_PLANO * 1.5, dv))
	for nome in Layout.SITIOS:
		var s: Dictionary = Layout.SITIOS[nome]
		var d := l.distance_to(s["centro"])
		h = lerpf(_altura_do_sitio(s), h, smoothstep(float(s["plano"]), float(s["transicao"]), d))
	return h * smoothstep(0.0, COSTA, _borda(l))


## `h` puxado para a altura do disco plano (vila ou sítio) de que `l` está dentro/perto: exatamente plano até o raio plano, relevo de volta na transição.
## Usado DEPOIS das estradas, que de outro modo entortam o disco.
func _prender_ao_plano(l: Vector2, h: float) -> float:
	var dv := l.distance_to(Layout.VILA)
	h = lerpf(Layout.VILA_ALTURA, h, smoothstep(Layout.VILA_RAIO_PLANO, Layout.VILA_RAIO_PLANO * 1.5, dv))
	for nome in Layout.SITIOS:
		var s: Dictionary = Layout.SITIOS[nome]
		h = lerpf(_altura_do_sitio(s), h, smoothstep(float(s["plano"]), float(s["transicao"]), l.distance_to(s["centro"])))
	return h


## O relevo sem vila, sítios nem estradas (chão ondulado + morros).
func _relevo_natural(l: Vector2) -> float:
	var h := 1.2 + 1.8 * (ruido.get_noise_2dv(l) * 0.5 + 0.5)
	for m in MORROS:
		var d := l.distance_to(m[0]) * (1.0 + 0.2 * ruido_fino.get_noise_2dv(l))
		h += float(m[2]) * (1.0 - smoothstep(0.0, float(m[1]), d))
	return h


## Altura bilinear da grade.
func _amostra(l: Vector2) -> float:
	var u := clampf((l.x + MEIA) / PASSO, 0.0, pontos - 1.001)
	var w := clampf((l.y + MEIA) / PASSO, 0.0, pontos - 1.001)
	var i := int(u)
	var j := int(w)
	var a := lerpf(H[j * pontos + i], H[j * pontos + i + 1], u - i)
	var b := lerpf(H[(j + 1) * pontos + i], H[(j + 1) * pontos + i + 1], u - i)
	return lerpf(a, b, w - j)


## Solo: 0 grama (vila e sítios), 2 terra (estradas), 3 areia (costa), 4 rocha (Trono), 5 chão de mata (onde as
## árvores gigantes entram).
## Código do solo se `l` está dentro da vila ou de um sítio plano (raio plano + 1 m); -1 fora.
func _solo_do_sitio(l: Vector2) -> int:
	if l.distance_to(Layout.VILA) < Layout.VILA_RAIO_PLANO:
		return 0
	for nome in Layout.SITIOS:
		var s: Dictionary = Layout.SITIOS[nome]
		if l.distance_to(s["centro"]) < float(s["plano"]) + 1.0:
			return int(s["solo"])
	return -1


func _pintar_solo() -> void:
	var n := pontos - 1
	S.resize(n * n)
	var conta := {0: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for j in n:
		for i in n:
			var l := _local(i, j) + Vector2(PASSO, PASSO) * 0.5
			var borda := _borda(l)
			var d_trilha := (D_trilha[j * pontos + i] + D_trilha[(j + 1) * pontos + i + 1]) * 0.5
			var codigo := 0
			var sitio := _solo_do_sitio(l)
			if borda < 5.0 + 3.0 * (ruido_fino.get_noise_2dv(l) * 0.5 + 0.5):
				codigo = 3
			elif d_trilha < Layout.LARGURA_ESTRADA and sitio != 4:
				codigo = 2
			elif sitio >= 0:
				codigo = sitio
			elif borda > 18.0 and d_trilha > 6.0 and ruido_mata.get_noise_2dv(l) > -0.25:
				codigo = 5
			S[j * n + i] = codigo
			conta[codigo] += 1
	contagem["solo (células)"] = "grama %d · terra %d · areia %d · rocha %d · mata %d" % [conta[0], conta[2], conta[3], conta[4], conta[5]]


## Altura (m) → fração inteira do bloco. A MESMA conta de `gerar_ilha.gd`.
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
			var p := {"id": "%srelevo_%d_%d" % [PREFIXO, ti, tj], "tipo": "terreno", "grupo": "macacos_relevo",
				"posicao": Vector3(CENTRO.x - MEIA + (ti + 0.5) * BLOCO, BASE_DOS_BLOCOS + tamanho_y * 0.5,
					CENTRO.y - MEIA + (tj + 0.5) * BLOCO),
				"rotacao_graus": Vector3.ZERO, "tamanho": Vector3(BLOCO, tamanho_y, BLOCO),
				"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true,
				"relevo": {"celulas": CELULAS, "alturas": alturas, "solo": solo, "agua": PackedInt32Array()}}
			lista.append(p)
			blocos["%d_%d" % [ti, tj]] = p
	contagem["blocos"] = lista.size()
	return lista


## Y do mundo do chão como a MALHA desenha (só dentro da placa).
func _chao(l: Vector2) -> float:
	var ti := clampi(int(floor((l.x + MEIA) / BLOCO)), 0, int(2.0 * MEIA / BLOCO) - 1)
	var tj := clampi(int(floor((l.y + MEIA) / BLOCO)), 0, int(2.0 * MEIA / BLOCO) - 1)
	var p: Dictionary = blocos["%d_%d" % [ti, tj]]
	var pos: Vector3 = p["posicao"]
	var y := TerrenoDoMapa.altura_local(p["relevo"], p["tamanho"], clampf(CENTRO.x + l.x - pos.x, -BLOCO * 0.5, BLOCO * 0.5),
		clampf(CENTRO.y + l.y - pos.z, -BLOCO * 0.5, BLOCO * 0.5))
	return pos.y + y


# --------------------------------------------------------------------- praia
## Anel de areia em volta da placa, da altura EXATA da borda da ilha até abaixo do mar:
## a mesma conta de `gerar_ilha.gd` (`_anel_de_praia`/`_altura_praia`).
func _anel_de_praia() -> Array[Dictionary]:
	var lista: Array[Dictionary] = []
	var por_lado := int(2.0 * MEIA / BLOCO)
	var w := LARGURA_PRAIA
	var faixas: Array = []
	for k in por_lado:
		var ao_longo := -MEIA + (k + 0.5) * BLOCO
		faixas.append([Vector2(MEIA + w * 0.5, ao_longo), Vector2(w, BLOCO)])     # leste
		faixas.append([Vector2(-MEIA - w * 0.5, ao_longo), Vector2(w, BLOCO)])    # oeste
		faixas.append([Vector2(ao_longo, -MEIA - w * 0.5), Vector2(BLOCO, w)])    # norte
		faixas.append([Vector2(ao_longo, MEIA + w * 0.5), Vector2(BLOCO, w)])     # sul
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
		lista.append({"id": "%spraia_%d" % [PREFIXO, lista.size()], "tipo": "terreno", "grupo": "macacos_praia",
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


# -------------------------------------------------------------------- macacos
## Volume do bando: abraça o chão sob a área, do mais baixo ao mais alto, +6 m (a mesma
## regra de `colocar_areas_de_animais.gd`).
func _bando(b: Dictionary) -> Dictionary:
	var c: Vector2 = b["centro"]
	var lo := INF
	var hi := -INF
	for i in 9:
		for j in 9:
			var l := c + Vector2((i / 8.0 - 0.5) * TAMANHO_BANDO.x, (j / 8.0 - 0.5) * TAMANHO_BANDO.y)
			if _borda(l) < 0.0:
				return {}
			var y := _chao(l)
			lo = minf(lo, y)
			hi = maxf(hi, y)
	var altura := (hi - lo) + 6.0
	contagem["bando " + str(b["id"])] = "chão %.1f..%.1f m" % [lo, hi]
	return {"id": "%sanimais_%s" % [PREFIXO, b["id"]], "tipo": "area_animais", "grupo": "macacos_animais",
		"posicao": Vector3(CENTRO.x + c.x, lo - 1.0 + altura * 0.5, CENTRO.y + c.y), "rotacao_graus": Vector3.ZERO,
		"tamanho": Vector3(TAMANHO_BANDO.x, altura, TAMANHO_BANDO.y), "cor": Color("#40f0a8"), "material": "liso",
		"grade_celula": 4.0, "colisao": false, "especie": ESPECIE, "quantidade": int(b["quantidade"])}


## Normalizado → dado cru do JSON (o validador quer o formato do arquivo).
func _cru(mapa: Dictionary) -> Dictionary:
	return JSON.parse_string(MapaArquivo.para_texto({"nome": mapa["nome"], "spawn": mapa["spawn"],
		"pecas": mapa["pecas"], "grupos": mapa["grupos"]}))
