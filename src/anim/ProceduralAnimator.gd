class_name ProceduralAnimator
extends Node
# Gatilho: novas poses complexas são componentes externos; agachar em
# pose_agachar.gd. A divisão do animador legado permanece em tarefa própria.
const NadoPoses = preload("res://src/anim/nado_poses.gd")
const MontariaPoses = preload("res://src/anim/montaria_poses.gd")
const NavioPoses = preload("res://src/anim/navio_poses.gd")
const PescaPoses = preload("res://src/anim/pesca_poses.gd")
const PikaPoses = preload("res://src/anim/PikaPoses.gd")
const RocketPoses = preload("res://src/anim/rocket_poses.gd")
const OpePoses = preload("res://src/anim/OpePoses.gd")
const BaraPoses = preload("res://src/anim/BaraPoses.gd")
const GoroPoses = preload("res://src/anim/GoroPoses.gd")
const GomuPoses = preload("res://src/anim/GomuPoses.gd")
# Animação PROCEDURAL em tempo real do rig articulado (nós, não skinado).
# Lê o estado do Player (velocidade, corrida/shift, no chão, escalando, pitch da mira) e gera
# idle / walk / sprint-run / jump-fall / climb em runtime.

const SPEED_REF := 4.2     # SPEED do Player (para normalizar 0..1)
# Rigidez do lerp das juntas. 16 era folgado demais depois que a marcha passou a
# ter ciclo curto (11-25 quadros): o filtro atrasava e atenuava a perna, o pé
# plantado deixava de cancelar a subida do corpo e voltava a flutuar. 38 segue o
# alvo de perto sem perder a suavidade das transições (que têm blend próprio).
const STIFFNESS := 38.0
# Passadas por metro percorrido (cadência ligada à DISTÂNCIA, não ao tempo).
# Menor = animação de walk/run mais lenta e calma; maior = passos mais curtos/rápidos.
const STRIDE_GAIN := 1.0
# ------------------------------------------------------- RITMO DA MARCHA
# O personagem tem 1,5 m e anda a 4,2 m/s. Casar o pé com o chão nessa
# combinação exige ~7,9 passos por segundo (medido) — o dobro de um humano
# correndo, e era isso que deixava a animação frenética.
#
# ⚠️ LEIA ANTES DE MEXER (medido em 2026-08-10, os números anteriores aqui
# estavam errados: falavam em "8% de deslize", e o valor real é 45%):
#
#   deslize ≡ 1 − CADENCIA_ESCALA
#
# Isso é IDENTIDADE, não coincidência, e vale enquanto `CADENCIA_MAX` não morder:
# a velocidade do pé no apoio é passada/π·ω, e ω já traz a passada no
# denominador, então ela CANCELA. Consequências práticas:
#   • o deslize NÃO depende do porte do personagem (base 0,47 m de perna e nami
#     0,61 m dão os mesmos 45%), nem da passada, nem da altura do quadril;
#   • `CADENCIA_ESCALA` é a ÚNICA alavanca de deslize que existe aqui;
#   • quando `CADENCIA_MAX` morde, o deslize passa de 1 − CADENCIA_ESCALA sem
#     avisar (o teste tem um item só para pegar isso).
#
# As outras duas alavancas mexem no RITMO e na SILHUETA, não no deslize:
#   • ALTURA DO QUADRIL — agachar alonga o alcance do pé (√(alcance² − H²)), o
#     que alonga a passada e DERRUBA a cadência na mesma proporção. Como o
#     deslize não muda sozinho, ela só vira ganho de deslize se `CADENCIA_ESCALA`
#     subir junto, mantendo a cadência. Medido em base/WALK, cadência fixa:
#         H=0,80·perna → passada 0,49 m, deslize 45%, coxa  87°  (hoje)
#         H=0,70·perna → passada 0,59 m, deslize 34%, coxa 108°
#         H=0,60·perna → passada 0,65 m, deslize 26%, coxa 125°
#     Ou seja: dá para comprar deslize com agachamento, pagando em silhueta.
#   • `PASSADA_GANHO` está INERTE no regime de jogo: a passada pedida (1,52·perna
#     a plena velocidade) estoura o teto geométrico (1,13·perna) e é cortada por
#     ele. Trocar 1,6 por 1,3 não muda um milímetro na medição; só abaixo de ~1,1
#     o valor volta a ter efeito.
#
# Zerar o deslize mantendo a cadência de hoje exigiria passada 1,83× maior, ou
# seja, o quadril a 10 cm do chão numa perna de 47 cm: geometricamente
# impossível. Os 45% são o preço ESCOLHIDO para não virar hélice; o walk que saiu
# daqui foi aprovado pelo dono do projeto. O conserto de verdade é reduzir
# `Player.SPEED` — 4,2 m/s num corpo de 1,5 m é um humano a ~11 m/s.
const CADENCIA_ESCALA := 0.55
const PASSADA_GANHO := 1.6
# Teto da cadência (rad/s). Serve para as pernas não virarem hélice num pico de
# velocidade; no sprint normal a conta fica abaixo dele.
const CADENCIA_MAX := 30.0
# Altura do quadril como fração da perna esticada. Nunca 1.0: o joelho precisa
# sobrar dobrado, senão a IK satura e o pé sobe em vez de esticar.
const H_PARADO := 0.94
# ⚠️ ABAIXADOS EM 2026-08-27 (0,80/0,76 -> 0,70/0,66) para DESACELERAR a
# animação sem tocar no deslocamento — pedido do dono.
#
# A alavanca não é óbvia e vale registrar: a cadência sai de ω = π·v/passada, e a
# passada está travada por um TETO GEOMÉTRICO que depende da altura do quadril
# (com o quadril a H do chão, o pé só alcança sqrt(alcance² − H²)). Agachar um
# pouco levanta esse teto: a passada cresce, e como v é a mesma, a cadência CAI.
#
# Mexer em `PASSADA_GANHO` não fazia nada — a passada já estava saturada no teto.
# E mexer em `CADENCIA_ESCALA` desacelera, mas o deslize é `1 − ESCALA` (ver a
# identidade acima): para −18% de cadência ele iria de 45% para 55%, estourando
# o teto de 50% do `test_walk_run`. Por aqui o deslize NÃO muda.
#
# Medido (walk / run):
#   0,80 / 0,76   cadência 4,35 / 6,64   deslize 45-47%   coxa  87° /  84°
#   0,70 / 0,66   cadência 3,54 / 5,60   deslize 45-46%   coxa 112° / 107°
#   0,66 / 0,62   cadência 3,40 / 5,41   deslize 45-46%   coxa 122° / 116°
#
# O preço é a SILHUETA: passo maior, corpo um pouco mais agachado. É o preço que
# a geometria cobra por uma marcha mais calma nesta velocidade de jogo.
const H_CORRIDA := 0.70
const H_SPRINT := 0.66   # corrida agacha mais -> o pé alcança mais longe
# ------------------------------------------------------- SILHUETA DO SPRINT
# Onde os dois braços ficam parados no sprint, e o quanto eles balançam em torno
# disso. A BASE é a assinatura visual (braços apontados para trás) e o
# `test_walk_run` a cobra: a média relativa do braço tem que ficar <= −0,70 rad.
# O BALANÇO é simétrico, então ele não mexe nessa média — só na vida.
# Medido em 10/09/2026 (`tools/dev_tests/medir_corrida.gd`): com 0,32 o braço
# varre 33,9° e a média fica em −61,7° — o mesmo −61,9° de antes, dentro do
# arredondamento. O limite prático NÃO é o teste (que só cobra a média, e
# sobram 22°): é a silhueta. Com 0,32 o braço nunca passa de −44°, então ele
# continua inequivocamente atrás no ponto mais à frente do arco. Passar disso
# começa a ler como corrida comum no pico, que é justamente o que a pose evita.
## CORRIDA DO MIXAMO (03/10/2026). Pedido do dono: "tira a animação de correr do
## Naruto e coloca uma animação da Mixamo" — substitui a decisão antiga de manter a
## "silhueta Naruto" (braços travados para trás) como assinatura. Correndo, os
## clipes `running` e `sprint` (pipeline Mixamo → `tools/bake_mixamo.gd`) tomam o
## corpo; a marcha procedural fica para o começo da arrancada (velocidade baixa)
## e para quem não tem clipe (Mink galopa). A inclinação de curva, a de arrancada/
## frenagem e o giro do quadril do clipe somam POR CIMA.
const CLIPE_CORRIDA := "res://assets/animations/running.res"
const CLIPE_SPRINT := "res://assets/animations/sprint.res"
## Velocidade (m/s) em que o clipe começa a entrar / está inteiro.
const CORRIDA_VEL_MIN := 1.8
const CORRIDA_VEL_CHEIA := 3.0
## Mistura running → sprint pela velocidade (corrida 4,2; sprint 6,3).
const SPRINT_VEL_MIN := 4.9
const SPRINT_VEL_CHEIA := 6.0
## TETO DE CADÊNCIA (passos/s), o mesmo da marcha procedural (`test_walk_run`):
## personagem de perna curta (o `base`: 0,52 m, passada do clipe 0,91 m/ciclo)
## precisaria de 9 passos/s para o pé não patinar a 4,2 m/s — frenético. Acima do
## teto o clipe para de acelerar e o pé desliza; é a mesma troca já aceita.
const CADENCIA_MAX_CORRIDA := 5.0
const CADENCIA_MAX_SPRINT := 7.5
## O olhar não passa disto abaixo/acima do horizonte (o clipe do sprint encara o
## chão a −23,6°; critério do dono: até 12°, "não correr olhando pro chão").
const OLHAR_MAX := deg_to_rad(6.0)

var _n: Dictionary = {}     # papel -> Node3D
var _rest: Dictionary = {}  # papel -> Vector3 (rotação de descanso)
var _m: Dictionary = {}     # métricas do corpo
# 1.0 quando o corpo tem as juntas finas do `base_v2` (coluna, cintura escapular,
# punho/mão/dedos, antepé) — ver `src/anim/RigDetalhado.gd`. Fica em 0.0 no rig A
# (buggy) e nos skinnados, e é ELE que decide entre a torção de tronco de
# verdade e o remendo antigo que girava as coxas no lugar do quadril.
var _detalhe := 0.0
var _rest_torso_pos := Vector3.ZERO
var _posicoes_mp := preload("res://src/anim/posicoes_mine_piece.gd").new()
var _bob_suave := 0.0   # bob filtrado com a MESMA rigidez das juntas

var _phase := 0.0
var _air_w := 0.0
var _climb_w := 0.0
## NADO (01/10/2026, docs/AGUA_PLANO.md): lido do `modo_na_agua` do Player. Apaga a
## marcha e a pose de ar; crawl andando, "pedalar" parado.
var _swim_w := 0.0
var _swim_phase := 0.0
var _charge_w := 0.0        # peso da pose de "estilingue" (segurando a skill)
var _wallrun_w := 0.0       # parkour: corrida na parede (#3)
var _borda_w := 0.0         # pendurado na borda (escalada, fatia 3)
var _subida_w := 0.0        # subindo a borda (escalada, fatia 3)
var _roll_w := 0.0          # parkour: rolamento do pouso de precisão (#4)
var _ljump_w := 0.0         # parkour: salto longo / vault no ar (#1, #2)
var _gun_w := 0.0           # rajada Z (mera/hie): pose de dedo-revólver mirando
var _magu_z_w := 0.0
var _magu_z_soco := 0.0  # cursor armado(0) -> socando(1) da pose do Z da Magu
var _magu_x_w := 0.0
var _hibashira_w := 0.0     # pose de entrada e sustentação do Hibashira (soca o chão, pernas abertas)
var _mera_z_charge_w := 0.0 # peso da pose de preparo e saque das pistolas de fogo
var _mera_z_charge_progress := 0.0 # 0..1, relógio real da animação de saque
var _mera_x_charge_w := 0.0 # peso da concentração do Hiken (Jajanken: Pedra)
var _mera_x_charge_progress := 0.0
var _bomu_z_charge_w := 0.0
var _bomu_x_charge_w := 0.0
var _bomu_strike_w := 0.0
var _gura_x_charge_w := 0.0 # pose de carregamento da Skill X (braço direito esticado para captura)
var _gura_rush_w := 0.0     # pose assimétrica de investida do Barba Branca (braço direito levantado)
var _kurouzu_w := 0.0       # pose de atração do Kurouzu (braço à frente)
var _black_hole_w := 0.0    # pose do Barba Negra no Black Hole (pernas abertas, mão pro chão)
var _gura_golpe_w := 0.0    # peso do golpe autoral da Gura (src/anim/GuraPoses.gd)
var _gura_golpe_state := "" # QUAL golpe está tocando — nomes em GuraPoses.GOLPES
var _gura_golpe_t := 0.0    # segundos desde a troca de estado = a FASE da animação
var _pika_golpe_w := 0.0    # C/V autorais da luz (src/anim/PikaPoses.gd)
var _pika_golpe_state := ""
var _pika_golpe_t := 0.0
var _ope_golpe_w := 0.0
var _ope_golpe_state := ""
var _ope_golpe_t := 0.0
var _bara_golpe_w := 0.0
var _bara_golpe_state := ""
var _bara_golpe_t := 0.0
var _goro_golpe_w := 0.0
var _goro_golpe_state := ""
var _goro_golpe_t := 0.0
var _gomu_golpe_w := 0.0
var _ext_w := 0.0          # pose EXTERNA (meta `pose_externa`: Dictionary papel→Vector3 em rad, calculada por quem dirige o golpe — hoje a Ushi Ushi)
var _gomu_golpe_state := ""
var _gomu_golpe_t := 0.0
var _sword_w := 0.0         # peso da pose da espada de duas mãos
var _melee_stance_w := 0.0  # peso da postura de combate (pernas em V + guarda) durante o combo desarmado
var _melee_guarda: String = ""  # "" | "R" | "L" | "perna_R" | "perna_L" — ver play_baked()
var _dano_w := 0.0          # tranco de recepção de dano (src/mechanics/RecepcaoDeDano.gd)
var _knockdown_w := 0.0     # pose de queda no chão (src/mechanics/RecepcaoDeDano.gd)
var _recovery_t := 0.0      # timer do tranco elástico de recepção (chicote)
var _t := 0.0

var _hitstop_timer: float = 0.0
var _hitstop_shake: float = 0.0

func trigger_hitstop(duration: float, shake_intensity: float = 0.04) -> void:
	_hitstop_timer = duration
	_hitstop_shake = shake_intensity


# Clipe BAKED (ex.: Mixamo retargetado): dirige os nós por role, sobrepondo a
# animação procedural enquanto toca. Cada faixa tem path "<Role>:rotation".
var _baked: Animation = null
var _baked_t := 0.0
var _baked_speed := 1.0
var _baked_fim := -1.0   # fim da janela, em tempo de clipe. Ver play_baked().
## LOCOMOÇÃO POR ARMA (Epic Fight, 12/11/2026): os clipes `hold_*` (parado), `walk_*` e `run_*` da arma empunhada tocam em laço no lugar da marcha procedural,
## enquanto o corpo está no chão e sem golpe/pose de skill. Chave ausente = marcha procedural naquele estado. Ver `definir_locomocao_de_arma`.
var _loco_arma := {}
var _loco_t := 0.0
var _loco_chave := ""
## MOVIMENTO DO CORPO PELO CLIPE (Epic Fight, 12/11/2026): o clipe do mod traz o avanço do corpo em `Corpo:deslocamento` (ex. `battojutsu_dash` ≈ 10 m, autos ≤ 0,25 m).
## Ligado só para golpes (`movimento_do_clipe`): a cada quadro o corpo anda a diferença do deslocamento do clipe, para a frente do personagem, com colisão.
var movimento_do_clipe := false
## LIMITE DA DOBRA DO TRONCO nos golpes do Epic Fight (12/11/2026, queixa do dono: "as armas viram o personagem para baixo"): vários clipes do mod (espada longa, adaga, tachi)
## chegam com o `Torso` quase 90–115° inclinado já no 1º quadro (o mod reparte a dobra por 3 ossos da coluna; este rig tem 1). 0 = sem limite; em rad, só a INCLINAÇÃO
## (o giro do tronco sobre o próprio eixo fica). `play_baked` zera.
var limite_da_dobra_do_tronco := 0.0
## GIRO do quadril num golpe de clipe do Epic Fight (rad; 0 = sem limite). Os clipes do mod giram o corpo todo (o montante chega a ~115° só na antecipação), e com a câmera
## atrás do personagem isso lia como "ataca para trás" (pedido do dono, 13/11/2026). O corte limita só a torção em yaw do `Torso` (a raiz do clipe), o braço e a lâmina seguem o clipe.
var limite_do_giro_do_quadril := 0.0
## DESVIO de yaw do torso (rad) durante um golpe de clipe do EF: recentra o corte na mira (`RumoDosGolpes`, medido por `test_direcao_de_todas_as_armas_ef`).
var desvio_de_rumo_do_torso := 0.0
var _baked_segurar := false   # no fim da janela, congela a última pose em vez de soltar o clipe (morte)

