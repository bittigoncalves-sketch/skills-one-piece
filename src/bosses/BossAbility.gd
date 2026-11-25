class_name BossAbility
extends Resource
## Dados imutáveis; relógio, orçamento e cooldown vivem no BossCombat.
@export var id: StringName = &"jab"
@export_enum("L", "R") var hand: String = "L"
@export var windup: float = 0.48
@export var active: float = 0.18
@export var recovery: float = 0.72
@export var cooldown: float = 1.25
@export var damage: float = 72.0
@export var hit_radius: float = 0.22
@export var knockback: float = 5.0
@export var hitstun: float = 0.18
## Arremesso com derrubada no alvo (voa, cai deitado, levanta). Zero = não arremessa.
## Só o último soco do combo usa; os outros não empurram, para o combo conectar.
@export var launch_horizontal: float = 0.0
@export var launch_vertical: float = 0.0

func launches() -> bool:
	return launch_horizontal > 0.0 or launch_vertical > 0.0

## Quando a marca do golpe aparece. Jab: desde o início da preparação.
func telegraph_start() -> float:
	return 0.0

func duration() -> float:
	return windup + active + recovery

func valid() -> bool:
	for value in [windup, active, recovery, cooldown, damage, hit_radius, knockback, hitstun, launch_horizontal, launch_vertical]:
		if not is_finite(value) or value < 0:
			return false
	return hand in ["L", "R"] and windup >= 0.1 and active > 0 and recovery > 0 and cooldown >= 0 and damage >= 0 and hit_radius > 0
