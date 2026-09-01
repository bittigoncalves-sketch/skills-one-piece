class_name AsaLunar
extends Node3D
# ============================================================================
#  AS ASAS NEGRAS DO LUNARIANO — em camadas de penas, e reagindo ao movimento.
#
#  ------------------------------------------------- POR QUE NÃO É UMA PEÇA
#  As outras raças são caixas soltas no catálogo (`Racas.CATALOGO.pecas`), e a
#  asa antiga era uma delas: UM retângulo preto inclinado de cada lado. Contra a
#  folha de referência isso não se sustenta — lá a asa tem quatro fileiras de
#  penas de comprimentos diferentes, e é o escalonamento que a faz ler como asa
#  em vez de placa.
#
#  Peça de catálogo também não tem `_process`, e as asas precisam de dois
#  movimentos: o batimento de repouso e a POSE que responde ao que o jogador
#  está fazendo. Por isso a asa é um NÓ, com as penas como filhas.
#
#  ⚠️ O MOVIMENTO É DO OMBRO. Girar cada pena daria um leque desmontando; a asa
#  de verdade pivota na raiz. A rotação é aplicada NESTE nó e as penas só
#  acompanham — que é para o que a hierarquia serve.
# ============================================================================

## ============================================================================
##  A FORMA DA ASA (refeita em 2026-08-29, folha `lunarian 2`)
##
##  ⚠️ A ASA SOBE E AS PENAS CAEM. A versão anterior tratava a asa como uma peça
##  rígida que apontava para algum lado, e a pergunta virava "para cima ou para
##  baixo?" — nenhuma das duas estava certa. Na folha a asa faz as DUAS coisas
##  ao mesmo tempo: o dorso sobe do ombro num arco até acima da cabeça, e as
##  penas longas DESCEM desse arco até a altura do quadril.
##
##  Por isso a geometria agora é um ARCO com penas penduradas nele, e não
##  fileiras crescendo para trás. É o que faz a ponta ficar embaixo (o pedido do
##  dono) sem que a asa deixe de ser alta.
##
##      ARCO ..... por onde o dorso da asa passa: sobe saindo do ombro, abre
##                 para o lado e recua um pouco.
##      PENAS .... penduradas no arco, descendo. As do meio são as mais longas,
##                 como numa asa de verdade.
##      CAMADAS .. duas fileiras, uma atrás da outra, para dar volume — é o que
##                 separa "asa" de "recorte de papel".
## ============================================================================

## Quantas penas ao longo do arco.
const PENAS := 9
## O `tom` da camada da FRENTE, usado para normalizar as demais — ver a nota da
## cor em `_montar`. Se uma camada nova entrar mais clara que esta, é este
## número que muda.
const TOM_MAX := 0.20
## Quanto a camada de trás escurece em relação à cor base.
const PISO_DO_TOM := 0.60
## Duas camadas: a de trás é mais longa e mais escura, a da frente cobre a raiz.
const CAMADAS := [
	{"recuo": 0.00, "comp": 1.00, "tom": 0.20, "larg": 0.085},
	{"recuo": 0.13, "comp": 1.26, "tom": 0.11, "larg": 0.075},
]

## O ARCO, em unidades do modelo. `ALTURA_ARCO` é o quanto o dorso sobe no pico;
## `ABERTURA_ARCO`, o quanto ele afasta do corpo.
const ALTURA_ARCO := 0.62
const ABERTURA_ARCO := 0.86
const RECUO_ARCO := 0.20
## Comprimento das penas: a base mais o que as do meio ganham a mais.
const PENA_BASE := 0.30
const PENA_MEIO := 0.92

## O batimento de repouso, que corre POR CIMA da pose como uma respiração.
## Lento de propósito: é uma asa parada, não voando.
const AMPLITUDE := 0.085
const PERIODO := 3.4