# Presente só em personagens SKINNADOS: espelha os proxies nos ossos.
var _driver: SkeletonDriver = null

var _trail: WeaponTrail3D = null
var _trail_tip: Node3D = null

# ============================================================================
#  O RASTRO SAI DA LÂMINA, NÃO DO COTOVELO (2026-09-06)
# ============================================================================
#  Relato do dono: "o efeito do combate corpo a corpo está acontecendo ao invés
#  do efeito da espada". Uma das duas causas era esta.
#
#  O rastro era desenhado entre `ForeArm_R` (o COTOVELO) e um ponto chutado a
#  1,8 m dele. Com a Yoru na mão, a lâmina só começa 0,75 m depois do cotovelo —
#  então a faixa branca cobria o antebraço INTEIRO mais a lâmina, e em tela lia
#  como uma chapa saindo do peito, apontando para um lado enquanto a espada
#  apontava para outro.
#
#  Agora a arma DIZ onde ela começa e acaba. Quem não tem arma continua no
#  palpite antigo, que é reserva honesta e não caminho principal.
var _trail_base_arma: Node3D = null
var _trail_ponta_arma: Node3D = null
# O nó da ARMA em si. Ele recebe uma rotação própria durante o golpe (ver
# `WeaponPoses.postura_da_arma`): é o que controla a DIREÇÃO DO FIO sem tocar na
# mão que o segura.
var _arma: Node3D = null


## A arma assume o rastro. `base` é a guarda (onde o fio começa) e `ponta` é a
## ponta; os dois são nós DA ARMA, então acompanham a animação sem conta nenhuma.
func usar_lamina_no_rastro(base: Node3D, ponta: Node3D, arma: Node3D = null) -> void:
	_trail_base_arma = base
	_trail_ponta_arma = ponta
	_arma = arma
	if _trail != null and is_instance_valid(base) and is_instance_valid(ponta):
		_trail.target_base = base
		_trail.target_tip = ponta
		_trail.clear()


## Guardou a arma: o rastro volta ao palpite do braço e apaga o que estava em
## tela — sem o `clear` a última faixa fica congelada no ar apontando para uma
## espada que não existe mais.
func soltar_lamina_do_rastro() -> void:
	if is_instance_valid(_arma):
		_arma.rotation = Vector3.ZERO     # devolve a espada à pose neutra
	_arma = null
	_trail_base_arma = null
	_trail_ponta_arma = null
	if _trail != null:
		_trail.emit(false)
		_trail.clear()
		if _n.has("ForeArm_R"):
			_trail.target_base = _n["ForeArm_R"]
			_trail.target_tip = _trail_tip

const REC_DUR := 0.35       # duração da recepção (recovery)

# Toca um clipe retargetado (Animation com faixas <Role>:rotation) por cima do rig.
# `speed` acelera o clipe sem reassá-lo: os golpes do Mixamo são autorados em
# ~2 s, tempo demais para um combo de corpo a corpo encadeado em 2 s.
#
# `start` PULA o começo do clipe. Os golpes do Mixamo abrem com uma guarda parada
# (medido: o `right_upper_hook_from_guard` só mexe o braço aos 0,392 s de 1,77 s —
# 22% do clipe é pose de espera). Sem isso a única forma de o soco CONECTAR rápido
# é acelerar o clipe inteiro, e é a aceleração que borra qual braço saiu. Cortar a
# espera e tocar o golpe MAIS DEVAGAR dá as duas coisas: resposta e leitura.
var _sword_slash_type: int = -1
var _sword_slash_t: float = 0.0
var _sword_slash_speed: float = 1.0

# Fronteiras do golpe dentro do ciclo, em tempo normalizado. Vêm do frame data
# via `Melee.fracao_do_golpe`; os padrões só valem se ninguém disser.
var _sword_golpe_ini := WeaponPoses.GOLPE_INICIO_PADRAO
var _sword_golpe_fim := WeaponPoses.GOLPE_FIM_PADRAO

func play_procedural_slash(type: int, speed: float = 1.0,
		golpe_ini: float = WeaponPoses.GOLPE_INICIO_PADRAO,
		golpe_fim: float = WeaponPoses.GOLPE_FIM_PADRAO) -> void:
	_sword_golpe_ini = golpe_ini
	_sword_golpe_fim = golpe_fim
	_sword_slash_type = type
	_sword_slash_t = 0.0
	_sword_slash_speed = maxf(speed, 0.01)
	_baked = null # Cancela baked clip para liberar as pernas
	_baked_fim = -1.0

# `fim` = onde a JANELA do clipe fecha, em tempo de clipe. -1 (padrão) = toca
# até o fim do clipe, que é o que todo chamador fazia antes de 2026-08-25.
#
# ⚠️ POR QUE UMA JANELA. Com frame data o combo trava por 0,40 s e os clipes do
# Mixamo têm 1,37-2,23 s: sem corte, o braço continuaria voando por mais de um
# segundo depois de o corpo já estar livre, e o clique seguinte trocaria o
# clipe no meio do anterior. É o defeito de INTERRUPÇÃO de 2026-08-11 (ver o
# cabeçalho de `Melee.gd`), que travas 3x menores só agravariam.
#
# Cortar não é acelerar: a janela é escolhida em `Melee` para conter o golpe e
# descartar a volta à guarda, na velocidade natural do clipe.
## `segurar` = ao chegar no fim da janela, o corpo FICA na última pose (a morte: o corpo não
## levanta de novo) até outro `play_baked` — `play_baked(null)` solta.
func play_baked(anim: Animation, speed: float = 1.0, start: float = 0.0, melee_guarda: String = "", fim: float = -1.0, segurar := false) -> void:
	movimento_do_clipe = false
	limite_da_dobra_do_tronco = 0.0
	limite_do_giro_do_quadril = 0.0
	desvio_de_rumo_do_torso = 0.0
	_baked_segurar = segurar and anim != null
	_baked = anim
	_baked_t = 0.0 if anim == null else clampf(start, 0.0, maxf(anim.length - 0.01, 0.0))
	_baked_speed = maxf(speed, 0.01)
	_baked_fim = -1.0 if anim == null else (anim.length if fim < 0.0 else clampf(fim, _baked_t, anim.length))
	_sword_slash_type = -1 # Cancela procedural
	_melee_guarda = melee_guarda

## `clipes` = {hold, walk, run: Animation} (qualquer chave pode faltar). Vazio desliga.
func definir_locomocao_de_arma(clipes: Dictionary) -> void:
	_loco_arma = clipes
	_loco_t = 0.0
	_loco_chave = ""


func locomocao_de_arma_ativa() -> String:
	return _loco_chave


## Aplica o clipe de locomoção da arma (parado/andando/correndo). Devolve true se o corpo ficou por conta dele neste quadro.
func _aplicar_locomocao_de_arma(delta: float, speed01: float, on_floor: bool, climbing: bool, correndo: bool, carregando: bool, parkour: String,
		mira: bool, custom_pose: String, controle_agachar: Variant) -> bool:
	if _loco_arma.is_empty() or not on_floor or climbing or carregando or mira or parkour != "" or custom_pose != "":
		_loco_chave = ""
		return false
	if controle_agachar != null and controle_agachar.ativo:
		_loco_chave = ""
		return false
	var chave := "hold" if speed01 < 0.12 else ("run" if (correndo or speed01 > 0.8) else "walk")
	# GUARDA (RMB): a pose `guard_<categoria>` do mod, parada, enquanto o executor está em guarda (anda mais devagar pelo próprio executor).
	var pai := get_parent()
	var ex_g: Variant = pai.get("combate_direcional") if pai != null else null
	if _loco_arma.has("guard") and ex_g != null and ex_g.em_guarda():
		chave = "guard"
	var anim: Animation = _loco_arma.get(chave)
	if anim == null:
		_loco_chave = ""
		return false                               # sem clipe para este estado: marcha procedural
	if chave != _loco_chave:
		_loco_chave = chave
		_loco_t = 0.0
	# velocidade do passo acompanha a do corpo (o clipe de andar é a 0,5 e o de correr a 1,0 da velocidade de referência)
	var fator := 1.0 if (chave == "hold" or chave == "guard") else clampf(speed01 / (0.5 if chave == "walk" else 1.0), 0.6, 1.6)
	if chave == "guard":
		_loco_t = minf(_loco_t + delta, anim.length)          # entra na pose e a segura (não faz laço)
	else:
		_loco_t = fmod(_loco_t + delta * fator, maxf(anim.length, 0.05))
	for i in anim.get_track_count():
		var papel := String(anim.track_get_path(i)).get_slice(":", 0)
		if papel == "Corpo" or not _n.has(papel):
			continue
		var euler: Variant = anim.value_track_interpolate(i, _loco_t)
		if euler is Vector3:
			(_n[papel] as Node3D).rotation = euler
	if _driver:
		_driver.push()
	return true


func _mover_corpo_pelo_clipe(t0: float, t1: float) -> void:
	var corpo := get_parent() as CharacterBody3D
	if corpo == null or _baked == null:
		return
	for i in _baked.get_track_count():
		if String(_baked.track_get_path(i)) != "Corpo:deslocamento":
			continue
		var a: Variant = _baked.value_track_interpolate(i, minf(t0, _baked.length))
		var b: Variant = _baked.value_track_interpolate(i, minf(t1, _baked.length))
		if not (a is Vector3 and b is Vector3):
			return
		var d: Vector3 = (b as Vector3) - (a as Vector3)
		# o clipe é feito para um personagem olhando para −Z (o do jogo): x = lado, z = frente (negativo); o y (altura) o `Corpo:altura` cuida
		# A frente é a do MODELO (o `Player` não gira: quem vira é o `_char_model`). Com `corpo.global_basis` o avanço saía sempre para −Z do mundo, não para onde se golpeia.
		var modelo = corpo.get("_char_model")
		var base: Basis = (modelo as Node3D).global_basis if modelo is Node3D else corpo.global_basis
		var mundo := base * Vector3(d.x, 0.0, d.z)
		if mundo.length_squared() > 1e-8:
			corpo.move_and_collide(mundo)
		return


func is_playing_baked() -> bool:
	return _baked != null

func _apply_baked(delta: float) -> void:
	var t_antes := _baked_t
	_baked_t += delta * _baked_speed
	if movimento_do_clipe:
		_mover_corpo_pelo_clipe(t_antes, _baked_t)
	for i in _baked.get_track_count():
		var role := String(_baked.track_get_path(i)).get_slice(":", 0)
		if _n.has(role):
			var euler = _baked.value_track_interpolate(i, _baked_t)
			if euler is Vector3:
				(_n[role] as Node3D).rotation = euler
	if limite_da_dobra_do_tronco > 0.0 and _n.has("Torso"):
		_limitar_dobra_do_tronco()
	if desvio_de_rumo_do_torso != 0.0 and _n.has("Torso"):
		var tr := _n["Torso"] as Node3D
		tr.quaternion = Quaternion(Vector3.UP, desvio_de_rumo_do_torso) * tr.quaternion
	if limite_do_giro_do_quadril > 0.0 and _n.has("Torso"):
		var tronco := _n["Torso"] as Node3D          # o yaw do clipe mora em `Torso:rotation` (a raiz do mod é o Torso deste rig)
		tronco.rotation.y = clampf(wrapf(tronco.rotation.y, -PI, PI), -limite_do_giro_do_quadril, limite_do_giro_do_quadril)
	# Postura do combo desarmado (pernas em V + guarda + balanço de peso). É um
	# OVERRIDE sobre o clipe recém-copiado acima, e tem que rodar ANTES do
	# `_driver.push()` — senão nos personagens skinnados (Meshy) a postura nunca
	# chega aos ossos, só aparece nos voxel. Ver o cabeçalho de `MeleePoses.gd`
	# para o porquê deste bloco não usar o padrão `add.call(off, ...)`.
	if _melee_stance_w > 0.001 and _melee_guarda != "":
		var e_chute := _melee_guarda.begins_with("perna")
		var perna_ativa := _melee_guarda.get_slice("_", 1) if e_chute else ""
		var lado_guarda := "perna" if e_chute else _melee_guarda
		var pernas := MeleePoses.pernas_v(perna_ativa)
		var bracos := MeleePoses.guarda_bracos(lado_guarda)
		for papel in pernas:
			if _n.has(papel):
				var no := _n[papel] as Node3D
				no.rotation = no.rotation.lerp(_rest.get(papel, Vector3.ZERO) + pernas[papel], _melee_stance_w)
		for papel in bracos:
			if _n.has(papel):
				var no := _n[papel] as Node3D
				no.rotation = no.rotation.lerp(_rest.get(papel, Vector3.ZERO) + bracos[papel], _melee_stance_w)
		if _n.has("Torso"):
			var t_progresso := clampf(_baked_t / maxf(_baked.length, 0.001), 0.0, 1.0)
			var lado := 1.0 if _melee_guarda in ["R", "perna_R"] else -1.0
			(_n["Torso"] as Node3D).rotation += MeleePoses.balanco_torso(t_progresso, lado) * _melee_stance_w
	if _driver:
		_driver.push()
	# Fecha na JANELA, não no fim do clipe. `_baked_fim` só é menor que
	# `length` quando o passo tem frame data (ver `Melee.fim_da_janela`).
	var fim_da_janela := _baked.length if _baked_fim < 0.0 else _baked_fim
	if _baked_t >= fim_da_janela:
		if _baked_segurar:
			_baked_t = fim_da_janela      # segura a última pose
		else:
			_baked = null

## Se o eixo "para cima" do tronco inclina além do limite, reduz SÓ a inclinação até o limite (o giro sobre o próprio eixo, a "torção", fica).
func _limitar_dobra_do_tronco() -> void:
	var no := _n["Torso"] as Node3D
	var q := no.quaternion
	var cima := q * Vector3.UP
	var dobra := cima.angle_to(Vector3.UP)
	if dobra <= limite_da_dobra_do_tronco:
		return
	var inclinacao := Quaternion(Vector3.UP, cima)
	var torcao := inclinacao.inverse() * q
	no.quaternion = Quaternion.IDENTITY.slerp(inclinacao, limite_da_dobra_do_tronco / dobra) * torcao


func setup(profile: Dictionary) -> void:
	_pose_agachar = preload("res://src/anim/pose_agachar.gd").new()
	_n = profile.get("nodes", {})
	_rest = profile.get("rest", {})
	_m = profile.get("metrics", {})
	# Pergunta ao PERFIL, não ao id do personagem: quem resolve a cadeia é o
	# BodyScanner, e um personagem futuro com o mesmo rig entra sozinho.
	_detalhe = 1.0 if RigDetalhado.tem_cadeia(_n) else 0.0
	# Personagem SKINNADO: os nós acima são proxies; o driver copia a rotação
	# deles pros ossos do Skeleton3D depois que os geradores rodam.
	_driver = profile.get("driver")
	if _n.has("Torso"):
		_rest_torso_pos = (_n["Torso"] as Node3D).position
		if _driver:
			_driver.set_torso_rest(_rest_torso_pos)
			
	if _n.has("ForeArm_R"):
		if _trail == null:
			_trail = load("res://src/fx/WeaponTrail3D.gd").new()
			add_child(_trail)
		if _trail_tip == null:
			_trail_tip = Node3D.new()
			_n["ForeArm_R"].add_child(_trail_tip)
			# ⚠️ PALPITE, e assumido como tal: "ponta da espada PRESUMIDA em Y
			# negativo a partir da mão". Vale como reserva para quando não há uma
			# arma de verdade dizendo onde ela começa e acaba — ver
			# `usar_lamina_no_rastro`, que é o caminho preferido.
			_trail_tip.position = Vector3(0, -1.8, 0)

		if _trail_base_arma == null or not is_instance_valid(_trail_base_arma):
			_trail.target_base = _n["ForeArm_R"]
			_trail.target_tip = _trail_tip
		else:
			_trail.target_base = _trail_base_arma
			_trail.target_tip = _trail_ponta_arma
		_trail.life_time = 0.25
		_trail.startColor = Color(1.0, 1.0, 1.0, 0.6)
		_trail.endColor = Color(1.0, 1.0, 1.0, 0.0)

