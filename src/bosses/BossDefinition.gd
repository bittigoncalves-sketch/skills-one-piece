class_name BossDefinition
extends Resource
const PartDefinition = preload("res://src/bosses/BodyPartDefinition.gd")
@export var detached_part: PartDefinition
@export var id: StringName
@export var display_name: String = "Boss"
@export var visual: CharacterVisualDefinition
@export var ability: BossAbility
@export var followups: Array[BossAbility] = []
## Corte à distância contra quem foge. Opcional.
@export var slash: BossSlashAbility
@export var reaction_interval: float = 0.06
@export var max_health: float = 4096.0
@export var height: float = 2.2
@export var width: float = 1.1
@export var speed: float = 3.2
@export var aggro_range: float = 11.0
@export var leash_range: float = 22.0
@export var attack_distance: float = 1.25
## Distância entre corpos acima da qual o combo não emenda o próximo soco.
@export var combo_break_distance: float = 2.0
@export var gravity: float = 32.0

func moves() -> Array[BossAbility]:
	var result: Array[BossAbility] = [ability]
	result.append_array(followups)
	return result

func move_for(action: String) -> BossAbility:
	for move in moves():
		if str(move.id) == action:
			return move
	if slash and str(slash.id) == action:
		return slash
	return ability

func valid() -> bool:
	if detached_part != null and not detached_part.valid():
		return false
	for move in moves():
		if move is BossDetachedAbility and (detached_part == null or visual == null or str(detached_part.bone_name) != str(visual.hand_bones.get(move.hand, ""))):
			return false
	var ids := {str(ability.id) if ability else "": true}
	for move in followups:
		# action_id replicado identifica o golpe no cliente; id repetido pintaria a mão errada.
		if move == null or not move.valid() or ids.has(str(move.id)):
			return false
		ids[str(move.id)] = true
	if slash and (not slash.valid() or ids.has(str(slash.id))):
		return false
	for value in [reaction_interval, max_health, height, width, speed, aggro_range, leash_range, attack_distance, combo_break_distance, gravity]:
		if not is_finite(value) or value <= 0:
			return false
	return visual != null and ability != null and ability.valid() and max_health > 0 and height > 0 and width > 0
