class_name GuraPoses
extends RefCounted
# ============================================================================
#  GURA GURA NO MI — as animações autorais dos quatro golpes.
#
#  POR QUE ESTE ARQUIVO EXISTE (e não mais um bloco no `FruitPoses`)
#  ---------------------------------------------------------------
#  O `FruitPoses.gd` nasceu do corte de 2026-08-14 com um critério declarado:
#  "separar pelo que CRESCE". A Gura é hoje a única fruta com animação autoral
#  nos QUATRO slots — sozinha ela é maior que as seis poses das outras frutas
#  somadas. Deixá-la lá dentro faria o `FruitPoses` repetir a trajetória do
#  `ProceduralAnimator` (que bateu 864/900 e travou o V no meio do caminho).
#
#  ⚠️ O QUE ESTE ARQUIVO SUBSTITUIU: Z, X e C tocavam clipes GENÉRICOS do Mixamo
#  via `play_baked` — `right_upper_hook_from_guard`, `punching` e
#  `left_uppercut_from_guard`. Eram animações de boxeador, não do Barba Branca, e
#  o `play_baked` SOBREPÕE O CORPO INTEIRO (ver `_apply_baked`): durante o clipe
#  a locomoção, o parkour e a mira sumiam. As poses daqui SOMAM, que é o contrato
#  do projeto (`docs/frutas/gura_gura.md`).
#
#  ---------------------------------------------------------------------------
#  COMO UMA ANIMAÇÃO É ESCRITA AQUI
#  ---------------------------------------------------------------------------
#  Uma pose estática não é animação. Cada golpe é uma TABELA DE QUADROS-CHAVE
#  (`Dictionary` papel -> Euler) e a função interpola entre eles com a `fase` —
#  os segundos desde que o estado entrou, que o `ProceduralAnimator` zera a cada
#  troca de `custom_pose`.
#
#  As tabelas de um mesmo golpe têm SEMPRE AS MESMAS CHAVES. Não é estilo: o
#  `_mistura` percorre só as chaves de `a`, então um papel que existisse apenas
#  em `b` entraria de repente no meio da interpolação, com salto.
#
#  ---------------------------------------------------------------------------
#  CONVENÇÕES DO RIG (medidas neste projeto, não adivinhadas)
#  ---------------------------------------------------------------------------
#    Torso.x   NEGATIVO = tronco à FRENTE   (ver `gura_rush_pose`, FruitPoses)
#    Head.x    POSITIVO = olhar para CIMA   (compensa a inclinação do tronco)
#    UpperArm.z  ±1,4 = braço na HORIZONTAL — o T. O sinal é −L / +R, e o valor
#                em radianos ≈ o ângulo de elevação (1,4 rad ≈ 80°, medido 78°
#                pelo `medir_gura_rush.gd`). Por isso ~2,6 = braço bem alto.
#    UpperArm.x  +1,5 = braço apontando à FRENTE (−Z do modelo)
#    ForeArm.x   POSITIVO = cotovelo DOBRADO
#    Thigh.z   abre a perna de lado (−L / +R);  Shin.x NEGATIVO = joelho dobrado
#
#  O espelhamento de `is_backwards` e o filtro `_n.has(role)` viajam DENTRO do
#  `add` (é um Callable, não um atalho) — reimplementar aqui duplicaria regra.
# ============================================================================

# Nomes de `custom_pose` que este módulo desenha. Quem escreve a meta são os
# efeitos (`GuraVNode`, `GuraFX`); quem lê é o `ProceduralAnimator`. A lista
# existe para o animador não precisar conhecer os nomes um a um — e para o
# acoplamento por string ter UM lugar onde é conferido.
const GOLPES := [
	"gura_z_soco",        # Z  — o soco que fecha a investida
	"gura_x_arremesso",   # X  — o arremesso da esfera sísmica
	"gura_c_kabutsuchi",  # C  — o golpe de cima para baixo (erupção)
	"gura_v_lift",        # V  — armar a ultimate
	"gura_v_tpose",       # V  — A POSE DE T SOCANDO O AR (obrigatória)
]

