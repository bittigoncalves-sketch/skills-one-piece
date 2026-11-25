extends SceneTree
# ============================================================================
#  TESTE — relevo marinho (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E1).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_relevo_marinho.gd
#
#  Lê o MAPA VIVO (só leitura). Confere o campo (`RelevoMarinho`) contra a decisão do
#  dono (plataforma 5–25 m, mar aberto 60–80 m, fossa entre as ilhas), a preservação da
#  costa (d < 60 m = rampa de antes: porto e vagas do cais), a folga de navegação, a
#  continuidade, e o fundo montado no mundo (colisão = campo, sem buraco, abismo fora da
#  grade, cada fundo na sua ilha). Controles de sabotagem: as mesmas réguas reprovam um
#  campo liso e um baixio raso demais.
# ============================================================================

var _falhas := 0
var _mapa: Dictionary
var _relevo: RelevoMarinho
var _placas: Array[Rect2] = []


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	print("\n===== RELEVO MARINHO =====")
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	_ok(lido["ok"], "mapa vivo válido")
	if not lido["ok"]:
		quit(1)
		return
	_mapa = lido["mapa"]
	var bases: Array = _mapa["pecas"].filter(func(p: Dictionary) -> bool: return OceanoScript().e_base(p))
	for ilha in FundoDoMar.agrupar(bases):
		_placas.append(FundoDoMar.caixa_de(ilha))
	_ok(_placas.size() >= 2, "ilhas no mapa: %d" % _placas.size())
	var terrenos: Array = _mapa["pecas"].filter(func(p: Dictionary) -> bool: return p.get("tipo") == "terreno")
	_relevo = RelevoMarinho.new()
	_relevo.relevo_em = FundoDoMar._relevo_em.bind(terrenos)
	_relevo.configurar(_placas, FundoDoMar.ALCANCE, -0.65)
	_perfis()
	_fossa()
	_controles()
	await _no_mundo()
	print("\nRELEVO_MARINHO_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


static func OceanoScript() -> Script:
	return load("res://src/world/oceano_historia.gd")


## Pontos (x, z) com a distância à placa mais perto, em raios saindo das ilhas.
func _amostras() -> Array[Dictionary]:
	var saida: Array[Dictionary] = []
	for placa in _placas:
		var c := placa.get_center()
		var meio := placa.size * 0.5
		for k in 64:
			var ang := TAU * k / 64.0
			var dir := Vector2(cos(ang), sin(ang))
			# Sai da borda da placa nessa direção.
			var t := minf(meio.x / maxf(absf(dir.x), 1e-4), meio.y / maxf(absf(dir.y), 1e-4))
			var borda := c + dir * t
			for d in range(2, 560, 4):
				var p := borda + dir * float(d)
				var dist := INF
				for r in _placas:
					dist = minf(dist, RelevoMarinho._fora(r, p))
				if not _relevo.limite.grow(-90.0).has_point(p):
					continue
				saida.append({"p": p, "d": dist, "s": _relevo.amostra(p.x, p.y)})
	return saida


func _perfis() -> void:
	print("\n-- A. perfil por faixa --")
	var amostras := _amostras()
	var costa_dif := 0.0
	var raso := 0
	var plataforma: Array[float] = []
	var aberto: Array[float] = []
	var rocha := 0
	var recife := 0
	for a in amostras:
		var d: float = a.d
		var s: Vector4 = a.s
		var prof := -0.65 - s.x
		if d < RelevoMarinho.COSTA_PRESERVADA:
			var praia := _relevo._praia(_mais_perto(a.p), a.p)
			var antigo := lerpf(praia, RelevoMarinho.FUNDO_ANTIGO, smoothstep(0.0, RelevoMarinho.RAMPA_ANTIGA, d))
			costa_dif = maxf(costa_dif, absf(s.x - antigo))
		elif prof < RelevoMarinho.FOLGA_DE_NAVEGACAO - 0.01:
			raso += 1
		if d > 100.0 and d < 165.0:
			plataforma.append(prof)
			rocha += int(s.y > 0.5)
			recife += int(s.z > 0.5)
		if d > 380.0 and d < 520.0:
			aberto.append(prof)
	_ok(costa_dif < 0.01, "d < 60 m = rampa de antes (porto, vagas do cais, costa): maior diferença %.3f m" % costa_dif)
	_ok(raso == 0, "folga de navegação: nenhum ponto além de 60 m com menos de %.0f m de água (%d)" % [RelevoMarinho.FOLGA_DE_NAVEGACAO, raso])
	var p := _estat(plataforma)
	_ok(p.dentro(5.0, 25.0) > 0.97, "plataforma (100–165 m): %.0f%% entre 5 e 25 m (média %.1f, desvio %.1f m)" % [p.dentro(5.0, 25.0) * 100.0, p.media, p.desvio])
	_ok(p.desvio > 1.5, "plataforma com relevo (desvio %.1f m > 1,5): não é lisa" % p.desvio)
	var frac_rocha := float(rocha) / maxf(plataforma.size(), 1)
	var frac_recife := float(recife) / maxf(plataforma.size(), 1)
	_ok(frac_rocha > 0.02 and frac_rocha < 0.4, "rocha em %.0f%% da plataforma" % (frac_rocha * 100.0))
	_ok(frac_recife > 0.03 and frac_recife < 0.5, "zona de recife em %.0f%% da plataforma" % (frac_recife * 100.0))
	var o := _estat(aberto)
	_ok(o.dentro(56.0, 82.0) > 0.97, "mar aberto (380–520 m): %.0f%% entre 56 e 82 m (média %.1f m)" % [o.dentro(56.0, 82.0) * 100.0, o.media])
	# Continuidade: degrau entre amostras vizinhas de 4 m.
	var maior := 0.0
	for z in range(-500, 500, 4):
		var antes := _relevo.altura(300.0, float(z))
		for x in range(304, 1360, 4):
			var y := _relevo.altura(float(x), float(z))
			maior = maxf(maior, absf(y - antes))
			antes = y
	_ok(maior < 5.0, "sem degrau: maior diferença entre vizinhos de 4 m = %.2f m" % maior)


func _mais_perto(p: Vector2) -> Rect2:
	var r := _placas[0]
	for q in _placas:
		if RelevoMarinho._fora(q, p) < RelevoMarinho._fora(r, p):
			r = q
	return r


func _fossa() -> void:
	print("\n-- B. fossa entre as ilhas --")
	var a := _placas[0]
	var b := _placas[1]
	var meio_x := (a.end.x + b.position.x) * 0.5
	var linhas := 0
	var com_fossa := 0
	var mais_fundo := 0.0
	for z in range(-480, 481, 40):
		linhas += 1
		var menor := INF
		for x in range(int(meio_x) - 160, int(meio_x) + 161, 4):
			menor = minf(menor, _relevo.altura(float(x), float(z)))
		mais_fundo = minf(mais_fundo, menor)
		com_fossa += int(menor < -74.0)
	_ok(com_fossa == linhas, "fossa contínua na linha do meio (x≈%.0f): %d/%d travessias passam de −74 m" % [meio_x, com_fossa, linhas])
	_ok(mais_fundo > RelevoMarinho.FOSSA - 6.0 and mais_fundo < RelevoMarinho.FOSSA + 4.0, "fundo da fossa a %.1f m (alvo ~%.0f)" % [mais_fundo, RelevoMarinho.FOSSA])


## As réguas reprovam o que deveriam reprovar.
func _controles() -> void:
	print("\n-- C. controles (sabotagem) --")
	var liso: Array[float] = []
	for i in 200:
		liso.append(16.0)
	_ok(_estat(liso).desvio <= 1.5, "controle: plataforma lisa reprova na régua do relevo (desvio %.1f)" % _estat(liso).desvio)
	var sabotado := RelevoMarinho.new()
	sabotado.configurar(_placas, FundoDoMar.ALCANCE, -0.65)
	var min_prof := INF
	for x in range(320, 430, 2):
		for z in range(-200, 200, 2):
			min_prof = minf(min_prof, -0.65 - sabotado.altura(float(x), float(z)))
	_ok(min_prof >= RelevoMarinho.FOLGA_DE_NAVEGACAO - 0.01, "baixio mais raso da plataforma leste: %.2f m de água (≥ %.0f)" % [min_prof, RelevoMarinho.FOLGA_DE_NAVEGACAO])
	var antes_do_teto := 0
	for x in range(320, 430, 2):
		for z in range(-200, 200, 2):
			var s := sabotado.call("_perfil", Vector2(x, z), RelevoMarinho._fora(_placas[0], Vector2(x, z)), INF, 0.0) as Vector4
			antes_do_teto += int(-0.65 - s.x < RelevoMarinho.FOLGA_DE_NAVEGACAO + 0.01 and -0.65 - s.x > RelevoMarinho.FOLGA_DE_NAVEGACAO - 0.01)
	_ok(antes_do_teto > 0, "controle: %d pontos encostam no teto da folga (sem ele subiriam mais: a régua não passa por acaso)" % antes_do_teto)


func _no_mundo() -> void:
	print("\n-- D. fundo montado no mundo --")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var bases: Array = _mapa["pecas"].filter(func(p: Dictionary) -> bool: return OceanoScript().e_base(p))
	var t0 := Time.get_ticks_msec()
	var fundos := FundoDoMar.montar_por_ilha(mundo, _mapa, bases, -0.65)
	var gasto := Time.get_ticks_msec() - t0
	_ok(gasto < 4000, "montagem em %d ms (carregamento)" % gasto)
	var blocos := 0
	var formas := 0
	var nomes := {}
	var repetidos := 0
	for f in fundos:
		for n in f.get_children():
			if n is MeshInstance3D:
				blocos += 1
				repetidos += int(nomes.has(n.name))
				nomes[n.name] = true
				if blocos == 1:
					_ok((n as MeshInstance3D).visibility_range_end > 0.0, "bloco com alcance de desenho")
			elif n is CollisionShape3D:
				formas += 1
	print("     %d blocos, %d formas de colisão, %d fundos" % [blocos, formas, fundos.size()])
	_ok(repetidos == 0, "nenhum bloco desenhado por dois fundos")
	for k in fundos.size():
		var f := fundos[k]
		_ok(f.placa.has_point(Vector2(f.position.x, f.position.z)), "%s posicionado na sua ilha (%.0f, %.0f)" % [f.name, f.position.x, f.position.z])
	for i in 3:
		await physics_frame
	var espaco := mundo.get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sem_chao := 0
	var erro_grade := 0.0
	var erro_meio := 0.0
	var testados := 0
	while testados < 400:
		var p := Vector2(rng.randf_range(_relevo.limite.position.x, _relevo.limite.end.x), rng.randf_range(_relevo.limite.position.y, _relevo.limite.end.y))
		if _placas.any(func(r: Rect2) -> bool: return r.grow(6.0).has_point(p)):
			continue
		testados += 1
		var g := p.snapped(Vector2.ONE * FundoDoMar.CELULA)          # ponto da grade
		var na_grade := intersect(espaco, g.x, g.y)
		var fora_da_grade := intersect(espaco, p.x, p.y)
		if is_nan(na_grade) or is_nan(fora_da_grade):
			sem_chao += 1
			continue
		erro_grade = maxf(erro_grade, absf(na_grade - _relevo.altura(g.x, g.y)))
		erro_meio = maxf(erro_meio, absf(fora_da_grade - _relevo.altura(p.x, p.y)))
	_ok(sem_chao == 0, "sem buraco: %d de %d raios no mar sem fundo" % [sem_chao, testados])
	_ok(erro_grade < 0.05, "colisão = campo nos pontos da grade: maior erro %.3f m" % erro_grade)
	_ok(erro_meio < 1.2, "entre pontos da grade, a interpolação fica perto do campo: maior erro %.2f m" % erro_meio)
	var fora := intersect(espaco, _relevo.limite.end.x + 300.0, 0.0)
	_ok(absf(fora - RelevoMarinho.BORDA_DO_MUNDO) < 0.2, "além da grade, o abismo: %.2f m" % fora)
	var borda_dentro := intersect(espaco, _relevo.limite.end.x - 1.0, 0.0)
	_ok(absf(borda_dentro - fora) < 0.3, "abismo encosta na borda sem degrau: %.2f | %.2f m" % [borda_dentro, fora])
	mundo.queue_free()
	await process_frame


static func intersect(espaco: PhysicsDirectSpaceState3D, x: float, z: float) -> float:
	var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 30, z), Vector3(x, -150, z)))
	return float(hit["position"].y) if not hit.is_empty() else NAN


class Estat:
	var media := 0.0
	var desvio := 0.0
	var valores: Array[float] = []
	func dentro(a: float, b: float) -> float:
		if valores.is_empty():
			return 0.0
		return float(valores.filter(func(v: float) -> bool: return v >= a and v <= b).size()) / valores.size()


func _estat(v: Array[float]) -> Estat:
	var e := Estat.new()
	e.valores = v
	if v.is_empty():
		return e
	for x in v:
		e.media += x
	e.media /= v.size()
	for x in v:
		e.desvio += (x - e.media) * (x - e.media)
	e.desvio = sqrt(e.desvio / v.size())
	return e
