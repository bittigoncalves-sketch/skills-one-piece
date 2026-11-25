class_name GradeVoxel
extends Node3D
# ============================================================================
#  GRADE VOXEL EM SEÇÕES (11/11/2026, docs/MUNDO_VOXEL_PLANO.md, etapas V1 e V3) — o mundo de blocos ao estilo Minecraft.
#
#  Pedido do dono: "transformar o jogo em um jogo de blocos também" e diminuir o custo de quebrar terreno e
#  construções. A causa medida do travamento (~150 ms por corte): o relevo de cada ilha é UMA malha e UMA colisão
#  (465 mil vértices na ilha inicial); cortar qualquer coisa troca a colisão inteira.
#
#  COMO O MINECRAFT FAZ (e aqui também):
#    · o mundo é dividido em SEÇÕES de 16³ blocos; cada uma tem a sua malha e a sua colisão;
#    · mexer num bloco suja só a seção dele (e a vizinha, se ele está na borda);
#    · a malha só tem as faces VISÍVEIS (face coberta por vizinho opaco não existe);
#    · a malha é refeita numa thread e entra no quadro seguinte; entram poucas seções por quadro.
#  Diferença daqui: o Minecraft não tem colisão em malha (consulta o bloco); a Godot precisa de forma, então a
#  malha das faces visíveis é também a colisão — e as faces vizinhas do mesmo cubo são fundidas (guloso), como no
#  `RelevoEmBlocos`, para a forma ter poucos triângulos.
#
#  Grade do MUNDO: bloco = 0,88 m (a mesma do Mine Piece), origem em (0, 0, 0). Valor da célula = tipo | estado << 12
#  (`TiposDeBloco`): cubo, laje, escada, porta, painel; opaco ou translúcido (gelo, vidro, água); com ou sem colisão.
# ============================================================================

## Grupo das grades de terreno (uma por ilha): quem escava ou consulta o chão as procura por ele.
const GRUPO := &"grade_voxel"
const LADO := 16
## Lado da faixa de colisão antiga, em seções (a mesma divisão do `RelevoDasIlhas`).
const TILE_SECOES := 4
const BLOCO := 0.88
const VOLUME := LADO * LADO * LADO
const PAD := LADO + 2
## Octantes (meio bloco) por lado da seção.
const OCT := LADO * 2
## Cada face avança isto sobre as vizinhas (junção em T sem fresta de um pixel; ver `RelevoEmBlocos.SOBRA`).
const SOBRA := 0.002
const CAMADA_MUNDO := 1
## Tarefas de malha em voo ao mesmo tempo (as threads do jogo não se afogam numa cratera grande).
const MAX_TAREFAS := 16

# Atalhos dos tipos mais usados (valor de cubo = o próprio tipo).
const AR := TiposDeBloco.AR
const GRAMA := TiposDeBloco.GRAMA
const TERRA := TiposDeBloco.TERRA
const PEDRA := TiposDeBloco.PEDRA
const AREIA := TiposDeBloco.AREIA
const MADEIRA := TiposDeBloco.MADEIRA
const GELO := TiposDeBloco.GELO
const BASALTO := TiposDeBloco.BASALTO

## Seções refeitas por quadro, no máximo (cada troca de forma custa na thread principal).
var trocas_por_quadro := 2
var material: Material
var material_translucido: Material
## Estatística: quantas malhas de seção foram despachadas (testes e medição).
var reconstrucoes := 0

## Terreno de base, gerado sob demanda (ver `GeradorDeRelevo`). Seção sem dados guardados vem daqui; seção editada fica em `_secoes`.
var gerador: GeradorDeRelevo
## Quem a grade segue: devolve o `Node3D` (o jogador). As seções num raio ao redor dele têm malha e colisão; as outras, não.
var alvo_de := Callable()
var raio_secoes := 8
## Material da malha DISTANTE (o relevo antigo, só desenho): recebe o furo onde as seções de blocos já cobrem (`furo_caixa` do cel shader).
var material_longe: ShaderMaterial
var _prontas := {}                               # Vector3i → true: malha aplicada (mesmo vazia) e não suja
var _relogio_seguir := 0.0
var _furo_ativo := false
var _sc_alvo := Vector3i(1 << 30, 0, 0)
var _malhas := {}                                # Vector3i → MeshInstance3D (para ligar/desligar o desenho sem mexer na colisão)
## Colisão ANTIGA do relevo, em faixas de TILE_SECOES × TILE_SECOES seções (Vector2i → CollisionShape3D). Faixa sem seção carregada
## usa a colisão antiga (o terreno intocado, em qualquer lugar da ilha — bichos, spawn e raios longe do jogador seguem achando chão);
## faixa ativa (perto do jogador ou com edição) usa as seções de blocos e desliga a antiga SÓ quando todas estão prontas.
## Vazio = sem faixas: só o anel do jogador carrega (testes sintéticos).
var tiles_colisao := {}
var _tile_estado := {}                           # Vector2i → 1 carregando, 2 ativa
var _secoes := {}                                # Vector3i (seção) → PackedInt32Array(VOLUME): só o que foi editado (ou tudo, sem gerador)
var _nos := {}                                   # Vector3i → StaticBody3D (só seções com face)
var _sujas := {}                                 # Vector3i → true (em ordem de chegada)
var _tarefas := {}                               # Vector3i → {id, resultado}


