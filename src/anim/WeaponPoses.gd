class_name WeaponPoses
extends RefCounted
# ============================================================================
#  POSES DE ARMAS (Weapons)
#
#  Segrega as poses procedurais de armas das poses de Akuma no Mi para manter o 
#  Princípio de Responsabilidade Única (SRP) e evitar que módulos inchem.
# ============================================================================

static func two_handed_sword_idle(add: Callable, off: Dictionary, w: float, t: float) -> void:
	if w <= 0.001:
		return
	
	# Tronco levemente rotacionado para alinhar os ombros com a espada à frente
	add.call(off, "Torso", Vector3(0.05, -0.1, 0.0) * w)
	add.call(off, "Head", Vector3(-0.05, 0.1, 0.0) * w)
	
	# Pernas abertas em V (Base Firme de Combate)
	add.call(off, "Thigh_R", Vector3(0.0, 0.4, 0.2) * w)
	add.call(off, "Thigh_L", Vector3(0.0, -0.4, -0.2) * w)
	
	# Braço Direito (mão principal no punho/hilt) estendido à frente, levemente dobrado
	add.call(off, "UpperArm_R", Vector3(0.7, -0.1, 0.1) * w)
	add.call(off, "ForeArm_R", Vector3(0.1, 0.0, 0.0) * w)
	
	# Braço Esquerdo — a SEGUNDA MÃO, no pomo. O comentário sempre disse "alcança
	# o cabo"; medido, ela ficava a **0,875 m** dele, ou seja não alcançava nada.
	#
	# Os valores abaixo saíram de uma BUSCA por cinemática direta (varredura dos
	# ângulos dos dois ossos, medindo a distância da mão ao cabo a cada
	# combinação), não de tentativa e erro: 0,875 m -> 0,366 m, que é o limite
	# geométrico do braço neste rig. E 0,366 m do CENTRO do cabo é justamente
	# onde vai a segunda mão — o cabo da Yoru tem 0,62 m, então a mão cai perto
	# do pomo, que é onde ela deve estar numa espada de duas mãos.
	add.call(off, "UpperArm_L", Vector3(1.14, -0.15, 1.03) * w)
	add.call(off, "ForeArm_L", Vector3(-0.31, -0.60, 0.10) * w)

static func ease_in_cubic(x: float) -> float:
	return x * x * x

static func ease_out_expo(x: float) -> float:
	return 1.0 if x >= 1.0 else 1.0 - pow(2.0, -10.0 * x)

## ⚠️ A CURVA DO CORTE. Era `ease_out_expo`, e ela DESTRUÍA o arco.
##
## Medido, quanto do arco já passou em cada fração da janela do golpe:
##
##      10% da janela -> 50,0% do arco
##      30% da janela -> 87,5% do arco
##      50% da janela -> 96,9% do arco
##
## Ou seja: metade do corte acontecia nos primeiros 10% e o resto rastejava. Em
## espaço local do personagem a ponta SALTAVA de +1,53 para -1,22 entre duas
## amostras — 2,75 m sem passar pela frente. Não havia arco: a lâmina teleportava
## de um lado ao outro, que é o que o dono descreveu ao dizer que o movimento não
## lia como corte.
##
## Um corte pesado acelera ENTRANDO no centro, é mais rápido AO cruzar e
## desacelera saindo. Isso é uma curva em S, não um `ease_out`:
##
##      10% -> 0,4%      30% -> 10,9%      50% -> 50,0%
##      70% -> 89,1%     90% -> 99,6%
##
## `forca` controla quão íngreme é o meio. 2,5 dá um corte nítido sem virar
## degrau — degrau é justamente o defeito que esta função substitui.
static func ease_corte(x: float, forca: float = 2.5) -> float:
	var t := clampf(x, 0.0, 1.0)
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	var a := pow(t, forca)
	var b := pow(1.0 - t, forca)
	return a / (a + b)

static func ease_out_elastic(x: float) -> float:
	if x <= 0.0: return 0.0
	if x >= 1.0: return 1.0
	var c4 = (2.0 * PI) / 3.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * c4) + 1.0

