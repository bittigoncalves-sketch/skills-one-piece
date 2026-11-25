class_name FundoDoMar
extends StaticBody3D
# ============================================================================
#  FUNDO DO MAR — o chão embaixo do oceano.
#
#  01/10/2026 (docs/AGUA_PLANO.md, A5): rampa lisa da praia até −30 m, para mergulhar.
#  14/10/2026 (docs/MAR_HISTORIA_PLANO.md, E1): RELEVO MARINHO de verdade — plataforma
#  com baixios, dunas e rochas, talude com ravinas, mar aberto a ~−64 m e fossa entre as
#  ilhas. A altura vem de UM campo do mundo (`RelevoMarinho`); este nó só o desenha e dá
#  colisão. Os primeiros 60 m da costa seguem a rampa de antes (porto e vagas do cais).
#
#  Peça de MUNDO gerada em tempo de jogo, como o `Oceano`: não vai para o arquivo do
#  mapa (não incha o mapa nem quebra o pincel de relevo).
#
#  BLOCOS (14/10): uma grade GLOBAL de 4 m partida em blocos de 128 m. Cada bloco é uma
#  malha (alcance de desenho próprio: só os blocos perto da câmera são desenhados) e
#  uma forma de colisão. Cada bloco pertence à ilha mais perto dele — um `FundoDoMar`
#  por ilha, POSICIONADO no centro dela (o desenho por distância decide a ilha de um nó
#  pela posição; antes os dois nós ficavam na origem e o dos Macacos caía na inicial).
#  Bloco que encosta na ilha tem a colisão partida em pedaços de 32 m, sem os pedaços
#  embaixo dela: forma embaixo da ilha entra no teste de movimento de todo bicho
#  (medido 01/10/2026: ~0,9 ms por quadro com 23 animais quando era uma forma só).
#
#  Fora da grade, o ABISMO (`AbismoDoMar`): moldura plana na altura da borda do campo,
#  com colisão — antes, além de 600 m da ilha, quem mergulhava caía no vazio.
# ============================================================================

const SHADER := preload("res://src/world/fundo_do_mar.gdshader")
const OCEANO := preload("res://src/world/oceano_historia.gd")
## Quanto o fundo detalhado avança mar adentro além da ilha mais externa.
const ALCANCE := 600.0
const CELULA := 4.0
const CELULAS_POR_BLOCO := 32
const BLOCO := CELULA * CELULAS_POR_BLOCO
const CELULAS_POR_PEDACO := 8
## Distância da câmera (m) em que um bloco deixa de ser desenhado; folga contra pisca.
## A superfície é opaca (decisão do dono, 14/10): o fundo só aparece mergulhando.
const ALCANCE_DE_DESENHO := 420.0
const FOLGA_DE_DESENHO := 20.0
## Bloco só submerso (E7, 14/10/2026): a névoa da água deixa ~1 % a 110 m.
const ALCANCE_SUBMERSO := 170.0
const LARGURA_DO_ABISMO := 4000.0

## Placa (x, z) da ilha deste fundo.
var placa := Rect2()
## O campo de altura compartilhado por todos os fundos (o mesmo objeto).
var relevo: RelevoMarinho
var _material: ShaderMaterial


## Um fundo por ilha, filhos de `pai`. O da ilha com a baseplate `baseplate` se chama
## "FundoDoMar"; os outros, "FundoDoMar_<resto do id da 1ª baseplate>". Também cria o
## `AbismoDoMar` em `pai`. `nivel_do_mar`: o do `Oceano` (sem ele, a mesma conta dele).
static func montar_por_ilha(pai: Node, mapa: Dictionary, bases: Array, nivel_do_mar := NAN) -> Array[FundoDoMar]:
	var m := preparar_por_ilha(pai, mapa, bases, nivel_do_mar)
	m.bloquear = true
	while m.passo():
		pass
	return m.fundos


