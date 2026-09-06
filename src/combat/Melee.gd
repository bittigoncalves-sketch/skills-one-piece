class_name Melee
extends RefCounted
# ============================================================================
#  CORPO A CORPO — simples e eficaz, no botão esquerdo do mouse.
#
#  COMBO (definido pelo usuário):
#    clique 1  -> SOCO com o braço DIREITO
#    clique 2  -> SOCO com o braço ESQUERDO   (se vier em até JANELA segundos)
#    clique 3  -> CHUTE, que fecha o combo    (idem)
#  Passou a janela sem clicar, o combo volta ao primeiro soco.
#
#  Sem custo de energia, de propósito: é o golpe que sobra quando a barra azul
#  acaba. Dano moderado e knockback crescente — quem mata é o buraco, não o
#  dano. Os valores vêm de `Balance.MELEE`; ver a nota sobre a reescala em
#  `COMBO`, embaixo.
#
#  OS DOIS SOCOS SÃO CLIPES DE VERDADE, um de cada lado. Vieram do pacote
#  Meshy "Blue Block Buddy" e foram medidos (soma UpperArm + ForeArm):
#
#    right_upper_hook_from_guard   braço D 477°  x  braço E 144°   (3,3x)
#    left_uppercut_from_guard      braço E 276°  x  braço D  56°   (4,9x)
#
#  Antes disso o combo usava UM clipe só (`punching`, de braço esquerdo — 210°
#  contra 84°) e produzia o soco direito ESPELHANDO-o. `espelhar()` continua
#  aqui embaixo, e continua correta, mas o combo não depende mais dela: clipe
#  autoral lê melhor que reflexão, porque a reflexão também espelha o passo, o
#  ombro e a guarda.
#
#  ⏱️ ANATOMIA MEDIDA DOS CLIPES (2026-08-11). O sinal é o DESLOCAMENTO DO EFETOR
#  (punho / pé) em relação à posição dele em t=0, por cinemática direta no
#  referencial do tronco — o mesmo número para soco reto, hook e chute, e o único
#  dos três candidatos testados que acerta os três (o desvio ANGULAR erra o chute
#  em 0,22 s, porque a perna continua girando na retração; o alcance FRONTAL erra
#  o uppercut, que sobe em vez de ir pra frente). Tudo em TEMPO DE CLIPE, antes de
#  aplicar `inicio`/`vel`:
#
#    | clipe                       | dur   | membro  | começa | PICO=impacto | acaba |
#    | right_upper_hook_from_guard | 1,77s | braço D | 0,217  | 0,633        | 0,933 |
#    | left_uppercut_from_guard    | 1,37s | braço E | 0,217  | 0,367        | 0,783 |
#    | kicking                     | 2,30s | perna D | 0,450  | 1,233        | 1,775 |
#    | roundhouse_kick             | 2,17s | perna E | 0,442  | 1,100        | 1,367 |
#
#  ⚠️ POR QUE OS DOIS SOCOS LIAM IGUAL (relato do dono, medido em 2026-08-11).
#  Não era clipe errado — o contraste entre os braços é enorme nos dois casos
#  (hook: 234° no D contra 52° no E; uppercut: 157° no E contra 30° no D). Eram
#  duas outras coisas, ambas de TEMPO:
#
#   1. VELOCIDADE. A 1,9x, o golpe inteiro do braço direito (0,716 s de clipe)
#      passava em 0,377 s — 23 quadros a 60 fps para 234° de braço. Nesse borrão o
#      olho vê "um braço", não "o braço DIREITO". O esquerdo, a 1,25x, tinha
#      0,453 s. Hoje são 0,597 s e 0,539 s.
#   2. INTERRUPÇÃO. `recuo` era 0,40 s e o impacto do hook caía em 0,368 s (na
#      medição antiga): sobravam **32 ms — 2 quadros** com o braço estendido antes
#      de o clique seguinte TROCAR o clipe. E os dois clipes partem da MESMA pose
#      de guarda (medido: UpperArm_R (50,26,-45)°, ForeArm_L (16,-106,-15)° em
#      ambos, idênticos ao grau). Se o instante que os distingue dura 2 quadros,
#      o que sobra em tela é a guarda — que é comum aos dois.
#
#  A correção tem três partes, e as três dependem uma da outra:
#   • `inicio` corta a guarda parada da abertura (o hook gastava 0,217 s e o chute
#     0,450 s sem mexer o membro) — é isso que paga a desaceleração sem atrasar o
#     soco;
#   • `vel` cai (1,9→1,2 / 1,25→1,05 / 2,4→1,7);
#   • `recuo` passa a ser >= atraso + 0,15 s, garantindo pelo menos 9 quadros de
#     membro estendido antes de o clique seguinte poder cortar (hoje 13, 15 e 14).
#
#  🦵 O CHUTE VIROU LATERAL (2026-08-18, pedido do dono). O passo 2 tocava
#  `kicking` (chute FRONTAL, perna D indo pra frente — alcance frontal 2,30 nas
#  unidades de osso da medição). O dono queria um chute de LADO no lugar.
#
#  CANDIDATOS TESTADOS (`medir_impacto_res.gd kicking roundhouse_kick
#  roundhouse_kick_2 flying_kick chapa_2 chapa_giratoria_2`), com o alcance
#  FRONTAL (−Z) de cada perna como pista de "quão de frente" o chute é — não
#  como medida final (o próprio cabeçalho deste arquivo já avisa que o alcance
#  frontal erra o uppercut; num chute de verdade lateral ele SUBESTIMA o pico,
#  porque o pé cruza mais pro lado que pra frente):
#   • `roundhouse_kick` / `roundhouse_kick_2` — alcance frontal baixo nas duas
#     pernas (0,26 e 0,83): o pé nunca vai muito à frente, sinal de arco
#     LATERAL de verdade. "Roundhouse" É a lateral/giratória do jargão (o nome
#     já entrega). As duas variações são **pose-idênticas** (comparado clipe a
#     clipe por cinemática direta: diferença máxima 0,000 em todo o comprimento
#     — mesma dupla do `Punching`/`punching` já catalogada na seção 2 do
#     `docs/ANIMACOES_MIXAMO.md`); ficou a `roundhouse_kick` (nome canônico,
#     sem sufixo de variação).
#   • `chapa_2` — alcance frontal alto (1,15) E a maior amplitude de perna de
#     todos os candidatos (826° só na canela). "Chapa" aqui é o chute de
#     EMPURRÃO reto (tipo teep de Muay Thai): frontal, não lateral — descartado
#     pelo próprio movimento medido, não só pelo nome.
#   • `chapa_giratoria_2` — "giratória" é lateral no jargão, mas é um chute
#     GIRATÓRIO (o corpo roda quase 360°): golpe vistoso demais pro combo
#     básico de 3 cliques, mesmo problema de escopo do `flying_kick` (chute
#     COM SALTO) — o dono pediu um chute lateral simples, não um especial.
#
#  ESCOLHIDO: `roundhouse_kick`. A perna que soca é a ESQUERDA — não a direita
#  como no `kicking` antigo — confirmado por dois sinais concordantes:
#  amplitude (coxa+canela E = 354° contra D = 200°, via
#  `medir_amplitude_res.gd`) e alcance frontal (perna E = 0,83 contra D = 0,26,
#  via `medir_impacto_res.gd`). Por isso o `melee_guarda` deste passo é
#  `"perna_L"`, não `"perna_R"`.
#
#  RECALIBRAÇÃO (mesmo método do resto deste arquivo — ver `_janela_acao` em
#  `tools/dev_tests/test_arena.gd`, que é quem de fato mede "começa"/PICO/
#  "acaba" pelo DESLOCAMENTO do efetor relativo ao t=0 do clipe, não pelo
#  alcance frontal usado só para triar candidato acima):
#   • `começa` (perna E passa de 25% do pico) = 0,442s — não há guarda parada
#     de verdade pra cortar (a perna já está saindo da pose de repouso desde
#     ~0,03s, diferente do `kicking`, que ficava 0,45s imóvel); `inicio` = 0,40
#     corta só o início lento do arremesso do quadril, igual ao `kicking`
#     antigo, sem entrar na guarda.
#   • PICO (=impacto) = 1,10s. É MAIS TARDE que o pico do alcance frontal
#     (0,83 em t=1,02) — esperado num chute lateral: o pé continua abrindo
#     para o lado depois de passar pelo ponto mais à frente, e o deslocamento
#     TOTAL (o sinal que este arquivo já usa pros outros 3 golpes) pega esse
#     instante, não o alcance frontal isolado.
#   • `vel` = 1,5 (mesma da soco rápido/finalizador — dá 1,18s de golpe em
#     tela, no mesmo talho dos outros três passos do combo).
#   • `atraso` = (1,10 − 0,40) / 1,5 = 0,4667.
#  `dano`/`kb`/`alcance`/`raio`/`vida`/`shake` ficaram OS MESMOS: são parâmetros
#  de JOGO (a hitbox nasce à frente do jogador ao longo da mira, ver
#  `golpear()`) e não da pose — o chute virar lateral em tela não muda pra
#  onde a hitbox precisa alcançar.
# ============================================================================

