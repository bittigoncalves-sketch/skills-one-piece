class_name MeleePoses
extends RefCounted
# ============================================================================
#  POSES DO COMBO DESARMADO — postura de luta durante os clipes bakeados do
#  Mixamo (`ProceduralAnimator.play_baked`), criadas em 2026-08-18.
#
#  ⚠️ ESTE ARQUIVO NÃO SEGUE O PADRÃO DE `FruitPoses.gd` / `GuraPoses.gd` — E É
#  DE PROPÓSITO. NÃO "corrija" isto para `add.call(off, papel, offset * w)`.
#
#  O padrão `add.call(off, ...)` funciona porque as poses de fruta rodam DENTRO
#  do pipeline aditivo do `ProceduralAnimator.update()` — o `off` é o
#  Dictionary desse pipeline, e `add` é o Callable que escreve nele (com
#  espelhamento de `is_backwards` e filtro de `_n.has(role)` embutidos).
#
#  O combo desarmado NÃO passa por ali. `update()` toca o clipe bakeado do
#  Mixamo (soco/chute) via `_apply_baked()`, e o próprio `update()` faz
#  `return` IMEDIATAMENTE depois de chamar `_apply_baked(delta)` (ver o `if
#  _baked != null: ... return` logo no início de `update()`). Ou seja: enquanto
#  o soco está tocando, o `off`/`add` do pipeline aditivo NEM EXISTE naquele
#  frame — ele é pulado por completo, junto com todo o resto de `update()`.
#
#  Por isso as funções abaixo não recebem `add`/`off`/`w`: elas devolvem
#  Dictionary papel -> Vector3 (um OFFSET sobre a rotação de descanso, `_rest`,
#  daquele papel) para o `ProceduralAnimator._apply_baked()` aplicar ele mesmo,
#  como um passo de OVERRIDE rodado DEPOIS do loop que copia o clipe bakeado e
#  ANTES do `_driver.push()` (senão o override nunca chega aos ossos dos
#  personagens skinnados/Meshy — só apareceria nos voxel). Quem lê estes
#  Dictionaries e faz o lerp/soma é o próprio animador; ver `_apply_baked`.
#
#  CONVENÇÕES DO RIG (as mesmas medidas em `GuraPoses.gd`):
#    Torso.x   NEGATIVO = tronco à FRENTE
#    Torso.y   torção do tronco (twist), sinal por lado
#    UpperArm.z  ±alto = braço aberto na horizontal (sinal −L / +R)
#    ForeArm.x   POSITIVO = cotovelo DOBRADO
#    Thigh.z   abre a perna de lado (sinal −L / +R);  Shin.x NEGATIVO = joelho dobrado
#
#  MAGNITUDE: a base de combate aqui é uma GUARDA DE BOXE em pé, não um golpe
#  especial — bem mais sutil que `FruitPoses.hibashira_pose` (que dobra o
#  tronco quase ao chão). Os números abaixo ficam por volta de 40-50% da
#  abertura de perna do Hibashira, e o balanço do torso fica na faixa de
#  ~0,05-0,15 rad para ler como peso do corpo, não como um tranco.
# ============================================================================

# Pernas abertas em V, base de boxe, joelhos levemente flexionados.
# `perna_ativa`: "" (nenhuma — os dois socos usam as duas pernas de apoio),
# "R" ou "L" — a perna que ESTÁ CHUTANDO nesse instante. Essa perna é
# controlada pelo próprio clipe bakeado (o chute), então suas entradas SAEM do
# dicionário devolvido, para o override não competir com a animação do chute.
static func pernas_v(perna_ativa: String = "") -> Dictionary:
	var pose := {
		"Thigh_L": Vector3(0.15, 0.0, -0.30),
		"Thigh_R": Vector3(0.15, 0.0, 0.30),
		"Shin_L": Vector3(-0.40, 0.0, 0.0),
		"Shin_R": Vector3(-0.40, 0.0, 0.0),
		"Foot_L": Vector3(0.16, 0.0, 0.10),
		"Foot_R": Vector3(0.16, 0.0, -0.10),
	}
	if perna_ativa == "R":
		pose.erase("Thigh_R")
		pose.erase("Shin_R")
		pose.erase("Foot_R")
	elif perna_ativa == "L":
		pose.erase("Thigh_L")
		pose.erase("Shin_L")
		pose.erase("Foot_L")
	return pose

# Guarda: punho perto do queixo, cotovelo protegendo o tronco.
# `lado_ativo`: "R" — o braço direito está socando (controlado pelo clipe);
# só o ESQUERDO entra na guarda. "L" — o inverso, só o DIREITO entra. "perna"
# — é um chute: os dois braços estão livres e os dois entram em guarda.
static func guarda_bracos(lado_ativo: String) -> Dictionary:
	var guarda_l := {
		"UpperArm_L": Vector3(0.35, 0.0, -0.30),
		"ForeArm_L": Vector3(1.70, 0.0, 0.0),
	}
	var guarda_r := {
		"UpperArm_R": Vector3(0.35, 0.0, 0.30),
		"ForeArm_R": Vector3(1.70, 0.0, 0.0),
	}
	match lado_ativo:
		"R":
			return guarda_l
		"L":
			return guarda_r
		"perna":
			var pose := {}
			pose.merge(guarda_l)
			pose.merge(guarda_r)
			return pose
		_:
			return {}

# Balanço do torso: transferência de peso durante o golpe. `t_progresso` é
# 0..1 (progresso dentro do clipe bakeado); `lado` é -1.0/+1.0 (para que lado
# o peso se inclina). Sobe e relaxa ao longo do golpe — sin(π·t) começa e
# termina em zero e pica no meio, quando o punho/chute "conecta". É um offset
# ADITIVO: quem chama SOMA isto na rotação já calculada do Torso, não
# substitui.
static func balanco_torso(t_progresso: float, lado: float) -> Vector3:
	var peso := sin(clampf(t_progresso, 0.0, 1.0) * PI)
	return Vector3(0.0, lado * peso * 0.12, lado * peso * 0.05)
