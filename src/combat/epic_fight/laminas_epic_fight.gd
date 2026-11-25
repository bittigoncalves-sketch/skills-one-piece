class_name LaminasEpicFight
extends RefCounted
## ARMAS DO EPIC FIGHT NO JOGO (10/11/2026; refeito em 12/11/2026 para ser FIEL ao mod). Entram no inventário (N → ARMAS) e usam o combate direcional da
## espada da história, com tudo que o mod define por item (extraído por `tools/epic_fight/extrair_itens.py` a partir do Java decompilado e dos JSON do mod):
##  • DANO      — o atributo de ataque do item (1,0 + base da categoria + bônus do material: adaga 1+tier, lança 3+tier, tachi/espada longa 4+tier, montante 11+tier,
##                uchigatana 6). `multiplicador` = dano do item ÷ 7,0 (a espada longa de ferro é o 1,0 do executor).
##  • VELOCIDADE — 4,0 + atributo (espada longa 1,2; adaga 2,4; uchigatana 2,0; montante 1,05): escala o tempo dos golpes (`EstiloEpicFight`, como o mod: velocidade ÷ basis_speed).
##  • IMPACTO, MAX_STRIKES e ANULAÇÃO DE ARMADURA — dos JSON de capacidade do item (uma mão).
##  • ALCANCE   — o comprimento da lâmina (proporcional ao collider OBB do mod).
##  • ARTE      — a TEXTURA REAL do mod extrudada em voxels (`ModeloDeItemEF`, como o Minecraft desenha `item/generated`); sem a extração local, um modelo provisório.
## A luva (`glove`) é o punho do mod (M1 `ef_fist_*`), não uma lâmina; não entra aqui.
## 18/11/2026: a concessão automática SAIU (pedido do dono); `conceder_a` só serve a testes e ferramentas. Como obter as armas no jogo: ainda em aberto.

const VOXEL := 0.045
## Os seis ids de ANTES (jogos salvos e testes antigos): viram os itens do mod de mesmo papel.
const APELIDOS := {"ef_adaga": "ef_iron_dagger", "ef_espada_longa": "ef_iron_longsword", "ef_montante": "ef_iron_greatsword",
	"ef_tachi": "ef_iron_tachi", "ef_uchigatana": "ef_uchigatana", "ef_lanca": "ef_iron_spear"}
## Categoria do mod → comprimento da lâmina em jogo (m), cor do metal do modelo provisório (só sem a textura do mod), largura do provisório, nome.
const CATEGORIAS := {
	"dagger": {"nome": "Adaga", "comprimento": 0.40, "metal": Color(0.74, 0.76, 0.80), "largura": 2},
	"longsword": {"nome": "Espada longa", "comprimento": 1.00, "metal": Color(0.78, 0.80, 0.84), "largura": 2},
	"greatsword": {"nome": "Montante", "comprimento": 1.45, "metal": Color(0.70, 0.72, 0.78), "largura": 3},
	"tachi": {"nome": "Tachi", "comprimento": 1.15, "metal": Color(0.86, 0.88, 0.92), "largura": 2},
	"uchigatana": {"nome": "Uchigatana", "comprimento": 0.95, "metal": Color(0.88, 0.90, 0.94), "largura": 1},
	"spear": {"nome": "Lança", "comprimento": 2.00, "metal": Color(0.76, 0.78, 0.82), "largura": 2},
	"sword": {"nome": "Bokken", "comprimento": 0.90, "metal": Color(0.60, 0.45, 0.28), "largura": 2},
}
const MATERIAIS := {"wooden": "de madeira", "stone": "de pedra", "iron": "de ferro", "golden": "de ouro", "diamond": "de diamante", "netherite": "de netherite"}
## Dano de referência: a espada longa de ferro do mod (dano total 7,0) é o multiplicador 1,0 do executor direcional.
const DANO_DE_REFERENCIA := 7.0
const GUARDA_Y := 0.16
static var _cenas := {}
static var _icones := {}
static var _ids: Array[String] = []
static var _tabela := {}


