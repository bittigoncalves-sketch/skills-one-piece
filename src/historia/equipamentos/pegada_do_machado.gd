class_name PegadaDoMachado
extends RefCounted
## As DUAS mãos no cabo do machado (17/10/2026). Fonte única da conta: o gerador dos cortes
## (`tools/criar_corte_horizontal_machado.gd`) e o arremesso (`habilidades_do_machado.gd`)
## pedem aqui o alvo dos punhos e a orientação deles.
##
## Por que existe: o alvo da IK é o PUNHO, e a pega (o nó `Weapon_*`, onde o cabo mora) fica a
## ~9 cm dele. Mirar o punho no cabo deixava a mão esquerda a 10–30 cm do machado. Aqui o
## alvo é a PEGA e o desvio punho → pega sai da conta, como em `giro_da_espada.gd`.
##
## Eixos do machado no encaixe da mão (medidos em `tools/dev_tests/test_machado_corte.gd`):
## +Y é o cabo, indo da mão para a cabeça; o fio é a face local −Z.

## Do punho até a pega (`Weapon_*`), no espaço do próprio punho — medido no rig base.
const DESVIO_D := Vector3(0.0106, -0.0759, -0.0417)
const DESVIO_E := Vector3(-0.0106, -0.0759, -0.0417)
## Distância entre as palmas ao longo do cabo (a esquerda fica mais perto do cabo, atrás).
const ENTRE_MAOS := 0.17


## `pega`: onde a mão DIREITA segura (espaço do corpo). `cabo`: direção do cabo, da mão para
## a cabeça. `fio`: para onde o FIO deve olhar (projetado para ficar ⟂ ao cabo).
## Devolve {mao_R, mao_L, punho_R, punho_L} — punhos em RADIANOS (euler do `PoseDeCombate`).
static func calcular(pega: Vector3, cabo: Vector3, fio: Vector3) -> Dictionary:
	var h := cabo.normalized()
	# O fio é a face local −Z: a coluna Z da base aponta para o lado OPOSTO ao do fio.
	var z := -(fio - h * fio.dot(h)).normalized()
	var base := Basis(h.cross(z).normalized(), h, z)
	# "Socket vira PI em X" (mesma convenção de `giro_da_espada.gd`); a esquerda segura com a
	# palma do lado oposto.
	var base_d := base * Basis(Vector3.RIGHT, PI)
	var base_e := base * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI)
	return {
		"mao_R": pega - base_d * DESVIO_D,
		"mao_L": pega - h * ENTRE_MAOS - base_e * DESVIO_E,
		"punho_R": base_d.get_euler(),
		"punho_L": base_e.get_euler(),
	}