## O mesmo trabalho em PASSOS (a TELA DE CARREGAMENTO devolve o quadro entre eles; 28/10/2026, medido: a amostragem do relevo
## do fundo leva ~10 s no mapa vivo). `while m.passo(): await ...`; ao fim, `m.fundos` tem o que `montar_por_ilha` devolve.
static func preparar_por_ilha(pai: Node, mapa: Dictionary, bases: Array, nivel_do_mar := NAN) -> Montagem:
	var fundos: Array[FundoDoMar] = []
	if bases.is_empty():
		return Montagem.new(pai, null, fundos, null)
	var ilhas := agrupar(bases)
	var placas: Array[Rect2] = []
	for ilha in ilhas:
		placas.append(caixa_de(ilha))
	if is_nan(nivel_do_mar):
		nivel_do_mar = INF
		for b: Dictionary in bases:
			nivel_do_mar = minf(nivel_do_mar, (b["posicao"] as Vector3).y + (b["tamanho"] as Vector3).y * 0.5)
		nivel_do_mar += float((OCEANO as Script).get_property_default_value("nivel_relativo"))
	var terrenos: Array = mapa.get("pecas", []).filter(func(p: Dictionary) -> bool: return p.get("tipo") == "terreno")
	var relevo := RelevoMarinho.new()
	relevo.relevo_em = _relevo_em.bind(terrenos)
	relevo.configurar(placas, ALCANCE, nivel_do_mar)
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("nivel", nivel_do_mar)
	# Debaixo d'água a luz é difusa (a água espalha): piso de sombra alto e borda de faixa
	# macia. Com o piso do mundo (0,16) e sol baixo, cada duna trocava de faixa e o fundo
	# virava listras de alto contraste (foto E1, 14/10).
	material.set_shader_parameter("sombra_min", 0.5)
	material.set_shader_parameter("suavidade", 0.16)
	for k in ilhas.size():
		var fundo := FundoDoMar.new()
		var nome := "FundoDoMar"
		if not ilhas[k].any(func(b: Dictionary) -> bool: return b["id"] == "baseplate"):
			nome += "_" + String(ilhas[k][0]["id"]).trim_prefix("baseplate_")
		fundo.name = nome
		fundo.placa = placas[k]
		fundo.relevo = relevo
		fundo._material = material
		fundo.collision_layer = 1
		fundo.collision_mask = 0
		pai.add_child(fundo)
		fundo.position = Vector3(placas[k].get_center().x, 0.0, placas[k].get_center().y)
		fundos.append(fundo)
	var m := Montagem.new(pai, relevo, fundos, material)
	m.chave_do_cache = _chave_do_cache(placas, nivel_do_mar, terrenos)
	return m


## Chave do cache em disco da grade: tudo o que muda o resultado (placas das ilhas, nível do mar, o relevo dos TERRENOS — que dá a
## altura da praia —, o tamanho da célula/bloco e o CÓDIGO do relevo). Mudar uma árvore, um NPC ou um modelo não a invalida.
static func _chave_do_cache(placas: Array[Rect2], nivel_do_mar: float, terrenos: Array) -> String:
	var partes := PackedStringArray([str(placas), str(nivel_do_mar), str(ALCANCE), str(CELULA), str(CELULAS_POR_BLOCO),
		FileAccess.get_sha256("res://src/world/relevo_marinho.gd")])
	for t: Dictionary in terrenos:
		partes.append(JSON.stringify({"p": var_to_str(t["posicao"]), "t": var_to_str(t["tamanho"]), "r": t["relevo"]}, "", true))
	return "\n".join(partes).sha256_text().substr(0, 20)


## Baseplates que se tocam (ou se sobrepõem) = uma ilha.
static func agrupar(bases: Array) -> Array[Array]:
	var ilhas: Array[Array] = []
	for b: Dictionary in bases:
		var junto: Array = [b]
		var resto: Array[Array] = []
		for ilha in ilhas:
			if ilha.any(func(o: Dictionary) -> bool: return caixa_de([o]).grow(0.5).intersects(caixa_de([b]))):
				junto.append_array(ilha)
			else:
				resto.append(ilha)
		resto.append(junto)
		ilhas = resto
	return ilhas


## Caixa (x, z) que envolve as baseplates.
static func caixa_de(bases: Array) -> Rect2:
	var r := Rect2()
	for k in bases.size():
		var pos: Vector3 = bases[k]["posicao"]
		var tam: Vector3 = bases[k]["tamanho"]
		var b := Rect2(pos.x - tam.x * 0.5, pos.z - tam.z * 0.5, tam.x, tam.z)
		r = b if k == 0 else r.merge(b)
	return r


## Altura da praia lida do RELEVO da ilha no ponto p (0 fora dos blocos de terreno).
static func _relevo_em(p: Vector2, terrenos: Array) -> float:
	for t: Dictionary in terrenos:
		var pos: Vector3 = t["posicao"]
		var tam: Vector3 = t["tamanho"]
		if absf(p.x - pos.x) <= tam.x * 0.5 and absf(p.y - pos.z) <= tam.z * 0.5:
			var y := TerrenoDoMapa.altura_local(t["relevo"], tam, p.x - pos.x, p.y - pos.z)
			if not is_nan(y):
				return pos.y + y
	return 0.0


