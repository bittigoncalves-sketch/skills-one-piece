extends RefCounted
## Fonte única dos consumíveis e números de sobrevivência. Valores de comida/preço
## e fome por dia são balanceamento inicial; capacidades e sede vieram do pedido.
const FOME_MAX := 200.0
const SEDE_MAX := 300.0
const DIAS_SEM_AGUA := 4.0
const FOME_POR_DIA := 50.0
const MAX_MEMBROS := 16
const GASTO_DIRETO_MAX_DIA := 100
const CARGOS := ["Cozinheiro", "Construtor", "Médico", "Estoquista", "Comandante da divisão", "Combatente"]
## ALIMENTOS (18/11/2026, pedido do dono: "adicionar mais tipos de alimentos e um NPC que os vende"). Cada item tem `tipo` (comida vai na barra "comida", bebida na
## barra "agua"), `fome`/`sede` que devolve e `preco` em moedas. A ORDEM de `COMIDAS_NA_BARRA`/`BEBIDAS_NA_BARRA` é a de consumo: do mais fraco ao mais forte,
## para o clique na barra gastar primeiro o que menos desperdiça. Alimento novo = uma linha aqui + o id numa dessas listas e em `VENDIDOS`.
const ITENS := {
	"pao": {"nome": "Pão", "tipo": "comida", "fome": 25.0, "sede": 0.0, "preco": 1},
	"maca": {"nome": "Maçã", "tipo": "comida", "fome": 15.0, "sede": 5.0, "preco": 1},
	"peixe_assado": {"nome": "Peixe assado", "tipo": "comida", "fome": 45.0, "sede": 0.0, "preco": 2},
	"sopa_de_peixe": {"nome": "Sopa de peixe", "tipo": "comida", "fome": 60.0, "sede": 20.0, "preco": 3},
	"refeicao": {"nome": "Refeição", "tipo": "comida", "fome": 75.0, "sede": 0.0, "preco": 3},
	"carne_assada": {"nome": "Carne assada", "tipo": "comida", "fome": 100.0, "sede": 0.0, "preco": 5},
	"agua_potavel": {"nome": "Água potável", "tipo": "bebida", "fome": 0.0, "sede": 75.0, "preco": 1},
	"leite": {"nome": "Leite", "tipo": "bebida", "fome": 10.0, "sede": 50.0, "preco": 2},
	"suco_de_laranja": {"nome": "Suco de laranja", "tipo": "bebida", "fome": 5.0, "sede": 90.0, "preco": 3},
}
const COMIDAS_NA_BARRA := ["maca", "pao", "peixe_assado", "sopa_de_peixe", "refeicao", "carne_assada"]
const BEBIDAS_NA_BARRA := ["agua_potavel", "leite", "suco_de_laranja"]
## O que o Vendedor de provisões (`loja_de_comida.gd`) tem na banca. A refeição é a de sempre (estoque antigo, e agora também à venda).
const VENDIDOS := ["pao", "maca", "peixe_assado", "sopa_de_peixe", "refeicao", "carne_assada", "agua_potavel", "leite", "suco_de_laranja"]

static func estado(prog: ProgressaoDoPersonagem) -> Dictionary:
	if not prog.sistemas.has("sobrevivencia"):
		prog.sistemas["sobrevivencia"] = {}
	var d: Dictionary = prog.sistemas["sobrevivencia"]
	d["fome"] = clampf(float(d.get("fome", FOME_MAX)), 0, FOME_MAX)
	d["sede"] = clampf(float(d.get("sede", SEDE_MAX)), 0, SEDE_MAX)
	if not d.get("estoque") is Dictionary: d["estoque"] = {}
	if not d.get("membros") is Dictionary: d["membros"] = {}
	if not d.get("vagas") is Array or d["vagas"].size() != CARGOS.size():
		d["vagas"] = ["", "", "", "", "", ""]
	d["reserva"] = maxi(0, int(d.get("reserva", 0)))
	d["dias"] = maxf(0, float(d.get("dias", 0)))
	d["pedido_dia"] = int(d.get("pedido_dia", -1))
	d["alinhamento"] = str(d.get("alinhamento", "neutro"))
	if not d.get("historico_membros") is Dictionary: d["historico_membros"] = {}
	if int(d.get("dia_do_gasto", -1)) != int(d.dias):
		d["dia_do_gasto"] = int(d.dias)
		d["gasto_direto"] = 0
	for id in d.membros.keys():
		if not d.membros[id] is Dictionary:
			d.membros.erase(id)
			continue
		var m: Dictionary = d.membros[id]
		m["vida_max"] = maxf(1, float(m.get("vida_max", 100)))
		m["vida"] = clampf(float(m.get("vida", m.vida_max)), 0, float(m.vida_max))
		m.erase("fome") # Migração: companheiros não precisam mais de comida.
		m["morto"] = bool(m.get("morto", false))
	var vistos := {}
	for i in d.vagas.size():
		var id := str(d.vagas[i])
		if not d.membros.has(id) or vistos.has(id): d.vagas[i] = ""
		else: vistos[id] = true
	return d