# Golpes que tomam o CORPO INTEIRO (o animador zera a locomoção sob eles).
# O Z e o X não estão aqui de propósito: o soco do Z acontece no fim de uma
# corrida e as pernas têm que continuar correndo por baixo.
const CORPO_INTEIRO := ["gura_c_kabutsuchi", "gura_v_lift", "gura_v_tpose"]

# QUANDO O PUNHO CHEGA — segundos desde o início de cada golpe até o quadro de
# impacto. Quem dispara o efeito (`GuraFX`) começa a pose ANTES do estrago, por
# `atraso − IMPACTO_EM`, para a mão chegar JUNTO com a onda de choque.
#
# ⚠️ Não é number magic: o atraso do `GuraFX._punch` é `0,25 × mult`, e `mult`
# cresce com a carga (na investida do Z, `charge = 1.0` dá 0,42 s). Com a pose
# começando em zero, a mão chegava a 0,14 s e o chão rachava a 0,42 s — quase
# três décimos de dessincronia, que o olho lê como golpe que não conecta.
const Z_IMPACTO_EM := 0.14
const X_IMPACTO_EM := 0.20
const C_IMPACTO_EM := 0.34
# Até assentar. É quando o efeito devolve o corpo à locomoção.
const Z_DURACAO := 0.55
const X_DURACAO := 0.62
const C_DURACAO := 0.80

static func e_golpe(nome: String) -> bool:
	return GOLPES.has(nome)

static func toma_o_corpo(nome: String) -> bool:
	return CORPO_INTEIRO.has(nome)

# ============================================================================
#  DESPACHO
# ============================================================================
static func golpe(add: Callable, off: Dictionary, w: float, t: float, fase: float, estado: String) -> void:
	if w <= 0.001:
		return
	match estado:
		"gura_z_soco":       _z_soco(add, off, w, t, fase)
		"gura_x_arremesso":  _x_arremesso(add, off, w, t, fase)
		"gura_c_kabutsuchi": _c_kabutsuchi(add, off, w, t, fase)
		"gura_v_lift":       _v_armar(add, off, w, t, fase)
		"gura_v_tpose":      _v_tpose(add, off, w, t, fase)

