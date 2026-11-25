extends SceneTree
# ============================================================================
#  ILHA DOS MACACOS v2 (22/11/2026) — o MAPA: vila plana, sítios planos, estradas, e nada de construção que não seja árvore.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ilha_macacos_v2.gd
#  Plano: docs/ILHA_DOS_MACACOS_V2_PLANO.md. O que isto prova: geometria do mapa gravado. NÃO prova a vista no jogo (foto) nem o desempenho.
# ============================================================================
const Layout := preload("res://tools/mapa_ilha/layout_macacos.gd")
var _ok_n := 0
var _falhas := 0
var _terrenos: Array[Dictionary] = []


func _ok(rotulo: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
	else:
		_falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _init() -> void:
	_executar.call_deferred()


## Altura do chão no ponto LOCAL à ilha (null se fora).
func _y(l: Vector2) -> Variant:
	var p := Layout.CENTRO + l
	for t in _terrenos:
		var pos: Vector3 = t["posicao"]
		var s: Vector3 = t["tamanho"]
		var lx := p.x - pos.x
		var lz := p.y - pos.z
		if absf(lx) <= s.x * 0.5 and absf(lz) <= s.z * 0.5:
			return pos.y + TerrenoDoMapa.altura_local(t["relevo"], s, lx, lz)
	return null


func _solo(l: Vector2) -> int:
	var p := Layout.CENTRO + l
	for t in _terrenos:
		var pos: Vector3 = t["posicao"]
		var s: Vector3 = t["tamanho"]
		if absf(p.x - pos.x) <= s.x * 0.5 and absf(p.y - pos.z) <= s.z * 0.5:
			return TerrenoDoMapa.solo_local(t["relevo"], s, p.x - pos.x, p.y - pos.z)
	return -1


func _variacao(centro: Vector2, raio: float) -> float:
	var lo := INF
	var hi := -INF
	for k in 40:
		for a in 12:
			var l := centro + Vector2.from_angle(a * TAU / 12.0) * raio * (k / 39.0)
			var y: Variant = _y(l)
			if y == null:
				return INF
			lo = minf(lo, float(y))
			hi = maxf(hi, float(y))
	return hi - lo


func _executar() -> void:
	await process_frame
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	_ok("mapa válido", lido["ok"])
	var pecas: Array = lido["mapa"]["pecas"]
	for p: Dictionary in pecas:
		if p["tipo"] == "terreno" and String(p["id"]).begins_with("macacos_relevo_"):
			_terrenos.append(p)
	_ok("16 blocos de relevo", _terrenos.size() == 16)

	# 1) nada de construção que não seja árvore: nas peças da ilha só terreno, árvores, vegetação, rocha, personagens, NPCs e as plataformas do Geppo.
	var permitidas_prefixo := ["floresta_tree_", "floresta_bush", "floresta_mushroom", "floresta_rock", "floresta_fallen_log", "floresta_grass",
		"mp_macaco_", "npc_", "mpe_macaco_", "macaco_vila_", "gorila_"]
	var intrusas: PackedStringArray = []
	var loja := 0
	for p: Dictionary in pecas:
		var x: float = p["posicao"].x
		if x < Layout.CENTRO.x - 160.0 or x > Layout.CENTRO.x + 160.0 or absf(p["posicao"].z) > 160.0:
			continue
		var id := String(p["id"])
		if id.begins_with("mpi_ilha_dos_macacos_") or id == "macacos_pier":
			loja += 1
		if p["tipo"] == "modelo":
			var m := String(p.get("modelo", ""))
			var vale := false
			for pre in permitidas_prefixo:
				if m.begins_with(pre):
					vale = true
			# modelos temáticos da v2 entram por prefixo de ID, não de modelo
			if id.begins_with("macacos_vila_") or id.begins_with("macacos_sitio_"):
				vale = true
			if not vale:
				intrusas.append("%s(%s)" % [id, m])
	_ok("nenhuma loja, vendedor ou píer antigo (%d)" % loja, loja == 0)
	_ok("nenhum modelo estranho na ilha %s" % str(intrusas), intrusas.is_empty())
	_ok("o píer `dock_long` e o Macaco-rei antigo sumiram", not pecas.any(func(p): return String(p.get("modelo", "")) in ["dock_long", "mp_macaco_rei"] and p["posicao"].x > 1300.0 and p["posicao"].x < 1700.0))

	# 2) vila plana: variação de altura pequena no raio plano
	var v := _variacao(Layout.VILA, Layout.VILA_RAIO_PLANO - 2.0)
	_ok("a vila é plana (variação %.3f m no raio %.0f)" % [v, Layout.VILA_RAIO_PLANO - 2.0], v <= 0.15)
	var y_vila: Variant = _y(Layout.VILA)
	_ok("a vila fica a %.2f m (alvo %.1f)" % [float(y_vila), Layout.VILA_ALTURA], y_vila != null and absf(float(y_vila) - Layout.VILA_ALTURA) <= 0.15)
	for nome in Layout.SITIOS:
		var s: Dictionary = Layout.SITIOS[nome]
		var var_s := _variacao(s["centro"], float(s["plano"]) - 1.5)
		_ok("sítio %s plano (%.3f m)" % [nome, var_s], var_s <= 0.15)
	var yt: Variant = _y(Layout.SITIOS["trono"]["centro"])
	_ok("Trono a %.2f m (alvo 10,0), solo rocha" % float(yt), yt != null and absf(float(yt) - 10.0) <= 0.2 and _solo(Layout.SITIOS["trono"]["centro"]) == 4)

	# 3) estradas: terra ao longo de cada uma e subida suave (≤ 14° entre amostras de 2 m)
	for nome in Layout.ESTRADAS:
		var pts: Array = Layout.ESTRADAS[nome]
		var curva := Curve2D.new()
		for k in pts.size():
			var antes: Vector2 = pts[maxi(k - 1, 0)]
			var depois: Vector2 = pts[mini(k + 1, pts.size() - 1)]
			var alca := (depois - antes) * 0.25
			curva.add_point(pts[k], -alca, alca)
		var linha := curva.tessellate_even_length(6, 2.0)
		var terra := 0
		var dentro := 0
		var maior_inclinacao := 0.0
		var anterior: Variant = null
		for l in linha:
			var y: Variant = _y(l)
			if y == null:
				continue
			dentro += 1
			var so := _solo(l)
			if so == 2 or so == 4 or so == 0:      # terra (ou o disco liso da vila/sítio no começo e no fim)
				terra += 1
			if anterior != null:
				maior_inclinacao = maxf(maior_inclinacao, rad_to_deg(atan2(absf(float(y) - float(anterior)), 2.0)))
			anterior = y
		_ok("estrada %s: %d%% em solo de estrada/disco, inclinação máx %.1f°" % [nome, int(100.0 * terra / maxi(dentro, 1)), maior_inclinacao], dentro > 20 and terra * 100 >= dentro * 88 and maior_inclinacao <= 14.0)

	# 4) árvores fora de vila, sítios e estradas
	var ruim := 0
	for p: Dictionary in pecas:
		var m := String(p.get("modelo", ""))
		if m.begins_with("floresta_tree_") and String(p["id"]).begins_with("macacos_floresta_"):
			var l := Vector2(p["posicao"].x, p["posicao"].z) - Layout.CENTRO
			if l.distance_to(Layout.VILA) < Layout.VILA_RAIO_LIVRE - 6.0:
				ruim += 1
			for nome in Layout.SITIOS:
				if l.distance_to(Layout.SITIOS[nome]["centro"]) < float(Layout.SITIOS[nome]["plano"]):
					ruim += 1
	_ok("nenhuma árvore na vila nem nos sítios (%d)" % ruim, ruim == 0)
	var gigantes := pecas.filter(func(p): return String(p.get("modelo", "")).begins_with("floresta_tree_") and p["tamanho"].y >= 45.0 and p["posicao"].x > 1300.0)
	_ok("a floresta gigante continua (%d árvores imensas)" % gigantes.size(), gigantes.size() >= 35)
	print("RESULTADO test_ilha_macacos_v2: %d ok, %d falhas" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
