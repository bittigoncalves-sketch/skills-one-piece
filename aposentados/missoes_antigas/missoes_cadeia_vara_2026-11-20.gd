extends RefCounted
# ============================================================================
#  MISSÕES DA ILHA (08/10/2026) — a tabela. O estado de cada uma mora no progresso
#  (`ProgressaoDoPersonagem.missoes`); quem oferece é um NPC com "?" amarela.
#
#  Pedido do dono: "adicionar um npc na vila com uma interrogação amarela acima da
#  cabeça que dá a missão de matar os bandidos". Escolha dele: matar 5 bandidos,
#  300 XP + 50 de ouro, uma vez.
#
#  CADEIA DO GUARDA (08/10/2026, Ilha dos Macacos — docs/ILHA_DOS_MACACOS_PLANO.md):
#  pedido do dono, "completar todas as missões do guarda da vila ... facilita a busca"
#  da ilha; escolhas dele: conseguir um pet, uma Akuma no Mi, vencer a corrida dos
#  caranguejos e pescar 10 peixes; o prêmio da última é a BÚSSOLA. Uma por vez, na
#  ordem da tabela (`depois_de`); só conta o que acontece depois de aceitar.
#
#  Missão nova = uma entrada aqui (nome, NPC que dá, alvo, quantos, recompensa, falas,
#  `tarefa`/`contador` para a janela) e o NPC na ficha de `NpcDaIlha` com `"missao"`.
#  O alvo é o EVENTO que conta (`ProgressaoDoPersonagem.contar_abate(alvo)`): "bandido"
#  abatido, "pet" novo, "fruta" conseguida, "corrida" vencida, "peixe" pescado.
#  10/11/2026: as missões de cortar madeira ("cortar_arvores", "madeira") e o machado saíram do jogo
#  (pedido do dono); a facção vem logo depois da ferraria e os bandidos depois da facção.
#  18/10/2026: "provisao" comprada no vendedor, contada POR ITEM (`itens`; o item vai
#  como `parte` em `contar_abate`).
#  `marcar` (10/10/2026, marcador de missão na tela): onde a tarefa se faz enquanto a
#  missão está aceita — `{"inimigos": comportamento}` marca cada inimigo vivo daquele
#  comportamento (os bandidos); `{"npc": tipo}` marca o NPC (domador, vendedor…). Pronta,
#  o marcador vai para o `npc` que paga (`src/ui/marcador_de_missao.gd`).
# ============================================================================

const Provisoes := preload("res://src/historia/tripulantes/provisoes.gd")