static func guardar(prog: ProgressaoDoPersonagem, id: String, quantidade: int) -> bool:
	if not ITENS.has(id) or quantidade <= 0: return false
	var d := estado(prog)
	d.estoque[id] = maxi(0, int(d.estoque.get(id, 0))) + quantidade
	return true

static func comprar(prog: ProgressaoDoPersonagem, id: String, quantidade := 1) -> bool:
	if not ITENS.has(id) or quantidade < 1 or quantidade > 999: return false
	var custo := int(ITENS[id].preco) * quantidade
	if prog.ouro < custo: return false
	prog.ouro -= custo
	guardar(prog, id, quantidade)
	# Missão "Provisões para a viagem": a compra conta por item (um `mudou` só).
	if prog.contar_abate("provisao", quantidade, id).is_empty():
		prog.mudou.emit()
	return true

static func consumir(prog: ProgressaoDoPersonagem, id: String, membro := "") -> bool:
	if not ITENS.has(id) or not membro.is_empty(): return false
	var d := estado(prog)
	if int(d.estoque.get(id, 0)) <= 0: return false
	var alvo: Dictionary = d if membro.is_empty() else d.membros.get(membro, {})
	if alvo.is_empty() or bool(alvo.get("morto", false)): return false
	var comida: Dictionary = ITENS[id]
	# Só consome se ALGO do que o item devolve ainda faz falta (a maçã mata fome e um pouco de sede; basta uma das duas estar baixa).
	var serve_fome := float(comida.fome) > 0 and float(alvo.get("fome", FOME_MAX)) < FOME_MAX
	var serve_sede := float(comida.sede) > 0 and membro.is_empty() and float(d.sede) < SEDE_MAX
	if not (serve_fome or serve_sede): return false
	d.estoque[id] = int(d.estoque[id]) - 1
	alvo["fome"] = minf(FOME_MAX, float(alvo.get("fome", FOME_MAX)) + float(comida.fome))
	if membro.is_empty(): d.sede = minf(SEDE_MAX, float(d.sede) + float(comida.sede))
	prog.mudou.emit()
	return true

static func avancar(prog: ProgressaoDoPersonagem, dias: float) -> bool:
	var d := estado(prog)
	dias = maxf(0, dias)
	d.dias = float(d.dias) + dias
	d.fome = maxf(0, float(d.fome) - FOME_POR_DIA * dias)
	d.sede = maxf(0, float(d.sede) - SEDE_MAX / DIAS_SEM_AGUA * dias)
	# Epsilon impede que 4 dias repartidos em frames deixem uma fração imortal.
	if float(d.sede) < 0.000001: d.sede = 0.0
	if float(d.fome) < 0.000001: d.fome = 0.0
	return float(d.sede) <= 0

