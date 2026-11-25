extends SceneTree
## V2 do mundo voxel: o terreno gerado sob demanda a partir do `RelevoEmBlocos` tem a MESMA superfície do relevo atual.
## Sintético (relevo com ruído arrumado pelo `_ajustar` do próprio relevo): classificação em cubo/laje/escada/octantes,
## equivalência da colisão por raios (relevo atual × grade), cavar só suja a seção e o terreno de base não vira dado guardado.
##   godot --headless --path . --script tools/dev_tests/test_gerador_de_relevo.gd
var ok := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func confere(cond: bool, msg: String) -> void:
	if cond:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", msg)

func relevo_de(f_meios: Callable, larg: int, prof: int, origem := Vector2i.ZERO) -> RelevoEmBlocos:
	var r := RelevoEmBlocos.new()
	r.origem = origem
	r.largura = larg
	r.profundidade = prof
	var reais := PackedFloat32Array()
	reais.resize(larg * prof)
	for j in prof:
		for i in larg:
			reais[j * larg + i] = f_meios.call(i, j)
	var solo := PackedByteArray()
	solo.resize(larg * prof)
	r._paleta()
	r._ajustar(reais, solo)
	return r

func rodar() -> void:
	TiposDeBloco.iniciar()
	var G := TiposDeBloco.GRAMA

	# 1. classificação das células por forma
	var plano := relevo_de(func(_i, _j): return 6.0, 32, 32)             # 6 meios = 3 blocos
	var gp := GeradorDeRelevo.new(plano)
	confere(gp.valor_em(Vector3i(3, 2, 3)) == G and gp.valor_em(Vector3i(3, 1, 3)) == TiposDeBloco.TERRA and gp.valor_em(Vector3i(3, 0, 3)) == TiposDeBloco.TERRA, "3 blocos de altura: grama no topo, terra embaixo")
	var fundo := relevo_de(func(_i, _j): return 20.0, 32, 32)             # 10 blocos
	var gf := GeradorDeRelevo.new(fundo)
	confere(gf.valor_em(Vector3i(3, 9, 3)) == G and gf.valor_em(Vector3i(3, 6, 3)) == TiposDeBloco.TERRA and gf.valor_em(Vector3i(3, 5, 3)) == TiposDeBloco.PEDRA, "10 blocos: grama, 3 de terra, pedra no resto")
	confere(gp.valor_em(Vector3i(3, 3, 3)) == TiposDeBloco.AR, "acima do topo é ar")
	var meio := relevo_de(func(_i, _j): return 5.0, 32, 32)              # 5 meios = 2 blocos + meio
	var gm := GeradorDeRelevo.new(meio)
	confere(gm.valor_em(Vector3i(3, 2, 3)) == TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + G, 0), "meio bloco no topo é laje embaixo")
	var degrau := relevo_de(func(i, _j): return 5.0 if i % 2 == 0 else 6.0, 32, 32)   # 1 2 / 1 2 em meios (−x baixo, +x alto)
	var gd := GeradorDeRelevo.new(degrau)
	var v_deg := gd.valor_em(Vector3i(3, 2, 3))
	confere(TiposDeBloco.forma_de(v_deg) == TiposDeBloco.Forma.ESCADA, "degrau (meio bloco + lado alto) é escada (forma %d)" % TiposDeBloco.forma_de(v_deg))
	var lateral := relevo_de(func(i, _j): return 6.0 if i % 2 == 1 else NAN, 32, 32)  # 0 2 / 0 2
	var gl := GeradorDeRelevo.new(lateral)
	confere(gl.valor_em(Vector3i(3, 1, 3)) == TiposDeBloco.AR or TiposDeBloco.forma_de(gl.valor_em(Vector3i(3, 1, 3))) == TiposDeBloco.Forma.OCTANTES, "lateral vira bloco de octantes")

	# 2. a seção gerada concorda célula a célula com a consulta pontual
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ruido := FastNoiseLite.new()
	ruido.frequency = 0.04
	var rel := relevo_de(func(i, j): return 4.0 + (ruido.get_noise_2d(i, j) + 1.0) * 14.0, 96, 96, Vector2i(-20, 8))
	var g := GeradorDeRelevo.new(rel)
	var diverge := 0
	for sc in [Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 1), Vector3i(-1, 0, 0)]:
		var dados := g.gerar(sc)
		for k in 200:
			var l := Vector3i(rng.randi() % 16, rng.randi() % 16, rng.randi() % 16)
			var esperado := g.valor_em(sc * 16 + l)
			var obtido := 0 if dados.is_empty() else dados[l.x + 16 * (l.y + 16 * l.z)]
			if esperado != obtido:
				diverge += 1
	confere(diverge == 0, "gerar(seção) = valor_em(célula) em 800 células (%d divergem)" % diverge)

	# 3. equivalência da superfície: o relevo atual (malha+colisão) × a grade, por raios
	var corpo := StaticBody3D.new()
	corpo.collision_layer = 2
	var forma := CollisionShape3D.new()
	forma.shape = rel.forma(rel.triangulos())
	corpo.add_child(forma)
	root.add_child(corpo)
	var gv := GradeVoxel.new()
	gv.gerador = g
	root.add_child(gv)
	gv.carregar_caixa(g.caixa_min, g.caixa_max)
	var t0 := Time.get_ticks_msec()
	gv.esperar_tudo()
	print("   (grade da ilha sintética: %d seções, %d triângulos, %d ms)" % [gv.secoes_com_malha(), gv.triangulos(), Time.get_ticks_msec() - t0])
	await physics_frame
	await physics_frame
	var espaco := root.get_world_3d().direct_space_state
	var difere := 0
	var testados := 0
	var maior := 0.0
	for k in 400:
		var x := rng.randf_range(-18.0, 50.0) * RelevoEmBlocos.MEIO + 0.01
		var z := rng.randf_range(10.0, 100.0) * RelevoEmBlocos.MEIO + 0.01
		var q_velho := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -30, z), 2)
		var q_novo := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -30, z), 1)
		var a := espaco.intersect_ray(q_velho)
		var b := espaco.intersect_ray(q_novo)
		if a.is_empty() and b.is_empty():
			continue
		testados += 1
		if a.is_empty() != b.is_empty():
			difere += 1
			continue
		var d := absf(a.position.y - b.position.y)
		maior = maxf(maior, d)
		if d > 0.02:
			difere += 1
	confere(testados > 200, "raios que acertam o terreno (%d)" % testados)
	confere(difere == 0, "topo do terreno igual ao relevo atual em %d raios (%d divergem, maior diferença %.4f m)" % [testados, difere, maior])
	print("   (raios: %d testados, maior diferença %.5f m)" % [testados, maior])

	# 4. cavar: guarda só a seção editada, refaz só ela (e a vizinha na borda)
	var antes := gv.reconstrucoes
	var p := Vector3i(8, 8, 8)
	var topo_y := p.y
	while gv.obter(Vector3i(8, topo_y + 1, 8)) != TiposDeBloco.AR:
		topo_y += 1
	confere(gv.secoes_com_blocos() == 0, "terreno intocado não fica guardado")
	gv.definir(Vector3i(8, topo_y, 8), TiposDeBloco.AR)
	gv.esperar_tudo()
	confere(gv.secoes_com_blocos() == 1, "uma edição guarda 1 seção (%d)" % gv.secoes_com_blocos())
	confere(gv.reconstrucoes - antes <= 2, "uma edição refaz ≤ 2 seções (%d)" % (gv.reconstrucoes - antes))
	confere(gv.obter(Vector3i(8, topo_y, 8)) == TiposDeBloco.AR, "o bloco cavado é ar")
	# descarregar e carregar de novo mantém a edição
	gv.descarregar(GradeVoxel.secao_de(Vector3i(8, topo_y, 8)))
	gv.carregar(GradeVoxel.secao_de(Vector3i(8, topo_y, 8)))
	gv.esperar_tudo()
	confere(gv.obter(Vector3i(8, topo_y, 8)) == TiposDeBloco.AR, "a edição sobrevive a descarregar/carregar")
	print("GERADOR_DE_RELEVO ok=%d falhas=%d" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