## ============================================================================
##  AS POSES, POR ESTADO DE MOVIMENTO (pedido do dono, 2026-08-29)
##
##  "as asas fecham para o centro quando o jogador pula e abrem quando cai; se
##   organizam para trás quando começa a se mover e se fecham encostando uma na
##   outra quando começa a correr"
##
##  Cada pose é (abertura, inclinação), em radianos:
##    ABERTURA ..... quanto a asa RECUA. 0 = aberta de lado; mais negativo = mais
##                   para trás, até as duas quase se encostarem nas costas.
##    INCLINAÇÃO ... quanto a ponta SOBE. Maior = asa mais erguida, em V.
##
##  ⚠️ A DE REPOUSO ABRIU. Era (−0,32, 0,14) e o dono disse que as asas ficavam
##  "na horizontal"; na folha elas sobem num V amplo. O que as deitava era a
##  INCLINAÇÃO baixa, não a abertura — mexer na abertura não teria resolvido.
## ============================================================================
## ⚠️ A INCLINAÇÃO ESCRITA NÃO É O ÂNGULO QUE SAI. As penas descem ao longo da
## envergadura (`queda` + o rebaixamento por `t`), e essa geometria come cerca de
## 17° da elevação: com 0,52 rad escritos (30°) a ponta subia só +12,3° — o dono
## olhou e disse, com razão, que a asa continuava "na horizontal". Os valores
## abaixo foram CALIBRADOS contra o ângulo medido da ponta, não escolhidos pelo
## número que parecia certo.
##
## Alvos, em ângulo REAL da ponta (medido por `_tmp` e travado no teste):
##   repouso  ≈ +40°   aberta em V
##   andando  ≈  +5°   recuada, "para trás"
##   correndo ≈  −5°   juntas nas costas
##   pulando  ≈ −45°   "ao pular deve ir para BAIXO"
##   caindo   ≈ +55°   "ao cair para CIMA"
const POSE := {
	# ⚠️ NEUTRA. Com a forma nova — arco que sobe, penas que caem — o repouso não
	# precisa girar nada: a asa já tem a silhueta da folha parada. As outras
	# poses são desvios A PARTIR daqui.
	"repouso":  {"abertura": -0.15, "inclinacao":  0.06, "pitch":  0.00},
	# andando: deitam para TRÁS — cresce o recuo, e a asa fecha um pouco
	"andando":  {"abertura": -0.60, "inclinacao": -0.10, "pitch":  0.18},
	# correndo: recuo máximo, quase juntas nas costas
	"correndo": {"abertura": -1.10, "inclinacao": -0.22, "pitch":  0.30},
	# pulando: a asa inteira mergulha, as pontas apontam mais para baixo ainda
	"pulando":  {"abertura": -0.70, "inclinacao": -0.85, "pitch":  0.48},
	# caindo: sobem e ABREM, como quem freia a queda
	"caindo":   {"abertura":  0.16, "inclinacao":  0.62, "pitch": -0.42},
}

## Quão depressa a asa persegue a pose do estado. Rápido o bastante para o
## jogador ligar o gesto ao que fez; suave o bastante para nunca saltar.
const VELOCIDADE_DA_POSE := 6.5

## Acima disto no plano horizontal o jogador está ANDANDO (e não parado). Baixo:
## o que interessa é a intenção de andar, não a velocidade.
const LIMIAR_ANDANDO := 0.6
## E acima disto na vertical ele está SUBINDO, não caindo. A folga evita que o
## quadro exato do ápice do pulo conte como queda e a asa pisque.
const LIMIAR_SUBINDO := 0.5

var _lado := 1.0
var _t := 0.0
## O corpo a que esta asa pertence, achado uma vez subindo a árvore. `null` na
## prévia do menu — lá não há jogador, e a asa fica em repouso, que é a pose em
## que o dono quer vê-la ao escolher a raça.
var _dono: CharacterBody3D = null
var _procurou_dono := false
## Ângulos correntes, perseguindo os da pose. Guardados em vez de recalculados
## para a transição ser contínua quando o estado muda no meio do caminho.
var _abertura := 0.0
var _inclinacao := 0.0
var _pitch := 0.0
## Multiplica o tom de cada fileira. Branco = asa clara; escuro = a do Lunariano.
var _cor_base := Color(1.0, 1.0, 1.0)


