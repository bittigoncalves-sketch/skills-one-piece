class_name SelecaoDoEditor
extends RefCounted
# ============================================================================
#  SELEÇÃO do editor de mapa — quais peças (e/ou o spawn) estão selecionadas.
#
#  O spawn entra na seleção com um id reservado que tem "@". O `MapaArquivo` não
#  aceita "@" em id de peça, então os dois nunca colidem, e Explorer, gizmo e
#  cena 3D tratam o spawn como mais um item selecionável.
# ============================================================================

signal mudou

const SPAWN := "@spawn"

var _ids: Array[String] = []


func ids() -> Array[String]:
	return _ids.duplicate()


## Os itens sem o spawn — peças E grupos (ver `OperacoesDoEditor.pecas_da_selecao`
## para chegar às peças de dentro dos grupos).
func pecas() -> Array[String]:
	var so: Array[String] = []
	for id in _ids:
		if id != SPAWN:
			so.append(id)
	return so


func vazia() -> bool:
	return _ids.is_empty()


func contem(id: String) -> bool:
	return _ids.has(id)


func tem_spawn() -> bool:
	return _ids.has(SPAWN)


func definir(novos: Array[String]) -> void:
	var limpos: Array[String] = []
	for id in novos:
		if not limpos.has(id):
			limpos.append(id)
	if limpos == _ids:
		return
	_ids = limpos
	mudou.emit()


func alternar(id: String) -> void:
	var novos := _ids.duplicate()
	if novos.has(id):
		novos.erase(id)
	else:
		novos.append(id)
	definir(novos)


func limpar() -> void:
	definir([])


## Depois de apagar ou desfazer: tira da seleção o que não existe mais.
func podar(doc: DocumentoMapa) -> void:
	var vivos: Array[String] = []
	for id in _ids:
		if id == SPAWN or doc.tem_item(id):     # grupo também é item selecionável
			vivos.append(id)
	definir(vivos)
