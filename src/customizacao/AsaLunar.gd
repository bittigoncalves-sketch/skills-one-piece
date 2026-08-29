class_name AsaLunar
extends Node3D
# ============================================================================
#  AS ASAS NEGRAS DO LUNARIANO — em camadas de penas, e batendo.
#
#  Pedido do dono (2026-08-29): "detalhamento nas asas, nova asa baseada na
#  imagem, adicionar animação à asa também".
#
#  ------------------------------------------------- POR QUE NÃO É UMA PEÇA
#  As outras raças são caixas soltas no catálogo (`Racas.CATALOGO.pecas`), e a
#  asa antiga era uma delas: UM retângulo preto inclinado de cada lado. Contra a
#  folha de referência isso não se sustenta — lá a asa tem quatro fileiras de
#  penas de comprimentos diferentes, e é o escalonamento que a faz ler como asa
#  em vez de placa.
#
#  Descrever ~40 penas por lado no catálogo daria oitenta linhas de números
#  onde ninguém enxergaria o desenho, e continuaria sem resolver a segunda
#  metade do pedido: peça de catálogo não tem `_process`, então não bate. Aqui a
#  asa é um NÓ, com as penas como filhas e o batimento no próprio nó.
#
#  ⚠️ O BATIMENTO É DO OMBRO. Girar cada pena daria um leque desmontando; a asa
#  de verdade pivota na raiz. Por isso a rotação é aplicada NESTE nó, e as penas
#  só acompanham — que é para o que a hierarquia serve.
# ============================================================================

## Quanto a asa sobe e desce, em radianos, e em quanto tempo. Lento de propósito:
## é uma asa em repouso, não voando. Bater rápido puxaria o olho para longe do
## personagem, que é o que o jogador está ali para ver.
const AMPLITUDE := 0.115
const PERIODO := 3.4

## As quatro fileiras: (comprimento, altura da pena, recuo, queda).
## Comprimentos crescentes da frente para trás — é o que faz o contorno da asa
## abrir em vez de virar um bloco.
## ⚠️ A QUEDA É PEQUENA DE PROPÓSITO. Na primeira versão ela ia até 0,27 e, somada
## ao rebaixamento ao longo da envergadura, punha a ponta da asa na altura do
## quadril: o conjunto lia como uma saia preta, não como asa. Na folha as asas
## saem das omoplatas e se abrem para os LADOS, descendo pouco.
const FILEIRAS := [
	{"comp": 0.34, "alt": 0.115, "recuo": 0.02, "queda": 0.00, "tom": 0.34},
	{"comp": 0.54, "alt": 0.130, "recuo": 0.09, "queda": 0.03, "tom": 0.26},
	{"comp": 0.76, "alt": 0.145, "recuo": 0.17, "queda": 0.07, "tom": 0.18},
	{"comp": 0.98, "alt": 0.160, "recuo": 0.25, "queda": 0.12, "tom": 0.11},
]
const PENAS_POR_FILEIRA := 7

var _lado := 1.0
var _t := 0.0
var _base := Basis.IDENTITY


static func criar(lado: int, escala: float = 1.0) -> AsaLunar:
	var a := AsaLunar.new()
	a._lado = float(lado)
	a._montar(escala)
	return a


func _montar(escala: float) -> void:
	# A asa nasce apontando para trás e para fora; o batimento oscila em torno
	# desta pose, e por isso ela é guardada como `_base`.
	# Aberta para o LADO e um pouco para trás. Com -0,62 em Y a asa ficava quase
	# de perfil e sumia na vista de frente — na folha ela aparece nas três.
	_base = Basis.from_euler(Vector3(0.0, _lado * -0.32, _lado * 0.14))
	basis = _base

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
	var onda := sin(_t * TAU / PERIODO)
	# a ponta sobe um pouco mais que a raiz: torção leve, não rotação rígida
	basis = _base * Basis.from_euler(Vector3(0.0, 0.0, _lado * AMPLITUDE * onda))