# Chamado todo frame pelo Player (suporta is_sprinting pelo Shift).
func update(velocity: Vector3, on_floor: bool, climbing: bool, delta: float, pitch: float, is_sprinting: bool = false, charging: bool = false, charge_slot: String = "", parkour: String = "", aim_gun: bool = false, gun_recoil: float = 0.0, mera_z_charge_progress: float = 0.0, gun_recoil_side: int = -1, mera_x_charge_progress: float = 0.0, custom_pose_override: String = "") -> void:
	var controle_agachar = get_parent().get("_agachar") if get_parent() != null else null
	_pose_agachar.atualizar(parkour == "agachar" or (controle_agachar != null and controle_agachar.ativo), delta)
	_posicoes_mp.restaurar()
	# Lentidão de skill (Noro Noro, 06/10/2026): o corpo lento AGE devagar — pose, passo
	# e transições andam no tempo dele.
	var lento := Lentidao.fator(get_parent()) if get_parent() != null else 1.0
	delta *= lento
	var real_delta := delta
	if _hitstop_timer > 0.0:
		_hitstop_timer -= real_delta
		delta = 0.0
	
	_t += delta
	# A entrada do Player é a fonte do quadro atual. A leitura no pai permanece
	# para chamadas antigas, mas um clipe de ataque não pode ocultar a preparação.
	var custom_pose: String = custom_pose_override if not custom_pose_override.is_empty() else (get_parent().get_meta("custom_pose", "") if get_parent() else "")
	if get_parent() != null and get_parent().has_meta("combate_mine_piece"):
		_baked = null
		_baked_fim = -1.0
		_melee_guarda = ""
	if custom_pose == "mera_x_charge" or custom_pose == "mera_z_charge" or custom_pose.begins_with("bomu_") or custom_pose.begins_with("magu_") or OpePoses.e_golpe(custom_pose) or GomuPoses.e_golpe(custom_pose) or BaraPoses.e_golpe(custom_pose) or custom_pose.begins_with("rocket_"):
		_baked = null
		_baked_fim = -1.0
		_melee_guarda = ""
	if get_parent() != null and (get_parent().get_meta("montado", false) or get_parent().get_meta("pilotando", false)):
		_baked = null
		_baked_fim = -1.0
	# CLIPE DE AÇÃO (roll do Q, deslize do Ctrl — 03/10/2026): o corpo inteiro
	# segue o clipe que o Player escolheu, no TEMPO que ele mandou (a física da
	# ação dirige o clipe). Entra em ~0,06 s; ao acabar, a marcha procedural
	# retoma suavizada a partir da pose em que o clipe deixou o corpo.
	if acao_clipe != "" and _clipe(acao_clipe).has("anim"):
		_acao_w = minf(_acao_w + real_delta * 18.0, 1.0)
		_baked = null
		_aplicar_acao(_acao_w * acao_peso)
		return
	_acao_w = 0.0
	# Clipe retargetado (Mixamo) sobrepõe TUDO enquanto toca.
	if _baked != null:
		_melee_stance_w = lerpf(_melee_stance_w, 1.0 if _melee_guarda != "" else 0.0, 1.0 - exp(-20.0 * delta))
		_apply_baked(delta)
		_pose_agachar.sobrepor_clipe(self, delta)
		if _hitstop_timer > 0.0 and _hitstop_shake > 0.0 and _n.has("Torso"):
			(_n["Torso"] as Node3D).rotation += Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * _hitstop_shake
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var speed01: float = clampf(planar / SPEED_REF, 0.0, 1.8)
	if _aplicar_locomocao_de_arma(delta, speed01, on_floor, climbing, is_sprinting, charging, parkour, aim_gun, custom_pose, controle_agachar):
		return

	# ---- pesos de estado (blend suave) ----
	var climb_target := 1.0 if climbing else 0.0
	_climb_w = lerpf(_climb_w, climb_target, 1.0 - exp(-14.0 * delta))

	var air_target := 0.0 if (on_floor or climbing) else 1.0
	_air_w = lerpf(_air_w, air_target, 1.0 - exp(-10.0 * delta))
	var nadando := get_parent() != null and str(get_parent().get("modo_na_agua")) == "nadando"
	_swim_w = lerpf(_swim_w, 1.0 if nadando else 0.0, 1.0 - exp(-8.0 * delta))

	var charge_target := 1.0 if charging else 0.0
	_charge_w = lerpf(_charge_w, charge_target, 1.0 - exp(-18.0 * delta))

	# ---- pesos PARKOUR (blend rápido; sobrepõem locomoção/ar) ----
	_wallrun_w = lerpf(_wallrun_w, 1.0 if parkour == "wall_run" else 0.0, 1.0 - exp(-16.0 * delta))
	_borda_w = lerpf(_borda_w, 1.0 if parkour == "borda" else 0.0, 1.0 - exp(-16.0 * delta))
	_subida_w = lerpf(_subida_w, 1.0 if parkour == "subindo_borda" else 0.0, 1.0 - exp(-20.0 * delta))
	_roll_w    = lerpf(_roll_w,    1.0 if parkour == "roll" else 0.0,     1.0 - exp(-22.0 * delta))
	_ljump_w   = lerpf(_ljump_w,   1.0 if parkour == "long_jump" else 0.0, 1.0 - exp(-12.0 * delta))
	_gun_w     = lerpf(_gun_w,     1.0 if aim_gun else 0.0,               1.0 - exp(-20.0 * delta))
	_hibashira_w  = lerpf(_hibashira_w,  1.0 if custom_pose == "hibashira" else 0.0,  1.0 - exp(-20.0 * delta))
	_magu_z_w = lerpf(_magu_z_w, 1.0 if custom_pose == "magu_z_prep" or custom_pose == "magu_z_soco" else 0.0, 1.0 - exp(-24.0 * delta))
	_magu_z_soco = lerpf(_magu_z_soco, 1.0 if custom_pose == "magu_z_soco" else 0.0, 1.0 - exp(-32.0 * delta))
	_magu_x_w = lerpf(_magu_x_w, 1.0 if custom_pose == "magu_x_surf" else 0.0, 1.0 - exp(-14.0 * delta))
	_mera_z_charge_w = lerpf(_mera_z_charge_w, 1.0 if custom_pose == "mera_z_charge" else 0.0, 1.0 - exp(-15.0 * delta))
	_mera_z_charge_progress = lerpf(_mera_z_charge_progress,
		clampf(mera_z_charge_progress, 0.0, 1.0) if custom_pose == "mera_z_charge" else 0.0,
		1.0 - exp(-30.0 * delta))
	_mera_x_charge_w = lerpf(_mera_x_charge_w, 1.0 if custom_pose == "mera_x_charge" else 0.0, 1.0 - exp(-18.0 * delta))
	_mera_x_charge_progress = lerpf(_mera_x_charge_progress,
		clampf(mera_x_charge_progress, 0.0, 1.0) if custom_pose == "mera_x_charge" else 0.0,
		1.0 - exp(-28.0 * delta))
	_bomu_z_charge_w = lerpf(_bomu_z_charge_w, 1.0 if custom_pose == "bomu_z_charge" else 0.0, 1.0 - exp(-22.0 * delta))
	_bomu_x_charge_w = lerpf(_bomu_x_charge_w, 1.0 if custom_pose == "bomu_x_charge" else 0.0, 1.0 - exp(-22.0 * delta))
	_bomu_strike_w = lerpf(_bomu_strike_w, 1.0 if custom_pose == "bomu_z_strike" or custom_pose == "bomu_x_burst" else 0.0, 1.0 - exp(-24.0 * delta))
	_kurouzu_w    = lerpf(_kurouzu_w,    1.0 if custom_pose == "kurouzu" else 0.0,    1.0 - exp(-20.0 * delta))
	_black_hole_w = lerpf(_black_hole_w, 1.0 if custom_pose == "black_hole" else 0.0, 1.0 - exp(-20.0 * delta))
	_gura_x_charge_w = lerpf(_gura_x_charge_w, 1.0 if custom_pose == "gura_x_charge" else 0.0, 1.0 - exp(-20.0 * delta))
	_gura_rush_w  = lerpf(_gura_rush_w,  1.0 if custom_pose == "gura_rush" else 0.0,  1.0 - exp(-25.0 * delta))
	# Pose do Skills Builder: toma o corpo enquanto existe (06/10/2026). Sem isto a
	# corrida do Mixamo, aplicada POR CIMA, apagava a pose num recuo (braço a 22° em vez
	# de 92° no "Soltar" da Noro Noro — medido).
	_pose_skill_w = lerpf(_pose_skill_w, 1.0 if get_parent() != null and get_parent().has_meta("pose_de_skill") else 0.0, 1.0 - exp(-20.0 * delta))
	# RECEPÇÃO DE DANO -> src/mechanics/RecepcaoDeDano.gd. Entra RÁPIDO (40) e sai
	# devagar (14): o tranco tem que bater na hora e relaxar depois. As poses de
	# fruta usam 15-25 nos dois sentidos porque são intenção, não impacto.
	var _quer_dano: bool = custom_pose == RecepcaoDeDano.POSE
	var _quer_knockdown: bool = custom_pose == RecepcaoDeDano.POSE_KNOCKDOWN
	_dano_w = lerpf(_dano_w, 1.0 if _quer_dano else 0.0,
		1.0 - exp(-(RecepcaoDeDano.RIGIDEZ_ENTRA if _quer_dano else RecepcaoDeDano.RIGIDEZ_SAI) * delta))
	_knockdown_w = lerpf(_knockdown_w, 1.0 if _quer_knockdown else 0.0,
		1.0 - exp(-(RecepcaoDeDano.RIGIDEZ_ENTRA if _quer_knockdown else RecepcaoDeDano.RIGIDEZ_SAI) * delta))
	
	# GOLPES AUTORAIS DA GURA (Z/X/C/V) — `src/anim/GuraPoses.gd`.
	# `_gura_golpe_t` é a FASE da animação: quem desenha interpola quadros-chave
	# com ela, então trocar de estado TEM que zerá-la. Sem isso o golpe seguinte
	# nasceria no fim da própria linha do tempo e o recuo do soco (o primeiro
	# tempo, o que faz o olho ler "soco" em vez de "braço subiu") nunca apareceria.
	if GuraPoses.e_golpe(custom_pose):
		if custom_pose != _gura_golpe_state:
			_gura_golpe_state = custom_pose
			_gura_golpe_t = 0.0
		_gura_golpe_t += delta
		_gura_golpe_w = lerpf(_gura_golpe_w, 1.0, 1.0 - exp(-15.0 * delta))
	else:
		_gura_golpe_w = lerpf(_gura_golpe_w, 0.0, 1.0 - exp(-15.0 * delta))
	if PikaPoses.e_golpe(custom_pose):
		if custom_pose != _pika_golpe_state:
			_pika_golpe_state = custom_pose
			_pika_golpe_t = 0.0
		_pika_golpe_t += delta
		_pika_golpe_w = lerpf(_pika_golpe_w, 1.0, 1.0 - exp(-18.0 * delta))
	else:
		_pika_golpe_w = lerpf(_pika_golpe_w, 0.0, 1.0 - exp(-18.0 * delta))
	if OpePoses.e_golpe(custom_pose):
		if custom_pose != _ope_golpe_state:
			_ope_golpe_state = custom_pose
			_ope_golpe_t = 0.0
		# O relógio do controller mantém estocada, gesto e VFX no mesmo instante.
		_ope_golpe_t = float(get_parent().get_meta("ope_pose_t", _ope_golpe_t + delta)) if get_parent() else _ope_golpe_t + delta
		_ope_golpe_w = lerpf(_ope_golpe_w, 1.0, 1.0 - exp(-30.0 * delta))
	else:
		_ope_golpe_w = lerpf(_ope_golpe_w, 0.0, 1.0 - exp(-18.0 * delta))
	if BaraPoses.e_golpe(custom_pose):
		if custom_pose != _bara_golpe_state:
			_bara_golpe_state = custom_pose
			_bara_golpe_t = 0.0
		_bara_golpe_t = float(get_parent().get_meta("bara_pose_t", _bara_golpe_t + delta)) if get_parent() else _bara_golpe_t + delta
		_bara_golpe_w = lerpf(_bara_golpe_w, 1.0, 1.0 - exp(-30.0 * delta))
	else:
		_bara_golpe_w = lerpf(_bara_golpe_w, 0.0, 1.0 - exp(-18.0 * delta))
	if GoroPoses.e_golpe(custom_pose):
		if custom_pose != _goro_golpe_state:
			_goro_golpe_state = custom_pose
			_goro_golpe_t = 0.0
		# O relógio vem do golpe quando ele publica `goro_pose_t` (é o caso da
		# carga do V, que não tem duração fixa); senão corre sozinho.
		_goro_golpe_t = float(get_parent().get_meta("goro_pose_t", _goro_golpe_t + delta)) if get_parent() else _goro_golpe_t + delta
		_goro_golpe_w = lerpf(_goro_golpe_w, 1.0, 1.0 - exp(-30.0 * delta))
	else:
		_goro_golpe_w = lerpf(_goro_golpe_w, 0.0, 1.0 - exp(-18.0 * delta))
	if GomuPoses.e_golpe(custom_pose):
		if custom_pose != _gomu_golpe_state:
			_gomu_golpe_state = custom_pose
			_gomu_golpe_t = 0.0
		_gomu_golpe_t = float(get_parent().get_meta("gomu_pose_t", _gomu_golpe_t + delta)) if get_parent() else _gomu_golpe_t + delta
		_gomu_golpe_w = lerpf(_gomu_golpe_w, 1.0, 1.0 - exp(-30.0 * delta))
	else:
		_gomu_golpe_w = lerpf(_gomu_golpe_w, 0.0, 1.0 - exp(-18.0 * delta))
	
	_ext_w = lerpf(_ext_w, 1.0 if get_parent() != null and get_parent().has_meta("pose_externa") else 0.0, 1.0 - exp(-30.0 * delta))
	var parent = get_parent()
	var weapon = parent.equipped_weapon if parent and "equipped_weapon" in parent else ""
	_sword_w = lerpf(_sword_w, 1.0 if weapon == "sword" else 0.0, 1.0 - exp(-10.0 * delta))
		
	var parkour_w: float = maxf(maxf(_wallrun_w, maxf(_borda_w, _subida_w)), maxf(_roll_w, _ljump_w))
	# as poses especiais assumem o corpo todo
	# ...mas nem todo golpe da Gura faz isso: o soco do Z fecha uma CORRIDA e as
	# pernas têm que continuar correndo por baixo dele (ver GuraPoses.CORPO_INTEIRO).
	var gura_corpo: float = _gura_golpe_w if GuraPoses.toma_o_corpo(_gura_golpe_state) else 0.0
	# Só o El Thor trava o jogador e domina as pernas. O V da Goro é canalizado
	# ANDANDO desde 2026-09-12, então fica fora daqui de propósito: incluí-lo
	# apagaria a corrida por baixo da pose.
	var goro_corpo: float = _goro_golpe_w if GoroPoses.toma_o_corpo(_goro_golpe_state) else 0.0
	# A mira de pistola domina também no ar. Sem retirar `_gun_w` daqui, a pose
	# aérea ainda somava os braços abertos por baixo da mira.
	var upper_free: float = (1.0 - parkour_w) * (1.0 - _gun_w) * (1.0 - _hibashira_w) * (1.0 - _kurouzu_w) * (1.0 - _black_hole_w) * (1.0 - _mera_z_charge_w) * (1.0 - _mera_x_charge_w) * (1.0 - _bomu_z_charge_w) * (1.0 - _bomu_x_charge_w) * (1.0 - _bomu_strike_w) * (1.0 - gura_corpo) * (1.0 - _pika_golpe_w) * (1.0 - _ope_golpe_w) * (1.0 - goro_corpo) * (1.0 - _gomu_golpe_w) * (1.0 - _bara_golpe_w) * (1.0 - _pose_skill_w) * (1.0 - _magu_z_w) * (1.0 - _magu_x_w) * (1.0 - _ext_w)

	var ground_w := (1.0 - _air_w) * (1.0 - _climb_w) * (1.0 - _swim_w)
	var loco_w: float = ground_w * smoothstep(0.05, 0.35, speed01) * upper_free
	var idle_w: float = ground_w * (1.0 - smoothstep(0.05, 0.25, speed01)) * upper_free
	var mink_galope := usa_corrida_mink(_raca_do_modelo(), is_sprinting)

	# ---- CORRIDA DO MIXAMO: peso e fase ----
	# Só no chão, fora de parkour/escalada/nado e de montaria; o Mink galopa.
	var montado: bool = get_parent() != null and (get_parent().get_meta("montado", false) or get_parent().get_meta("pilotando", false))
	var corrida_alvo := 0.0
	if on_floor and not climbing and parkour == "" and _swim_w < 0.5 and not mink_galope \
			and not montado and usar_clipe_de_corrida and _clipe(CLIPE_CORRIDA).has("anim"):
		corrida_alvo = smoothstep(CORRIDA_VEL_MIN, CORRIDA_VEL_CHEIA, planar)
	_corrida_w = lerpf(_corrida_w, corrida_alvo, 1.0 - exp(-12.0 * delta))
	_sprint_w = lerpf(_sprint_w, smoothstep(SPRINT_VEL_MIN, SPRINT_VEL_CHEIA, planar), 1.0 - exp(-8.0 * delta))
	if _corrida_w > 0.001:
		# A fase anda com a DISTÂNCIA (pé que não patina): um ciclo cobre a passada
		# que o clipe produz NESTE rig — medida nele (`_passada_no_rig`), porque o
		# clipe é retargetado por ângulo e a passada depende das proporções. A
		# estimativa por "alturas de quadril × perna" deixava 51 % de deslize.
		var ciclo_m: float = lerpf(_passada_no_rig(CLIPE_CORRIDA), _passada_no_rig(CLIPE_SPRINT), _sprint_w)
		var ciclos_s: float = minf(planar / maxf(ciclo_m, 0.1),
			lerpf(CADENCIA_MAX_CORRIDA, CADENCIA_MAX_SPRINT, _sprint_w) * 0.5)
		_corrida_u = fposmod(_corrida_u + delta * ciclos_s, 1.0)

	# ---- fase da marcha: DERIVADA DA PASSADA -> zero deslize ----
	# Enquanto um pé está no chão, ele tem que andar para trás EXATAMENTE na
	# velocidade do corpo. Cada perna fica em apoio metade do ciclo, e nessa
	# metade o corpo avança uma passada. Logo:
	#   T_ciclo = 2·passada / velocidade   ->   ω = π · velocidade / passada
	# (Usar 2π aqui, como eu tinha feito, deixa a cadência DOBRADA e o pé patina.)
	# A cadência passa a sair da geometria — perna curta dá passo mais rápido —
	# em vez de um fator mágico.
	var leg: float = maxf(_m.get("leg_len", 0.8), 0.3)
	var passada: float = _passada(speed01, is_sprinting)

	if climbing:
		# A escada anda com o corpo (03/10/2026): parado na parede, as mãos param.
		# 2,9 rad por metro: 2,2 m/s de subida ≈ 6,4 rad/s, o ritmo de antes.
		_phase += (absf(velocity.y) + planar) * 2.9 * delta
	elif parkour == "wall_run":
		_phase += maxf(planar, 3.5) * delta * (STRIDE_GAIN / leg)   # pernas correndo na parede
	elif on_floor and planar > 0.15:
		_phase += cadencia(planar, speed01, is_sprinting) * (1.18 if mink_galope else 1.0) * delta

	# ---- acumula offsets de rotação por junta ----
	var off: Dictionary = {}
	_idle(off, idle_w * (1.0 - _charge_w))
	_climb(off, _climb_w, _phase)
	# A marcha procedural cede o corpo ao clipe do Mixamo (ver `_aplicar_corrida`).
	_locomotion(off, loco_w * (1.0 - _corrida_w), _phase, speed01, is_sprinting)
	_air(off, _air_w * upper_free * (1.0 - _swim_w), velocity.y)
	_swim(off, _swim_w * upper_free, delta, speed01)
	_parkour(off, _phase)
	var buki_slot := str(get_parent().get("_buki_weapon")) if get_parent() != null and get_parent().get("_buki_weapon") != null else ""
	if buki_slot != "" and buki_slot != "X":
		_buki_pose(off, _gun_w, buki_slot, pitch, gun_recoil, speed01, is_sprinting)
	else:
		_finger_gun(off, _gun_w, pitch, gun_recoil, gun_recoil_side)
	if not is_instance_valid(get_parent().get("_yoru_combat")):
		WeaponPoses.two_handed_sword_idle(_add, off, _sword_w, _t)
	if _sword_slash_type >= 0:
		WeaponPoses.two_handed_sword_slash(_add, off, _sword_w, _sword_slash_t,
			_sword_slash_type, _sword_golpe_ini, _sword_golpe_fim)
		# ⚠️ A DIREÇÃO DO FIO ANDA NO RELÓGIO DO ANTEBRAÇO, não no do tronco.
		# Quem carrega a lâmina é o `ForeArm_R`, e ele usa o frame atrasado em
		# 0,06 (a cadeia cinética). Compensar com o frame do TRONCO deixava a
		# correção adiantada em relação ao que a estava causando: medido, a
		# lâmina ficava ótima no auge (89,1° da vertical) mas mergulhava a 55,9°
		# na ENTRADA da janela ativa. Mesmo atraso, mesma fase.
		if is_instance_valid(_arma):
			var fr := WeaponPoses._get_slash_frame(
				clampf(_sword_slash_t - 0.06, 0.0, 1.0),
				_sword_golpe_ini, _sword_golpe_fim)
			_arma.rotation = WeaponPoses.postura_da_arma(_sword_slash_type, fr) * _sword_w
		_sword_slash_t += delta * _sword_slash_speed
		
		# Emite o rastro apenas na parte veloz do golpe (durante a fase de strike)
		if _trail:
			# ⚠️ A JANELA DO RASTRO SEGUE O GOLPE, e era fixa em 0,18..0,32.
			# Com as fases vindo do frame data, deixar o rastro num intervalo
			# escrito à mão o faria brilhar antes ou depois do corte. Um pouco
			# antes e um pouco depois de propósito: rastro que começa no mesmo
			# quadro do dano não tem tempo de desenhar arco nenhum.
			if _sword_slash_t >= _sword_golpe_ini - 0.04 \
					and _sword_slash_t <= _sword_golpe_fim + 0.08:
				_trail.emit(true)
			else:
				_trail.emit(false)
		
		if _sword_slash_t >= 1.0:
			_sword_slash_type = -1
			if is_instance_valid(_arma):
				_arma.rotation = Vector3.ZERO
			if _trail:
				_trail.emit(false)
			
	FruitPoses.hibashira_pose(_add, off, _hibashira_w, _t)
	MaguPoses.soco(_add, off, _magu_z_w, _magu_z_soco, _t)
	MaguPoses.surf(_add, off, _magu_x_w, _t)
	FruitPoses.mera_z_charge_pose(_add, off, _mera_z_charge_w, _mera_z_charge_progress)
	FruitPoses.mera_x_charge_pose(_add, off, _mera_x_charge_w, _mera_x_charge_progress)
	FruitPoses.bomu_charge_pose(_add, off, _bomu_z_charge_w, _t, "Z")
	FruitPoses.bomu_charge_pose(_add, off, _bomu_x_charge_w, _t, "X")
	FruitPoses.bomu_strike_pose(_add, off, _bomu_strike_w, _t, custom_pose == "bomu_x_burst")
	FruitPoses.kurouzu_pose(_add, off, _kurouzu_w, _t)
	FruitPoses.black_hole_pose(_add, off, _black_hole_w, _t)
	FruitPoses.gura_rush_pose(_add, off, _gura_rush_w, _t) # Pose assimetrica sobreposta
	FruitPoses.gura_x_charge_pose(_add, off, _gura_x_charge_w, _t)
	_mink_combat_pose(off, custom_pose)
	GuraPoses.golpe(_add, off, _gura_golpe_w, _t, _gura_golpe_t, _gura_golpe_state)
	PikaPoses.golpe(_add, off, _pika_golpe_w, _t, _pika_golpe_t, _pika_golpe_state)
	OpePoses.golpe(_add, off, _ope_golpe_w, _t, _ope_golpe_t, _ope_golpe_state)
	BaraPoses.golpe(_add, off, _bara_golpe_w, _t, _bara_golpe_t, _bara_golpe_state)
	GoroPoses.golpe(_add, off, _goro_golpe_w, _t, _goro_golpe_t, _goro_golpe_state)
	GomuPoses.golpe(_add, off, _gomu_golpe_w, _t, _gomu_golpe_t, _gomu_golpe_state)
	RocketPoses.aplicar(off, custom_pose, float(get_parent().get_meta("rocket_pose_t", 0.0)))
	if _ext_w > 0.001 and get_parent() != null and get_parent().has_meta("pose_externa"):
		var ext: Dictionary = get_parent().get_meta("pose_externa")
		for papel: String in ext:
			_add(off, papel, (ext[papel] as Vector3) * _ext_w)
	# Pose do Skills Builder (06/10/2026): deslocamentos por junta já com a transição
	# feita pelo `ExecutorDeSkill` (a mesma conta da prévia do Builder).
	# `get_meta(k, null)` NÃO cala o erro: padrão nulo conta como "sem padrão" no Godot 4.
	var pose_skill: Variant = get_parent().get_meta("pose_de_skill") if get_parent() != null and get_parent().has_meta("pose_de_skill") else null
	if pose_skill is Dictionary:
		for papel in pose_skill:
			_add(off, str(papel), pose_skill[papel])
	# Clipes de animação do JOGADOR do Mine Piece (PoseDoMod/AnimacaoDoMod): mesmo caminho da pose do Builder.
	var pose_mod: Variant = get_parent().get_meta("pose_do_mod") if get_parent() != null and get_parent().has_meta("pose_do_mod") else null
	if pose_mod is Dictionary:
		for papel in pose_mod:
			_add(off, str(papel), pose_mod[papel])
	if custom_pose in ["rocket_z", "rocket_c"]:
		_add(off, "UpperArm_R", Vector3(float(get_parent().get_meta("rocket_pitch", 0.0)), 0, 0))
	# POR ÚLTIMO entre as poses: o tranco de dano SOMA por cima do que o corpo já
	# estava fazendo. É o que faz levar um tiro correndo continuar lendo como corrida.
	RecepcaoDeDano.pose(_add, off, _dano_w, _t)
	RecepcaoDeDano.pose_knockdown(_add, off, _knockdown_w, _t)
	_charge(off, _charge_w, charge_slot)
	
	# Se não estiver em charge, mas tem charge_slot = "C" (Gatling firing) -> aplica shake no torso.
	# NUNCA durante a pose de pistola (aim_gun), senão sacode a mira.
	if not charging and charge_slot == "C" and not aim_gun:
		_add(off, "Torso", Vector3(randf_range(-0.06, 0.06), randf_range(-0.1, 0.1), randf_range(-0.05, 0.05)))
		_add(off, "Head", Vector3(0, 0, 0)) # estabiliza
		
	_recovery(off, delta)
	_lookat(off, pitch, ground_w * (1.0 - _charge_w) * (1.0 - _ope_golpe_w) * (1.0 - _bara_golpe_w), delta)

	if get_parent() != null and get_parent().get_meta("montado", false):
		if get_parent().get_meta("bicicleta_gelo", false):
			MontariaPoses.bicicleta(off, _n, float(get_parent().get_meta("bicicleta_fase", 0.0)))
		else:
			MontariaPoses.aplicar(off, _n, _t, planar, get_parent().get_meta("montaria_larga", false))
	if get_parent() != null and get_parent().get_meta("pilotando", false):
		NavioPoses.aplicar(off, _n, _t, float(get_parent().get_meta("leme_direcao", 0.0)))
	# PESCA (03/10/2026): braços na vara POR CIMA da marcha — as pernas seguem andando.
	# A última pose fica guardada para o braço voltar suave quando a vara sai.
	var pose_pesca: String = str(get_parent().get_meta("pesca_pose", "")) if get_parent() != null else ""
	if not pose_pesca.is_empty():
		_pesca_pose = pose_pesca
	_pesca_w = lerpf(_pesca_w, 1.0 if not pose_pesca.is_empty() else 0.0, 1.0 - exp(-16.0 * delta))
	if _pesca_w > 0.001:
		PescaPoses.aplicar(off, _n, _t, _pesca_pose, float(get_parent().get_meta("pesca_fase", 0.0)),
			bool(get_parent().get_meta("pesca_girando", false)), _pesca_w)

	preload("res://src/anim/alimentacao_poses.gd").aplicar(off, get_parent())

	# POR ÚLTIMO, depois de TODO gerador: as tampas de cotovelo e joelho copiam
	# metade da dobra que sobrou no `off`. Aqui elas valem para qualquer pose —
	# marcha, golpe, parkour ou clipe do Mixamo — porque leem o resultado, não a
	# fórmula de quem escreveu.
	if _detalhe > 0.0:
		RigDetalhado.juntas(_add, off)

	if _hitstop_timer > 0.0 and _hitstop_shake > 0.0:
		_add(off, "Torso", Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * _hitstop_shake)
		_add(off, "UpperArm_R", Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * _hitstop_shake)
		_add(off, "UpperArm_L", Vector3(randf_range(-1,1), randf_range(-1,1), randf_range(-1,1)) * _hitstop_shake)

	_pose_agachar.aplicar(self, off, velocity, real_delta,
		not custom_pose.is_empty() or charging or aim_gun or _sword_w > 0.01 or get_parent().has_meta("alimentacao_pose"))
	# ---- aplica rotação (lerp suave) ----
	var a: float = 1.0 - exp(-STIFFNESS * real_delta)
	for role in _n:
		var target: Vector3 = _rest.get(role, Vector3.ZERO) + off.get(role, Vector3.ZERO)
		var node: Node3D = _n[role]
		node.rotation = node.rotation.lerp(target, a)
	# Clipe do Mixamo POR CIMA da pose suavizada, com o mesmo peso que a marcha
	# procedural teria (`loco_w` já desconta golpe, mira de arma etc.).
	_corrida_altura = 0.0
	if _corrida_w * loco_w * (1.0 - _pose_agachar.peso) > 0.001:
		_aplicar_corrida(_corrida_w * loco_w * (1.0 - _pose_agachar.peso))

	# ---- bob do torso (oscilação vertical) ----
	if _n.has("Torso"):
		var bob := 0.0
		bob += 0.010 * sin(_t * 2.2) * idle_w
		bob += 0.05 * sin(2.0 * _phase) * _climb_w   # puxada vertical da escalada (2 por ciclo)
		# QUADRIL SEGUE OS PÉS. O sobe/desce da caminhada não vem de fórmula: é
		# MEDIDO na pose que de fato saiu (já filtrada pela rigidez) e ajustado
		# para o pé mais baixo encostar sempre na mesma altura. Calcular por
		# fórmula não fecha — o filtro atenua ângulo e altura de formas
		# diferentes, e sobra o pé flutuando.
		# Só o idle/escalada passam pelo filtro. A parte da caminhada NÃO pode ser
		# filtrada: ela já foi medida na pose pós-filtro, e filtrar de novo
		# reintroduziria exatamente o atraso que ela existe para cancelar.
		_bob_suave = lerpf(_bob_suave, bob, a)
		var bob_final := _bob_suave
		if loco_w > 0.001:
			bob_final += (centro_galope(_phase) if mink_galope else _bob_dos_pes(speed01, is_sprinting)) * loco_w * (1.0 - _corrida_w)
			# Clipe: o quadril desce o que o clipe desce (joelho dobrado), em
			# alturas de quadril — senão os pés flutuam.
			bob_final += _corrida_altura * maxf(_m.get("leg_len", 0.8), 0.3) * loco_w * _corrida_w
		bob_final = lerpf(bob_final, _bob_dos_pes(speed01, false), _pose_agachar.peso)
		(_n["Torso"] as Node3D).position = _rest_torso_pos + Vector3(0, bob_final, 0)

	# Skinnado: espelha os proxies recém-escritos nos ossos do Skeleton3D.
	_pose_agachar.apoiar(self)
	_posicoes_mp.aplicar(_n, get_parent())
	if get_parent().has_meta("alimentacao_pose"):
		var alimentacao := get_parent().get_node_or_null("AlimentacaoVisual")
		if alimentacao != null:
			alimentacao.ajustar_contato()
	if _driver:
		_driver.push()