## COMER LEVA TEMPO (20/11/2026, pedido do dono): comida é uma AÇÃO de 2 a 4,5 s (proporcional ao tamanho: pão ≈ 2,1 s, carne assada 4 s). O item é RESERVADO ao começar,
## a fome entra ao TERMINAR (se algo interromper, o item volta ao estoque). Água/bebida continua instantânea no clique. A regeneração acelerada vem em `bonus_de_regeneracao`.
const TEMPO_DE_COMER_BASE := 1.5
const TEMPO_DE_COMER_MIN := 2.0
const TEMPO_DE_COMER_MAX := 4.5
const REGEN_DA_COMIDA_FATOR := 3.0         # vida e energia regeneram 3× (o bônus de kill é 4×) enquanto dura
const REGEN_DA_COMIDA_BASE_S := 10.0
## ÁGUA (22/11/2026, pedido do dono: "regeneração de energia dobrada ao beber água"): qualquer bebida dobra a regeneração de ENERGIA (a vida não) por alguns segundos.
## Duração = base + sede devolvida × `REGEN_DA_AGUA_POR_SEDE` (água potável 25 s, leite 20 s, suco 28 s). GATILHO: o dono não deu a duração — ajustar aqui.
const REGEN_ENERGIA_DA_AGUA_FATOR := 2.0
const REGEN_DA_AGUA_BASE_S := 10.0
const REGEN_DA_AGUA_POR_SEDE := 0.2
const REGEN_DA_COMIDA_POR_FOME := 0.3      # +0,3 s de bônus por ponto de fome do item (pão 17,5 s, carne assada 40 s)

static func tempo_de_comer(id: String) -> float:
	if not ITENS.has(id): return TEMPO_DE_COMER_MIN
	return clampf(TEMPO_DE_COMER_BASE + float(ITENS[id].fome) / 40.0, TEMPO_DE_COMER_MIN, TEMPO_DE_COMER_MAX)

## {"fator": ×, "duracao": s} da regeneração acelerada que a refeição dá; fator 1 e duração 0 se o item não é comida.
static func bonus_de_regeneracao(id: String) -> Dictionary:
	if not ITENS.has(id) or str(ITENS[id].tipo) != "comida": return {"fator": 1.0, "duracao": 0.0}
	return {"fator": REGEN_DA_COMIDA_FATOR, "duracao": REGEN_DA_COMIDA_BASE_S + float(ITENS[id].fome) * REGEN_DA_COMIDA_POR_FOME}

## {"fator": ×, "duracao": s} da regeneração de ENERGIA que a bebida dá; fator 1 e duração 0 se o item não é bebida.
static func bonus_de_energia_da_agua(id: String) -> Dictionary:
	if not ITENS.has(id) or str(ITENS[id].tipo) != "bebida": return {"fator": 1.0, "duracao": 0.0}
	return {"fator": REGEN_ENERGIA_DA_AGUA_FATOR, "duracao": REGEN_DA_AGUA_BASE_S + float(ITENS[id].sede) * REGEN_DA_AGUA_POR_SEDE}

## O que o clique na barra de comida comeria agora ("" = nada): o mesmo critério de `comer_da_barra` (do mais fraco ao mais forte).
static func proxima_comida(prog: ProgressaoDoPersonagem) -> String:
	var d := estado(prog)
	for id in COMIDAS_NA_BARRA:
		if int(d.estoque.get(id, 0)) > 0: return id
	return ""

## A bebida que o clique na barra de água beberia agora ("" = nada): o mesmo critério de `beber_da_barra_id`, sem gastar.
static func proxima_bebida(prog: ProgressaoDoPersonagem) -> String:
	var d := estado(prog)
	for id in BEBIDAS_NA_BARRA:
		if int(d.estoque.get(id, 0)) > 0: return id
	return ""

## Tira UMA unidade do estoque sem dar a fome (ela entra em `aplicar_refeicao`, ao fim de comer). `devolver` desfaz se a refeição for interrompida.
static func reservar(prog: ProgressaoDoPersonagem, id: String) -> bool:
	var d := estado(prog)
	if not ITENS.has(id) or int(d.estoque.get(id, 0)) <= 0: return false
	d.estoque[id] = int(d.estoque[id]) - 1
	prog.mudou.emit()
	return true

static func devolver(prog: ProgressaoDoPersonagem, id: String) -> void:
	if ITENS.has(id): guardar(prog, id, 1); prog.mudou.emit()

## A refeição terminou: a comida (e a bebida embutida, como a sopa) fazem efeito.
static func aplicar_refeicao(prog: ProgressaoDoPersonagem, id: String) -> void:
	if not ITENS.has(id): return
	var d := estado(prog)
	d.fome = minf(FOME_MAX, float(d.fome) + float(ITENS[id].fome))
	d.sede = minf(SEDE_MAX, float(d.sede) + float(ITENS[id].sede))
	prog.mudou.emit()