# ============================================================================
#  V — A POSE DE T SOCANDO O AR   ⚠️ ANIMAÇÃO OBRIGATÓRIA DO PEDIDO
# ============================================================================
#
#  O pedido, palavra por palavra: "a pose de T especificamente na skill V
#  socando o ar e criando rachaduras com os tremores no ar invocando ondas".
#
#  O QUE ESTAVA ERRADO ANTES: o "soco" era um SALTO de um quadro entre
#  `gura_v_lift` (ombros em z=±0,8) e `gura_v_tpose` (z=±1,4), contando com o
#  filtro de rigidez para borrar a troca. Isso dá um braço que SOBE e para — a
#  leitura é "levantou os braços", não "socou". Um soco tem três tempos, e é a
#  ausência deles que o olho percebia:
#
#     RECUO  — o braço volta ANTES de ir. Sem isso não há soco, há um empurrão.
#     GOLPE  — passa DO ALVO (z=±1,55 > o T de ±1,40). O exagero de 0,15 rad é o
#              que vira "impacto"; parar exatamente no alvo lê como pose.
#     ASSENTA— volta para o T EXATO e FICA. É aqui que a pose obrigatória mora,
#              e é o quadro em que as rachaduras nascem das mãos.
#
#  O TREMOR não é enfeite: é a Gura Gura. Ele NUNCA zera enquanto o T é
#  sustentado (amplitude de sustentação 0,035 rad), porque um corpo parado
#  segurando um terremoto lê como boneco. Duas frequências primas entre si
#  (50 e 37 Hz) para o corpo não pulsar todo no mesmo compasso — é a mesma
#  disciplina do `_idle` do animador.
const _V_RECUO := {
	"Torso": Vector3(0.18, 0.0, 0.0),          # peito para trás: carrega o golpe
	"Head": Vector3(0.22, 0.0, 0.0),           # queixo erguido — o Barba Branca olha para cima
	"UpperArm_L": Vector3(-0.16, 0.0, -1.15),  # ombros AQUÉM do T e ATRÁS
	"UpperArm_R": Vector3(-0.16, 0.0, 1.15),
	"ForeArm_L": Vector3(0.30, 0.0, 0.0),      # cotovelos dobrados = mola armada
	"ForeArm_R": Vector3(0.30, 0.0, 0.0),
	"Thigh_L": Vector3(0.0, 0.0, -0.40),       # base larga e plantada
	"Thigh_R": Vector3(0.0, 0.0, 0.40),
	"Shin_L": Vector3(-0.30, 0.0, 0.0),
	"Shin_R": Vector3(-0.30, 0.0, 0.0),
	"Foot_L": Vector3(0.22, 0.0, 0.0),
	"Foot_R": Vector3(0.22, 0.0, 0.0),
}
const _V_GOLPE := {
	"Torso": Vector3(-0.14, 0.0, 0.0),         # o tronco SNAPA para a frente
	"Head": Vector3(0.06, 0.0, 0.0),
	"UpperArm_L": Vector3(0.42, 0.0, -1.55),   # PASSA do T e SOCA À FRENTE
	"UpperArm_R": Vector3(0.42, 0.0, 1.55),
	"ForeArm_L": Vector3(-0.12, 0.0, 0.0),     # braço ESTALA reto
	"ForeArm_R": Vector3(-0.12, 0.0, 0.0),
	"Thigh_L": Vector3(0.0, 0.0, -0.46),       # a base abre com o impacto
	"Thigh_R": Vector3(0.0, 0.0, 0.46),
	"Shin_L": Vector3(-0.42, 0.0, 0.0),        # joelho cede: o soco tem peso
	"Shin_R": Vector3(-0.42, 0.0, 0.0),
	"Foot_L": Vector3(0.30, 0.0, 0.0),
	"Foot_R": Vector3(0.30, 0.0, 0.0),
}
# ⚠️ ESTA É A POSE OBRIGATÓRIA. z=±1,40 é o T medido (elevação 78°, +0,55 para
# fora) e o `test_gura_tpose.gd` trava esses números. Mexer aqui quebra o pedido.
const _V_T := {
	"Torso": Vector3(-0.06, 0.0, 0.0),
	"Head": Vector3(0.12, 0.0, 0.0),
	"UpperArm_L": Vector3(0.0, 0.0, -1.40),    # O T
	"UpperArm_R": Vector3(0.0, 0.0, 1.40),
	"ForeArm_L": Vector3(-0.08, 0.0, 0.0),     # antebraço quase reto: o T é uma LINHA
	"ForeArm_R": Vector3(-0.08, 0.0, 0.0),
	"Thigh_L": Vector3(0.0, 0.0, -0.42),
	"Thigh_R": Vector3(0.0, 0.0, 0.42),
	"Shin_L": Vector3(-0.34, 0.0, 0.0),
	"Shin_R": Vector3(-0.34, 0.0, 0.0),
	"Foot_L": Vector3(0.26, 0.0, 0.0),
	"Foot_R": Vector3(0.26, 0.0, 0.0),
}

const V_RECUO_ATE := 0.07    # s — o braço volta
const V_GOLPE_ATE := 0.15    # s — e estala para fora (o quadro do impacto)
const V_ASSENTA_ATE := 0.30  # s — assenta no T e fica

static func _v_tpose(add: Callable, off: Dictionary, w: float, t: float, fase: float) -> void:
	var alvo: Dictionary
	if fase < V_RECUO_ATE:
		# Entra vindo do `gura_v_lift`; o recuo é o primeiro tempo do soco.
		alvo = _V_RECUO
	elif fase < V_GOLPE_ATE:
		# EASE_OUT (raiz): o golpe sai rápido e desacelera no fim do curso. Um
		# lerp linear aqui lê como braço empurrado por trilho.
		alvo = _mistura(_V_RECUO, _V_GOLPE, sqrt(_entre(fase, V_RECUO_ATE, V_GOLPE_ATE)))
	elif fase < V_ASSENTA_ATE:
		alvo = _mistura(_V_GOLPE, _V_T, _suave(_entre(fase, V_GOLPE_ATE, V_ASSENTA_ATE)))
	else:
		alvo = _V_T

	_aplicar(add, off, alvo, w)

	# TREMOR — forte no impacto, nunca zero na sustentação.
	var amp: float = 0.035 + 0.075 * (1.0 - clampf(fase / 0.45, 0.0, 1.0))
	var a := sin(t * 50.0) * amp
	var b := cos(t * 37.0) * amp
	add.call(off, "UpperArm_L", Vector3(b * 0.4, 0.0, -a) * w)
	add.call(off, "UpperArm_R", Vector3(b * 0.4, 0.0, a) * w)
	add.call(off, "Torso", Vector3(b * 0.5, a * 0.6, 0.0) * w)
	add.call(off, "Head", Vector3(a * 0.4, 0.0, b * 0.5) * w)

