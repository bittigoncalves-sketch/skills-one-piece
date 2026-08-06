class_name CharacterAudio
extends Node
# res://scripts/audio/components/character_audio.gd
# Componente principal de áudio para entidades (Player, NPCs, Inimigos).
# Fica acoplado à entidade e reage aos seus estados sem precisar conhecer as lógicas internas de animação ou movimento.

enum MovementState { IDLE, WALK, RUN, JUMP, FALL, LAND }

@export var character: Node3D

var _current_state: MovementState = MovementState.IDLE
var footstep_system: FootstepSystem

func _ready() -> void:
	# Busca ou cria o sistema de passos como sub-nó
	footstep_system = get_node_or_null("FootstepSystem")
	if not footstep_system:
		footstep_system = FootstepSystem.new()
		footstep_system.name = "FootstepSystem"
		footstep_system.character = character if character else get_parent()
		add_child(footstep_system)
		
	if not character:
		character = get_parent()

# O Player/NPC chama essa função para notificar seu estado
func update_movement_state(new_state: MovementState) -> void:
	if _current_state == new_state:
		return
		
	_current_state = new_state
	
	# Processamento de transições únicas de estado
	match _current_state:
		MovementState.JUMP:
			_play_jump_sound()
		MovementState.LAND:
			_play_land_sound()
			
	# Atualiza o comportamento contínuo dos passos
	footstep_system.update_movement_state(_current_state)

func _play_jump_sound() -> void:
	# Som de impulso corporal (esforço, não cartunesco)
	AudioManager.play_3d(
		"movement", 
		"jump", 
		character.global_position, 
		{
			"pitch_rand": 0.1,
			"vol_rand": 1.5,
			"pitch_scale": 1.0,
			"volume_db": 0.0
		}
	)

func _play_land_sound() -> void:
	# Som de impacto de aterrissagem
	AudioManager.play_3d(
		"movement", 
		"land", 
		character.global_position, 
		{
			"pitch_rand": 0.15,
			"vol_rand": 1.0,
			"pitch_scale": 0.9,
			"volume_db": 2.0
		}
	)

# Métodos helper para eventos externos
func on_attack_started(attack_type: String) -> void:
	pass # Futuro: AudioManager.play_3d("combat", attack_type, ...)

func on_damage_received(amount: float) -> void:
	pass # Futuro: AudioManager.play_3d("combat", "damage_impact", ...)

# Para ser exposto e chamado livremente por AnimationPlayers de outros modelos
func trigger_animation_step() -> void:
	if footstep_system:
		footstep_system.trigger_step()
