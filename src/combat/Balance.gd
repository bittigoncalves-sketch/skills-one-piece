class_name Balance
extends RefCounted
# ============================================================================
#  A TABELA. Todo número de dano do jogo mora aqui, e só aqui.
#
#  Antes deste arquivo os valores estavam em três lugares que não se falavam:
#  o campo `dano` do `SkillSystem`, vinte e quatro multiplicadores literais
#  espalhados pelos arquivos de efeito (`damage * 0.35`, `damage * 2.5`, ...) e
#  literais escritos à mão dentro do `Player.gd` (as rajadas Z valiam `8.0`,
#  ignorando a tabela que dizia 20 e 28). Balancear uma skill exigia abrir o
#  arquivo de partículas dela.
#
#  ---------------------------------------------------------------- A ESCALA
#  Os números aqui são FINAIS: é o que a barra de vida perde. Não há mais
#  nenhum fator escondido no caminho — o `DamageZone.DAMAGE_SCALE` de 0,12 foi
#  removido junto com esta tabela, e era ele que fazia o mesmo golpe valer
#  8,3x mais quando o efeito chamava `take_damage()` direto em vez de criar
#  hitbox. Ver `src/combat/CombatResolver.gd`.
#
#  Referência: o jogador tem 2048 de vida (`health_controller.gd`).
#
#  ---------------------------------------------- COMO LER UMA LINHA DA TABELA
#      "Z": {"tipo": T.MULTI, "dano": 12.0, "hits": 16, "teto": 200.0}
#
#  `dano` é POR ACERTO, sempre. `hits` é quantos acertos o golpe promete, e
#  serve para o teste conferir que o golpe consegue chegar ao seu teto. `teto`
#  é o máximo que UMA conjuração tira de UM alvo, por mais hitboxes que ela
#  crie — é a resposta ao pedido "multi-hit deve possuir limite de dano total".
#
#  ⚠️ O teto NÃO é o mesmo que baixar o dano por acerto até caber. Baixar o
#  dano puniria o caso comum: quem toma metade dos acertos levaria metade do
#  golpe, enquanto um golpe único entrega tudo. Com teto, os primeiros acertos
#  valem cheio e o corte só acontece para quem toma TODOS.
# ============================================================================

const T := DamageSpec.Tipo

## Vida cheia do jogador. Fica aqui como referência de leitura — quem manda no
## valor continua sendo o `HealthController`. Se um dia mudar lá, muda aqui e a
## tabela inteira é reavaliada contra o número novo.
const HP_BASE := 2048.0

# ---------------------------------------------------------- REFERÊNCIA DE SLOT
# O contrato de balanceamento, em constantes. Toda skill tem de caber na faixa
# do seu slot, e `tools/dev_tests/test_balance.gd` recusa a tabela se não couber.
#
# A razão Z:V é de ~8x no teto (200 -> 768). Antes desta tabela era de 755x
# entre o golpe mais fraco (Goro C, 2,4) e o mais forte (Yami V, 1811) — a
# ultimate da Yami tirava 88% da vida de uma vez, e a da Gura, 1%.
#
# ⚠️ RECARGA NÃO MORA AQUI, de propósito. Ela já tem dono (`Player.RECARGA_POR_SLOT`
# e `SkillSystem.get_slot_cooldown`), e os dois hoje discordam no slot V (25 s
# contra 60 s). Repetir o número aqui criaria um TERCEIRO valor e transformaria
# uma divergência conhecida numa armadilha. Este arquivo manda em dano, só.
const SLOT := {
	"Z": {"unico": [80.0, 96.0],   "por_hit": 40.0, "teto": 200.0},
	"X": {"unico": [128.0, 192.0], "por_hit": 64.0, "teto": 256.0,
		  "carregado": [192.0, 256.0]},
	"C": {"unico": [192.0, 256.0], "por_hit": 80.0, "teto": 384.0,
		  "carregado": [256.0, 384.0]},
	"V": {"unico": [512.0, 768.0], "por_hit": 96.0, "teto": 768.0,
		  "carregado": [512.0, 768.0], "base": 640.0},
}

