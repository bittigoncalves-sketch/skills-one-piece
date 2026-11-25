extends RefCounted
# ============================================================================
#  RELEVO DAS ILHAS EM BLOCOS (22/10/2026, docs/RELEVO_EM_BLOCOS_PLANO.md, E2).
#
#  Ao montar o Modo História, o relevo liso de cada ilha vira o relevo em blocos
#  (`RelevoEmBlocos`): UM corpo por ilha, com a malha e a colisão fundidas. As peças
#  `terreno` continuam no mapa montado — são a fonte, e a água do rio é delas —, mas
#  sem malha e sem colisão. O editor de mapa não passa por aqui: lá o relevo segue liso.
#  Peça `terreno` fora de qualquer ilha do cadastro fica como estava.
#  O resultado de cada ilha fica em `user://relevo_em_blocos/` (ver `RelevoEmBlocos.VERSAO`).
# ============================================================================

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
## Só para medir/comparar (o medidor de desempenho liga para ter o "antes", relevo liso).
static var desligado := false
## Terreno em BLOCOS de verdade (11/11/2026, docs/MUNDO_VOXEL_PLANO.md, V2b): o relevo antigo fica só como malha DISTANTE (sem colisão)
## e as seções de blocos (`GradeVoxel`) ao redor do jogador têm malha e colisão — é o que a técnica cava e o jogador quebra.
## `false` = o corpo único com a colisão do terreno inteiro (a troca custa ~150 ms por corte).
static var voxel := OS.get_environment("RELEVO_VOXEL") != "0"     # RELEVO_VOXEL=0 volta ao corpo único (comparar/depurar)


## Monta o relevo em blocos de cada ilha dentro de `raiz` (o nó `Mapa`). Devolve os corpos.
static func montar(raiz: Node3D, mapa: Dictionary) -> Array[StaticBody3D]:
	if desligado:
		return []
	var caixas := Ilhas.caixas(mapa)
	var grupos := {}
	for p: Dictionary in mapa.get("pecas", []):
		if p["tipo"] != "terreno":
			continue
		var ilha := Ilhas.ilha_em(caixas, p["posicao"], Ilhas.MARGEM)
		if ilha.is_empty():
			continue
		if not grupos.has(ilha):
			grupos[ilha] = []
		grupos[ilha].append(p)
	var material := _material()
	var corpos: Array[StaticBody3D] = []
	# A conta de cada ilha numa thread (só dados); malha, forma e nós na principal.
	var t0 := Time.get_ticks_msec()
	var ids: Array = grupos.keys()
	var relevos: Array[RelevoEmBlocos] = []
	for ilha in ids:
		relevos.append(RelevoEmBlocos.new())
	var tarefa := WorkerThreadPool.add_group_task(func(k: int) -> void: relevos[k].calcular_ou_ler(grupos[ids[k]], ids[k]),
		ids.size())
	WorkerThreadPool.wait_for_group_task_completion(tarefa)
	print("RELEVO_EM_BLOCOS %d ilhas calculadas em %d ms" % [ids.size(), Time.get_ticks_msec() - t0])
	# V2b: a colisão ANTIGA, em faixas (uma tarefa por ilha). É o chão de todo lugar que não tem seção de blocos carregada.
	var faixas_por_ilha: Array = []
	if voxel:
		faixas_por_ilha.resize(ids.size())
		var t_faixas := WorkerThreadPool.add_group_task(func(k: int) -> void: faixas_por_ilha[k] = _triangular_em_faixas(relevos[k]), ids.size())
		WorkerThreadPool.wait_for_group_task_completion(t_faixas)
		print("RELEVO_EM_BLOCOS colisão em faixas pronta em %d ms" % (Time.get_ticks_msec() - t0))
	for k in ids.size():
		var ilha: String = ids[k]
		var relevo := relevos[k]
		var tri := relevo.calculado
		var corpo := StaticBody3D.new()
		corpo.name = "RelevoEmBlocos_" + ilha
		corpo.set_meta(RelevoEmBlocos.META, relevo)
		corpo.set_meta("ilha", ilha)
		corpo.set_meta("escalavel", false)
		corpo.add_to_group(RelevoEmBlocos.GRUPO)
		var malha := MeshInstance3D.new()
		malha.name = "Malha"
		malha.mesh = relevo.malha(tri)
		var material_longe := _material() if voxel else material     # um por ilha: o furo é da ilha
		malha.material_override = material_longe
		corpo.add_child(malha)
		var forma := CollisionShape3D.new()
		forma.name = "Colisao"
		if voxel:
			forma.disabled = true                    # a colisão é das seções da grade
		else:
			forma.shape = relevo.forma(tri)
		# Os triângulos já viraram malha e colisão: não ficam em memória (dezenas de MB).
		# `cor` e `tipos` só servem para montar; `f` fica (é o `altura()`).
		relevo.calculado = {}
		# `cor` FICA (1 byte por meio): refazer a malha depois de uma cratera precisa dela. `tipos` só conta.
		relevo.tipos = PackedByteArray()
		corpo.add_child(forma)
		if voxel:
			var grade := GradeVoxel.new()
			grade.name = "Grade"
			grade.gerador = GeradorDeRelevo.new(relevo)
			# Com as texturas vanilla, o material é o do próprio bloco (`bloco_minecraft.gdshader`: sem contorno, sem banda de luz).
			if not TexturasDeBloco.tem_textura():
				grade.material = _material()
			grade.material_longe = material_longe as ShaderMaterial
			grade.alvo_de = func() -> Node: return corpo.get_tree().get_first_node_in_group("player") if corpo.is_inside_tree() else null
			for par: Array in faixas_por_ilha[k]:
				var cs := CollisionShape3D.new()
				cs.name = "Faixa_%d_%d" % [(par[0] as Vector2i).x, (par[0] as Vector2i).y]
				var antiga := ConcavePolygonShape3D.new()
				antiga.set_faces(par[1])
				cs.shape = antiga
				corpo.add_child(cs)
				grade.tiles_colisao[par[0]] = cs
			corpo.add_child(grade)
		raiz.add_child(corpo)
		# A peça lisa fica (é a fonte, e a água do rio é filha dela), mas a malha e a
		# forma dela são SOLTAS, não só escondidas: medido em 23/10/2026
		# (`medir_memoria_relevo`), as 520 peças seguravam 73 MB de vídeo e ~1 milhão de
		# triângulos de colisão. A meta `terreno_forma` (seleção do editor, ver
		# `MapaMontador.forma_de_selecao`) também segurava a forma — sai junto.
		soltar_pecas(raiz, grupos[ilha])
		corpos.append(corpo)
		print("RELEVO_EM_BLOCOS %-26s %4d peças -> %6d faces%s" % [ilha, grupos[ilha].size(), relevo.faces,
			" (cache)" if relevo.lido_do_cache else ""])
	print("RELEVO_EM_BLOCOS total %d ms" % (Time.get_ticks_msec() - t0))
	return corpos


