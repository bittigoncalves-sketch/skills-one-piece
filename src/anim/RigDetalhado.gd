class_name RigDetalhado
extends RefCounted
# ============================================================================
#  RIG DETALHADO — as juntas que o personagem base ganhou em 08/09/2026.
#
#  O `base_v2` (tools/blender/redesenhar_base.py) trouxe 126 juntas no lugar das
#  13 do rig A: uma coluna de verdade (SpineLower/SpineMid/Chest), cintura
#  escapular (Clavicle/Scapula), punho e mão com 19 ossos por lado, e o
#  antepé (Ball) sob o pé. Nada disso se mexia: o `ProceduralAnimator` só conhece
#  os 13 papéis, então o corpo novo andava com a mesma silhueta do corpo velho —
#  um tronco rígido, mãos de placa e o pé chapado no chão do começo ao fim.
#
#  Este arquivo é a CAMADA FINA: recebe o mesmo `_add` das poses de fruta e soma
#  offsets SÓ nas juntas novas. Ele nunca escreve num papel do rig A, com três
#  exceções declaradas e explicadas no lugar (`Head`, `Foot_*` e os `Elbow/Knee`).
#
#  ------------------------------------------------- POR QUE ARQUIVO SEPARADO
#  O `ProceduralAnimator` já está em 1.343 linhas, muito acima do teto de 900 do
#  projeto (docs/LIMITE_DE_TAMANHO.md), e a divisão que funciona lá é "separar o
#  que CRESCE" — foi assim que nasceu o `FruitPoses`. O detalhe do rig é
#  exatamente isso: cada junta que ganhar movimento (dedos na mira, dedos no
#  cabo da espada, pé no freio, ombro no bloqueio) entra AQUI, não lá.
#
#  ------------------------------------------------------ QUEM RECEBE O QUÊ
#  Só entra em cena quando a cadeia inteira existe (`tem_cadeia`). Personagem
#  voxel antigo (buggy) e skinnado (Meshy) não têm nenhum destes nós — medido:
#  buggy resolve 8 de 36 nomes, todos do rig A; nami, 0 de 36. Então não há
#  colisão possível e nada muda para eles, nem por acidente.
#
#  ---------------------------------------------- CONVENÇÃO DE EIXOS (medida)
#  Os nós do `base_v2_runtime.glb` são ALINHADOS AOS EIXOS DO JOGO — o
#  `test_base_v2` cobra isso ("runtime joint axes match game axes", erro < 1e-4).
#  Logo, para TODA junta:
#     rotation.x > 0  leva a ponta do membro para -Z  (FRENTE)
#     rotation.y > 0  gira o que está em +X para -Z   (ombro direito à frente)
#     rotation.z > 0  levanta o lado +X               (ombro direito para cima)
#  É por isso que os offsets aqui são espelhados em z (e não em x) entre L e R.
#
#  --------------------------------------- O QUE FICOU DE FORA, E COM GATILHO
#  • `Pelvis`  — é IRMÃO das coxas (as duas penduram no `Torso`), não pai delas.
#    Girar a pelve cisalharia o bloco do quadril para longe das pernas em vez de
#    levar a perna junto. O balanço de quadril que existe já está no `Torso`, que
#    É o osso do quadril neste rig. GATILHO: se a pelve ganhar geometria própria
#    que precise se mover sem as pernas (cinto, casaco, saia), ela volta.
#  • `ThighTwist`/`ShinTwist`/`UpperArmTwist` — torção não lê em membro de bloco
#    quadrado. GATILHO: quando o personagem receber malha contínua (skin), a
#    torção passa a valer e entra junto com o `ForeArmTwist`, que já está aqui
#    porque a pronação do antebraço muda a cara da MÃO, e a mão tem dedos.
#  • `Heel_*` — mesmo caso da pelve: é filho do pé, girar só arranca o calcanhar.
#    O calcanhar sobe girando o PÉ, que é o que `pe()` faz.
#  • Dedos do pé (30 juntas) — invisíveis dentro da bota, e o antepé inteiro já
#    se move pelo `Ball_*`, que é o pai deles. GATILHO: personagem descalço.
#  • Dedos da mão na MIRA — a pose de pistola (`_finger_gun`) ainda é feita só
#    com braço e antebraço. GATILHO: é o próximo uso óbvio destes 30 papéis.
# ============================================================================