## Amostra a grade global (com uma célula de margem, para as normais da borda) e entrega cada bloco ao fundo da ilha mais perto,
## EM PASSOS: 1) linhas da grade (`LINHAS_POR_PASSO` por passo), 2) uma fileira de blocos por passo, 3) o abismo.
class Montagem:
	extends RefCounted
	const LINHAS_POR_TAREFA := 8
	## Medido (i5-13420H, 12 threads lógicas): o `FastNoiseLite` e o relevo escalam até 4 threads (2,5× mais rápido) e PIORAM acima
	## disso (8 threads: 4,6 s; 12: 6,5 s; 4: 1,9 s). Prioridade ALTA: o pool só dá 30 % das threads às de baixa.
	const LIMITE_DE_THREADS := 4
	const PASTA_DO_CACHE := "user://cache"
	## Os testes apontam para uma pasta PRÓPRIA (a limpeza das grades antigas apagaria o cache do jogo).
	var pasta_do_cache := PASTA_DO_CACHE
	const MAGICA := "SOP-FUNDO-1"
	var fundos: Array[FundoDoMar]
	## Chave do cache em disco (vazia = sem cache). Quem chama sem tela (`montar_por_ilha`) liga `bloquear`.
	var chave_do_cache := ""
	var bloquear := false
	## De onde veio a grade: "cache" ou "threads" (para a tela e os testes).
	var origem := ""
	var _pai: Node
	var _relevo: RelevoMarinho
	var _material: ShaderMaterial
	var _fase := 0                  # 0 grade · 1 blocos · 2 abismo · 3 pronto
	var _x0 := 0.0
	var _z0 := 0.0
	var _nbx := 0
	var _nbz := 0
	var _grade := {}
	var _alturas := PackedFloat32Array()
	var _mascaras := PackedColorArray()
	var _bj := 0
	# amostragem em threads
	var _tarefa := -1
	var _n_tarefas := 0
	var _resultados: Array = []
	var _feitas := 0
	var _mutex := Mutex.new()
	var _copias := {}               # id da thread -> RelevoMarinho próprio

	func _init(pai: Node, relevo: RelevoMarinho, fundos_: Array[FundoDoMar], material: ShaderMaterial) -> void:
		_pai = pai
		_relevo = relevo
		fundos = fundos_
		_material = material
		if relevo == null:
			_fase = 3
			return
		var lim := relevo.limite
		_x0 = floorf(lim.position.x / BLOCO) * BLOCO
		_z0 = floorf(lim.position.y / BLOCO) * BLOCO
		_nbx = int(ceil((lim.end.x - _x0) / BLOCO))
		_nbz = int(ceil((lim.end.y - _z0) / BLOCO))
		_grade = {"x0": _x0 - CELULA, "z0": _z0 - CELULA,
			"nx": _nbx * CELULAS_POR_BLOCO + 3, "nz": _nbz * CELULAS_POR_BLOCO + 3}

	## Faz um pedaço do trabalho. Devolve true enquanto ainda falta.
	func passo() -> bool:
		match _fase:
			0:
				_passo_da_grade()
			1:
				for bi in _nbx:
					var r := Rect2(_x0 + bi * BLOCO, _z0 + _bj * BLOCO, BLOCO, BLOCO)
					if fundos.any(func(f: FundoDoMar) -> bool: return f.placa.grow(-CELULA).encloses(r)):
						continue                  # bloco todo embaixo de uma ilha: ninguém vê
					var dono := fundos[0]
					for f in fundos:
						if RelevoMarinho._fora(f.placa, r.get_center()) < RelevoMarinho._fora(dono.placa, r.get_center()):
							dono = f
					dono._bloco(_grade, bi * CELULAS_POR_BLOCO + 1, _bj * CELULAS_POR_BLOCO + 1, r)
				_bj += 1
				if _bj >= _nbz:
					_fase = 2
			2:
				_pai.add_child(FundoDoMar._abismo(_relevo, _material))
				_fase = 3
		return _fase < 3

	# ---- fase 0: a grade de alturas/máscaras (cache em disco, senão threads) ----
	func _passo_da_grade() -> void:
		if _tarefa == -1:
			if _ler_cache():
				origem = "cache"
				_fase = 1
				return
			_n_tarefas = int(ceil(float(_grade.nz) / LINHAS_POR_TAREFA))
			_resultados.resize(_n_tarefas)
			origem = "threads"
			_tarefa = WorkerThreadPool.add_group_task(_trabalhar, _n_tarefas, mini(LIMITE_DE_THREADS, maxi(OS.get_processor_count() / 2, 1)), true, "fundo do mar")
		if not bloquear and not WorkerThreadPool.is_group_task_completed(_tarefa):
			return
		WorkerThreadPool.wait_for_group_task_completion(_tarefa)
		_alturas.resize(0)
		_mascaras.resize(0)
		for r: Array in _resultados:
			_alturas.append_array(r[0])
			_mascaras.append_array(r[1])
		_resultados.clear()
		_grade["alturas"] = _alturas
		_grade["mascaras"] = _mascaras
		_gravar_cache()
		_fase = 1

	## Roda numa thread do pool: um pacote de linhas da grade, com a cópia do relevo DESTA thread.
	func _trabalhar(k: int) -> void:
		var copia := _copia_desta_thread()
		var j0 := k * LINHAS_POR_TAREFA
		var j1 := mini(j0 + LINHAS_POR_TAREFA, int(_grade.nz))
		# Valores LOCAIS: ler `_grade` (um Dictionary compartilhado) por amostra, de todas as threads, disputava o contador atômico dele.
		var nx: int = _grade.nx
		var gx0: float = _grade.x0
		var gz0: float = _grade.z0
		var alt := PackedFloat32Array()
		var mas := PackedColorArray()
		alt.resize((j1 - j0) * nx)
		mas.resize((j1 - j0) * nx)
		for j in range(j0, j1):
			var z: float = gz0 + j * CELULA
			for i in nx:
				var s := copia.amostra(gx0 + i * CELULA, z)
				alt[(j - j0) * nx + i] = s.x
				mas[(j - j0) * nx + i] = Color(s.y, s.z, s.w)
		_mutex.lock()
		_resultados[k] = [alt, mas]
		_feitas += 1
		_mutex.unlock()

	func _copia_desta_thread() -> RelevoMarinho:
		var id := OS.get_thread_caller_id()
		_mutex.lock()
		var c: RelevoMarinho = _copias.get(id)
		_mutex.unlock()
		if c == null:
			c = _relevo.duplicar()
			_mutex.lock()
			_copias[id] = c
			_mutex.unlock()
		return c

	# ---- cache em disco ----
	func _caminho_do_cache() -> String:
		return pasta_do_cache.path_join("fundo_do_mar_%s.bin" % chave_do_cache)

	func _ler_cache() -> bool:
		if chave_do_cache.is_empty() or not FileAccess.file_exists(_caminho_do_cache()):
			return false
		var f := FileAccess.open(_caminho_do_cache(), FileAccess.READ)
		if f == null:
			return false
		var ok := f.get_pascal_string() == MAGICA and f.get_pascal_string() == chave_do_cache \
			and f.get_32() == int(_grade.nx) and f.get_32() == int(_grade.nz)
		if not ok:
			return false
		var tam_alt := f.get_64()
		var tam_mas := f.get_64()
		var tam_comp_alt := f.get_64()
		var tam_comp_mas := f.get_64()
		var alt := f.get_buffer(tam_comp_alt).decompress(tam_alt, FileAccess.COMPRESSION_ZSTD)
		var mas := f.get_buffer(tam_comp_mas).decompress(tam_mas, FileAccess.COMPRESSION_ZSTD)
		var total: int = int(_grade.nx) * int(_grade.nz)
		if alt.size() != total * 4 or mas.size() != total * 16:
			return false                          # arquivo truncado/de outro formato: ignora e recalcula
		_alturas = alt.to_float32_array()
		var cores := mas.to_float32_array()
		_mascaras = PackedColorArray()
		_mascaras.resize(total)
		for k in total:
			_mascaras[k] = Color(cores[k * 4], cores[k * 4 + 1], cores[k * 4 + 2], cores[k * 4 + 3])
		_grade["alturas"] = _alturas
		_grade["mascaras"] = _mascaras
		return true

	func _gravar_cache() -> void:
		if chave_do_cache.is_empty():
			return
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta_do_cache))
		var cores := PackedFloat32Array()
		cores.resize(_mascaras.size() * 4)
		for k in _mascaras.size():
			var c := _mascaras[k]
			cores[k * 4] = c.r
			cores[k * 4 + 1] = c.g
			cores[k * 4 + 2] = c.b
			cores[k * 4 + 3] = c.a
		var alt := _alturas.to_byte_array()
		var mas := cores.to_byte_array()
		var comp_alt := alt.compress(FileAccess.COMPRESSION_ZSTD)
		var comp_mas := mas.compress(FileAccess.COMPRESSION_ZSTD)
		var caminho := _caminho_do_cache()
		var f := FileAccess.open(caminho + ".tmp", FileAccess.WRITE)
		if f == null:
			return
		f.store_pascal_string(MAGICA)
		f.store_pascal_string(chave_do_cache)
		f.store_32(int(_grade.nx))
		f.store_32(int(_grade.nz))
		f.store_64(alt.size())
		f.store_64(mas.size())
		f.store_64(comp_alt.size())
		f.store_64(comp_mas.size())
		f.store_buffer(comp_alt)
		f.store_buffer(comp_mas)
		f.close()
		DirAccess.rename_absolute(ProjectSettings.globalize_path(caminho + ".tmp"), ProjectSettings.globalize_path(caminho))
		# Só a grade mais recente: as de chaves antigas (mapa editado) saem.
		for nome in DirAccess.get_files_at(pasta_do_cache):
			if nome.begins_with("fundo_do_mar_") and nome != caminho.get_file():
				DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta_do_cache.path_join(nome)))

	## (feito, total, texto) para a tela: a grade vale a primeira metade da barra, os blocos a segunda.
	func andamento() -> Array:
		match _fase:
			0:
				_mutex.lock()
				var feitas := _feitas
				_mutex.unlock()
				var total := maxi(_n_tarefas, 1)
				return [feitas * int(_grade.nz) / total, int(_grade.nz) * 2,
					"medindo o relevo do fundo do mar (%d de %d pacotes, %d threads)" % [feitas, _n_tarefas, OS.get_processor_count()]]
			1:
				return [int(_grade.nz) + _bj * int(_grade.nz) / maxi(_nbz, 1), int(_grade.nz) * 2,
					"montando os blocos do fundo do mar (fileira %d de %d)" % [_bj, _nbz]]
		return [1, 1, "fechando o fundo do mar"]


