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

## As quatro fileiras: (comprimento, altura da pena, recuo, queda).
## Comprimentos crescentes da frente para trás — é o que faz o contorno da asa
## abrir em vez de virar um bloco.
##
## ⚠️ A QUEDA É PEQUENA DE PROPÓSITO. Na primeira versão ela ia até 0,27 e,
## somada ao rebaixamento ao longo da envergadura, punha a ponta da asa na
## altura do quadril: o conjunto lia como uma saia preta, não como asa.
const FILEIRAS := [
	{"comp": 0.34, "alt": 0.115, "recuo": 0.02, "queda": 0.00, "tom": 0.34},
	{"comp": 0.54, "alt": 0.130, "recuo": 0.09, "queda": 0.03, "tom": 0.26},
	{"comp": 0.76, "alt": 0.145, "recuo": 0.17, "queda": 0.07, "tom": 0.18},
	{"comp": 0.98, "alt": 0.160, "recuo": 0.25, "queda": 0.12, "tom": 0.11},
]
const PENAS_POR_FILEIRA := 7

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
const POSE := {
	"repouso":  {"abertura": -0.18, "inclinacao":  0.52},
	# andando: recuadas, "organizadas para trás", mas ainda abertas
	"andando":  {"abertura": -0.62, "inclinacao":  0.30},
	# correndo: quase juntas nas costas — é o "encostando uma na outra"
	"correndo": {"abertura": -1.15, "inclinacao":  0.06},
	# pulando: recolhidas para o centro, como ave que salta
	"pulando":  {"abertura": -1.30, "inclinacao": -0.18},
	# caindo: escancaradas, planando
	"caindo":   {"abertura": -0.02, "inclinacao":  0.86},
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


static func criar(lado: int, escala: float = 1.0) -> AsaLunar:
	var a := AsaLunar.new()
	a._lado = float(lado)
	a._montar(escala)
	return a


func _montar(escala: float) -> void:
	_abertura = float(POSE["repouso"]["abertura"])
	_inclinacao = float(POSE["repouso"]["inclinacao"])
	_aplicar_pose()

	for f in FILEIRAS:
		var fila: Dictionary = f
		var comp: float = float(fila["comp"]) * escala
		var alt: float = float(fila["alt"]) * escala
		var tom: float = float(fila["tom"])
		for i in PENAS_POR_FILEIRA:
			# Ao longo da envergadura as penas encurtam na ponta — asa afina.
			var t := float(i) / float(PENAS_POR_FILEIRA - 1)
			var encurta: float = 1.0 - 0.42 * t * t
			var m := MeshInstance3D.new()
			var caixa := BoxMesh.new()
			caixa.size = Vector3(0.075 * escala, alt, comp * encurta)
			m.mesh = caixa
			m.position = Vector3(
				_lado * (0.10 + t * 0.62) * escala,
				-float(fila["queda"]) * escala - t * 0.09 * escala,
				(float(fila["recuo"]) + comp * encurta * 0.5) * escala)
			# leve abertura em leque
			m.rotation = Vector3(0.0, _lado * t * 0.26, _lado * -t * 0.30)
			# ⚠️ CEL SHADING, como todo o resto. Um `StandardMaterial3D` avulso
			# deixaria a asa lisa e brilhante ao lado de um corpo chapado.
			m.material_override = Materiais.superficie(Color(tom * 0.9, tom * 0.9, tom))
			add_child(m)


func _process(delta: float) -> void:
	_t += delta
	var alvo: Dictionary = POSE[estado()]
	var k := clampf(VELOCIDADE_DA_POSE * delta, 0.0, 1.0)
	_abertura = lerpf(_abertura, float(alvo["abertura"]), k)
	_inclinacao = lerpf(_inclinacao, float(alvo["inclinacao"]), k)
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


func _aplicar_pose() -> void:
	# O respiro entra somado à INCLINAÇÃO: é o que mantém a asa viva mesmo
	# parada, sem brigar com o gesto do estado.
	var respiro := sin(_t * TAU / PERIODO) * AMPLITUDE
	basis = Basis.from_euler(Vector3(
		0.0,
		_lado * _abertura,
		_lado * (_inclinacao + respiro)))
