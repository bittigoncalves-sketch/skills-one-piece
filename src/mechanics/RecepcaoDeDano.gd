class_name RecepcaoDeDano
extends RefCounted
# ============================================================================
#  ANIMAÇÃO DE RECEPÇÃO DE DANO — a mecânica que NÃO EXISTIA.
#
#  Pedido do dono (2026-08-14): "animação de recepção de dano: vai ocorrer
#  sempre que o jogador receber dano".
#
#  O QUE JÁ HAVIA, E POR QUE NÃO BASTAVA
#  -------------------------------------
#  `Player._feedback_de_dano` fazia três coisas: flash vermelho no modelo, som de
#  dor e número flutuante. Nenhuma delas é ANIMAÇÃO — o boneco continuava correndo
#  como se nada tivesse acontecido, e um golpe que tira 500 de vida lia igual a um
#  que tira 5. O corpo não reagia.
#
#  POR QUE POSE PROCEDURAL E NÃO CLIPE ASSADO
#  ------------------------------------------
#  Havia duas saídas, e a escolha aqui é deliberada:
#
#   • clipe do Mixamo (`play_baked`): o rig tem 29 clipes e um deles serviria.
#     MAS `_apply_baked` faz `return` no `update()` — enquanto um clipe assado
#     toca, TODA a animação procedural morre: locomoção, pulo, idle. Levar um tiro
#     enquanto corre pararia a corrida. Pior, é exatamente o buraco dos itens
#     37/38: o soco da Gura sequestra o rig por 7,37 s por causa disso.
#   • POSE PROCEDURAL somada por cima (o que está aqui): o tranco entra e sai por
#     peso, misturado ao que o corpo já estava fazendo. Levar um tiro correndo
#     continua sendo uma corrida — com um tranco.
#
#  Para um flinch de 0,3 s que acontece o tempo todo, a segunda é a única que não
#  atrapalha o jogo. Um clipe assado faria sentido para uma animação de morte,
#  que legitimamente toma o corpo.
#
#  ⚠️ GATILHO DECLARADO: se um dia o flinch precisar variar por direção do golpe
#  (levar de costas ≠ levar de frente), esta pose ganha um parâmetro de direção e
#  vira duas ou quatro variações. Hoje é uma só, porque uma só é o que o pedido
#  pede e o dono cobra complexidade adequada.
#
#  DEPENDÊNCIA CONHECIDA: a mecânica "dano de paralisia" (a outra do pedido) usa
#  esta pose — paralisar sem animar era meio caminho. Ver `paralisar_com_animacao`.
# ============================================================================

# Quanto tempo o tranco dura. Curto de propósito: é reação, não interrupção.
# 0,30 s ≈ 18 quadros a 60 fps — o bastante para o olho registrar e pouco o
# bastante para não atrapalhar quem está no meio de um pulo.
const DURACAO := 0.30

# Nome da pose no `custom_pose`. É o mesmo mecanismo que as poses de fruta já
# usam (`hibashira`, `kurouzu`, `gura_rush`), então não há mecanismo novo para
# manter — só mais um valor.
const POSE := "dano"
const POSE_KNOCKDOWN := "knockdown"

# Rigidez da entrada e da saída do peso. ALTA de propósito: o tranco tem que
# BATER, não deslizar para dentro. As poses de fruta usam 15–25; esta usa 40 na
# entrada porque o impacto é instantâneo.
const RIGIDEZ_ENTRA := 40.0
const RIGIDEZ_SAI := 14.0