const TABELA := {
	"vara_inicial": {
		"nome": "Uma vara para começar",
		"npc": "npc_pescador",
		"alvo": "vara_inicial",
		"meta": 1,
		"xp": 0,
		"ouro": 0,
		"tarefa": "Pegue uma vara de pesca com o pescador",
		"contador": "Vara recebida",
		"marcar": {
			"npc": "npc_pescador"
		},
		"oferta": "O pescador do porto tem uma vara para você.",
		"andamento": "Fale com o pescador e pegue a vara gratuitamente.",
		"pronta": "Agora você pode pescar. Não há recompensa por esta missão.",
		"concluida": "Equipe a vara em N → PESCA."
	},
	"peixe_raro": {
		"nome": "Um peixe raro",
		"npc": "npc_pescador",
		"depois_de": "vara_inicial",
		"alvo": "peixe_raro",
		"meta": 1,
		"xp": 0,
		"ouro": 20,
		"tarefa": "Pesque um peixe raro e volte ao pescador",
		"contador": "Peixes raros",
		"marcar": {
			"npc": "npc_pescador"
		},
		"oferta": "Pesque um peixe raro. Pagarei 20 moedas.",
		"andamento": "Atum, espadarte e outros peixes raros contam. Peixes comuns não.",
		"pronta": "Bela pescaria! Aqui estão suas 20 moedas.",
		"concluida": "Procure o ferreiro para aprender a fazer uma ferramenta."
	},
	"ferraria": {
		"nome": "Aprendiz de ferreiro",
		"npc": "npc_ferreiro",
		"depois_de": "peixe_raro",
		"alvo": "ferraria",
		"meta": 1,
		"xp": 0,
		"ouro": 0,
		"tarefa": "Acenda a fornalha, martele a lâmina e esfrie no tempo certo",
		"contador": "Ferramentas forjadas",
		"marcar": {
			"npc": "npc_ferreiro"
		},
		"oferta": "Vou ensinar a forjar uma lâmina: fornalha, martelo e o tempo certo de esfriar.",
		"andamento": "Complete as três etapas de ferraria.",
		"pronta": "Bem forjado! Agora procure o guarda da vila para escolher seu caminho.",
		"concluida": "Você já sabe forjar."
	},
	"faccao_inicial": {
		"nome": "Escolha seu caminho",
		"npc": "npc_missao_bandidos",
		"depois_de": "ferraria",
		"alvo": "faccao_inicial",
		"meta": 1,
		"xp": 0,
		"ouro": 0,
		"alimentos": 60,
		"tarefa": "Escolha Pirata ou Marinheiro com o guarda",
		"contador": "Facção escolhida",
		"marcar": {
			"npc": "npc_missao_bandidos"
		},
		"oferta": "Pirata ou Marinheiro? Você receberá 60 pães para a viagem.",
		"andamento": "Escolha seu caminho.",
		"pronta": "Aqui estão os 60 pães para sua viagem.",
		"concluida": "Sua jornada começou."
	},

	"bandidos": {
		"nome": "Bandidos no campo",
		"npc": "npc_missao_bandidos",
		"depois_de": "faccao_inicial",
		"alvo": "bandido",
		"alvo_plural": "bandidos",
		"meta": 5,
		"xp": 300,
		"ouro": 50,
		"oferta": "Bandidos montaram acampamento no campo aberto. Derrote 5 deles e eu te pago.",
		"andamento": "Ainda há bandidos lá fora. Volte quando tiver derrotado 5.",
		"pronta": "Você conseguiu! Tome a sua recompensa.",
		"concluida": "A vila está mais tranquila graças a você.",
		"tarefa": "Derrote 5 bandidos",
		"contador": "Bandidos derrotados",
		"marcar": {"inimigos": "bandido"},
	},
	"pet": {
		"nome": "Um companheiro de viagem",
		"npc": "npc_missao_bandidos",
		"depois_de": "bandidos",
		"alvo": "pet",
		"meta": 1,
		"xp": 150,
		"ouro": 20,
		"oferta": "Quem vai para o mar precisa de companhia. Dome um bicho ou compre um no domador.",
		"andamento": "Ainda sem companheiro? Dome um bicho com uma fruta na mão ou fale com o domador.",
		"pronta": "Belo companheiro! Tome, para a viagem.",
		"concluida": "Cuide bem do seu companheiro.",
		"tarefa": "Consiga um pet novo",
		"contador": "Pets novos",
		"marcar": {"npc": "npc_domador"},
	},
	"fruta": {
		"nome": "O poder de uma Akuma no Mi",
		"npc": "npc_missao_bandidos",
		"depois_de": "pet",
		"alvo": "fruta",
		"meta": 1,
		"xp": 200,
		"ouro": 30,
		"oferta": "Lá fora há gente mais forte que bandido. Consiga uma Akuma no Mi; o vendedor de frutas tem.",
		"andamento": "Ainda sem Akuma no Mi? O vendedor de frutas da vila vende.",
		"pronta": "Agora sim você tem poder. Tome.",
		"concluida": "Use esse poder com cabeça.",
		"tarefa": "Consiga uma Akuma no Mi",
		"contador": "Akuma no Mi",
		"marcar": {"npc": "npc_vendedor_frutas"},
	},
	"corrida": {
		"nome": "Vencer a corrida dos caranguejos",
		"npc": "npc_missao_bandidos",
		"depois_de": "fruta",
		"alvo": "corrida",
		"meta": 1,
		"xp": 250,
		"ouro": 40,
		"oferta": "No mar não dá para hesitar. Vença a corrida dos caranguejos: chegue em primeiro.",
		"andamento": "Ainda não venceu? Fale com o organizador da corrida e chegue em primeiro.",
		"pronta": "Primeiro lugar! Rápido assim, o mar não te assusta.",
		"concluida": "Ainda falam da sua corrida na vila.",
		"tarefa": "Vença a corrida dos caranguejos (1º lugar)",
		"contador": "Vitórias",
		"marcar": {"npc": "npc_corrida"},
	},
	# 18/10/2026: era "peixes" (pescar 10). Pedido do dono: o vendedor de provisões
	# entra na missão; escolhas dele: comprar 5 pães + 5 águas, o jogador paga.
	# `itens` = metas por item (a soma é a `meta`); conta só a COMPRA no vendedor.
	"provisoes": {
		"nome": "Provisões para a viagem",
		"npc": "npc_missao_bandidos",
		"depois_de": "corrida",
		"alvo": "provisao",
		"itens": {"pao": 5, "agua_potavel": 5},
		"meta": 10,
		"xp": 200,
		"ouro": 30,
		"premio": "bussola",
		"oferta": "Última coisa: provisões. Compre 5 pães e 5 águas com o vendedor de provisões e eu te dou algo que vai te levar longe.",
		"andamento": "Faltam provisões. O vendedor de provisões fica nas barracas da vila.",
		"pronta": "Provisões feitas. Tome esta bússola: ela aponta para a Ilha dos Macacos, a leste.",
		"concluida": "Siga a bússola. A Ilha dos Macacos fica a leste, depois do porto.",
		"tarefa": "Compre 5 pães e 5 águas com o vendedor de provisões",
		"contador": "Provisões compradas",
		"marcar": {"npc": "npc_comida"},
	},
}