## Um clipe assado, com as faixas por papel já indexadas. Cacheado por caminho
## (todos os personagens dividem). `ciclo` = alturas de quadril por ciclo.
static func _clipe(caminho: String) -> Dictionary:
	if _clipes_cache.has(caminho):
		return _clipes_cache[caminho]
	var info := {}
	var anim := load(caminho) as Animation if ResourceLoader.exists(caminho) else null
	if anim != null:
		var faixas := {}
		for i in anim.get_track_count():
			var caminho_faixa := String(anim.track_get_path(i))
			if caminho_faixa.ends_with(":rotation"):
				faixas[caminho_faixa.get_slice(":", 0)] = i
			elif caminho_faixa == "Corpo:altura":
				info["altura"] = i
			elif caminho_faixa == "Corpo:giro":
				info["giro"] = i
			elif caminho_faixa == "Corpo:deslocamento":
				var fim = anim.value_track_interpolate(i, anim.length)
				info["ciclo"] = absf((fim as Vector3).z) if fim is Vector3 else 3.2
		info["anim"] = anim
		info["faixas"] = faixas
	_clipes_cache[caminho] = info
	return info


## Quanto o pé de APOIO anda para trás num ciclo do clipe, neste rig, em metros do
## mundo. Toca o ciclo nos próprios nós (64 amostras), soma o recuo do pé mais
## baixo e devolve a pose. Uma vez por personagem e clipe.
func _passada_no_rig(caminho: String) -> float:
	if _passadas.has(caminho):
		return _passadas[caminho]
	var info := _clipe(caminho)
	var reserva: float = info.get("ciclo", 3.2) * maxf(_m.get("leg_len", 0.8), 0.3)
	if not info.has("anim") or not (_n.has("Torso") and _n.has("Foot_L") and _n.has("Foot_R")):
		_passadas[caminho] = reserva
		return reserva
	var anim: Animation = info["anim"]
	var modelo := (_n["Torso"] as Node3D).get_parent() as Node3D
	if modelo == null or not modelo.is_inside_tree():
		return reserva                     # sem árvore não há global: tenta no próximo quadro
	var guardadas := {}
	for papel in info["faixas"]:
		if _n.has(papel):
			guardadas[papel] = (_n[papel] as Node3D).quaternion
	var frente: Vector3 = -modelo.global_basis.z.normalized()
	var cima: Vector3 = modelo.global_basis.y.normalized()
	# Amostra os DOIS pés (altura, avanço). O apoio se decide depois: o pé a até
	# 3 cm da menor altura atingida. "O pé mais baixo" não serve — correndo há fase
	# de voo, e nela o mais baixo pode ser o que balança (subestimava a passada).
	var amostras := {"L": [], "R": []}
	for k in 65:
		var t := anim.length * float(k % 64) / 64.0
		for papel in guardadas:
			(_n[papel] as Node3D).quaternion = Quaternion.from_euler(anim.value_track_interpolate(info["faixas"][papel], t))
		for lado in ["L", "R"]:
			var pe: Vector3 = (_n["Foot_" + lado] as Node3D).global_position
			amostras[lado].append(Vector2(pe.dot(cima), pe.dot(frente)))
	for papel in guardadas:
		(_n[papel] as Node3D).quaternion = guardadas[papel]
	var y_min := INF
	for lado in amostras:
		for a in amostras[lado]:
			y_min = minf(y_min, a.x)
	var total := 0.0
	for lado in amostras:
		var serie: Array = amostras[lado]
		for k in range(1, serie.size()):
			if serie[k - 1].x <= y_min + 0.03 and serie[k].x <= y_min + 0.03:
				total += maxf(serie[k - 1].y - serie[k].y, 0.0)
	var passada := total if total > 0.2 else reserva
	_passadas[caminho] = passada
	return passada


