class_name HistoricoDeEdicao
extends RefCounted
# ============================================================================
#  HISTÓRICO — desfazer/refazer do editor de mapa.
#
#  Toda edição é uma TRANSAÇÃO: `iniciar` fotografa o estado, a edição acontece
#  quantas vezes quiser (um arraste muda a peça a cada movimento do mouse), e
#  `concluir` guarda só a DIFERENÇA entre a foto e o agora. Um arraste inteiro vira
#  um passo de desfazer, não trezentos.
#
#  POR QUE DIFERENÇA DE ESTADO, E NÃO UM COMANDO POR FERRAMENTA
#  -----------------------------------------------------------
#  Com comando por ferramenta, cada operação nova (mover, girar, renomear, trocar
#  forma...) precisaria escrever o próprio "desfazer" — e o dia em que um deles
#  esquecer um campo, o desfazer mente. Guardando antes/depois de cada peça, o
#  desfazer é o MESMO código para qualquer edição, inclusive as que ainda não
#  existem.
#
#  A foto é barata porque o `DocumentoMapa` nunca altera um valor no lugar (ver o
#  cabeçalho dele): copiar o dicionário id→peça copia só as referências.
#
#  Seleção NÃO entra no histórico (igual ao Roblox Studio): desfazer não troca o
#  que está selecionado, só devolve quais peças o passo tocou.
# ============================================================================

signal mudou

const LIMITE := 200

var _doc: DocumentoMapa
var _desfazer: Array[Dictionary] = []
var _refazer: Array[Dictionary] = []
var _foto: Dictionary = {}          # vazio = nenhuma transação aberta


func _init(doc: DocumentoMapa) -> void:
	_doc = doc


func aberta() -> bool:
	return not _foto.is_empty()


func iniciar(nome: String) -> void:
	if aberta():
		concluir()
	_foto = {"nome": nome, "pecas": _doc._pecas.duplicate(), "ordem": _doc._ordem.duplicate(),
		"spawn": _doc.spawn, "grupos": _doc._grupos.duplicate(), "ordem_grupos": _doc._ordem_grupos.duplicate()}


## Guarda o passo se algo mudou. Devolve true se guardou.
func concluir() -> bool:
	if not aberta():
		return false
	var passo := _diferenca(_foto)
	_foto = {}
	if passo.is_empty():
		return false
	_desfazer.append(passo)
	if _desfazer.size() > LIMITE:
		_desfazer.pop_front()
	_refazer.clear()
	mudou.emit()
	return true


## Abandona a transação e devolve o documento ao estado da foto (ESC no meio de
## um arraste).
func cancelar() -> void:
	if not aberta():
		return
	var passo := _diferenca(_foto)
	_foto = {}
	if not passo.is_empty():
		_aplicar(passo, 0)


## Atalho para edição instantânea (apagar, inserir, digitar um valor).
func executar(nome: String, edicao: Callable) -> bool:
	iniciar(nome)
	edicao.call()
	return concluir()


func pode_desfazer() -> bool:
	return not _desfazer.is_empty()


func pode_refazer() -> bool:
	return not _refazer.is_empty()


func nome_do_desfazer() -> String:
	return _desfazer.back()["nome"] if pode_desfazer() else ""


func nome_do_refazer() -> String:
	return _refazer.back()["nome"] if pode_refazer() else ""


## Devolve os ids que o passo tocou e que existem depois de desfeito.
func desfazer() -> Array[String]:
	if aberta():
		cancelar()
	if not pode_desfazer():
		return []
	var passo: Dictionary = _desfazer.pop_back()
	_aplicar(passo, 0)
	_refazer.append(passo)
	mudou.emit()
	return _existentes(passo)


func refazer() -> Array[String]:
	if aberta():
		concluir()
	if not pode_refazer():
		return []
	var passo: Dictionary = _refazer.pop_back()
	_aplicar(passo, 1)
	_desfazer.append(passo)
	mudou.emit()
	return _existentes(passo)


func tamanho() -> int:
	return _desfazer.size()


# ------------------------------------------------------------------- internos
func _diferenca(foto: Dictionary) -> Dictionary:
	var antes: Dictionary = foto["pecas"]
	var agora: Dictionary = _doc._pecas
	var pecas := {}
	for id in antes:
		if not agora.has(id):
			pecas[id] = [antes[id], null]
		elif not is_same(antes[id], agora[id]) and antes[id] != agora[id]:
			pecas[id] = [antes[id], agora[id]]
	for id in agora:
		if not antes.has(id):
			pecas[id] = [null, agora[id]]
	var grupos := {}
	var g_antes: Dictionary = foto["grupos"]
	var g_agora: Dictionary = _doc._grupos
	for gid in g_antes:
		if not g_agora.has(gid):
			grupos[gid] = [g_antes[gid], null]
		elif g_antes[gid] != g_agora[gid]:
			grupos[gid] = [g_antes[gid], g_agora[gid]]
	for gid in g_agora:
		if not g_antes.has(gid):
			grupos[gid] = [null, g_agora[gid]]
	var passo := {"nome": foto["nome"], "pecas": pecas, "grupos": grupos}
	if foto["spawn"] != _doc.spawn:
		passo["spawn"] = [foto["spawn"], _doc.spawn]
	if foto["ordem"] != _doc._ordem:
		passo["ordem"] = [foto["ordem"], _doc._ordem.duplicate()]
	if foto["ordem_grupos"] != _doc._ordem_grupos:
		passo["ordem_grupos"] = [foto["ordem_grupos"], _doc._ordem_grupos.duplicate()]
	if pecas.is_empty() and grupos.is_empty() and not passo.has("spawn") and not passo.has("ordem"):
		return {}
	return passo


# lado 0 = antes (desfazer), 1 = depois (refazer). Remoções e inclusões primeiro,
# ordem por último — incluir põe a peça no fim, e a ordem gravada a devolve ao lugar.
func _aplicar(passo: Dictionary, lado: int) -> void:
	# Grupos que passam a existir entram ANTES das peças que apontam para eles; os
	# que deixam de existir saem DEPOIS. Assim nenhum sinal do meio do caminho vê
	# uma peça apontando para grupo inexistente.
	var grupos: Dictionary = passo.get("grupos", {})
	for gid: String in grupos:
		if grupos[gid][lado] != null:
			_doc.definir_grupo(gid, grupos[gid][lado])
	for id: String in passo["pecas"]:
		var valor: Variant = passo["pecas"][id][lado]
		if valor == null:
			_doc.remover_peca(id)
		else:
			_doc.definir_peca(id, valor)
	if passo.has("spawn"):
		_doc.definir_spawn(passo["spawn"][lado])
	for gid: String in grupos:
		if grupos[gid][lado] == null:
			_doc.remover_grupo(gid)
	if passo.has("ordem"):
		_doc.definir_ordem(passo["ordem"][lado])
	if passo.has("ordem_grupos") and _doc._ordem_grupos.size() == (passo["ordem_grupos"][lado] as Array).size():
		_doc._ordem_grupos = (passo["ordem_grupos"][lado] as Array[String]).duplicate()
		_doc.hierarquia_mudou.emit()


func _existentes(passo: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id: String in passo["pecas"]:
		if _doc.tem(id):
			ids.append(id)
	for gid: String in passo.get("grupos", {}):
		if _doc.tem_grupo(gid):
			ids.append(gid)
	return ids