const JANELA := 2.0        # tempo pra encadear o próximo golpe (pedido do usuário)

# Cada passo do combo.
#
# `inicio` = de onde o clipe começa a tocar (corta a guarda parada da abertura).
# `atraso` = quando a hitbox nasce, contado do CLIQUE. É (pico − inicio) / vel, ou
#            seja uma FRAÇÃO do clipe — mexeu em `vel` ou `inicio`, recalcule.
#            O teste `test_arena.gd` (seção 4) confere essa conta.
#
# ⚠️ NÃO EXISTE MAIS UM `recuo` AQUI. Ele era escrito à mão golpe a golpe e virou
# conta derivada da animação em 2026-08-15 — ver `static func recuo()` embaixo e
# o `tools/dev_tests/medir_tempos_melee.gd`, que mede a defasagem que motivou a
# troca. Quem quiser um golpe mais lento mexe em `vel`/`inicio`: a trava segue.
# ⚠️ OS VALORES DE `dano` FORAM REESCALADOS EM 2026-08-21, junto com o resto do
# jogo. Eram 30/34/40/70, números da escala antiga, em que a `DamageZone` ainda
# multiplicava tudo por 0,12 — o combo inteiro tirava 20,9 de uma vida de 2048.
#
# Agora são os de `Balance.MELEE`, e o combo completo vale 278: pouco mais que
# um golpe Z de fruta. Sem este realinhamento o corpo a corpo ficaria trinta
# vezes mais fraco que as frutas e deixaria de ser uma opção.
#
# ⚠️ Eles ficam AQUI, e não só no `Balance`, de propósito: cada passo é uma
# linha de frame data (`vel`, `inicio`, `atraso`, `vida`, `shake`) e separar só
# a coluna `dano` para outro arquivo tornaria ilegível a leitura de um golpe.
# O `test_balance.gd` confere que as duas tabelas continuam batendo.
# ============================================================================
#  ⏱️ FRAME DATA — REESCRITO EM 2026-08-25
#  (Frente 1 de `docs/PLANO_COMBATE_BATTLEGROUNDS.md`, §4.2)
#
#  Cada passo declara agora as TRÊS fases que um golpe de battlegrounds tem,
#  em segundos de TELA:
#
#    `startup`      do clique até a hitbox nascer. Era o `atraso` escrito à
#                   mão; agora é ele quem manda e o `atraso` sai derivado.
#    `ativo`        quanto tempo a hitbox fica viva. Era o `vida`.
#    `recuperacao`  o rabo do golpe, em que o corpo ainda está preso.
#
#  `trava = startup + ativo + recuperacao`. Não existe mais "trava = clipe
#  inteiro": a trava virou frame data, e é o CLIPE que se ajusta a ela.
#
#  ------------------------------------------------------------ POR QUE MUDOU
#  A regra do dono ("não se move até a animação acabar", 2026-08-15) continua
#  valendo ao pé da letra. O que muda é a duração do clipe que ela tranca:
#  0,40 s em vez de 1,2-1,5 s.
#
#  Com trava = clipe inteiro e hitstun fixo de 0,30 s, a vantagem no acerto
#  era NEGATIVA nos quatro golpes (−49 quadros no primeiro soco): acertar um
#  M1 era jogada PERDEDORA, porque o atacante ainda estava preso quando o
#  alvo já podia responder. Isto não é gosto, é aritmética (§2.3 do plano):
#
#      vantagem_no_acerto = hitstun − (ativo + recuperacao)
#      o combo encadeia  ⟺  vantagem ≥ startup do próximo golpe
#
#  Com a tabela abaixo a vantagem é +0,21 s nos socos e +0,23 s no chute,
#  contra um startup de 0,20 s: o combo trava de verdade.
#
#  --------------------------------------------- `pico` É O NÚMERO MEDIDO
#  É o instante, em tempo de CLIPE, em que o efetor (punho ou pé) chega ao
#  deslocamento máximo — a medição está na tabela do cabeçalho deste arquivo e
#  sai do `medir_impacto_res.gd`.
#
#  `inicio` NÃO é mais escrito à mão: é DERIVADO, de forma que o pico caia
#  exatamente no fim do `startup` (ver `inicio()` embaixo). Mexeu em `startup`
#  ou em `vel`, a janela do clipe se reposiciona sozinha — que é a mesma razão
#  pela qual o `recuo` deixou de ser escrito à mão em 2026-08-15.
#
#  -------------------------------- ⚠️ O QUE ESTÁ EM TELA HOJE É UMA JANELA
#  Interino, declarado, com gatilho. Os quatro clipes do Mixamo têm 1,37-2,23 s
#  e em 0,40 s só cabe um pedaço. A janela é escolhida para conter o GOLPE (a
#  aproximação e o impacto) e cortar a VOLTA À GUARDA.
#
#  NÃO se acelera o clipe para caber. Para o `boxing_1` caber inteiro em
#  0,40 s seria preciso 5,6x — e a 1,9x o soco já virava borrão, que é
#  exatamente o defeito de 2026-08-11 documentado lá em cima. Janela na
#  velocidade natural mostra o movimento de verdade; acelerar mostra um risco.
#
#  ✅ GATILHO CUMPRIDO EM 2026-08-25 — as Fases A-D entregaram os quatro clipes
#  autorais (`m1_jab`, `m1_soco_esquerdo`, `m1_chute`, `m1_finalizador`, feitos
#  por `tools/autorar_combo_m1.py`). Eles JÁ nascem com a duração do frame data,
#  então `vel = 1.0`, `pico = startup`, `inicio` derivado = 0 e a janela cobre o
#  clipe inteiro: nada é cortado.
#
#  A janela CONTINUA implementada, e não é código morto: é ela que segura a
#  `COMBO_SWORD` e qualquer clipe do Mixamo que volte a entrar no combo.
#
#  ⚠️ E REFAZER NÃO ERA SÓ QUESTÃO DE TEMPO. Medido nos 29 clipes do acervo:
#  ONZE começam com o tronco rolado mais de 25° no eixo Z, e dois eram do combo
#  — `boxing_1` (jab) a −32,8° e `roundhouse_kick` (chute) entre −52° e −86° o
#  clipe INTEIRO, ou seja nunca de pé. Conferido no jogo e não só no dado: o
#  "up" do torso ficava a 51° da vertical. Defeito de retarget que janela
#  nenhuma conserta. Ver `docs/erros.md`.
#
#  ⚠️ `COMBO_SWORD` NÃO FOI CONVERTIDO. O plano trata dos quatro M1 do punho;
#  a espada nem está no mapa hoje (saiu do spawn em 2026-08-23). Ela continua
#  na tabela antiga (`atraso`/`vida`/`inicio` escritos à mão) e os acessores
#  embaixo caem para esses campos quando o frame data não existe. Converter a
#  espada sem o plano cobri-la seria inventar números.