## Os ids das armas do mod (`ef_<item do mod>`). Com os dados locais (`itens.json`): TODAS as do mod com combate de espada — 6 materiais × adaga, espada longa,
## montante, tachi, lança + uchigatana + bokken. Sem eles: as seis provisórias de antes, com os ids novos.
static func ids() -> Array[String]:
	_montar()
	return _ids


static func _montar() -> void:
	if not _ids.is_empty():
		return
	var itens := EpicFightDados.itens()
	for nome: String in itens:
		var d: Dictionary = itens[nome]
		var cat := str(d.categoria)
		if cat == "bokken":
			cat = "sword"
		if not CATEGORIAS.has(cat):
			continue                                   # a luva é o punho (M1 do `ef_fist_*`), não uma lâmina
		_registrar("ef_" + nome, cat, str(d.material), d)
	if _ids.is_empty():
		for velho in APELIDOS:
			var nome := str(APELIDOS[velho]).trim_prefix("ef_")
			var cat := nome.split("_")[-1]
			var mat := nome.split("_")[0] if nome.split("_").size() > 1 else nome
			_registrar(str(APELIDOS[velho]), cat, mat, {})


static func _registrar(id: String, categoria: String, material: String, item: Dictionary) -> void:
	var c: Dictionary = CATEGORIAS[categoria]
	var nome := str(c.nome)
	if MATERIAIS.has(material):
		nome += " " + str(MATERIAIS[material])
	_tabela[id] = {"nome": nome, "tipo": categoria, "material": material, "item": item, "comprimento": c.comprimento, "metal": c.metal, "largura": c.largura}
	_ids.append(id)


## Duas armas formam o estilo dual do mod: adaga+adaga ou espada(bokken)+espada, itens diferentes (`DUAL_DAGGERS`/`DUAL_SWORDS`).
static func pode_dual(principal: String, secundaria: String) -> bool:
	_montar()
	var a := resolver(principal)
	var b := resolver(secundaria)
	if a == "" or b == "" or a == b or not _tabela.has(a) or not _tabela.has(b):
		return false
	var t: String = _tabela[a].tipo
	return t == _tabela[b].tipo and t in ["dagger", "sword"]


static func resolver(id: String) -> String:
	return str(APELIDOS.get(id, id))


static func existe(id: String) -> bool:
	_montar()
	return _tabela.has(resolver(id))


## Concede todas ao inventário (teste).
static func conceder_a(equipamentos: Dictionary, quebradas := {}) -> void:
	for id in ids():
		if not quebradas.has(id):
			equipamentos[id] = true


## Usos máximos do item no mod (`durabilidade` de `itens.json`; sem o dado local, 250 = ferro).
static func durabilidade_maxima(id: String) -> int:
	_montar()
	var real := resolver(id)
	return int((_tabela[real].item as Dictionary).get("durabilidade", 250)) if _tabela.has(real) else 250


## Impacto do mod NA EMPUNHADURA PADRÃO (`DEFAULT_1H/2H_WIELD_STYLE` com a mão livre: adaga e bokken a uma mão; espada longa, montante, tachi, lança e uchigatana a duas,
## e então valem os atributos `two_hand` — ex. lança de ferro: impacto 1,6, 3 alvos, em vez de 2,3 e 1). Sem o dado local, o do ferro da categoria.
static func impacto(id: String) -> float:
	var d: Dictionary = _tabela[resolver(id)]
	var v: Variant = ((d.item as Dictionary).get("atributos", {}) as Dictionary).get("impacto")
	if v == null:
		v = EpicFightDados.categoria(str(d.tipo)).get("materiais", {}).get("iron", {}).get("impacto")
	return float(v) if v != null else 1.0


## Dano de ataque do item no mod (1,0 do jogador + o atributo: ex. espada longa de ferro 7,0, montante de diamante 15,0). Sem dado local: 7,0.
static func dano_do_mod(id: String) -> float:
	var d: Dictionary = _tabela[resolver(id)]
	return float((d.item as Dictionary).get("dano_total", DANO_DE_REFERENCIA))


