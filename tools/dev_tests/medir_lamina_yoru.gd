extends SceneTree
## Mede a GEOMETRIA da lâmina da Yoru: qual eixo local é a espessura, qual é a
## largura (fio<->dorso), e de que lado da largura fica o fio (a aresta afiada).
## godot --headless --path . -s tools/dev_tests/medir_lamina_yoru.gd
func _init() -> void:
	await process_frame
	var cena := load(YoruSword.CAMINHO) as PackedScene
	var raiz := cena.instantiate() as Node3D
	get_root().add_child(raiz)
	print("=== árvore do %s ===" % YoruSword.CAMINHO)
	_arvore(raiz, 0)
	var malhas: Array[MeshInstance3D] = []
	_coletar(raiz, malhas)
	for mi in malhas:
		var m := mi.mesh
		var caixa := m.get_aabb()
		print("\n--- %s  vértices=%d  superfícies=%d" % [mi.name, _n_vertices(m), m.get_surface_count()])
		print("    AABB local  pos=%s  tam=%s" % [caixa.position, caixa.size])
		var t := mi.global_transform
		var mundo := t * caixa
		print("    AABB mundo  pos=%s  tam=%s" % [mundo.position, mundo.size])
		# eixo mais fino = espessura; eixo mais longo = comprimento; o do meio = largura
		var tam := caixa.size
		var eixos := [["X", tam.x], ["Y", tam.y], ["Z", tam.z]]
		eixos.sort_custom(func(a, b): return a[1] < b[1])
		print("    espessura=%s(%.4f)  largura=%s(%.4f)  comprimento=%s(%.4f)"
			% [eixos[0][0], eixos[0][1], eixos[1][0], eixos[1][1], eixos[2][0], eixos[2][1]])
		_perfil(m, eixos[0][0], eixos[1][0], eixos[2][0], caixa)
	quit()

func _arvore(n: Node, d: int) -> void:
	print("%s- %s [%s]" % ["  ".repeat(d), n.name, n.get_class()])
	for c in n.get_children():
		_arvore(c, d + 1)

func _coletar(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		out.append(n)
	for c in n.get_children():
		_coletar(c, out)

func _n_vertices(m: Mesh) -> int:
	var t := 0
	for s in m.get_surface_count():
		t += (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return t

## Fatia o eixo da LARGURA em 10 faixas e mede a espessura média em cada uma.
## O lado que afina até quase zero é o FIO; o lado que fica grosso é o DORSO.
func _perfil(m: Mesh, eixo_esp: String, eixo_larg: String, eixo_comp: String, caixa: AABB) -> void:
	var indice := {"X": 0, "Y": 1, "Z": 2}
	var i_esp: int = indice[eixo_esp]
	var i_larg: int = indice[eixo_larg]
	var i_comp: int = indice[eixo_comp]
	var lo: float = caixa.position[i_larg]
	var tam: float = caixa.size[i_larg]
	var comp_lo: float = caixa.position[i_comp]
	var comp_tam: float = caixa.size[i_comp]
	var faixas := 10
	var mn := []
	var mx := []
	for i in faixas:
		mn.append(1e9)
		mx.append(-1e9)
	for s in m.get_surface_count():
		for v in (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			# só a parte da LÂMINA (metade superior do comprimento), para o cabo
			# e a guarda não sujarem o perfil
			if comp_tam > 0.0 and (v[i_comp] - comp_lo) / comp_tam < 0.45:
				continue
			var k: int = clampi(int((v[i_larg] - lo) / maxf(tam, 1e-6) * faixas), 0, faixas - 1)
			mn[k] = minf(mn[k], v[i_esp])
			mx[k] = maxf(mx[k], v[i_esp])
	# ⚠️ "espessura 0,0000" NÃO é "sem dado" — é a ARESTA (o fio afina até um ponto
	# só). A primeira versão imprimia os dois casos parecido e eu quase registrei o
	# fio como se fosse o dorso. Agora o vazio diz VAZIO e o zero diz FIO.
	print("    perfil da espessura ao longo de %s (só a lâmina, %s > 45%%):" % [eixo_larg, eixo_comp])
	for i in faixas:
		var rotulo := "faixa %d (%s=%+.3f)" % [i, eixo_larg, lo + tam * (i + 0.5) / faixas]
		if mn[i] > 1e8:
			print("      %s: VAZIO (nenhum vértice nesta faixa)" % rotulo)
			continue
		var e: float = mx[i] - mn[i]
		print("      %s: espessura %.4f%s" % [rotulo, e, "   <- ARESTA (afina a zero)" if e < 0.0005 else ""])
