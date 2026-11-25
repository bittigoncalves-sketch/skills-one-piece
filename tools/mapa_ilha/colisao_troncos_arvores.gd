extends SceneTree
# ============================================================================
#  COLISÃO SÓ NOS TRONCOS das árvores antigas da loja (01/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/mapa_ilha/colisao_troncos_arvores.gd
#
#  Decisão do dono: os aglomerados `trees` e `pine_trees` (171 no mapa, até 29 m de
#  largura) colidiam pela MALHA INTEIRA — galhos e cones de folhagem. Bicho entrava entre
#  os galhos e ficava encaixado sem saída (o urso do test_animais), e o jogador esbarrava
#  nas copas. Passam a colidir só pelos TRONCOS, como as árvores novas.
#
#  Usa as PARTES CONVEXAS da loja (o mecanismo das construções: `<id>.colisao.json` com o
#  SHA do .glb; o .glb importado pelo dono não é tocado). Uma parte por tronco: a malha
#  do material "Wood" separada em pedaços conectados, só a parte de baixo de cada um
#  (`ATE`), onde estão o tronco e não os galhos altos.
# ============================================================================

const ARVORES := ["trees", "pine_trees"]
const MATERIAL_DO_TRONCO := "wood"
const ATE := 0.6          # fração da altura do pedaço que vira colisão (tronco, sem a copa)


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var erros := 0
	for id: String in ARVORES:
		if not bib.tem(id):
			push_error("fora da loja: " + id)
			erros += 1
			continue
		var partes := _troncos(bib, id)
		if partes.is_empty():
			push_error("%s: nenhum tronco achado (material \"%s\")" % [id, MATERIAL_DO_TRONCO])
			erros += 1
			continue
		erros += int(bib.definir_partes_de_colisao(id, partes) != OK)
		print("TRONCOS %-11s %d partes convexas" % [id, partes.size()])
	quit(1 if erros else 0)


func _troncos(bib: BibliotecaDeModelos, id: String) -> Array:
	var modelo := bib.instanciar(id)
	var partes: Array = []
	for mi: MeshInstance3D in modelo.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or BibliotecaDeModelos.e_malha_de_colisao(mi):
			continue
		var t := BibliotecaDeModelos._transformacao_ate(mi, modelo)
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s)
			if mat == null or not mat.resource_name.to_lower().contains(MATERIAL_DO_TRONCO):
				continue
			var arr := mi.mesh.surface_get_arrays(s)
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			partes.append_array(_pedacos(t * v, idx))
	modelo.free()
	return partes


## Pedaços conectados da malha (união-busca pelos triângulos), cada um cortado na parte
## de baixo. Vértices repetidos na mesma posição (costura de UV) contam como o mesmo.
func _pedacos(v: PackedVector3Array, idx: PackedInt32Array) -> Array:
	var pai := PackedInt32Array()
	pai.resize(v.size())
	for i in v.size():
		pai[i] = i
	var mesma_posicao := {}
	for i in v.size():
		var chave := v[i].snapped(Vector3.ONE * 0.0005)
		if mesma_posicao.has(chave):
			_unir(pai, i, mesma_posicao[chave])
		else:
			mesma_posicao[chave] = i
	var n_tri := idx.size() / 3 if not idx.is_empty() else v.size() / 3
	for k in n_tri:
		var a := idx[k * 3] if not idx.is_empty() else k * 3
		var b := idx[k * 3 + 1] if not idx.is_empty() else k * 3 + 1
		var c := idx[k * 3 + 2] if not idx.is_empty() else k * 3 + 2
		_unir(pai, a, b)
		_unir(pai, a, c)
	# ⚠️ PackedVector3Array é VALOR: `append` numa cópia tirada do dicionário não muda o
	# que está guardado — junta numa Array (referência) e converte no fim.
	var grupos := {}
	for i in v.size():
		var r := _raiz(pai, i)
		if not grupos.has(r):
			grupos[r] = []
		(grupos[r] as Array).append(v[i])
	# Chão do modelo: o pedaço que não nasce nele é galho solto no meio da copa (o jogador
	# e os bichos não o alcançam) — fica de fora.
	var chao := INF
	var topo := -INF
	for p in v:
		chao = minf(chao, p.y)
		topo = maxf(topo, p.y)
	var saida: Array = []
	for lista: Array in grupos.values():
		var g := PackedVector3Array(lista)
		var mais_baixo := INF
		for p in g:
			mais_baixo = minf(mais_baixo, p.y)
		if mais_baixo > chao + (topo - chao) * 0.05:
			continue
		var lo := INF
		var hi := -INF
		for p in g:
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		var corte := lo + (hi - lo) * ATE
		var baixo := PackedVector3Array()
		for p in g:
			if p.y <= corte:
				baixo.append(p)
		if baixo.size() >= 4:
			saida.append(baixo)
	return saida


func _raiz(pai: PackedInt32Array, i: int) -> int:
	while pai[i] != i:
		pai[i] = pai[pai[i]]
		i = pai[i]
	return i


func _unir(pai: PackedInt32Array, a: int, b: int) -> void:
	var ra := _raiz(pai, a)
	var rb := _raiz(pai, b)
	if ra != rb:
		pai[ra] = rb
