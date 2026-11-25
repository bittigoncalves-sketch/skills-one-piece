class_name DocumentoMapa
extends RefCounted
# ============================================================================
#  DOCUMENTO DO MAPA — o mapa aberto no editor, em memória. Não cria nó.
#
#  Quem MOSTRA é a `VistaDoMapa`, quem DESFAZ é o `HistoricoDeEdicao`, quem
#  GRAVA é o `MapaArquivo`. Este objeto só guarda o estado e avisa por sinal o que
#  mudou — é assim que Explorer, Propriedades e a cena 3D ficam em dia sem um
#  chamar o outro.
#
#  ⚠️ VALOR IMUTÁVEL. Cada peça guardada é um dicionário que NUNCA é alterado no
#  lugar: `definir_peca` guarda uma cópia nova e `peca()` devolve uma cópia. O
#  histórico depende disso — ele guarda as referências antigas como "antes" sem
#  copiar o mapa inteiro a cada arraste. Mexer num dicionário interno por
#  referência corromperia o desfazer em silêncio.
# ============================================================================

signal peca_adicionada(id: String)
signal peca_mudou(id: String)
signal peca_removida(id: String)
signal ordem_mudou
signal spawn_mudou
signal sujo_mudou(sujo: bool)
## A árvore de grupos mudou: grupo criado/apagado/re-parentado, ou peça que trocou
## de grupo. O Explorer reconstrói; ninguém mais precisa.
signal hierarquia_mudou

const TAMANHO_PADRAO := Vector3(2, 2, 2)
const COR_PADRAO := Color("#a3a2a5")

var nome := "Sem nome"
var spawn := Vector3.ZERO
var sujo := false

var _pecas := {}                  # id -> Dictionary normalizado (imutável)
var _ordem: Array[String] = []    # ordem do arquivo e do Explorer
# GRUPOS (Ctrl+G): id -> {id, pai}. Mesma regra de valor imutável das peças. Grupo
# não tem transformação: mover um grupo é mover as peças dele.
var _grupos := {}
var _ordem_grupos: Array[String] = []
var _regex_id := RegEx.create_from_string(MapaArquivo.PADRAO_ID)


## A partir do mapa NORMALIZADO que o `MapaArquivo` devolve.
static func de_mapa(mapa: Dictionary) -> DocumentoMapa:
	var doc := DocumentoMapa.new()
	doc.nome = mapa["nome"]
	doc.spawn = mapa["spawn"]["posicao"]
	for p: Dictionary in mapa["pecas"]:
		doc._pecas[p["id"]] = p.duplicate(true)
		doc._ordem.append(p["id"])
	for g: Dictionary in mapa.get("grupos", []):
		doc._grupos[g["id"]] = g.duplicate()
		doc._ordem_grupos.append(g["id"])
	return doc


func para_mapa() -> Dictionary:
	var pecas: Array[Dictionary] = []
	for id in _ordem:
		pecas.append((_pecas[id] as Dictionary).duplicate(true))
	var grupos: Array[Dictionary] = []
	for gid in _ordem_grupos:
		grupos.append((_grupos[gid] as Dictionary).duplicate())
	return {"nome": nome, "spawn": {"posicao": spawn}, "pecas": pecas, "grupos": grupos}


func tem(id: String) -> bool:
	return _pecas.has(id)


func peca(id: String) -> Dictionary:
	return (_pecas[id] as Dictionary).duplicate(true)


## A peça SEM cópia, para varrer o mapa todo a cada quadro (pincel de relevo). ⚠️ Só
## LEITURA: alterar o dicionário devolvido pularia o histórico e os sinais — para
## mudar, `peca()` + `definir_peca()`.
func ler(id: String) -> Dictionary:
	return _pecas[id]


func ids() -> Array[String]:
	return _ordem.duplicate()


func quantidade() -> int:
	return _ordem.size()