## O clipe de ação no tempo `acao_tempo`, com peso `w` (entrada suave). Mistura
## por quatérnio (o roll gira o tronco uma volta inteira — o euler gravado passa
## de ±π). O quadril baixa por `Corpo:altura` e o giro do corpo volta por
## `Corpo:giro`, em volta da vertical do personagem.
func _aplicar_acao(w: float) -> void:
	var info := _clipe(acao_clipe)
	var anim: Animation = info["anim"]
	var t := clampf(acao_tempo, 0.0, anim.length)
	for papel in info["faixas"]:
		if _n.has(papel):
			var no: Node3D = _n[papel]
			var alvo := Quaternion.from_euler(anim.value_track_interpolate(info["faixas"][papel], t))
			no.quaternion = no.quaternion.slerp(alvo, w)
	if _n.has("Torso"):
		var tronco: Node3D = _n["Torso"]
		if info.has("giro"):
			var giro: float = anim.value_track_interpolate(info["giro"], t)
			tronco.basis = Basis(Vector3.UP, giro * w) * tronco.basis
		var altura: float = anim.value_track_interpolate(info["altura"], t) if info.has("altura") else 0.0
		tronco.position = _rest_torso_pos + Vector3(0, altura * maxf(_m.get("leg_len", 0.8), 0.3) * w, 0)
	if _driver:
		_driver.push()


## Aplica running/sprint (misturados por `_sprint_w`, na fase `_corrida_u`) com
## peso `w`. A MISTURA É POR QUATÉRNIO: o euler gravado é contínuo e passa de ±π
## perto de 90° (coxa do sprint) — interpolar ângulos ali giraria o membro.
func _aplicar_corrida(w: float) -> void:
	var run := _clipe(CLIPE_CORRIDA)
	var spr := _clipe(CLIPE_SPRINT)
	var a_run: Animation = run["anim"]
	var a_spr: Animation = spr.get("anim")
	var t_run := _corrida_u * a_run.length
	var t_spr := _corrida_u * a_spr.length if a_spr != null else 0.0
	var ws := _sprint_w if a_spr != null else 0.0
	for papel in run["faixas"]:
		if not _n.has(papel):
			continue
		var q := Quaternion.from_euler(a_run.value_track_interpolate(run["faixas"][papel], t_run))
		if ws > 0.001 and (spr["faixas"] as Dictionary).has(papel):
			q = q.slerp(Quaternion.from_euler(a_spr.value_track_interpolate(spr["faixas"][papel], t_spr)), ws)
		var peso := w * ((1.0 - _gura_rush_w) if papel.ends_with("_R") and papel.begins_with("UpperArm") or papel == "ForeArm_R" else 1.0)
		# Segurando a vara, o clipe não balança o braço da vara (nem o da carretilha).
		if _pesca_w > 0.0 and (papel in PescaPoses.BRACOS_D or (papel in PescaPoses.BRACOS_E and PescaPoses.duas_maos(_pesca_pose))):
			peso *= 1.0 - _pesca_w
		if get_parent().has_meta("alimentacao_pose") and papel in preload("res://src/anim/alimentacao_poses.gd").PAPEIS:
			peso = 0.0
		var no: Node3D = _n[papel]
		no.quaternion = no.quaternion.slerp(q, peso)
	# POR CIMA do clipe: giro do quadril (tirado das poses no assado), inclinação de
	# curva (tronco para dentro, coxas e cabeça devolvem parte) e de arrancada/
	# frenagem (+ = frente → x negativo no tronco). Mesmas proporções da marcha.
	var giro := 0.0
	if run.has("giro"):
		giro = a_run.value_track_interpolate(run["giro"], t_run)
		if ws > 0.001 and spr.has("giro"):
			giro = lerpf(giro, a_spr.value_track_interpolate(spr["giro"], t_spr), ws)
	if _n.has("Torso"):
		var tronco: Node3D = _n["Torso"]
		# Giro do quadril em volta da vertical do PERSONAGEM (espaço do pai).
		tronco.basis = Basis(Vector3.UP, giro * w) * tronco.basis
		tronco.rotate_object_local(Vector3.RIGHT, -loco_inclinacao_frente * w)
		tronco.rotate_object_local(Vector3.BACK, loco_inclinacao * w)
	for papel in ["Thigh_L", "Thigh_R"]:
		if _n.has(papel):
			(_n[papel] as Node3D).rotate_object_local(Vector3.BACK, -loco_inclinacao * 0.6 * w)
	if _n.has("Head"):
		(_n["Head"] as Node3D).rotate_object_local(Vector3.BACK, -loco_inclinacao * 0.5 * w)
	# OLHAR NIVELADO: o pitch da cabeça em relação à raiz do personagem fica em
	# ±OLHAR_MAX (o clipe do sprint corre encarando o chão).
	if _n.has("Head") and _n.has("Torso"):
		var raiz := (_n["Torso"] as Node3D).get_parent() as Node3D
		var cabeca: Node3D = _n["Head"]
		if raiz != null and raiz.is_inside_tree():
			var rel: Basis
			if (_n["Torso"] as Node3D).is_ancestor_of(cabeca):
				rel = raiz.global_basis.orthonormalized().inverse() * cabeca.global_basis.orthonormalized()
			else:
				# Skinnado (Meshy): os nós são intermediários SOLTOS — a hierarquia
				# está no esqueleto. O olhar é tronco × cabeça.
				rel = (_n["Torso"] as Node3D).basis.orthonormalized() * cabeca.basis.orthonormalized()
			var pitch := rel.get_euler().x
			var excesso := 0.0
			if pitch < -OLHAR_MAX:
				excesso = -OLHAR_MAX - pitch
			elif pitch > OLHAR_MAX:
				excesso = OLHAR_MAX - pitch
			if excesso != 0.0:
				cabeca.rotate_object_local(Vector3.RIGHT, excesso * w)
	if run.has("altura"):
		_corrida_altura = a_run.value_track_interpolate(run["altura"], t_run)
		if ws > 0.001 and spr.has("altura"):
			_corrida_altura = lerpf(_corrida_altura, a_spr.value_track_interpolate(spr["altura"], t_spr), ws)
	# Rig detalhado: as tampas de cotovelo e joelho copiam metade da dobra que o
	# CLIPE produziu (a camada `RigDetalhado.juntas` só enxerga o `off`).
	if _detalhe > 0.0:
		for lado in ["L", "R"]:
			for par in [["ForeArm_", "Elbow_"], ["Shin_", "Knee_"]]:
				var membro: String = par[0] + lado
				var tampa: String = par[1] + lado
				if _n.has(membro) and _n.has(tampa):
					var rel := Quaternion.from_euler(_rest.get(membro, Vector3.ZERO)).inverse() * (_n[membro] as Node3D).quaternion
					var alvo := Quaternion.from_euler(_rest.get(tampa, Vector3.ZERO)) * Quaternion.IDENTITY.slerp(rel, 0.5)
					var no_t: Node3D = _n[tampa]
					no_t.quaternion = no_t.quaternion.slerp(alvo, w)


var is_backwards: bool = false
var _pose_skill_w := 0.0       # peso da pose do Skills Builder (toma o corpo)

## LOCOMOÇÃO NO CHÃO (02/10/2026, src/player/locomocao_chao.gd). O Player escreve
## antes do `update`: inclinação lateral na curva (rad, + = esquerda), para a frente
## na arrancada (+) e para trás na frenagem (−), e o estado ("arrancando",
## "freando", "derrapando", "girando"...). Visual só: a cápsula não inclina.
var loco_inclinacao := 0.0
var loco_inclinacao_frente := 0.0
var loco_estado := ""
## Abdução do braço que apoia na parede (rad).
const BRACO_NA_PAREDE := 1.45
## WALL RUN (03/10/2026): +1 = parede à DIREITA, −1 = à esquerda, 0 = sem parede.
## O Player inclina a RAIZ do modelo para longe da parede (pés nela); aqui fica a
## pose: a mão do lado da parede apoia nela, a outra bomba.
var parede_lado := 0
## ESCALADA (03/10/2026, fatia 3): progresso 0..1 de subir a borda (0–0,7 puxando o
## corpo para cima, 0,7–1 passando por cima). Vem de `escalada.gd`.
var subida_borda := 0.0

## CLIPE DE AÇÃO: caminho do `.res` ("" = nenhum) e o tempo dele neste quadro.
## O Player escreve antes do `update` (roll do Q, deslize do Ctrl).
var acao_clipe := ""
var acao_tempo := 0.0
## Quanto do clipe de ação vale (0..1). Roll e deslize: 1. O bloco Animação do Skills
## Builder manda a "Intensidade" dele (07/10/2026).
var acao_peso := 1.0
var _acao_w := 0.0
var _pesca_w := 0.0          # braços na vara de pesca (PescaPoses)
var _pesca_pose := ""

## Estado da corrida do Mixamo (ver CLIPE_CORRIDA).
## Desligável: o `test_walk_run` mede a marcha PROCEDURAL (ainda usada na
## arrancada lenta, no galope Mink e em quem não tem clipe) com o clipe desligado.
var _pose_agachar = preload("res://src/anim/pose_agachar.gd").new()
var usar_clipe_de_corrida := true
var _corrida_w := 0.0       # peso do clipe na locomoção (0 = marcha procedural)
var _sprint_w := 0.0        # mistura running → sprint
var _corrida_u := 0.0       # fase 0..1 COMPARTILHADA: os dois clipes começam com o pé
                            # esquerdo à frente e trocam de pé em u≈0,5 (medido 03/10)
var _corrida_altura := 0.0  # Corpo:altura do clipe neste quadro (× altura do quadril)
static var _clipes_cache := {}
var _passadas := {}         # passada (m, mundo) de cada clipe neste rig

# ---------------------------------------------------------------- geradores ---
func _add(off: Dictionary, role: String, v: Vector3) -> void:
	if is_backwards:
		v.x = -v.x
		v.z = -v.z
	if _n.has(role):
		off[role] = off.get(role, Vector3.ZERO) + v

# IDLE — parado, mas PRONTO. Não é repouso neutro: é a postura de quem está
# esperando briga, que é o que a referência de One Piece pede.
#
# Três frequências diferentes de propósito (0,55 / 0,9 / 1,7 Hz). Se respiração,
# balanço e cabeça compartilham o mesmo período, o corpo pulsa inteiro no mesmo
# compasso e lê como boneco de mola. Períodos primos entre si nunca repetem o
# mesmo instante e o parado fica "vivo".
func _idle(off: Dictionary, w: float) -> void:
	if w <= 0.001:
		return
	var resp := sin(_t * 1.7)               # respiração (mais rápida)
	var peso := sin(_t * 0.55)              # troca de peso de uma perna p/ outra
	var giro := sin(_t * 0.9 + 1.0)         # deriva lenta do olhar

	# tronco: peito sobe na inspiração, e o corpo pende p/ o lado que aguenta o peso
	_add(off, "Torso", Vector3(-0.015 - 0.012 * resp, 0.03 * giro, 0.035 * peso) * w)
	_add(off, "Neck", Vector3(0.01 * resp, 0, -0.02 * peso) * w)
	# cabeça contra o giro do tronco (olhar fica firme) e varre devagar
	_add(off, "Head", Vector3(0.02 * resp, 0.09 * giro - 0.03 * giro, 0) * w)

	# pernas: uma sustenta, a outra relaxa — o joelho de apoio estica um pouco
	_add(off, "Thigh_L", Vector3(-0.02 * peso, 0, 0.02 * peso) * w)
	_add(off, "Thigh_R", Vector3(0.02 * peso, 0, 0.02 * peso) * w)
	_add(off, "Shin_L", Vector3(-0.05 - 0.03 * maxf(-peso, 0.0), 0, 0) * w)
	_add(off, "Shin_R", Vector3(-0.05 - 0.03 * maxf(peso, 0.0), 0, 0) * w)

	# braços soltos, um pouco à frente e afastados: guarda baixa, não em posição
	# de sentido. O `_gun_w` tira o balanço quando a pistola está erguida.
	var arm_w: float = w * (1.0 - _gun_w)
	var arm_r_w: float = arm_w * (1.0 - _gura_rush_w) # Isola o braço direito da animação normal
	_add(off, "UpperArm_L", Vector3(0.10 - 0.05 * resp, 0, -0.13) * arm_w)
	_add(off, "UpperArm_R", Vector3(0.10 + 0.05 * resp, 0, 0.13) * arm_r_w)
	_add(off, "ForeArm_L", Vector3(0.34 - 0.05 * peso, 0, -0.10) * arm_w)
	_add(off, "ForeArm_R", Vector3(0.34 + 0.05 * peso, 0, 0.10) * arm_r_w)
	_add(off, "Torso", Vector3(0.04 + 0.02 * resp, 0, 0) * w)

	# Coluna, ombro, punho, dedos e antepé do rig detalhado. Nada aqui em cima
	# muda: a camada só SOMA nas juntas que o rig A não tinha.
	if _detalhe > 0.0:
		RigDetalhado.idle(_add, off, w, arm_w, _t)