# Papéis extras que o `BodyScanner` deve resolver quando a cadeia existir.
# É esta lista que decide o que o animador consegue mover — nome fora daqui é
# nó que existe no modelo e nunca recebe rotação.
const PAPEIS := [
	"SpineLower", "SpineMid", "Chest", "NeckUpper",
	"Clavicle_L", "Clavicle_R", "Scapula_L", "Scapula_R",
	"Elbow_L", "Elbow_R", "ForeArmTwist_L", "ForeArmTwist_R",
	"Wrist_L", "Wrist_R", "Hand_L", "Hand_R",
	"Knee_L", "Knee_R", "Ball_L", "Ball_R",
	"Index1_L", "Index2_L", "Index3_L", "Middle1_L", "Middle2_L", "Middle3_L",
	"Ring1_L", "Ring2_L", "Ring3_L", "Little1_L", "Little2_L", "Little3_L",
	"Thumb1_L", "Thumb2_L", "Thumb3_L",
	"Index1_R", "Index2_R", "Index3_R", "Middle1_R", "Middle2_R", "Middle3_R",
	"Ring1_R", "Ring2_R", "Ring3_R", "Little1_R", "Little2_R", "Little3_R",
	"Thumb1_R", "Thumb2_R", "Thumb3_R",
]

# Âncoras da detecção. Não uso metadado do CharacterBuilder de propósito: o rig
# se declara pela PRÓPRIA anatomia, então um personagem futuro que nasça com
# coluna e ombro entra sozinho, sem ninguém lembrar de marcar uma flag.
const ANCORAS := ["Chest", "SpineMid", "Clavicle_L", "Clavicle_R", "Wrist_R", "Ball_R"]

const DEDOS := ["Index", "Middle", "Ring", "Little"]
# Cascata: o mindinho fecha mais que o indicador. É o que separa mão viva de
# mão de manequim, e custa um multiplicador.
const CASCATA := {"Index": 0.86, "Middle": 1.0, "Ring": 1.06, "Little": 1.16}
# Curvatura de repouso das três falanges de um dedo relaxado (rad).
const REPOUSO_DEDO := [0.34, 0.46, 0.36]
const REPOUSO_POLEGAR := [0.20, 0.26, 0.20]

# ----------------------------------------------------- ESTABILIZAÇÃO DO OLHAR
# A cabeça pende no fim da coluna (Torso→SpineLower→SpineMid→Chest→Neck→
# NeckUpper→Head), então TUDO o que a coluna faz chega nela somado. Se ninguém
# devolver, o personagem anda olhando para o lado (torção) e corre encarando o
# chão (inclinação).
#
# ⚠️ ISTO NÃO É OPCIONAL E NÃO É CHUTE. Os coeficientes abaixo eram um número
# fixo (1,00) calibrado à mão para a torção de 1,70 da marcha; quando a corrida
# passou a torcer 2,22, o mesmo 1,00 deixava de fechar a conta. Agora a
# devolução é DERIVADA da soma que de fato foi aplicada — quem mexer numa
# amplitude de coluna não precisa lembrar de recalibrar a cabeça.
#
# Conta, em unidades de `ombro·sen(fase)` (yaw) ou de `lean` (pitch):
#     acumulado = quadril − coluna + legado_do_ProceduralAnimator
#     devolução = resíduo desejado − acumulado
# O resíduo é de propósito diferente de zero: cabeça 100% travada lê como olhar
# de manequim. Um resto mínimo LIDERA a curva no yaw e sobra à frente no pitch,
# que é o que dá a leitura de "determinado" em vez de "escaneando o horizonte".
const RESIDUO_OLHAR := -0.10        # yaw que sobra depois de tudo
const RESIDUO_PITCH := -0.15        # pitch que sobra (negativo = ainda p/ baixo)
# O que o `ProceduralAnimator._locomotion` JÁ escreve na `Head` por conta
# própria, e que portanto entra na soma. Mudou lá? Mude aqui.
const OLHAR_LEGADO := -0.40         # Head.y = −0,40·ombro·sen(fase)
const PITCH_LEGADO := 0.75          # Head.x = +0,75·lean
# De quanto da devolução fica no PESCOÇO. O resto vai na cabeça. Dividir é o que
# impede o giro de nascer no crânio, com o pescoço rígido embaixo.
const ESTABILIZA_PESCOCO := 0.35
const ESTABILIZA_PESCOCO_PITCH := 0.40

# ------------------------------------------------------------ NÚMEROS DA CORRIDA
# Somas dos coeficientes que a `corrida()` aplica na coluna. Ficam aqui, e não
# soltas lá dentro, porque a cabeça DERIVA delas quanto tem que devolver: um
# número aqui e outro lá é como o olhar já se perdeu uma vez.
const CORRIDA_TORCAO := 0.45 + 0.72 + 1.05   # yaw, em unidades de `ombro`
const CORRIDA_LEAN := 0.35 + 0.55            # pitch, em unidades de `lean`
# Retração dos ombros: os dois puxados para trás, peito aberto. É o que segura a
# silhueta de braço para trás sem transformar o ombro numa esfera parada.
const CORRIDA_RETRACAO := 0.15


