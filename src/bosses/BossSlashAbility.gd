class_name BossSlashAbility
extends BossAbility
## Corte à distância lançado quando o alvo FOGE. Preparação em duas partes: a mira
## acompanha o alvo por `aim_time`; depois trava, a linha vermelha aparece no chão
## e o corte sai no fim de `windup`. A frente é uma YoruWave (CCD, parede, um
## acerto por alvo, dano só no servidor).
@export var aim_time: float = 0.30
@export var slash_range: float = 18.0
@export var speed: float = 26.0
@export var width: float = 1.5
## Altura do centro da frente acima do chão.
@export var height_above_floor: float = 0.95
## Distância mínima entre corpos para lançar; mais perto, o combo de jabs resolve.
@export var min_distance: float = 4.0
## Velocidade com que o alvo se afasta (m/s, suavizada) para contar como fuga.
@export var flee_speed: float = 2.0
## Borda acima de 1,0 estoura no bloom; núcleo vermelho escuro mantém a silhueta.
@export var edge_color: Color = Color(2.4, 0.9, 0.7)
@export var core_color: Color = Color(0.85, 0.07, 0.04)

func telegraph_start() -> float:
	return aim_time

func valid() -> bool:
	for value in [aim_time, slash_range, speed, width, height_above_floor, min_distance, flee_speed]:
		if not is_finite(value) or value <= 0:
			return false
	return super() and aim_time < windup and min_distance < slash_range