# ---- V, tempo 1: ARMAR ------------------------------------------------------
# A massa se juntando. Os braços sobem pelos lados até a meia-altura e o corpo
# AFUNDA — quem vai socar para cima primeiro desce. O tremor entra crescendo
# junto com a `fase`, para o corpo já estar vibrando quando o T chegar.
const _V_ARMAR_INI := {
	"Torso": Vector3(0.05, 0.0, 0.0),
	"Head": Vector3(0.10, 0.0, 0.0),
	"UpperArm_L": Vector3(0.0, 0.0, -0.25),
	"UpperArm_R": Vector3(0.0, 0.0, 0.25),
	"ForeArm_L": Vector3(0.15, 0.0, 0.0),
	"ForeArm_R": Vector3(0.15, 0.0, 0.0),
	"Thigh_L": Vector3(0.0, 0.0, -0.30),
	"Thigh_R": Vector3(0.0, 0.0, 0.30),
	"Shin_L": Vector3(-0.20, 0.0, 0.0),
	"Shin_R": Vector3(-0.20, 0.0, 0.0),
	"Foot_L": Vector3(0.15, 0.0, 0.0),
	"Foot_R": Vector3(0.15, 0.0, 0.0),
}
const _V_ARMAR_FIM := {
	"Torso": Vector3(0.20, 0.0, 0.0),
	"Head": Vector3(0.26, 0.0, 0.0),
	"UpperArm_L": Vector3(0.0, 0.0, -0.85),    # meia-altura: o T ainda não chegou
	"UpperArm_R": Vector3(0.0, 0.0, 0.85),
	"ForeArm_L": Vector3(0.34, 0.0, 0.0),
	"ForeArm_R": Vector3(0.34, 0.0, 0.0),
	"Thigh_L": Vector3(0.0, 0.0, -0.44),
	"Thigh_R": Vector3(0.0, 0.0, 0.44),
	"Shin_L": Vector3(-0.52, 0.0, 0.0),        # afunda: carrega as pernas
	"Shin_R": Vector3(-0.52, 0.0, 0.0),
	"Foot_L": Vector3(0.34, 0.0, 0.0),
	"Foot_R": Vector3(0.34, 0.0, 0.0),
}

static func _v_armar(add: Callable, off: Dictionary, w: float, t: float, fase: float) -> void:
	var k := _suave(_entre(fase, 0.0, 0.40))
	_aplicar(add, off, _mistura(_V_ARMAR_INI, _V_ARMAR_FIM, k), w)
	var amp := 0.012 + 0.030 * k                  # o tremor CRESCE com a carga
	var a := sin(t * 44.0) * amp
	add.call(off, "Torso", Vector3(a, 0.0, 0.0) * w)
	add.call(off, "UpperArm_L", Vector3(0.0, 0.0, -a) * w)
	add.call(off, "UpperArm_R", Vector3(0.0, 0.0, a) * w)