## ⚠️ A COR É PARÂMETRO desde 2026-09-01, e não uma constante escondida no
## desenho. O dono pediu que o Skypean use ESTAS asas em branco — a mesma
## silhueta em camadas, o mesmo batimento, as mesmas poses por estado. Duplicar
## o arquivo para trocar uma cor significaria manter dois desenhos em sincronia
## para sempre, e o segundo pararia de acompanhar na primeira mudança.
##
## `base` é a cor da pena mais CLARA; as fileiras de trás escurecem a partir
## dela, que é o que dá profundidade à asa.
static func criar(lado: int, escala: float = 1.0,
		base: Color = Color(1.0, 1.0, 1.0)) -> AsaLunar:
	var a := AsaLunar.new()
	a._lado = float(lado)
	a._cor_base = base
	a._montar(escala)
	return a


func _montar(escala: float) -> void:
	_abertura = float(POSE["repouso"]["abertura"])
	_inclinacao = float(POSE["repouso"]["inclinacao"])
	_pitch = float(POSE["repouso"]["pitch"])
	_aplicar_pose()

	for c in CAMADAS:
		var camada: Dictionary = c
		for i in PENAS:
			var t := float(i) / float(PENAS - 1)
			# ⚠️ O ARCO SOBE E DESCE. `sin(t·π·0.72)` põe o pico a cerca de dois
			# terços da envergadura, não na ponta: é onde fica a "mão" da asa na
			# folha, e é isso que dá o contorno de asa em vez de rampa reta.
			var altura := sin(t * PI * 0.72) * ALTURA_ARCO
			var x: float = _lado * (0.12 + t * ABERTURA_ARCO) * escala
			var y: float = altura * escala
			var z: float = (float(camada["recuo"]) + t * RECUO_ARCO) * escala

			# A pena DESCE do arco. As do meio são as mais longas.
			var comp: float = (PENA_BASE + sin(t * PI * 0.88) * PENA_MEIO) \
				* float(camada["comp"]) * escala

			var m := MeshInstance3D.new()
			var caixa := BoxMesh.new()
			caixa.size = Vector3(float(camada["larg"]) * escala, comp, 0.075 * escala)
			m.mesh = caixa
			# a caixa nasce centrada, então desce meio comprimento para pendurar
			m.position = Vector3(x, y - comp * 0.5, z)
			# leve inclinação para fora, acompanhando o arco
			m.rotation = Vector3(0.0, _lado * t * 0.20, _lado * -t * 0.26)
			# ⚠️ CEL SHADING, como todo o resto. Um `StandardMaterial3D` avulso
			# deixaria a asa lisa e brilhante ao lado de um corpo chapado.
			var tom: float = float(camada["tom"])
			# O `tom` da fileira escurece da frente para trás; a cor base decide
			# se a asa é negra (Lunariano) ou branca (Skypean).
			# ⚠️ O `tom` É FRAÇÃO DA COR BASE, não um valor absoluto.
			#
			# Ele nasceu como a luminância da pena do Lunariano (0,11 e 0,20 —
			# tudo escuro), e multiplicar isso por branco continua dando escuro:
			# medido, as asas do Skypean saíam em (0,17, 0,17, 0,20) com a cor
			# base branca chegando corretamente ao nó. Normalizando pelo tom da
			# camada da frente, ela fica na cor base cheia e a de trás escurece
			# a partir dela — profundidade sem apagar a cor.
			var f: float = lerpf(PISO_DO_TOM, 1.0, tom / TOM_MAX)
			m.material_override = Materiais.superficie(Color(
				_cor_base.r * f, _cor_base.g * f, _cor_base.b * f))
			add_child(m)


