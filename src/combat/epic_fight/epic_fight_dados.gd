class_name EpicFightDados
extends RefCounted
## Acesso aos dados do Epic Fight convertidos por `tools/epic_fight/` (extrair_fases.py + extrair_dados.py).
## Os JSON ficam em `res://assets/epic_fight/` (LOCAL, fora do git — assets All Rights Reserved). Sem eles,
## `disponivel()` é false e cada consulta devolve o vazio/padrão: o jogo NUNCA depende do mod para rodar.
## DADOS entram como estão; ARTE de mod passa pela voxelização (docs/MODS_VOXELIZACAO.md).

const PASTA := "res://assets/epic_fight/"
static var _cache := {}


static func _json(nome: String) -> Variant:
	if _cache.has(nome):
		return _cache[nome]
	var caminho := PASTA + nome + ".json"
	var dados: Variant = {}
	if FileAccess.file_exists(caminho):
		var lido: Variant = JSON.parse_string(FileAccess.get_file_as_string(caminho))
		if lido != null:
			dados = lido
	_cache[nome] = dados
	return dados


static func recarregar() -> void:
	_cache.clear()


static func disponivel() -> bool:
	return not ataques().is_empty()


## id do clipe sem prefixo "biped/", ex.: "combat/fist_auto1"
static func ataques() -> Dictionary:
	var d: Variant = _json("fases")
	return d.get("ataques", {}) if d is Dictionary else {}


static func ataque(clipe: String) -> Dictionary:
	return ataques().get(clipe, {})


## Janela de dano (pré-atraso → contato) e fim do golpe, em segundos DO CLIPE. Vazio se desconhecido.
static func fase(clipe: String, indice := 0) -> Dictionary:
	var a := ataque(clipe)
	var f: Array = a.get("fases", [])
	if indice < 0 or indice >= f.size():
		return {}
	return f[indice]


## Fator de velocidade do clipe no jogo: o mod toca o clipe a `velocidade_do_jogador / basis_speed`.
static func velocidade_do_clipe(clipe: String, velocidade_de_ataque := 4.0) -> float:
	var basis := float(ataque(clipe).get("basis_speed", 0.0))
	return velocidade_de_ataque / basis if basis > 0.0 else 1.0


# ------------------------------------------------------------------ 1b. itens (extrair_itens.py)
## Todos os itens de arma do mod: `{<nome>: {categoria, material, dano_total, velocidade_total, durabilidade, impacto, max_strikes, anula_armadura, duas_maos, textura}}`.
static func itens() -> Dictionary:
	var d: Variant = _json("itens")
	return d.get("itens", {}) if d is Dictionary else {}


static func item(nome: String) -> Dictionary:
	return itens().get(nome, {})


# ------------------------------------------------------------------ 2. armas
static func armas() -> Dictionary: return _json("armas")
static func categoria(tipo: String) -> Dictionary: return armas().get(tipo, {})


# ------------------------------------------------- 3. atordoamento / golpes
## Tipo de stun do mod (SHORT, LONG, KNOCKDOWN…) → {hitstun, derruba, empurra} em segundos do JOGO.
static func atordoamento(tipo: String) -> Dictionary:
	return _json("atordoamento").get(tipo, {"hitstun": 0.35, "derruba": 0.0, "empurra": true})


## Stun do golpe: o primeiro declarado no mod; sem declaração, o padrão do mod é SHORT.
static func stun_do_ataque(clipe: String) -> String:
	var s: Array = ataque(clipe).get("stun", [])
	return str(s[0]) if not s.is_empty() else "SHORT"


## Quantos alvos o golpe atravessa (`max_strikes`): material da arma + modificadores do golpe. Padrão do mod = 1.
static func max_alvos(tipo_de_arma: String, material: String, clipe := "") -> int:
	var base := int(categoria(tipo_de_arma).get("materiais", {}).get(material, {}).get("max_strikes", 1))
	for m: Dictionary in ataque(clipe).get("max_strikes", []):
		base = base + int(m["valor"]) if m["op"] == "adding" else (int(base * float(m["valor"])) if m["op"] == "multiplier" else int(m["valor"]))
	return maxi(base, 1)


# ------------------------------------------------------------ 4. reações
static func reacao(nome: String) -> Dictionary: return _json("reacoes").get(nome, {})


# ------------------------------------------------------------ 5. estamina
static func estamina() -> Dictionary: return _json("estamina")
static func custo_de(habilidade: String) -> float: return float(estamina().get("custos", {}).get(habilidade, 0.0))


# ----------------------------------------------------------- 8. rastros
## Janelas do rastro do golpe: [{start_time, end_time, joint, item_skin_hand}]
static func trilhas(clipe: String) -> Array: return _json("trilhas").get(clipe, [])


# ------------------------------------------------------------ 7. habilidades
static func habilidade(id: String) -> Dictionary: return _json("habilidades").get(id, {})
static func armadura(id: String) -> Dictionary: return _json("armaduras").get(id, {})