# ============================================================================
#  Z — O SOCO QUE FECHA A INVESTIDA
# ============================================================================
#
#  A pose de CORRIDA do Z (`gura_rush_pose`, braço direito aberto em meia-T)
#  NÃO foi tocada: ela é um pedido explícito do dono ("no Z a animação deveria
#  levantar o braço direito enquanto corre") e está travada em número pelo
#  `tools/dev_tests/medir_gura_rush.gd`. O que muda é o FIM da investida, que
#  antes era o clipe de boxe `right_upper_hook_from_guard` do Mixamo.
#
#  O braço já está aberto no lado quando o soco começa — então o golpe é um
#  CRUZADO que varre de fora para dentro e termina apontando à frente, e não um
#  jab. É o encaixe natural da meia-T que o jogador estava vendo, e é o soco do
#  Barba Branca: o braço vem de longe, com o corpo inteiro atrás.
#
#  Só o lado DIREITO é escrito. O esquerdo fica com a locomoção — durante a
#  investida as pernas continuam correndo por baixo (`CORPO_INTEIRO` não lista
#  este golpe), e um braço esquerdo autorado brigaria com a corrida.
const _Z_ARMA := {
	"Torso": Vector3(0.10, 0.35, 0.0),        # ombro direito ATRÁS: torção carregada
	"Head": Vector3(0.05, -0.20, 0.0),        # o olhar já foi para o alvo
	"UpperArm_R": Vector3(0.0, 0.0, 1.30),    # de onde a meia-T deixou o braço
	"ForeArm_R": Vector3(0.55, 0.0, 0.0),
}
const _Z_IMPACTO := {
	"Torso": Vector3(-0.22, -0.40, 0.0),      # a torção DESCARREGA para a frente
	"Head": Vector3(0.10, 0.10, 0.0),
	"UpperArm_R": Vector3(1.62, 0.0, 0.10),   # varre de fora até apontar à FRENTE
	"ForeArm_R": Vector3(-0.10, 0.0, 0.0),    # estala reto no impacto
}
const _Z_FIM := {
	"Torso": Vector3(-0.10, -0.22, 0.0),
	"Head": Vector3(0.08, 0.06, 0.0),
	"UpperArm_R": Vector3(1.30, 0.0, 0.30),   # o braço fica estendido, fumegando
	"ForeArm_R": Vector3(0.18, 0.0, 0.0),
}

static func _z_soco(add: Callable, off: Dictionary, w: float, t: float, fase: float) -> void:
	var alvo: Dictionary
	if fase < 0.06:
		alvo = _Z_ARMA
	elif fase < Z_IMPACTO_EM:
		alvo = _mistura(_Z_ARMA, _Z_IMPACTO, sqrt(_entre(fase, 0.06, Z_IMPACTO_EM)))
	else:
		alvo = _mistura(_Z_IMPACTO, _Z_FIM, _suave(_entre(fase, Z_IMPACTO_EM, 0.34)))
	_aplicar(add, off, alvo, w)
	# Tremor curto no braço que socou — só enquanto o impacto é recente.
	var amp: float = 0.06 * (1.0 - clampf(fase / 0.30, 0.0, 1.0))
	add.call(off, "UpperArm_R", Vector3(sin(t * 55.0) * amp, 0.0, 0.0) * w)

# ============================================================================
#  X — O ARREMESSO DA ESFERA SÍSMICA
# ============================================================================
#
#  A CARGA (`gura_x_charge_pose`, braço esticado à frente vibrando) continua no
#  `FruitPoses` e não mudou — ela é a "captura sísmica" e o jogador a segura.
#  Aqui é o que acontece quando ele SOLTA, e que antes era o `punching.res`.
#
#  O Barba Branca não empurra a esfera: ele AGARRA o ar, puxa por cima do ombro
#  e ARREMESSA. Por isso o primeiro quadro leva o braço para TRÁS DA CABEÇA
#  (UpperArm_R.x negativo com cotovelo muito dobrado) antes de qualquer coisa ir
#  para a frente — é o mesmo princípio de recuo do V, aplicado a um só braço.
const _X_PUXA := {
	"Torso": Vector3(0.16, 0.30, 0.0),
	"Head": Vector3(0.12, -0.12, 0.0),
	"UpperArm_R": Vector3(-0.55, 0.0, 0.55),   # mão atrás da cabeça
	"ForeArm_R": Vector3(1.45, 0.0, 0.0),      # cotovelo fechado: a esfera na mão
	"UpperArm_L": Vector3(0.70, 0.0, -0.30),   # esquerdo aponta o alvo (mira)
	"ForeArm_L": Vector3(0.25, 0.0, 0.0),
}
const _X_SOLTA := {
	"Torso": Vector3(-0.26, -0.34, 0.0),
	"Head": Vector3(0.10, 0.08, 0.0),
	"UpperArm_R": Vector3(1.70, 0.0, 0.05),    # o arremesso passa da frente
	"ForeArm_R": Vector3(-0.12, 0.0, 0.0),
	"UpperArm_L": Vector3(-0.35, 0.0, -0.45),  # o esquerdo desce como contrapeso
	"ForeArm_L": Vector3(0.30, 0.0, 0.0),
}
const _X_FIM := {
	"Torso": Vector3(-0.12, -0.18, 0.0),
	"Head": Vector3(0.08, 0.04, 0.0),
	"UpperArm_R": Vector3(1.35, 0.0, 0.20),
	"ForeArm_R": Vector3(0.15, 0.0, 0.0),
	"UpperArm_L": Vector3(-0.15, 0.0, -0.30),
	"ForeArm_L": Vector3(0.20, 0.0, 0.0),
}