## Um bloco: malha + colisão. (i0, j0) = canto do bloco na grade global.
func _bloco(grade: Dictionary, i0: int, j0: int, r: Rect2) -> void:
	var nx: int = grade.nx
	var alturas: PackedFloat32Array = grade.alturas
	var mascaras: PackedColorArray = grade.mascaras
	var n := CELULAS_POR_BLOCO + 1
	var origem := Vector2(position.x, position.z)
	var vertices := PackedVector3Array()
	var normais := PackedVector3Array()
	var cores := PackedColorArray()
	vertices.resize(n * n)
	normais.resize(n * n)
	cores.resize(n * n)
	for j in n:
		for i in n:
			var gi := i0 + i
			var gj := j0 + j
			var k := gj * nx + gi
			var x: float = grade.x0 + gi * CELULA
			var z: float = grade.z0 + gj * CELULA
			vertices[j * n + i] = Vector3(x - origem.x, alturas[k], z - origem.y)
			var dx := alturas[k + 1] - alturas[k - 1]
			var dz := alturas[k + nx] - alturas[k - nx]
			normais[j * n + i] = Vector3(-dx, 2.0 * CELULA, -dz).normalized()
			cores[j * n + i] = mascaras[k]
	var indices := PackedInt32Array()
	var dentro := placa.grow(-0.01)
	for j in CELULAS_POR_BLOCO:
		for i in CELULAS_POR_BLOCO:
			var a := j * n + i
			# Célula inteira debaixo da ilha: ninguém vê.
			var canto := Vector2(r.position.x + i * CELULA, r.position.y + j * CELULA)
			if dentro.encloses(Rect2(canto, Vector2.ONE * CELULA)):
				continue
			indices.append_array([a, a + n + 1, a + n, a, a + 1, a + n + 1])   # horário visto de cima
	if indices.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normais
	arrays[Mesh.ARRAY_COLOR] = cores
	arrays[Mesh.ARRAY_INDEX] = indices
	var malha := ArrayMesh.new()
	malha.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Bloco_%d_%d" % [roundi(r.position.x), roundi(r.position.y)]
	mi.mesh = malha
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end_margin = FOLGA_DE_DESENHO
	# Bloco que nunca chega perto da superfície só se vê mergulhando, e a névoa da água
	# (E7) apaga tudo além de ~60 m: alcance curto e escondido de cima (grupo da
	# `VisaoSubmersa`). O da costa (areia molhada à vista de fora d'água) fica sempre.
	var mais_alto := -INF
	for v in vertices:
		mais_alto = maxf(mais_alto, v.y)
	if mais_alto < relevo.nivel - 2.0:
		mi.visibility_range_end = ALCANCE_SUBMERSO
		mi.add_to_group("so_submerso")
	else:
		mi.visibility_range_end = ALCANCE_DE_DESENHO
	add_child(mi)
	# Colisão: o bloco inteiro numa forma; perto da ilha, em pedaços sem os de baixo dela.
	if placa.grow(BLOCO * 0.5).intersects(r):
		var passos := CELULAS_POR_BLOCO / CELULAS_POR_PEDACO
		for pj in passos:
			for p_i in passos:
				var pr := Rect2(r.position + Vector2(p_i, pj) * CELULA * CELULAS_POR_PEDACO, Vector2.ONE * CELULA * CELULAS_POR_PEDACO)
				if placa.grow(-CELULA).encloses(pr):
					continue
				_forma(grade, i0 + p_i * CELULAS_POR_PEDACO, j0 + pj * CELULAS_POR_PEDACO, CELULAS_POR_PEDACO, pr)
	else:
		_forma(grade, i0, j0, CELULAS_POR_BLOCO, r)