# ============================================================================
#  AS FASES DA ANIMACAO VEM DO FRAME DATA (2026-09-06)
# ============================================================================
#  Eram 0,20 e 0,26 do ciclo, escritos a mao aqui. A hitbox, por outro lado,
#  nasce em `startup` e vive `ativo` SEGUNDOS, vindos de `Melee.COMBO_SWORD`.
#  Duas descricoes independentes da mesma coisa, e elas nao batiam:
#
#      corte horizontal (0,20/0,09/0,20 = 0,49 s de ciclo)
#        hitbox ATIVA .....: 0,200 -> 0,290 s
#        anim GOLPEIA .....: 0,098 -> 0,127 s
#        a lamina passava 0,102 s ANTES de a hitbox nascer
#
#  Ou seja: o fio varria o alvo, e so seis quadros depois o dano aparecia — com
#  a espada ja no arco de volta. Agora quem manda e o frame data, e os dois
#  concordam por construcao.
#
#  Os padroes abaixo sao os numeros antigos, e valem para quem chamar sem dizer
#  as fases (o `two_handed_sword_idle` e qualquer uso futuro sem tabela).
const GOLPE_INICIO_PADRAO := 0.20
const GOLPE_FIM_PADRAO := 0.26

# Quanto do clipe a inércia leva depois do corte, e quanto ela passa do ponto
# final. A especificação do dono pede follow-through entre 65% e 78% do clipe —
# 0,13 é essa faixa. O excesso de 0,18 é o "alguns graus" que ela pede: o
# bastante para ler como peso, pouco para não virar rodopio.
const FOLLOW_THROUGH := 0.13
const EXCESSO_INERCIA := 0.18

static func _get_slash_frame(t: float, inicio: float = GOLPE_INICIO_PADRAO,
		fim: float = GOLPE_FIM_PADRAO) -> float:
	var i: float = clampf(inicio, 0.02, 0.95)
	var f: float = clampf(fim, i + 0.02, 0.98)
	if t < i:
		var preparo := clampf(t / i, 0.0, 1.0)
		return lerpf(0.0, -0.4, ease_in_cubic(preparo)) # puxa pra trás
	elif t < f:
		# ⚠️ `ease_corte`, NÃO `ease_out_expo`: a lâmina precisa ATRAVESSAR o
		# arco, não teleportar. Ver o bloco em `ease_corte`.
		var golpe := clampf((t - i) / (f - i), 0.0, 1.0)
		return lerpf(-0.4, 1.0, ease_corte(golpe))
	elif t < f + FOLLOW_THROUGH:
		# ⚠️ FOLLOW-THROUGH: A INÉRCIA CONTINUA O MOVIMENTO (2026-09-06).
		#
		# Antes daqui o `ease_out_elastic` começava no instante em que o corte
		# terminava e trazia a lâmina de volta num tranco. Medido nos 16 quadros
		# de referência da especificação: aos 66,7% do clipe (quadro 11, "final
		# do corte, espada claramente à ESQUERDA") a espada já estava de volta em
		# x = +1,33 — do lado DIREITO. O golpe não tinha follow-through nenhum;
		# a arma era freada no ar.
		#
		# "Não interromper artificialmente a espada. Permitir que a inércia
		#  continue o movimento alguns graus." Uma Yoru de 1,38 m não para no fim
		#  do arco: ela passa um pouco, e é esse excesso que comunica MASSA.
		var extra := clampf((t - f) / FOLLOW_THROUGH, 0.0, 1.0)
		return lerpf(1.0, 1.0 + EXCESSO_INERCIA, ease_out_expo(extra))
	else:
		# RECUPERAÇÃO, e ela é mais lenta que o cruzamento — de propósito. Sai do
		# ponto extremo (já com o excesso da inércia) e volta ao repouso.
		var base := f + FOLLOW_THROUGH
		var recuo := clampf((t - base) / maxf(1.0 - base, 0.01), 0.0, 1.0)
		return lerpf(1.0 + EXCESSO_INERCIA, 0.0, ease_out_elastic(recuo))