# Punição de whiff (§4.3): errar alonga a RECUPERAÇÃO. É o que impede o rusher
# de clicar sem alcance e sair impune — e não toca no startup nem no ativo,
# porque o que se pune é ter ficado exposto, não ter tentado.
const WHIFF_MULT := 1.35

const COMBO := [
	{
		"nome": "Jab", "anim": "m1_jab", "espelhar": false,
		"vel": 1.0, "pico": 0.20,
		"startup": 0.20, "ativo": 0.06, "recuperacao": 0.14,
		"hitstun": 0.75,
		"dano": 48.0, "kb": 11.0, "alcance": 1.5, "raio": 1.5, "shake": 0.25,
		"melee_guarda": "R",
	},
	{
		"nome": "Soco Esquerdo", "anim": "m1_soco_esquerdo", "espelhar": false,
		"vel": 1.0, "pico": 0.20,
		"startup": 0.20, "ativo": 0.06, "recuperacao": 0.14,
		"hitstun": 0.75,
		"dano": 54.0, "kb": 13.0, "alcance": 1.5, "raio": 1.5, "shake": 0.30,
		"melee_guarda": "L",
	},
	{
		# Chute LATERAL (2026-08-18). Ver a nota datada no cabeçalho para a
		# escolha do clipe. A perna que golpeia é a ESQUERDA — daí o
		# `melee_guarda` ser "perna_L".
		#
		# Recuperação 0,03 s mais longa que a dos socos, e hitstun 0,05 s maior:
		# é o golpe de alcance do combo (2,0 m contra 1,5 m), e o plano paga o
		# alcance com exposição. A vantagem sai +0,23 s, ainda acima do startup.
		"nome": "Chute Lateral", "anim": "m1_chute", "espelhar": false,
		"vel": 1.0, "pico": 0.20,
		"startup": 0.20, "ativo": 0.06, "recuperacao": 0.17,
		"hitstun": 0.80,
		"dano": 64.0, "kb": 15.0, "alcance": 2.0, "raio": 1.9, "shake": 0.4,
		"melee_guarda": "perna_L",
	},
	{
		# FINALIZADOR. Startup e recuperação maiores de propósito: é o golpe
		# que se vê chegar e que pune quem erra.
		#
		# ⚠️ `derruba` NO LUGAR DO RAGDOLL. O §4.2 pede ragdoll de 2,0 s aqui, e
		# `CombatStateRagdoll` é Ordem 3 do §7 — ainda não existe. O que existe
		# HOJE e chega mais perto é o KNOCKDOWN, que já está inteiro de ponta a
		# ponta (`DamageZone.derruba` -> meta `knockdown_dur` ->
		# `RecepcaoDeDano.derrubar_com_animacao` -> `pose_knockdown` ->
		# `_etapa_locomocao` congela o corpo). Usar o que existe é honesto; um
		# `hitstun: 2.0` no flinch normal deixaria o alvo de pé, tremendo por
		# 2 s, que lê como travamento de jogo e não como derrubada.
		#
		# GATILHO: quando `CombatStateRagdoll` entrar (Ordem 3), este campo vira
		# o gatilho do ragdoll e o knockdown volta a ser só o do plano B.
		"nome": "Finalizador", "anim": "m1_finalizador", "espelhar": false,
		"vel": 1.0, "pico": 0.25,
		"startup": 0.25, "ativo": 0.08, "recuperacao": 0.35,
		"hitstun": 0.80, "derruba": 2.0,
		"dano": 112.0, "kb": 26.0, "alcance": 2.2, "raio": 2.0, "shake": 0.6,
	},
]

