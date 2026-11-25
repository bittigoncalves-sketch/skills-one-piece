class_name McLoot
extends RefCounted
## LOOT TABLES do Mine Piece (09/11/2026, item 9 da auditoria): as 15 do mod (`mapas/east_blue/loot_do_mod.json`, de `tools/mine_piece/extrair_dados_do_mod.py`)
## — fruta aleatória (`loot_devil_fruit`), baús (tesouro, arma, comida de navio/vila), livro de habilidade, blocos de gelo. As procedures pedem
## `world.getServer().getLootData().getLootTable(id).getRandomItems(Builder.create(…))`; antes isso abortava (`GetRandomItem`, o livro da `StartMinePieceComplated`).
## Só o formato que o mod usa: `rolls` (número ou {min,max}), entradas `minecraft:item` com `weight` e `set_count` ({min,max}). As condições `survives_explosion`
## (blocos) são aceitas e ignoradas — o jogo não tem explosão de bloco com chance de perder o drop.

const ARQUIVO := "res://mapas/east_blue/loot_do_mod.json"
static var _tabelas: Dictionary = {}
static var _rng := RandomNumberGenerator.new()


static func tabelas() -> Dictionary:
	if _tabelas.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
		_tabelas = d if d is Dictionary else {"_": {}}
	return _tabelas


## `LootDataManager`: `getLootTable(ResourceLocation)`.
class Dados:
	extends RefCounted
	func getLootTable(id: Variant) -> Tabela:
		var t := Tabela.new()
		t.definicao = McLoot.tabelas().get(str(id), {})
		if t.definicao.is_empty():
			Mc._falta("loot", str(id))
		return t


## `LootContextParams.Builder` / `LootParams`: o jogo não usa o contexto (sorteio puro).
class Contexto:
	extends RefCounted
	func create(_conjunto: Variant = null) -> Contexto: return self


class Tabela:
	extends RefCounted
	var definicao: Dictionary = {}

	## Sorteio fiel ao Minecraft: por pool, `rolls` vezes escolhe uma entrada por peso e aplica `set_count`.
	func getRandomItems(_contexto: Variant = null) -> Array:
		var saida := []
		for pool: Dictionary in definicao.get("pools", []):
			var entradas: Array = (pool.get("entries", []) as Array).filter(func(e): return str(e.get("type", "")) == "minecraft:item")
			if entradas.is_empty():
				continue
			var peso_total := 0
			for e: Dictionary in entradas:
				peso_total += maxi(int(e.get("weight", 1)), 0)
			if peso_total <= 0:
				continue
			for _r in _inteiro(pool.get("rolls", 1)):
				var alvo := McLoot._rng.randi_range(1, peso_total)
				for e: Dictionary in entradas:
					alvo -= maxi(int(e.get("weight", 1)), 0)
					if alvo <= 0:
						var n := 1
						for f: Dictionary in e.get("functions", []):
							if str(f.get("function", "")) == "set_count" or str(f.get("function", "")) == "minecraft:set_count":
								n = _inteiro(f.get("count", 1))
						if n > 0:
							saida.append(McItem.pilha(Mc.item(StringName(str(e.get("name", "")))), n))
						break
		return saida

	static func _inteiro(v: Variant) -> int:
		if v is Dictionary:
			return McLoot._rng.randi_range(int(v.get("min", 0)), int(v.get("max", v.get("min", 0))))
		return int(v)