func _locomotion(off: Dictionary, w: float, phase: float, speed01: float, is_sprinting: bool) -> void:
	if w <= 0.001:
		return
	if usa_corrida_mink(_raca_do_modelo(), is_sprinting):
		_galope_mink(off, phase, w)
		return

	# Amplitudes calibradas contra movimento humano real (em radianos).
	# ATENÇÃO ao mexer: o braço parte do repouso PENDURADO (−90° de elevação), então
	# A_arm é o quanto ele sobe. A_arm=1.55 punha o braço quase na HORIZONTAL andando
	# (elevação −21°) — era o bug do "andando com os braços para cima".
	# Referência: caminhada ~20° de braço; corrida ~45°. As PERNAS não têm amplitude
	# aqui — elas vêm da IK em _perna_ik(), que resolve a partir do alvo do pé.
	var t: float = clampf(speed01, 0.0, 1.0)
	var A_arm   := lerpf(0.15, 0.40, t)
	# Inclinação do tronco p/ FRENTE — mais a da física: arrancada joga o corpo para
	# a frente, frenagem para trás (`loco_inclinacao_frente`).
	var lean    := lerpf(0.02, 0.08, t) + loco_inclinacao_frente

	if is_sprinting:
		A_arm *= 2.0
		lean += 0.18

	var sL := sin(phase)
	var sR := sin(phase + PI)

	# PERNAS por IK, não por balanço solto. Antes as duas coxas oscilavam com o
	# mesmo padrão de joelho, então no cruzamento do ciclo as DUAS ficavam
	# dobradas e o corpo afundava — o personagem parecia quicar em vez de pisar.
	# Agora cada pé recebe um ALVO: no apoio ele fica na altura do chão (o corpo
	# passa por cima dele), e na balanço levanta num arco.
	# `lean` entra porque as coxas são FILHAS do torso: sem devolver a inclinação,
	# a perna herda o tombo do tronco e o pé plantado sobe/desce junto.
	# ⚠️ AS FASES ESTÃO TROCADAS DE PROPÓSITO (L recebe `phase + PI`).
	# Quando o `base.scn` foi desespelhado (2026-08-14), o papel `_L` passou a
	# apontar para o nó do lado −X, que antes se chamava `_R`. Todos os offsets de
	# `_add` foram trocados junto para o resultado FÍSICO não mudar — mas a perna
	# não vem de `_add`, vem daqui, da IK. Sem trocar a fase também, os braços
	# passaram a balançar JUNTO com a perna do mesmo lado em vez de opostos, e o
	# `test_walk_run` reprovou com "braço não está oposto à perna".
	# Regra para quem mexer aqui: braço e perna do MESMO papel têm que estar em
	# contra-fase. O teste mede isso por correlação (tem que ser negativa).
	# Pose EXTERNA (Ushi Ushi: bicuda) toma as pernas: a IK que planta o pé no chão anulava o chute (medido: pé a 0,42 m no pico em vez de ~0,8 m).
	var w_ik := w * (1.0 - _ext_w)
	_perna_ik(off, "Thigh_L", "Shin_L", "Foot_L", phase + PI, speed01, is_sprinting, w_ik, lean)
	_perna_ik(off, "Thigh_R", "Shin_R", "Foot_R", phase, speed01, is_sprinting, w_ik, lean)
	# Calcanhar que sai de ponta e pé que aterrissa de salto. A MESMA fase de
	# cada perna acima — trocar uma e esquecer a outra põe o desenrolar no pé
	# errado, e o teste do pé plantado não pega isso (ele só mede coxa e canela).
	if _detalhe > 0.0:
		RigDetalhado.pe(_add, off, "L", phase + PI, w, t)
		RigDetalhado.pe(_add, off, "R", phase, w, t)

	# Braços: balançam em contra-fase com as pernas — no sprint também (03/10/2026:
	# a "silhueta Naruto", braços travados para trás, saiu a pedido do dono; o
	# sprint de verdade é o clipe Mixamo, ver `_aplicar_corrida`).
	var arm_w: float = w * (1.0 - _gun_w)
	var arm_r_w: float = arm_w * (1.0 - _gura_rush_w) # Isola o braço direito
	# COSSENO, não seno: a perna agora vem da IK, cuja posição à frente é máxima
	# em fase 0 (rampa linear de +passada/2 a −passada/2). Com seno o braço ficava
	# 90° fora de fase — nem oposto nem junto, só estranho.
	var cL := cos(phase)
	var cR := cos(phase + PI)
	var arm_out: float = lerpf(0.09, 0.15, t) # muito abre "asa de galinha"
	var sL_lag := cos(phase - 0.6) # atraso -> sensação de braço "solto"
	var sR_lag := cos(phase + PI - 0.6)
	_add(off, "UpperArm_L", Vector3(-A_arm * cR, 0, -0.08 - arm_out) * arm_w)
	_add(off, "UpperArm_R", Vector3(-A_arm * cL, 0, 0.08 + arm_out) * arm_r_w)
	# Cotovelo: dobra um pouco mais quando o braço vem à frente (não fica esticado).
	var A_elbow: float = lerpf(0.10, 0.25, t)
	_add(off, "ForeArm_L", Vector3(0.18 + A_elbow * maxf(sR_lag, 0.0), 0, -0.08) * arm_w)
	_add(off, "ForeArm_R", Vector3(0.18 + A_elbow * maxf(sL_lag, 0.0), 0, 0.08) * arm_r_w)

	# Torso inclina p/ FRENTE (-Z) + BALANÇO DOS OMBROS: giro no eixo Y (ombros gingam
	# opostos ao passo) e leve rolamento no Z. rot.x+ joga o topo p/ +Z (trás), logo a
	# inclinação p/ frente é NEGATIVA. Amplitude do giro sobe com a velocidade.
	var shoulder: float = lerpf(0.07, 0.15, t) * (1.75 if is_sprinting else 1.0)
	# CURVA: o tronco inclina para dentro (tg θ = v·ω/g, calculado na física); as
	# coxas devolvem 60 % (os pés ficam sob o corpo, só um pouco para fora, como
	# quem pisa firme na curva) e a cabeça devolve metade (o olhar fica no rumo).
	var curva_incl: float = loco_inclinacao
	_add(off, "Torso", Vector3(-lean, shoulder * sin(phase), 0.05 * sin(phase) + curva_incl) * w)
	_add(off, "Thigh_L", Vector3(0, 0, -curva_incl * 0.6) * w)
	_add(off, "Thigh_R", Vector3(0, 0, -curva_incl * 0.6) * w)
	_add(off, "Head", Vector3(0, 0, -curva_incl * 0.5) * w)
	# QUADRIL contra-rotaciona os ombros — é isso que dá sensação de peso e de
	# impulso. No rig A não havia coluna, então o giro entrava nas duas coxas: um
	# remendo, e dos caros, porque girar a coxa gira a PERNA, não o quadril.
	#
	# No rig detalhado quem contra-rotaciona é a coluna (`RigDetalhado.marcha`),
	# que é o osso certo para isso, e aí o remendo TEM que sair — os dois juntos
	# torceriam o corpo duas vezes. `(1 - _detalhe)` é essa chave.
	var quadril: float = shoulder * 0.55 * (1.0 - _detalhe)
	_add(off, "Thigh_L", Vector3(0, -quadril * sin(phase), 0) * w)
	_add(off, "Thigh_R", Vector3(0, -quadril * sin(phase), 0) * w)
	# Cabeça compensa a inclinação do tronco (senão o personagem corre olhando pro
	# chão) e estabiliza o giro dos ombros. 0.75 = quase nivelada, mas ainda
	# sobra um resto pra frente, que lê como "determinado".
	_add(off, "Head", Vector3(lean * 0.75, -shoulder * 0.4 * sin(phase), 0) * w)

	# Torção de tronco, ombro que avança com o braço, mão com atraso e dedos. No
	# sprint a camada própria (coluna dobrando e olhar no horizonte) recebe a
	# amplitude REAL do balanço — desde 03/10 os braços balançam também no sprint.
	if _detalhe > 0.0:
		if is_sprinting:
			RigDetalhado.corrida(_add, off, w, arm_w, phase, shoulder, A_arm, lean)
		else:
			RigDetalhado.marcha(_add, off, w, arm_w, phase, shoulder, A_arm, lean)


## Galope Mink: as duas pernas traseiras comprimem e lançam o corpo, enquanto
## os braços viram patas dianteiras que alcançam o chão, plantam e empurram para
## trás. Não é uma corrida humana inclinada: há compressão, voo e aterrissagem.
func _galope_mink(off: Dictionary, phase: float, w: float) -> void:
	var onda := sin(phase)
	var voo := maxf(onda, 0.0)       # corpo no ar, após o impulso traseiro
	var aterrissa := maxf(-onda, 0.0) # mãos/pés recebem o peso no chão
	var maos_frente := cos(phase)
	var pernas_frente := cos(phase + 0.34)

	# Patas traseiras: dobram bastante na compressão e estendem no salto.
	for lado in ["L", "R"]:
		_add(off, "Thigh_" + lado, Vector3(0.42 + pernas_frente * 0.56 - aterrissa * 0.28, 0.0, 0.0) * w)
		_add(off, "Shin_" + lado, Vector3(-0.96 + voo * 0.70 - aterrissa * 0.34, 0.0, 0.0) * w)
		_add(off, "Foot_" + lado, Vector3(0.20 - pernas_frente * 0.22, 0.0, 0.0) * w)

	# Patas dianteiras: vão à frente para tocar o solo e passam para trás no
	# empurrão. O antebraço dobra na aterrissagem, leitura clara de "mão no chão".
	_add(off, "UpperArm_L", Vector3(1.18 + maos_frente * 0.62 - voo * 0.20, 0.0, -0.30) * w)
	_add(off, "UpperArm_R", Vector3(1.18 + maos_frente * 0.62 - voo * 0.20, 0.0, 0.30) * w)
	_add(off, "ForeArm_L", Vector3(0.72 - maos_frente * 0.34 + aterrissa * 0.36, 0.0, -0.10) * w)
	_add(off, "ForeArm_R", Vector3(0.72 - maos_frente * 0.34 + aterrissa * 0.36, 0.0, 0.10) * w)

	# Coluna baixa na corrida, mas ergue no voo e abaixa de volta ao aterrissar.
	# Giro forte no centro: o tronco deixa a vertical humana e vira uma coluna
	# quase horizontal. A cabeça compensa só parcialmente, olhando para a frente
	# do galope em vez de continuar ereta como numa corrida bípede.
	_add(off, "Torso", Vector3(-0.98 + voo * 0.20 + aterrissa * 0.14,
		0.06 * sin(phase * 2.0), 0.03 * sin(phase)) * w)
	_add(off, "Head", Vector3(0.52 - voo * 0.18, -0.05 * sin(phase), 0.0) * w)


## Altura da trajetória do corpo no salto do galope. A fase positiva é o voo;
## elevar duas vezes mais que a marcha comum deixa a leitura de animal selvagem.
static func altura_galope(phase: float) -> float:
	return maxf(sin(phase), 0.0) * 0.105


## O quadril humano deixa as mãos altas demais. No galope, a silhueta inteira
## baixa 22 cm e só volta parte disso no voo; mãos e pés passam pelo mesmo plano
## do chão sem alterar a cápsula/colisão real do Player.
static func centro_galope(phase: float) -> float:
	# Abaixado até a altura de apoio das mãos; o voo sobe 10,5 cm, mas ainda
	# fica bem abaixo do centro de uma corrida humana.
	return -0.42 + altura_galope(phase)


## Poses curtas do estilo Mink. A investida inclina cabeça/ombros para a mordida;
## a presa mantém o alvo junto da boca; o clique seguinte abre a perna no chute.
func _mink_combat_pose(off: Dictionary, pose: String) -> void:
	match pose:
		"mink_bite_dash":
			_add(off, "Torso", Vector3(-1.12, 0.0, 0.0))
			_add(off, "Head", Vector3(0.82, 0.0, 0.0))
			_add(off, "UpperArm_L", Vector3(0.92, 0.0, -0.24))
			_add(off, "UpperArm_R", Vector3(0.92, 0.0, 0.24))
		"mink_bite_hold":
			_add(off, "Torso", Vector3(-0.92, 0.0, 0.0))
			_add(off, "Head", Vector3(0.96, 0.0, 0.0))
		"mink_kick":
			_add(off, "Torso", Vector3(-0.30, 0.0, 0.12))
			_add(off, "Thigh_R", Vector3(1.38, 0.0, 0.24))
			_add(off, "Shin_R", Vector3(-0.28, 0.0, 0.0))
		"air_slam_dive":
			# Calcanhar mira o chão; braços abrem para a silhueta ler como queda,
			# e não como o chute horizontal do terceiro M1.
			_add(off, "Torso", Vector3(0.78, 0.0, 0.0))
			_add(off, "Thigh_R", Vector3(-1.48, 0.0, 0.18))
			_add(off, "Shin_R", Vector3(0.30, 0.0, 0.0))
			_add(off, "UpperArm_L", Vector3(-0.64, 0.0, -0.44))
			_add(off, "UpperArm_R", Vector3(-0.64, 0.0, 0.44))
		"spin_kick":
			# Aú de capoeira: braços buscam o chão para sustentar a passagem e
			# pernas formam um V alto. O Player gira a raiz lateralmente; esta pose
			# constrói a silhueta que a pirueta em pé não tinha.
			_add(off, "Torso", Vector3(0.26, 0.0, 0.0))
			_add(off, "UpperArm_L", Vector3(1.52, -0.22, -0.34))
			_add(off, "ForeArm_L", Vector3(0.42, 0.0, 0.0))
			_add(off, "UpperArm_R", Vector3(1.52, 0.22, 0.34))
			_add(off, "ForeArm_R", Vector3(0.42, 0.0, 0.0))
			_add(off, "Thigh_R", Vector3(-1.34, 0.24, 0.42))
			_add(off, "Shin_R", Vector3(0.22, 0.0, 0.0))
			_add(off, "Thigh_L", Vector3(-1.10, -0.24, -0.42))
			_add(off, "Shin_L", Vector3(-0.10, 0.0, 0.0))


static func usa_corrida_mink(raca: String, sprintando: bool) -> bool:
	return sprintando and raca in ["mink_coelho", "mink_lobo", "mink_lobo_neve"]


func _raca_do_modelo() -> String:
	var no: Node = _n.get("Torso", null)
	while no != null:
		if no is Node3D and (no as Node3D).has_meta("raca_id"):
			return String((no as Node3D).get_meta("raca_id"))
		no = no.get_parent()
	return ""

# Altura do quadril acima do chão. Agacha com a velocidade (corrida é mais baixa).
func _altura_quadril(speed01: float, sprint: bool) -> float:
	var perna: float = _perna_len()
	if sprint:
		return perna * H_SPRINT
	return perna * lerpf(H_PARADO, H_CORRIDA, clampf(speed01, 0.0, 1.0))

func _perna_len() -> float:
	return maxf(_m.get("thigh_len", 0.30), 0.05) + maxf(_m.get("shin_len", 0.30), 0.05)

# Passada = quanto o pé viaja de frente a trás num ciclo. É a MESMA conta usada
# pela cadência (em update) e pela IK — se as duas discordarem, o pé desliza.
# Velocidade angular da marcha (rad/s). FONTE ÚNICA — o teste chama esta mesma
# função. Já teve uma cópia da fórmula no teste, e ela ficou para trás quando o
# freio de cadência entrou: os números continuavam mostrando o estado antigo.
func cadencia(planar: float, speed01: float, sprint: bool) -> float:
	var p: float = _passada(speed01, sprint)
	return minf(PI * planar / p * CADENCIA_ESCALA, CADENCIA_MAX)

# Deslize PREVISTO do pé no apoio, em fração da velocidade do corpo (0 = cravado).
# É o MODELO, não a medição: ignora o que o filtro de rigidez faz com a amplitude
# (com ciclo curto ele come passada e o deslize real fica maior). O teste mede o
# deslize na pose que saiu e usa esta função só para comparar as duas coisas.
func deslize(planar: float, speed01: float, sprint: bool) -> float:
	if planar < 0.01:
		return 0.0
	var v_pe: float = _passada(speed01, sprint) / PI * cadencia(planar, speed01, sprint)
	return absf(v_pe - planar) / planar

func _passada(speed01: float, sprint: bool) -> float:
	var perna: float = _perna_len()
	var p: float = perna * lerpf(0.45, 0.95, clampf(speed01, 0.0, 1.0)) * PASSADA_GANHO
	if sprint:
		p *= 1.25
	# TETO GEOMÉTRICO: com o quadril a H do chão, o pé só alcança
	# sqrt(alcance² − H²) para a frente. Pedir mais satura a IK e o pé sobe.
	var H: float = _altura_quadril(speed01, sprint)
	var alcance: float = perna * 0.98
	var meia_max: float = sqrt(maxf(alcance * alcance - H * H, 0.0))
	return maxf(minf(p, meia_max * 2.0), 0.05)

# Sobe/desce do quadril ao longo do ciclo. O corpo está MAIS ALTO no meio de cada
# apoio (perna esticada por baixo) e mais baixo no duplo apoio — duas subidas por
# ciclo. É o "vault" que dá peso à caminhada, e a spec pede esse movimento
# vertical do tronco. Vai somado tanto no torso quanto no alvo do pé, senão o pé
# plantado subiria junto com o corpo.
func _vault(speed01: float, sprint: bool) -> float:
	var amp: float = _perna_len() * lerpf(0.012, 0.030, clampf(speed01, 0.0, 1.0))
	if sprint:
		amp *= 1.35
	return amp * (0.5 - 0.5 * cos(2.0 * _phase))

# Quanto o quadril precisa subir para o pé MAIS BAIXO encostar sempre na mesma
# altura. Lê as rotações que realmente ficaram nas juntas (depois do filtro de
# rigidez), então é exato por construção: seja qual for o atraso do filtro, o
# porte do personagem ou a velocidade, o pé de apoio não flutua.
func _bob_dos_pes(speed01: float, sprint: bool) -> float:
	if not (_n.has("Torso") and _n.has("Thigh_L") and _n.has("Shin_L")):
		return 0.0
	var L1: float = maxf(_m.get("thigh_len", 0.30), 0.05)
	var L2: float = maxf(_m.get("shin_len", 0.30), 0.05)
	var tronco: float = (_n["Torso"] as Node3D).rotation.x
	var mais_baixo := 0.0
	var achou := false
	for lado in ["L", "R"]:
		if not (_n.has("Thigh_" + lado) and _n.has("Shin_" + lado)):
			continue
		# ângulo da coxa no espaço do PERSONAGEM (a coxa carrega +lean, o torso −lean)
		var ac: float = (_n["Thigh_" + lado] as Node3D).rotation.x + tronco
		var aj: float = ac + (_n["Shin_" + lado] as Node3D).rotation.x
		var y: float = -(L1 * cos(ac) + L2 * cos(aj))
		if not achou or y < mais_baixo:
			mais_baixo = y
			achou = true
	if not achou:
		return 0.0
	# O pé de apoio tem que ficar na MESMA profundidade em que o pé de REPOUSO fica
	# abaixo do quadril — é nela que o modelo encosta no chão (o piso da colisão).
	# ⚠️ Até 01/10/2026 a referência era `-_altura_quadril()`: a altura AGACHADA da
	# marcha (0,70 da perna; 0,66 no sprint). A IK punha o pé de apoio lá, o bob
	# dava zero e o quadril não descia — o corpo inteiro pairava (1 − 0,70) da perna
	# acima do chão ao andar: +14 cm no `base` (medido em 08/09 e de novo em 01/10;
	# a poeira dos pés, que nasce no chão, denunciava). Agora o quadril DESCE o que a
	# marcha agacha, que era o desenho declarado em H_CORRIDA ("corpo um pouco mais
	# agachado").
	return _profundidade_do_pe_em_repouso() - mais_baixo