## Velocidade de ataque do item (4,0 + atributo: espada longa 1,2; adaga 2,4; montante de ferro 1,05). 0 = sem dado local.
static func velocidade_do_mod(id: String) -> float:
	var d: Dictionary = _tabela[resolver(id)]
	return float((d.item as Dictionary).get("velocidade_total", 0.0))


## Golpes que o mod deixa acertar de uma vez (`max_strikes`; uma mão). Padrão do mod: 1.
static func max_alvos(id: String) -> int:
	var d: Dictionary = _tabela[resolver(id)]
	var m: Variant = ((d.item as Dictionary).get("atributos", {}) as Dictionary).get("max_strikes")
	if m == null:
		m = EpicFightDados.categoria(str(d.tipo)).get("materiais", {}).get("iron", {}).get("max_strikes")
	return maxi(int(m) if m != null else 1, 1)


## Multiplicador do executor = dano do mod ÷ dano da espada longa de ferro (7,0).
static func multiplicador(id: String) -> float:
	return dano_do_mod(id) / DANO_DE_REFERENCIA


## Sons da arma (`{golpe: [nome], impacto: [nomes]}`): o swingSound da categoria e o hitSound do material, como no mod. Vazio sem a extração local.
static func sons(id: String) -> Dictionary:
	_montar()
	var real := resolver(id)
	if not _tabela.has(real):
		return {}
	var item: Dictionary = _tabela[real].item
	if not item.has("som_golpe") or not SonsEpicFight.existe(str(item.som_golpe)):
		return {}
	return {"golpe": [str(item.som_golpe)], "impacto": item.get("som_impacto", [])}


## Dados da arma em ESTILO DUAL: o tipo do estilo vira `<tipo>_dual`, e valem os atributos `two_hand` (adaga: 1 alvo, mesmo impacto).
static func dados_dual(principal: String, secundaria: String) -> Dictionary:
	var d := dados(principal)
	if d.is_empty() or not pode_dual(principal, secundaria):
		return d
	d["dual"] = true
	d["dano_do_mod"] = (dano_do_mod(principal) + dano_do_mod(secundaria)) * 0.5      # golpes alternam as mãos (`DualWieldingAttack`): vale a média das duas armas
	d["multiplicador"] = float(d["dano_do_mod"]) / DANO_DE_REFERENCIA
	d["max_alvos"] = 1
	return d


static func dados(id: String) -> Dictionary:
	_montar()
	var real := resolver(id)
	if not _tabela.has(real):
		return {}
	var d: Dictionary = _tabela[real]
	return {"nome": d.nome, "base": Vector3(0, GUARDA_Y, 0), "ponta": Vector3(0, GUARDA_Y + float(d.comprimento), 0),
		"multiplicador": multiplicador(real), "tipo": d.tipo, "material": d.material, "velocidade": velocidade_do_mod(real),
		"max_alvos": max_alvos(real), "sons": sons(real), "dano_do_mod": dano_do_mod(real), "impacto": impacto(real)}


## Ícone 16×16 do item do mod (`<item>_gui.png`; adaga e uchigatana usam o sprite da mão), para a barra de itens e a mochila. null sem a extração local.
static func icone(id: String) -> Texture2D:
	_montar()
	id = resolver(id)
	if not _tabela.has(id):
		return null
	var caminho := ProjectSettings.globalize_path(ModeloDeItemEF.PASTA + str((_tabela[id].item as Dictionary).get("textura_gui", "")))
	if not (_tabela[id].item as Dictionary).has("textura_gui") or not FileAccess.file_exists(caminho):
		return null
	if not _icones.has(id):
		var img := Image.load_from_file(caminho)
		img.convert(Image.FORMAT_RGBA8)
		_icones[id] = ImageTexture.create_from_image(img)
	return _icones[id]


