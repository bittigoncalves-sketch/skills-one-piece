class_name CharacterVisualDefinition
extends Resource
## Visual de ensaio. Não muda identidade, colisão, fruta ou autoridade do ator.
## O launcher opta pelo recurso somente neste processo; sem persistência.
@export var model_scene: PackedScene
@export var target_height: float = 1.5
@export var rotation_degrees: Vector3 = Vector3.ZERO
@export var bone_map: Dictionary = {}
@export var hand_bones: Dictionary = {}

static func test_option(actor: Node = null) -> CharacterVisualDefinition:
	# O atalho da área de trabalho pode restringir o ensaio ao Player.
	if OS.get_environment("SOP_TEST_CHARACTER_TARGET") == "player" and (actor == null or not actor.is_in_group("player")):
		return null
	var path := OS.get_environment("SOP_TEST_CHARACTER_VISUAL")
	if path.is_empty():
		return null
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		push_warning("Visual de teste indisponível: " + path)
		return null
	var definition := load(path) as CharacterVisualDefinition
	if definition == null:
		push_warning("A opção de visual exige CharacterVisualDefinition: " + path)
	return definition

func instantiate_visual() -> Dictionary:
	if model_scene == null or not is_finite(target_height) or target_height <= 0.0 or not rotation_degrees.is_finite():
		push_warning("Visual de teste sem cena/altura válida; usando modelo original")
		return {}
	var instance := model_scene.instantiate()
	var model := instance as Node3D
	if model == null:
		instance.free()
		push_warning("Visual de teste exige raiz Node3D; usando modelo original")
		return {}
	var skeleton := BodyScanner._find_skeleton(model)
	if skeleton == null:
		model.free()
		push_warning("Visual de teste exige Skeleton3D; usando modelo original")
		return {}
	for role in BodyScanner.ROLES:
		if not bone_map.has(role) or skeleton.find_bone(str(bone_map[role])) < 0:
			model.free()
			push_warning("Mapa incompleto do visual de teste: " + role)
			return {}
	for child in model.find_children("*", "AnimationPlayer", true, false):
		(child as AnimationPlayer).active = false
	var wrapper := Node3D.new()
	wrapper.name = "CharacterTestVisual"
	wrapper.set_meta("visual_definition", self)
	wrapper.set_meta("preserve_original_materials", true)
	wrapper.set_meta("bone_map", bone_map)
	model.rotation_degrees += rotation_degrees
	wrapper.add_child(model)
	return {"node": wrapper, "skeleton": skeleton, "skinned": true, "anim_player": null}
