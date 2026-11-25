extends RefCounted
## Pontos medidos nos GLBs, antes da escala do editor. +Z é popa no ator.
## As três casas náuticas têm portas/fachadas e casco como telhado: continuam cenário.
const CASAS := ["house", "house-2kytqgs4rh", "house-g7esjlfi4v"]

## Os 3 barcos medidos à mão: saíram da venda em 18/10/2026 (os 12 do Mine Piece entraram);
## o modelo e o perfil ficam para quem já comprou um.
const LEGADO := ["boat", "small_ship", "ship"]

static func e_navegavel(id: String) -> bool:
	return not id in CASAS


## Navio ANCORADO no mapa (grupo terminado em "_ancorados", 18/10/2026): cenário da ilha —
## parado, com a tripulação da facção, sob o desenho por distância; não vira barco pilotável
## (senão o jogador levaria de graça o navio da Marinha). À venda, os mesmos modelos navegam.
static func ancorado(p: Dictionary) -> bool:
	return String(p.get("grupo", "")).ends_with("_ancorados")


## Perfil gravado pelo conversor das estruturas do Mine Piece (`<id>.perfil_navio.json`,
## metros na origem do molde: linha d'água, contorno do casco, convés, leme, saídas).
static func do_mod(bib: BibliotecaDeModelos, id: String) -> Dictionary:
	var caminho := bib.raiz.path_join(id + ".perfil_navio.json")
	if not FileAccess.file_exists(caminho):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
	if not (d is Dictionary) or not ((d as Dictionary).get("casco") is Array) or (d["casco"] as Array).size() < 3 \
			or not (d.get("leme") is Array) or not (d.get("saidas") is Array):
		return {}
	return d


## Navio do mod: o modelo É o navio (escala 1:1), proa = lado oposto ao timão; o convés
## andável é a malha `Colisao` do próprio modelo (`Barco._criar_conves_do_modelo`).
static func _criar_do_mod(bib: BibliotecaDeModelos, id: String, tamanho: Vector3, d: Dictionary) -> Dictionary:
	var info := bib.info(id)
	var bruto: Vector3 = info["tamanho"]
	var escala := tamanho / bruto
	var linha := float(d.get("linha", 0.88))
	var leme_m := Vector3(d["leme"][0], d["leme"][1], d["leme"][2])
	var yaw := 0.0 if leme_m.z >= 0.0 else PI
	var giro := Basis(Vector3.UP, yaw)
	var origem := Vector3(0, linha, 0)
	var casco := PackedVector2Array()
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for p in d["casco"]:
		var v: Vector3 = giro * ((Vector3(float(p[0]), linha, float(p[1])) - origem) * escala)
		var q := Vector2(v.x, v.z)
		casco.append(q)
		minp = minp.min(q)
		maxp = maxp.max(q)
	# Calado da FÍSICA limitado a 1,5 m: o casco desenhado desce até o fundo do mod (o Merry
	# 3,5 m, o Moby Dick 8,8 m), mas assim não encalha no raso do porto. No raso, o casco
	# desenhado pode atravessar o fundo do mar — só visual.
	var calado := clampf(linha * escala.y, .08, 1.5)
	var conves := (float(d.get("conves", linha + 1.76)) - linha) * escala.y
	var leme_local := giro * ((leme_m - origem) * escala)
	var saidas: Array[Vector3] = []
	for s in d["saidas"]:
		saidas.append(giro * ((Vector3(float(s[0]), float(s[1]), float(s[2])) - origem) * escala))
	return {"yaw_modelo": yaw, "escala": escala, "origem_arquivo": origem, "centro_arquivo": info["centro"],
		"casco": casco, "calado": calado, "conves": conves, "leme": leme_local, "saidas": saidas,
		"tamanho_casco": Vector3(maxp.x - minp.x, calado + maxf(conves, leme_local.y), maxp.y - minp.y),
		"partes": [] as Array[Dictionary], "rampas": [] as Array[Dictionary], "borda": conves + .35, "bote": false,
		"conves_do_modelo": true}