static func tem_cadeia(achados: Dictionary) -> bool:
	for a in ANCORAS:
		if not achados.has(a):
			return false
	return true


# ---------------------------------------------------------------------- IDLE
# O idle do rig A já respira no `Torso` e troca o peso nas pernas. O que faltava
# era o corpo ACOMPANHAR: a respiração morria no quadril, o ombro não subia, e a
# mão era uma placa parada na ponta do braço.
#
# Três coisas entram aqui, nesta ordem de importância visual:
#  1. CONTRAPPOSTO — o `Torso` (quadril) rola num sentido, a coluna devolve no
#     outro. Sem isso o boneco é um tubo; com isso ele tem linha de ombro.
#  2. RESPIRAÇÃO QUE SOBE — o ar entra pelo abdômen (SpineLower) e termina no
#     peito e nos ombros (Chest + Clavicle), com atraso entre os elos.
#  3. MÃO RELAXADA — dedos semicurvados com cascata e um respiro lento por cima.
static func idle(add: Callable, off: Dictionary, w: float, arm_w: float, t: float) -> void:
	if w <= 0.001:
		return
	# MESMAS frequências do `_idle` (1.7 / 0.55 / 0.9 Hz) de propósito: se a
	# coluna respirasse noutro compasso, o corpo bateria contra si mesmo.
	var resp := sin(t * 1.7)
	var peso := sin(t * 0.55)
	var giro := sin(t * 0.9 + 1.0)

	# 1+2. Coluna. O `x` sobe pelos elos (o ar chega ao peito por último), o `z`
	# desfaz o rolamento do quadril, o `y` atrasa o giro do tronco.
	add.call(off, "SpineLower", Vector3(-0.008 * resp, 0.008 * giro, -0.012 * peso) * w)
	add.call(off, "SpineMid", Vector3(0.010 * resp, -0.012 * giro, -0.016 * peso) * w)
	add.call(off, "Chest", Vector3(0.018 * resp, -0.014 * giro, -0.020 * peso) * w)

	# Cintura escapular: os dois ombros SOBEM na inspiração (é o mesmo sinal de
	# `z` invertido entre os lados, porque +z levanta o lado +X). O termo de peso
	# baixa o ombro do lado cujo quadril subiu — a regra do contrapposto.
	var ombro_resp := 0.030 * resp
	var ombro_peso := 0.012 * peso
	add.call(off, "Clavicle_R", Vector3(0, -0.018 * giro, ombro_resp - ombro_peso) * w)
	add.call(off, "Clavicle_L", Vector3(0, -0.018 * giro, -ombro_resp + ombro_peso) * w)
	# A escápula desliza menos que a clavícula: é uma placa presa nas costas.
	add.call(off, "Scapula_R", Vector3(0, -0.010 * giro, 0.45 * (ombro_resp - ombro_peso)) * w)
	add.call(off, "Scapula_L", Vector3(0, -0.010 * giro, -0.45 * (ombro_resp - ombro_peso)) * w)

	# Pescoço em DOIS elos: o olhar já vinha da `Head` sozinha, o que fazia a
	# cabeça pivotar em cima de um poste. Dando um terço para o `NeckUpper`, o
	# pescoço ARQUEIA e a mesma varredura passa a ler como olhar, não como giro.
	add.call(off, "NeckUpper", Vector3(0.006 * resp, 0.030 * giro, -0.008 * peso) * w)

	# 3. Punho e mão. Amplitude pequena de propósito: a espada e as pistolas
	# penduram em `Weapon_R`/`Grip_*`, que são netos do punho — o que sobrar aqui
	# vira balanço de lâmina.
	var atraso := sin(t * 1.7 - 0.9)     # a mão chega depois do peito
	for lado in ["L", "R"]:
		var s := 1.0 if lado == "R" else -1.0
		# Pronação: a palma procura a coxa. Metade vai no osso de torção, que é
		# quem carrega a malha do antebraço — é para isso que ele existe.
		add.call(off, "Wrist_" + lado, Vector3(0.05 + 0.035 * atraso, -0.26 * s, 0.05 * s) * arm_w)
		add.call(off, "ForeArmTwist_" + lado, Vector3(0, -0.13 * s, 0) * arm_w)
		add.call(off, "Hand_" + lado, Vector3(0.08 + 0.030 * atraso, 0.02 * s, 0.03 * s) * arm_w)
	_dedos(add, off, arm_w, 0.045 * atraso)

	# Antepé: o peso passa de um pé para o outro e os dedos acompanham. Sem isto
	# o único par de juntas abaixo do tornozelo fica congelado em pé parado.
	add.call(off, "Ball_L", Vector3(0.05 * maxf(-peso, 0.0) + 0.012 * resp, 0, 0) * w)
	add.call(off, "Ball_R", Vector3(0.05 * maxf(peso, 0.0) + 0.012 * resp, 0, 0) * w)


