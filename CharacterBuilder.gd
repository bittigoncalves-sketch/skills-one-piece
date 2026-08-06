class_name CharacterBuilder
extends Node

# ============================================================================
#  CHARACTER BUILDER — Construtor Voxel 3D e Animações Procedurais (Godot 4)
#  Cria os modelos 3D em estilo Voxel e a árvore de Animações Pose-a-Pose
#  para Buggy o Palhaço e Nami. Substitui o bloco/quadrado cinza!
# ============================================================================

# Personagens SKINNADOS (Skeleton3D + malha skinada, ex.: modelos do Meshy AI).
# Usam animação ESQUELETAL (SkeletalAnimator), não o rig por-nós. Textura vem do
# próprio modelo (PBR), então NÃO aplicamos o <id>.png por cima.
const SKINNED_MODELS := {
	"ace": "res://assets/models/meshy_ace/ace_meshy.fbx",
	"nami": "res://assets/models/meshy_nami/meshy_nami.fbx",
	"blackbeard": "res://assets/models/meshy_blackbeard/meshy_blackbeard.fbx",
	"crocodile": "res://assets/models/meshy_crocodile/meshy_crocodile.fbx",
}
# Walk NATIVO de cada modelo (bind-pose própria — NÃO reusar entre modelos, senão distorce).
const SKINNED_WALKS := {
	"ace": "res://assets/models/meshy_ace/ace_meshy_walk.fbx",
	"nami": "res://assets/models/meshy_nami/meshy_nami_walk.fbx",
	"blackbeard": "res://assets/models/meshy_blackbeard/meshy_blackbeard_walk.fbx",
}