## Cria ou substitui. `dados["id"]` precisa ser igual a `id`.
func definir_peca(id: String, dados: Dictionary) -> void:
	assert(dados["id"] == id, "id do dado difere da chave")
	var nova := not _pecas.has(id)
	var mudou_de_grupo := nova or str(_pecas[id].get("grupo", "")) != str(dados.get("grupo", ""))
	_pecas[id] = dados.duplicate(true)
	if nova:
		_ordem.append(id)
		peca_adicionada.emit(id)
		ordem_mudou.emit()
	else:
		peca_mudou.emit(id)
	if mudou_de_grupo and not str(dados.get("grupo", "")).is_empty() or (mudou_de_grupo and not nova):
		hierarquia_mudou.emit()
	_sujar()


func remover_peca(id: String) -> void:
	if not _pecas.has(id):
		return
	var tinha_grupo := not str(_pecas[id].get("grupo", "")).is_empty()
	_pecas.erase(id)
	_ordem.erase(id)
	peca_removida.emit(id)
	ordem_mudou.emit()
	if tinha_grupo:
		hierarquia_mudou.emit()
	_sujar()


# -------------------------------------------------------------------- grupos
func tem_grupo(id: String) -> bool:
	return _grupos.has(id)


## Peça OU grupo.
func tem_item(id: String) -> bool:
	return _pecas.has(id) or _grupos.has(id)


func grupo(id: String) -> Dictionary:
	return (_grupos[id] as Dictionary).duplicate()


func grupos_ids() -> Array[String]:
	return _ordem_grupos.duplicate()


func definir_grupo(id: String, dados: Dictionary) -> void:
	assert(dados["id"] == id, "id do grupo difere da chave")
	if not _grupos.has(id):
		_ordem_grupos.append(id)
	_grupos[id] = dados.duplicate()
	hierarquia_mudou.emit()
	_sujar()


func remover_grupo(id: String) -> void:
	if not _grupos.has(id):
		return
	_grupos.erase(id)
	_ordem_grupos.erase(id)
	hierarquia_mudou.emit()
	_sujar()


## Grupo pai de uma peça ou de um grupo ("" = no topo).
func pai_de(id: String) -> String:
	if _pecas.has(id):
		return str(_pecas[id].get("grupo", ""))
	if _grupos.has(id):
		return str(_grupos[id]["pai"])
	return ""


## O item mais alto da hierarquia que contém `id` (ele mesmo se está no topo). É o
## que o clique no 3D seleciona, como um Model do Roblox.
func raiz_de(id: String) -> String:
	var atual := id
	for _passo in _grupos.size() + 1:
		var pai := pai_de(atual)
		if pai.is_empty() or not _grupos.has(pai):
			return atual
		atual = pai
	return atual


## Filhos diretos de um grupo ("" = o topo): peças na ordem do mapa, depois grupos.
func filhos_de(grupo_id: String) -> Array[String]:
	var filhos: Array[String] = []
	for gid in _ordem_grupos:
		if _grupos[gid]["pai"] == grupo_id:
			filhos.append(gid)
	for pid in _ordem:
		if str(_pecas[pid].get("grupo", "")) == grupo_id:
			filhos.append(pid)
	return filhos


## Todas as peças abaixo de um item (a própria, se for peça).
func pecas_de(id: String) -> Array[String]:
	var saida: Array[String] = []
	if _pecas.has(id):
		saida.append(id)
	elif _grupos.has(id):
		for filho in filhos_de(id):
			saida.append_array(pecas_de(filho))
	return saida


## `ancestral` contém `id` em algum nível?
func dentro_de(id: String, ancestral: String) -> bool:
	var atual := pai_de(id)
	for _passo in _grupos.size() + 1:
		if atual.is_empty():
			return false
		if atual == ancestral:
			return true
		atual = pai_de(atual)
	return false


func definir_spawn(posicao: Vector3) -> void:
	if spawn == posicao:
		return
	spawn = posicao
	spawn_mudou.emit()
	_sujar()


## Só reordena: a lista precisa ter exatamente os mesmos ids.
func definir_ordem(nova: Array[String]) -> void:
	if nova == _ordem:
		return
	assert(nova.size() == _ordem.size(), "ordem com quantidade diferente")
	_ordem = nova.duplicate()
	ordem_mudou.emit()


