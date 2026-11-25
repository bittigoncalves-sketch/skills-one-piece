class_name StreamingDeIlhas
extends Node
# ============================================================================
#  CARGA POR DISTÂNCIA DAS ILHAS (28/10/2026). Pedido do dono: "carregar ao mínimo conforme a distância e carregar pouco a
#  distância, deixando o jogo carregando apenas onde o jogador está vendo e jogando".
#
#  Antes, a entrada montava as 11 ilhas (2.799 peças, 320 modelos, 1,7 GB) e o `LodDasIlhas` só ESCONDIA o que estava longe.
#  Agora a unidade é a ILHA:
#    • sempre carregado (barato): o relevo em blocos de todas as ilhas (de longe elas aparecem como terra), o fundo do mar, o oceano;
#    • carregado só PERTO: as peças da ilha (modelos 3D, terreno, áreas de animais) e tudo que nasce delas (NPCs, inimigos,
#      bandidos, personagens do mod, animais, bestas, pomar, coleta, navios ancorados);
#    • a entrada monta a ilha onde o jogador nasce; as outras entram quando ele chega a `RAIO_DE_CARGA` da PLACA (a pé ou de barco),
#      aos poucos (alguns objetos por quadro, sem engasgar), e saem da memória ao passar de `RAIO_DE_DESCARGA`.
#
#  Cada ilha tem a PRÓPRIA lista de peças (`particionar`); os sistemas continuam os mesmos: cada um é chamado com o sub-mapa da ilha
#  (`ModoHistoria._ligar_ilha`). O que um sistema cria fora da raiz do mapa (animais, frutas do pomar) sai por `_desligar_ilha`.
#  O que NÃO se perde de verdade: progresso, missões, ouro, frutas comidas (estão no save). O que se perde: o estado passageiro
#  (inimigo ferido, fruta caída no chão, animal que andou) — a ilha volta como no começo, como já acontece ao reiniciar.
# ============================================================================

signal ilha_carregada(id: String)
signal ilha_descarregada(id: String)

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const RelevoDasIlhas := preload("res://src/historia/ilhas/relevo_das_ilhas.gd")
## Distância (m, até a PLACA) em que a ilha passa a ser montada / deixa de existir. A histerese de 250 m evita montar e
## desmontar a mesma ilha quando o jogador anda na borda.
const RAIO_DE_CARGA := 700.0
const RAIO_DE_DESCARGA := 950.0
const INTERVALO := 0.5
## Peças por quadro ao montar uma ilha durante o jogo (a entrada usa o lote da tela de carregamento).
const PECAS_POR_QUADRO := 10
## Peças até esta distância da placa são da ilha (a mesma conta do `LodDasIlhas`).
const MARGEM_DA_ILHA := 120.0

var raiz: Node3D
var mapa: Dictionary
var biblioteca: BibliotecaDeModelos
var caixas: Dictionary = {}
var jogador_de: Callable
## `ao_ligar(id, sub_mapa)`: corrotina do ModoHistoria que liga os sistemas à ilha recém-montada (devolve nada).
var ao_ligar: Callable
## `ao_desligar(id, ids_das_pecas, nos)`: o ModoHistoria tira a ilha das listas dos sistemas ANTES de os nós serem liberados
## (uma lista que ainda aponta para nó enfileirado dá erro na próxima volta de `_process`).
var ao_desligar: Callable
## Falso = nunca descarrega (testes e `carregar_tudo`).
var descarrega := true
## Quem pode vetar a descarga de uma ilha (ex.: o barco do jogador está atracado nela). `(id) -> bool`.
var pode_descarregar := Callable()

var particao: Dictionary = {}              # id da ilha ("" = fora de qualquer ilha) → peças
var carregadas: Dictionary = {}            # id → {"nos": Array[Node], "ids": Array}
var _carregando: Dictionary = {}
var _materiais: Dictionary = {}
var _relogio := 0.0


# ------------------------------------------------------------------ partição
## Reparte as peças por ilha (a mesma regra do LOD: a placa mais perto, até `MARGEM_DA_ILHA`). Cada peça entra em UMA lista; o que
## não está perto de ilha nenhuma fica em "".
static func particionar(pecas: Array, caixas_: Dictionary) -> Dictionary:
	var saida := {"": []}
	for id in caixas_:
		saida[id] = []
	for p: Dictionary in pecas:
		var id := Ilhas.ilha_em(caixas_, p["posicao"], MARGEM_DA_ILHA)
		(saida[id] as Array).append(p)
	return saida


func configurar(raiz_: Node3D, mapa_: Dictionary, bib: BibliotecaDeModelos, caixas_: Dictionary) -> void:
	raiz = raiz_
	mapa = mapa_
	biblioteca = bib
	caixas = caixas_
	particao = particionar(mapa_.get("pecas", []), caixas_)