# ============================================================================
#  COMBO DA ESPADA — HORIZONTAL, DEPOIS VERTICAL (2026-09-06)
# ============================================================================
#  Pedido do dono: *"vamos começar com um corte horizontal e em seguida um
#  vertical, especificamente um seguido do outro quando clicados"*.
#
#  A tabela anterior tinha TRÊS passos (corte D-E, corte E-D, corte vertical) e
#  era a última do projeto ainda escrita no modelo antigo — `atraso`/`vida` em
#  vez de startup/ativo/recuperação. O comentário do cabeçalho registrava o
#  porquê: "a espada não está no mapa, o plano não a cobre, e escrever frame
#  data para ela seria inventar números".
#
#  Isso deixou de valer: a espada volta ao jogo agora, com dois golpes definidos
#  pelo dono, então os números passam a ser escolha declarada em vez de invenção
#  sem dono. **A espada entra no mesmo modelo de frame data do combo de punho.**
#
#  ------------------------------------------------------- de onde vêm os tempos
#  Da ANIMAÇÃO, não do gosto. `WeaponPoses._get_slash_frame` já divide o corte
#  em três trechos, e são eles que mandam:
#
#      0,00 .. 0,20   puxa para trás      -> STARTUP
#      0,20 .. 0,26   joga para a frente  -> ATIVO   (o fio passa aqui)
#      0,26 .. 1,00   volta ao repouso    -> RECUPERAÇÃO
#
#  ------------------------------------ ⚠️ A ESPADA É MAIS LENTA QUE O PUNHO
#  Pedido do dono (2026-09-06): "o ataque da espada demora mais que o ataque
#  corpo a corpo com os punhos". Os tempos subiram para valer isso:
#
#      jab (punho) ........ 0,20 / 0,06 / 0,14 = 0,40 s
#      corte horizontal ... 0,32 / 0,14 / 0,30 = 0,76 s   (1,9x o jab)
#      corte vertical ..... 0,40 / 0,16 / 0,44 = 1,00 s   (2,5x o jab)
#
#  O `ativo` cresceu junto, e não só o startup: uma lâmina de 1,38 m varrendo o
#  espaço fica perigosa por mais tempo que um punho, e encolher só o começo
#  daria uma espada lenta de sacar E fácil de errar — o pior dos dois.
#
#  ⚠️ E AS FASES DA ANIMAÇÃO SEGUEM ESTES NÚMEROS. `WeaponPoses` tinha o golpe
#  fixo em 0,20..0,26 do ciclo, e a hitbox nascia em `startup` segundos: com o
#  ciclo de 0,49 s a lâmina passava 0,102 s ANTES de o dano existir. Agora o
#  Player deriva as fases daqui (ver `Melee.fracao_do_golpe`) e os dois não
#  podem mais divergir.
#
#  ⚠️ O `alcance`/`raio` continuam na tabela mas NÃO valem mais para o dano da
#  espada: quem machuca agora são as bolinhas da `SwordBlade`, presas ao fio.
#  Eles seguem aqui porque o `_impacto` (fagulhas, tremor) e o auto-lunge ainda
#  os leem para saber onde desenhar e quanto avançar.
const COMBO_SWORD := [
	{
		# 1º CLIQUE — HORIZONTAL. `slash_type` 0 é o corte direita→esquerda do
		# `WeaponPoses`, que é o gesto que abre naturalmente para o vertical
		# vir por cima em seguida.
		"nome": "Corte Horizontal", "anim": "", "espelhar": false,
		"slash_type": 0,
		"vel": 1.4, "pico": 0.32,
		"startup": 0.32, "ativo": 0.14, "recuperacao": 0.30,
		"hitstun": 0.75,
		"dano": 64.0, "kb": 15.0, "alcance": 2.5, "raio": 2.0, "shake": 0.35,
		"melee_guarda": "R",
	},
	{
		# 2º CLIQUE — VERTICAL, de cima para baixo (`slash_type` 2). Startup e
		# recuperação maiores: é o fechamento do par, o golpe que se vê chegar.
		#
		# ⚠️ O `projetil: true` do antigo corte vertical NÃO foi trazido. A
		# meia-lua era o que dava alcance ao terceiro passo de um combo de três;
		# num par de dois ela transforma o fechamento num golpe à distância, que
		# é outro assunto. Fica como decisão do dono, não como herança silenciosa.
		"nome": "Corte Vertical", "anim": "", "espelhar": false,
		"slash_type": 2,
		"vel": 1.2, "pico": 0.40,
		"startup": 0.40, "ativo": 0.16, "recuperacao": 0.44,
		"hitstun": 0.80,
		"dano": 96.0, "kb": 25.0, "alcance": 3.0, "raio": 2.5, "shake": 0.50,
	},
]

static var _cache: Dictionary = {}   # "anim|espelhado" -> Animation

static func passo(i: int, weapon: String = "") -> Dictionary:
	if weapon == "sword":
		return COMBO_SWORD[clampi(i, 0, COMBO_SWORD.size() - 1)]
	return COMBO[clampi(i, 0, COMBO.size() - 1)]

# ============================================================================
#  ACESSORES DE FRAME DATA
#
#  Uma função por grandeza, e TODAS caem para o campo antigo do dicionário
#  quando o frame data não existe. É isso que deixa `COMBO_SWORD` (tabela
#  antiga, `atraso`/`vida`/`inicio` na mão) continuar funcionando sem uma
#  linha de mudança enquanto o `COMBO` do punho já roda no modelo novo.
#
#  A alternativa era converter as duas tabelas de uma vez. Foi descartada: a
#  espada não está no mapa (saiu do spawn em 2026-08-23), o plano não a cobre,
#  e escrever startup/ativo/recuperação para ela seria inventar números que
#  ninguém mediu.
# ============================================================================

# Tem frame data novo? É o que decide qual dos dois caminhos vale.
static func tem_frame_data(i: int, weapon: String = "") -> bool:
	return passo(i, weapon).has("startup")