# ============================================================================
#  A DIREÇÃO DA LÂMINA — postura da ARMA, não dos ossos
# ============================================================================
#  Pedido do dono (2026-09-06): "a direção da lâmina da espada durante o
#  movimento".
#
#  A espada nasce colada à mão com `rotation = ZERO` e daí em diante só é
#  CARREGADA pelo braço. Medido no corte horizontal, o ângulo do fio em relação
#  à vertical: 80° parado (quase deitada, certo) e **43,8° no auge** — ou seja,
#  no meio do corte a lâmina EMPINA quase 46° para fora da horizontal. Um corte
#  horizontal com a lâmina empinada não corta: bate de chapa.
#
#  A correção não pode vir dos ossos. Girar o antebraço para deitar a lâmina
#  moveria a MÃO junto, e a mão é o que segura o cabo — mexer nela desfaz a
#  empunhadura de duas mãos que custou uma busca por cinemática direta.
#
#  Então a arma ganha postura PRÓPRIA: uma rotação aplicada ao nó da espada, em
#  torno da origem dela — que é o `handle`, que é onde a mão está. Girar ali
#  muda a direção do fio e NÃO move o ponto de pega um milímetro.
#
#  Devolve a rotação local que o nó da arma deve ter neste instante do golpe.
static func postura_da_arma(tipo: int, frame: float) -> Vector3:
	match tipo:
		0:
			# HORIZONTAL: a lâmina deita e o fio lidera o arco. O X negativo
			# baixa a ponta (contra o empinar medido) e cresce com o golpe; o Z
			# rola o fio para a frente da varredura.
			return Vector3(-0.55 * frame, 0.0, 0.42 * frame)
		2:
			# VERTICAL: o oposto — a lâmina sobe no preparo e desce de fio, e o
			# rolamento é quase nulo porque o corte já está no plano certo.
			return Vector3(0.30 * frame, 0.0, 0.0)
	return Vector3.ZERO