func sub_mapa(id: String) -> Dictionary:
	var m := mapa.duplicate()
	m["pecas"] = particao.get(id, [])
	return m


func esta_carregada(id: String) -> bool:
	return carregadas.has(id)


func ids_carregadas() -> Array:
	return carregadas.keys()


# ------------------------------------------------------------------ carga
## A entrada: o que não é de ilha, a ilha do spawn e as que já estão no raio de carga dele. Com `tudo`, todas.
func carregar_inicial(spawn: Vector3, tudo := false) -> void:
	await carregar("", true)
	for id in caixas:
		if tudo or Ilhas.distancia(caixas[id], spawn) <= RAIO_DE_CARGA:
			await carregar(id, true)


## Garante a ilha montada (corrotina). Várias chamadas esperam a mesma montagem.
func garantir(id: String) -> void:
	if carregadas.has(id):
		return
	await carregar(id)


## Monta a ilha. `na_entrada`: usa o ritmo da tela de carregamento; senão espalha por quadros (jogo rolando).
func carregar(id: String, na_entrada := false) -> void:
	if carregadas.has(id):
		return
	if _carregando.has(id):
		while _carregando.has(id):
			await get_tree().process_frame
		return
	_carregando[id] = true
	var nome := Ilhas.nome(id) if not id.is_empty() else "Arredores"
	var t0 := Time.get_ticks_msec()
	var antes := _nomes_dos_filhos()
	var pecas: Array = particao.get(id, [])
	var ids: Array = pecas.map(func(p: Dictionary) -> String: return String(p["id"]))
	if na_entrada:
		await MonitorDeCarga.etapa("Montando %s" % nome, "%d peças" % pecas.size())
	var ao_lote := func(feitas: int, total: int) -> void:
		if na_entrada:
			MonitorDeCarga.andamento(feitas, total, "%s: %d de %d peças montadas" % [nome, feitas, total])
			await MonitorDeCarga.passo()
		else:
			await get_tree().process_frame
	await MapaMontador.montar_pecas_em(raiz, pecas, ao_lote, 12 if na_entrada else PECAS_POR_QUADRO, _materiais)
	# O terreno liso já virou relevo em blocos (sempre carregado): a malha e a forma das peças nascem soltas.
	RelevoDasIlhas.soltar_pecas(raiz, pecas)
	for p: Dictionary in pecas:
		var no := raiz.get_node_or_null(NodePath(String(p["id"])))
		if no != null:
			MapaMontador.marcar_cenario(no)         # o gelo do V da Hie pinta só o cenário, antes de a peça virar NPC/inimigo
	if na_entrada:
		await MonitorDeCarga.etapa("Ligando %s" % nome, "NPCs, inimigos, animais, pomar, navios...")
	else:
		await get_tree().process_frame
	if ao_ligar.is_valid():
		await ao_ligar.call(id, sub_mapa(id))
	var nos: Array[Node] = []
	for filho in raiz.get_children():
		if not antes.has(String(filho.name)):
			nos.append(filho)
	carregadas[id] = {"nos": nos, "ids": ids}
	_carregando.erase(id)
	print("[Ilhas] %s montada: %d peças, %d nós, %d ms" % [nome, pecas.size(), nos.size(), Time.get_ticks_msec() - t0])
	ilha_carregada.emit(id)


func _nomes_dos_filhos() -> Dictionary:
	var d := {}
	for filho in raiz.get_children():
		d[String(filho.name)] = true
	return d


# ------------------------------------------------------------------ descarga
## Tira a ilha da memória: primeiro dos sistemas, depois os nós. A ilha "" (arredores) nunca sai.
func descarregar(id: String) -> void:
	if id.is_empty() or not carregadas.has(id):
		return
	var dados: Dictionary = carregadas[id]
	carregadas.erase(id)
	if ao_desligar.is_valid():
		ao_desligar.call(id, dados["ids"], dados["nos"])
	for no in dados["nos"]:
		if is_instance_valid(no):
			no.queue_free()
	print("[Ilhas] %s descarregada (%d nós)" % [Ilhas.nome(id), (dados["nos"] as Array).size()])
	ilha_descarregada.emit(id)


# ------------------------------------------------------------------ política por distância
func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0 or not jogador_de.is_valid():
		return
	_relogio = INTERVALO
	atualizar()


func atualizar() -> void:
	var j: Node3D = jogador_de.call()
	if j == null or not is_instance_valid(j):
		return
	for id in caixas:
		var d := Ilhas.distancia(caixas[id], j.global_position)
		if not carregadas.has(id) and not _carregando.has(id) and d <= RAIO_DE_CARGA:
			carregar(id)                          # corrotina solta: monta aos poucos, uma por vez abaixo
			return
		if descarrega and carregadas.has(id) and d > RAIO_DE_DESCARGA and _carregando.is_empty():
			if pode_descarregar.is_valid() and not bool(pode_descarregar.call(id)):
				continue
			descarregar(id)
			return