func _init() -> void:
	TiposDeBloco.iniciar()
	TexturasDeBloco.iniciar()
	material = _material_de_blocos(false)
	material_translucido = _material_de_blocos(true)


## Material dos blocos: o shader de textura vanilla; sem as texturas locais, o mesmo visual de antes (cor por vértice).
static func _material_de_blocos(translucido: bool) -> Material:
	if TexturasDeBloco.tem_textura():
		var sh := Shader.new()
		var codigo := (load("res://src/voxel/bloco_minecraft.gdshader") as Shader).code
		sh.code = ("#define TRANSLUCIDO\n" if translucido else "") + codigo
		var sm := ShaderMaterial.new()
		sm.shader = sh
		sm.set_shader_parameter("blocos", TexturasDeBloco.matriz)
		sm.set_shader_parameter("grama_personalizada", TexturasDeBloco.GRAMA_PERSONALIZADA)
		sm.set_shader_parameter("camada_grama", float(TexturasDeBloco.camada(TiposDeBloco.GRAMA, 3)))
		return sm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.roughness = 1.0
	if translucido:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _ready() -> void:
	add_to_group(GRUPO)


func _exit_tree() -> void:
	# Tarefa de malha em voo não pode sobreviver à grade (a thread leria dados liberados e o jogo abortaria ao fechar).
	for sc: Vector3i in _tarefas.keys():
		WorkerThreadPool.wait_for_task_completion((_tarefas[sc] as Dictionary).id)
	_tarefas.clear()


func _process(dt: float) -> void:
	processar()
	if alvo_de.is_null() or gerador == null:
		return
	# O alvo mudou de seção (andou, ou teletransportou): refaz as contas já, não daqui a 0,2 s.
	var alvo := alvo_de.call() as Node3D
	if alvo != null:
		var sc := secao_de(celula_em(alvo.global_position))
		if sc != _sc_alvo:
			_sc_alvo = sc
			_relogio_seguir = 0.0
	_relogio_seguir -= dt
	if _relogio_seguir <= 0.0:
		_relogio_seguir = 0.2
		seguir()


# =================================================================== DADOS
static func secao_de(c: Vector3i) -> Vector3i:
	return Vector3i(floori(float(c.x) / LADO), floori(float(c.y) / LADO), floori(float(c.z) / LADO))


static func _indice(l: Vector3i) -> int:
	return l.x + LADO * (l.y + LADO * l.z)


## Célula (grade do mundo) sob um ponto em metros.
static func celula_em(p: Vector3) -> Vector3i:
	return Vector3i(floori(p.x / BLOCO), floori(p.y / BLOCO), floori(p.z / BLOCO))


## Valor da célula (tipo | estado << 12); 0 = ar.
func obter(c: Vector3i) -> int:
	var sc := secao_de(c)
	if not _secoes.has(sc):
		return gerador.valor_em(c) if gerador != null else AR
	return (_secoes[sc] as PackedInt32Array)[_indice(c - sc * LADO)]


func definir(c: Vector3i, valor: int) -> void:
	var sc := secao_de(c)
	var l := c - sc * LADO
	var dados: PackedInt32Array
	if _secoes.has(sc):
		dados = _secoes[sc]
	else:
		# Primeira edição da seção: guarda a cópia do terreno de base (ou uma seção de ar).
		if gerador != null:
			dados = gerador.gerar(sc)
		if dados.is_empty():
			if valor == AR:
				return
			dados = PackedInt32Array()
			dados.resize(VOLUME)
		_secoes[sc] = dados
	var k := _indice(l)
	if dados[k] == valor:
		return
	dados[k] = valor
	_sujas[sc] = true
	# Bloco na borda: a face dele para a seção vizinha mudou também.
	for eixo in 3:
		if l[eixo] == 0:
			_sujar_vizinha(sc, eixo, -1)
		elif l[eixo] == LADO - 1:
			_sujar_vizinha(sc, eixo, 1)


func _sujar_vizinha(sc: Vector3i, eixo: int, sinal: int) -> void:
	var v := sc
	v[eixo] += sinal
	if _secoes.has(v) or _prontas.has(v):
		_sujas[v] = true


## Preenche a caixa [a, b] (inclusive).
func preencher(a: Vector3i, b: Vector3i, valor: int) -> void:
	for x in range(a.x, b.x + 1):
		for y in range(a.y, b.y + 1):
			for z in range(a.z, b.z + 1):
				definir(Vector3i(x, y, z), valor)


## Seções guardadas (editadas). Sem gerador = todas as que têm bloco.
func secoes_com_blocos() -> int:
	return _secoes.size()


## Pede a malha da seção (o terreno de base é gerado na thread). Sem efeito se o gerador não cobre a seção.
func carregar(sc: Vector3i) -> void:
	if _prontas.has(sc) or _tarefas.has(sc):
		return
	if gerador != null and not _secoes.has(sc) and not gerador.cobre(sc):
		return
	_sujas[sc] = true