static func quantidade_comida(prog: ProgressaoDoPersonagem) -> int:
	return _total_de(prog, COMIDAS_NA_BARRA)

## Um clique consome exatamente uma unidade, inclusive se o jogador está saciado.
static func comer_da_barra(prog: ProgressaoDoPersonagem) -> bool:
	if prog.item_em_uso() != "comida": return false
	return _usar_da_barra(prog, COMIDAS_NA_BARRA)

static func quantidade_agua(prog: ProgressaoDoPersonagem) -> int:
	return _total_de(prog, BEBIDAS_NA_BARRA)

## Um clique bebe exatamente uma unidade (como o pão, mesmo sem sede).
static func beber_da_barra(prog: ProgressaoDoPersonagem) -> bool:
	return not beber_da_barra_id(prog).is_empty()

## O mesmo, devolvendo O QUE bebeu ("" = nada): a HUD precisa do id para dar a regeneração de energia.
static func beber_da_barra_id(prog: ProgressaoDoPersonagem) -> String:
	if prog.item_em_uso() != "agua": return ""
	return _usar_da_barra_id(prog, BEBIDAS_NA_BARRA)

static func _total_de(prog: ProgressaoDoPersonagem, ids: Array) -> int:
	var estoque: Dictionary = estado(prog).estoque
	var total := 0
	for id in ids: total += maxi(0, int(estoque.get(id, 0)))
	return total

static func _usar_da_barra(prog: ProgressaoDoPersonagem, ids: Array) -> bool:
	return not _usar_da_barra_id(prog, ids).is_empty()

static func _usar_da_barra_id(prog: ProgressaoDoPersonagem, ids: Array) -> String:
	var d := estado(prog)
	for id in ids:
		if int(d.estoque.get(id, 0)) <= 0: continue
		d.estoque[id] = int(d.estoque[id]) - 1
		d.fome = minf(FOME_MAX, float(d.fome) + float(ITENS[id].fome))
		d.sede = minf(SEDE_MAX, float(d.sede) + float(ITENS[id].sede))
		prog.mudou.emit()
		return str(id)
	return ""

static func adicionar(prog: ProgressaoDoPersonagem, id: String) -> bool:
	var d := estado(prog)
	if d.membros.has(id) or d.membros.size() >= MAX_MEMBROS or Tripulacao.aliado(prog, null, id).is_empty(): return false
	if bool(d.historico_membros.get(id, {}).get("morto", false)): return false
	d.membros[id] = d.historico_membros.get(id, {"vida": 100.0, "vida_max": 100.0, "morto": false}).duplicate(true)
	d.membros[id].erase("fome")
	prog.mudou.emit()
	return true

static func atribuir(prog: ProgressaoDoPersonagem, id: String, vaga: int) -> bool:
	var d := estado(prog)
	if vaga < 0 or vaga >= CARGOS.size() or not d.membros.has(id) or bool(d.membros[id].get("morto", false)): return false
	for i in d.vagas.size():
		if d.vagas[i] == id: d.vagas[i] = ""
	d.vagas[vaga] = id
	prog.mudou.emit()
	return true

static func tem_cargo(prog: ProgressaoDoPersonagem, cargo: int) -> bool:
	var d := estado(prog)
	var id := str(d.vagas[cargo])
	return d.membros.has(id) and not bool(d.membros[id].get("morto", false)) and float(d.membros[id].get("vida", 0)) > 0

static func depositar(prog: ProgressaoDoPersonagem, quantia: int) -> bool:
	if quantia <= 0 or prog.ouro < quantia: return false
	var d := estado(prog)
	prog.ouro -= quantia
	d.reserva = int(d.reserva) + quantia
	prog.mudou.emit()
	return true

static func pagar(prog: ProgressaoDoPersonagem, quantia: int) -> bool:
	if quantia < 0: return false
	var d := estado(prog)
	# Com estoquista, só o orçamento autorizado é usado. Sem ele, cargos usam o ouro.
	if tem_cargo(prog, 3):
		if int(d.reserva) < quantia: return false
		d.reserva = int(d.reserva) - quantia
	else:
		if prog.ouro < quantia or int(d.gasto_direto) + quantia > GASTO_DIRETO_MAX_DIA: return false
		prog.ouro -= quantia
		d.gasto_direto = int(d.gasto_direto) + quantia
	return true
