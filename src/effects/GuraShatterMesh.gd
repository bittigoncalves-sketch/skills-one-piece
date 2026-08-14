class_name GuraShatterMesh
extends Node
## Gera um mesh 3D procedural usando SurfaceTool que simula o ar "rachando" no impacto.
## É instanciado nos ataques da Gura Gura no Mi.

static func spawn(parent: Node, pos: Vector3, scale_factor: float = 1.0) -> void:
	var mi := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	
	# Cor ciano/branco da Gura Gura
	var color := Color(0.85, 0.94, 1.0, 1.0)
	
	# Gera vértices aleatórios a partir do centro para simular rachaduras (teia de aranha radial)
	var num_cracks := 8
	var max_radius := 3.0 * scale_factor
	
	for i in range(num_cracks):
		var angle = (float(i) / num_cracks) * TAU + randf_range(-0.2, 0.2)
		var current_pos = Vector3.ZERO
		var crack_length = randf_range(0.5, 1.0) * max_radius
		
		var segments = 4
		for j in range(segments):
			var next_radius = (float(j + 1) / segments) * crack_length
			var offset = Vector3(
				cos(angle) * next_radius + randf_range(-0.3, 0.3) * scale_factor,
				randf_range(-0.3, 0.3) * scale_factor,
				sin(angle) * next_radius + randf_range(-0.3, 0.3) * scale_factor
			)
			
			st.set_color(color)
			st.add_vertex(current_pos)
			st.set_color(color)
			st.add_vertex(offset)
			
			current_pos = offset
			
	mi.mesh = st.commit()
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mi.material_override = mat
	
	mi.global_position = pos
	parent.add_child(mi)
	
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.5, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tw.set_parallel(false)
	tw.tween_callback(mi.queue_free)
