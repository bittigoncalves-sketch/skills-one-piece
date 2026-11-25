class_name GolpeDirecional
extends Resource
# ============================================================================
#  FICHA DE UM GOLPE — combate direcional do Modo História.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (§7). Tempos em segundos, giro em
#  graus por segundo, fatores entre 0 e 1.
#
#  É a FONTE ÚNICA do golpe: o executor conta as fases por aqui, e a pose, a
#  varredura de contato e a IA leem os mesmos campos. Nenhum número de golpe mora
#  no código — quem quiser um golpe mais lento edita o `.tres` do estilo.
#
#  ⚠️ OS PADRÕES ABAIXO SÃO NEUTROS DE PROPÓSITO (tempo 0, movimento inteiro, giro
#  livre). O Godot NÃO grava no `.tres` campo igual ao padrão do script: com um
#  padrão "bom" (preparo 0,30), o jab guardaria o tempo DENTRO DO CÓDIGO, e mudar
#  o padrão mudaria o golpe em silêncio. Neutro obriga todo número real a estar
#  escrito no `.tres` — e tempo zero é recusado por `validar()`.
#
#  ⚠️ Campo sem consumidor é número que ninguém confere: todo campo daqui tem um
#  leitor no executor, na pose ou na resolução de contato.
# ============================================================================

## Para onde o golpe VIAJA, visto por quem ataca. `PARA_ESQUERDA` começa do lado
## direito do atacante e termina no esquerdo (mouse para a esquerda). O nome é
## pela viagem, e não pela origem, de propósito: "golpe esquerdo" já significou as
## duas coisas neste projeto.
## As 4 primeiras são as direções do gesto do mouse (todo estilo tem EXATAMENTE um golpe em cada). As 3 últimas são ENCAIXES EXTRAS, opcionais
## (0 ou 1 golpe), que o Epic Fight usa: o 4º auto da cadeia, o golpe de corrida (dash) e o golpe de ar (airslash). Nunca saem do gesto: a entrada
## escolhe `CORRIDA`/`NO_AR` pelo estado do corpo e `AUTO_4` pela sequência de cliques; `HABILIDADE` é pedido só pela habilidade inata da arma (tecla R).
enum Direcao { FRENTE, PARA_ESQUERDA, PARA_DIREITA, DE_CIMA, AUTO_4, NO_AR, CORRIDA, HABILIDADE, HABILIDADE_2, HABILIDADE_3 }
const DIRECOES_BASE := 4

## As fases em ordem. `FIM` é o instante depois da recuperação — o executor usa a
## ordem numérica para atravessar fases uma a uma num delta grande.
enum Fase { PREPARO, ATIVO, RECUPERACAO, FIM }

@export var id: StringName
@export var nome := ""
@export var direcao: Direcao = Direcao.FRENTE

@export_group("Fases")
## Antecipação: o corpo carrega o golpe; ainda não há contato.
@export_range(0.0, 2.0, 0.01, "suffix:s") var preparo := 0.0
## Janela de contato: única fase em que o golpe pode acertar.
@export_range(0.0, 1.0, 0.01, "suffix:s") var ativo := 0.0
## Rabo do golpe: o corpo volta à guarda e fica exposto.
@export_range(0.0, 2.0, 0.01, "suffix:s") var recuperacao := 0.0

@export_group("Efeito")
@export_range(0.0, 1000.0, 0.5) var dano := 0.0
## Tempo que o alvo atingido fica sem agir (reação).
@export_range(0.0, 2.0, 0.01, "suffix:s") var hitstun := 0.0
## Golpe pesado: reação própria e impacto maior.
@export var pesado := false
## Quanto este golpe, BLOQUEADO, tira da postura da guarda de quem defende.
@export_range(0.0, 1000.0, 0.5) var dano_de_postura := 0.0
## Pode ser APARADO (guarda erguida na hora certa rebate o golpe e abre riposte).
## Padrão falso, como todo campo: o `.tres` precisa dizer que sim.
@export var aparavel := false

@export_group("Corpo durante o golpe")
## Fração da velocidade de andar permitida em cada fase. Nunca zero por padrão:
## o personagem não congela ao atacar (pedido do dono), só perde mobilidade.
@export_range(0.0, 1.0, 0.01) var fator_movimento_preparo := 1.0
@export_range(0.0, 1.0, 0.01) var fator_movimento_ativo := 1.0
@export_range(0.0, 1.0, 0.01) var fator_movimento_recuperacao := 1.0
## Quanto o corpo pode girar atrás da mira em cada fase. Sem teto, girar a câmera
## no ativo arrastaria o golpe 360° em volta do corpo.
@export_range(0.0, 1440.0, 1.0, "suffix:°/s") var giro_max_preparo := 1440.0
@export_range(0.0, 1440.0, 1.0, "suffix:°/s") var giro_max_ativo := 1440.0
@export_range(0.0, 1440.0, 1.0, "suffix:°/s") var giro_max_recuperacao := 1440.0
## Quanto o corpo avança acompanhando o golpe, em metros, da metade do preparo ao
## fim do ativo. Deslocamento POR CÓDIGO (plano, D8): acertar corta o resto.
@export_range(0.0, 3.0, 0.01, "suffix:m") var avanco := 0.0