## Qual pose de corte o passo usa (`WeaponPoses.two_handed_sword_slash`):
## 0 = horizontal direita→esquerda, 1 = horizontal esquerda→direita,
## 2 = vertical de cima para baixo.
##
## Existe para o tipo do corte não ser o ÍNDICE do passo. Eram a mesma coisa por
## acidente enquanto o combo tinha três golpes na mesma ordem dos três tipos;
## bastou o combo virar um par para o segundo clique pedir o corte errado.
## Em que FRAÇÃO do ciclo o golpe acontece — o par que a animação precisa para
## fazer o fio passar exatamente na janela ativa.
##
## Existe porque `WeaponPoses` tinha essas duas fronteiras escritas à mão
## (0,20 e 0,26) enquanto a hitbox vinha daqui em segundos. Eram duas descrições
## independentes da mesma coisa, e não batiam: no corte horizontal a lâmina
## passava 0,102 s antes de o dano nascer. Derivando as duas do mesmo lugar,
## divergir deixa de ser possível.
static func fracao_do_golpe(i: int, weapon: String = "") -> Vector2:
	var dur := duracao_tocada(i, weapon)
	if dur <= 0.0:
		return Vector2(WeaponPoses.GOLPE_INICIO_PADRAO, WeaponPoses.GOLPE_FIM_PADRAO)
	var ini: float = startup(i, weapon) / dur
	var fim: float = (startup(i, weapon) + ativo(i, weapon)) / dur
	return Vector2(ini, fim)


static func slash_type(i: int, weapon: String = "") -> int:
	return int(passo(i, weapon).get("slash_type", i))