# ------------------------------------------------------------------- MARCHA
# A caminhada humana é uma TORÇÃO: o quadril gira para um lado e a linha dos
# ombros para o outro, e é essa oposição que dá a sensação de passo. O rig A não
# tinha como fazer isso — o comentário do `_locomotion` dizia, com todas as
# letras, "o rig não tem osso de pelve, então o giro entra nas duas coxas". Só
# que girar as coxas gira as PERNAS, não o quadril: o passo saía torto e a
# torção do tronco, que é o que o olho lê, nunca existiu.
#
# Agora existe. O `Torso` (quadril) continua girando `+ombro·sen(fase)`; a coluna
# devolve 1,7× no sentido oposto, e o resultado é uma linha de ombros a 0,7× do
# quadril, contra ele. Quem consome isso: `ProceduralAnimator._locomotion`, que
# em troca DESLIGA o giro das coxas quando esta camada está no ar.
#
# `ombro` e `a_braco` vêm de lá prontos porque são a mesma calibragem: derivar
# de novo aqui seria duas fontes para o mesmo número.
# `a_braco` é a amplitude do balanço de braço deste quadro. Ela vem ZERADA no
# sprint, porque lá os braços ficam travados para trás (silhueta Naruto) e um
# ombro protraindo sozinho denunciaria a fraude. Tudo o que NÃO é balanço —
# torção do tronco, inclinação do peito, pronação — continua valendo.
static func marcha(add: Callable, off: Dictionary, w: float, arm_w: float,
		fase: float, ombro: float, a_braco: float, lean: float) -> void:
	if w <= 0.001:
		return
	var s := sin(fase)
	var c := cos(fase)

	# --- torção do tronco (o item principal) ---
	# Soma dos três elos = 1,70·ombro no sentido contrário ao quadril.
	add.call(off, "SpineLower", Vector3(0, -0.35 * ombro * s, 0) * w)
	add.call(off, "SpineMid", Vector3(-lean * 0.25, -0.55 * ombro * s, -0.012 * s) * w)
	# O peito também LIDERA a inclinação: no rig A todo o `lean` estava no
	# `Torso`, e inclinar o quadril arrasta as pernas (a IK tem que devolver o
	# `lean` na coxa justamente por isso). Aqui a parte de cima se inclina
	# sozinha, que é como um corredor de verdade entra na corrida.
	add.call(off, "Chest", Vector3(-lean * 0.45, -0.80 * ombro * s, -0.030 * s) * w)

	# --- cabeça: devolve o que o peito acabou de tirar ---
	# ⚠️ `Head`/`NeckUpper` são os únicos papéis do rig A que esta camada escreve,
	# e é obrigatório. Sem isto o personagem anda olhando para o lado (medido:
	# -9,1° de amplitude). A conta está em `_olhar_yaw`, que a corrida também usa.
	_olhar_yaw(add, off, w, ombro * s, 0.35 + 0.55 + 0.80)

	# --- cintura escapular ---
	# O ombro AVANÇA com o braço em vez de o braço sair de uma esfera parada.
	# Os dois lados usam a mesma expressão porque o cíngulo gira inteiro: quando
	# o direito vai à frente, o esquerdo vai atrás. `-c` porque o braço direito
	# está à frente quando cos(fase) é negativo (ver `_locomotion`).
	var protracao: float = 0.22 * a_braco
	var quique: float = 0.020 * sin(2.0 * fase)   # o ombro cai a cada pisada
	add.call(off, "Clavicle_R", Vector3(0, -protracao * c, quique) * arm_w)
	add.call(off, "Clavicle_L", Vector3(0, -protracao * c, -quique) * arm_w)
	add.call(off, "Scapula_R", Vector3(0, -0.5 * protracao * c, 0.5 * quique) * arm_w)
	add.call(off, "Scapula_L", Vector3(0, -0.5 * protracao * c, -0.5 * quique) * arm_w)

	# --- mão solta na ponta do braço ---
	# ATRASO CRESCENTE pela cadeia: o antebraço já vem 0,6 atrás do braço no
	# `_locomotion`; o punho fica 1,0 atrás e a mão 1,3. É a mesma ideia do
	# chicote — cada elo chega depois do anterior, e é isso que faz o braço
	# parecer que TEM peso em vez de ser uma haste.
	var a_mao: float = 0.75 * a_braco
	for lado in ["L", "R"]:
		var s_lado := 1.0 if lado == "R" else -1.0
		var fase_lado: float = fase if lado == "L" else fase + PI
		add.call(off, "Wrist_" + lado, Vector3(
			a_mao * cos(fase_lado - 1.0), -0.22 * s_lado, 0.04 * s_lado) * arm_w)
		add.call(off, "ForeArmTwist_" + lado, Vector3(0, -0.11 * s_lado, 0) * arm_w)
		add.call(off, "Hand_" + lado, Vector3(
			0.6 * a_mao * cos(fase_lado - 1.3), 0.02 * s_lado, 0.02 * s_lado) * arm_w)
	# A mão abre um pouco quando o braço vem à frente e fecha na volta.
	_dedos(add, off, arm_w, -0.10 * c)