static func build_character(char_id: String) -> Dictionary:
	# --- caminho SKINNADO (tem prioridade) ---
	if SKINNED_MODELS.has(char_id) and ResourceLoader.exists(SKINNED_MODELS[char_id]):
		var packed = load(SKINNED_MODELS[char_id])
		if packed:
			var inst := (packed.instantiate()) as Node3D
			print("🧍 Modelo SKINNADO carregado: ", SKINNED_MODELS[char_id])
			return {
				"node": inst,
				"anim_player": _find_anim_player(inst),
				"skeleton": _find_skeleton(inst),
				"skinned": true,
			}

	var root := Node3D.new()
	root.name = "CharacterRoot_" + char_id

	var anim_player := AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	root.add_child(anim_player)

	var library := AnimationLibrary.new()

	# Tenta carregar modelo 3D autêntico (.scn ou .glb)
	var scn_path := "res://assets/models/" + char_id + ".scn"
	var glb_path := "res://assets/models/" + char_id + ".glb"
	var used_glb := false
	var model_inst: Node3D = null

	if ResourceLoader.exists(scn_path):
		var scene: PackedScene = load(scn_path)
		if scene:
			model_inst = scene.instantiate() as Node3D
			print("✨ Modelo 3D autêntico .scn carregado: ", scn_path)

	if not model_inst and FileAccess.file_exists(glb_path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var err := doc.append_from_file(glb_path, state)
		if err == OK:
			model_inst = doc.generate_scene(state) as Node3D
			print("✨ Modelo 3D autêntico GLB carregado: ", glb_path)

	if model_inst:
		var skin_pivot := Node3D.new()
		skin_pivot.name = "SkinPivot"
		if char_id == "buggy":
			skin_pivot.rotation.y = PI
		root.add_child(skin_pivot)

		model_inst.name = "GLBModel_" + char_id
		model_inst.scale = Vector3(1.8, 1.8, 1.8)
		skin_pivot.add_child(model_inst)
		
		if char_id == "ace":
			var ace_head := model_inst.find_child("Head", true, false) as Node3D
			if ace_head:
				ace_head.rotation.y += PI
				print("🔧 Orientação da cabeça de Ace (GLB) corrigida (+180° Y)")

		print("=== NOS DE ", scn_path, " ===")
		_print_node_tree(model_inst, "")
		print("==========================")

		# Aplica textura PNG do Blockbench se disponível
		var png_path := "res://assets/models/" + char_id + ".png"
		if FileAccess.file_exists(png_path):
			var img := Image.load_from_file(png_path)
			if img and not img.is_empty():
				var tex := ImageTexture.create_from_image(img)
				_apply_texture_to_meshes(model_inst, tex)
				print("🎨 Textura PNG vinculada com sucesso: ", png_path)

		used_glb = true

	if char_id == "nami":
		if not used_glb:
			VoxelMeshes.build_nami(root)
		_build_nami_animations(library, root)
	elif char_id == "ace":
		if not used_glb:
			VoxelMeshes.build_ace(root)
		_build_ace_animations(library, root)
	else:
		if not used_glb:
			VoxelMeshes.build_buggy(root)
		_build_buggy_animations(library, root, used_glb)

	anim_player.add_animation_library("", library)
	return {"node": root, "anim_player": anim_player, "skinned": false}

static func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim_player(c)
		if r:
			return r
	return null

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null

# Meshes voxel (Buggy/Nami/Ace) -> VoxelMeshes.gd
static func _build_buggy_animations(lib: AnimationLibrary, root: Node3D, used_glb: bool = false) -> void:
	if used_glb:
		# O construtor também usa este conjunto de animações para o personagem
		# base. O path deve apontar para o modelo efetivamente instanciado, não
		# ficar preso ao nome do Buggy.
		var node_p := "SkinPivot/GLBModel_" + root.name.trim_prefix("CharacterRoot_")
		var idle_tracks: Array = [
			{"path": node_p + ":position", "keys": [{0.0: Vector3(0, 0, 0), 0.6: Vector3(0, 0.08, 0), 1.2: Vector3(0, 0, 0)}]}
		]
		_append_part_rotation(idle_tracks, root, "UpperArm_L", {0.0: Vector3(-0.10, 0, 0), 0.6: Vector3(0.12, 0, 0), 1.2: Vector3(-0.10, 0, 0)})
		_append_part_rotation(idle_tracks, root, "UpperArm_R", {0.0: Vector3(0.10, 0, 0), 0.6: Vector3(-0.12, 0, 0), 1.2: Vector3(0.10, 0, 0)})
		lib.add_animation("idle", _make_anim(1.2, idle_tracks, true))
		var run_tracks: Array = [
			{"path": node_p + ":position", "keys": [{0.0: Vector3(0, 0, 0), 0.25: Vector3(0, 0.11, 0), 0.5: Vector3(0, 0, 0)}]}
		]
		# Os modelos importados têm membros separados. Animá-los por path real
		# (em vez de só balançar o modelo inteiro) dá uma corrida legível.
		_append_part_rotation(run_tracks, root, "UpperArm_L", {0.0: Vector3(-0.85, 0, 0), 0.25: Vector3(0.85, 0, 0), 0.5: Vector3(-0.85, 0, 0)})
		_append_part_rotation(run_tracks, root, "UpperArm_R", {0.0: Vector3(0.85, 0, 0), 0.25: Vector3(-0.85, 0, 0), 0.5: Vector3(0.85, 0, 0)})
		_append_part_rotation(run_tracks, root, "Thigh_L", {0.0: Vector3(0.75, 0, 0), 0.25: Vector3(-0.75, 0, 0), 0.5: Vector3(0.75, 0, 0)})
		_append_part_rotation(run_tracks, root, "Thigh_R", {0.0: Vector3(-0.75, 0, 0), 0.25: Vector3(0.75, 0, 0), 0.5: Vector3(-0.75, 0, 0)})
		lib.add_animation("run", _make_anim(0.5, run_tracks, true))
		lib.add_animation("walk", _make_anim(0.9, run_tracks, true))
		var jump_tracks: Array = [
			{"path": node_p + ":position", "keys": [{0.0: Vector3(0, 0, 0), 0.4: Vector3(0, 0.6, 0), 0.8: Vector3(0, 0, 0)}]}
		]
		_append_part_rotation(jump_tracks, root, "UpperArm_L", {0.0: Vector3(0, 0, 0), 0.4: Vector3(-0.85, 0, 0), 0.8: Vector3(0, 0, 0)})
		_append_part_rotation(jump_tracks, root, "UpperArm_R", {0.0: Vector3(0, 0, 0), 0.4: Vector3(-0.85, 0, 0), 0.8: Vector3(0, 0, 0)})
		_append_part_rotation(jump_tracks, root, "Thigh_L", {0.0: Vector3(0, 0, 0), 0.4: Vector3(0.45, 0, 0), 0.8: Vector3(0, 0, 0)})
		_append_part_rotation(jump_tracks, root, "Thigh_R", {0.0: Vector3(0, 0, 0), 0.4: Vector3(0.45, 0, 0), 0.8: Vector3(0, 0, 0)})
		lib.add_animation("jump", _make_anim(0.8, jump_tracks, false))
		var climb_tracks: Array = [
			{"path": node_p + ":position", "keys": [{0.0: Vector3(0, 0, 0), 0.275: Vector3(0, 0.12, 0), 0.55: Vector3(0, 0, 0)}]},
			{"path": node_p + ":rotation", "keys": [{0.0: Vector3(0, 0, -0.10), 0.275: Vector3(0, 0, 0.10), 0.55: Vector3(0, 0, -0.10)}]}
		]
		_append_part_rotation(climb_tracks, root, "UpperArm_L", {0.0: Vector3(-1.1, 0, 0), 0.275: Vector3(0.35, 0, 0), 0.55: Vector3(-1.1, 0, 0)})
		_append_part_rotation(climb_tracks, root, "UpperArm_R", {0.0: Vector3(0.35, 0, 0), 0.275: Vector3(-1.1, 0, 0), 0.55: Vector3(0.35, 0, 0)})
		lib.add_animation("climb", _make_anim(0.55, climb_tracks, true))
		var damage_tracks: Array = [
			{"path": node_p + ":position", "keys": [{0.0: Vector3(0, 0, 0), 0.2: Vector3(0, 0, -0.2), 0.4: Vector3(0, 0, 0)}]}
		]
		_append_part_rotation(damage_tracks, root, "UpperArm_L", {0.0: Vector3(0, 0, 0), 0.2: Vector3(-1.0, 0, 0.35), 0.4: Vector3(0, 0, 0)})
		_append_part_rotation(damage_tracks, root, "UpperArm_R", {0.0: Vector3(0, 0, 0), 0.2: Vector3(-1.0, 0, -0.35), 0.4: Vector3(0, 0, 0)})
		lib.add_animation("damage", _make_anim(0.4, damage_tracks, false))
		var kill_tracks: Array = [
			{"path": node_p + ":rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.5: Vector3(0, 0.35, 0), 1.0: Vector3(0, 0, 0)}]}
		]
		_append_part_rotation(kill_tracks, root, "UpperArm_L", {0.0: Vector3(0, 0, 0), 0.26: Vector3(-1.35, 0, 0), 1.0: Vector3(0, 0, 0)})
		_append_part_rotation(kill_tracks, root, "UpperArm_R", {0.0: Vector3(0, 0, 0), 0.48: Vector3(-1.75, 0, 0), 1.0: Vector3(0, 0, 0)})
		lib.add_animation("kill", _make_anim(1.0, kill_tracks, false))
		lib.add_animation("death", _make_anim(1.2, [
			{"path": node_p + ":position", "keys": [{0.0: Vector3(0, 0, 0), 0.6: Vector3(0, -0.6, 0), 1.2: Vector3(0, -0.8, 0)}]},
			{"path": node_p + ":rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.6: Vector3(-1.57, 0, 0), 1.2: Vector3(-1.57, 0, 0)}]}
		], false))
		_build_combat_animations(lib, root)
		return

	# Idle: Respiração dinâmica, inclinação sutil da cabeça e agitação das chiquinhas
	lib.add_animation("idle", _make_anim(1.4, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.95, 0), 0.7: Vector3(0, 0.99, 0), 1.4: Vector3(0, 0.95, 0)}]},
		{"path": "Torso/Head:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.7: Vector3(0.04, 0.05, 0), 1.4: Vector3(0, 0, 0)}]},
		{"path": "Torso/LeftArm:rotation", "keys": [{0.0: Vector3(0, 0, 0.12), 0.7: Vector3(0, 0, 0.28), 1.4: Vector3(0, 0, 0.12)}]},
		{"path": "Torso/RightArm:rotation", "keys": [{0.0: Vector3(0, 0, -0.12), 0.7: Vector3(0, 0, -0.28), 1.4: Vector3(0, 0, -0.12)}]},
		{"path": "Torso/Head/HairLeftPigtail:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.7: Vector3(0, 0, 0.15), 1.4: Vector3(0, 0, 0)}]},
		{"path": "Torso/Head/HairRightPigtail:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.7: Vector3(0, 0, -0.15), 1.4: Vector3(0, 0, 0)}]}
	], true))

	# Run: Corrida vigorosa com balanço oposto de braços/pernas e inclinação do torso
	lib.add_animation("run", _make_anim(0.5, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.95, 0), 0.25: Vector3(0, 1.08, 0), 0.5: Vector3(0, 0.95, 0)}]},
		{"path": "Torso:rotation", "keys": [{0.0: Vector3(0.12, 0, 0), 0.25: Vector3(0.12, 0, 0.05), 0.5: Vector3(0.12, 0, 0)}]},
		{"path": "Torso/LeftLeg:rotation", "keys": [{0.0: Vector3(0.75, 0, 0), 0.25: Vector3(-0.75, 0, 0), 0.5: Vector3(0.75, 0, 0)}]},
		{"path": "Torso/RightLeg:rotation", "keys": [{0.0: Vector3(-0.75, 0, 0), 0.25: Vector3(0.75, 0, 0), 0.5: Vector3(-0.75, 0, 0)}]},
		{"path": "Torso/LeftArm:rotation", "keys": [{0.0: Vector3(-0.65, 0, 0.1), 0.25: Vector3(0.65, 0, 0.1), 0.5: Vector3(-0.65, 0, 0.1)}]},
		{"path": "Torso/RightArm:rotation", "keys": [{0.0: Vector3(0.65, 0, -0.1), 0.25: Vector3(-0.65, 0, -0.1), 0.5: Vector3(0.65, 0, -0.1)}]}
	], true))
	lib.add_animation("walk", _make_anim(0.9, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.95, 0), 0.45: Vector3(0, 1.02, 0), 0.9: Vector3(0, 0.95, 0)}]},
		{"path": "Torso/LeftLeg:rotation", "keys": [{0.0: Vector3(0.55, 0, 0), 0.45: Vector3(-0.55, 0, 0), 0.9: Vector3(0.55, 0, 0)}]},
		{"path": "Torso/RightLeg:rotation", "keys": [{0.0: Vector3(-0.55, 0, 0), 0.45: Vector3(0.55, 0, 0), 0.9: Vector3(-0.55, 0, 0)}]}
	], true))

	# Jump: Desprendimento Bara Bara! O tronco flutua e as pernas estendem
	lib.add_animation("jump", _make_anim(0.8, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.95, 0), 0.4: Vector3(0, 1.45, 0), 0.8: Vector3(0, 0.95, 0)}]},
		{"path": "Torso/Head:position", "keys": [{0.0: Vector3(0, 0.58, 0), 0.4: Vector3(0, 0.78, 0), 0.8: Vector3(0, 0.58, 0)}]}, # Cabeça flutua
		{"path": "Torso/LeftLeg:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.4: Vector3(0.85, 0, -0.2), 0.8: Vector3(0, 0, 0)}]},
		{"path": "Torso/RightLeg:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.4: Vector3(0.85, 0, 0.2), 0.8: Vector3(0, 0, 0)}]}
	], false))

	lib.add_animation("climb", _make_anim(0.55, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.95, 0), 0.275: Vector3(0, 1.06, 0), 0.55: Vector3(0, 0.95, 0)}]},
		{"path": "Torso/LeftArm:rotation", "keys": [{0.0: Vector3(-0.9, 0, 0.1), 0.275: Vector3(0.45, 0, 0.1), 0.55: Vector3(-0.9, 0, 0.1)}]},
		{"path": "Torso/RightArm:rotation", "keys": [{0.0: Vector3(0.45, 0, -0.1), 0.275: Vector3(-0.9, 0, -0.1), 0.55: Vector3(0.45, 0, -0.1)}]}
	], true))

	# Damage: Recuo de impacto com reação de choque
	lib.add_animation("damage", _make_anim(0.4, [
		{"path": "Torso:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.2: Vector3(-0.45, 0, 0.15), 0.4: Vector3(0, 0, 0)}]},
		{"path": "Torso/Head:position", "keys": [{0.0: Vector3(0, 0.58, 0), 0.2: Vector3(0, 0.82, -0.25), 0.4: Vector3(0, 0.58, 0)}]},
		{"path": "Torso/LeftArm:rotation", "keys": [{0.0: Vector3(0, 0, 0.1), 0.2: Vector3(0, 0, 1.2), 0.4: Vector3(0, 0, 0.1)}]},
		{"path": "Torso/RightArm:rotation", "keys": [{0.0: Vector3(0, 0, -0.1), 0.2: Vector3(0, 0, -1.2), 0.4: Vector3(0, 0, -0.1)}]}
	], false))

	# Kill: Ataque Bara Bara Ho (Puño Desmembrado com Facas Giratórias!)
	lib.add_animation("kill", _make_anim(1.0, [
		{"path": "Torso/LeftArm:position", "keys": [{0.0: Vector3(-0.42, 0.1, 0), 0.4: Vector3(-1.4, 0.5, 1.2), 1.0: Vector3(-0.42, 0.1, 0)}]},
		{"path": "Torso/RightArm:position", "keys": [{0.0: Vector3(0.42, 0.1, 0), 0.4: Vector3(1.4, 0.5, 1.2), 1.0: Vector3(0.42, 0.1, 0)}]},
		{"path": "Torso/LeftArm:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.5: Vector3(0, 6.28, 0), 1.0: Vector3(0, 0, 0)}]},
		{"path": "Torso/RightArm:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.5: Vector3(0, -6.28, 0), 1.0: Vector3(0, 0, 0)}]}
	], false))

	# Death: Desmontagem Completa dos Voxels Bara Bara ao Cair
	lib.add_animation("death", _make_anim(1.2, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.95, 0), 0.6: Vector3(0, 0.2, 0), 1.2: Vector3(0, 0.1, 0)}]},
		{"path": "Torso:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.6: Vector3(-1.57, 0, 0), 1.2: Vector3(-1.57, 0, 0)}]},
		{"path": "Torso/Head:position", "keys": [{0.0: Vector3(0, 0.58, 0), 0.6: Vector3(0.6, 0.1, 0.5), 1.2: Vector3(0.6, 0.1, 0.5)}]},
		{"path": "Torso/LeftArm:position", "keys": [{0.0: Vector3(-0.42, 0.1, 0), 0.6: Vector3(-0.9, 0.1, 0.2), 1.2: Vector3(-0.9, 0.1, 0.2)}]},
		{"path": "Torso/RightArm:position", "keys": [{0.0: Vector3(0.42, 0.1, 0), 0.6: Vector3(0.9, 0.1, 0.2), 1.2: Vector3(0.9, 0.1, 0.2)}]}
	], false))
	_build_combat_animations(lib, root)