## Profundidade (negativa) do pé mais baixo abaixo do quadril na pose de REPOUSO —
## a mesma conta de `_bob_dos_pes`, com as rotações de repouso das juntas.
func _profundidade_do_pe_em_repouso() -> float:
	var L1: float = maxf(_m.get("thigh_len", 0.30), 0.05)
	var L2: float = maxf(_m.get("shin_len", 0.30), 0.05)
	var tronco: float = (_rest.get("Torso", Vector3.ZERO) as Vector3).x
	var mais_baixo := 0.0
	var achou := false
	for lado in ["L", "R"]:
		if not (_rest.has("Thigh_" + lado) and _rest.has("Shin_" + lado)):
			continue
		var ac: float = (_rest["Thigh_" + lado] as Vector3).x + tronco
		var aj: float = ac + (_rest["Shin_" + lado] as Vector3).x
		var y: float = -(L1 * cos(ac) + L2 * cos(aj))
		if not achou or y < mais_baixo:
			mais_baixo = y
			achou = true
	return mais_baixo if achou else -(L1 + L2)

# IK de duas juntas para uma perna, no plano sagital (frente/trás).
#
# Recebe o pé como ALVO e resolve coxa+joelho, em vez de girar as juntas às
# cegas. É isso que faz o pé PLANTAR: durante o apoio o alvo fica na altura do
# chão, então o joelho estica ou dobra sozinho para o corpo passar por cima do
# pé — o "vault" que dá peso à caminhada.
#
# Convenção do rig: o membro pende em -Y e girar +X leva o pé para -Z (frente).
# Com o joelho dobrando PARA TRÁS (como o humano), o ângulo do joelho é NEGATIVO.
func _perna_ik(off: Dictionary, papel_coxa: String, papel_canela: String,
		papel_pe: String, fase: float, speed01: float, sprint: bool, w: float,
		lean: float = 0.0) -> void:
	if w <= 0.001:
		return
	var L1: float = maxf(_m.get("thigh_len", 0.30), 0.05)
	var L2: float = maxf(_m.get("shin_len", 0.30), 0.05)
	var perna := L1 + L2

	var H: float = _altura_quadril(speed01, sprint)
	var passada: float = _passada(speed01, sprint)
	var levanta: float = perna * lerpf(0.10, 0.22, clampf(speed01, 0.0, 1.0))

	# Alvo do pé em relação ao quadril.
	# APOIO (meia volta): trajetória LINEAR de +passada/2 até −passada/2. Tem que
	# ser reta — com uma senoide o pé varreria rápido no meio e devagar nas pontas,
	# e como o corpo avança a velocidade constante isso VIRA DESLIZE. Combinada
	# com ω = π·v/passada, a linear dá velocidade do pé = −v exata: pé cravado.
	# BALANÇO: volta à frente com entrada/saída suaves e levantando num arco.
	var ciclo: float = fposmod(fase, TAU)
	var apoio: bool = ciclo < PI
	var frente: float
	var sobe := 0.0
	if apoio:
		frente = (passada * 0.5) * (1.0 - 2.0 * (ciclo / PI))
	else:
		var u: float = (ciclo - PI) / PI            # 0 -> 1
		frente = -passada * 0.5 + passada * (1.0 - cos(PI * u)) * 0.5
		sobe = sin(PI * u) * levanta
	# O corpo sobe no meio do apoio; o pé plantado NÃO pode subir junto, então a
	# distância quadril->pé cresce na mesma medida.
	var h: float = maxf(H + _vault(speed01, sprint) - sobe, perna * 0.30)

	# --- IK analítica de 2 elos ---
	var d: float = clampf(sqrt(h * h + frente * frente), absf(L1 - L2) + 0.001, perna - 0.001)
	var cos_j: float = clampf((d * d - L1 * L1 - L2 * L2) / (2.0 * L1 * L2), -1.0, 1.0)
	var joelho: float = -acos(cos_j)              # negativo = dobra p/ trás
	var coxa: float = atan2(frente, h) - atan2(L2 * sin(joelho), L1 + L2 * cos(joelho))

	# +lean devolve a inclinação que a perna herdou do torso, para a IK resolver
	# num plano de fato vertical.
	var coxa_final: float = coxa + lean
	_add(off, papel_coxa, Vector3(coxa_final, 0, 0) * w)
	_add(off, papel_canela, Vector3(joelho, 0, 0) * w)

	# PÉ: no apoio fica PLANO no chão (cancela as duas juntas, exatamente — é o
	# "pé toca completamente o chão" da spec). No balanço, ponta levantada para
	# não raspar e para atacar o solo de calcanhar.
	var pe_ang: float = -(coxa_final + joelho)
	if not apoio:
		pe_ang += 0.30 * maxf(0.0, -sin(fase))
	_add(off, papel_pe, Vector3(pe_ang, 0, 0) * w)