## Modelo da arma: a textura REAL do mod voxelizada (`ModeloDeItemEF`); sem ela, o modelo provisório abaixo.
static func cena(id: String) -> PackedScene:
	_montar()
	id = resolver(id)
	if _cenas.has(id):
		return _cenas[id]
	var d: Dictionary = _tabela[id]
	var textura := str((d.item as Dictionary).get("textura", ""))
	var total: float = float(d.comprimento) + GUARDA_Y + ModeloDeItemEF.RECUO_DO_CABO
	var feito := ModeloDeItemEF.construir(textura, total)
	if not feito.is_empty():
		_cenas[id] = feito.cena
		return feito.cena
	_cenas[id] = _cena_provisoria(id)
	return _cenas[id]


## Modelo voxel provisório: empunhadura abaixo da origem, guarda em GUARDA_Y, lâmina para +Y.
static func _cena_provisoria(id: String) -> PackedScene:
	var d: Dictionary = _tabela[id]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := VOXEL
	var cabo := Color(0.30, 0.20, 0.12)
	var ouro := Color(0.85, 0.68, 0.22)
	var n_cabo := 3 if d.tipo != "spear" else 0
	for i in n_cabo:                                   # empunhadura
		_cubo(st, Vector3(0, -v * (i + 0.5) + 0.06, 0), Vector3(v, v, v), cabo)
	_cubo(st, Vector3(0, -v * n_cabo - v * 0.5 + 0.06, 0), Vector3(v * 1.4, v, v * 1.4), ouro)   # pomo
	var eixo_y := GUARDA_Y
	if d.tipo == "spear":
		var haste := int((float(d.comprimento) * 0.78) / v)
		for i in haste:
			_cubo(st, Vector3(0, -0.12 + v * (i + 0.5), 0), Vector3(v, v, v), cabo)
		eixo_y = -0.12 + v * haste
		_cubo(st, Vector3(0, eixo_y + v * 0.5, 0), Vector3(v * 1.6, v, v * 1.6), ouro)   # anel sob a ponta
		eixo_y += v
		var ponta := int((float(d.comprimento) * 0.22) / v)
		for i in ponta:
			var f := 1.0 - float(i) / maxf(ponta, 1.0)                       # afina até a ponta
			_cubo(st, Vector3(0, eixo_y + v * (i + 0.5), 0), Vector3(v * maxf(2.0 * f, 1.0), v, v), d.metal)
	else:
		_cubo(st, Vector3(0, GUARDA_Y - v * 0.5, 0), Vector3(v * 5.0, v, v * 1.6), ouro)   # guarda
		var n := int(float(d.comprimento) / v)
		for i in n:
			var largura := float(d.largura)
			if i >= n - 2:                                                    # ponta: dois voxels mais estreitos
				largura = 1.0
			_cubo(st, Vector3(0, GUARDA_Y + v * (i + 0.5), 0), Vector3(v * largura, v, v * 0.8), d.metal)
	var malha := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.3
	mat.roughness = 0.55
	malha.surface_set_material(0, mat)
	var raiz := Node3D.new()
	raiz.name = "Lamina_" + id
	var mi := MeshInstance3D.new()
	mi.name = "Voxels"
	mi.mesh = malha
	raiz.add_child(mi)
	mi.owner = raiz
	var cena_pronta := PackedScene.new()
	cena_pronta.pack(raiz)
	raiz.free()
	return cena_pronta


static func _cubo(st: SurfaceTool, c: Vector3, t: Vector3, cor: Color) -> void:
	var h := t * 0.5
	var faces := [
		[Vector3(0, 0, 1), Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
		[Vector3(0, 0, -1), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z)],
		[Vector3(1, 0, 0), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z)],
		[Vector3(-1, 0, 0), Vector3(-h.x, -h.y, -h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3(0, 1, 0), Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3(0, -1, 0), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)],
	]
	for f in faces:
		st.set_color(cor)
		st.set_normal(f[0])
		for idx in [1, 2, 3, 1, 3, 4]:
			st.add_vertex(c + f[idx])