# ------------------------------------------------------------------- AS FRUTAS
#
# ⚠️ SOBRE AS RAJADAS Z (Mera, Hie, Buki): a referência pede "~40 por hit" E
# "total 160-200" no slot Z, o que descreve um golpe de 4 a 5 acertos. Estas
# skills disparam 12 a 16 projéteis — outro arquétipo. Aqui o TOTAL é o que
# manda (é a restrição dura do balanceamento), então o dano por bala sai de
# `teto / nº de balas`. Uma rajada de 16 balas a 40 cada valeria 640, três
# vezes o teto do slot: a segunda metade do pente não faria nada.
const FRUTAS := {
	"gomu_gomu": {
		"Z": {"tipo": T.UNICO, "dano": 88.0},
		"X": {"tipo": T.UNICO, "dano": 176.0},
		# 16 socos: 15 de 80 e o último de 160. O Gatling sempre concentrou o
		# estrago no soco final (era `damage * 1.8` contra `* 0.4`), e isso é
		# leitura de golpe, não número solto — o último soco é o que arremessa.
		# ⚠️ `hits` conta só os acertos que valem `dano`; toda parte nomeada é um
		# acerto ADICIONAL, de valor próprio. Contá-la duas vezes faria a conta do
		# teste divergir da do golpe.
		"C": {"tipo": T.MULTI, "dano": 80.0, "hits": 15, "partes": {"final": 160.0}},
		# A queimadura do Red Hawk varre o grupo "enemies", que está vazio desde
		# que os inimigos foram desativados. O valor fica declarado para o dia em
		# que voltarem, mas hoje não alcança ninguém.
		"V": {"tipo": T.UNICO, "dano": 704.0, "partes": {"queimadura": 32.0}},
	},
	"gura_gura": {
		"Z": {"tipo": T.UNICO, "dano": 96.0},
		"X": {"tipo": T.CARREGADO, "dano": 192.0, "dano_max": 256.0, "tempo_de_carga": 3.0},
		"C": {"tipo": T.UNICO, "dano": 224.0},
		# Duas ondas, uma de cada borda do mapa. Cada `DamageZone` acerta cada
		# corpo uma vez, então o teto de 768 é exatamente 2 x 384: quem é pego
		# pelas duas leva a ultimate inteira, quem desvia de uma leva metade.
		"V": {"tipo": T.MULTI, "dano": 384.0, "hits": 2},
	},
	"mera_mera": {
		"Z": {"tipo": T.MULTI, "dano": 12.0, "hits": 16},
		"X": {"tipo": T.UNICO, "dano": 160.0},
		# Vagalumes de Fogo: Uma nuvem de vagalumes, se um é ativado, explode em cadeia.
		"C": {"tipo": T.UNICO, "dano": 256.0},
		# Dai Enkai: Entei (Sol Quadrado)
		"V": {"tipo": T.CARREGADO, "dano": 256.0, "dano_max": 384.0, "tempo_de_carga": 3.5},
	},
	"bara_bara": {
		"Z": {"tipo": T.UNICO, "dano": 92.0},
		"X": {"tipo": T.UNICO, "dano": 168.0},
		# ⚠️ REDESENHADA junto com o número. Era um tique a cada 0,25 s por 7 s
		# = 28 acertos de dano CRU, 175 de dano total. Só reescalar produziria 28
		# tiques de 14, e uma névoa que tira lascas não lê como "área cortante".
		# Agora são 5 cortes pesados (intervalo em `BaraFX.INTERVALO_CLEAVE`).
		"C": {"tipo": T.MULTI, "dano": 80.0, "hits": 5},
		# ⚠️ REDESENHADA pelo mesmo motivo, em escala maior: eram 3 cortes por
		# segundo durante 30 s (90 acertos, 810 de dano cru) num raio de 40 m
		# sem linha de visão. Agora é 1 corte a cada 3,5 s — o domínio continua
		# durando 30 s e continua sendo controle de área; o que ele não é mais é
		# um moedor que tira 40% da vida de quem estiver na metade da arena.
		"V": {"tipo": T.MULTI, "dano": 96.0, "hits": 8},
	},
	"goro_goro": {
		"Z": {"tipo": T.UNICO, "dano": 84.0},
		# 11 raios que paralisam + a coluna final, que é a única que arremessa.
		"X": {"tipo": T.MULTI, "dano": 64.0, "hits": 11, "partes": {"coluna": 128.0}},
		"C": {"tipo": T.UNICO, "dano": 200.0},
		"V": {"tipo": T.CARREGADO, "dano": 512.0, "dano_max": 768.0, "tempo_de_carga": 3.0,
			  "partes": {"orbe": 256.0}},
	},
	"yami_yami": {
		# TOGGLE, não conjuração: a tecla empunha a pistola e o botão esquerdo
		# atira, sem pente e sem recarga de slot. Por isso cada tiro é uma
		# conjuração própria e NÃO há teto — um teto aqui zeraria a arma depois
		# de N tiros e ela nunca mais machucaria. O freio é a cadência (0,35 s) e
		# o custo de energia por bala. 8 tiros seguidos = 192, dentro do slot Z.
		"Z": {"tipo": T.UNICO, "dano": 24.0, "teto": 0.0},
		# O vórtice tritura (64) e o ARREMESSO fecha (192): 64 + 192 = 256, o teto.
		"X": {"tipo": T.MULTI, "dano": 64.0, "hits": 1, "partes": {"arremesso": 192.0}},
		"C": {"tipo": T.UNICO, "dano": 256.0},
		# Liberation: a onda de repulsão + os escombros. O `hits` de 8 é quantos
		# escombros precisam acertar para o golpe chegar ao teto — ele continua
		# ejetando de 12 a 25, e os que sobram viram só espetáculo. Era exatamente
		# aqui que estava o pior desequilíbrio do jogo: 25 blocos de dano cru
		# somavam 1800 contra 2048 de vida.
		"V": {"tipo": T.MULTI, "dano": 96.0, "hits": 8, "partes": {"onda": 128.0}},
	},
	"suna_suna": {
		"Z": {"tipo": T.UNICO, "dano": 92.0},
		"X": {"tipo": T.MULTI, "dano": 64.0, "hits": 9},
		"C": {"tipo": T.UNICO, "dano": 240.0},
		"V": {"tipo": T.UNICO, "dano": 640.0},
	},
	"hie_hie": {
		"Z": {"tipo": T.MULTI, "dano": 12.0, "hits": 16},
		"X": {"tipo": T.UNICO, "dano": 168.0},
		"C": {"tipo": T.UNICO, "dano": 192.0},
		# O impacto da placa rompendo o chão + o campo que fica. O campo tica a
		# cada 0,2 s por 50 s (250 tiques): quem for pego DENTRO dele e não sair
		# chega ao teto em ~16 tiques, e a partir daí o gelo é só controle —
		# congela e recongela, como sempre foi, mas não executa mais.
		"V": {"tipo": T.MULTI, "dano": 32.0, "hits": 16, "partes": {"impacto": 256.0}},
	},
	# ⚠️ BUKI BUKI: `dano` aqui é POR BALA. É a única fruta em que a tecla
	# EMPUNHA uma arma em vez de lançar um golpe, e a munição é a penalidade.
	# Os valores saem de `teto / nº de balas` (o pente está em `BukiFX.ARSENAL`),
	# então a arma inteira vale o teto do slot, não importa o calibre.
	"buki_buki": {
		"Z": {"tipo": T.MULTI, "dano": 16.0, "hits": 12},   # pistola,  12 x 16 = 192
		"X": {"tipo": T.MULTI, "dano": 85.0, "hits": 3},    # canhão,    3 x 85 = 255
		"C": {"tipo": T.MULTI, "dano": 76.0, "hits": 5},    # sniper,    5 x 76 = 380
		"V": {"tipo": T.MULTI, "dano": 7.0,  "hits": 100},  # minigun, 100 x  7 = 700
	},
}

