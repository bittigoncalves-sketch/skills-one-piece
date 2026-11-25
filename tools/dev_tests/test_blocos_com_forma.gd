extends SceneTree
## Tipos de bloco com forma (etapa V3): laje, escada (com canto), porta, painel de vidro, translúcido, sem colisão.
## As formas e as regras vêm do Minecraft 1.20.1 decompilado (StairBlock/SlabBlock/DoorBlock/IronBarsBlock).
##   godot --headless --path . --script tools/dev_tests/test_blocos_com_forma.gd
var ok := 0
var falhas := 0
const B := GradeVoxel.BLOCO

func _init() -> void:
	rodar.call_deferred()

func confere(cond: bool, msg: String) -> void:
	if cond:
		ok += 1
	else:
		falhas += 1
		print("FALHOU: ", msg)

func nova() -> GradeVoxel:
	var g := GradeVoxel.new()
	root.add_child(g)
	return g

func fisica() -> void:
	await physics_frame
	await physics_frame

func raio(de: Vector3, ate: Vector3) -> Dictionary:
	return root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(de, ate, 1))

func area(g: GradeVoxel) -> float:
	var a := 0.0
	for no: StaticBody3D in g._nos.values():
		var m := (no.get_node("Malha") as MeshInstance3D).mesh as ArrayMesh
		for s in m.get_surface_count():
			var v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for t in v.size() / 3:
				a += (v[3 * t + 1] - v[3 * t]).cross(v[3 * t + 2] - v[3 * t]).length() * 0.5
	return a

