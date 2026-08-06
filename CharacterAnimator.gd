class_name CharacterAnimator
extends Node

# ============================================================================
#  Gerenciador da Máquina de Estados de Animações (Godot 4)
#  Suporta os 6 estados padrão: IDLE, RUN, JUMP, DAMAGE, KILL, DEATH
# ============================================================================

enum AnimState { IDLE, RUN, JUMP, CLIMB, DAMAGE, KILL, DEATH }

@export var animation_player: AnimationPlayer
@export var character_id: String = "buggy"

var current_state: AnimState = AnimState.IDLE
var is_locked: bool = false
var _rest_poses: Array[Dictionary] = []

signal animation_finished(anim_name: String)

func _ready() -> void:
	if animation_player:
		_cache_rest_poses()
		animation_player.animation_finished.connect(_on_animation_finished)

# Toda animação procedural precisa começar da mesma pose. Sem essa restauração,
# uma faixa que não anima determinado membro deixava nele o último frame de
# walk/run, gerando braços e pernas travados ao voltar para idle.
func _cache_rest_poses() -> void:
	var root := animation_player.get_node_or_null(animation_player.root_node)
	if root == null:
		return
	for node in _node3d_descendants(root):
		_rest_poses.append({
			"node": node,
			"position": node.position,
			"rotation": node.rotation,
			"scale": node.scale,
		})

func _restore_rest_pose() -> void:
	for pose in _rest_poses:
		var node: Node3D = pose["node"]
		if is_instance_valid(node):
			node.position = pose["position"]
			node.rotation = pose["rotation"]
			node.scale = pose["scale"]

func _node3d_descendants(root: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for child in root.get_children():
		if child is Node3D:
			result.append(child)
		result.append_array(_node3d_descendants(child))
	return result

func update_state(velocity: Vector3, is_on_floor: bool, is_climbing: bool = false) -> void:
	if is_locked:
		return
		
	if is_climbing:
		_play_state(AnimState.CLIMB, "climb")
	elif not is_on_floor:
		_play_state(AnimState.JUMP, "jump")
	elif velocity.length() > 0.2:
		_play_state(AnimState.RUN, "run")
	else:
		_play_state(AnimState.IDLE, "idle")

func trigger_damage() -> void:
	if current_state == AnimState.DEATH:
		return
	is_locked = true
	_play_state(AnimState.DAMAGE, "damage")

func trigger_kill() -> void:
	if current_state == AnimState.DEATH:
		return
	is_locked = true
	_play_state(AnimState.KILL, "kill")

func trigger_death() -> void:
	is_locked = true
	_play_state(AnimState.DEATH, "death")

func _play_state(new_state: AnimState, anim_name: String) -> void:
	if current_state == new_state and animation_player and animation_player.is_playing():
		return
	current_state = new_state
	if animation_player and animation_player.has_animation(anim_name):
		_restore_rest_pose()
		animation_player.play(anim_name)
		# Amostra o primeiro keyframe imediatamente: não há um frame com a pose
		# anterior quando idle, walk, jump ou climb trocam entre si.
		animation_player.seek(0.0, true)
	elif animation_player:
		# Mantém o modelo em uma pose válida caso algum personagem ainda não
		# tenha uma animação específica para este estado.
		animation_player.play("idle")

func _on_animation_finished(anim_name: String) -> void:
	if anim_name not in ["idle", "run", "jump", "climb"]:
		is_locked = false
		current_state = AnimState.IDLE
	emit_signal("animation_finished", anim_name)
