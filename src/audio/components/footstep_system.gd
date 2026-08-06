class_name FootstepSystem
extends Node
# res://scripts/audio/components/footstep_system.gd
# Sistema dedicado à lógica de passos. Responde a eventos de animação (AnimationPlayer) ou fallback por distância.

@export var character: Node3D
@export var walk_step_distance: float = 1.8
@export var run_step_distance: float = 2.4

# Estado interno
var _is_moving: bool = false
var _is_running: bool = false
var _distance_accumulated: float = 0.0
var _last_position: Vector3
var _current_surface: String = "grass" # No futuro, pode ler de um SurfaceDetectorComponent

func _ready() -> void:
	if character:
		_last_position = character.global_position

func update_movement_state(state: CharacterAudio.MovementState) -> void:
	match state:
		CharacterAudio.MovementState.WALK:
			_is_moving = true
			_is_running = false
		CharacterAudio.MovementState.RUN:
			_is_moving = true
			_is_running = true
		_:
			_is_moving = false
			_distance_accumulated = 0.0

func _process(delta: float) -> void:
	if not _is_moving or not character:
		if character:
			_last_position = character.global_position
		return
		
	var current_pos = character.global_position
	# Considera apenas a distância no plano XZ (horizontal)
	var pos_2d = Vector2(current_pos.x, current_pos.z)
	var last_pos_2d = Vector2(_last_position.x, _last_position.z)
	var distance_moved = last_pos_2d.distance_to(pos_2d)
	
	_last_position = current_pos
	_distance_accumulated += distance_moved
	
	var threshold = run_step_distance if _is_running else walk_step_distance
	
	# Fallback baseado em distância: só é acionado se a distância ultrapassar o limiar.
	# Quando há Animation Events, eles chamam 'trigger_step' explicitamente
	# e podemos opcionalmente desabilitar/zerar este acumulador.
	if _distance_accumulated >= threshold:
		_distance_accumulated -= threshold
		trigger_step()

# Pode ser chamado via Call Method Track no AnimationPlayer
func trigger_step() -> void:
	# Zeramos o acumulador de distância para que o fallback não conflite com o evento de animação
	_distance_accumulated = 0.0 
	
	var volume_mod = 0.0
	var pitch_mod = 1.0
	var pitch_rand = 0.1
	var vol_rand = 2.0 # Pequena variação em DB
	
	if _is_running:
		volume_mod = 2.5 # Mais alto
		pitch_mod = 0.85 # Mais grave (sensação de peso)
		
	AudioManager.play_3d(
		"footsteps", 
		_current_surface, 
		character.global_position, 
		{
			"pitch_scale": pitch_mod,
			"pitch_rand": pitch_rand,
			"volume_db": volume_mod,
			"vol_rand": vol_rand,
			"max_distance": 25.0
		}
	)

# Prepara a arquitetura para mudança de materiais
func set_surface(surface_name: String) -> void:
	_current_surface = surface_name