# ------------------------------------------------------------- CORPO A CORPO
# Um combo completo vale ~278, ou seja pouco mais de um golpe Z de fruta. Sem
# isto o corpo a corpo ficaria 30x mais fraco que as frutas e deixaria de ser
# uma opção — os valores antigos (30/34/40/70) estavam na escala pré-0,12.
const MELEE := {
	"combo":  [48.0, 54.0, 64.0, 112.0],   # soco D, soco E, chute, finalizador
	"espada": [64.0, 72.0, 96.0],          # corte D-E, corte E-D, corte vertical
	"projetil_mult": 1.2,                  # a meia-lua do corte vertical
}

# ------------------------------------------------ ESTILOS DE LUTA (modo style)
# Mesma referência de slot das frutas. O V do Karatê Tritão continua desativado
# (`desabilitado` em FightingStyles.STYLES) — dano 0 aqui é consequência disso,
# não um valor a calibrar.
const ESTILOS := {
	"karate_tritao": {"Z": 88.0, "X": 160.0, "C": 224.0, "V": 0.0},
	"pacifista":     {"Z": 92.0, "X": 176.0, "C": 200.0, "V": 704.0},
	"mink":          {"Z": 84.0, "X": 152.0, "C": 208.0, "V": 672.0},
	"boxe":          {"Z": 88.0, "X": 168.0, "C": 192.0, "V": 688.0},
	"cyborg":        {"Z": 96.0, "X": 176.0, "C": 216.0, "V": 720.0},
	"teste_animacao":{"Z": 80.0, "X": 128.0, "C": 192.0, "V": 512.0},
}