## Estados (o que o progresso guarda é "aceita"/"entregue"; "disponivel" e "pronta" são
## calculados).
const DISPONIVEL := "disponivel"
const ACEITA := "aceita"
const PRONTA := "pronta"
const ENTREGUE := "entregue"


static func dados(id: String) -> Dictionary:
	return TABELA.get(id, {})


static func existe(id: String) -> bool:
	return TABELA.has(id)


## "7 / 10" — ou, com `itens`, um por item: "Pão 3 / 5 · Água potável 4 / 5".
static func contagem(id: String, prog: Object) -> String:
	var d := dados(id)
	if not d.has("itens"):
		return "%d / %d" % [prog.call("abates_da_missao", id), int(d.get("meta", 1))]
	var feitos: Dictionary = (prog.get("missoes") as Dictionary).get(id, {}).get("itens", {})
	var partes: PackedStringArray = []
	for item in d.itens:
		var nome := str(Provisoes.ITENS.get(item, {}).get("nome", item))
		partes.append("%s %d / %d" % [nome, int(feitos.get(item, 0)), int(d.itens[item])])
	return " · ".join(partes)


## A missão da vez do NPC `npc` (tipo da ficha): a primeira da cadeia dele ainda não
## entregue. "" = todas entregues. `prog` = o progresso (`estado_da_missao`).
static func atual_do_npc(npc: String, prog: Object) -> String:
	for id in TABELA:
		if TABELA[id]["npc"] == npc and prog.call("estado_da_missao", id) != ENTREGUE:
			return id
	return ""


## A última missão da cadeia do NPC (para mostrar "Concluída" no fim).
static func ultima_do_npc(npc: String) -> String:
	var ultima := ""
	for id in TABELA:
		if TABELA[id]["npc"] == npc:
			ultima = id
	return ultima


## Alguma missão aceita ou pronta (cumprida, mas ainda sem entregar)?
static func ha_em_andamento(prog: Object) -> bool:
	for id in TABELA:
		var e: String = prog.call("estado_da_missao", id)
		if e == ACEITA or e == PRONTA:
			return true
	return false


## As missões que o jogador já pode COMEÇAR: ainda não aceitas e com a anterior da
## cadeia entregue (17/10/2026: o marcador e o rastreador apontam o NPC quando uma
## missão acaba). Vazio enquanto houver uma em andamento — uma por vez.
static func proximas(prog: Object) -> Array[String]:
	var saida: Array[String] = []
	if ha_em_andamento(prog):
		return saida
	for id in TABELA:
		if prog.call("estado_da_missao", id) != DISPONIVEL:
			continue
		var antes := str(TABELA[id].get("depois_de", ""))
		if antes.is_empty() or prog.call("estado_da_missao", antes) == ENTREGUE:
			saida.append(id)
	return saida
