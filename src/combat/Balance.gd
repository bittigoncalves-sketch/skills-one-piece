class_name Balance
extends RefCounted
## Modo História (pedido do dono, 23/10/2026): "diminuir o dano do soco e aumentar o dano
## das skills" — soco −50 %, técnicas +50 %. Só com o perfil de fruta da história (a arena
## não tem perfil: fica como está). Soco = o boxe do jogador (`multiplicador_de_dano` do
## executor, ver `ModoHistoria.instalar_combate_direcional`) e o soco do Mine Piece
## (`Player.escala_de_dano_da_fruta(fruta, false)`); técnica = o resto do kit da fruta.
const HISTORIA_SOCO := 0.5
## 22/11/2026 (pedido do dono, "aumentar o dano das akuma no mi"): técnicas das FRUTAS 1,5 -> 2,0.
## O estilo de combate BASE (o kit do Builder, `KitDoBuilder.ID`) passa pela mesma escala e subiu junto no 1º teste (3,0): ele FICA em 1,5.
const HISTORIA_TECNICAS := 2.0
const HISTORIA_TECNICAS_ESTILO_BASE := 1.5
## Frutas FORA do +50 % (decisão do dono, 23/10/2026): a Magu da história já tem dano
## elevado próprio (`MAGU_HISTORIA`, pago pela antecipação lenta); com o bônus um golpe
## passaria da metade da vida do inimigo comum (132 de 250).
const HISTORIA_SEM_BONUS_DE_TECNICA: Array[String] = ["magu_magu"]
## AIRubbleProcedure (Mine Piece v14), unidades do mod; MundoMinePiece converte.
const MINE_PIECE_OPE := {"entulho": 15.0, "tamanho_minimo_dano": 0.8, "empurrao": 0.5}
## Mine Piece: danos adaptados à arena; história aplica PerfilDeFrutas.ESCALA_DO_MOD (dano do mod × 10 × 1/10 = o do mod).
## Rajada distribui orçamento entre os contatos; final preserva proporção 11 × 1,2.
const MINE_PIECE_LUTA := {
	# 30/10/2026 (pedido do dono): Z e X empurram bem mais (eram 3 e 18); no C só o golpe FINAL empurra — os da
	# rajada não empurram (0) e PARALISAM o alvo (`paralisia`, segundos renovados a cada soco; ver `combate_mine_piece`).
	"soco": {"dano": 90.0, "empurrao": 9.0, "stun": 0.12},
	"pesado": {"dano": 110.0, "empurrao": 27.0, "stun": 0.3},
	"rajada": {"dano": 8.0, "empurrao": 0.0, "stun": 0.0, "paralisia": 0.4},
	"final": {"dano": 132.0, "empurrao": 21.6, "stun": 0.3},
}
## Goro Goro (Mine Piece), em UNIDADES DO MOD ("Damage" de cada procedimento do v14):
## `MundoMinePiece.ataque_em_area` multiplica por 10 (escala da arena) e pela escala do modo.
## As fórmulas que somam carga (`× (1 + cnt6 × 0,1)`) ficam nas técnicas, como no mod.
const MINE_PIECE_GORO := {
	"vari": 14.0,                 # VariProcedure: (14 + cnt3 × 0,01) × CNT6
	"el_thor": 16.0, "el_thor_forte": 24.0,   # ElThor/ElThorFall: 16, 24 depois do tick 20/25
	"sango": 18.0,                # SangoProcedure, cada raio do céu
	"relampago": 18.0,            # LightningStrike2Procedure (o raio de carga do Sango)
	"mamaragan": 18.0,            # MamaraganOnEffectActiveTick, cada raio da tempestade
	"onda": 16.0, "onda_forte": 24.0,         # AIImpactWave modo 56: 16, 24 nos 6 últimos ticks
	"meteoro_queda": 24.0, "meteoro_explosao": 45.0,   # AIMeteor modo 1 (Raigo)
	"kari_krash": 18.0,           # KariKrashProcedure
}
## Hie Hie (Mine Piece v14), unidades do mod; MundoMinePiece converte.
const MINE_PIECE_HIE := {
	"partisan": 15.0,             # AIEntityBird (EntityPartisan): 15 × CNT6
	"passaro": 20.0,              # AIEntityBird (EntityBird): 20 × CNT6
	"vida_partisan": 40.0,        # IceBlockPartisan/2: HP 40 (+ Força × 4)
	"vida_passaro": 60.0,         # IceBlockPheasantBeak: HP 60 (+ Força × 10)
	"bola": 15.0,                 # IceBallProcedure: 15 × CNT6 por cubo
	"ice_age": 18.0,              # IceAgeProcedure: (18 + cnt2 × 0,1) × CNT6
	"vida_gelo": 30.0,            # Effect12: HP da EntityIceBall 30 × CNT6 (+ Força × 8)
	"gelo_ticks": 300,            # AIIceBall: some depois de 300 ticks
}
## Moku Moku (Mine Piece v14), unidades do mod; MundoMinePiece converte.
const MINE_PIECE_MOKU := {
	"punho": 18.0,                # AIFist (FistEntity, move −1): 18 × CNT6
	"vida_punho": 50.0,           # WhiteBlow: HP 50 (+ Força × 8)
	"tornado": 11.0,              # AITornado: 11 × CNT6 por tick no corpo
	"vida_tornado": 50.0,         # WhiteVine: HP 50 (+ Força × 10)
	"white_out": 18.0,            # WhiteOut: 18 × CNT6, cubo de 32 × CNT6
}
## Pika Pika (Mine Piece v14), unidades do mod; MundoMinePiece converte.
const MINE_PIECE_PIKA := {
	"laser": 17.0,                # KizaruLaser1: 17 × CNT6 no feixe e na explosão (cubo 12 × CNT6)
	"laser_pe": 24.0,             # KizaruLaser2: 24 × CNT6 (explosão 24 × CNT6)
	"chute": 17.0,                # KizaruKick (no Yata no Kagami): 17 × CNT6, cubo de 6
	"mergulho": 20.0,             # SpeedIsPower: 20 a cada bloco do mergulho
	"impacto_mergulho": 21.0,     # SpeedIsPower: 21 no chão, cubo de 12
	"flecha": 0.6,                # YasakaniNoMagatama: dano base da flecha (× DamageFix × 8 de velocidade)
	"espada": 8.0,                # AmanoMurakumoItem: 3 + 4 do tier + 1 do jogador
}
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
	"F": {"unico": [0.0, 0.0], "por_hit": 0.0, "teto": 0.0},
	# ⚠️ O Z GANHOU FAIXA DE CARGA em 2026-08-31, com a Bomu Bomu — a primeira
	# fruta do jogo com um Z CARREGADO. Sem ela, `ref.get("carregado",
	# ref["unico"])` caía no único ([80, 96]) e reprovava qualquer carga de Z,
	# por mais equilibrada que fosse: não era a Bomu que estava fora da régua, era
	# a régua que não existia para este slot.
	#
	# O intervalo segue o mesmo desenho dos outros três: começa no topo do dano
	# ÚNICO do slot (96) e termina no TETO dele (200) — carregar é o que separa
	# o piso do teto, e é o padrão exato do X (único até 192, carga de 192 a 256).
	"Z": {"unico": [80.0, 96.0],   "por_hit": 40.0, "teto": 200.0,
		  "carregado": [96.0, 200.0]},
	"X": {"unico": [128.0, 192.0], "por_hit": 64.0, "teto": 256.0,
		  "carregado": [192.0, 256.0]},
	"C": {"unico": [192.0, 256.0], "por_hit": 80.0, "teto": 384.0,
		  "carregado": [240.0, 384.0]},
	"V": {"unico": [512.0, 768.0], "por_hit": 96.0, "teto": 768.0,
		  "carregado": [512.0, 768.0], "base": 640.0},
	# K e L: poderes extras da Zushi Zushi autoral (12/11/2026). Sem eles `test_balance` abortava (`SLOT["K"]` inexistente) e não validava NENHUMA fruta depois.
	"K": {"unico": [240.0, 300.0], "por_hit": 100.0, "teto": 300.0, "carregado": [240.0, 300.0]},
	"L": {"unico": [240.0, 300.0], "por_hit": 100.0, "teto": 480.0, "carregado": [240.0, 480.0]},
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
	# Zushi Zushi autoral (12/11/2026): os poderes do Fujitora fora do mod. K = Jigoku Tabi (cratera, um impacto); L = Abare Himatsuri (chuva de meteoros).
	"zushi_zushi": {
		"K": {"tipo": T.UNICO, "dano": 260.0},
		"L": {"tipo": T.MULTI, "dano": 60.0, "hits": 8, "teto": 480.0},
		"V": {"tipo": T.MULTI, "dano": 50.0, "hits": 12, "teto": 600.0},     # Rubble autoral: chuva de rochas sobre o alvo
	},
	# Ushi Ushi autoral (21/11/2026): Z/X/C da girafa humanoide e do humano; "ushi_ushi_girafa" = forma quadrúpede (Z Pescoçada, X Martelada; sem C).
	"ushi_ushi_giraffe": {
		"Z": {"tipo": T.UNICO, "dano": 96.0},                           # Investida do Pescoço
		"X": {"tipo": T.UNICO, "dano": 160.0},                          # Corte no Ar
		"C": {"tipo": T.MULTI, "dano": 36.0, "hits": 9, "teto": 324.0},   # Rajada de Cortes: 9 cortes do X em leque
	},
	"ushi_ushi_girafa": {
		"Z": {"tipo": T.UNICO, "dano": 96.0},                           # Pescoçada
		"X": {"tipo": T.UNICO, "dano": 192.0},                          # Martelada com o nariz
	},
	"hito_hito_daibutsu": {
		"X": {"tipo": T.UNICO, "dano": 192.0}, # Flor de Buda autoral: um impacto em área.
	},
	"tori_tori_phoenix": {
		"Z": {"tipo": T.UTILITARIO, "dano": 0.0, "teto": 0.0},
		"X": {"tipo": T.UNICO, "dano": 160.0},
		"C": {"tipo": T.UNICO, "dano": 240.0},
		"V": {"tipo": T.UNICO, "dano": 512.0},
		"F": {"tipo": T.UTILITARIO, "dano": 0.0, "teto": 0.0},
	},
	# Magu: dano alto compensado por preparação e deslocamento lentos.
	"magu_magu": {
		"Z": {"tipo": T.UNICO, "dano": 96.0},
		"X": {"tipo": T.UNICO, "dano": 192.0},
		"C": {"tipo": T.UNICO, "dano": 256.0},
		"V": {"tipo": T.MULTI, "dano": 96.0, "hits": 8, "teto": 768.0},
	},
	"rocket": {
		"Z": {"tipo": T.UNICO, "dano": 88.0},
		"X": {"tipo": T.UNICO, "dano": 160.0},
		"C": {"tipo": T.MULTI, "dano": 40.0, "hits": 8, "teto": 320.0},
		"V": {"tipo": T.UNICO, "dano": 576.0, "teto": 576.0},
	},
	"ope_ope": {
		"Z": {"tipo": T.UTILITARIO, "dano": 0.0, "teto": 0.0},
		"X": {"tipo": T.UTILITARIO, "dano": 0.0, "teto": 0.0},
		"C": {"tipo": T.MULTI, "dano": 64.0, "hits": 5, "teto": 320.0},
		"V": {"tipo": T.UNICO, "dano": 576.0, "teto": 576.0},
	},
	"gomu_gomu": {
		"Z": {"tipo": T.UNICO, "dano": 88.0},
		"X": {"tipo": T.UNICO, "dano": 176.0},
		# O Gatling sempre concentrou o estrago no soco final (era `damage * 1.8`
		# contra `* 0.4`): o último soco é o que ARREMESSA, e isso é leitura de
		# golpe, não número solto.
		# ⚠️ `hits` conta só os acertos que valem `dano`; toda parte nomeada é um
		# acerto ADICIONAL, de valor próprio.
		# 3 socos de 80 pagos + o FINAL de 144, guardado pela `reserva`. Fecha em
		# 384, o teto do slot. Os outros 12 socos continuam saindo — eles empurram
		# e sacodem a tela, mas não tiram vida: é o mesmo trato dos escombros do
		# Liberation, que ejeta até 25 e paga 8.
		"C": {"tipo": T.MULTI, "dano": 80.0, "hits": 3,
			  "partes": {"final": 144.0}, "reserva": 144.0},
		# ⚠️ O V DA GOMU É A TRANSFORMAÇÃO GEAR 2 (decisão de 2026-08-27): estado,
		# não golpe com dano.
		"V": {"tipo": T.UTILITARIO, "dano": 0.0, "teto": 0.0},
	},
	"gomu_gomu_gear2": {
		"Z": {"tipo": T.UNICO, "dano": 96.0},
		"X": {"tipo": T.UNICO, "dano": 192.0},
		"C": {"tipo": T.UNICO, "dano": 256.0},
		"V": {"tipo": T.UTILITARIO, "dano": 0.0, "teto": 0.0},
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
		# Higan: oito tiros relevantes a 25 cada. O pente curto faz cada acerto
		# importar quando a mira só conecta parcialmente, sem passar do teto Z.
		"Z": {"tipo": T.MULTI, "dano": 25.0, "hits": 8, "teto": 200.0, "tempo_de_carga": 0.5},
		# ⚠️ VIROU MULTI (2026-08-22). O Hiken sempre teve DUAS partes — o punho e a
		# explosão no fim do trajeto —, mas só o punho estava declarado. E havia um
		# incentivo invertido: a explosão nascia num temporizador que só corria se a
		# zona ainda existisse, então ERRAR rendia a explosão e ACERTAR não.
		# Agora ela nasce também no ponto de impacto, e a `reserva` garante que o
		# punho não coma o orçamento dela. 160 + 96 = 256, o teto do slot.
		"X": {"tipo": T.MULTI, "dano": 160.0, "hits": 1,
			  "partes": {"explosao": 96.0}, "reserva": 96.0, "tempo_de_carga": 1.0},
		# Vagalumes de Fogo: Uma nuvem de vagalumes, se um é ativado, explode em cadeia.
		# Vagalumes: 1 s de preparação anuncia a área. A carga é requisito de
		# execução (não multiplicador de dano), e o orçamento fecha no primeiro
		# contato para evitar acúmulo aleatório.
		"C": {"tipo": T.CARREGADO, "dano": 240.0, "dano_max": 256.0,
			  "tempo_de_carga": 1.0, "teto": 256.0},
		# Dai Enkai: Entei (Sol Quadrado)
		#
		# ⚠️ 256->384 CORRIGIDO PARA 512->768 em 2026-08-21. O Entei MUDOU DE SLOT
		# (era o C carregado, virou o V) e veio com os números do slot antigo. A
		# faixa de carga do C é 256-384 e a do V é 512-768, então a ultimate da
		# Mera estava valendo o mesmo que um C de qualquer outra fruta — metade do
		# que o slot promete. Quem pegou foi `tools/dev_tests/test_balance.gd`,
		# checagem [1]: "mera_mera/V: carga 256->384 fora da faixa [512, 768]".
		# Com 2048 HP, carga cheia tira no máximo 31,25%: ameaça alta, sem matar
		# sozinha ou variar conforme quantas zonas do Sol tocam o mesmo alvo.
		"V": {"tipo": T.CARREGADO, "dano": 512.0, "dano_max": 640.0, "tempo_de_carga": 1.5, "teto": 640.0},
	},
	# Bomu Bomu compensa ter somente dois slots com dano alto dentro do teto
	# normal. Ambos carregam em 0,5 s; a recarga única de 10 s mora no Player.
	"bomu_bomu": {
		"Z": {"tipo": T.CARREGADO, "dano": 144.0, "dano_max": 200.0, "tempo_de_carga": 0.5},
		"X": {"tipo": T.CARREGADO, "dano": 192.0, "dano_max": 256.0, "tempo_de_carga": 0.5},
	},
	"bara_bara": {
		"Z": {"tipo": T.UNICO, "dano": 92.0, "teto": 92.0},
		"X": {"tipo": T.UNICO, "dano": 176.0, "teto": 176.0},
		"C": {"tipo": T.UNICO, "dano": 240.0, "teto": 240.0},
		"V": {"tipo": T.MULTI, "dano": 96.0, "hits": 4, "teto": 576.0,
			"partes": {"final": 192.0}, "reserva": 192.0},
	},
	"goro_goro": {
		"Z": {"tipo": T.UNICO, "dano": 84.0},
		# 11 raios que paralisam + a coluna final, que é a única que arremessa.
		# 2 raios de 64 pagos + a COLUNA de 128, guardada pela `reserva`: 256, o
		# teto do slot. Os 11 raios continuam caindo e continuam PARALISANDO — o
		# que eles deixaram de fazer é comer o orçamento inteiro antes de a coluna
		# chegar, que era o que zerava o clímax do golpe.
		"X": {"tipo": T.MULTI, "dano": 64.0, "hits": 2,
			  "partes": {"coluna": 128.0}, "reserva": 128.0},
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
		# ⚠️ A ONDA TEM RESERVA (2026-08-22). Os escombros são criados ANTES dela
		# no código (`YamiFX._liberation`), e sem reserva os 8 blocos podiam esgotar
		# o teto e deixar o repelão em ZERO. Na prática a onda quase sempre chega
		# primeiro — é instantânea, num raio de 25 m, e os blocos ainda precisam
		# voar —, mas "quase sempre" é exatamente o tipo de suposição que o teto
		# existe para não depender. 6 blocos de 96 + onda de 128 = 704.
		"V": {"tipo": T.MULTI, "dano": 96.0, "hits": 6,
			  "partes": {"onda": 128.0}, "reserva": 128.0},
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
	# PIKA PIKA — o Z é salva de 7 raios. O número por raio é DECISÃO DO DONO
	# (2026-09-04), não leitura do vídeo: dano não se lê em gravação. Chegou por
	# vizinhança — Mera Z tira 25 num acerto só, Gura Z tira 96, e a Buki Z faz
	# 12 x 16. Sete x 14 = 98 no teto, e só se a salva inteira conectar.
		"pika_pika": {
			"Z": {"tipo": T.MULTI, "dano": 14.0, "hits": 7},    # yasakani, 7 x 14 = 98
		# X — a explosão do mergulho. ESCOLHA MINHA, o dono ajusta: fica na
		# vizinhança dos outros X (mera 160, hie 168), e só sai se o ziguezague
		# realmente encontrar alguém.
			"X": {"tipo": T.UNICO, "dano": 160.0},             # yata no kagami
			# C/V: valores inferidos pela faixa canônica do slot. Muitos feixes são
			# visuais; o cast_id/teto impede a densidade de multiplicar o dano.
			"C": {"tipo": T.MULTI, "dano": 8.0, "hits": 48, "teto": 384.0},
			"V": {"tipo": T.MULTI, "dano": 32.0, "hits": 24, "teto": 768.0},
		},
}

