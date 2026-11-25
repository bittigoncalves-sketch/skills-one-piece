extends RefCounted
## POSES BÁSICAS do Skills Builder (07/10/2026). Pedido do dono: "adicionar poses
## básicas ao criador de skills". Prontas para entrar na skill (botão "Poses básicas" na
## seção Poses) e servir de ponto de partida para editar.
##
## Graus por junta do rig A, a mesma convenção do editor (medida neste rig, mão × ombro
## e pé × quadril, no `test_poses_basicas`; o modelo olha para −Z):
##   braço +X levanta para a FRENTE · braço D +Z / E −Z abre para o lado ·
##   braço D +Y / E −Y cruza na frente do corpo · antebraço +X dobra o cotovelo ·
##   tronco +Y leva o ombro direito à frente · tronco −X inclina para a frente ·
##   coxa +X levanta a perna à frente · canela −X dobra o joelho.
## ⚠️ O tronco é a RAIZ do corpo: incliná-lo leva as pernas junto. Pose que inclina o
## tronco e quer o pé no lugar soma a inclinação nas coxas (a Investida: −30 no tronco,
## +30 nas duas coxas).
## As do lado esquerdo saem espelhadas das do direito (`espelhar`).

const GUARDA_BRACOS := {"UpperArm_L": [55, -20, 0], "ForeArm_L": [105, 0, 0],
	"UpperArm_R": [45, 20, 0], "ForeArm_R": [115, 0, 0]}
const BASE_DE_LUTA := {"Thigh_L": [25, 0, 0], "Shin_L": [-30, 0, 0], "Thigh_R": [-12, 0, 0], "Shin_R": [-15, 0, 0]}

const POSES := {
	"Guarda": {"Torso": [-8, 0, 0]},
	"Soco direito": {"Torso": [-5, 25, 0], "UpperArm_R": [88, 12, 0], "ForeArm_R": [5, 0, 0],
		"Thigh_R": [-15, 0, 0], "Shin_R": [-10, 0, 0]},
	"Chute frontal": {"Torso": [12, 0, 0], "Thigh_R": [95, 0, 0], "Shin_R": [-5, 0, 0],
		"Thigh_L": [-5, 0, 0], "Shin_L": [-10, 0, 0]},
	"Apontar": {"Torso": [0, 10, 0], "UpperArm_R": [90, 0, 0], "ForeArm_R": [0, 0, 0],
		"UpperArm_L": [10, 0, -8], "ForeArm_L": [20, 0, 0]},
	"Braços abertos": {"UpperArm_R": [0, 0, 85], "UpperArm_L": [0, 0, -85]},
	"Mãos ao céu": {"UpperArm_R": [170, 0, 10], "UpperArm_L": [170, 0, -10], "Head": [12, 0, 0]},
	"Defesa cruzada": {"Torso": [-8, 0, 0], "UpperArm_R": [75, 35, 0], "ForeArm_R": [80, 0, 0],
		"UpperArm_L": [75, -35, 0], "ForeArm_L": [80, 0, 0]},
	"Base baixa": {"Torso": [-18, 0, 0], "Thigh_L": [35, 0, 0], "Shin_L": [-55, 0, 0],
		"Thigh_R": [35, 0, 0], "Shin_R": [-55, 0, 0], "UpperArm_L": [35, -10, 0], "ForeArm_L": [40, 0, 0],
		"UpperArm_R": [35, 10, 0], "ForeArm_R": [40, 0, 0]},
	"Investida": {"Torso": [-30, 0, 0], "UpperArm_L": [-45, 0, -10], "UpperArm_R": [-45, 0, 10],
		"ForeArm_L": [15, 0, 0], "ForeArm_R": [15, 0, 0],
		"Thigh_L": [80, 0, 0], "Shin_L": [-60, 0, 0], "Thigh_R": [5, 0, 0], "Shin_R": [-30, 0, 0]},
	"Carregar (mãos juntas)": {"Torso": [-5, 0, 0], "UpperArm_R": [55, 40, 0], "ForeArm_R": [70, 0, 0],
		"UpperArm_L": [55, -40, 0], "ForeArm_L": [70, 0, 0]},
	"Arremessar": {"Torso": [5, -30, 0], "UpperArm_R": [20, 0, 95], "ForeArm_R": [100, 0, 0],
		"UpperArm_L": [80, 0, 0], "ForeArm_L": [10, 0, 0],
		"Thigh_L": [25, 0, 0], "Shin_L": [-20, 0, 0], "Thigh_R": [-15, 0, 0], "Shin_R": [-10, 0, 0]},
}


## Os nomes, na ordem do menu (o soco esquerdo é o direito espelhado).
static func nomes() -> Array[String]:
	var saida: Array[String] = []
	for n in POSES:
		saida.append(str(n))
		if n == "Soco direito":
			saida.append("Soco esquerdo")
	return saida


## As juntas da pose `nome` (graus), já com a guarda e a base onde a pose não diz outra.
static func ossos(nome: String) -> Dictionary:
	if nome == "Soco esquerdo":
		return espelhar(ossos("Soco direito"))
	var p: Dictionary = (POSES.get(nome, {}) as Dictionary).duplicate(true)
	if nome in ["Guarda", "Soco direito", "Chute frontal"]:
		for papel in GUARDA_BRACOS:
			if not p.has(papel):
				p[papel] = GUARDA_BRACOS[papel].duplicate()
	if nome in ["Guarda", "Soco direito"]:
		for papel in BASE_DE_LUTA:
			if not p.has(papel):
				p[papel] = BASE_DE_LUTA[papel].duplicate()
	return p


## Esquerda ↔ direita (Y e Z trocam de sinal), como o "Espelhar" do editor.
static func espelhar(ossos_d: Dictionary) -> Dictionary:
	var novos := {}
	for papel in ossos_d:
		var g: Array = ossos_d[papel]
		var outro := str(papel).replace("_L", "_X").replace("_R", "_L").replace("_X", "_R")
		novos[outro] = [g[0], -float(g[1]), -float(g[2])]
	return novos