## Os triângulos do relevo em faixas de `GradeVoxel.TILE_SECOES`² seções (alinhadas à grade do mundo): [[Vector2i(faixa), vértices], …].
## Roda numa thread (uma por ilha): `triangulos_da_faixa` usa estado interno do relevo, então cada relevo fica numa thread só.
static func _triangular_em_faixas(r: RelevoEmBlocos) -> Array:
	var tam := GradeVoxel.TILE_SECOES * GradeVoxel.LADO * 2          # meios por faixa
	var saida: Array = []
	var faces := r.faces
	var tx0 := floori(float(r.origem.x) / tam)
	var tx1 := floori(float(r.origem.x + r.largura - 1) / tam)
	var tz0 := floori(float(r.origem.y) / tam)
	var tz1 := floori(float(r.origem.y + r.profundidade - 1) / tam)
	for tx in range(tx0, tx1 + 1):
		for tz in range(tz0, tz1 + 1):
			var x0 := maxi(tx * tam - r.origem.x, 0)
			var x1 := mini((tx + 1) * tam - r.origem.x, r.largura)
			var z0 := maxi(tz * tam - r.origem.y, 0)
			var z1 := mini((tz + 1) * tam - r.origem.y, r.profundidade)
			if x1 <= x0 or z1 <= z0:
				continue
			var tri := r.triangulos_da_faixa(x0, x1, z0, z1)
			if not (tri["vertices"] as PackedVector3Array).is_empty():
				saida.append([Vector2i(tx, tz), tri["vertices"]])
	r.faces = faces
	return saida


## A peça lisa fica (é a fonte, e a água do rio é filha dela), mas a malha e a forma dela são SOLTAS. Chamada por ilha quando as
## peças de terreno nascem DEPOIS do relevo (carga por distância, `StreamingDeIlhas`).
static func soltar_pecas(raiz: Node3D, pecas: Array) -> void:
	for p: Dictionary in pecas:
		if p.get("tipo", "") != "terreno":
			continue
		var no := raiz.get_node_or_null(NodePath(String(p["id"])))
		if no == null:
			continue
		var m := no.get_node_or_null("Malha") as MeshInstance3D
		if m:
			m.visible = false
			m.mesh = null
		var c := no.get_node_or_null("Colisao") as CollisionShape3D
		if c:
			c.disabled = true
			c.shape = null
		no.remove_meta("terreno_forma")
		no.remove_meta("terreno_forma_chave")


## O cel shader do relevo, SEM a variação de cor do chão (pedido: blocos sem textura).
static func _material() -> Material:
	var m := Materiais.terreno()
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("usar_variacao_chao", false)
	return m