func id_valido(id: String) -> bool:
	return _regex_id.search(id) != null


## "caixa_1", "caixa_2"... pula os que existem. Em cópia, reaproveita a base do
## original sem empilhar sufixos ("caixa_3" → "caixa_4", não "caixa_3_1").
func novo_id(base: String) -> String:
	var limpa := base
	var sufixo := RegEx.create_from_string("_\\d+$").search(base)
	if sufixo != null:
		limpa = base.substr(0, sufixo.get_start())
	if limpa.is_empty():
		limpa = "peca"
	limpa = limpa.left(56)
	var n := 1
	while _pecas.has("%s_%d" % [limpa, n]) or _grupos.has("%s_%d" % [limpa, n]):
		n += 1
	return "%s_%d" % [limpa, n]


func marcar_salvo() -> void:
	sujo = false
	sujo_mudou.emit(false)


func _sujar() -> void:
	if not sujo:
		sujo = true
		sujo_mudou.emit(true)


## Peça nova com os padrões do editor — tamanho de 2 m e cinza-pedra.
static func peca_padrao(tipo: String, id: String, posicao: Vector3) -> Dictionary:
	var p := {
		"id": id, "tipo": tipo, "posicao": posicao, "rotacao_graus": Vector3.ZERO,
		"tamanho": TAMANHO_PADRAO, "cor": COR_PADRAO, "material": "liso",
		"grade_celula": MapaArquivo.GRADE_PADRAO, "colisao": true, "grupo": "",
	}
	if tipo == "area_animais":
		# Região de nascimento: larga e baixa, sem colisão; espécie de partida
		# trocada no painel de propriedades.
		p["tamanho"] = Vector3(24, 6, 24)
		p["colisao"] = false
		p["especie"] = ESPECIE_PADRAO
		p["quantidade"] = 3
	return p


## Espécie de uma área de animais recém-inserida (o painel troca).
const ESPECIE_PADRAO := "rabbit"


## Peça que mostra um modelo da loja, no tamanho em que ele foi importado.
static func peca_modelo(id: String, modelo_id: String, tamanho: Vector3, posicao: Vector3) -> Dictionary:
	var p := peca_padrao("caixa", id, posicao)
	p["tipo"] = "modelo"
	p["modelo"] = modelo_id
	p["tamanho"] = tamanho.clamp(Vector3.ONE * MapaArquivo.TAMANHO_MIN, Vector3.ONE * MapaArquivo.TAMANHO_MAX)
	return p


## As regras de tamanho do `MapaArquivo` aplicadas a um valor digitado ou
## arrastado, para o editor nunca produzir peça que o arquivo recusaria.
## `eixo_mandante` diz qual eixo a pessoa mexeu (−1 = nenhum em especial).
static func normalizar_tamanho(tipo: String, tamanho: Vector3, eixo_mandante: int = -1) -> Vector3:
	var t := tamanho.clamp(Vector3.ONE * MapaArquivo.TAMANHO_MIN, Vector3.ONE * MapaArquivo.TAMANHO_MAX)
	match tipo:
		"esfera":
			var d: float = t[eixo_mandante] if eixo_mandante >= 0 else minf(t.x, minf(t.y, t.z))
			return Vector3(d, d, d)
		# "capsula" só existe como forma de HITBOX, nunca como tipo de peça — mas a
		# regra de base redonda é a mesma do cilindro.
		"cilindro", "capsula":
			var diametro: float = t.z if eixo_mandante == 2 else t.x
			return Vector3(diametro, t.y, diametro)
	return t


## Rotação em graus dentro de [−180, 180], sem o ruído de 1e−5 que o `get_euler`
## deixa — senão o arquivo ganharia "89.99999" onde a pessoa girou 90.
static func normalizar_rotacao(graus: Vector3) -> Vector3:
	var r := Vector3.ZERO
	for i in 3:
		r[i] = snappedf(wrapf(graus[i], -180.0, 180.0), 0.001)
		if is_equal_approx(r[i], -180.0):
			r[i] = 180.0
	return r
