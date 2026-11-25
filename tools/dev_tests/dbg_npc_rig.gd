extends SceneTree
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	await process_frame
	var n := NpcDaIlha.new()
	n.tipo = "npc_treinador"
	root.add_child(n)
	await process_frame
	await process_frame
	var m: Node3D = n._rig.modelo()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var inst := mi as MeshInstance3D
		if inst.mesh == null: continue
		for s in inst.mesh.get_surface_count():
			var mat = inst.get_surface_override_material(s)
			if mat == null: mat = inst.material_override
			if mat == null: mat = inst.mesh.surface_get_material(s)
			if mat is BaseMaterial3D and mat.albedo_color.r > 0.55 and mat.albedo_color.g < 0.45:
				print("RED ", inst.get_path().get_concatenated_names().right(70), " surf ", s, " cor ", mat.albedo_color, " vis ", inst.is_visible_in_tree(), " y ", snappedf(inst.global_position.y - n.global_position.y, 0.01))
	quit()