static func _x_arremesso(add: Callable, off: Dictionary, w: float, t: float, fase: float) -> void:
	var alvo: Dictionary
	if fase < 0.10:
		# A puxada é LENTA de propósito: é ela que avisa o adversário que vem
		# coisa grande. Golpe pesado sem aviso vira dado, não duelo.
		alvo = _X_PUXA
	elif fase < X_IMPACTO_EM:
		alvo = _mistura(_X_PUXA, _X_SOLTA, sqrt(_entre(fase, 0.10, X_IMPACTO_EM)))
	else:
		alvo = _mistura(_X_SOLTA, _X_FIM, _suave(_entre(fase, X_IMPACTO_EM, 0.42)))
	_aplicar(add, off, alvo, w)
	var amp: float = 0.05 * (1.0 - clampf(fase / 0.35, 0.0, 1.0))
	add.call(off, "UpperArm_R", Vector3(sin(t * 48.0) * amp, 0.0, 0.0) * w)

# ============================================================================
#  C — KABUTSUCHI: O GOLPE DE CIMA PARA BAIXO
# ============================================================================
#
#  Este slot NÃO TINHA POSE NENHUMA — só o `left_uppercut_from_guard` do Mixamo,
#  que é um gancho de BAIXO PARA CIMA. O golpe abre uma erupção NO CHÃO
#  (`GuraFX._eruption` nasce em `y = 0,2`), então a animação contava a história
#  ao contrário: o braço subia e o chão explodia.
#
#  No mangá o Kabutsuchi é o golpe de cima para baixo — o Barba Branca ergue os
#  dois braços acima da cabeça e RACHA para baixo, como quem parte lenha. É o
#  arco mais legível que existe e é o que casa com a erupção.
#
#  z ≈ 2,6 põe os braços quase na vertical (o valor em radianos ≈ a elevação, e
#  1,4 já é a horizontal). Não uso 3,14: perto de 180° o Euler fica ambíguo e o
#  filtro de rigidez pode escolher o caminho longo — o braço daria a volta.
const _C_ERGUE := {
	"Torso": Vector3(0.34, 0.0, 0.0),          # arco para trás: pega impulso
	"Head": Vector3(0.30, 0.0, 0.0),           # olhando para as próprias mãos
	"UpperArm_L": Vector3(0.0, 0.0, -2.60),    # os dois braços ACIMA da cabeça
	"UpperArm_R": Vector3(0.0, 0.0, 2.60),
	"ForeArm_L": Vector3(0.20, 0.0, 0.0),
	"ForeArm_R": Vector3(0.20, 0.0, 0.0),
	"Thigh_L": Vector3(0.0, 0.0, -0.26),
	"Thigh_R": Vector3(0.0, 0.0, 0.26),
	"Shin_L": Vector3(-0.18, 0.0, 0.0),
	"Shin_R": Vector3(-0.18, 0.0, 0.0),
	"Foot_L": Vector3(0.14, 0.0, 0.0),
	"Foot_R": Vector3(0.14, 0.0, 0.0),
}
const _C_RACHA := {
	"Torso": Vector3(-0.70, 0.0, 0.0),         # dobra fundo sobre o ponto de impacto
	"Head": Vector3(0.30, 0.0, 0.0),           # cabeça segura o olhar à frente
	"UpperArm_L": Vector3(0.55, 0.0, -0.16),   # os braços descem à frente do corpo
	"UpperArm_R": Vector3(0.55, 0.0, 0.16),
	"ForeArm_L": Vector3(0.30, 0.0, 0.0),
	"ForeArm_R": Vector3(0.30, 0.0, 0.0),
	"Thigh_L": Vector3(0.20, 0.0, -0.50),      # AFUNDA: o peso do golpe vai ao chão
	"Thigh_R": Vector3(0.20, 0.0, 0.50),
	"Shin_L": Vector3(-0.95, 0.0, 0.0),
	"Shin_R": Vector3(-0.95, 0.0, 0.0),
	"Foot_L": Vector3(0.55, 0.0, 0.0),
	"Foot_R": Vector3(0.55, 0.0, 0.0),
}
const _C_FIM := {
	"Torso": Vector3(-0.40, 0.0, 0.0),
	"Head": Vector3(0.34, 0.0, 0.0),
	"UpperArm_L": Vector3(0.42, 0.0, -0.34),
	"UpperArm_R": Vector3(0.42, 0.0, 0.34),
	"ForeArm_L": Vector3(0.36, 0.0, 0.0),
	"ForeArm_R": Vector3(0.36, 0.0, 0.0),
	"Thigh_L": Vector3(0.12, 0.0, -0.42),
	"Thigh_R": Vector3(0.12, 0.0, 0.42),
	"Shin_L": Vector3(-0.70, 0.0, 0.0),
	"Shin_R": Vector3(-0.70, 0.0, 0.0),
	"Foot_L": Vector3(0.44, 0.0, 0.0),
	"Foot_R": Vector3(0.44, 0.0, 0.0),
}

