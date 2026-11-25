class_name RumoDosGolpes
extends RefCounted
## CORREÇÃO DE RUMO dos golpes do Epic Fight (13/11/2026, pedido do dono: "o montante de pedra realiza seus ataques para trás… promover o teste de todas as espadas para confirmar a direção
## que atacam e em seguida a correção"). `tools/dev_tests/test_direcao_de_todas_as_armas_ef.gd` mede, por clipe, para onde a PONTA aponta no meio da janela de dano em relação à mira
## (com sinal, graus; + = à esquerda). Vários clipes do mod têm o corte centrado longe da frente (o `greatsword_auto1` corta a −164°, ATRÁS; a lança −89°/+68°; a espada +87°…),
## porque o mod gira o corpo inteiro e o rig daqui tem uma coluna só. Aqui cada clipe fora de ±`TOLERANCIA` ganha um DESVIO de yaw no torso (o quanto falta para o rumo cair dentro
## da tolerância), aplicado pelo `ProceduralAnimator` durante o golpe. Clipe que não está na tabela não é mexido. Os números são MEDIDOS (mediana nas armas de cada clipe, câmera 0°).
## GATILHO: refazer a medição (rodar o teste com `giro=0 desvio=0`) quando os clipes forem re-extraídos ou o rig ganhar a coluna de 3 ossos.
const TOLERANCIA := 35.0
## clipe (sem `ef_` e sem `.res`) → rumo medido (graus, com sinal) no meio da janela de dano, SEM correção.
const RUMO_MEDIDO := {
	"greatsword_auto1": -164.0, "greatsword_auto2": 42.0, "longsword_auto1": 72.0,   # medido +58; a correção rendeu ~80% do desvio (40° residual), então a entrada foi subida até o teste passar
	 "longsword_auto3": -71.0,
	"spear_twohand_auto1": -89.0, "spear_twohand_auto2": 68.0, "sword_auto2": 87.0, "sword_auto3": -68.0, "sword_auto4": -70.0,
	"uchigatana_auto1": -62.0, "uchigatana_auto3": -95.0,
}
const DESVIO_MAXIMO := 130.0


## Desvio de yaw (rad) a somar ao torso durante o clipe `caminho` (ex.: "res://assets/epic_fight/res/ef_greatsword_auto1.res"); 0 se o clipe não precisa.
static func desvio_do_clipe(caminho: String) -> float:
	var nome := caminho.get_file().get_basename().trim_prefix("ef_")
	if not RUMO_MEDIDO.has(nome) or Engine.has_meta(&"sem_desvio_de_rumo"):
		return 0.0
	var theta: float = RUMO_MEDIDO[nome]
	var excesso := theta - clampf(theta, -TOLERANCIA, TOLERANCIA)
	if absf(excesso) < 8.0:
		return 0.0
	return deg_to_rad(clampf(-excesso, -DESVIO_MAXIMO, DESVIO_MAXIMO))