# ------------------------------------------------------------------- CORRIDA
# O SPRINT (Shift) é a "silhueta Naruto": os dois braços apontados para trás,
# tronco jogado à frente. A silhueta continua — é a assinatura do personagem e o
# dono do projeto pediu para mantê-la —, mas ela era uma POSE, não uma animação:
#
#   MEDIDO na linha de base (tools/dev_tests/medir_corrida.gd, base a 7 m/s):
#     UpperArm  x  0,0°   <- os braços não se moviam. Nada. Só 3,7° de yaw.
#     ForeArm / Wrist / Hand ......... PARADOS
#     Clavicle / Scapula ............. 0,0° em y (nenhuma retração)
#     ombros ÷ quadril = 0,87        <- o tronco girava MENOS que a bacia
#     OLHAR REAL = -13,5°            <- corria encarando o chão
#
# O último item é um defeito que ficou escondido por dois anos de teste verde: o
# `test_walk_run` mede o olhar como `-Head.x - Torso.x` e a COLUNA está entre os
# dois, então os 24° de peito inclinado nunca entravam na conta. Ver
# `docs/erros.md`.
#
# ---------------------------------------------------------- O QUE MUDA, E POR QUÊ
#  1. TORÇÃO MAIOR que a marcha (2,22 contra 1,70). Corrida é o regime em que a
#     contra-rotação de tronco aparece mais, não menos: é ela que devolve o
#     momento angular que as pernas jogam a cada passada. MEDIDO depois: linha
#     de ombro a 1,45× o quadril, contra ele (era 0,87 — o tronco girava MENOS
#     que a bacia, que é o oposto do que uma corrida faz).
#  2. OMBROS RETRAÍDOS. Constante, os dois lados para trás, peito aberto — é o
#     que sustenta a silhueta de braço para trás sem que o braço saia de uma
#     esfera parada. Por cima dela, a alternância do cíngulo continua.
#  3. INCLINAÇÃO NO TRONCO SUPERIOR. O quadril fica onde está (é ele que o
#     `test_walk_run` cobra entre 10° e 15°, e a margem lá é de 1,1°); quem
#     inclina mais é peito e abdômen, que é onde um corredor de verdade dobra.
#  4. OLHAR CORRIGIDO EM PITCH, não só em yaw. Item 4 da lista acima.
#  5. MÃO DE CORTE. Dedos quase retos em vez da mão relaxada da caminhada — é a
#     mão da referência, e é o que sobra de silhueta na ponta do braço.
#
# `a_braco` aqui é a amplitude REAL do balanço do braço no sprint (o
# `_locomotion` deixou de mandar zero, porque o braço deixou de ser fixo).
static func corrida(add: Callable, off: Dictionary, w: float, arm_w: float,
		fase: float, ombro: float, a_braco: float, lean: float) -> void:
	if w <= 0.001:
		return
	var s := sin(fase)
	var c := cos(fase)

	# --- 1+3. coluna: torce mais que a marcha e inclina o tronco de cima ---
	# Os coeficientes de yaw somam CORRIDA_TORCAO e os de pitch, CORRIDA_LEAN.
	# Mexeu num? Mexa na constante — é dela que a cabeça deriva a devolução.
	add.call(off, "SpineLower", Vector3(0, -0.45 * ombro * s, -0.016 * s) * w)
	add.call(off, "SpineMid", Vector3(-lean * 0.35, -0.72 * ombro * s, -0.022 * s) * w)
	add.call(off, "Chest", Vector3(-lean * 0.55, -1.05 * ombro * s, -0.042 * s) * w)

	# --- 4. cabeça: devolve torção E inclinação ---
	_olhar_yaw(add, off, w, ombro * s, CORRIDA_TORCAO)
	_olhar_pitch(add, off, w, lean, CORRIDA_LEAN)

	# --- 2. cintura escapular: retraída, e viva ---
	# Convenção medida (cabeçalho do arquivo): y > 0 leva o ombro DIREITO à
	# frente e o esquerdo atrás — o cíngulo gira inteiro. Logo, para puxar os
	# DOIS para trás os sinais têm que ser opostos entre os lados; é só a parte
	# alternada que compartilha a mesma expressão.
	var retrac := CORRIDA_RETRACAO
	var alterna: float = 0.30 * a_braco * c
	# O ombro cai a cada pisada — duas por ciclo. Mais forte que na caminhada
	# porque a pisada da corrida é um impacto, não um apoio.
	var quique: float = 0.034 * sin(2.0 * fase)
	add.call(off, "Clavicle_R", Vector3(0, -retrac - alterna, quique) * arm_w)
	add.call(off, "Clavicle_L", Vector3(0, retrac - alterna, -quique) * arm_w)
	# A escápula ADUZ mais que a clavícula gira (é ela que junta as omoplatas nas
	# costas), mas desliza menos na alternância: é uma placa presa, não um eixo.
	add.call(off, "Scapula_R", Vector3(0, -0.70 * retrac - 0.5 * alterna, 0.5 * quique) * arm_w)
	add.call(off, "Scapula_L", Vector3(0, 0.70 * retrac - 0.5 * alterna, -0.5 * quique) * arm_w)

	# --- 5. punho e mão: a mão de corte, com atraso ---
	# O antebraço já vem 0,5 atrás do braço (`_locomotion`); o punho fica 0,9
	# atrás e a mão 1,2. Cada elo chega depois do anterior — é o que faz a ponta
	# do braço ter peso em vez de ser uma haste soldada.
	var a_mao: float = 0.55 * a_braco
	for lado in ["L", "R"]:
		var s_lado := 1.0 if lado == "R" else -1.0
		# ⚠️ MESMA convenção de fase do `_locomotion`: o braço do lado L anda com
		# `fase + PI`. Trocar aqui e esquecer lá põe a mão em contramão do
		# próprio braço, e o efeito de chicote vira tremor.
		var fase_lado: float = fase + PI if lado == "L" else fase
		# Palma voltada para dentro/para trás e punho ESTENDIDO: a mão continua a
		# linha do antebraço em vez de pender dela.
		add.call(off, "Wrist_" + lado, Vector3(
			-0.12 + a_mao * cos(fase_lado - 0.9), -0.30 * s_lado, 0.06 * s_lado) * arm_w)
		# PRONAÇÃO QUE ANDA COM O ARCO. Na `marcha` este osso recebe um valor
		# constante — postura, não movimento —, e é por isso que ele aparecia
		# como papel MUDO na varredura (item 5 do `medir_corrida`). Aqui a palma
		# roda ao longo do ciclo: ela se fecha contra o corpo quando o braço
		# volta e se abre no fim do empurrão. Amplitude pequena de propósito, pelo
		# motivo do cabeçalho — torção quase não lê em membro de bloco quadrado.
		# O que ela de fato muda é a cara da MÃO, que é filha deste osso.
		add.call(off, "ForeArmTwist_" + lado, Vector3(
			0, (-0.16 + 0.07 * cos(fase_lado - 1.1)) * s_lado, 0) * arm_w)
		add.call(off, "Hand_" + lado, Vector3(
			-0.06 + 0.6 * a_mao * cos(fase_lado - 1.2), 0.03 * s_lado, 0.02 * s_lado) * arm_w)
	# `curva` baixa = dedos quase retos. A mão da referência é uma lâmina, não um
	# punho fechado nem a mão relaxada de quem passeia.
	_dedos(add, off, arm_w, -0.05 * c, 0.18)


