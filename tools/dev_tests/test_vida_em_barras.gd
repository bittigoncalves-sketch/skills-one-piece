extends SceneTree
## Vida dos chefes em 10 barras (10/11/2026): nunca morre em menos de 10 golpes; dano que esvazia a barra só tira a barra;
## 1 s de janela sem dano depois de cada barra caída (o golpe ainda "entra" para atordoar, a vida não cai).
var _ok := 0
var _f := 0
func ok(c: bool, n: String) -> void:
	if c: _ok += 1
	else:
		_f += 1
		print("FALHA: ", n)
func _init() -> void:
	var c := Node.new()
	var vida := 1000.0                       # barras de 100
	# 1) golpe menor que a barra: desconta inteiro
	var d := VidaEmBarras.filtrar(c, 30.0, vida, 1000.0, 0)
	ok(is_equal_approx(d, 30.0), "golpe menor que a barra desconta inteiro")
	vida -= d
	# 2) golpe que passa do que resta na barra (70): só a barra cai, resto descartado, abre a janela
	d = VidaEmBarras.filtrar(c, 500.0, vida, 1000.0, 100)
	ok(is_equal_approx(d, 70.0), "golpe grande só tira o que resta da barra (70), não 500")
	vida -= d
	ok(is_equal_approx(vida, 900.0), "vida parou na fronteira da barra (900)")
	ok(VidaEmBarras.barras_restantes(vida, 1000.0) == 9, "9 barras restantes")
	# 3) dentro de 1 s: dano não conta (mesmo enorme)
	ok(is_equal_approx(VidaEmBarras.filtrar(c, 999.0, vida, 1000.0, 600), 0.0), "0,5 s depois: dano negado")
	ok(is_equal_approx(VidaEmBarras.filtrar(c, 999.0, vida, 1000.0, 1099), 0.0), "até 1 s depois: dano negado")
	# 4) passado 1 s o dano volta
	d = VidaEmBarras.filtrar(c, 40.0, vida, 1000.0, 1100)
	ok(is_equal_approx(d, 40.0), "depois de 1 s o dano volta a contar")
	# 5) nunca morre em menos de 10 golpes, mesmo com dano absurdo e golpes espaçados > 1 s
	var corpo := Node.new()
	var v := 1000.0
	var golpes := 0
	var t := 0
	while v > 0.0 and golpes < 50:
		var x := VidaEmBarras.filtrar(corpo, 100000.0, v, 1000.0, t)
		v -= x
		golpes += 1
		t += 1200
	ok(golpes == 10, "dano absurdo mata em exatamente 10 golpes (foram %d)" % golpes)
	# 6) golpes rápidos (0,2 s) com dano absurdo: a janela segura, ainda 10 golpes EFETIVOS
	var corpo2 := Node.new()
	v = 1000.0
	var efetivos := 0
	t = 0
	for i in 200:
		var x2 := VidaEmBarras.filtrar(corpo2, 100000.0, v, 1000.0, t)
		if x2 > 0.0: efetivos += 1
		v -= x2
		t += 200
		if v <= 0.0: break
	ok(v <= 0.0 and efetivos == 10, "golpes de 0,2 s: janela de 1 s segura; 10 efetivos (%d)" % efetivos)
	# 7) última barra: sem janela depois (morte)
	var corpo3 := Node.new()
	ok(is_equal_approx(VidaEmBarras.filtrar(corpo3, 500.0, 60.0, 1000.0, 0), 60.0) and not corpo3.has_meta(VidaEmBarras.META_IMUNE), "última barra: mata e não abre janela")
	# 8) fração: barra parcial desce até zerar sem trocar de barra
	var corpo4 := Node.new()
	var vv := 1000.0
	for i in 3: vv -= VidaEmBarras.filtrar(corpo4, 20.0, vv, 1000.0, i * 10)
	ok(is_equal_approx(vv, 940.0), "três golpes de 20 na mesma barra: 940")
	# 9) queda no vazio / kill ignora as barras
	var corpo5 := Node.new()
	corpo5.set_meta(VidaEmBarras.META_MORTE_ABSOLUTA, true)
	ok(is_equal_approx(VidaEmBarras.filtrar(corpo5, 800.0, 800.0, 1000.0, 0), 800.0), "morte absoluta tira a vida toda de uma vez")
	print("test_vida_em_barras: %d ok, %d falhas" % [_ok, _f])
	quit(1 if _f > 0 else 0)
