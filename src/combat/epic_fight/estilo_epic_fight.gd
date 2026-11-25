class_name EstiloEpicFight
extends RefCounted
## ESTILO DE COMBATE DE UMA CATEGORIA DE ARMA DO EPIC FIGHT (10/11/2026): a cadeia de golpes REAL do mod no executor direcional.
## Gerado em tempo de execução a partir dos dados locais (`assets/epic_fight/armas.json` + `fases.json` + `atordoamento.json`):
##  • clipe — o golpe toca o clipe do mod (`ef_<ataque>.res`), que é dono do corpo; a pose procedural do estilo base não entra.
##  • fases — preparo = 0 → pré-atraso (antecipação), ativo = pré-atraso → contato, recuperação = contato → fim do clipe (tempos do `Animations.java`).
##  • atordoamento — o `hitstun` e `pesado` saem do StunType do golpe (SHORT 0,35 s … KNOCKDOWN 0,8 s).
##  • dano — o do estilo base × multiplicador da arma (`LaminasEpicFight.multiplicador`: dano do item no mod ÷ 7,0).
##  • velocidade — o fator `velocidade do item ÷ basis_speed` encurta/alonga as três fases (clipe e hitstun seguem as durações do golpe).
##  • cadeia — clique simples percorre auto1 → auto2 → auto3 (as direções do executor são só os 4 encaixes); o 4º encaixe é o golpe de corrida
##    (`*_dash`) ou, sem ele, o último auto. Gestos de mouse continuam escolhendo golpes por direção.
## Não vem do mod ainda: `max_strikes` (acerta N alvos), variantes de habilidade (liechtenauer, dual), airslash, rastros. Contrato em `docs/CHECKPOINT_EPIC_FIGHT.md`.
## Base de rig/guarda/defesa: o estilo da espada da história (`espada.tres`) — o mod não tem postura de guarda.

const BASE := preload("res://src/combat/direcional/estilos/espada.tres")
const PASTA_CLIPES := "res://assets/epic_fight/res/"
const DURACAO_MINIMA := 0.04
## Encaixes do executor, na ordem do clique: 1º PARA_ESQUERDA, 2º PARA_DIREITA, 3º FRENTE; DE_CIMA = corrida.
const ORDEM_DA_CADEIA: Array[int] = [GolpeDirecional.Direcao.PARA_ESQUERDA, GolpeDirecional.Direcao.PARA_DIREITA, GolpeDirecional.Direcao.FRENTE, GolpeDirecional.Direcao.AUTO_4]
const JANELA_DA_CADEIA := 1.0

static var _cache := {}


static func existe(tipo: String) -> bool:
	return not _nomes_da_cadeia(tipo).is_empty()