# ------------------------------------------------------------- PÉ: DESENROLA
# O `_perna_ik` deixa o pé CHAPADO durante todo o apoio ("pé toca completamente o
# chão", da spec). Certo no miolo do apoio, errado nas pontas: pé humano
# ATERRISSA de calcanhar e SAI de ponta. O `Ball_*` é a junta que faltava.
#
# ⚠️ O LIMITE QUE MANDA AQUI, E POR QUE O GIRO GRANDE NÃO PODE FICAR NO APOIO
# ---------------------------------------------------------------------------
# Marcha de verdade tem o tornozelo num U raso: alto na batida de calcanhar,
# baixo no meio do apoio, alto de novo na saída de ponta. A IK deste projeto o
# mantém RETO no chão durante o apoio inteiro. Consequência geométrica: girar o
# pé em volta de um tornozelo parado empurra uma quina para DENTRO do piso,
# sempre — não existe amplitude "de graça" no apoio.
#
# MEDIDO por `tools/dev_tests/medir_rig_detalhado.gd` (base a 1,5 m, WALK, ponto
# mais baixo da sola do pé de apoio, em unidades de jogo):
#     linha de base .............................. 0,1502
#     batida de calcanhar sozinha, a 0,14-0,24 ... 0,1407  (afunda 9,5 mm)
#     desprendimento sozinho, a 0,10-0,16 ........ 0,1383  (afunda 11,9 mm)
#     amplitudes de hoje (metade) ................ 0,1396  (afunda 10,6 mm)
#     empurrão no BALANÇO ........................ 0,0 mm  <- DE GRAÇA
# O mínimo do ciclo INTEIRO é igual ao do apoio: por mais que o pé se estenda no
# ar, ele nunca chega perto do chão. Metade da amplitude no apoio não devolve
# metade do afundamento porque as duas quinas que descem (calcanhar e dedos)
# giram em torno de pivôs diferentes — por isso o número é medido, não estimado.
#
# Daí o desenho: o giro GRANDE (0,34-0,62 rad) mora no início do balanço, onde é
# de graça e onde o olho lê "ele impulsionou"; no apoio ficam sobras de ~1 cm,
# no instante em que a bota está justamente rolando.
#
# CONTEXTO: em 08/09 o corpo do `base` pairava 13-14 cm ACIMA do piso ao andar, e
# este 1 cm não tinha chão para atravessar. A flutuação foi CONSERTADA em
# 01/10/2026 (`ProceduralAnimator._bob_dos_pes` media o pé contra a altura agachada
# da marcha, não contra a do repouso): andando, o pé mais baixo fica de −1,2 a
# +2,8 cm do piso; correndo, de −1,4 a +1,1 cm. Ou seja, AGORA o 1 cm do rolamento
# da bota encosta no chão — é a sola rolando, não erro.
#
# GATILHO para crescer: precisa da IK levantando o tornozelo na saída do apoio.
# Isso é mudança ACOPLADA — mexe na altura do quadril (`_bob_dos_pes` recalcula
# o corpo pelo pé mais baixo) e gasta o orçamento de 2 cm que o item "pé
# plantado" do `test_walk_run` guarda hoje intocado (varia 0,0000). É outra
# tarefa, com medição própria; nunca um número maior nesta função.
#
# `fase` é a MESMA passada ao `_perna_ik` desta perna (L recebe fase+PI).
static func pe(add: Callable, off: Dictionary, lado: String, fase: float,
		w: float, t: float) -> void:
	if w <= 0.001:
		return
	var ciclo: float = fposmod(fase, TAU)
	var pe_ang := 0.0
	var dedo_ang := 0.0
	if ciclo < PI:
		var u: float = ciclo / PI       # 0 = pisou agora, 1 = está saindo
		# ATERRISSAGEM: chega de ponta levantada e desaba nos primeiros 15%.
		var aterrissa: float = (1.0 - smoothstep(0.0, 0.15, u)) * lerpf(0.085, 0.145, t)
		# DESPRENDIMENTO no apoio: sobra. O empurrão de verdade é no balanço.
		var desprende: float = smoothstep(0.72, 1.0, u) * lerpf(0.05, 0.08, t)
		pe_ang = aterrissa - desprende
		dedo_ang = desprende             # dedos ficam no chão enquanto o pé gira
	else:
		# BALANÇO: o empurrão continua e devolve nos primeiros 45% do voo. O
		# `_perna_ik` já levanta a ponta na segunda metade (para o calcanhar
		# atacar o solo), e as duas curvas se cruzam sem briga.
		var v: float = (ciclo - PI) / PI
		var voo: float = sin(PI * clampf(v / 0.45, 0.0, 1.0)) * lerpf(0.34, 0.62, t)
		pe_ang = -voo
		dedo_ang = voo * 0.35            # dedos estendem no empurrão
	add.call(off, "Foot_" + lado, Vector3(pe_ang, 0, 0) * w)
	add.call(off, "Ball_" + lado, Vector3(dedo_ang, 0, 0) * w)


