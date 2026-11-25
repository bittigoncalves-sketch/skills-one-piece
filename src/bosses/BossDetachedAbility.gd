class_name BossDetachedAbility
extends BossAbility
## Um punho real como finalizador do combo; só a ida causa dano.
@export var distance: float = 7.0
@export var return_time: float = 0.35
@export var reuse_delay: float = 6.0

func duration() -> float:
	return windup + active + return_time + recovery

func valid() -> bool:
	return super() and hand == "R" and is_finite(distance) and distance > 0 \
		and is_finite(return_time) and return_time > 0 and is_finite(reuse_delay) and reuse_delay >= 0
