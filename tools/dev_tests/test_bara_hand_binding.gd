extends SceneTree
## Sem arena/ENet: duas mãos reais, encaixe animado, reversão e troca de avatar.
const Binding := preload("res://src/characters/BaraHandBinding.gd")
class Fixture extends Node3D:
	var _char_model: Node3D

var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func _init() -> void:
	await process_frame
	var actor := Fixture.new()
	root.add_child(actor)
	actor._char_model = CharacterBuilder.build_character("base").node
	actor.add_child(actor._char_model)
	actor._char_model.scale = Vector3.ONE * 0.85
	actor.rotation.y = 0.5
	var binding := Binding.new()
	check(binding.setup(actor), "base: duas mãos anatômicas disponíveis")
	check(binding.setup(actor), "setup repetido preserva cache")
	check(actor._char_model.find_children("BaraDetachedHand*", "Node3D", true, false).size() == 2, "cache não duplica partes")
	for side in 2:
		var suffix := "L" if side == 0 else "R"
		var hand := actor._char_model.find_child("Hand_" + suffix, true, false) as Node3D
		var palm := hand.find_child("Geo_Palm_" + suffix + "_Runtime", true, false) as MeshInstance3D
		var wrist := hand.get_parent() as Node3D
		var origin := binding.socket(side)
		var destination := origin.translated(Vector3(0, 0, -3))
		binding.present(side, true, destination)
		var flying := actor._char_model.find_child("BaraDetachedHand" + suffix, true, false) as Node3D
		check(not palm.visible and flying.visible, "base " + suffix + ": mão única visível no voo")
		check(flying.global_transform.is_equal_approx(destination), "base " + suffix + ": transform global conserva escala/rotação")
		check(binding.socket(side).is_equal_approx(origin), "base " + suffix + ": encaixe permanece no corpo")
		wrist.rotation.x += 0.4
		check(not binding.socket(side).is_equal_approx(origin), "base " + suffix + ": encaixe acompanha animação durante voo")
		binding.present(side, false, Transform3D.IDENTITY)
		check(palm.visible and not flying.visible, "base " + suffix + ": retorno recoloca geometria")
		var copy := flying.find_child(str(palm.name), true, false) as MeshInstance3D
		check(copy.mesh == palm.mesh and copy.material_override == palm.material_override, "base " + suffix + ": mesmas malhas e materiais")
	binding.restore()
	var base_model := actor._char_model
	var visual := load("res://assets/models/bosses/buggy/buggy_boss_visual.tres") as CharacterVisualDefinition
	actor._char_model = visual.instantiate_visual().node
	actor.add_child(actor._char_model)
	actor._char_model.scale = Vector3.ONE * 1.53
	var source_left := actor._char_model.find_child("tripo_part_9", true, false) as MeshInstance3D
	var source_right := actor._char_model.find_child("tripo_part_8", true, false) as MeshInstance3D
	var original_left := source_left.mesh
	var original_right := source_right.mesh
	check(binding.setup(actor), "Buggy: troca recompõe base e prepara dois punhos")
	base_model.queue_free()
	await process_frame
	check(source_left.mesh != original_left and source_right.mesh != original_right, "Buggy: antebraços recebem derivados fechados")
	for side in 2:
		var suffix := "L" if side == 0 else "R"
		var attached := actor._char_model.find_child("BaraAttachedHand" + suffix, true, false) as MeshInstance3D
		var flying := actor._char_model.find_child("BaraDetachedHand" + suffix, true, false) as Node3D
		var rigid := flying.get_child(0) as MeshInstance3D
		var target := binding.socket(side).translated(Vector3(0, 0, -2))
		binding.present(side, true, target)
		check(not attached.visible and flying.visible, "Buggy " + suffix + ": nenhuma mão duplicada")
		check(flying.global_transform.is_equal_approx(target), "Buggy " + suffix + ": transformação preservada")
		check(attached.mesh.get_surface_count() == 2 and rigid.mesh.get_surface_count() == 2, "Buggy " + suffix + ": pele e tampa do punho")
		var attached_material := attached.mesh.surface_get_material(0) as StandardMaterial3D
		var rigid_material := rigid.mesh.surface_get_material(0) as StandardMaterial3D
		check(attached_material != null and rigid_material != null \
			and attached_material.albedo_texture == rigid_material.albedo_texture \
			and attached_material.albedo_color == rigid_material.albedo_color,
			"Buggy " + suffix + ": textura preservada no voo")
		binding.present(side, false, Transform3D.IDENTITY)
		check(attached.visible and not flying.visible, "Buggy " + suffix + ": retorno visível")
	binding.dispose()
	check(source_left.mesh == original_left and source_right.mesh == original_right, "dispose restaura exatamente malhas originais")
	await process_frame
	check(actor._char_model.find_children("Bara*Hand*", "Node3D", true, false).is_empty(), "dispose remove todos os nós temporários")
	actor._char_model.queue_free()
	actor._char_model = Node3D.new()
	actor.add_child(actor._char_model)
	check(not binding.setup(actor) and not binding.reason.is_empty(), "rig sem mãos informa indisponibilidade")
	binding.dispose()
	actor.queue_free()
	await process_frame
	print("BARA HAND BINDING checks=", checks, " failures=", failures)
	quit(0 if failures == 0 else 1)