# ------------------------------------------------- TAMPAS DE JUNTA (cotovelo/joelho)
# `Elbow_*` e `Knee_*` carregam os blocos que TAPAM a dobra. No rig eles penduram
# no segmento de CIMA (o cotovelo é filho do braço, o joelho é filho da coxa),
# então quando o antebraço dobra 100° a tampa fica para trás e a dobra abre um
# rombo. O conserto é o de sempre em rig de bloco: a tampa faz METADE do ângulo
# do filho, e a dobra vira uma dobradiça em vez de um buraco.
#
# ⚠️ RODA DEPOIS DE TODOS OS GERADORES, não dentro do idle/marcha. A tampa tem
# que seguir a pose que de fato saiu — inclusive golpe, parkour e clipe de fruta,
# que dobram muito mais que uma caminhada. Ler o `off` já somado é o que dá isso
# de graça: uma fonte só, sem repetir a conta de ninguém.
static func juntas(add: Callable, off: Dictionary) -> void:
	for lado in ["L", "R"]:
		add.call(off, "Elbow_" + lado, (off.get("ForeArm_" + lado, Vector3.ZERO) as Vector3) * 0.5)
		add.call(off, "Knee_" + lado, (off.get("Shin_" + lado, Vector3.ZERO) as Vector3) * 0.5)