@export_group("Contato")
## Nó do rig que machuca (ex. "Hand_R"). É ele que a varredura segue no ATIVO.
@export var efetor: StringName = &""
## Segundo extremo opcional: varre toda a lâmina entre base e efetor.
@export var efetor_base: StringName = &""
@export_range(0.0, 0.6, 0.01, "suffix:m") var raio_de_contato := 0.0
## Empurrão no alvo atingido, na direção em que o golpe viajava.
@export_range(0.0, 40.0, 0.1) var empurrao := 0.0
## Pausa do golpe no contato (dos DOIS envolvidos, sem mexer no tempo do jogo).
@export_range(0.0, 0.3, 0.005, "suffix:s") var hitstop := 0.0

@export_group("Clipe (Epic Fight)")
## Clipe assado (caminho `res://`) que DIRIGE o corpo durante o golpe, no lugar da pose procedural. Vazio = pose das `chaves`.
## O relógio, as fases, o contato e o dano continuam sendo deste executor; o clipe só desenha o movimento.
@export var clipe := ""
## Velocidade de reprodução do clipe (o mod toca o golpe a `velocidade do item ÷ basis_speed`); as fases do golpe já vêm divididas por ela.
@export var velocidade_clipe := 1.0

@export_group("Pose")
## Poses-chave em ordem de tempo. O começo e o fim do golpe são SEMPRE a guarda
## do estilo — as chaves descrevem só o que acontece entre elas.
@export var chaves: Array[ChaveDePose] = []


func duracao() -> float:
	return preparo + ativo + recuperacao


## Em que fase o golpe está `t` segundos depois de começar.
func fase_em(t: float) -> Fase:
	if t < preparo:
		return Fase.PREPARO
	if t < preparo + ativo:
		return Fase.ATIVO
	if t < duracao():
		return Fase.RECUPERACAO
	return Fase.FIM


func fator_movimento(fase: Fase) -> float:
	match fase:
		Fase.PREPARO:
			return fator_movimento_preparo
		Fase.ATIVO:
			return fator_movimento_ativo
		Fase.RECUPERACAO:
			return fator_movimento_recuperacao
	return 1.0


## Em radianos por segundo, que é a unidade do yaw do Player.
func giro_maximo(fase: Fase) -> float:
	match fase:
		Fase.PREPARO:
			return deg_to_rad(giro_max_preparo)
		Fase.ATIVO:
			return deg_to_rad(giro_max_ativo)
		Fase.RECUPERACAO:
			return deg_to_rad(giro_max_recuperacao)
	return INF


## Problemas da ficha, em texto. Vazio = ficha válida. O teste e o estilo usam.
func validar() -> PackedStringArray:
	var erros := PackedStringArray()
	var rotulo := String(id) if id != &"" else "(golpe sem id)"
	if id == &"":
		erros.append("%s: falta o id" % rotulo)
	if preparo <= 0.0 or ativo <= 0.0 or recuperacao <= 0.0:
		erros.append("%s: toda fase precisa durar mais que zero" % rotulo)
	if dano < 0.0 or hitstun < 0.0:
		erros.append("%s: dano e hitstun não podem ser negativos" % rotulo)
	if dano_de_postura <= 0.0:
		erros.append("%s: golpe sem dano de postura nunca desgasta uma guarda" % rotulo)
	if efetor == &"" or raio_de_contato <= 0.0:
		erros.append("%s: golpe sem efetor ou sem raio de contato não acerta nada" % rotulo)
	var tempo_anterior := -1.0
	var tem_chave_no_ativo := false
	for i in chaves.size():
		var chave := chaves[i]
		if chave == null:
			erros.append("%s: chave %d vazia" % [rotulo, i])
			continue
		erros.append_array(chave.validar("%s/chave %d" % [rotulo, i]))
		var t := chave.tempo_em(self)
		if t < tempo_anterior:
			erros.append("%s: chave %d fora de ordem no tempo (%.3f s < %.3f s)" % [rotulo, i, t, tempo_anterior])
		tempo_anterior = t
		tem_chave_no_ativo = tem_chave_no_ativo or chave.fase == Fase.ATIVO
	# Sem chave no ATIVO a mão só passaria pela zona de contato por acaso da
	# interpolação — e a hitbox seguiria uma pose que ninguém desenhou.
	if not tem_chave_no_ativo and clipe == "":
		erros.append("%s: nenhuma chave no ATIVO — o contato precisa ser desenhado" % rotulo)
	return erros