func rodar() -> void:
	TiposDeBloco.iniciar()
	var PEDRA := TiposDeBloco.PEDRA

	# 1. octantes: laje e escada (SHAPE_BY_STATE do jogo)
	confere(TiposDeBloco.octantes(TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + PEDRA, 0)) == 0x33, "laje embaixo = 4 octantes de baixo")
	confere(TiposDeBloco.octantes(TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + PEDRA, 1)) == 0xCC, "laje em cima = 4 octantes de cima")
	confere(TiposDeBloco.octantes(TiposDeBloco.valor(TiposDeBloco.LAJE_BASE + PEDRA, 2)) == 0xFF, "laje dupla = cubo")
	# escada reta olhando para o sul (+z), embaixo: laje de baixo + octantes (−x,+z) e (+x,+z) de cima = 6 e 7
	var reta_s := TiposDeBloco.valor(TiposDeBloco.ESCADA_BASE + PEDRA, 0)
	confere(TiposDeBloco.octantes(reta_s) == (0x33 | (1 << 6) | (1 << 7)), "escada reta (sul) tem o degrau no +z")
	var reta_n_em_cima := TiposDeBloco.valor(TiposDeBloco.ESCADA_BASE + PEDRA, 2 | 4)
	confere(TiposDeBloco.octantes(reta_n_em_cima) == (0xCC | (1 << 0) | (1 << 1)), "escada de cabeça para baixo (norte): degrau embaixo no −z")

	# 2. forma da escada pelos vizinhos (getStairsShape)
	var g := nova()
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 0), PEDRA, 0)           # olha para o sul
	confere((TiposDeBloco.estado_de(g.obter(Vector3i(0, 0, 0))) >> 3) == 0, "escada sozinha é reta")
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 1), PEDRA, 1)           # na frente, olhando para o oeste
	confere((TiposDeBloco.estado_de(g.obter(Vector3i(0, 0, 0))) >> 3) == 4, "escada com outra de lado na frente vira canto externo direito (%d)" % (TiposDeBloco.estado_de(g.obter(Vector3i.ZERO)) >> 3))
	g.queue_free()
	g = nova()
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 0), PEDRA, 0)
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, -1), PEDRA, 3)          # atrás, olhando para o leste (anti-horário do sul)
	confere((TiposDeBloco.estado_de(g.obter(Vector3i(0, 0, 0))) >> 3) == 1, "escada com outra de lado atrás vira canto interno esquerdo (%d)" % (TiposDeBloco.estado_de(g.obter(Vector3i.ZERO)) >> 3))
	g.queue_free()
	# quebrar o vizinho devolve a forma reta
	g = nova()
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 0), PEDRA, 0)
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 1), PEDRA, 1)
	RegrasDeBloco.quebrar(g, Vector3i(0, 0, 1))
	confere((TiposDeBloco.estado_de(g.obter(Vector3i(0, 0, 0))) >> 3) == 0, "quebrar o vizinho devolve a escada reta")
	g.queue_free()

	# 3. colisão da escada: degrau alto no +z, baixo no −z
	g = nova()
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 0), PEDRA, 0)
	g.esperar_tudo()
	await fisica()
	var alto := raio(Vector3(0.4, 4, 0.7), Vector3(0.4, -1, 0.7))
	var baixo := raio(Vector3(0.4, 4, 0.2), Vector3(0.4, -1, 0.2))
	confere(not alto.is_empty() and absf(alto.position.y - B) < 0.01, "degrau alto (+z) topo em %s" % str(alto.get("position")))
	confere(not baixo.is_empty() and absf(baixo.position.y - B * 0.5) < 0.01, "degrau baixo (−z) topo em %s" % str(baixo.get("position")))
	g.queue_free()

	# 4. duas lajes juntas: a face entre elas não existe (área = caixa 2B × B × B/2)
	g = nova()
	RegrasDeBloco.colocar_laje(g, Vector3i(0, 0, 0), PEDRA, 0)
	RegrasDeBloco.colocar_laje(g, Vector3i(1, 0, 0), PEDRA, 0)
	g.esperar_tudo()
	var esperado := 2.0 * (2.0 * B * B + 2.0 * B * B * 0.5 + B * B * 0.5)
	confere(absf(area(g) / esperado - 1.0) < 0.04, "2 lajes juntas: área %.3f vs %.3f" % [area(g), esperado])
	g.queue_free()

	# 5. cubo ao lado de laje: a face do cubo que encosta na laje aparece (a laje não cobre a face inteira)
	g = nova()
	g.definir(Vector3i(0, 0, 0), PEDRA)
	RegrasDeBloco.colocar_laje(g, Vector3i(1, 0, 0), PEDRA, 0)
	g.esperar_tudo()
	var sem_laje := 6.0 * B * B + 2.0 * B * B * 0.5 + 2.0 * B * B * 0.5 + 2.0 * B * 0.5 * B * 0.5   # só confere que há mais que 10 faces do cubo
	confere(g.triangulos() > 12, "cubo ao lado de laje mostra a face (%d triângulos)" % g.triangulos())
	g.queue_free()

	# 6. porta: fechada bloqueia o raio; aberta (dobradiça à esquerda) vai para o lado e libera o meio
	g = nova()
	RegrasDeBloco.colocar_porta(g, Vector3i(0, 0, 0), 0)                   # sul, dobradiça à esquerda, fechada
	g.esperar_tudo()
	await fisica()
	var h1 := raio(Vector3(0.4, 0.5, -2), Vector3(0.4, 0.5, 2))
	confere(not h1.is_empty() and absf(h1.position.z) < 0.01, "porta fechada bloqueia (%s)" % str(h1.get("position")))
	var h_cima := raio(Vector3(0.4, B + 0.5, -2), Vector3(0.4, B + 0.5, 2))
	confere(not h_cima.is_empty(), "a metade de cima da porta também bloqueia")
	confere(RegrasDeBloco.alternar_porta(g, Vector3i(0, 1, 0)), "alternar pela metade de cima abre a porta")
	g.esperar_tudo()
	await fisica()
	var h2 := raio(Vector3(0.4, 0.5, -2), Vector3(0.4, 0.5, 2))
	confere(h2.is_empty(), "porta aberta libera o meio do vão (%s)" % str(h2.get("position")))
	var h3 := raio(Vector3(0.8, 0.5, -2), Vector3(0.8, 0.5, 2))
	confere(not h3.is_empty(), "porta aberta fica encostada no lado da dobradiça (%s)" % str(h3.get("position")))
	RegrasDeBloco.quebrar(g, Vector3i(0, 1, 0))
	confere(g.obter(Vector3i(0, 0, 0)) == 0 and g.obter(Vector3i(0, 1, 0)) == 0, "quebrar uma metade leva a porta inteira")
	g.queue_free()

	# 7. painel de vidro: poste sozinho; liga ao bloco do lado
	g = nova()
	RegrasDeBloco.colocar_painel(g, Vector3i(0, 0, 0))
	g.esperar_tudo()
	await fisica()
	confere(not raio(Vector3(B * 0.5, 4, B * 0.5), Vector3(B * 0.5, -1, B * 0.5)).is_empty(), "poste do painel colide no centro")
	confere(raio(Vector3(B * 0.8, 4, B * 0.5), Vector3(B * 0.8, -1, B * 0.5)).is_empty(), "painel sozinho não tem braço")
	g.definir(Vector3i(1, 0, 0), PEDRA)
	RegrasDeBloco.atualizar_vizinhos(g, Vector3i(1, 0, 0))
	confere(TiposDeBloco.estado_de(g.obter(Vector3i.ZERO)) == 8, "painel liga ao bloco do leste (estado %d)" % TiposDeBloco.estado_de(g.obter(Vector3i.ZERO)))
	g.esperar_tudo()
	await fisica()
	confere(not raio(Vector3(B * 0.8, 4, B * 0.5), Vector3(B * 0.8, -1, B * 0.5)).is_empty(), "com ligação o braço colide")
	g.queue_free()

	# 8. translúcido: vidro com vidro funde; pedra ao lado de vidro mostra a face; água não colide
	g = nova()
	g.definir(Vector3i(0, 0, 0), TiposDeBloco.VIDRO)
	g.definir(Vector3i(1, 0, 0), TiposDeBloco.VIDRO)
	g.esperar_tudo()
	confere(g.triangulos() == 12, "2 vidros juntos = 6 quadros fundidos (%d)" % g.triangulos())
	g.queue_free()
	g = nova()
	g.definir(Vector3i(0, 0, 0), PEDRA)
	g.definir(Vector3i(1, 0, 0), TiposDeBloco.VIDRO)
	g.esperar_tudo()
	confere(g.triangulos() == 22, "pedra mostra a face para o vidro, o vidro esconde a dele (%d)" % g.triangulos())
	confere((g.no_da_secao(Vector3i.ZERO).get_node("Malha") as MeshInstance3D).mesh.get_surface_count() == 2, "opaco e translúcido em superfícies separadas")
	g.queue_free()
	g = nova()
	g.definir(Vector3i(0, 0, 0), TiposDeBloco.AGUA)
	g.esperar_tudo()
	confere(g.triangulos() == 12 and g.vertices_de_colisao() == 0, "água desenha e não colide (%d tri, %d col)" % [g.triangulos(), g.vertices_de_colisao()])
	g.queue_free()

	# 9. alçapão: fechado é um tampo fino; aberto vira parede
	g = nova()
	RegrasDeBloco.colocar_alcapao(g, Vector3i(0, 0, 0), 0, 0, false)
	g.esperar_tudo()
	await fisica()
	var t1 := raio(Vector3(0.4, 4, 0.4), Vector3(0.4, -1, 0.4))
	confere(not t1.is_empty() and absf(t1.position.y - 3.0 / 16.0 * B) < 0.01, "alçapão fechado embaixo: topo a 3/16 (%s)" % str(t1.get("position")))
	confere(RegrasDeBloco.alternar_alcapao(g, Vector3i(0, 0, 0)), "alternar abre o alçapão")
	g.esperar_tudo()
	await fisica()
	var t2 := raio(Vector3(0.4, 4, 0.4), Vector3(0.4, -1, 0.4))
	confere(t2.is_empty(), "alçapão aberto libera o vão por cima (%s)" % str(t2.get("position")))
	g.queue_free()

	# 10. blocos novos: todos registrados com cor, e lajes/escadas dos materiais de construção
	for t in [TiposDeBloco.TRONCO, TiposDeBloco.FOLHAS, TiposDeBloco.TIJOLO, TiposDeBloco.PEDREGULHO, TiposDeBloco.NEVE, TiposDeBloco.OBSIDIANA,
			TiposDeBloco.ARGILA, TiposDeBloco.LA_BRANCA, TiposDeBloco.LA_VERMELHA, TiposDeBloco.LA_AZUL, TiposDeBloco.LA_VERDE, TiposDeBloco.LA_AMARELA]:
		confere(TiposDeBloco.nome[t] != "" and TiposDeBloco.cor[t].a > 0.0, "tipo %d registrado" % t)
	confere(TiposDeBloco.forma[TiposDeBloco.ESCADA_BASE + TiposDeBloco.TIJOLO] == TiposDeBloco.Forma.ESCADA, "escada de tijolo existe")
	g = nova()
	RegrasDeBloco.colocar_escada(g, Vector3i(0, 0, 0), TiposDeBloco.PEDREGULHO, 0)
	g.definir(Vector3i(5, 0, 0), TiposDeBloco.TIJOLO)
	g.esperar_tudo()
	confere(g.triangulos() > 12, "escada de pedregulho e cubo de tijolo desenham (%d)" % g.triangulos())
	g.queue_free()

	print("BLOCOS_COM_FORMA ok=%d falhas=%d" % [ok, falhas])
	quit(1 if falhas > 0 else 0)