## O estilo da categoria (`longsword`, `dagger`, `tachi`…) ou null se o mod local não está extraído / não há clipe.
## `velocidade` = velocidade de ataque do ITEM (espada longa 1,2; adaga 2,4); 0 = a do mod para a categoria (fator 1,0). O mod toca cada golpe a
## `velocidade do item ÷ basis_speed do golpe` (`EpicFightDados.velocidade_do_clipe`): as fases (preparo/ativo/recuperação) encolhem na mesma proporção.
static func criar(tipo: String, velocidade := 0.0, dual := false, variante := "") -> EstiloCorpoACorpo:
	var chave := "%s|%.3f|%s|%s" % [tipo, velocidade, dual, variante]
	if _cache.has(chave):
		return _cache[chave]
	var nomes := _nomes_da_cadeia(tipo, dual, variante)
	if nomes.is_empty():
		return null
	var estilo := BASE.duplicate(true) as EstiloCorpoACorpo
	estilo.id = StringName("ef_" + tipo + ("_dual" if dual else "") + ("_" + variante if variante != "" else ""))
	estilo.nome = "Epic Fight · " + tipo + (" (dual)" if dual else "")
	var modelo: GolpeDirecional = BASE.golpes[0]
	var golpes: Array[GolpeDirecional] = []
	# Os 3 primeiros encaixes são SEMPRE preenchidos (o validador exige as 3 direções do gesto); categoria com menos autos repete o último. O 4º auto (`AUTO_4`) só existe
	# se o mod tem 4 (a `sword`); o DE_CIMA do gesto repete o último auto, porque o mod não escolhe golpe por direção.
	for i in 3:
		golpes.append(_golpe(modelo, ORDEM_DA_CADEIA[i], nomes[mini(i, nomes.size() - 1)], velocidade, dual))
	golpes.append(_golpe(modelo, GolpeDirecional.Direcao.DE_CIMA, nomes[mini(2, nomes.size() - 1)], velocidade, dual))
	if nomes.size() >= 4:
		golpes.append(_golpe(modelo, GolpeDirecional.Direcao.AUTO_4, nomes[3], velocidade, dual))
	# Golpe de corrida (dash) e golpe de ar (airslash) do mod: encaixes extras escolhidos pelo estado do corpo.
	var corrida := _clipe_existente(tipo + ("_dual_dash" if dual else ("_sheath_dash" if variante == "sheath" else "_dash")))
	if corrida != "":
		golpes.append(_golpe(modelo, GolpeDirecional.Direcao.CORRIDA, corrida, velocidade, dual))
	# Habilidade inata da arma (tecla R): um golpe do mod no encaixe HABILIDADE; os do tipo "modo" (Liechtenauer) não têm golpe próprio.
	var hab := HabilidadesDeArma.para(tipo, dual)
	if not hab.is_empty() and hab.tipo == "golpe":
		var parte := 0
		for clipe_hab in hab.clipes:
			var nome_hab := str(clipe_hab).get_file()
			if _clipe_existente(nome_hab, "skill") == "" or parte >= 3:
				continue                                  # parte sem clipe extraído (ou além das 3 do encaixe): fica de fora
			golpes.append(_golpe(modelo, GolpeDirecional.Direcao.HABILIDADE + parte, nome_hab, velocidade, dual, "skill"))
			parte += 1
		var corrida_hab := str(hab.get("clipe_corrida", "")).get_file()
		if corrida_hab != "" and _clipe_existente(corrida_hab, "skill") != "":
			golpes.append(_golpe(modelo, GolpeDirecional.Direcao.HABILIDADE_3, corrida_hab, velocidade, dual, "skill"))     # versão correndo (Battojutsu dash)
	var no_ar := _primeiro_existente([tipo + "_sheath_airslash"] if variante == "sheath" else EpicFightDados.categoria(tipo).get("airslash", []))
	if no_ar != "":
		golpes.append(_golpe(modelo, GolpeDirecional.Direcao.NO_AR, no_ar, velocidade, dual))
	estilo.golpes = golpes
	_respeitar_invariantes(estilo)
	var cadeia: Array[int] = []
	for i in mini(nomes.size(), ORDEM_DA_CADEIA.size()):
		cadeia.append(ORDEM_DA_CADEIA[i])
	# a cadeia de cliques usa as 3 primeiras direções-base na ordem do mod (+ o 4º auto, se houver)
	estilo.sequencia_cliques = cadeia
	estilo.janela_sequencia = JANELA_DA_CADEIA
	_cache[chave] = estilo
	return estilo


## Nomes dos ataques do clique (sem variantes de habilidade nem dual) que têm clipe extraído, na ordem do mod.
static func _nomes_da_cadeia(tipo: String, dual := false, variante := "") -> Array[String]:
	var saida: Array[String] = []
	if not EpicFightDados.disponivel():
		return saida
	if variante == "sheath":
		# UCHIGATANA_SHEATHED (`EpicFightMovesets`): um auto só, sacando da bainha (`uchigatana_sheath_auto`)
		if _clipe_existente(tipo + "_sheath_auto") != "":
			saida.append(tipo + "_sheath_auto")
		return saida
	for n in EpicFightDados.categoria(tipo).get("combo", []):
		var nome := str(n)
		if nome.contains("liechtenauer") != (variante == "liechtenauer") or nome.contains("dual") != dual:
			continue                                   # a cadeia é a da empunhadura: só os `_dual_` no estilo dual, e só os comuns fora dele
		if _clipe_existente(nome) != "" and not EpicFightDados.ataque("combat/" + nome).is_empty():
			saida.append(nome)
	return saida


