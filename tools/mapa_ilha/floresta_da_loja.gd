extends RefCounted
## Substituição pontual: só os aglomerados antigos do grupo floresta.
## Lê o relevo atual; não regenera ilha, rios, estradas ou estruturas.
const ANTIGOS := ["trees", "pine_trees"]
const PREFIXO := "floresta_loja_"
const FOLHOSAS := ["floresta_tree_oak_large_green", "floresta_tree_oak_medium_green",
	"floresta_tree_oak_hero_green", "floresta_tree_birch_large_green",
	"floresta_tree_birch_medium_green", "floresta_tree_elm_green"]
const CONIFERAS := ["floresta_tree_pine_large", "floresta_tree_pine_medium",
	"floresta_tree_pine_hero", "floresta_tree_spruce_large", "floresta_tree_spruce_medium"]
const ARBUSTOS := ["floresta_bush_medium", "floresta_bush_clumps_small",
	"floresta_bush_with_flowers", "floresta_bush_small"]
const CHAO := ["floresta_grass_large", "floresta_grass_medium", "floresta_flowers_red",
	"floresta_mushroom_brown_large"]
var _rng := RandomNumberGenerator.new()
var _terrenos: Array[Dictionary] = []
var _obstaculos: Array[Dictionary] = []
var _novas: Array[Dictionary] = []
var _plantadas: Array[Dictionary] = []
var _bib: BibliotecaDeModelos

static func e_antiga(p: Dictionary) -> bool:
	return p.get("grupo") == "floresta" and p.get("modelo") in ANTIGOS

func refazer(original: Dictionary, bib: BibliotecaDeModelos) -> Dictionary:
	_bib = bib
	_rng.seed = 8102026
	_terrenos.clear()
	_obstaculos.clear()
	_novas.clear()
	_plantadas.clear()
	for id in FOLHOSAS + CONIFERAS + ARBUSTOS + CHAO:
		if not bib.tem(id): return {"ok": false, "erro": "Asset ausente: " + id}
	var mapa := original.duplicate(true)
	var antigas: Array[Dictionary] = []
	var preservadas: Array[Dictionary] = []
	for p: Dictionary in mapa.pecas:
		if e_antiga(p): antigas.append(p)
		else:
			preservadas.append(p)
			if p.tipo == "terreno": _terrenos.append(p)
			elif p.tipo == "modelo": _obstaculos.append(p)
	if antigas.is_empty(): return {"ok": true, "mapa": mapa, "removidas": 0, "novas": 0}
	antigas.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for antiga in antigas:
		var quantidade := clampi(roundi(antiga.tamanho.x * antiga.tamanho.z / 80.0), 2, 4)
		var paleta: Array = CONIFERAS if antiga.modelo == "pine_trees" else FOLHOSAS
		var centro: Vector3 = antiga.posicao
		var arvore_central := false
		for i in quantidade:
			for tentativa in 30:
				var modelo: String = paleta[_rng.randi_range(0, paleta.size() - 1)]
				# Algumas bétulas aparecem na borda do pinhal para transição.
				if antiga.modelo == "pine_trees" and _rng.randf() < .18: modelo = FOLHOSAS[3]
				var escala: float = [.85, 1.0, 1.15][_rng.randi_range(0, 2)]
				var p := Vector2(centro.x, centro.z)
				if i > 0 or tentativa > 0:
					var local := Vector2(_rng.randf_range(-.34, .34) * antiga.tamanho.x,
						_rng.randf_range(-.34, .34) * antiga.tamanho.z)
					p += local.rotated(-deg_to_rad(antiga.rotacao_graus.y))
				if _plantar(modelo, p, escala, true):
					arvore_central = true
					break
		if arvore_central:
			for paleta_chao in [ARBUSTOS, CHAO]:
				for tentativa in 16:
					var p := Vector2(centro.x, centro.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.5, 6.5)
					var modelo: String = paleta_chao[_rng.randi_range(0, paleta_chao.size() - 1)]
					if _plantar(modelo, p, 1.0, false): break
	mapa.pecas = preservadas + _novas
	return {"ok": true, "mapa": mapa, "removidas": antigas.size(), "novas": _novas.size(),
		"arvores": _plantadas.filter(func(p): return p.arvore).size()}

func _plantar(modelo: String, p: Vector2, escala: float, arvore: bool) -> bool:
	var tam := _bib.tamanho_padrao(modelo) * escala
	var raio := maxf(tam.x, tam.z) * .5
	var amostra := chao_em(p)
	if amostra.is_empty(): return false
	# O mesmo solo pintado que o editor desenha define onde plantar.
	if amostra.solo != 5 or amostra.molhado: return false
	var minimo: float = amostra.altura
	var maximo := minimo
	var margem := maxf(2.5, raio * .75) if arvore else maxf(.6, raio)
	for i in 8:
		var c := chao_em(p + Vector2.from_angle(i * TAU / 8) * margem)
		if c.is_empty() or c.molhado or c.solo in [2, 3, 6]: return false
	for i in 4:
		var c := chao_em(p + Vector2.from_angle(i * TAU / 4) * (.45 if arvore else minf(raio, .65)))
		if c.is_empty(): return false
		minimo = minf(minimo, c.altura)
		maximo = maxf(maximo, c.altura)
	if maximo - minimo > (.7 if arvore else .4): return false
	for o in _plantadas:
		var folga := maxf(3.2, (raio + o.raio) * .7) if arvore and o.arvore else 1.0
		if p.distance_to(o.pos) < folga: return false
	for o in _obstaculos:
		var local := (p - Vector2(o.posicao.x, o.posicao.z)).rotated(deg_to_rad(o.rotacao_graus.y))
		var margem_obstaculo := 1.4 if arvore else .5
		if absf(local.x) < o.tamanho.x * .5 + margem_obstaculo and absf(local.y) < o.tamanho.z * .5 + margem_obstaculo:
			return false
	_novas.append({"id": PREFIXO + str(_novas.size()), "tipo": "modelo", "modelo": modelo, "grupo": "floresta",
		"posicao": Vector3(p.x, minimo - .06 + tam.y * .5, p.y),
		"tamanho": tam, "rotacao_graus": Vector3(0, _rng.randi_range(-180, 179), 0),
		"cor": Color.WHITE, "material": "liso", "colisao": not _bib.atravessavel(modelo)})
	_plantadas.append({"pos": p, "raio": raio, "arvore": arvore})
	return true

func chao_em(p: Vector2) -> Dictionary:
	for terreno in _terrenos:
		var pos: Vector3 = terreno.posicao
		var local := (p - Vector2(pos.x, pos.z)).rotated(deg_to_rad(terreno.rotacao_graus.y))
		var t: Vector3 = terreno.tamanho
		if absf(local.x) > t.x * .5 or absf(local.y) > t.z * .5: continue
		return {"altura": pos.y + TerrenoDoMapa.altura_local(terreno.relevo, t, local.x, local.y),
			"solo": TerrenoDoMapa.solo_local(terreno.relevo, t, local.x, local.y),
			"molhado": TerrenoDoMapa.molhado_local(terreno.relevo, t, local.x, local.y)}
	return {}