# ------------------------------------ ANIMAÇÕES DO RIG ARTICULADO (Nami/Ace)
# Nami e Ace usam o MESMO rig do Base, então compartilham o conjunto de animações,
# montado pelas juntas reais (UpperArm_L/R, Thigh_L/R) via _append_part_rotation.
# A locomoção fina roda pelo ProceduralAnimator; aqui ficam idle/one-shots.
static func _build_nami_animations(lib: AnimationLibrary, root: Node3D) -> void:
	_build_rig_animations(lib, root)

static func _build_ace_animations(lib: AnimationLibrary, root: Node3D) -> void:
	_build_rig_animations(lib, root)

static func _build_rig_animations(lib: AnimationLibrary, root: Node3D) -> void:
	var idle: Array = [{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.98, 0), 0.7: Vector3(0, 1.02, 0), 1.4: Vector3(0, 0.98, 0)}]}]
	_append_part_rotation(idle, root, "UpperArm_L", {0.0: Vector3(0, 0, 0.08), 0.7: Vector3(0.06, 0, 0.12), 1.4: Vector3(0, 0, 0.08)})
	_append_part_rotation(idle, root, "UpperArm_R", {0.0: Vector3(0, 0, -0.08), 0.7: Vector3(0.06, 0, -0.12), 1.4: Vector3(0, 0, -0.08)})
	lib.add_animation("idle", _make_anim(1.4, idle, true))

	var run: Array = [{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.98, 0), 0.25: Vector3(0, 1.09, 0), 0.5: Vector3(0, 0.98, 0)}]}]
	_append_part_rotation(run, root, "UpperArm_L", {0.0: Vector3(-0.7, 0, 0), 0.25: Vector3(0.7, 0, 0), 0.5: Vector3(-0.7, 0, 0)})
	_append_part_rotation(run, root, "UpperArm_R", {0.0: Vector3(0.7, 0, 0), 0.25: Vector3(-0.7, 0, 0), 0.5: Vector3(0.7, 0, 0)})
	_append_part_rotation(run, root, "Thigh_L", {0.0: Vector3(0.7, 0, 0), 0.25: Vector3(-0.7, 0, 0), 0.5: Vector3(0.7, 0, 0)})
	_append_part_rotation(run, root, "Thigh_R", {0.0: Vector3(-0.7, 0, 0), 0.25: Vector3(0.7, 0, 0), 0.5: Vector3(-0.7, 0, 0)})
	lib.add_animation("run", _make_anim(0.5, run, true))
	lib.add_animation("walk", _make_anim(0.9, run, true))

	var jump: Array = [{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.98, 0), 0.4: Vector3(0, 1.45, 0), 0.8: Vector3(0, 0.98, 0)}]}]
	_append_part_rotation(jump, root, "UpperArm_L", {0.0: Vector3(0, 0, 0), 0.4: Vector3(-1.2, 0, 0.3), 0.8: Vector3(0, 0, 0)})
	_append_part_rotation(jump, root, "UpperArm_R", {0.0: Vector3(0, 0, 0), 0.4: Vector3(-1.2, 0, -0.3), 0.8: Vector3(0, 0, 0)})
	_append_part_rotation(jump, root, "Thigh_L", {0.0: Vector3(0, 0, 0), 0.4: Vector3(0.45, 0, 0), 0.8: Vector3(0, 0, 0)})
	_append_part_rotation(jump, root, "Thigh_R", {0.0: Vector3(0, 0, 0), 0.4: Vector3(0.45, 0, 0), 0.8: Vector3(0, 0, 0)})
	lib.add_animation("jump", _make_anim(0.8, jump, false))

	var climb: Array = [{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.98, 0), 0.275: Vector3(0, 1.09, 0), 0.55: Vector3(0, 0.98, 0)}]}]
	_append_part_rotation(climb, root, "UpperArm_L", {0.0: Vector3(-1.1, 0, 0), 0.275: Vector3(0.35, 0, 0), 0.55: Vector3(-1.1, 0, 0)})
	_append_part_rotation(climb, root, "UpperArm_R", {0.0: Vector3(0.35, 0, 0), 0.275: Vector3(-1.1, 0, 0), 0.55: Vector3(0.35, 0, 0)})
	lib.add_animation("climb", _make_anim(0.55, climb, true))

	var dmg: Array = [{"path": "Torso:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.2: Vector3(-0.4, 0, 0.1), 0.4: Vector3(0, 0, 0)}]}]
	_append_part_rotation(dmg, root, "UpperArm_L", {0.0: Vector3(0, 0, 0), 0.2: Vector3(-1.0, 0, 0.35), 0.4: Vector3(0, 0, 0)})
	_append_part_rotation(dmg, root, "UpperArm_R", {0.0: Vector3(0, 0, 0), 0.2: Vector3(-1.0, 0, -0.35), 0.4: Vector3(0, 0, 0)})
	lib.add_animation("damage", _make_anim(0.4, dmg, false))

	var kill: Array = [{"path": "Torso:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.3: Vector3(0, 0.3, 0), 1.0: Vector3(0, 0, 0)}]}]
	_append_part_rotation(kill, root, "UpperArm_R", {0.0: Vector3(0, 0, 0), 0.4: Vector3(-1.9, 0, 0), 1.0: Vector3(0, 0, 0)})
	_append_part_rotation(kill, root, "UpperArm_L", {0.0: Vector3(0, 0, 0), 0.5: Vector3(-1.5, 0, 0), 1.0: Vector3(0, 0, 0)})
	lib.add_animation("kill", _make_anim(1.0, kill, false))

	lib.add_animation("death", _make_anim(1.2, [
		{"path": "Torso:position", "keys": [{0.0: Vector3(0, 0.98, 0), 0.6: Vector3(0, 0.2, 0), 1.2: Vector3(0, 0.15, 0)}]},
		{"path": "Torso:rotation", "keys": [{0.0: Vector3(0, 0, 0), 0.6: Vector3(-1.57, 0, 0), 1.2: Vector3(-1.57, 0, 0)}]}
	], false))
	_build_combat_animations(lib, root)

# ------------------------------------------------------------- GERADOR DE ANIMAÇÃO KEYFRAME
static func _make_anim(duration: float, tracks_data: Array, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = duration
	if loop:
		anim.loop_mode = Animation.LOOP_LINEAR

	for track_info in tracks_data:
		var node_path: String = track_info["path"]
		var keys: Array = track_info["keys"]
		var track_idx := anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(track_idx, NodePath(node_path))
		
		for key_dict in keys:
			for time_val in key_dict.keys():
				anim.track_insert_key(track_idx, float(time_val), key_dict[time_val])
	return anim

# Adiciona uma faixa somente se o membro existir no modelo importado. Isso
# permite a mesma animação funcionar em Base e Buggy sem warnings de path.
static func _append_part_rotation(tracks: Array, root: Node, part_name: String, keys: Dictionary) -> void:
	var part := root.find_child(part_name, true, false)
	if part:
		tracks.append({"path": str(root.get_path_to(part)) + ":rotation", "keys": [keys]})

# ----------------------------------------------- ANIMAÇÕES DE COMBATE CORPO A CORPO
# Gera as animações punching (Z), mmakick (X) e groundsmash (C) com rotações reais
# nos nós do modelo (UpperArm_R/L, Thigh_R/L, Torso, etc.) para funcionar no Voxel e Rig autêntico
static func _build_combat_animations(lib: AnimationLibrary, root: Node3D) -> void:
	# --- PUNCHING (Soco rápido frontal - 0.4s) ---
	var punch: Array = []
	_append_part_rot_multi(punch, root, ["Torso"], {0.0: Vector3(0, 0, 0), 0.15: Vector3(-0.15, 0.45, 0), 0.4: Vector3(0, 0, 0)})
	_append_part_rot_multi(punch, root, ["UpperArm_R", "RightArm"], {0.0: Vector3(0, 0, 0), 0.15: Vector3(-1.5, -0.3, 0), 0.25: Vector3(-1.5, -0.3, 0), 0.4: Vector3(0, 0, 0)})
	_append_part_rot_multi(punch, root, ["ForeArm_R"], {0.0: Vector3(0, 0, 0), 0.15: Vector3(-0.2, 0, 0), 0.4: Vector3(0, 0, 0)})
	_append_part_rot_multi(punch, root, ["UpperArm_L", "LeftArm"], {0.0: Vector3(0, 0, 0), 0.15: Vector3(-0.7, 0.4, -0.2), 0.4: Vector3(0, 0, 0)})
	lib.add_animation("punching", _make_anim(0.4, punch, false))

	# --- MMA KICK (Chute giratório potente - 0.6s) ---
	var kick: Array = []
	_append_part_rot_multi(kick, root, ["Torso"], {0.0: Vector3(0, 0, 0), 0.2: Vector3(0.35, -0.6, 0.35), 0.4: Vector3(0.35, -0.6, 0.35), 0.6: Vector3(0, 0, 0)})
	_append_part_rot_multi(kick, root, ["Thigh_R", "RightLeg"], {0.0: Vector3(0, 0, 0), 0.2: Vector3(-1.4, 0.5, -0.5), 0.4: Vector3(-1.4, 0.5, -0.5), 0.6: Vector3(0, 0, 0)})
	_append_part_rot_multi(kick, root, ["Shin_R"], {0.0: Vector3(0, 0, 0), 0.2: Vector3(0.3, 0, 0), 0.4: Vector3(0.3, 0, 0), 0.6: Vector3(0, 0, 0)})
	_append_part_rot_multi(kick, root, ["UpperArm_L", "LeftArm"], {0.0: Vector3(0, 0, 0), 0.2: Vector3(-0.5, 0, 0.8), 0.6: Vector3(0, 0, 0)})
	_append_part_rot_multi(kick, root, ["UpperArm_R", "RightArm"], {0.0: Vector3(0, 0, 0), 0.2: Vector3(-0.8, 0, -0.4), 0.6: Vector3(0, 0, 0)})
	lib.add_animation("mmakick", _make_anim(0.6, kick, false))

	# --- GROUND SMASH (Salto e impacto devastador de dois punhos no chão - 0.8s) ---
	var smash: Array = []
	_append_part_rot_multi(smash, root, ["Torso"], {0.0: Vector3(0, 0, 0), 0.3: Vector3(-0.45, 0, 0), 0.5: Vector3(0.75, 0, 0), 0.8: Vector3(0, 0, 0)})
	_append_part_rot_multi(smash, root, ["UpperArm_L", "LeftArm"], {0.0: Vector3(0, 0, 0), 0.3: Vector3(-2.6, -0.2, 0), 0.5: Vector3(0.4, 0.2, 0), 0.8: Vector3(0, 0, 0)})
	_append_part_rot_multi(smash, root, ["UpperArm_R", "RightArm"], {0.0: Vector3(0, 0, 0), 0.3: Vector3(-2.6, 0.2, 0), 0.5: Vector3(0.4, -0.2, 0), 0.8: Vector3(0, 0, 0)})
	_append_part_rot_multi(smash, root, ["Thigh_L", "LeftLeg"], {0.0: Vector3(0, 0, 0), 0.3: Vector3(0.2, 0, 0), 0.5: Vector3(-0.4, 0, 0), 0.8: Vector3(0, 0, 0)})
	_append_part_rot_multi(smash, root, ["Thigh_R", "RightLeg"], {0.0: Vector3(0, 0, 0), 0.3: Vector3(0.2, 0, 0), 0.5: Vector3(-0.4, 0, 0), 0.8: Vector3(0, 0, 0)})
	lib.add_animation("groundsmash", _make_anim(0.8, smash, false))

static func _append_part_rot_multi(tracks: Array, root: Node, part_names: Array[String], keys: Dictionary) -> void:
	for p_name in part_names:
		var part := root.find_child(p_name, true, false)
		if part:
			tracks.append({"path": str(root.get_path_to(part)) + ":rotation", "keys": [keys]})
			break

static func _apply_texture_to_meshes(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			# NÃO removemos mais triângulos "laterais". Aquela remoção (abs(x)>0.48)
			# abria buracos no casaco do Buggy e criava o efeito de tábuas
			# explodidas — o modelo é COERENTE quando só recebe a textura. Se um dia
			# for preciso enxugar o casaco, faça no modelo (Blender/geo), não rasgando
			# faces em runtime.
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.roughness = 0.7
			for i in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_texture_to_meshes(child, tex)

static func _print_node_tree(n: Node, prefix: String) -> void:
	print(prefix, "- ", n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		_print_node_tree(c, prefix + "  ")
