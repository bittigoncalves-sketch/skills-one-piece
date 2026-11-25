extends RefCounted
# ============================================================================
#  MISSÕES DA ILHA (08/10/2026; reduzida ao TREINO em 20/11/2026) — a tabela. O estado de cada uma mora no progresso
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

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")

## `ilha`: a missão só é OFERECIDA (rastreador "Próxima" e "?" do NPC) enquanto o jogador está nessa ilha; sem a chave vale em qualquer lugar.
## `entrega_vara`: aceitar a missão entrega a vara de pesca já na HOTBAR (Ilha dos Macacos, 22/11/2026).
const TABELA := {
	# 20/11/2026 (pedido do dono): a cadeia que começava na vara de pesca (vara → peixe raro → ferraria → facção → bandidos → pet/fruta/corrida/10 peixes →
	# bússola) SAIU; o treino é a primeira — e hoje a única — missão. A tabela antiga está em `aposentados/missoes_antigas/`. Missão nova = outra entrada aqui,
	# `depois_de: "treino"` se vier depois dele.
	# O treino é repetível (até o nível 3): a MISSÃO só é entregue uma vez, na primeira sessão; o XP de CADA sessão vem de `RegrasDoTreino` (500 por treino),
	# não da tabela (por isso `xp` = 0 aqui).
	"treino": {
		"nome": "Primeiro treino",
		"npc": "npc_treinador",
		"alvo": "treino",
		"meta": 1,
		"xp": 0,
		"ouro": 0,
		"tarefa": "Treine com o instrutor no campo de treino",
		"contador": "Treinos feitos",
		"marcar": {
			"npc": "npc_treinador"
		},
		"oferta": "Fale com o instrutor no campo de treino. Cada treino rende até 500 de XP, conforme os acertos.",
		"andamento": "Fale com o instrutor e acerte as teclas no tempo para socar o boneco.",
		"pronta": "Bom trabalho! Seu primeiro treino está completo.",
		"concluida": "Treine de novo com o instrutor enquanto o campo ainda te ensinar algo."
	},
	# Desafio do Buggy (21/11/2026, docs/DESAFIO_DO_BUGGY_PLANO.md). `por_evento`: NÃO é oferecida por NPC com "?" — nasce de um evento (`RegrasDoDesafioBuggy`).
	# `nivel_minimo`: `aceitar_missao` recusa abaixo dele (sem uso hoje: a luta do Buggy ficou no nível 3 por `luta_disponivel`).
	"desafio_dos_copos": {
		"nome": "O desafio do Buggy",
		"npc": "npc_buggy",
		"alvo": "copos",
		"meta": 1,
		"xp": 4000,
		"ouro": 0,
		"por_evento": true,
		"depois_de": "treino",
		"tarefa": "Vá ao cais e aceite o desafio dos copos do Buggy",
		"contador": "Copos",
		"oferta": "O Buggy chegou ao cais.",
		"andamento": "Descubra em qual copo está a pedra. Você só tem uma tentativa.",
		"pronta": "Você achou a pedra!",
		"concluida": "O Buggy cumpriu a palavra: você venceu o jogo dos copos."
	},
	# Resgate do baú (21/11/2026, 3ª missão; `RegrasDoResgateDoBau`): o Barba Negra pede o "Baú misterioso" que um MÍMICO guarda; a bússola aponta o baú. Vem depois do desafio do Buggy.
	"resgate_do_bau": {
		"nome": "Resgate o baú",
		"npc": "npc_barba_negra",
		"alvo": "bau_misterioso",
		"meta": 1,
		"xp": 700,
		"ouro": 20,
		"fruta": "ushi_ushi_giraffe",       # recompensa EXTRA (21/11/2026): o Barba Negra entrega a Ushi Ushi no Mi (Modelo Girafa); vai para N › FRUTAS (`receber_fruta`)
		"depois_de": "desafio_dos_copos",
		"tarefa": "Ache o baú com a bússola, acerte o mímico e pegue o Baú misterioso",
		"contador": "Baú misterioso",
		"oferta": "Gwahaha! Um baú meu sumiu. Dizem que virou mímico. Siga a bússola e traga o que ele guarda!",
		"andamento": "O baú é um mímico: acerte um ataque nele, pegue o Baú misterioso e volte aqui.",
		"pronta": "Gwahaha! É esse mesmo! O Baú misterioso está comigo, sua recompensa é sua.",
		"concluida": "O baú voltou para mim. Obrigado, pirata!"
	},
	# O barril da Alvida (22/11/2026, 5ª missão; `RegrasDaAlvida`, src/historia/alvida/): o vendedor de navios dá um barril a quem VENCEU OS COPOS do Buggy; o jogador é pescado pelo navio da Alvida e duela
	# com ela no pedra-papel-tesoura (7 vidas). Vitória = 1000 moedas + 8000 XP (esta tabela é a ÚNICA fonte do prêmio). `por_evento`: nasce depois do baú, não de um "?".
	"alvida_no_navio": {
		"nome": "O barril da Alvida",
		"npc": "npc_vendedor_barcos",
		"alvo": "alvida",
		"meta": 1,
		"xp": 8000,
		"ouro": 1000,
		"por_evento": true,
		"depois_de": "resgate_do_bau",
		"marcar": {
			"npc": "npc_vendedor_barcos"
		},
		"tarefa": "Fale com o vendedor de navios (a bússola aponta) e vença a Alvida no pedra, papel e tesoura",
		"contador": "Alvida vencida",
		"oferta": "O vendedor de navios tem uma proposta para quem venceu o Buggy.",
		"andamento": "Vença a Alvida no navio dela: sete acertos antes que ela dê os sete dela.",
		"pronta": "A Alvida foi derrotada!",
		"concluida": "Você venceu a Alvida e voltou à Ilha dos Macacos."
	},
	# ===== Ilha dos Macacos v2 (22/11/2026, docs/ILHA_DOS_MACACOS_V2_PLANO.md) =====
	# Principal: começa SOZINHA quando o jogador pisa na ilha (`ModoHistoria._garantir_missao_da_ilha`) e se entrega sozinha ao derrubar o Gorila-rei.
	# `paralela`: não conta como "em andamento" (não trava o marcador das outras, que são de NPC e seguem a regra de uma por vez).
	"rei_da_selva": {
		"icone": "res://assets/textures/ilha_macacos/icone_coroa_gorila.png",
		"nome": "O Rei da Selva",
		"npc": "npc_mestre_geppo",
		"alvo": "gorila_rei",
		"meta": 1,
		"xp": 6000,
		"ouro": 800,
		"por_evento": true,
		"paralela": true,
		"marcar": {"alvos_de_golpe": "gorila_rei"},
		"tarefa": "Derrote o Gorila-rei no Trono (estrada a nordeste da vila)",
		"contador": "Gorila-rei derrotado",
		"oferta": "Um gorila gigante tomou a ilha.",
		"andamento": "Siga a estrada a nordeste da vila até o Trono. Todo golpe dele avisa em VERMELHO no chão: saia da área antes que ela feche.",
		"pronta": "O Gorila-rei caiu!",
		"concluida": "A ilha é dos macacos livres outra vez, graças a você."
	},
	"cesto_de_bananas": {
		"ilha": Ilhas.MACACOS,
		"icone": "res://assets/textures/ilha_macacos/missao_cesto_bananas.png",
		"nome": "Cesto de bananas",
		"npc": "npc_macaco_cozinheira",
		"alvo": "banana",
		"meta": 6,
		"xp": 500,
		"ouro": 100,
		"tarefa": "Colha 6 cachos de banana no Bananal (E perto de cada cacho)",
		"contador": "Cachos colhidos",
		"marcar": {"npc": "npc_macaco_cozinheira"},
		"oferta": "O Rei levou nossa comida! Colha 6 cachos de banana no Bananal, a noroeste da vila.",
		"andamento": "Os cachos ficam no Bananal, no fim da estrada a noroeste. Pegue com E.",
		"pronta": "Que cesto cheio! A vila vai comer hoje.",
		"concluida": "Obrigada pelas bananas, forasteiro."
	},
	"pesca_do_cais": {
		"ilha": Ilhas.MACACOS,
		"icone": "res://assets/textures/ilha_macacos/missao_pesca_cais.png",
		"nome": "Pesca do cais",
		"npc": "npc_macaco_pescador",
		"alvo": "peixe",
		"meta": 3,
		"xp": 450,
		"ouro": 80,
		"entrega_vara": true,
		"tarefa": "Pesque 3 peixes (equipado com a vara, perto do cais)",
		"contador": "Peixes pescados",
		"marcar": {"npc": "npc_macaco_pescador"},
		"oferta": "Os macacos não pescam mais com o Rei por perto. Pesque 3 peixes no cais para a vila.",
		"andamento": "A vara já está na sua barra: equipe-a, mire a água perto do cais e lance. Só conta peixe pescado depois de aceitar.",
		"pronta": "Peixe fresco! Você pesca bem.",
		"concluida": "O cais está mais animado com você por aqui."
	},
	"os_saqueadores": {
		"ilha": Ilhas.MACACOS,
		"icone": "res://assets/textures/ilha_macacos/missao_saqueadores.png",
		"nome": "Os saqueadores",
		"npc": "npc_macaco_vigia",
		"alvo": "macaco",
		"meta": 8,
		"xp": 800,
		"ouro": 150,
		"marcar": {"alvos_de_golpe": "macaco_humanoide"},
		"tarefa": "Derrote 8 macacos saqueadores do Rei na floresta",
		"contador": "Saqueadores derrotados",
		"oferta": "Do alto da torre eu os vejo: os macacos do Rei roubam a floresta. Derrote 8 deles.",
		"andamento": "Os bandos rondam a floresta nos quatro cantos da ilha.",
		"pronta": "Os bandos recuaram. Bom trabalho!",
		"concluida": "A floresta respira melhor."
	},
	"fruto_dourado": {
		"ilha": Ilhas.MACACOS,
		"icone": "res://assets/textures/ilha_macacos/missao_fruto_dourado.png",
		"nome": "O fruto dourado",
		"npc": "npc_macaco_vigia",
		"alvo": "fruto_dourado",
		"meta": 1,
		"xp": 1500,
		"ouro": 300,
		"depois_de": "os_saqueadores",
		"tarefa": "Suba com o Geppo pelas plataformas da árvore imensa e colha o fruto dourado (E)",
		"contador": "Fruto dourado",
		"oferta": "Dizem que há um fruto dourado no topo da árvore imensa. Só quem usa o Geppo chega lá.",
		"andamento": "As plataformas em espiral levam ao topo. Aprenda o Geppo com o Mestre, na vila.",
		"pronta": "Ele brilha mesmo! O baú do topo também é seu.",
		"concluida": "O fruto dourado voltou para a vila."
	},
	"os_quatro_totens": {
		"ilha": Ilhas.MACACOS,
		"icone": "res://assets/textures/ilha_macacos/missao_quatro_totens.png",
		"nome": "Os quatro totens",
		"npc": "npc_macaco_curandeiro",
		"alvo": "totem",
		"meta": 4,
		"xp": 700,
		"ouro": 120,
		"tarefa": "Desperte os 4 totens no sítio a sudeste (E perto de cada um)",
		"contador": "Totens despertos",
		"marcar": {"npc": "npc_macaco_curandeiro"},
		"oferta": "Os totens do sudeste protegem a ilha, mas dormem. Desperte os quatro.",
		"andamento": "Os quatro totens estão no sítio ao fim da estrada sudeste. Toque cada um com E.",
		"pronta": "Os totens brilham de novo! Eles vão nos proteger.",
		"concluida": "Os totens velam pela ilha outra vez."
	},
	"defender_a_vila": {
		"nome": "Defender a vila",
		"npc": "npc_buggy",
		"alvo": "buggy",
		"meta": 1,
		"xp": 6500,
		"ouro": 350,
		"por_evento": true,
		"tarefa": "Treine com o instrutor até o nível 3 e desafie o Buggy no ringue do cais (11 acertos antes de perder as 11 vidas)",
		"contador": "Buggy derrotado",
		"oferta": "Treine até o nível 3 e volte para enfrentar o Buggy.",
		"andamento": "Fale com o instrutor e treine até o nível 3 (a bússola aponta ele). Depois volte ao cais e fale com o Buggy (E): a luta é num ringue; Z/X/C atacam, F defende.",
		"pronta": "O Buggy foi derrotado. A vila está a salvo.",
		"concluida": "A vila foi poupada."
	},
}

const DISPONIVEL := "disponivel"
const ACEITA := "aceita"
const PRONTA := "pronta"
const ENTREGUE := "entregue"
## Perdida para sempre (21/11/2026, Alvida: quem perde o duelo não repete a missão; ela some). Não é oferecida, não conta e não bloqueia a cadeia por andamento.
const FALHOU := "falhou"


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
		if TABELA[id]["npc"] == npc and not bool(TABELA[id].get("por_evento", false)) and prog.call("estado_da_missao", id) != ENTREGUE:
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
		if bool(TABELA[id].get("paralela", false)):
			continue
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
		if prog.call("estado_da_missao", id) != DISPONIVEL or bool(TABELA[id].get("por_evento", false)):
			continue
		var onde := str(TABELA[id].get("ilha", ""))
		if not onde.is_empty() and str(prog.get("ilha")) != onde:
			continue                          # missão de outra ilha: não aparece aqui
		var antes := str(TABELA[id].get("depois_de", ""))
		if antes.is_empty() or prog.call("estado_da_missao", antes) == ENTREGUE:
			saida.append(id)
	return saida
