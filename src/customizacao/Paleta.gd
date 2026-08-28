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