## Carrega as seções que tocam a caixa de blocos [a, b].
func carregar_caixa(a: Vector3i, b: Vector3i) -> void:
	var s0 := secao_de(a)
	var s1 := secao_de(b)
	for x in range(s0.x, s1.x + 1):
		for y in range(s0.y, s1.y + 1):
			for z in range(s0.z, s1.z + 1):
				carregar(Vector3i(x, y, z))


## A seção editada voltou a ser igual ao terreno de base? Então deixa de ser dado guardado (16 KB) e volta a ser gerada sob demanda.
func compactar(sc: Vector3i) -> void:
	if gerador == null or not _secoes.has(sc):
		return
	var base := gerador.gerar(sc)
	if base.is_empty():
		base = PackedInt32Array()
		base.resize(VOLUME)
	if (_secoes[sc] as PackedInt32Array) == base:
		_secoes.erase(sc)


## Tira a malha da seção (o terreno de base volta a ser só dado; o que foi editado continua guardado).
func descarregar(sc: Vector3i) -> void:
	_sujas.erase(sc)
	_prontas.erase(sc)
	var no: StaticBody3D = _nos.get(sc)
	if no != null:
		no.queue_free()
		_nos.erase(sc)
	_malhas.erase(sc)


func secoes_com_malha() -> int:
	return _nos.size()


## Triângulos desenhados (opacos + translúcidos).
func triangulos() -> int:
	var t := 0
	for no: StaticBody3D in _nos.values():
		t += int(no.get_meta("triangulos", 0))
	return t


func vertices_de_colisao() -> int:
	var t := 0
	for no: StaticBody3D in _nos.values():
		t += int(no.get_meta("vertices_colisao", 0))
	return t


func no_da_secao(sc: Vector3i) -> StaticBody3D:
	return _nos.get(sc)


## Nada sujo e nenhuma malha em voo? (para os testes esperarem).
func pronto() -> bool:
	return _sujas.is_empty() and _tarefas.is_empty()


# =================================================================== SEGUIR O JOGADOR
static func tile_de(sc: Vector3i) -> Vector2i:
	return Vector2i(floori(float(sc.x) / TILE_SECOES), floori(float(sc.z) / TILE_SECOES))


## Carrega o que o alvo precisa (as seções num raio de `raio_secoes`, ou as faixas que as contêm), descarrega o que ficou para
## trás, liga o desenho só no anel do alvo e atualiza o furo da malha distante.
func seguir() -> void:
	if gerador == null:
		return
	var a := secao_de(gerador.caixa_min)
	var b := secao_de(gerador.caixa_max)
	var alvo := alvo_de.call() as Node3D if not alvo_de.is_null() else null
	var sc0 := secao_de(celula_em(alvo.global_position)) if alvo != null else Vector3i(1 << 30, 0, 1 << 30)
	var perto := alvo != null and not (sc0.x < a.x - raio_secoes - 1 or sc0.x > b.x + raio_secoes + 1
		or sc0.z < a.z - raio_secoes - 1 or sc0.z > b.z + raio_secoes + 1)
	if tiles_colisao.is_empty():
		_seguir_por_secoes(sc0, perto, a, b)
	else:
		_seguir_por_faixas(sc0, perto, a, b)
	# O desenho é só do anel do alvo; fora dele a seção existe para a COLISÃO (a malha distante é a do relevo antigo).
	for sc: Vector3i in _malhas.keys():
		var mi := _malhas[sc] as MeshInstance3D
		if is_instance_valid(mi):
			mi.visible = perto and maxi(absi(sc.x - sc0.x), absi(sc.z - sc0.z)) <= raio_secoes
	if perto:
		_atualizar_furo(sc0, a.y, b.y)
	elif material_longe != null and _furo_ativo:
		material_longe.set_shader_parameter("furo_caixa", Vector4.ZERO)
		_furo_ativo = false


## Sem faixas: só o anel do alvo, de perto para longe (a ordem de `_sujas` é a de chegada).
func _seguir_por_secoes(sc0: Vector3i, perto: bool, a: Vector3i, b: Vector3i) -> void:
	if perto:
		for r in raio_secoes + 1:
			for sx in range(maxi(sc0.x - r, a.x), mini(sc0.x + r, b.x) + 1):
				for sz in range(maxi(sc0.z - r, a.z), mini(sc0.z + r, b.z) + 1):
					if maxi(absi(sx - sc0.x), absi(sz - sc0.z)) != r:
						continue
					for sy in range(a.y, b.y + 1):
						carregar(Vector3i(sx, sy, sz))
	for sc: Vector3i in _prontas.keys():
		if not perto or maxi(absi(sc.x - sc0.x), absi(sc.z - sc0.z)) > raio_secoes + 1:
			descarregar(sc)
	for sc: Vector3i in _sujas.keys():
		if not _secoes.has(sc) and (not perto or maxi(absi(sc.x - sc0.x), absi(sc.z - sc0.z)) > raio_secoes + 1):
			_sujas.erase(sc)