# ------------------------------------------------------------- as três fases
static func startup(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	return float(g.get("startup", g.get("atraso", 0.0)))

static func ativo(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	return float(g.get("ativo", g.get("vida", 0.0)))

static func recuperacao(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	if g.has("recuperacao"):
		return float(g["recuperacao"])
	# Tabela antiga: a recuperação é o que sobra da trava depois do golpe.
	return maxf(recuo(i, weapon) - startup(i, weapon) - ativo(i, weapon), 0.0)

# Quanto tempo o alvo fica preso ao levar este golpe. Era um 0,30 s fixo
# enterrado na assinatura da `DamageZone` — e era metade da causa de a vantagem
# no acerto ser negativa (§2.3 do plano).
static func hitstun(i: int, weapon: String = "") -> float:
	return float(passo(i, weapon).get("hitstun", 0.3))

# Quanto tempo o alvo fica DERRUBADO. 0 = não derruba. Ver a nota do
# Finalizador sobre por que é knockdown e não ragdoll ainda.
static func derruba(i: int, weapon: String = "") -> float:
	return float(passo(i, weapon).get("derruba", 0.0))

# ------------------------------------------------------------------- a conta
#
#  vantagem_no_acerto = hitstun − (ativo + recuperacao)
#
#  Positiva = quem acertou volta a agir ANTES do alvo, e o combo encadeia.
#  Negativa = acertar é jogada perdedora, que era o estado até 2026-08-25.
#  Comparar com o `startup` do golpe seguinte responde se o combo TRAVA.
#
#  Fica aqui, e não só no teste, porque é a regra que justifica a tabela
#  inteira: quem mexer num `recuperacao` sem olhar isto quebra o combo sem
#  perceber.
static func vantagem(i: int, weapon: String = "") -> float:
	return hitstun(i, weapon) - ativo(i, weapon) - recuperacao(i, weapon)

# ---------------------------------------------------------------- RECUPERAÇÃO
#
#  ⏱️ A TRAVA ERA A ANIMAÇÃO (2026-08-15). AGORA É O FRAME DATA (2026-08-25).
#
#  Histórico, porque a ordem das trocas importa para quem vier depois:
#
#   • Até 2026-08-15 `recuo` era um número escrito à mão em cada golpe, sem
#     nada que o ligasse ao clipe em tela. Medido pelo `medir_tempos_melee.gd`,
#     a defasagem era de 0,30 s a 1,00 s nos sete golpes — o clique seguinte
#     SEMPRE abria com o golpe anterior ainda correndo.
#   • De 2026-08-15 a 2026-08-25 saía de `(comprimento − inicio) / vel`: a
#     trava passou a ser o clipe inteiro. Consertou a defasagem e criou outra
#     coisa — travas de 1,2-1,5 s, e com elas a vantagem negativa do §2.3.
#   • Agora sai de `startup + ativo + recuperacao`. O clipe deixou de mandar na
#     trava e passou a ser JANELADO por ela (ver `fim_da_janela`).
#
#  A regra do dono não mudou em nenhum dos três momentos: a trava continua
#  sendo "não se move até a animação acabar". Mudou quem decide quanto a
#  animação dura.
const MARGEM_POS_IMPACTO := 0.15

# ⚠️ LEGADO — só vale para quem NÃO tem frame data (hoje: `COMBO_SWORD`).
# 1,0 = trava até o último quadro da animação.
const TRAVA_DA_ANIMACAO := 1.0

# Quanto tempo o golpe segura o CLIQUE seguinte e o CORPO. São o mesmo número de
# propósito: é isso que "correlacionar a animação com o próximo clique" quer.
#
# `errou` alonga só a recuperação (§4.3 do plano) — ver `WHIFF_MULT`.
static func recuo(i: int, weapon: String = "", errou: bool = false) -> float:
	var g := passo(i, weapon)
	if g.has("startup"):
		var rec: float = float(g["recuperacao"]) * (WHIFF_MULT if errou else 1.0)
		return float(g["startup"]) + float(g["ativo"]) + rec
	# ------ caminho antigo: a trava é o clipe inteiro
	var d := duracao_tocada(i, weapon) * TRAVA_DA_ANIMACAO
	# PISO: a regra antiga (`recuo >= atraso + 0,15`) não era capricho — garante
	# ~9 quadros de membro estendido depois de a hitbox nascer. Ela sobrevive para
	# o dia em que entrar um clipe curto demais.
	return maxf(d, float(g["atraso"]) + MARGEM_POS_IMPACTO)

# ------------------------------------------------------- o clipe e sua janela
#
# `inicio` DERIVADO: onde a janela do clipe abre, de forma que o `pico` medido
# caia exatamente no fim do `startup`.
#
#     tempo_de_tela(pico) = (pico − inicio) / vel = startup
#     =>  inicio = pico − startup * vel
#
# Escrever `inicio` à mão de novo seria voltar ao erro que o cabeçalho do
# arquivo já documenta duas vezes: número de tempo desacoplado do clipe
# envelhece em silêncio.
static func inicio(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	if not g.has("pico"):
		return float(g.get("inicio", 0.0))
	var a := clipe(i, weapon)
	var teto := 0.0 if a == null else maxf(a.length - 0.01, 0.0)
	return clampf(float(g["pico"]) - float(g["startup"]) * float(g["vel"]), 0.0, teto)

# Onde a janela FECHA, em tempo de clipe. É isto que corta a volta à guarda:
# sem este corte o clipe de 2,23 s continuaria correndo por 1,8 s depois de o
# corpo já estar livre, e o clique seguinte trocaria o clipe no meio — que é o
# defeito de INTERRUPÇÃO de 2026-08-11, agravado por travas 3x menores.
static func fim_da_janela(i: int, weapon: String = "") -> float:
	var a := clipe(i, weapon)
	if a == null:
		return 0.0
	if not tem_frame_data(i, weapon):
		return a.length
	var g := passo(i, weapon)
	return minf(inicio(i, weapon) + recuo(i, weapon) * float(g["vel"]), a.length)

# Quanto tempo o clipe do passo `i` fica em tela, já com `inicio` e `vel`.
# Com frame data isto é a JANELA (= a trava); sem ele é o clipe inteiro, e aí
# é ele quem define a trava (ver `recuo`).
static func duracao_tocada(i: int, weapon: String = "") -> float:
	# ⚠️ GOLPE SEM CLIPE NÃO TEM DURAÇÃO ZERO — TEM A DURAÇÃO DO FRAME DATA.
	#
	# Os cortes de espada são PROCEDURAIS (`WeaponPoses.two_handed_sword_slash`)
	# e não têm `.tres` nenhum, então `clipe()` devolve `null` para eles. Com o
	# `return 0.0` que morava aqui, o Player fazia
	#
	#     speed = 1.0 / maxf(duracao, 0.1)      -> 1.0 / 0.1 = 10x
	#
	# e o corte inteiro passava em 0,1 s. Em tela isso é um tranco de dois
	# quadros: o jogador clicava, nada de espada aparecia, e o que sobrava era a
	# pose de repouso — indistinguível de "o sistema de punho ainda está no
	# lugar da espada", que foi exatamente como o defeito foi relatado.
	#
	# Quando há frame data, ele é a fonte: startup + ativo + recuperação É a
	# duração do golpe, com ou sem clipe assado por trás.
	var g_sem_clipe := passo(i, weapon)
	if not g_sem_clipe.has("anim") or String(g_sem_clipe.get("anim", "")).is_empty():
		if tem_frame_data(i, weapon):
			return startup(i, weapon) + ativo(i, weapon) + recuperacao(i, weapon)
	var a := clipe(i, weapon)
	if a == null:
		return 0.0
	var g := passo(i, weapon)
	if tem_frame_data(i, weapon):
		return maxf(fim_da_janela(i, weapon) - inicio(i, weapon), 0.0) / float(g["vel"])
	return maxf(a.length - float(g.get("inicio", 0.0)), 0.0) / float(g["vel"])

# Instante do clipe (tempo de CLIPE, não de tela) em que a hitbox nasce. Serve
# para o teste conferir que o `startup` continua casado com o pico medido do
# membro depois de qualquer mexida em `vel`.
static func impacto_no_clipe(i: int, weapon: String = "") -> float:
	var g := passo(i, weapon)
	return inicio(i, weapon) + startup(i, weapon) * float(g["vel"])

# ------------------------------------------------------------------ animação
# Devolve o clipe do passo, já espelhado se for o caso (e memorizado — espelhar
# percorre todas as faixas, não vale refazer a cada soco).
static func clipe(i: int, weapon: String = "") -> Animation:
	var g := passo(i, weapon)
	# Golpe PROCEDURAL não tem clipe, e isso é legítimo — não é ausência de
	# arquivo. Os cortes de espada são gerados por `WeaponPoses`; avisar
	# "clipe ausente" a cada golpe encheria o log de ruído por um caso normal.
	if String(g.get("anim", "")).is_empty():
		return null
	var chave: String = "%s|%s" % [g["anim"], g["espelhar"]]
	if _cache.has(chave):
		return _cache[chave]
	# ⚠️ `.res` E `.tres`. O caminho era `%s.res` fixo, e o editor de animação do
	# projeto (`tools/anim_editor/`, e o `autorar_combo_m1.py`) grava `.tres` —
	# texto, que o Godot carrega igual. Todo clipe autoral entrava aqui como
	# "clipe ausente" e o golpe ficava sem animação nenhuma, com um warning que
	# some no meio do log.
	var caminho := ""
	for ext in [".tres", ".res"]:
		var tentativa: String = "res://assets/animations/%s%s" % [g["anim"], ext]
		if ResourceLoader.exists(tentativa):
			caminho = tentativa
			break
	if caminho == "":
		push_warning("[Melee] clipe ausente (nem .tres nem .res): " + String(g["anim"]))
		return null
	var a: Animation = load(caminho)
	if g["espelhar"]:
		a = espelhar(a)
	_cache[chave] = a
	return a

# Espelha um clipe do rig de papéis (esquerda <-> direita).
#
# NÃO é usada pelo combo desde que entraram os dois socos autorais — fica porque
# a biblioteca do Mixamo é quase toda de um lado só, e o dia que um golpe novo
# precisar do lado oposto, isto resolve sem reexportar nada. Validada: no
# `punching`, 56°/159° vira 159°/56°.
# Gatilho para apagar: se daqui a alguns golpes nenhum tiver usado, é dívida.
static func espelhar(orig: Animation) -> Animation:
	var out: Animation = orig.duplicate(true)
	for i in out.get_track_count():
		var caminho := String(out.track_get_path(i))
		var papel := caminho.get_slice(":", 0)
		var resto := caminho.substr(papel.length())
		if papel.ends_with("_L"):
			papel = papel.substr(0, papel.length() - 2) + "_R"
		elif papel.ends_with("_R"):
			papel = papel.substr(0, papel.length() - 2) + "_L"
		out.track_set_path(i, NodePath(papel + resto))
		for k in out.track_get_key_count(i):
			var v = out.track_get_key_value(i, k)
			if v is Vector3:
				out.track_set_key_value(i, k, Vector3(v.x, -v.y, -v.z))
	return out

# --------------------------------------------------------------------- golpe
# Cria a hitbox do passo `i` à frente de `caster`. RODA NO SERVIDOR (é ele que
# instancia a DamageZone; ver Player._do_server_melee).
# O corte da espada confirma o acerto por aqui. `hit_confirmed` é lido pela
# punição de whiff (errar alonga a recuperação) e pelo counter hit; sem esta
# ponte o corte por lâmina contaria como errado mesmo acertando.
static func _marcar_acerto(_alvo: Node, caster: Node) -> void:
	if is_instance_valid(caster) and "hit_confirmed" in caster:
		caster.hit_confirmed = true


static func golpear(world: Node, caster: Node3D, i: int, origem: Vector3, dir: Vector3) -> void:
	var weapon = caster.equipped_weapon if caster and "equipped_weapon" in caster else ""
	var g := passo(i, weapon)
	var fwd := dir.normalized()
	var alto: float = origem.y - caster.global_position.y   # altura do peito, relativa
	
	var s := 1.0
	if "scale" in caster:
		s = caster.scale.y
		
	# ⚠️ A HITBOX NASCE NO FIM DO STARTUP. Era `g["atraso"]`, escrito à mão; com
	# frame data o startup É o atraso, e `startup()` devolve o campo antigo
	# quando a tabela é a velha (espada). Um número só, uma fonte só.
	var timer := world.get_tree().create_timer(startup(i, weapon) * s)
	timer.timeout.connect(func():
		if not is_instance_valid(caster) or not is_instance_valid(world):
			return

		# ================================================================
		#  ESPADA: quem machuca são as BOLINHAS DO FIO, não uma caixa no ar
		# ================================================================
		#  Mudança pedida pelo dono em 2026-09-06. Até aqui o corte criava uma
		#  `BoxShape3D` de `raio*2` por `alcance*1.5` — com os números da tabela,
		#  4 m de largura por 3,75 m de fundo — parada na frente do peito
		#  durante os quadros ativos. Ela não tinha relação com onde a lâmina
		#  estava: era um volume que aparecia na direção do clique.
		#
		#  Agora a `SwordBlade` é armada pelos mesmos `ativo` segundos, e as
		#  zonas percorrem o arco de verdade porque estão presas à espada, que
		#  está presa à mão, que a animação gira. Acerta o que o fio encostou.
		#
		#  ⚠️ E é aqui que o CHOQUE DE ESPADAS passa a ser possível: duas caixas
		#  no ar não têm como se encontrar de forma que signifique alguma coisa;
		#  dois fios têm. O clash mora na `SwordBlade`, não neste arquivo.
		if weapon == "sword" and caster.has_method("lamina_da_espada"):
			var fio = caster.call("lamina_da_espada")
			if fio != null and is_instance_valid(fio):
				# `cast_id` 0 e `teto` 0 = golpe avulso, sem orçamento — o mesmo
				# que a `DamageZone` do corpo a corpo sempre usou. Teto é coisa
				# de conjuração de fruta, onde dezenas de hitboxes irmãs somam;
				# aqui o "um acerto por corpo por golpe" é garantido pelo
				# `_ja_acertou` da própria lâmina.
				fio.armar(float(g["dano"]) * s, float(g["kb"]) * s,
					hitstun(i, weapon), 0, 0.0)
				# `hit_confirmed` alimenta a punição de whiff e o counter hit —
				# o caminho da caixa o marcava por `hit_landed`, e o do fio
				# marca pelo `acertou`. Mesma informação, outra fonte.
				if not fio.acertou.is_connected(_marcar_acerto):
					fio.acertou.connect(_marcar_acerto.bind(caster), CONNECT_ONE_SHOT)
				var fim := world.get_tree().create_timer(ativo(i, weapon) * s)
				fim.timeout.connect(func():
					if is_instance_valid(fio):
						fio.desarmar())
				# ⚠️ O `_impacto` NÃO É CHAMADO AQUI, e chamá-lo foi o erro
				# relatado pelo dono: "o efeito do combate corpo a corpo está
				# acontecendo ao invés do efeito da espada".
				#
				# `_impacto` desenha um ANEL DE CHOQUE (`TorusMesh`) — a onda que
				# o SOCO atravessa — nascendo a `alcance` metros à frente do
				# peito. Com o punho isso funciona, porque o punho de fato chega
				# lá. Com a espada o anel aparecia solto no ar, sem relação
				# nenhuma com onde a lâmina estava, e o que se via em tela era o
				# efeito do murro em cima de um golpe de espada.
				#
				# O corte tem os efeitos DELE: o rastro sai da lâmina (ver
				# `ProceduralAnimator.usar_lamina_no_rastro`) e o impacto nasce
				# na bolinha que encostou (ver `SwordBlade._no_corpo`). Os dois
				# vêm da arma, não de um ponto calculado à frente do corpo.
				AudioFX.whoosh(world, caster.global_position + Vector3.UP * 1.2,
					1.25 if i == 0 else 0.95)
				return

		var zone := DamageZone.new()
		world.add_child(zone)
		
		zone.hit_landed.connect(func(target):
			if is_instance_valid(caster) and "hit_confirmed" in caster:
				caster.hit_confirmed = true
		)
		
		# A hitbox segue o CORPO até o instante do soco. `origem` foi capturada no
		# clique, e agora o clique fica até 0,50 s à frente do impacto — correndo a
		# 4,2 m/s isso são 2,1 m de defasagem, ou seja a hitbox nascia ATRÁS do
		# jogador. A DIREÇÃO continua a do clique: o golpe se compromete com o lado
		# para onde você olhou ao apertar, e girar o mouse no meio não teleguia.
		zone.global_position = caster.global_position + Vector3.UP * alto + fwd * (float(g["alcance"]) * s)
		
		var forma: Shape3D = null
		if weapon == "sword":
			zone.is_weapon_swing = true
			# Cria uma BoxShape3D longa para simular o arco do corte da espada
			var box = BoxShape3D.new()
			box.size = Vector3(float(g["raio"]) * 2.0 * s, float(g["raio"]) * 0.5 * s, float(g["alcance"]) * 1.5 * s)
			forma = box
			zone.basis = Basis.looking_at(fwd, Vector3.UP)
			
		# DERRUBAR: o Finalizador põe o alvo no chão. `derruba` é campo público
		# da zona e precisa estar escrito ANTES do `setup`, porque é o `_on_body`
		# — disparado já no primeiro quadro de sobreposição — que o lê.
		zone.derruba = derruba(i, weapon)

		# vel = 0: a hitbox do corpo a corpo fica onde nasceu; alcance é o braço,
		# não um projétil.
		#
		# ⚠️ `ativo` NO LUGAR DE `vida`, e `hitstun` VINDO DA TABELA. O hitstun
		# era o default 0,30 s da assinatura da `DamageZone` nos quatro golpes —
		# metade da causa de a vantagem no acerto ser negativa (§2.3 do plano).
		# Agora é 0,75-0,80 s, declarado por golpe.
		zone.setup(float(g["dano"]) * s, float(g["kb"]) * s, Vector3.ZERO,
			ativo(i, weapon) * s, caster, float(g["raio"]) * s, forma, hitstun(i, weapon))
		_impacto(world, zone.global_position, i, cor_do_impacto(caster), s, fwd)
		
		# Dispara projétil se o passo definir
		if g.get("projetil", false):
			_spawn_air_slash(world, caster, fwd, g, s)
	)

# ============================================================================
#  PROJÉTIL: MEIA LUA (Corte Aéreo)
# ============================================================================
static func _spawn_air_slash(world: Node, caster: Node3D, fwd: Vector3, g: Dictionary, s: float) -> void:
	var proj := DamageZone.new()
	world.add_child(proj)
	proj.is_projectile = true
	proj.global_position = caster.global_position + Vector3.UP * (1.5 * s) + fwd * 2.0 * s
	proj.basis = Basis.looking_at(fwd, Vector3.UP)
	
	var box = BoxShape3D.new()
	box.size = Vector3(4.0 * s, 0.5 * s, 1.0 * s) # Larga e fina (meia-lua)
	
	# Velocidade do projétil: 25 m/s
	proj.setup(float(g["dano"]) * Balance.MELEE["projetil_mult"] * s, float(g["kb"]) * 1.5 * s, fwd * 25.0, 1.5, caster, 1.0, box)
	
	# Visual da meia-lua
	var m := MeshInstance3D.new()
	var meia_lua := TorusMesh.new()
	meia_lua.inner_radius = 1.8 * s
	meia_lua.outer_radius = 2.2 * s
	m.mesh = meia_lua
	
	var mat := StandardMaterial3D.new()
	var cor = cor_do_impacto(caster).lightened(0.2)
	mat.albedo_color = FxUtil.brilho(cor, 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	
	proj.add_child(m)
	# Rotaciona para ficar em pé, parecendo um arco vertical viajando para frente
	m.rotation = Vector3(PI/2.0, 0, 0)
	
	# Deleta a metade de trás do Torus girando e escalando, ou apenas deixa o anel inteiro brilhante viajando
	# Por simplicidade e robustez, usamos o Torus escalado.
	m.scale = Vector3(1.0, 0.2, 1.0)

# COR DO SOCO = cor do ESTILO em uso (pedido do dono, 2026-08-12: "quando
# equipado os efeitos do combate corpo a corpo mudam para azul" — o Tritão já é
# azul em `FightingStyles.STYLES["karate_tritao"]["cor"]`).
#
# Genérico de propósito. Um `if estilo == "karate_tritao": azul` resolveria hoje
# e obrigaria a mexer aqui a cada estilo novo; ler a cor que o estilo JÁ declara
# não custa mais e faz o Pacifista sair vermelho e o Mink amarelo de graça.
# No modo FRUTA fica o branco-quente de sempre: lá o soco é o golpe "sem poder",
# e pintá-lo da cor da fruta confundiria com as skills dela.
static func cor_do_impacto(caster: Node) -> Color:
	const PADRAO := Color(1.0, 0.95, 0.8)
	if caster == null or str(caster.get("combat_mode")) != "style":
		return PADRAO
	if not caster.has_method("estilo_atual"):
		return PADRAO
	var estilo: String = caster.estilo_atual()
	if not FightingStyles.STYLES.has(estilo):
		return PADRAO
	return FightingStyles.STYLES[estilo].get("cor", PADRAO)

# Fiapo visual do golpe: um anel achatado que abre e some no lugar do impacto.
# Curto de propósito — o corpo a corpo tem que ler pela ANIMAÇÃO, não por VFX.
## ⚠️ `dir` NÃO É OPCIONAL POR CAPRICHO. Antes o anel usava `m.rotation.x = PI/2`
## — uma rotação FIXA NO MUNDO. A posição acompanhava o soco, mas a orientação
## nunca mudava: socar para o norte e para o sul desenhava o mesmo anel virado
## para o mesmo lado, e de certos ângulos ele aparecia de perfil, como um risco.
##
## É o mesmo erro de classe do auto-mira invertido: uma direção assumida onde
## havia uma direção disponível.
static func _impacto(world: Node, pos: Vector3, i: int, cor: Color = Color(1.0, 0.95, 0.8), s_factor: float = 1.0, dir: Vector3 = Vector3.ZERO) -> void:
	AudioFX.whoosh(world, pos, 1.15 if i < 2 else 0.85)
	var m := MeshInstance3D.new()
	var anel := TorusMesh.new()
	anel.inner_radius = 0.25
	anel.outer_radius = 0.45
	m.mesh = anel
	var mat := StandardMaterial3D.new()
	mat.albedo_color = FxUtil.brilho(Color(cor.r, cor.g, cor.b, 0.55), 2.5)
	# A emissão é a mesma cor puxada pro brilho — `lightened` em vez de um segundo
	# valor escrito à mão, senão cada cor de estilo precisaria de DUAS entradas na
	# tabela e as duas poderiam divergir.
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat

	# ⚠️ DUAS CAMADAS, e não uma base composta. O anel fica PERPENDICULAR ao
	# golpe — uma onda de choque que o soco atravessa — e isso pede duas coisas
	# diferentes: APONTAR (que muda a cada golpe) e VIRAR O TORO (que é fixo,
	# porque o eixo de um `TorusMesh` nasce em +Y e precisa virar −Z).
	#
	# A primeira tentativa fez as duas numa `global_basis` composta. Não
	# sobreviveu: o tween anima `scale`, e escrever escala RECOMPÕE a base a
	# partir de rotação + escala guardadas — a decomposição não voltava igual e o
	# anel saía girado. Medido: |dot| ia de 0,85 a 0,00 conforme o rumo.
	#
	# Com o suporte APONTANDO e a malha girada em LOCAL, o tween mexe só na
	# escala do suporte e a orientação não é recalculada.
	var suporte := Node3D.new()
	world.add_child(suporte)
	suporte.global_position = pos
	if dir.length_squared() > 0.001:
		var plano := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
		suporte.look_at(pos + dir.normalized(), plano)
	suporte.add_child(m)
	# −90° em X leva o eixo do toro (+Y) para o −Z do suporte, que é para onde o
	# `look_at` aponta.
	m.rotation.x = -PI * 0.5

	var escala: float = (1.0 if i < 2 else 1.7) * s_factor
	var tw := suporte.create_tween()
	tw.set_parallel(true)
	tw.tween_property(suporte, "scale", Vector3.ONE * escala * 2.2, 0.20).from(Vector3.ONE * 0.3 * s_factor)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.20)
	tw.chain().tween_callback(suporte.queue_free)