# ------------------------------------------------------------- CORPO A CORPO
# Um combo completo vale ~278, ou seja pouco mais de um golpe Z de fruta. Sem
# isto o corpo a corpo ficaria 30x mais fraco que as frutas e deixaria de ser
# uma opção — os valores antigos (30/34/40/70) estavam na escala pré-0,12.
const MELEE := {
	"combo":  [48.0, 54.0, 64.0, 112.0],   # soco D, soco E, chute, finalizador
	# ⚠️ ERAM TRÊS (64/72/96). O combo da espada virou um PAR — horizontal e
	# vertical — a pedido do dono em 2026-09-06, e o corte D-E do meio saiu.
	# Os dois que ficaram mantêm os valores que já tinham: o par vale 160, ainda
	# abaixo do combo de punho completo (278), o que é coerente com ele ter dois
	# golpes em vez de quatro.
	"espada": [64.0, 96.0],                # corte horizontal, corte vertical
	# Continua aqui porque a meia-lua ainda existe no código do projétil; hoje
	# nenhum passo da espada a dispara (ver a nota em `Melee.COMBO_SWORD`).
	"projetil_mult": 1.2,
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
	s.reserva = float(linha.get("reserva", 0.0))
	_moldes[chave] = s
	return s

## A spec pronta para uso, com identidade de conjuração própria. `escala` = a do
## modo de jogo (1 na arena; no Modo História, a do perfil da fruta — quem chama
## pergunta ao corpo: `Player.escala_de_dano_da_fruta`). Explícita de propósito: o
## fator escondido de 0,12 na `DamageZone` foi o erro que esta tabela veio corrigir.
# Magu da HISTÓRIA: pedido de dano elevado, pago pela antecipação lenta.
# Valores ainda na unidade da tabela; a escala do perfil é aplicada uma vez.
# A arena conserva as faixas de SLOT, sem mudar as outras frutas/modos.
const MAGU_HISTORIA := {"Z": [400.0,400.0], "X": [560.0,560.0], "C": [720.0,720.0], "V": [120.0,960.0]}

static func novo(fruta: String, slot: String, escala: float = 1.0) -> DamageSpec:
	var molde := spec(fruta, slot)
	if molde == null:
		return null
	var s := molde.para_cast()
	if fruta == "magu_magu" and escala < 1.0 and MAGU_HISTORIA.has(slot):
		s.dano = MAGU_HISTORIA[slot][0]
		s.dano_max = s.dano
		s.teto = MAGU_HISTORIA[slot][1]
	return s.escalar(escala) if not is_equal_approx(escala, 1.0) else s

static func teto_do_slot(slot: String) -> float:
	return float(SLOT[slot]["teto"]) if SLOT.has(slot) else 0.0

## Dano de um estilo de luta. Molde sem cache: são poucos e mudam de dono a cada
## troca de estilo.
static func spec_de_estilo(estilo: String, slot: String) -> DamageSpec:
	var d: float = float((ESTILOS.get(estilo, {}) as Dictionary).get(slot, 0.0))
	return DamageSpec.criar(T.UNICO, d, teto_do_slot(slot))