## Com faixas: as que tocam o anel do alvo e as que têm seção EDITADA ficam ativas (seções de blocos); as outras usam a colisão antiga.
func _seguir_por_faixas(sc0: Vector3i, perto: bool, a: Vector3i, b: Vector3i) -> void:
	var precisa := {}
	if perto:
		var t0 := tile_de(Vector3i(sc0.x - raio_secoes, 0, sc0.z - raio_secoes))
		var t1 := tile_de(Vector3i(sc0.x + raio_secoes, 0, sc0.z + raio_secoes))
		var centro := tile_de(sc0)
		var lista: Array[Vector2i] = []
		for tx in range(t0.x, t1.x + 1):
			for tz in range(t0.y, t1.y + 1):
				lista.append(Vector2i(tx, tz))
		lista.sort_custom(func(p: Vector2i, q: Vector2i) -> bool: return (p - centro).length_squared() < (q - centro).length_squared())
		for t in lista:
			if tiles_colisao.has(t):
				precisa[t] = true
	for sc: Vector3i in _secoes.keys():
		var t := tile_de(sc)
		if tiles_colisao.has(t):
			precisa[t] = true
	for t: Vector2i in precisa:
		if not _tile_estado.has(t):
			_tile_estado[t] = 1
			for sc in _secoes_da_faixa(t, a, b):
				carregar(sc)
	for t: Vector2i in _tile_estado.keys():
		if not precisa.has(t):
			_desativar_faixa(t, a, b)
		elif int(_tile_estado[t]) == 1:
			var pronto := true
			for sc in _secoes_da_faixa(t, a, b):
				if not _prontas.has(sc) or _sujas.has(sc) or _tarefas.has(sc):
					pronto = false
					break
			if pronto:
				(tiles_colisao[t] as CollisionShape3D).disabled = true      # a colisão passa a ser a das seções
				_tile_estado[t] = 2