# ------------------------------------------------------------------- DEDOS
# Mão relaxada: as três falanges fecham em cascata, o mindinho mais que o
# indicador, o polegar de leve por cima. `extra` soma a todas — é por onde a
# respiração (idle) e o balanço do braço (marcha) chegam aos dedos.
# `curva` escala a curvatura de REPOUSO sem tocar no `extra` que respira por
# cima: 1,0 é a mão relaxada de quem anda, 0,18 é a mão de corte da corrida
# (dedos quase retos). Um parâmetro em vez de um segundo array porque a mão é a
# mesma — o que muda é o quanto ela fecha.
static func _dedos(add: Callable, off: Dictionary, w: float, extra: float,
		curva: float = 1.0) -> void:
	if w <= 0.001:
		return
	for lado in ["L", "R"]:
		for dedo in DEDOS:
			var k: float = CASCATA[dedo]
			for j in 3:
				add.call(off, "%s%d_%s" % [dedo, j + 1, lado],
					Vector3((REPOUSO_DEDO[j] * curva + extra) * k, 0, 0) * w)
		for j in 3:
			add.call(off, "Thumb%d_%s" % [j + 1, lado],
				Vector3(REPOUSO_POLEGAR[j] * curva + extra * 0.5, 0, 0) * w)


# ------------------------------------------------- DEVOLUÇÃO DO OLHAR (a conta)
# Fonte única da regra "a cabeça devolve o que a coluna tirou". Marcha e corrida
# chamam a mesma função com a SUA soma de coeficientes; ninguém recalibra a
# cabeça à mão quando muda uma amplitude de tronco. Ver o bloco `RESIDUO_*`.
#
# `unidade` é o termo que multiplica tudo: `ombro·sen(fase)` no yaw, `lean` no
# pitch. `coluna` é a soma dos coeficientes aplicados nos três elos de coluna.
static func _olhar_yaw(add: Callable, off: Dictionary, w: float,
		unidade: float, coluna: float) -> void:
	# quadril (+1) − coluna + o que o `_locomotion` já pôs na Head
	var acumulado: float = 1.0 - coluna + OLHAR_LEGADO
	var devolve: float = RESIDUO_OLHAR - acumulado
	add.call(off, "NeckUpper", Vector3(0, ESTABILIZA_PESCOCO * devolve * unidade, 0) * w)
	add.call(off, "Head", Vector3(0, (1.0 - ESTABILIZA_PESCOCO) * devolve * unidade, 0) * w)


static func _olhar_pitch(add: Callable, off: Dictionary, w: float,
		lean: float, coluna: float) -> void:
	# O `Torso` já se inclina −1·lean (é o `lean` do `_locomotion`), a coluna
	# soma mais −coluna·lean, e a Head recebe +PITCH_LEGADO·lean de volta.
	var acumulado: float = -1.0 - coluna + PITCH_LEGADO
	var devolve: float = RESIDUO_PITCH - acumulado
	add.call(off, "NeckUpper", Vector3(ESTABILIZA_PESCOCO_PITCH * devolve * lean, 0, 0) * w)
	add.call(off, "Head", Vector3((1.0 - ESTABILIZA_PESCOCO_PITCH) * devolve * lean, 0, 0) * w)