func _air(off: Dictionary, w: float, vy: float) -> void:
	if w <= 0.001:
		return
	# Mesma isolação do braço direito de `_idle`/`_locomotion`: a investida da
	# Gura corre em cima de terreno qualquer, e ao passar por uma queda o `_air`
	# puxaria o braço erguido de volta para baixo no meio do golpe.
	var arm_r_w: float = w * (1.0 - _gura_rush_w)
	var rising := vy > 0.0
	if rising:
		_add(off, "Thigh_L", Vector3(0.7, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.7, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-1.1, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-1.1, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.4, 0, -0.2) * w)
		_add(off, "UpperArm_R", Vector3(-1.4, 0, 0.2) * arm_r_w)
	else:
		_add(off, "Thigh_L", Vector3(0.25, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.25, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.3, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.3, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(0.2, 0, -0.5) * w)
		_add(off, "UpperArm_R", Vector3(0.2, 0, 0.5) * arm_r_w)

## Nado autoral isolado: a cadência reage à velocidade, sem herdar a marcha.
func _swim(off: Dictionary, w: float, delta: float, speed01: float) -> void:
	if w <= 0.001:
		return
	var movimento := smoothstep(0.08, 0.48, speed01)
	_swim_phase = fposmod(_swim_phase + delta * lerpf(2.8, 4.8, movimento), TAU)
	NadoPoses.aplicar(_add, off, w, _swim_phase, movimento)


func _climb(off: Dictionary, w: float, phase: float) -> void:
	# ESCALADA hand-over-hand REFEITA: coordenação CONTRALATERAL (mão de um lado sobe
	# junto com o joelho do lado OPOSTO), com PESO — pausa nos extremos (agarra firme /
	# puxa forte), transferência de peso no tronco e follow-through do cotovelo.
	# Um ciclo completo (0..2PI) = duas braçadas (uma de cada braço).
	if w <= 0.001:
		return
	var s := sin(phase)
	# Timing com DWELL nos extremos: em vez de swing senoidal constante, segura o
	# agarre no topo e a puxada embaixo (smoothstep concentra o tempo nas pontas).
	var reach_l: float = smoothstep(-0.85, 0.85, s)     # 0=puxando(baixo) .. 1=agarrando(alto)
	var reach_r: float = 1.0 - reach_l
	var knee_l := reach_r                                # contralateral
	var knee_r := reach_l
	# Follow-through: o antebraço atrasa ~meia fase em relação ao ombro (2ário orgânico).
	var lag_l: float = smoothstep(-0.85, 0.85, sin(phase - 0.7))
	var lag_r: float = 1.0 - lag_l

	# --- BRAÇOS: alcançam BEM alto ao agarrar; dobram e PUXAM forte ao descer ---
	# ⚠️ CONVENÇÃO DO RIG: +X no UpperArm leva o braço para −Z (FRENTE, a parede);
	# −X leva para TRÁS. Até 03/10/2026 esta linha usava −0,9 → −3,0 ("x muito
	# negativo = pra cima") e o personagem escalava com as mãos para TRÁS, longe da
	# parede (relato do dono; medido: mão 0,11 m atrás do ombro em média).
	# +1,2 = cotovelo baixo, mão à frente na altura do peito (puxando); +2,6 = alto
	# e à frente (agarrando acima da cabeça) — sem passar da vertical, a mão fica
	# no plano da parede. z abre o cotovelo.
	_add(off, "UpperArm_L", Vector3(lerpf(1.2, 2.6, reach_r), 0.0, -lerpf(0.42, 0.06, reach_r)) * w)
	_add(off, "UpperArm_R", Vector3(lerpf(1.2, 2.6, reach_l), 0.0, lerpf(0.42, 0.06, reach_l)) * w)
	# ForeArm: reto no topo (mão agarra), flexiona na puxada — com follow-through.
	# 1,2 (não mais) para a mão continuar na parede em vez de voltar ao ombro.
	_add(off, "ForeArm_L", Vector3(lerpf(1.2, 0.05, lag_r), 0.0, -0.05) * w)
	_add(off, "ForeArm_R", Vector3(lerpf(1.2, 0.05, lag_l), 0.0, 0.05) * w)

	# --- PERNAS: joelho sobe a um apoio novo e depois ESTENDE empurrando o corpo ---
	_add(off, "Thigh_L", Vector3(lerpf(0.05, 1.78, knee_r), 0.0, -0.12) * w)
	_add(off, "Thigh_R", Vector3(lerpf(0.05, 1.78, knee_l), 0.0, 0.12) * w)
	_add(off, "Shin_L", Vector3(lerpf(-0.10, -1.7, knee_r), 0.0, 0.0) * w)
	_add(off, "Shin_R", Vector3(lerpf(-0.10, -1.7, knee_l), 0.0, 0.0) * w)
	# Pé aponta pra dentro da parede quando o joelho dobra (busca o apoio).
	_add(off, "Foot_L", Vector3(lerpf(0.10, 0.65, knee_r), 0.0, 0.0) * w)
	_add(off, "Foot_R", Vector3(lerpf(0.10, 0.65, knee_l), 0.0, 0.0) * w)

	# --- TRONCO/CABEÇA: cola na parede + TRANSFERÊNCIA DE PESO (torção+rolagem) ---
	# pitch pequeno p/ dentro; twist(Y) e roll(Z) seguem o lado que puxa dando swing ao corpo.
	_add(off, "Torso", Vector3(0.08, 0.20 * s, 0.11 * s) * w)
	_add(off, "Head", Vector3(-0.34, -0.16 * s, 0.0) * w)   # olha pra cima acompanhando as mãos

# Poses de PARKOUR (aditivas, ver pesos _wallrun_w/_roll_w/_ljump_w).
func _parkour(off: Dictionary, phase: float) -> void:
	# WALL RUN (#3, refeito 03/10/2026 — fatia 2). Pedido do dono: os dois pés
	# próximos/apoiados na parede, a mão do lado da parede auxilia no equilíbrio,
	# o torso levemente inclinado. A RAIZ já vem inclinada para longe da parede
	# pelo Player (pés nela); aqui: pernas correndo com as coxas buscando a
	# parede, mão do lado dela aberta até a parede, o outro braço bombando, e o
	# tronco e a cabeça devolvendo parte da inclinação (olhos nivelados).
	if _wallrun_w > 0.001:
		var w := _wallrun_w
		var s := sin(phase * 1.5)
		var l := float(parede_lado)
		_add(off, "Thigh_L", Vector3(-1.1 * s, 0, 0.15 * l) * w)
		_add(off, "Thigh_R", Vector3(1.1 * s, 0, 0.15 * l) * w)
		_add(off, "Shin_L", Vector3(-0.9 * clampf(-s, 0.0, 1.0), 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.9 * clampf(s, 0.0, 1.0), 0, 0) * w)
		_add(off, "Torso", Vector3(-0.3, 0, -0.15 * l) * w)   # à frente; volta um pouco p/ a parede
		_add(off, "Head", Vector3(0.2, 0, -0.25 * l) * w)     # olhos nivelados
		if parede_lado == 0:
			_add(off, "UpperArm_L", Vector3(1.5 * s, 0, -0.25) * w)
			_add(off, "UpperArm_R", Vector3(-1.5 * s, 0, 0.25) * w)
			_add(off, "ForeArm_L", Vector3(0.9, 0, 0) * w)
			_add(off, "ForeArm_R", Vector3(0.9, 0, 0) * w)
		else:
			# Braço da parede: abre até ela (z = abdução: + no direito, − no
			# esquerdo), um pouco à frente, cotovelo quase reto.
			var apoio := "R" if parede_lado > 0 else "L"
			var livre := "L" if parede_lado > 0 else "R"
			_add(off, "UpperArm_" + apoio, Vector3(0.35, 0, BRACO_NA_PAREDE * l) * w)
			_add(off, "ForeArm_" + apoio, Vector3(0.25, 0, 0) * w)
			# Braço livre: bomba com a passada, levemente afastado do corpo.
			var sinal_livre := 1.0 if livre == "L" else -1.0
			_add(off, "UpperArm_" + livre, Vector3(1.5 * s * sinal_livre, 0, -0.25 * l) * w)
			_add(off, "ForeArm_" + livre, Vector3(0.9, 0, 0) * w)
	# PENDURADO NA BORDA (escalada, fatia 3): as duas mãos em cima da borda, pés
	# apoiados na parede, cabeça olhando para cima.
	if _borda_w > 0.001:
		var w := _borda_w
		var balanco := sin(_t * 1.5) * 0.03
		# +X = à FRENTE (convenção do rig; ver `_climb`): mãos no alto, sobre a borda.
		_add(off, "UpperArm_L", Vector3(2.5, 0, -0.12) * w)
		_add(off, "UpperArm_R", Vector3(2.5, 0, 0.12) * w)
		_add(off, "ForeArm_L", Vector3(0.35, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(0.35, 0, 0) * w)
		_add(off, "Thigh_L", Vector3(0.45, 0, -0.1) * w)
		_add(off, "Thigh_R", Vector3(0.25, 0, 0.1) * w)
		_add(off, "Shin_L", Vector3(-0.7, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.5, 0, 0) * w)
		_add(off, "Foot_L", Vector3(0.3, 0, 0) * w)
		_add(off, "Foot_R", Vector3(0.3, 0, 0) * w)
		_add(off, "Torso", Vector3(0.05, 0, balanco) * w)
		_add(off, "Head", Vector3(-0.35, 0, 0) * w)
	# SUBINDO A BORDA (escalada, fatia 3) — pelo progresso, não pelo relógio: a
	# física é quem anda (sem teleporte) e a pose acompanha. Até 0,7 puxa o corpo:
	# braços passam de agarrando (alto) a empurrando a borda (ao lado do corpo), o
	# joelho direito sobe até a borda e o tronco debruça por cima. Depois, o passo
	# por cima devolve a pose ao neutro.
	if _subida_w > 0.001:
		var w := _subida_w
		var k1 := smoothstep(0.0, 1.0, clampf(subida_borda / 0.7, 0.0, 1.0))
		var k2 := smoothstep(0.0, 1.0, clampf((subida_borda - 0.7) / 0.3, 0.0, 1.0))
		var solta := 1.0 - k2
		# +2,5 (no alto, sobre a borda) → −0,2 (estendido junto ao quadril, empurrando).
		var braco := lerpf(2.5, -0.2, k1) * solta
		var cotovelo := 1.5 * sin(PI * k1) * solta
		_add(off, "UpperArm_L", Vector3(braco, 0, -0.15) * w)
		_add(off, "UpperArm_R", Vector3(braco, 0, 0.15) * w)
		_add(off, "ForeArm_L", Vector3(cotovelo, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(cotovelo, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(lerpf(lerpf(0.25, 1.7, k1), 0.5, k2), 0, 0.05) * w)
		_add(off, "Shin_R", Vector3(lerpf(-1.9 * k1, -0.6, k2), 0, 0) * w)
		_add(off, "Thigh_L", Vector3(lerpf(lerpf(0.45, -0.3, k1), 0.0, k2), 0, -0.05) * w)
		_add(off, "Shin_L", Vector3(-0.4 * solta, 0, 0) * w)
		_add(off, "Torso", Vector3(lerpf(-0.7 * k1, -0.2, k2), 0, 0) * w)
		_add(off, "Head", Vector3(lerpf(-0.35, 0.2, k1) * solta, 0, 0) * w)
	# ROLL do POUSO (#4): encolhe — joelhos ao peito, tronco dobrado, braços recolhidos.
	if _roll_w > 0.001:
		var w := _roll_w
		_add(off, "Thigh_L", Vector3(1.4, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(1.4, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-1.7, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-1.7, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.9, 0, 0) * w)    # dobra bem p/ frente
		_add(off, "Head", Vector3(0.45, 0, 0) * w)     # queixo ao peito
		_add(off, "UpperArm_L", Vector3(-0.8, 0, -0.6) * w)
		_add(off, "UpperArm_R", Vector3(-0.8, 0, 0.6) * w)
		_add(off, "ForeArm_L", Vector3(1.6, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(1.6, 0, 0) * w)
	# SALTO LONGO / VAULT (#1,#2): corpo estendido no ar — braços à frente, pernas atrás.
	if _ljump_w > 0.001:
		var w := _ljump_w
		# +X = à frente (o comentário sempre disse "braços à frente"; o sinal era −).
		_add(off, "UpperArm_L", Vector3(2.4, 0, -0.2) * w)
		_add(off, "UpperArm_R", Vector3(2.4, 0, 0.2) * w)
		_add(off, "ForeArm_L", Vector3(0.1, 0, 0) * w)
		_add(off, "ForeArm_R", Vector3(0.1, 0, 0) * w)
		_add(off, "Thigh_L", Vector3(-0.5, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(-0.5, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.2, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.2, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.35, 0, 0) * w)   # corpo mais horizontal (mergulho)

# DEDO-REVÓLVER (rajada Z mera/hie): braço direito ESTICADO à frente mirando como
# uma pistola; o modelo já vira p/ o alvo no yaw, então o -Z do braço aponta no alvo.
# gun_recoil (1->0 por tiro) dá o COICE: braço pula pra cima e o tronco recua.
func _finger_gun(off: Dictionary, w: float, pitch: float, gun_recoil: float, recoil_side: int) -> void:
	if w <= 0.001:
		return
	# x POSITIVO (~+1.5 = ~90°) estende o braço pra FRENTE (-Z); pitch inclina o cano
	# p/ cima/baixo. (x negativo puxaria pra TRÁS, como o _charge faz — era o bug.)
	var aim_x := 1.35 + clampf(pitch, -1.2, 1.2) * 0.72
	# O coice é um arco curto: ombro sobe/recua, cotovelo dobra e retorna até o
	# próximo tiro. A cadência de 160 ms deixa a leitura completa acontecer.
	var recoil_r := gun_recoil if recoil_side == 1 or recoil_side < 0 else 0.0
	var recoil_l := gun_recoil if recoil_side == 0 or recoil_side < 0 else 0.0
	var kick_r := recoil_r * 0.32
	var kick_l := recoil_l * 0.32
	var bend_r := recoil_r * 0.62
	var bend_l := recoil_l * 0.62
	# Os dois braços começam compactos e apontados; apenas a mão que disparou faz
	# o arco de recuo. Isto impede o T-pose no ar e deixa o tiro alternado legível.
	_add(off, "UpperArm_R", Vector3(aim_x + kick_r, 0.0, 0.10) * w)
	_add(off, "ForeArm_R", Vector3(0.18 + bend_r, 0.0, 0.0) * w)
	_add(off, "UpperArm_L", Vector3(aim_x + kick_l, 0.0, -0.10) * w)
	_add(off, "ForeArm_L", Vector3(0.18 + bend_l, 0.0, 0.0) * w)
	# APENAS os braços empunhando as armas ficam fixos à frente! As pernas e o corpo ficam livres!
	_add(off, "Head", Vector3(0.0, -pitch * 0.5, 0.0) * w)

# POSES DA BUKI BUKI (21/11/2026): uma empunhadura por arma, em CAMADA sobre a marcha — só os braços (e um pouco de tronco) são da arma; pernas, quadril e balanço
# da corrida seguem o `_locomotion`. Parado: mira firme; andando: a arma balança de leve; CORRENDO (`is_sprinting`): a arma baixa e o tronco inclina para a frente,
# sem congelar o passo. `w` = peso da pose de arma (0→1), `speed01` = 0..1 da velocidade, `gun_recoil` = coice (1→0 por tiro). Convenção: UpperArm x ≈ 1,35 = braço à frente.
#   Z pistola: braço direito estendido, mão esquerda apoia · C sniper: fuzil nos dois braços, coronha no ombro · V minigun: quadril, braço direito no cabo e esquerdo no cano.
func _buki_pose(off: Dictionary, w: float, slot: String, pitch: float, gun_recoil: float, speed01: float, sprinting: bool) -> void:
	if w <= 0.001:
		return
	var correr := 1.0 if sprinting and speed01 > 0.5 else 0.0
	var andar := clampf(speed01, 0.0, 1.0)
	var baixa := correr * 0.75                                   # quanto a arma desce na corrida
	var bob := sin(_phase * 2.0) * 0.05 * andar                  # a arma acompanha o passo
	var mira := clampf(pitch, -1.2, 1.2) * 0.72 * (1.0 - correr)
	var coice := gun_recoil * 0.32
	match slot:
		"Z":
			_add(off, "UpperArm_R", Vector3(1.35 + mira + coice - baixa + bob, 0.0, 0.10) * w)
			_add(off, "ForeArm_R", Vector3(0.18 + gun_recoil * 0.62, 0.0, 0.0) * w)
			_add(off, "UpperArm_L", Vector3(1.10 + mira * 0.8 - baixa + bob, 0.0, -0.42) * w)
			_add(off, "ForeArm_L", Vector3(0.75, 0.0, 0.0) * w)
		"C":
			# Braço direito = geometria do `_finger_gun` (ombro 1,35, cotovelo 0,18): é a que alinha o cano dos GLBs (cotovelo dobrado erguia/baixava a arma — capturas 21/11).
			_add(off, "UpperArm_R", Vector3(1.10 + mira + coice - baixa * 0.9 + bob * 0.5, 0.0, 0.10) * w)
			_add(off, "ForeArm_R", Vector3(0.70, 0.0, 0.0) * w)
			_add(off, "UpperArm_L", Vector3(1.45 + mira - baixa * 0.9 + bob * 0.5, 0.0, -0.30) * w)
			_add(off, "ForeArm_L", Vector3(0.70, 0.0, 0.0) * w)
			_add(off, "Torso", Vector3(0.0, -0.18 * (1.0 - correr), 0.0) * w)      # ombro da coronha para a frente
		"V":
			_add(off, "UpperArm_R", Vector3(0.95 + mira * 0.6 + coice * 0.6 - baixa * 0.6 + bob, 0.0, 0.14) * w)
			_add(off, "ForeArm_R", Vector3(0.80, 0.0, 0.0) * w)
			_add(off, "UpperArm_L", Vector3(1.15 + mira * 0.6 - baixa * 0.5 + bob, 0.0, -0.55) * w)
			_add(off, "ForeArm_L", Vector3(0.65, 0.0, 0.0) * w)
			_add(off, "Torso", Vector3(-0.10 + coice * 0.4, 0.0, 0.0) * w)         # peso para trás contra o recuo da minigun
	_add(off, "Torso", Vector3(0.14 * correr, 0.0, 0.0) * w)                       # corrida: inclina à frente
	_add(off, "Head", Vector3(0.0, -pitch * 0.5, 0.0) * w)

# INVESTIDA DA GURA GURA (Z): o Barba Branca avançando em MEIA T — o braço
# DIREITO aberto PARA O LADO na altura do ombro, o ESQUERDO de fora da pose,
# continuando o balanço da corrida. É pose ASSIMÉTRICA de propósito: só o braço
# direito sai da marcha (ver `arm_r_w` em `_idle`/`_locomotion`/`_air`); tronco,
# pernas e braço esquerdo seguem correndo, e é isso que faz a investida ler como
# CORRIDA e não como pose parada deslizando pelo chão. Por isso `_gura_rush_w`
# NÃO entra no `upper_free` lá em cima, ao contrário das outras poses especiais.
#
# ⚠️ QUAL EIXO ABRE O BRAÇO — a armadilha que esta pose tinha. O membro pende no
# -Y local; girar +X leva a ponta para -Z (FRENTE, a convenção da IK da perna) e
# girar Z leva a ponta para o LADO. São coisas diferentes:
#     UpperArm_R.x ≈ 1,57  ->  braço apontando À FRENTE
#     UpperArm_R.z ≈ -1,57 ->  braço aberto PARA O LADO DIREITO (o T)
# A versão anterior usava `(1.4, 0.1, 0.3)`: 1,4 no eixo X é o braço quase
# horizontal À FRENTE, e o +0,3 no Z ainda cruzava o braço por cima do peito.
# Medido com `tools/dev_tests/medir_gura_rush.gd`: 93,2° do chão (a horizontal),
# mas com o punho a 0,92 de alcance À FRENTE do ombro e 0,14 ABAIXO dele — ou
# seja, socando, não abrindo. O comentário dela dizia "socando para a frente",
# contradizendo o nome da variável (`braço direito levantado`) e o pedido.
#
# O "T" deste projeto mora hoje em `src/anim/GuraPoses.gd` (tabela `_V_T`, do
# estado `gura_v_tpose`): ombro em z = ±1,4 e cotovelo em x = -0,08. Reaproveitado
# aqui de propósito, com o sinal do lado direito, para as duas poses não
# inventarem cada uma o seu T. Medido, 1,4 rad dá 80° do chão — 10° abaixo da
# horizontal exata; quem quiser o T no esquadro troca por ±1,5708 nos DOIS lugares.
# O `tools/dev_tests/test_gura_animacoes.gd` trava esses números.

## O TRONCO ACOMPANHA A CÂMERA (12/11/2026): olhar para baixo curva o corpo para a frente A PARTIR DA CINTURA (osso `Torso`), olhar para cima inclina para trás; a cabeça faz o resto.
## `pitch` = o da câmera; 0,25 abaixo da horizontal (`Player.PITCH_DE_DESCANSO`) é o repouso e deixa o corpo em pé. A divisão é ~55 % tronco, ~45 % cabeça, para o olhar chegar
## ao total sem dobrar o pescoço. Suaviza para não tremer com o mouse. Quem ocupa o tronco (golpe, carga, pose de skill) já zera o peso `w`.
const PITCH_DE_REPOUSO := -0.25
const INCLINACAO_DO_TRONCO := 0.42       # rad de tronco por rad de câmera
const INCLINACAO_MAXIMA_DO_TRONCO := 0.62
var _tronco_pitch := 0.0

func _lookat(off: Dictionary, pitch: float, w: float, delta := 0.0166) -> void:
	if w <= 0.001:
		_tronco_pitch = lerpf(_tronco_pitch, 0.0, 1.0 - exp(-12.0 * delta))
		return
	_add(off, "Head", Vector3(clampf(-pitch * 0.35, -0.5, 0.5), 0, 0) * w)
	var alvo := clampf(-(pitch - PITCH_DE_REPOUSO) * INCLINACAO_DO_TRONCO, -INCLINACAO_MAXIMA_DO_TRONCO, INCLINACAO_MAXIMA_DO_TRONCO)
	_tronco_pitch = lerpf(_tronco_pitch, alvo, 1.0 - exp(-14.0 * delta))
	_add(off, "Torso", Vector3(_tronco_pitch, 0, 0) * w)

# Pose de CHARGE (estilingue):
	# - Z (Pistol): braço direito puxado p/ trás+cima, cotovelo dobrado, tronco em leve torção/recuo (tensão).
	# - X (Bazooka): dois braços simultaneamente para trás, peito avança, cotovelos flexionam levemente.
func _charge(off: Dictionary, w: float, slot: String) -> void:
	if w <= 0.001:
		return
	if slot == "X":
		_add(off, "UpperArm_R", Vector3(-1.8, 0, 0.4) * w)   
		_add(off, "ForeArm_R", Vector3(1.6, 0, 0) * w)          
		_add(off, "UpperArm_L", Vector3(-1.8, 0, -0.4) * w)     
		_add(off, "ForeArm_L", Vector3(1.6, 0, 0) * w)         
		_add(off, "Torso", Vector3(0.2, 0, 0) * w)            
		_add(off, "Head", Vector3(-0.15, 0, 0) * w)
	elif slot == "C":
		# Gatling Charge: postura agressiva, joelhos flexionados, braços recuados e tensionados, tronco inclinado
		_add(off, "Thigh_L", Vector3(0.4, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.4, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.6, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.6, 0, 0) * w)
		_add(off, "Torso", Vector3(-0.25, 0, 0) * w)
		_add(off, "UpperArm_R", Vector3(-1.4, 0, 0.2) * w)
		_add(off, "ForeArm_R", Vector3(1.7, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.4, 0, -0.2) * w)
		_add(off, "ForeArm_L", Vector3(1.7, 0, 0) * w)
		_add(off, "Head", Vector3(0.25, 0, 0) * w)
	elif slot == "V":
		# Red Hawk Charge: Postura agressiva extrema, braço direito puxado para trás
		_add(off, "Thigh_L", Vector3(0.5, 0, 0) * w)
		_add(off, "Thigh_R", Vector3(0.5, 0, 0) * w)
		_add(off, "Shin_L", Vector3(-0.7, 0, 0) * w)
		_add(off, "Shin_R", Vector3(-0.7, 0, 0) * w)
		_add(off, "Torso", Vector3(0.1, -0.4, 0) * w)
		_add(off, "UpperArm_R", Vector3(0.4, 0, 0.3) * w)
		_add(off, "ForeArm_R", Vector3(1.8, 0, 0) * w)
		_add(off, "UpperArm_L", Vector3(-1.9, 0, -0.5) * w)
		_add(off, "Head", Vector3(0.1, 0.4, 0) * w)
	else:
		_add(off, "UpperArm_R", Vector3(0.35, 0, 0.15) * w)   
		_add(off, "ForeArm_R", Vector3(1.5, 0, 0) * w)          
		_add(off, "UpperArm_L", Vector3(-1.7, 0, -0.35) * w)     
		_add(off, "Torso", Vector3(0.06, -0.32, 0) * w)         
		_add(off, "Head", Vector3(0, 0.26, 0) * w)              

var _recovery_slot := "Z"
# Dispara o tranco elástico de RECEPÇÃO (chicote) quando o punho volta ao corpo.
func trigger_recovery(slot: String = "Z") -> void:
	_recovery_t = REC_DUR
	_recovery_slot = slot

# Recepção: solavanco decaindo — ombro, tronco p/ frente, saltinho dos pés e chicote.
func _recovery(off: Dictionary, delta: float) -> void:
	if _recovery_t <= 0.0:
		return
	_recovery_t = maxf(_recovery_t - delta, 0.0)
	var k := _recovery_t / REC_DUR                 # 1 -> 0
	var whip := sin((1.0 - k) * PI * 2.5) * k      # oscila e decai (chicote)
	var pull := absf(whip)
	
	if _recovery_slot == "X":
		_add(off, "Torso", Vector3(-0.85 * whip, 0, 0))   # tranco muito maior p/ frente
		_add(off, "UpperArm_R", Vector3(-1.9 * whip, 0, -0.2)) # ambos solavancos violentos
		_add(off, "UpperArm_L", Vector3(-1.9 * whip, 0, 0.2))  
		_add(off, "ForeArm_R", Vector3(1.4 * pull, 0, 0))
		_add(off, "ForeArm_L", Vector3(1.4 * pull, 0, 0))
		_add(off, "Thigh_L", Vector3(0.85 * pull, 0, 0))             
		_add(off, "Thigh_R", Vector3(0.85 * pull, 0, 0))
		_add(off, "Head", Vector3(-0.35 * whip, 0, 0))
	elif _recovery_slot == "C":
		_add(off, "Torso", Vector3(-0.45 * whip, 0, 0.1 * whip))
		_add(off, "UpperArm_R", Vector3(-1.2 * whip, 0, 0))
		_add(off, "UpperArm_L", Vector3(-1.2 * whip, 0, 0))
		_add(off, "ForeArm_R", Vector3(0.7 * pull, 0, 0))
		_add(off, "ForeArm_L", Vector3(0.7 * pull, 0, 0))
		_add(off, "Thigh_L", Vector3(0.3 * pull, 0, 0))
		_add(off, "Thigh_R", Vector3(0.3 * pull, 0, 0))
	elif _recovery_slot == "V":
		# Red Hawk Recovery: Ajoelhado após o impacto massivo
		# T = 1 -> 0. Puxa forte p/ baixo, levanta no final.
		_add(off, "Thigh_L", Vector3(1.2 * k, 0, 0))
		_add(off, "Thigh_R", Vector3(1.2 * k, 0, 0))
		_add(off, "Shin_L", Vector3(-1.5 * k, 0, 0))
		_add(off, "Shin_R", Vector3(-1.5 * k, 0, 0))
		_add(off, "Torso", Vector3(0.4 * k, 0, 0))
		_add(off, "UpperArm_R", Vector3(0.5 * k, 0, -0.3 * k))
		_add(off, "Head", Vector3(-0.2 * k, 0, 0))
	else:
		_add(off, "Torso", Vector3(-0.55 * whip, 0, 0.12 * whip))   
		_add(off, "UpperArm_R", Vector3(-1.5 * whip, 0, 0))          
		_add(off, "ForeArm_R", Vector3(0.9 * pull, 0, 0))
		_add(off, "Thigh_L", Vector3(0.55 * pull, 0, 0))             
		_add(off, "Thigh_R", Vector3(0.55 * pull, 0, 0))
		_add(off, "Head", Vector3(-0.22 * whip, 0, 0))

# POSE DE ENTRADA DO HIBASHIRA (Mera Mera C): Soca o chão no centro e abre as pernas numa
# postura de firmeza de combate (power stance), permanecendo em imobilidade imune e imponente.

# POSE DE ESPIRAL NEGRA / KUROUZU (Yami Yami X): Levanta o braço direito diretamente à frente
# para atrair e segurar a vítima firmemente no ar pela força da gravidade abissal.

# POSE DO BARBA NEGRA / BLACK HOLE (Yami Yami C): Pernas afastadas em base firme e uma
# mão para baixo direcionada ao solo gerando o pântano de trevas.
