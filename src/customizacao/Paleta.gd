class_name Paleta
extends RefCounted
# ============================================================================
#  AS CORES DE JOGADOR — dado puro, sem dependência de nada.
#
#  ⚠️ POR QUE SAIU DO `Player.gd`. A lista morava lá, e o menu de Customização
#  precisou dela. Só que referenciar `Player` para ler três cores arrasta o
#  script inteiro (2.400 linhas) e, com ele, os AUTOLOADS de que ele depende —
#  e o `FruitNet` não existe ainda no momento em que uma sonda com `-s` compila:
#
#      SCRIPT ERROR: Compile Error: Identifier not found: FruitNet
#
#  O erro não era sobre cor nenhuma. Era sobre uma tela de menu ter virado
#  dependente da classe mais pesada do projeto para ler DADO.
#
#  `Player.CORES` continua existindo e apontando para cá: as dezenas de usos não
#  mudam, e a fonte continua sendo uma só.
# ============================================================================

const CORES := [
	{"nome": "azul",  "cor": Color(0.16, 0.42, 0.95)},
	{"nome": "verde", "cor": Color(0.18, 0.72, 0.32)},
	{"nome": "preto", "cor": Color(0.08, 0.08, 0.10)},
]


## ⚠️ LISTA SEPARADA, de propósito. `CORES` são as cores de TIME: elas existem
## para dizer de quem é o corpo numa partida, e `Player.cor_idx` indexa esta
## lista — misturar tons de pele nela mudaria o significado de um índice que a
## rede já transmite.
##
## Tom de pele é escolha de APARÊNCIA, não de time. Duas listas, dois usos.
const PELES := [
	{"nome": "clara",     "cor": Color(0.98, 0.85, 0.74)},
	{"nome": "bege",      "cor": Color(0.94, 0.78, 0.63)},
	{"nome": "dourada",   "cor": Color(0.87, 0.68, 0.48)},
	{"nome": "morena",    "cor": Color(0.73, 0.53, 0.36)},
	{"nome": "castanha",  "cor": Color(0.55, 0.38, 0.25)},
	{"nome": "escura",    "cor": Color(0.38, 0.25, 0.17)},
	{"nome": "profunda",  "cor": Color(0.24, 0.16, 0.11)},
]