static func criar(bib: BibliotecaDeModelos, id: String, tamanho: Vector3) -> Dictionary:
	var do_mod_ := do_mod(bib, id)
	if not do_mod_.is_empty():
		return _criar_do_mod(bib, id, tamanho, do_mod_)
	var info := bib.info(id)
	var bruto: Vector3 = info["tamanho"]
	var escala := tamanho / bruto
	var centro: Vector3 = info["centro"]
	var base := centro.y - bruto.y * .5
	var yaw := -PI * .5 if bruto.x > bruto.z else 0.0
	var linha := base + bruto.y * .22
	var piso := base + bruto.y * .36
	var origem := Vector3(centro.x, linha, centro.z)
	var comprimento := maxf(bruto.x, bruto.z)
	var largura := minf(bruto.x, bruto.z)
	var leme_bruto := Vector3(centro.x, piso, centro.z + comprimento * .28)
	if bruto.x > bruto.z:
		leme_bruto = Vector3(centro.x + comprimento * .28, piso, centro.z)
	var casco := PackedVector2Array()
	var extras: Array[Dictionary] = []
	match id:
		"boat":
			yaw = PI
			linha = .25
			piso = .46
			origem = Vector3(0, linha, -.3165)
			leme_bruto = Vector3(0, piso, -2.25)
			# Contorno do fundo interno; bordas são volumes separados.
			casco = PackedVector2Array([Vector2(-1.28,-3.39), Vector2(1.28,-3.39), Vector2(1.80,-1.8), Vector2(1.66,1.25), Vector2(0,2.71), Vector2(-1.66,1.25), Vector2(-1.80,-1.8)])
		"small_ship":
			yaw = -PI * .5
			linha = .4
			piso = .85
			origem = Vector3(-.12, linha, 0)
			leme_bruto = Vector3(1.79, piso, 0)
			casco = PackedVector2Array([Vector2(-2.3,0), Vector2(-1.58,-.94), Vector2(1.83,-.94), Vector2(2.08,-.65), Vector2(2.08,.65), Vector2(1.83,.94), Vector2(-1.58,.94)])
			# Barris laterais: impedem o casco de atravessar cais pelo lado.
			for lado in [-1.0, 1.0]:
				extras.append({"centro": Vector3(.47,.61,lado*1.31), "tamanho": Vector3(1.48,1.15,.91)})
		"ship":
			yaw = -PI * .5
			linha = 0.0
			piso = 1.02
			origem = Vector3(-.55, linha, 0)
			leme_bruto = Vector3(5.05,1.95,0)
			casco = PackedVector2Array([Vector2(-6.65,0), Vector2(-5.95,-1.45), Vector2(-3.0,-2.05), Vector2(3.7,-2.05), Vector2(5.65,-1.5), Vector2(5.65,1.5), Vector2(3.7,2.05), Vector2(-3.0,2.05), Vector2(-5.95,1.45)])
			extras.append({"centro": Vector3(-4.45,1.28,0), "tamanho": Vector3(4.0,.52,3.4)})
			extras.append({"centro": Vector3(4.46,1.485,0), "tamanho": Vector3(2.36,.93,3.55)})
			# Mastros e pedestal do timão, sem inventar uma caixa sobre o convés inteiro.
			for x in [-4.2,.43]:
				extras.append({"centro": Vector3(x,3.2,0), "tamanho": Vector3(.30,4.0,.30)})
			extras.append({"centro": Vector3(4.45,2.25,0), "tamanho": Vector3(.36,.60,.48)})
	if casco.is_empty():
		# Perfil conservador para um novo navio classificado: não deduz partes artísticas.
		for q in [Vector2(-.42,-.40),Vector2(.42,-.40),Vector2(.48,.24),Vector2(0,.48),Vector2(-.48,.24)]:
			casco.append(Vector2(centro.x + q.x * bruto.x, centro.z + q.y * bruto.z))
	var giro := Basis(Vector3.UP, yaw)
	var local_casco := PackedVector2Array()
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for p in casco:
		var v: Vector3 = giro * ((Vector3(p.x, linha, p.y) - origem) * escala)
		var q := Vector2(v.x, v.z)
		local_casco.append(q)
		minp = minp.min(q)
		maxp = maxp.max(q)
	var piso_local := (piso - linha) * escala.y
	var calado := maxf((linha - base) * escala.y, .08)
	var leme_local := giro * ((leme_bruto - origem) * escala)
	var partes: Array[Dictionary] = []
	for extra in extras:
		var e: Vector3 = extra["tamanho"] * escala
		var t := Vector3(absf(giro.x.x)*e.x + absf(giro.z.x)*e.z, e.y, absf(giro.x.z)*e.x + absf(giro.z.z)*e.z)
		partes.append({"centro": giro * ((extra["centro"] - origem) * escala), "tamanho": t})
	var rampas: Array[Dictionary] = []
	if id == "ship":
		# Passagens entre os três níveis do convés; sem degraus invisíveis de 1–2 m.
		for dados in [[-2.45,-1.70,1.54,1.02], [2.30,3.28,1.02,1.95]]:
			var pontos := PackedVector3Array()
			for x: float in [dados[0],dados[1]]:
				var y: float = dados[2] if x == dados[0] else dados[3]
				for z in [-.48,.48]:
					pontos.append(giro * ((Vector3(x,y,z)-origem)*escala))
					pontos.append(giro * ((Vector3(x,.98,z)-origem)*escala))
			rampas.append({"pontos": pontos})
	# Saída ao lado do comando, no mesmo piso; ponto dos PÉS, nunca centro da cápsula.
	var saidas: Array[Vector3] = []
	var deslocamento := clampf((maxp.x - minp.x) * .23, .55, 1.25)
	for lado in [-1.0,1.0]:
		saidas.append(leme_local + Vector3(lado * deslocamento,0,-.25))
	var tamanho_casco := Vector3(maxp.x-minp.x, calado+maxf(piso_local,leme_local.y), maxp.y-minp.y)
	# Barris e canhões participam da margem de aproximação, sem alargar o piso.
	if id == "small_ship":
		tamanho_casco.x = bruto.z * escala.z
	return {"yaw_modelo": yaw, "escala": escala, "origem_arquivo": origem,
		"centro_arquivo": centro, "casco": local_casco, "calado": calado,
		"conves": piso_local, "leme": leme_local, "saidas": saidas,
		"tamanho_casco": tamanho_casco, "partes": partes, "rampas": rampas,
		"borda": (1.64-linha)*escala.y if id == "boat" else piso_local + .35,
		"bote": id == "boat"}