func _process(delta: float) -> void:
	_t += delta
	var alvo: Dictionary = POSE[estado()]
	var k := clampf(VELOCIDADE_DA_POSE * delta, 0.0, 1.0)
	_abertura = lerpf(_abertura, float(alvo["abertura"]), k)
	_inclinacao = lerpf(_inclinacao, float(alvo["inclinacao"]), k)
	_pitch = lerpf(_pitch, float(alvo["pitch"]), k)
	_aplicar_pose()


## A REGRA, separada da leitura do mundo — e é de propósito.
##
## ⚠️ POR QUE PURA. Testar "andando" pelo corpo de verdade exige que o jogador
## ANDE, e o Player recalcula a velocidade todo quadro a partir do input: numa
## sonda headless a tecla não chega e o estado lido volta "repouso" sempre.
## Isso reprovava a regra por causa do ambiente, não do código. Assim a regra é
## verificável nos cinco casos sem mundo nenhum, e `estado()` fica com a única
## coisa que precisa do corpo: ler os três valores.
##
## A ORDEM IMPORTA: no ar, pular e cair mandam mais que andar ou correr — quem
## saltou correndo está PULANDO, não correndo.
static func estado_de(no_chao: bool, vel: Vector3, correndo: bool) -> String:
	if not no_chao:
		return "pulando" if vel.y > LIMIAR_SUBINDO else "caindo"
	if Vector2(vel.x, vel.z).length() < LIMIAR_ANDANDO:
		return "repouso"
	return "correndo" if correndo else "andando"


func estado() -> String:
	var p := corpo()
	if p == null:
		return "repouso"
	return estado_de(p.is_on_floor(), p.velocity, _correndo(p))


func _correndo(p: CharacterBody3D) -> bool:
	# `_is_sprinting` é do Player; a asa também roda em cenas de teste com um
	# corpo qualquer, e ali "não está correndo" é a resposta certa.
	if not p.has_method("_is_sprinting"):
		return false
	return bool(p.call("_is_sprinting"))


## Sobe a árvore até o corpo. Uma vez só: a asa é filha do modelo, que é filho
## do Player, e nada disso muda enquanto ela existe.
func corpo() -> CharacterBody3D:
	if _procurou_dono:
		return _dono
	_procurou_dono = true
	var n: Node = get_parent()
	while n != null:
		if n is CharacterBody3D:
			_dono = n
			break
		n = n.get_parent()
	return _dono


## ⚠️ O PITCH É O QUE PÕE A ASA DE PÉ, e a inclinação sozinha não conseguia.
##
## As penas crescem para TRÁS (+Z local) — é o comprimento delas. Girar em Z
## (inclinação) levanta a ENVERGADURA, mas não toca no eixo em que a asa é
## comprida: medido, o ângulo da ponta saturava em +53° por mais que a
## inclinação subisse, e acima de 1,6 rad PIORAVA. Nenhum valor de inclinação
## põe a asa na vertical, porque o problema não estava nela.
##
## O pitch gira em X, que é justamente o eixo que leva +Z para +Y: é ele que
## levanta o comprimento da asa e a deixa em pé, como o dono pediu.
##
## A ordem é PITCH → ABERTURA → INCLINAÇÃO, aplicada por multiplicação explícita
## em vez de `from_euler`: assim cada uma opera sobre o resultado da anterior e
## a leitura do código bate com o que se vê.
func _aplicar_pose() -> void:
	# O respiro entra somado à INCLINAÇÃO: é o que mantém a asa viva mesmo
	# parada, sem brigar com o gesto do estado.
	var respiro := sin(_t * TAU / PERIODO) * AMPLITUDE
	basis = Basis(Vector3.UP, _lado * _abertura) \
		* Basis(Vector3.RIGHT, _pitch) \
		* Basis(Vector3.BACK, _lado * (_inclinacao + respiro))