# O `GuraFX._eruption` espera 0,4 s antes de abrir a cratera. Os tempos abaixo
# põem o RACHA em 0,34 s: as mãos chegam ao fundo pouco ANTES do chão abrir, que
# é a ordem que o olho aceita como causa e efeito.
static func _c_kabutsuchi(add: Callable, off: Dictionary, w: float, t: float, fase: float) -> void:
	var alvo: Dictionary
	if fase < 0.22:
		alvo = _C_ERGUE
	elif fase < C_IMPACTO_EM:
		alvo = _mistura(_C_ERGUE, _C_RACHA, sqrt(_entre(fase, 0.22, C_IMPACTO_EM)))
	else:
		alvo = _mistura(_C_RACHA, _C_FIM, _suave(_entre(fase, C_IMPACTO_EM, 0.62)))
	_aplicar(add, off, alvo, w)
	# Enquanto ergue, o tremor SOBE; depois do impacto, ele decai.
	var carga := clampf(fase / 0.22, 0.0, 1.0)
	var amp: float = (0.010 + 0.035 * carga) if fase < C_IMPACTO_EM else 0.070 * (1.0 - clampf((fase - C_IMPACTO_EM) / 0.40, 0.0, 1.0))
	var a := sin(t * 46.0) * amp
	add.call(off, "Torso", Vector3(a, 0.0, 0.0) * w)
	add.call(off, "UpperArm_L", Vector3(0.0, 0.0, -a) * w)
	add.call(off, "UpperArm_R", Vector3(0.0, 0.0, a) * w)

# ============================================================================
#  OFICINA
# ============================================================================

# Aplica uma tabela de quadro-chave inteira, já pesada. O `add` é quem espelha
# (`is_backwards`) e quem ignora papel que o rig não tem.
static func _aplicar(add: Callable, off: Dictionary, tabela: Dictionary, w: float) -> void:
	for papel in tabela:
		add.call(off, papel, (tabela[papel] as Vector3) * w)

# Interpola duas tabelas. Percorre as chaves de `a` — ver o aviso do cabeçalho
# sobre as tabelas de um mesmo golpe precisarem ter as mesmas chaves.
static func _mistura(a: Dictionary, b: Dictionary, k: float) -> Dictionary:
	var r := {}
	for papel in a:
		r[papel] = (a[papel] as Vector3).lerp(b.get(papel, Vector3.ZERO), k)
	return r

# Progresso 0..1 dentro de uma janela de tempo.
static func _entre(f: float, ini: float, fim: float) -> float:
	return clampf((f - ini) / maxf(fim - ini, 0.0001), 0.0, 1.0)

# Aceleração e desaceleração nas pontas (smoothstep).
static func _suave(k: float) -> float:
	return k * k * (3.0 - 2.0 * k)