static func _primeiro_existente(nomes: Array) -> String:
	for n in nomes:
		var c := _clipe_existente(str(n))
		if c != "":
			return c
	return ""


static func _clipe_existente(nome: String, grupo := "combat") -> String:
	var caminho := PASTA_CLIPES + "ef_" + nome + ".res"
	return nome if ResourceLoader.exists(caminho) and not EpicFightDados.ataque(grupo + "/" + nome).is_empty() else ""


## O validador do estilo guarda invariantes do sistema (aparo/riposte e anti-combo infinito) que os tempos rápidos do mod violariam:
## o rebote e a quebra se ajustam ao ritmo do Epic Fight e o hitstun é limitado ao teto (recuperação + preparo mais rápido). DESVIO
## DECLARADO da fidelidade: o StunType do mod (SHORT 0,35 s) pode passar da recuperação de um golpe rápido; aqui nunca prende.
static func _respeitar_invariantes(estilo: EstiloCorpoACorpo) -> void:
	var preparo_min := INF
	var resto_max := 0.0
	for g in estilo.golpes:
		preparo_min = minf(preparo_min, g.preparo)
		resto_max = maxf(resto_max, g.ativo + g.recuperacao)
	estilo.duracao_rebatido = minf(estilo.duracao_rebatido, preparo_min * estilo.fator_de_riposte * 0.9)
	estilo.duracao_da_quebra = maxf(estilo.duracao_da_quebra, resto_max + preparo_min + EstiloCorpoACorpo.FOLGA_DA_QUEBRA + 0.05)
	for g in estilo.golpes:
		g.hitstun = minf(g.hitstun, g.recuperacao + preparo_min - 0.01)


static func _golpe(modelo: GolpeDirecional, direcao: int, nome: String, velocidade := 0.0, dual := false, grupo := "combat") -> GolpeDirecional:
	var g := modelo.duplicate(true) as GolpeDirecional
	var clipe := grupo + "/" + nome
	var f := EpicFightDados.fase(clipe)
	var fim := float(f.get("fim", 0.5))
	var contato := float(f.get("contato", fim * 0.6))
	var inicio_ativo := float(f.get("pre_atraso", f.get("antecipacao", 0.0)))
	inicio_ativo = clampf(inicio_ativo, DURACAO_MINIMA, maxf(contato - DURACAO_MINIMA, DURACAO_MINIMA))
	contato = maxf(contato, inicio_ativo + DURACAO_MINIMA)
	fim = maxf(fim, contato + DURACAO_MINIMA)
	g.id = StringName("ef_" + nome)
	if dual and str(EpicFightDados.ataque(clipe).get("junta", "")) == "toolL":
		g.efetor = &"EspadaPontaL"                # fase da mão esquerda: a varredura segue a SEGUNDA lâmina
		g.efetor_base = &"EspadaBaseL"
	g.nome = nome
	g.direcao = direcao as GolpeDirecional.Direcao
	g.clipe = PASTA_CLIPES + "ef_" + nome + ".res"
	var fator := EpicFightDados.velocidade_do_clipe(clipe, velocidade) if velocidade > 0.0 else 1.0
	fator = clampf(fator, 0.5, 2.5)
	g.velocidade_clipe = fator
	g.preparo = inicio_ativo / fator
	g.ativo = (contato - inicio_ativo) / fator
	g.recuperacao = (fim - contato) / fator
	var stun := EpicFightDados.stun_do_ataque(clipe)
	g.hitstun = float(EpicFightDados.atordoamento(stun)["hitstun"])
	g.pesado = stun in ["LONG", "KNOCKDOWN", "FALL", "NEUTRALIZE"]
	g.chaves = []
	return g