static func two_handed_sword_slash(add: Callable, off: Dictionary, w: float, t: float,
		type: int, golpe_inicio: float = GOLPE_INICIO_PADRAO,
		golpe_fim: float = GOLPE_FIM_PADRAO) -> void:
	if w <= 0.001:
		return

	# Progresso do golpe usando delays para criar Cadeia Cinética (Chicote)
	# Delays aumentados para enfatizar a "fluidez" (os braços e a arma vêm BEM depois do corpo)
	#
	# ⚠️ O ATRASO DA CADEIA ENCOLHEU de 0,05/0,10 para 0,03/0,06. Ele é medido em
	# tempo NORMALIZADO, então com o ciclo da espada mais longo (0,76 s no
	# horizontal contra 0,49 antes) o atraso antigo empurrava o braço 0,076 s
	# depois do tronco — o fio chegava atrasado à própria janela ativa. A cadeia
	# cinética continua existindo; ela só deixou de comer a janela de acerto.
	var frame_torso := _get_slash_frame(t, golpe_inicio, golpe_fim)
	var frame_upper := _get_slash_frame(clampf(t - 0.03, 0.0, 1.0), golpe_inicio, golpe_fim)
	var frame_fore  := _get_slash_frame(clampf(t - 0.06, 0.0, 1.0), golpe_inicio, golpe_fim)
	
	# ⚠️ A BASE ERA SIMÉTRICA E SEM DIREÇÃO: `absf(frame)` abria as duas coxas
	# do mesmo jeito, no preparo e no golpe, e as pernas só acompanhavam o
	# tronco. Medido, os dois pés terminavam do MESMO lado (−0,30 no eixo
	# lateral) no auge — lê como tropeço, não como passada.
	#
	# Agora cada corte tem a sua base, e o horizontal ganhou passada de verdade
	# (ver o `match` abaixo). Este bloco fica só com o AGACHAMENTO, que é comum
	# aos três: o corpo baixa para dar peso e volta.
	var agacha: float = absf(frame_torso)
	add.call(off, "Thigh_R", Vector3(0.16, 0.0, 0.0) * agacha * w)
	add.call(off, "Thigh_L", Vector3(0.16, 0.0, 0.0) * agacha * w)
	add.call(off, "Shin_R", Vector3(0.22, 0.0, 0.0) * agacha * w)
	add.call(off, "Shin_L", Vector3(0.22, 0.0, 0.0) * agacha * w)

	# Como as duas mãos seguram a mesma espada, o ForeArm_L e UpperArm_L seguem o direito
	match type:
		0: # ================================================================
			#  HORIZONTAL: as DUAS MAOS no cabo, a lamina sai da DIREITA e
			#  varre para a ESQUERDA. Pedido do dono, 2026-09-06.
			# ================================================================
			#  ⚠️ QUEM GIRA SAO OS BRACOS, NAO O TRONCO — e isto foi RELATADO
			#  depois de eu ter feito o contrario:
			#
			#    "o personagem rotaciona correto, porem a animacao esta
			#     permanecendo a mesma como se ele estivesse estatico [...]
			#     cabeca e torso ficam estaticos, pernas se dobram para manter o
			#     equilibrio e os bracos se movem ao redor do torso"
			#
			#  Eu tinha posto a varredura no TRONCO (Y = 1,70 rad) para manter as
			#  duas maos juntas no cabo. Funcionou para a empunhadura e destruiu
			#  a animacao, porque neste rig o `Torso` e PAI DE TUDO — cabeca,
			#  bracos e pernas. Girar o tronco roda o corpo inteiro em BLOCO: o
			#  personagem parecia estatico girando numa bandeja.
			#
			#  E pior: a "passada" que eu media (0,33 m de avanco do pe direito)
			#  era a perna sendo CARREGADA pela rotacao do tronco, nao um passo.
			#
			#  Agora cada parte tem movimento proprio:
			#    tronco e cabeca  -> quase parados (so respiram no golpe)
			#    bracos           -> ORBITAM o tronco, e sao eles que levam a espada
			#    pernas           -> DOBRAM para segurar o equilibrio do arremesso
			#
			#  ⚠️ CUSTO DECLARADO: com os bracos girando sozinhos, a mao esquerda
			#  se afasta mais do cabo que na versao de tronco (medido no fim
			#  deste trabalho). O rig tem ombro que nao translada, entao alcance
			#  de braco e o teto. O dono escolheu esta leitura sabendo disso.

			#  --------------------------------------------- TRONCO E CABECA
			#  Quase nada, de proposito. O pouco que sobra e ANTECIPACAO: o
			#  tronco recolhe no preparo e projeta no corte, sem girar.
			add.call(off, "Torso", Vector3(0.30, 0.16, 0.22) * frame_torso * w)
			add.call(off, "Head", Vector3(-0.12, 0.10, 0.0) * frame_torso * w)

			#  ------------------------------------- OS BRACOS LEVAM A ESPADA
			#  O Y grande mora aqui agora. O direito conduz (e a mao do `handle`)
			#  e o esquerdo acompanha no MESMO sentido — dois bracos no mesmo
			#  cabo tem de girar juntos, e girarem para lados opostos era o
			#  defeito da primeira versao desta pose.
			#
			#  O X e o Z sobem junto com o Y: o braco nao so gira, ele LEVANTA e
			#  atravessa a frente do peito. E o que faz o gesto ler como orbita
			#  em volta do tronco em vez de um limpador de para-brisa.
			add.call(off, "UpperArm_R", Vector3(1.05, 1.95, 0.55) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(0.34, 0.55, 0.0) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(0.95, 1.80, -0.45) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(0.30, -0.30, 0.0) * frame_fore * w)

			#  ------------------------------- AS PERNAS SEGURAM O EQUILIBRIO
			#  Sem o tronco girando, as pernas param de ser levadas e passam a
			#  ter trabalho proprio: DOBRAM para baixar o centro de massa e
			#  segurar o arremesso dos bracos. A direita afunda mais (e o lado
			#  de onde a espada sai) e a esquerda escora.
			#
			#  `frame_torso` e nao `absf`: a flexao tem sentido — recolhe no
			#  preparo, empurra no golpe.
			add.call(off, "Thigh_R", Vector3(-0.45, 0.30, 0.16) * frame_torso * w)
			add.call(off, "Shin_R", Vector3(0.55, 0.0, 0.0) * absf(frame_torso) * w)
			add.call(off, "Foot_R", Vector3(0.18, 0.22, 0.0) * frame_torso * w)
			add.call(off, "Thigh_L", Vector3(0.30, 0.22, -0.12) * frame_torso * w)
			add.call(off, "Shin_L", Vector3(0.40, 0.0, 0.0) * absf(frame_torso) * w)
			add.call(off, "Foot_L", Vector3(-0.10, 0.18, 0.0) * frame_torso * w)
		1: # Corte Esquerda para Direita
			add.call(off, "Torso", Vector3(0.4, 1.0, -0.2) * frame_torso * w)
			add.call(off, "Head", Vector3(-0.2, 0.5, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(1.4, 1.4, -0.9) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(0.6, 0.0, -0.6) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(1.4, 1.4, 0.3) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(0.6, 0.4, -0.3) * frame_fore * w)
		2: # Corte Vertical (Cima para Baixo)
			add.call(off, "Torso", Vector3(0.8, 0.0, 0.0) * frame_torso * w)
			add.call(off, "Head", Vector3(0.3, 0.0, 0.0) * frame_torso * w)
			add.call(off, "UpperArm_R", Vector3(2.4, 0.0, 0.0) * frame_upper * w)
			add.call(off, "ForeArm_R", Vector3(1.0, 0.0, 0.0) * frame_fore * w)
			add.call(off, "UpperArm_L", Vector3(2.4, 0.6, 0.5) * frame_upper * w)
			add.call(off, "ForeArm_L", Vector3(1.0, 0.3, 0.0) * frame_fore * w)