# ============================================================================
#  LEITURA
# ============================================================================

# Os moldes são construídos uma vez e reaproveitados. Cada conjuração recebe uma
# CÓPIA (`para_cast()`), nunca o molde — ver o cabeçalho de `DamageSpec`.
static var _moldes: Dictionary = {}

## O molde de uma skill. Devolve `null` quando a fruta ou o slot não existem —
## quem chama decide o que fazer, e o `Player` já tem a mensagem certa para
## "fruta sem poderes implementados".
static func spec(fruta: String, slot: String) -> DamageSpec:
	var chave := fruta + "/" + slot
	if _moldes.has(chave):
		return _moldes[chave]
	if not FRUTAS.has(fruta) or not (FRUTAS[fruta] as Dictionary).has(slot):
		return null
	var linha: Dictionary = FRUTAS[fruta][slot]
	var s := DamageSpec.new()
	s.tipo = linha.get("tipo", T.UNICO)
	s.dano = float(linha.get("dano", 0.0))
	s.dano_max = float(linha.get("dano_max", s.dano))
	s.hits = int(linha.get("hits", 1))
	s.tempo_de_carga = float(linha.get("tempo_de_carga", 0.0))
	s.partes = linha.get("partes", {})
	# O teto vem do SLOT, não da skill: é o contrato de balanceamento. Uma skill
	# só o declara para ficar ABAIXO do slot (o V da Mera, em 640).
	s.teto = float(linha.get("teto", teto_do_slot(slot)))
	_moldes[chave] = s
	return s

## A spec pronta para uso, com identidade de conjuração própria.
static func novo(fruta: String, slot: String) -> DamageSpec:
	var molde := spec(fruta, slot)
	return molde.para_cast() if molde != null else null

static func teto_do_slot(slot: String) -> float:
	return float(SLOT[slot]["teto"]) if SLOT.has(slot) else 0.0

## Dano de um estilo de luta. Molde sem cache: são poucos e mudam de dono a cada
## troca de estilo.
static func spec_de_estilo(estilo: String, slot: String) -> DamageSpec:
	var d: float = float((ESTILOS.get(estilo, {}) as Dictionary).get(slot, 0.0))
	return DamageSpec.criar(T.UNICO, d, teto_do_slot(slot))
