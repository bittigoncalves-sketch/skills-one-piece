class_name TecnicaDeFruta
extends Resource
# ============================================================================
#  UMA TÉCNICA DE FRUTA NO MODO HISTÓRIA — a ficha, não o código do golpe.
#
#  Plano: `~/.claude/plans/…fruta…` (Rocket, 21/09/2026). A arena continua tirando
#  os números de `Balance.gd` e o custo fixo de `Player.ENERGY_SKILL`; a história
#  tem escala própria (vida 20, inimigo 250) e energia de 10, onde um custo de 180
#  bloquearia tudo.
#
#  ⚠️ Padrões NEUTROS de propósito: o Godot não grava no `.tres` o campo igual ao
#  padrão, então número real tem que estar escrito lá (armadilha registrada na
#  Fase 1 do combate direcional, decisão 18).
# ============================================================================

## Tecla do golpe: "Z", "X", "C", "V" ou "F".
@export var slot := ""
## Nome que a HUD mostra.
@export var nome := ""
## O que o executor faz com esta tecla (`missil`, `bombardeio`, `mergulho`, `voo`…).
## É o comportamento, não a tecla: o mesmo comportamento pode servir a outra tecla.
@export var comportamento := ""
@export_range(0.0, 60.0, 0.1, "suffix:s") var recarga := 0.0
@export_range(0.0, 100.0, 0.5) var custo_de_energia := 0.0
@export_range(0.0, 500.0, 1.0) var dano := 0.0
## Raio da explosão/contato, em metros.
@export_range(0.0, 20.0, 0.1, "suffix:m") var raio := 0.0
## Até onde o golpe chega (míssil, salto). O bombardeio não usa: a distância dele deriva
## do raio (`mira_de_rocket.distancias_do_bombardeio`), para as explosões ficarem encostadas.
@export_range(0.0, 100.0, 0.5, "suffix:m") var alcance := 0.0
@export_range(0.0, 40.0, 0.5) var empurrao := 0.0
## Quanto tira da postura de quem BLOQUEIA com a guarda do combate direcional.
@export_range(0.0, 200.0, 1.0) var dano_de_postura := 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var hitstun := 0.0
## Quanto a técnica DURA, para as que duram (o voo). 0 nas que não duram.
@export_range(0.0, 20.0, 0.1, "suffix:s") var duracao := 0.0


func valida() -> bool:
	return not slot.is_empty() and not comportamento.is_empty()