# ------------------------------------------------------------------- a pose
# O tranco. Assinatura igual à das poses de fruta (`FruitPoses`), de propósito:
# quem já sabe mexer numa sabe mexer nesta.
#
# `add` é o `_add` do animador passado como Callable — ele carrega o
# espelhamento de `is_backwards` e o filtro de papéis que o rig não tem.
# Reimplementar isso aqui duplicaria regra.
static func pose(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return

	# Tremor rápido, some junto com o peso. É o que separa "tomou um golpe" de
	# "está fazendo uma pose": pose parada lê como intenção, tremor lê como
	# involuntário.
	var tremor: float = sin(t * 55.0) * 0.05 * w

	# TRONCO recuando e torcendo. O recuo (x positivo = topo pra trás) é o sinal
	# principal — é o que o olho lê como "levou".
	add.call(off, "Torso", Vector3(0.34 + tremor, 0.16, 0.0) * w)

	# CABEÇA jogada para trás e para o lado, um pouco ATRASADA em relação ao
	# tronco (o `0.8`): corpo e cabeça chegando juntos lê como robô.
	add.call(off, "Head", Vector3(-0.45 - tremor, -0.22, 0.0) * w * 0.8)

	# BRAÇOS subindo em guarda reflexa, assimétricos de propósito — reação
	# simétrica lê como coreografia. O direito sobe mais (é o lado +X desde
	# 2026-08-14; ver item 39 da LISTA_DE_CORRECOES).
	add.call(off, "UpperArm_R", Vector3(-0.85, 0.0, 0.55) * w)
	add.call(off, "ForeArm_R", Vector3(1.10, 0.0, 0.0) * w)
	add.call(off, "UpperArm_L", Vector3(-0.55, 0.0, -0.35) * w)
	add.call(off, "ForeArm_L", Vector3(0.85, 0.0, 0.0) * w)

	# PERNAS cedendo um pouco. Sem isto o boneco leva o golpe "de pé firme" e o
	# tranco fica só da cintura pra cima, que é o erro clássico de flinch.
	add.call(off, "Thigh_R", Vector3(0.18, 0.0, 0.0) * w)
	add.call(off, "Thigh_L", Vector3(0.12, 0.0, 0.0) * w)
	add.call(off, "Shin_R", Vector3(-0.24, 0.0, 0.0) * w)
	add.call(off, "Shin_L", Vector3(-0.18, 0.0, 0.0) * w)

# O tranco de ser derrubado no chão.
static func pose_knockdown(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	
	# Torso deita quase 90 graus para trás (-1.5 radianos no eixo X).
	add.call(off, "Torso", Vector3(1.5, 0.0, 0.0) * w)
	# Cabeça acompanha
	add.call(off, "Head", Vector3(0.2, 0.0, 0.0) * w)
	
	# Braços abertos/caídos
	add.call(off, "UpperArm_R", Vector3(0.5, 0.0, 0.8) * w)
	add.call(off, "UpperArm_L", Vector3(0.5, 0.0, -0.8) * w)
	
	# Pernas esticadas/levemente levantadas para acompanhar a queda
	add.call(off, "Thigh_R", Vector3(-1.0, 0.0, 0.0) * w)
	add.call(off, "Thigh_L", Vector3(-1.0, 0.0, 0.0) * w)
	add.call(off, "Shin_R", Vector3(0.5, 0.0, 0.0) * w)
	add.call(off, "Shin_L", Vector3(0.5, 0.0, 0.0) * w)

# ------------------------------------------------------------------ disparo
# Liga o tranco num corpo. Serve para o Player e para qualquer coisa com meta
# (o `TrainingDummy` também aceita).
#
# NÃO agenda o desligamento com um timer solto: quem apaga é o próprio contador
# em `tick()`. Timer solto foi como a morte deixava `is_casting` pendurado para
# sempre (item 23) — o respawn não tinha como cancelar o que já estava agendado.
static func aplicar(corpo: Node, duracao: float = DURACAO) -> void:
	if corpo == null or not is_instance_valid(corpo):
		return
	# Não sobrescreve uma pose que TOMA o corpo (cast, black hole, ultimate):
	# o tranco é reação, e reação não pode cancelar um golpe em andamento — quem
	# cancela golpe é a mecânica de INTERRUPÇÃO POR DANO, que é outra e tem
	# regra própria (janela `is_casting`).
	var atual: String = str(corpo.get_meta("custom_pose", ""))
	if atual != "" and atual != POSE:
		return
	corpo.set_meta("custom_pose", POSE)
	corpo.set_meta("_dano_pose_t", maxf(duracao, 0.05))

# Faz o contador andar. Chamado do `_physics_process` de quem usa.
# Devolve `true` enquanto o tranco está valendo.
static func tick(corpo: Node, delta: float) -> bool:
	if corpo == null or not is_instance_valid(corpo):
		return false
	if not corpo.has_meta("_dano_pose_t"):
		return false
	var t: float = float(corpo.get_meta("_dano_pose_t")) - delta
	if t <= 0.0:
		corpo.remove_meta("_dano_pose_t")
		var cp: String = str(corpo.get_meta("custom_pose", ""))
		if cp == POSE or cp == POSE_KNOCKDOWN:
			corpo.set_meta("custom_pose", "")
		# Solta a paralisia SE ela for nossa. O `is_frozen` é compartilhado com o
		# gelo da Hie Hie; descongelar sem conferir soltaria o alvo do outro golpe.
		if bool(corpo.get_meta("_dano_paralisia", false)):
			corpo.remove_meta("_dano_paralisia")
			corpo.set_meta("is_frozen", false)
			StatusFX.remover(corpo, StatusFX.CONGELADO)
		return false
	corpo.set_meta("_dano_pose_t", t)
	return true

# Limpeza — o respawn chama. Ver item 23: estado de combate que sobrevive à morte
# trava o jogo para o resto da partida.
static func limpar(corpo: Node) -> void:
	if corpo == null or not is_instance_valid(corpo):
		return
	if corpo.has_meta("_dano_pose_t"):
		corpo.remove_meta("_dano_pose_t")
	if corpo.has_meta("_dano_paralisia"):
		corpo.remove_meta("_dano_paralisia")
		corpo.set_meta("is_frozen", false)
	var cp: String = str(corpo.get_meta("custom_pose", ""))
	if cp == POSE or cp == POSE_KNOCKDOWN:
		corpo.set_meta("custom_pose", "")

# ------------------------------------------------- DANO DE PARALISIA (mec. 1)
# "quando o jogador receber dano de certas skills ele é paralisado por um certo
# período enquanto exibe a animação de recepção de dano" — palavras do dono.
#
# É a soma de duas mecânicas que já existiam separadas: a paralisia (que o campo
# `paralisa` da DamageZone já aplicava) e este tranco. O que faltava era
# justamente a segunda metade.
#
# A animação dura o TEMPO TODO da paralisia, não os 0,30 s do flinch normal: um
# alvo preso 1,2 s com o corpo em pose de corrida parada lê como travamento de
# jogo, não como golpe.
static func paralisar_com_animacao(corpo: Node, duracao: float) -> void:
	if corpo == null or not is_instance_valid(corpo) or duracao <= 0.0:
		return
	corpo.set_meta("is_frozen", true)
	# Marca que ESTE congelamento é nosso. Sem isso, o `tick` não teria como
	# distinguir a paralisia do congelamento da Hie Hie, e descongelaria o gelo
	# do outro golpe junto — duas mecânicas escrevendo no mesmo `is_frozen`.
	corpo.set_meta("_dano_paralisia", true)
	StatusFX.aplicar(corpo, StatusFX.CONGELADO, duracao)
	# Aqui a pose IGNORA a guarda de "não sobrescrever", de propósito: paralisia
	# vence pose de golpe — o alvo perdeu o controle do corpo.
	corpo.set_meta("custom_pose", POSE)
	corpo.set_meta("_dano_pose_t", duracao)

# Derruba no chão (Knockdown). Usa o mesmo fluxo de pose, mas bloqueia o controle.
static func derrubar_com_animacao(corpo: Node, duracao: float) -> void:
	if corpo == null or not is_instance_valid(corpo) or duracao <= 0.0:
		return
	# Não usa is_frozen para não matar o knockback físico da engine,
	# mas aplica a pose de knockdown e a meta.
	corpo.set_meta("custom_pose", POSE_KNOCKDOWN)
	corpo.set_meta("_dano_pose_t", duracao)
