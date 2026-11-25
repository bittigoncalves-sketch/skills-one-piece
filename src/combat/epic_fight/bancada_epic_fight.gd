class_name BancadaEpicFight
extends RefCounted
## FABRICAÇÃO DAS ARMAS DO EPIC FIGHT (12/11/2026) — as receitas do mod (`data/epicfight/recipe`, 26 `crafting_shaped` 3×3: adaga/espada longa/montante/tachi/lança em madeira, pedra, ferro, ouro
## e diamante; a netherite sai de ferraria no mod e não tem receita aqui) lidas de `assets/epic_fight/receitas.json`.
## O jogo só tem a grade 2×2 do inventário, então a fabricação é por PADRÃO: a janela BANCADA da central mostra o padrão 3×3 do mod e fabrica quando a mochila tem os ingredientes
## na QUANTIDADE do padrão (como o livro de receitas do Minecraft preenche a grade). Ingredientes `{item}`, `{tag}` (ex. `minecraft:planks`) ou alternativas; consome da mochila.
## O resultado é a ARMA (`equipamentos["ef_<item>"]`), não uma pilha: fabricar de novo restaura a durabilidade e tira da lista de quebradas.

static var _cache := {}
static var _lido := false


static func receitas() -> Dictionary:
	if not _lido:
		_lido = true
		var caminho := ProjectSettings.globalize_path("res://assets/epic_fight/receitas.json")
		if FileAccess.file_exists(caminho):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
			if d is Dictionary:
				_cache = (d as Dictionary).get("receitas", {})
	return _cache


## Ids de arma (`ef_<item>`) com receita, na ordem do arquivo.
static func ids() -> Array[String]:
	var r: Array[String] = []
	for k in receitas():
		var id := "ef_" + str(receitas()[k].get("resultado", ""))
		if LaminasEpicFight.existe(id):               # a luva (punho) tem receita no mod mas não é uma lâmina daqui
			r.append(id)
	return r


## `{chave: quantidade}` do padrão (ex. {"X": 5, "#": 1}), e `{chave: ingrediente}`.
static func contagem(id: String) -> Dictionary:
	var r: Dictionary = receitas().get(id.trim_prefix("ef_"), {})
	var n := {}
	for linha in r.get("padrao", []):
		for c in str(linha):
			if c != " ":
				n[c] = int(n.get(c, 0)) + 1
	return n


static func ingrediente(id: String, chave: String) -> Dictionary:
	return (receitas().get(id.trim_prefix("ef_"), {}) as Dictionary).get("chaves", {}).get(chave, {})


## Os ids de item que servem para o ingrediente (`{item}` ou as do `{tag}`).
static func alternativas(ing: Dictionary) -> Array[String]:
	var r: Array[String] = []
	if ing.has("item"):
		r.append(str(ing.item))
	elif ing.has("tag"):
		for id in ReceitasMinecraft._expandir(str(ing.tag)):
			r.append(str(id))
	return r


## Quantos do ingrediente a mochila tem (somando as alternativas da tag).
static func tem(inv: InventarioMinecraft, ing: Dictionary) -> int:
	var n := 0
	for id in alternativas(ing):
		n += inv.contar(id)
	return n


static func pode_fabricar(inv: InventarioMinecraft, id: String) -> bool:
	var cont := contagem(id)
	if cont.is_empty():
		return false
	for chave in cont:
		if tem(inv, ingrediente(id, str(chave))) < int(cont[chave]):
			return false
	return true


## Consome os ingredientes e entrega a arma. Devolve false (sem tocar em nada) se faltar algo.
static func fabricar(prog: ProgressaoDoPersonagem, id: String) -> bool:
	if prog == null or not pode_fabricar(prog.inventario, id):
		return false
	var cont := contagem(id)
	for chave in cont:
		var falta := int(cont[chave])
		for alt in alternativas(ingrediente(id, str(chave))):
			var tira := mini(falta, prog.inventario.contar(alt))
			if tira > 0:
				prog.inventario.remover(alt, tira)
				falta -= tira
			if falta == 0:
				break
	prog.equipamentos[id] = true
	prog.ef_quebradas.erase(id)
	prog.durabilidade_ef.erase(id)
	prog.mudou.emit()
	return true