func _secoes_da_faixa(t: Vector2i, a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var saida: Array[Vector3i] = []
	for sx in range(t.x * TILE_SECOES, (t.x + 1) * TILE_SECOES):
		for sz in range(t.y * TILE_SECOES, (t.y + 1) * TILE_SECOES):
			for sy in range(a.y, b.y + 1):
				var sc := Vector3i(sx, sy, sz)
				if gerador.cobre(sc):
					saida.append(sc)
	return saida


func _desativar_faixa(t: Vector2i, a: Vector3i, b: Vector3i) -> void:
	(tiles_colisao[t] as CollisionShape3D).disabled = false
	_tile_estado.erase(t)
	for sc in _secoes_da_faixa(t, a, b):
		descarregar(sc)


## Malha da seção AGORA, na thread principal (teletransporte e carga do jogador: poucos ms por seção).
func carregar_agora(sc: Vector3i) -> void:
	if _tarefas.has(sc):
		var t: Dictionary = _tarefas[sc]
		WorkerThreadPool.wait_for_task_completion(t.id)
		_tarefas.erase(sc)
		_aplicar(sc, t.resultado)
		if not _sujas.has(sc):
			return
	_sujas.erase(sc)
	reconstrucoes += 1
	var posicoes: Array[Vector3i] = []
	var copias: Array = []
	_copias_de(sc, posicoes, copias)
	_aplicar(sc, GradeVoxel._calcular(posicoes, copias, gerador))


## O furo da malha distante é a caixa de seções JÁ prontas ao redor do alvo (o maior anel completo).
func _atualizar_furo(sc0: Vector3i, y0: int, y1: int) -> void:
	if material_longe == null:
		return
	var pronto := -1
	for r in raio_secoes + 1:
		var completo := true
		for sx in range(sc0.x - r, sc0.x + r + 1):
			for sz in range(sc0.z - r, sc0.z + r + 1):
				if maxi(absi(sx - sc0.x), absi(sz - sc0.z)) != r:
					continue
				for sy in range(y0, y1 + 1):
					var sc := Vector3i(sx, sy, sz)
					if gerador.cobre(sc) and (not _prontas.has(sc) or _sujas.has(sc) or _tarefas.has(sc)):
						completo = false
						break
				if not completo:
					break
			if not completo:
				break
		if not completo:
			break
		pronto = r
	var lado := LADO * BLOCO
	_furo_ativo = pronto >= 0
	if pronto < 0:
		material_longe.set_shader_parameter("furo_caixa", Vector4.ZERO)
	else:
		material_longe.set_shader_parameter("furo_caixa", Vector4((sc0.x - pronto) * lado, (sc0.z - pronto) * lado,
			(sc0.x + pronto + 1) * lado, (sc0.z + pronto + 1) * lado))


# =================================================================== REFEITURA
## Um passo: entram as malhas prontas (até `limite`, ou `trocas_por_quadro`) e saem novas tarefas das seções sujas.
## Devolve quantas malhas entraram.
func processar(limite := -1) -> int:
	var max_trocas := trocas_por_quadro if limite < 0 else limite
	var trocas := 0
	for sc: Vector3i in _tarefas.keys():
		if trocas >= max_trocas:
			break
		var t: Dictionary = _tarefas[sc]
		if not WorkerThreadPool.is_task_completed(t.id):
			continue
		WorkerThreadPool.wait_for_task_completion(t.id)
		_tarefas.erase(sc)
		_aplicar(sc, t.resultado)
		trocas += 1
	for sc: Vector3i in _sujas.keys():
		if _tarefas.size() >= MAX_TAREFAS:
			break
		if _tarefas.has(sc):
			continue                              # a malha dela está em voo: continua suja, sai depois
		_sujas.erase(sc)
		_despachar(sc)
	return trocas


## Espera tudo ficar pronto, entrando todas as malhas (testes e carga inicial).
func esperar_tudo() -> void:
	while not pronto():
		processar(1000000)
		if not pronto():
			OS.delay_msec(1)


func _copias_de(sc: Vector3i, posicoes: Array[Vector3i], copias: Array) -> void:
	# Cópias das seções editadas (as Packed* passam por referência: a thread não pode ler o que o jogo continua mudando);
	# as que não foram editadas são geradas a partir do terreno de base.
	posicoes.append(sc)
	copias.append((_secoes[sc] as PackedInt32Array).duplicate() if _secoes.has(sc) else null)
	for d in 6:
		var v := sc
		v[d / 2] += 1 if d % 2 == 1 else -1
		posicoes.append(v)
		copias.append((_secoes[v] as PackedInt32Array).duplicate() if _secoes.has(v) else null)


static func _calcular(posicoes: Array[Vector3i], copias: Array, base: GeradorDeRelevo) -> Dictionary:
	var arrays: Array[PackedInt32Array] = []
	for q in 7:
		var a: PackedInt32Array
		if copias[q] != null:
			a = copias[q]
		elif base != null:
			a = base.gerar(posicoes[q])
		arrays.append(a)
	var viz: Array[PackedInt32Array] = [arrays[1], arrays[2], arrays[3], arrays[4], arrays[5], arrays[6]]
	return malhar(arrays[0], viz)


func _despachar(sc: Vector3i) -> void:
	reconstrucoes += 1
	var posicoes: Array[Vector3i] = []
	var copias: Array = []
	_copias_de(sc, posicoes, copias)
	var resultado := {}
	var base := gerador
	var id := WorkerThreadPool.add_task(func() -> void:
		resultado.merge(GradeVoxel._calcular(posicoes, copias, base)))
	_tarefas[sc] = {"id": id, "resultado": resultado}


func _aplicar(sc: Vector3i, r: Dictionary) -> void:
	_prontas[sc] = true
	var v: PackedVector3Array = r.get("vertices", PackedVector3Array())
	var vt: PackedVector3Array = r.get("vertices_t", PackedVector3Array())
	var col: PackedVector3Array = r.get("colisao", PackedVector3Array())
	var no: StaticBody3D = _nos.get(sc)
	if v.is_empty() and vt.is_empty() and col.is_empty():
		if no != null:
			no.queue_free()
			_nos.erase(sc)
			_malhas.erase(sc)
		return
	var mi: MeshInstance3D
	var cs: CollisionShape3D
	if no == null:
		no = StaticBody3D.new()
		no.name = "Secao_%d_%d_%d" % [sc.x, sc.y, sc.z]
		no.collision_layer = CAMADA_MUNDO
		no.collision_mask = 0
		no.position = Vector3(sc) * (LADO * BLOCO)
		mi = MeshInstance3D.new()
		mi.name = "Malha"
		no.add_child(mi)
		cs = CollisionShape3D.new()
		cs.name = "Colisao"
		no.add_child(cs)
		add_child(no)
		_nos[sc] = no
		_malhas[sc] = mi
	else:
		mi = no.get_node("Malha")
		cs = no.get_node("Colisao")
	var m := ArrayMesh.new()
	if not v.is_empty():
		_superficie(m, v, r["normais"], r["cores"], r["uv"], r["uv2"], material)
	if not vt.is_empty():
		_superficie(m, vt, r["normais_t"], r["cores_t"], r["uv_t"], r["uv2_t"], material_translucido)
	mi.mesh = m
	mi.visible = alvo_de.is_null() or maxi(absi(sc.x - _sc_alvo.x), absi(sc.z - _sc_alvo.z)) <= raio_secoes
	if col.is_empty():
		cs.shape = null
	else:
		var forma := ConcavePolygonShape3D.new()
		forma.set_faces(col)
		cs.shape = forma
	no.set_meta("triangulos", (v.size() + vt.size()) / 3)
	no.set_meta("vertices_colisao", col.size())


static func _superficie(m: ArrayMesh, v: PackedVector3Array, n: PackedVector3Array, c: PackedColorArray,
		uv: PackedVector2Array, uv2: PackedVector2Array, mat: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	# Sem compressão: vértice quantizado abriria fresta entre faces vizinhas.
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, 0)
	m.surface_set_material(m.get_surface_count() - 1, mat)


# =================================================================== MALHA (roda em thread: só dados)
class Saida:
	extends RefCounted
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var vt := PackedVector3Array()
	var nt := PackedVector3Array()
	var ct := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var uvt := PackedVector2Array()
	var uv2t := PackedVector2Array()
	var col := PackedVector3Array()

	## Retângulo (q0..q3 em volta) virado para `normal`, na ordem que a Godot desenha de frente. `capa` = camada da textura
	## (−1: só cor); o UV sai em unidades de bloco (ver `_uv_do_ponto`).
	func quad(q0: Vector3, q1: Vector3, q2: Vector3, q3: Vector3, normal: Vector3, cor: Color, transl: bool, colide: bool, capa := -1) -> void:
		if (q2 - q0).cross(q1 - q0).dot(normal) < 0.0:
			var tmp := q1
			q1 = q3
			q3 = tmp
		var seis := PackedVector3Array([q0, q1, q2, q0, q2, q3])
		var duv := PackedVector2Array()
		for p in seis:
			duv.append(GradeVoxel._uv_do_ponto(p, normal))
		var camada := Vector2(float(capa), 0.0)
		if transl:
			vt.append_array(seis)
			uvt.append_array(duv)
			for _k in 6:
				nt.append(normal)
				ct.append(cor)
				uv2t.append(camada)
		else:
			v.append_array(seis)
			uv.append_array(duv)
			for _k in 6:
				n.append(normal)
				c.append(cor)
				uv2.append(camada)
		if colide:
			col.append_array(seis)


## UV de um ponto da seção (metros locais) em unidades de bloco, sem espelhar a textura: o topo/base usa (x, z); as laterais
## usam o eixo horizontal que cresce para a direita de quem olha a face, e v = −y (a imagem cresce para baixo).
## A origem da seção é múltipla de 16 blocos: o ladrilho fica alinhado entre seções.
static func _uv_do_ponto(p: Vector3, normal: Vector3) -> Vector2:
	var k := 1.0 / BLOCO
	if absf(normal.y) > 0.5:
		return Vector2(p.x * k, p.z * k)
	if absf(normal.x) > 0.5:
		return Vector2((-p.z if normal.x > 0.0 else p.z) * k, -p.y * k)
	return Vector2((p.x if normal.z > 0.0 else -p.x) * k, -p.y * k)


## Malha de UMA seção, em coordenadas LOCAIS (metros). `centro` = valores da seção (vazio = nada); `vizinhas` = as
## seções −x, +x, −y, +y, −z, +z (vazio = ar). Devolve superfícies opaca (`vertices`/`normais`/`cores`), translúcida
## (`*_t`) e a lista de triângulos de colisão (`colisao`: só o que colide — água e afins ficam de fora).
static func malhar(centro: PackedInt32Array, vizinhas: Array[PackedInt32Array]) -> Dictionary:
	var s := Saida.new()
	if centro.is_empty():
		return _resultado(s)
	# Cópia com 1 bloco de borda (as seções vizinhas), para olhar o vizinho sem ramificar.
	var p := PackedInt32Array()
	p.resize(PAD * PAD * PAD)
	for z in LADO:
		for y in LADO:
			var o := (z + 1) * PAD * PAD + (y + 1) * PAD + 1
			var q := LADO * (y + LADO * z)
			for x in LADO:
				p[o + x] = centro[q + x]
	for a in LADO:
		for b in LADO:
			# −x/+x: (y=a, z=b); −y/+y: (x=a, z=b); −z/+z: (x=a, y=b)
			if not vizinhas[0].is_empty():
				p[(b + 1) * PAD * PAD + (a + 1) * PAD] = vizinhas[0][(LADO - 1) + LADO * (a + LADO * b)]
			if not vizinhas[1].is_empty():
				p[(b + 1) * PAD * PAD + (a + 1) * PAD + PAD - 1] = vizinhas[1][0 + LADO * (a + LADO * b)]
			if not vizinhas[2].is_empty():
				p[(b + 1) * PAD * PAD + (a + 1)] = vizinhas[2][a + LADO * ((LADO - 1) + LADO * b)]
			if not vizinhas[3].is_empty():
				p[(b + 1) * PAD * PAD + (PAD - 1) * PAD + (a + 1)] = vizinhas[3][a + LADO * (0 + LADO * b)]
			if not vizinhas[4].is_empty():
				p[(a + 1) + (b + 1) * PAD] = vizinhas[4][a + LADO * (b + LADO * (LADO - 1))]
			if not vizinhas[5].is_empty():
				p[(PAD - 1) * PAD * PAD + (b + 1) * PAD + (a + 1)] = vizinhas[5][a + LADO * (b + LADO * 0)]
	_octantes(s, p)
	_caixas_da_secao(s, p)
	return _resultado(s)


static func _resultado(s: Saida) -> Dictionary:
	return {"vertices": s.v, "normais": s.n, "cores": s.c, "vertices_t": s.vt, "normais_t": s.nt, "cores_t": s.ct,
		"uv": s.uv, "uv2": s.uv2, "uv_t": s.uvt, "uv2_t": s.uv2t, "colisao": s.col}


## Cubos, lajes, escadas e blocos de octantes: tudo é uma grade de OCTANTES (32³ por seção, meio bloco de lado).
## Cada coluna (x, z) é um inteiro com um bit por nível (y): as faces de uma direção saem de UMA operação de bits por coluna
## (ocupado e não coberto pelo vizinho), e as faces vizinhas viram retângulos (guloso) — o mesmo que o `RelevoEmBlocos`
## faz com os topos, só que em qualquer direção e para qualquer forma. Bit (y + 1): os bits 0 e 33 e as colunas −1 e 32 são
## a borda (as seções vizinhas) e só servem para saber quem cobre a face.
static func _octantes(s: Saida, p: PackedInt32Array) -> void:
	var largura := OCT + 2
	var opaco := PackedInt64Array()
	opaco.resize(largura * largura)
	var por_material := {}                            # material → colunas ocupadas por ele
	var tipos_forma := TiposDeBloco.forma
	var material_do := TiposDeBloco.material_do
	var cheio34 := (1 << (OCT + 2)) - 1
	for zp in PAD:
		for yp in PAD:
			var base := yp * PAD + zp * PAD * PAD
			for xp in PAD:
				var v := p[base + xp]
				if v == 0:
					continue
				var t := v & TiposDeBloco.MASCARA_TIPO
				var f := tipos_forma[t]
				if TiposDeBloco.e_de_caixas(f):
					continue
				var mat := material_do[t]
				var cols: PackedInt64Array
				if por_material.has(mat):
					cols = por_material[mat]
				else:
					cols = PackedInt64Array()
					cols.resize(largura * largura)
					por_material[mat] = cols
				var transl := TiposDeBloco.translucido[mat] == 1
				var mascara := TiposDeBloco.octantes(v)
				# bit de nível do octante (oy) desta célula: 2·yp − 1 + oy
				for oz in 2:
					var zi := 2 * zp - 1 + oz
					if zi < 0 or zi >= largura:
						continue
					for ox in 2:
						var xi := 2 * xp - 1 + ox
						if xi < 0 or xi >= largura:
							continue
						var bits := 0
						if yp > 0 and (mascara >> (ox + 4 * oz)) & 1 == 1:
							bits |= 1 << (2 * yp - 1)           # oy = 0 (a borda de baixo do primeiro nível não existe)
						if (mascara >> (ox + 2 + 4 * oz)) & 1 == 1:
							bits |= 1 << (2 * yp)               # oy = 1
						bits &= cheio34
						if bits == 0:
							continue
						var c := xi + largura * zi
						cols[c] |= bits
						if not transl:
							opaco[c] |= bits
	for mat: int in por_material:
		var cols: PackedInt64Array = por_material[mat]
		var transl := TiposDeBloco.translucido[mat] == 1
		var cobre := opaco
		if transl:
			cobre = PackedInt64Array()
			cobre.resize(largura * largura)
			for c in largura * largura:
				cobre[c] = opaco[c] | cols[c]
		_faces_do_material(s, cols, cobre, mat)


## As seis direções de um material: faces = ocupado & ~coberto-pelo-vizinho, por coluna; depois retângulos por fatia.
static func _faces_do_material(s: Saida, cols: PackedInt64Array, cobre: PackedInt64Array, mat: int) -> void:
	var largura := OCT + 2
	var miolo := ((1 << OCT) - 1) << 1                # bits 1..32 = os 32 níveis da seção
	var cor := TiposDeBloco.cor[mat]
	var transl := TiposDeBloco.translucido[mat] == 1
	var colide := TiposDeBloco.colide[mat] == 1
	var meio := BLOCO * 0.5
	var linhas := PackedInt64Array()
	linhas.resize(OCT)
	var rets := PackedInt32Array()
	for d in 6:
		var eixo := d / 2
		var sinal := 1 if d % 2 == 1 else -1
		var normal := Vector3.ZERO
		normal[eixo] = sinal
		var capa := TexturasDeBloco.camada(mat, d)
		# faces[x, z] (bits sobre y) desta direção
		var faces := PackedInt64Array()
		faces.resize(largura * largura)
		var capas := 0
		for z in OCT:
			for x in OCT:
				var c := (x + 1) + largura * (z + 1)
				var oc := cols[c]
				if oc == 0:
					continue
				var viz: int
				match d:
					0: viz = cobre[c - 1]
					1: viz = cobre[c + 1]
					2: viz = cobre[c] << 1
					3: viz = cobre[c] >> 1
					4: viz = cobre[c - largura]
					_: viz = cobre[c + largura]
				var f := oc & ~viz & miolo
				if f != 0:
					faces[c] = f
					capas |= f
		if capas == 0:
			continue
		# eixos do retângulo (u, v) e o que é a fatia
		var eu: int
		var ev: int
		match eixo:
			0: eu = 1; ev = 2
			1: eu = 0; ev = 2
			_: eu = 1; ev = 0
		for fatia in OCT:
			if (capas >> (fatia + 1)) & 1 == 0 and eixo == 1:
				continue
			linhas.fill(0)
			var tem := false
			if eixo == 1:
				var bit := fatia + 1
				for z in OCT:
					var linha := 0
					for x in OCT:
						if (faces[(x + 1) + largura * (z + 1)] >> bit) & 1 == 1:
							linha |= 1 << x
					if linha != 0:
						linhas[z] = linha
						tem = true
			elif eixo == 0:
				for z in OCT:
					var linha := (faces[(fatia + 1) + largura * (z + 1)] >> 1) & 0xFFFFFFFF
					if linha != 0:
						linhas[z] = linha
						tem = true
			else:
				for x in OCT:
					var linha := (faces[(x + 1) + largura * (fatia + 1)] >> 1) & 0xFFFFFFFF
					if linha != 0:
						linhas[x] = linha
						tem = true
			if not tem:
				continue
			rets.clear()
			_retangulos(linhas, rets)
			var plano := float(fatia + (1 if sinal > 0 else 0)) * meio
			for k in rets.size() / 4:
				var u0 := float(rets[4 * k]) * meio - SOBRA
				# ⚠️ A parede NÃO passa do topo (3 mm de lâmina acima do chão prendiam a cápsula ao subir: ver `RelevoEmBlocos._parede`);
				# o eixo y é `eu` em todas as faces laterais.
				var u1 := float(rets[4 * k] + rets[4 * k + 2]) * meio + (0.0 if eu == 1 else SOBRA)
				var v0 := float(rets[4 * k + 1]) * meio - SOBRA
				var v1 := float(rets[4 * k + 1] + rets[4 * k + 3]) * meio + SOBRA
				var q0 := Vector3.ZERO
				var q1 := Vector3.ZERO
				var q2 := Vector3.ZERO
				var q3 := Vector3.ZERO
				q0[eixo] = plano; q0[eu] = u0; q0[ev] = v0
				q1[eixo] = plano; q1[eu] = u1; q1[ev] = v0
				q2[eixo] = plano; q2[eu] = u1; q2[ev] = v1
				q3[eixo] = plano; q3[eu] = u0; q3[ev] = v1
				s.quad(q0, q1, q2, q3, normal, cor, transl, colide, capa)


## Retângulos gulosos de uma grade de 32 linhas de 32 bits: [u, v, largura, altura] em `saida`. Consome `linhas`.
static func _retangulos(linhas: PackedInt64Array, saida: PackedInt32Array) -> void:
	for v in OCT:
		var u := 0
		while linhas[v] != 0 and u < OCT:
			var r := linhas[v]
			if (r >> u) & 1 == 0:
				u += 1
				continue
			var w := 1
			while u + w < OCT and (r >> (u + w)) & 1 == 1:
				w += 1
			var mascara := ((1 << w) - 1) << u
			var h := 1
			while v + h < OCT and (linhas[v + h] & mascara) == mascara:
				h += 1
			for k in h:
				linhas[v + k] &= ~mascara
			saida.append(u)
			saida.append(v)
			saida.append(w)
			saida.append(h)
			u += w


## Portas e painéis: caixas finas, poucas por seção, sem fusão.
static func _caixas_da_secao(s: Saida, p: PackedInt32Array) -> void:
	for z in LADO:
		for y in LADO:
			for x in LADO:
				var idx := (x + 1) + PAD * (y + 1) + PAD * PAD * (z + 1)
				var v := p[idx]
				if v == 0:
					continue
				var t := v & TiposDeBloco.MASCARA_TIPO
				var f := TiposDeBloco.forma[t]
				if TiposDeBloco.e_de_caixas(f):
					_caixas(s, p, idx, t, v, Vector3(x, y, z) * BLOCO)


static func _passo(eixo: int) -> int:
	return 1 if eixo == 0 else (PAD if eixo == 1 else PAD * PAD)


static func _caixas(s: Saida, p: PackedInt32Array, idx: int, t: int, v: int, origem: Vector3) -> void:
	var cor := TiposDeBloco.cor[t]
	var transl := TiposDeBloco.translucido[t] == 1
	var colide := TiposDeBloco.colide[t] == 1
	var k := BLOCO / 16.0
	for cx: Array in TiposDeBloco.caixas(v):
		for d in 6:
			var eixo := d / 2
			var sinal := 1 if d % 2 == 1 else -1
			var plano16: int = cx[eixo + (3 if sinal > 0 else 0)]
			if (sinal < 0 and plano16 == 0) or (sinal > 0 and plano16 == 16):
				var nv := p[idx + sinal * _passo(eixo)]
				if nv != 0:
					var nt := nv & TiposDeBloco.MASCARA_TIPO
					var cara: int = TiposDeBloco.OCT_DA_FACE[d ^ 1]
					if (TiposDeBloco.octantes(nv) & cara) == cara and (TiposDeBloco.translucido[nt] == 0 or nt == t):
						continue
			var eu := (eixo + 1) % 3
			var ev := (eixo + 2) % 3
			var u0: float = origem[eu] + float(cx[eu]) * k - SOBRA
			var u1: float = origem[eu] + float(cx[eu + 3]) * k + (0.0 if eu == 1 else SOBRA)
			var v0: float = origem[ev] + float(cx[ev]) * k - SOBRA
			var v1: float = origem[ev] + float(cx[ev + 3]) * k + (0.0 if ev == 1 else SOBRA)
			var plano := origem[eixo] + float(plano16) * k
			var normal := Vector3.ZERO
			normal[eixo] = sinal
			var q0 := Vector3.ZERO
			var q1 := Vector3.ZERO
			var q2 := Vector3.ZERO
			var q3 := Vector3.ZERO
			q0[eixo] = plano; q0[eu] = u0; q0[ev] = v0
			q1[eixo] = plano; q1[eu] = u1; q1[ev] = v0
			q2[eixo] = plano; q2[eu] = u1; q2[ev] = v1
			q3[eixo] = plano; q3[eu] = u0; q3[ev] = v1
			s.quad(q0, q1, q2, q3, normal, cor, transl, colide, TexturasDeBloco.camada(t, d, v >> TiposDeBloco.BITS_TIPO))
