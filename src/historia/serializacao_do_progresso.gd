extends RefCounted
## Validação e migração do save; extraída para manter progressao.gd abaixo de 900 linhas.
static func de_dict(d: Variant) -> ProgressaoDoPersonagem:
	var p := ProgressaoDoPersonagem.new()
	if not (d is Dictionary) or d.get("formato") != ProgressaoDoPersonagem.FORMATO:
		return p
	var corpo_salvo: Variant = d.get("corpo", "")
	if corpo_salvo is String and corpo_salvo in ProgressaoDoPersonagem.CORPOS:
		p.corpo = corpo_salvo
	p.tom_de_pele = ProgressaoDoPersonagem.TonsDePele.normalizar(d.get("tom_de_pele"))
	p.aparencia = ProgressaoDoPersonagem.AparenciaHistoria.normalizar(d.get("aparencia"))
	var raca_salva: Variant = d.get("raca", "humano")
	if raca_salva is String and raca_salva in ProgressaoDoPersonagem.RACAS:
		p.raca = raca_salva
	# Ilhas visitadas: só as do cadastro.
	var iv: Variant = d.get("ilhas_visitadas", [])
	if iv is Array:
		for id in iv:
			if ProgressaoDoPersonagem.Ilhas.existe(str(id)) and not str(id) in p.ilhas_visitadas:
				p.ilhas_visitadas.append(str(id))
	p.nivel = maxi(_inteiro(d.get("nivel", 1)), 1)      # sem teto (A3)
	p.xp = maxi(_inteiro(d.get("xp", 0)), 0)
	# Save sem o campo (antes de 27/10/2026): o início do mod (10.000).
	p.limite_de_recompensa = maxf(float(_inteiro(d.get("limite_de_recompensa", 10000))), 10000.0)
	# Conquistas do mod: só ids que existem, só critérios que a conquista tem (id inventado à mão some).
	var cm: Variant = d.get("conquistas_mod", {})
	if cm is Dictionary:
		var defs := McConquistas.definicoes()
		for id in cm:
			var def: Variant = defs.get(str(id))
			if def != null and cm[id] is Array:
				var feitos := []
				for c in cm[id]:
					if (def as McConquistas.Def).criterios.has(str(c)) and not feitos.has(str(c)):
						feitos.append(str(c))
				if not feitos.is_empty():
					p.conquistas_mod[str(id)] = feitos
	p.ouro = maxi(_inteiro(d.get("ouro", 0)), 0)
	# `pontos` e `atributos` de saves antigos são ignorados: os atributos vêm do nível (A6).
	var sk: Variant = d.get("skills", {})
	for chave in ProgressaoDoPersonagem.SKILLS:
		var piso: int = ProgressaoDoPersonagem.SKILL_MINIMA.get(chave, 0)
		p.skills[chave] = clampi(_inteiro(sk.get(chave, piso)), piso, ProgressaoDoPersonagem.SKILL_MAXIMO) if sk is Dictionary else piso
	# `missoes_especiais` de saves antigos é ignorado: não há mais missão de nível (A3).
	var db: Variant = d.get("desbloqueios", {})
	for chave in p.desbloqueios:
		p.desbloqueios[chave] = db is Dictionary and db.get(chave) == true
	# Fruta do arquivo só vale se EXISTIR no jogo: id inventado à mão vira "" em vez de
	# deixar o corpo com uma fruta que ninguém sabe montar.
	var fr: Variant = d.get("fruta", "")
	if fr is String:
		fr = CatalogoFrutasMinePiece.atual(fr)
	# As traduções do Mine Piece (controlador próprio) também são frutas do jogo.
	if fr is String and (SkillSystem.get_fruit_skills().has(fr) or (KitDoBuilder.e_do_builder(fr) and KitDoBuilder.disponivel(fr))
			or CatalogoFrutasMinePiece.contem(fr) or FrutasDoMod.contem(fr) or fr == PerfilDeFrutas.GORO_MINE_PIECE):
		p.fruta = fr
	p.fruta_ativa = d.get("fruta_ativa", true) != false     # save antigo (sem o campo): ligada
	var ef: Variant = d.get("espada_da_fruta", "")
	if ef is String and CatalogoFrutasMinePiece.contem(p.fruta) \
			and str(CatalogoFrutasMinePiece.FICHAS[p.fruta].get("espada", {}).get("id", "")) == ef:
		p.espada_da_fruta = ef
	# Pets: só espécie que existe e modo válido. Save sem o campo fica sem pets (desde
	# 18/10/2026 o jogo novo começa sem nenhum).
	# 01/10/2026: um registro por pet (id → espécie/nome/modo); save antigo (id = espécie,
	# só {"modo"}) continua valendo. Espécie que não é do catálogo de pets é um animal da
	# loja — só o formato do id é conferido aqui (a loja pode não estar carregada).
	var pt: Variant = d.get("pets", null)
	if pt is Dictionary:
		p.pets = {}
		var forma := RegEx.create_from_string("^[A-Za-z0-9_-]{1,64}$")
		for id in pt:
			var dados: Variant = pt[id]
			if not (dados is Dictionary) or forma.search(str(id)) == null:
				continue
			var especie := str(dados.get("especie", id))
			if forma.search(especie) == null:
				continue
			if not dados.has("especie") and not CatalogoDePets.existe(especie):
				continue
			var modo: Variant = dados.get("modo", "")
			var nome := str(dados.get("nome", "")).strip_edges().left(40)
			p.pets[str(id)] = {"especie": especie,
				"nome": nome if not nome.is_empty() else CatalogoDePets.nome(especie),
				"modo": StringName(str(modo)) if ModoDoPet.valido(modo) else CatalogoDePets.modo_inicial(especie)}
	var recebidos: Variant = d.get("pets_do_mapa_recebidos", {})
	if recebidos is Dictionary:
		var forma_origem := RegEx.create_from_string("^[A-Za-z0-9_-]{1,96}$")
		for origem in recebidos:
			if recebidos[origem] == true and forma_origem.search(str(origem)) != null:
				p.pets_do_mapa_recebidos[str(origem)] = true
	var pc: Variant = d.get("pesca", {})
	if pc is Dictionary:
		for id in pc:
			var qtd := _inteiro(pc[id])
			if qtd > 0 and str(id).length() <= 64:
				p.pesca[str(id)] = qtd
	var ativo := str(d.get("item_ativo", "luta"))
	p.item_ativo = ativo if ProgressaoDoPersonagem.ITENS_DA_BARRA.has(ativo) or ativo == ProgressaoDoPersonagem.NENHUM_ITEM else "luta"
	var eq: Variant = d.get("equipamentos", {})
	if eq is Dictionary:
		for id in eq:
			if eq[id] == true and (str(id) == "vara_de_pesca" or LaminasEpicFight.existe(str(id))):   # espada antiga e machado saíram (10/11/2026)
				p.equipamentos[LaminasEpicFight.resolver(str(id))] = true
	# Saves antigos também recebem o item inicial, sem equipá-lo à força.
	p.machado_equipado = false
	var quebradas: Variant = d.get("ef_quebradas", {})
	if quebradas is Dictionary:
		for id in quebradas:
			p.ef_quebradas[LaminasEpicFight.resolver(str(id))] = true
			p.equipamentos.erase(LaminasEpicFight.resolver(str(id)))
	var gasto: Variant = d.get("durabilidade_ef", {})
	if gasto is Dictionary:
		for id in gasto:
			p.durabilidade_ef[LaminasEpicFight.resolver(str(id))] = int(gasto[id])
	var lam := LaminasEpicFight.resolver(str(d.get("lamina_ef", "")))
	p.lamina_ef = lam if LaminasEpicFight.existe(lam) and d.get("espada_equipada", false) == true else ""
	p.espada_equipada = p.lamina_ef != ""
	var sec := LaminasEpicFight.resolver(str(d.get("lamina_ef_sec", "")))
	p.lamina_ef_sec = sec if p.lamina_ef != "" and p.equipamentos.has(sec) and LaminasEpicFight.pode_dual(p.lamina_ef, sec) else ""
	if p.item_ativo in ["espada", "machado"]:
		p.item_ativo = "luta"
	p.madeira = maxi(0, _inteiro(d.get("madeira", 0)))
	if d.get("inventario") is Dictionary:
		p.inventario = InventarioMinecraft.de_dict(d["inventario"])
		p.inventario.mudou.connect(func(): p.itens_do_mod_mudaram.emit())
	var itens_mod: Variant = d.get("itens_do_mod", {})        # save antigo: contador de biscoitos → itens do inventário
	if itens_mod is Dictionary:
		for k in itens_mod:
			var q := maxi(0, _inteiro(itens_mod[k]))
			if q > 0 and p.inventario.contar(str(k)) == 0:
				p.inventario.inserir(InventarioMinecraft.nova(str(k), q))
	p.vara_equipada = d.get("vara_equipada", false) == true and p.equipamentos.has("vara_de_pesca")
	p.kit_de_blocos_entregue = d.get("kit_de_blocos_entregue", false) == true
	p.inventario_ef_entregue = d.get("inventario_ef_entregue", false) == true
	var fc: Variant = d.get("frutas_compradas", {})
	if fc is Dictionary:
		var da_arena := PerfilDeFrutas.frutas_a_venda()        # arena + frutas do Builder
		for id in fc:
			var qtd := _inteiro(fc[id])
			var atual := CatalogoFrutasMinePiece.atual(str(id))
			if qtd > 0 and da_arena.has(atual):
				p.frutas_compradas[atual] = mini(int(p.frutas_compradas.get(atual, 0)) + qtd, 99)
	var fp: Variant = d.get("frutas_do_pomar", {})
	if fp is Dictionary:
		for id in fp:
			var qtd := _inteiro(fp[id])
			if qtd > 0 and str(id).length() <= 64:
				p.frutas_do_pomar[str(id)] = mini(qtd, 9999)
	p.recolher_frutas_para_o_inventario()          # saves antigos: as frutas das listas passam para o inventário (25/11/2026)
	# Missões: só as da tabela, estado conhecido, abates entre 0 e a meta.
	var ms2: Variant = d.get("missoes", {})
	if ms2 is Dictionary:
		for id in ms2:
			var m: Variant = ms2[id]
			if not ProgressaoDoPersonagem.Missoes.existe(str(id)) or not (m is Dictionary):
				continue
			var estado := str(m.get("estado", ""))
			if estado == ProgressaoDoPersonagem.Missoes.FALHOU:
				p.missoes[str(id)] = {"estado": estado, "abates": 0}
				continue
			if estado != ProgressaoDoPersonagem.Missoes.ACEITA and estado != ProgressaoDoPersonagem.Missoes.ENTREGUE:
				continue
			var dm := ProgressaoDoPersonagem.Missoes.dados(str(id))
			var meta := int(dm["meta"])
			p.missoes[str(id)] = {"estado": estado, "abates": clampi(_inteiro(m.get("abates", 0)), 0, meta)}
			# Metas por item (provisões): só os itens da tabela, cada um até a sua meta;
			# `abates` volta a ser a soma (um save editado não pula a missão).
			if dm.has("itens"):
				var lidos: Variant = m.get("itens", {})
				var itens := {}
				var soma := 0
				for item in dm.itens:
					var n := clampi(_inteiro(lidos.get(item, 0)), 0, int(dm.itens[item])) if lidos is Dictionary else 0
					itens[item] = n
					soma += n
				p.missoes[str(id)]["itens"] = itens
				if estado == ProgressaoDoPersonagem.Missoes.ACEITA:
					p.missoes[str(id)]["abates"] = mini(soma, meta)
	# 18/10/2026: "peixes" (pescar 10) virou "provisoes" (comprar pão e água). Entregue
	# continua entregue (a bússola já veio); aceita recomeça do zero — peixe não é provisão.
	if ms2 is Dictionary and ms2.get("peixes") is Dictionary and not p.missoes.has("provisoes"):
		var antiga := str(ms2["peixes"].get("estado", ""))
		var dp := ProgressaoDoPersonagem.Missoes.dados("provisoes")
		if antiga == ProgressaoDoPersonagem.Missoes.ENTREGUE:
			p.missoes["provisoes"] = {"estado": antiga, "abates": int(dp.meta), "itens": (dp.itens as Dictionary).duplicate()}
		elif antiga == ProgressaoDoPersonagem.Missoes.ACEITA:
			p.missoes["provisoes"] = {"estado": antiga, "abates": 0, "itens": {}}
	# Missões de madeira saíram (10/11/2026). Quem já tinha começado a cadeia segue de onde parou:
	# quem passou da ferraria ou da facção mantém as iniciais entregues.
	if p.missoes.has("bandidos") or p.missoes.has("faccao_inicial"):
		for inicial in ["vara_inicial", "peixe_raro", "ferraria", "faccao_inicial"]:
			if not (ms2 is Dictionary and ms2.has(inicial)): p.missoes[inicial] = {"estado": ProgressaoDoPersonagem.Missoes.ENTREGUE, "abates": int(ProgressaoDoPersonagem.Missoes.dados(inicial).meta)}
	# Barcos: só o formato do id (a loja pode não estar carregada); quem monta confere.
	var bc: Variant = d.get("barcos", {})
	if bc is Dictionary:
		var forma_barco := RegEx.create_from_string("^[A-Za-z0-9_-]{1,64}$")
		for id in bc:
			if bc[id] == true and forma_barco.search(str(id)) != null:
				p.barcos[str(id)] = true
	var rc: Variant = d.get("recrutados", {})
	if rc is Dictionary:
		for id in rc:
			if rc[id] == true and CatalogoDeTripulantes.existe(str(id)):
				p.recrutados[str(id)] = true
	var si: Variant = d.get("sistemas", {})
	if si is Dictionary:
		for nome in si:
			if si[nome] is Dictionary and str(nome).length() <= 32:
				p.sistemas[str(nome)] = (si[nome] as Dictionary).duplicate(true)
	var rea: Variant = d.get("reanimacoes", [])
	if rea is Array:
		var lista: Array[int] = []
		for t in rea:
			var ms := _inteiro(t)
			if ms > 0:
				lista.append(ms)
		lista.sort()
		p.reanimacoes_ms.assign(lista.slice(maxi(lista.size() - ProgressaoDoPersonagem.MAX_REANIMACOES_GUARDADAS, 0)))
	# Último local pisado: só ilha do cadastro e números finitos (arquivo editado à mão não pode jogar o corpo no infinito).
	var ls: Variant = d.get("local_salvo", {})
	if ls is Dictionary and ProgressaoDoPersonagem.Ilhas.existe(str(ls.get("ilha", ""))):
		var xyz := [ls.get("x"), ls.get("y"), ls.get("z")]
		var ok := true
		for v in xyz:
			if not (v is float or v is int) or not is_finite(float(v)) or absf(float(v)) > 100000.0:
				ok = false
		if ok:
			p.local_salvo = {"ilha": str(ls["ilha"]), "x": float(xyz[0]), "y": float(xyz[1]), "z": float(xyz[2])}
	# Arquivo com XP acima do requisito (editado à mão): acerta o nível já.
	p._subir_o_que_der()
	return p


## Número do JSON (vem como float) ou 0 para qualquer outra coisa — `int(null)`
## derrubaria o carregamento.
static func _inteiro(v: Variant) -> int:
	if v is int:
		return v
	if v is float and is_finite(v):
		return int(v)
	return 0