## Um pedaço da grade como HeightMapShape3D. A forma tem 1 unidade entre pontos: escala
## UNIFORME pela célula (escala não uniforme em forma de colisão é desaconselhada) e
## alturas divididas por ela. Pedaços vizinhos dividem a fileira da emenda: sem fresta.
func _forma(grade: Dictionary, i0: int, j0: int, celulas: int, r: Rect2) -> void:
	var nx: int = grade.nx
	var alturas: PackedFloat32Array = grade.alturas
	var hm := HeightMapShape3D.new()
	hm.map_width = celulas + 1
	hm.map_depth = celulas + 1
	var dados := PackedFloat32Array()
	dados.resize(hm.map_width * hm.map_depth)
	for j in hm.map_depth:
		for i in hm.map_width:
			dados[j * hm.map_width + i] = alturas[(j0 + j) * nx + (i0 + i)] / CELULA
	hm.map_data = dados
	var cs := CollisionShape3D.new()
	cs.name = "Colisao_%d_%d" % [roundi(r.position.x), roundi(r.position.y)]
	cs.shape = hm
	cs.scale = Vector3.ONE * CELULA
	cs.position = Vector3(r.get_center().x - position.x, 0.0, r.get_center().y - position.z)
	add_child(cs)


## Moldura plana em volta da grade, na altura da borda do campo, com colisão.
static func _abismo(relevo: RelevoMarinho, material: ShaderMaterial) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	corpo.name = "AbismoDoMar"
	corpo.collision_layer = 1
	corpo.collision_mask = 0
	var lim := relevo.limite
	var y := RelevoMarinho.BORDA_DO_MUNDO - 0.05
	var w := LARGURA_DO_ABISMO
	var faixas := [
		Rect2(lim.position.x - w, lim.position.y - w, lim.size.x + 2.0 * w, w),   # norte
		Rect2(lim.position.x - w, lim.end.y, lim.size.x + 2.0 * w, w),            # sul
		Rect2(lim.position.x - w, lim.position.y, w, lim.size.y),                 # oeste
		Rect2(lim.end.x, lim.position.y, w, lim.size.y),                          # leste
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	st.set_color(Color(0, 0, 0))
	for f: Rect2 in faixas:
		var a := Vector3(f.position.x, y, f.position.y)
		var b := Vector3(f.end.x, y, f.position.y)
		var c := Vector3(f.position.x, y, f.end.y)
		var d := Vector3(f.end.x, y, f.end.y)
		for v in [a, d, c, a, b, d]:
			st.add_vertex(v)
		var cs := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = Vector3(f.size.x, 2.0, f.size.y)
		cs.shape = caixa
		cs.position = Vector3(f.get_center().x, y - 1.0, f.get_center().y)
		corpo.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.name = "Malha"
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	corpo.add_child(mi)
	return corpo
