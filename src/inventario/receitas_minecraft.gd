class_name ReceitasMinecraft
extends RefCounted
## RECEITAS DE FABRICAÇÃO da grade 2×2 (10/11/2026). Lê as receitas do JAR do Minecraft 1.20.1 (`assets/minecraft_local/recipes`, local) e as do Mine Piece
## (`mapas/east_blue/receitas_do_mod.json`, mesmo formato). Só `crafting_shaped` (padrão até 2×2, com espelho como no jogo) e `crafting_shapeless` (até 4
## ingredientes); ingredientes `{item}`, `{tag}` (tags em `assets/minecraft_local/tags/items`) ou lista de alternativas.
## Fora: receitas especiais (tinta, fogos, mapas…), fornalha, pedra, ferraria — dependem de blocos que o jogo ainda não tem.
const PASTA := "res://assets/minecraft_local/"

static var _carregado := false
static var _modeladas: Array = []      # {padrao: [[alt, alt], ...] (linhas), res: {id, count}}
static var _sem_forma: Array = []      # {ingredientes: [alt, ...], res}
static var _tags := {}                 # nome → {id: true}


static func _carregar() -> void:
	if _carregado:
		return
	_carregado = true
	var d := DirAccess.open(PASTA + "recipes")
	if d != null:
		for arq in d.get_files():
			if arq.ends_with(".json"):
				var f := FileAccess.open(PASTA + "recipes/" + arq, FileAccess.READ)
				if f != null:
					_adicionar(JSON.parse_string(f.get_as_text()))
	var m := FileAccess.open("res://mapas/east_blue/receitas_do_mod.json", FileAccess.READ)
	if m != null:
		var todas: Variant = JSON.parse_string(m.get_as_text())
		if todas is Dictionary:
			for k in todas:
				_adicionar(todas[k])


static func recarregar() -> void:
	_carregado = false
	_modeladas.clear()
	_sem_forma.clear()
	_tags.clear()


static func _alternativas(ing: Variant) -> Array:
	var saida: Array = []
	if ing is Array:
		for x in ing:
			saida.append_array(_alternativas(x))
	elif ing is Dictionary:
		if ing.has("item"):
			saida.append(str(ing["item"]))
		elif ing.has("tag"):
			saida.append("#" + str(ing["tag"]))
	return saida


static func _adicionar(r: Variant) -> void:
	if not (r is Dictionary) or not r.has("result"):
		return
	var tipo := str(r.get("type", "")).trim_prefix("minecraft:")
	var res: Variant = r["result"]
	var resultado := {"id": str(res.get("item", "")), "count": int(res.get("count", 1))} if res is Dictionary else {"id": str(res), "count": 1}
	if resultado.id.is_empty():
		return
	if tipo == "crafting_shaped":
		var padrao: Array = r.get("pattern", [])
		if padrao.is_empty() or padrao.size() > 2:
			return
		var larg := 0
		for linha in padrao:
			larg = maxi(larg, str(linha).length())
		if larg > 2:
			return
		var chaves: Dictionary = r.get("key", {})
		var grade: Array = []
		for linha in padrao:
			var cel: Array = []
			for i in larg:
				var c := str(linha)[i] if i < str(linha).length() else " "
				cel.append([] if c == " " else _alternativas(chaves.get(c)))
			grade.append(cel)
		_modeladas.append({"padrao": grade, "res": resultado})
	elif tipo == "crafting_shapeless":
		var ings: Array = []
		for x in r.get("ingredients", []):
			ings.append(_alternativas(x))
		if ings.size() <= 4 and not ings.is_empty():
			_sem_forma.append({"ingredientes": ings, "res": resultado})


static func _tag_contem(tag: String, id: String) -> bool:
	if not _tags.has(tag):
		var conj := {}
		var f := FileAccess.open(PASTA + "tags/items/%s.json" % tag.trim_prefix("minecraft:"), FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for v in d.get("values", []):
					var s := str(v)
					if s.begins_with("#"):
						for sub in _expandir(s.trim_prefix("#")):
							conj[sub] = true
					else:
						conj[s] = true
		_tags[tag] = conj
	return (_tags[tag] as Dictionary).has(id)


static func _expandir(tag: String) -> Array:
	_tag_contem(tag, "")
	return (_tags[tag] as Dictionary).keys()


static func _casa(alternativas: Array, id: String) -> bool:
	for a in alternativas:
		var s := str(a)
		if s.begins_with("#"):
			if _tag_contem(s.trim_prefix("#"), id):
				return true
		elif s == id:
			return true
	return false


## `grade`: 4 pilhas (linha 0: 0,1 · linha 1: 2,3). Devolve {id, count} ou {}.
static func achar(grade: Array) -> Dictionary:
	_carregar()
	var ids: Array = []
	var n := 0
	for p in grade:
		var id := "" if p == null or p.isEmpty() else String(p.item.id)
		ids.append(id)
		if id != "":
			n += 1
	if n == 0:
		return {}
	for r in _modeladas:
		var pad: Array = r.padrao
		var h := pad.size()
		var w: int = (pad[0] as Array).size()
		for espelho in [false, true]:
			for dy in range(0, 2 - h + 1):
				for dx in range(0, 2 - w + 1):
					if _confere(ids, pad, w, h, dx, dy, espelho):
						return r.res
	for r in _sem_forma:
		var ings: Array = r.ingredientes
		if ings.size() == n and _atribuir(ings, ids.filter(func(x): return x != ""), 0, []):
			return r.res
	return {}


static func _confere(ids: Array, pad: Array, w: int, h: int, dx: int, dy: int, espelho: bool) -> bool:
	for y in 2:
		for x in 2:
			var id: String = ids[y * 2 + x]
			var py := y - dy
			var px := x - dx
			var dentro := py >= 0 and py < h and px >= 0 and px < w
			if not dentro:
				if id != "":
					return false
				continue
			var cx := (w - 1 - px) if espelho else px
			var alt: Array = (pad[py] as Array)[cx]
			if alt.is_empty():
				if id != "":
					return false
			elif id == "" or not _casa(alt, id):
				return false
	return true


static func _atribuir(ings: Array, itens: Array, i: int, usados: Array) -> bool:
	if i >= ings.size():
		return true
	for k in itens.size():
		if usados.has(k) or not _casa(ings[i], str(itens[k])):
			continue
		if _atribuir(ings, itens, i + 1, usados + [k]):
			return true
	return false
