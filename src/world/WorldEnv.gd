class_name WorldEnv
extends RefCounted
# Ambiente do mundo: iluminação solar vibrante estilo anime + céu azul e limpo.

static func apply(parent: Node) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -135, 0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	parent.add_child(sun)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	
	# Céu azul vibrante estilo One Piece / Anime
	sky_mat.sky_top_color = Color(0.18, 0.52, 0.92)
	sky_mat.sky_horizon_color = Color(0.62, 0.82, 0.98)
	sky_mat.ground_bottom_color = Color(0.15, 0.32, 0.22)
	sky_mat.ground_horizon_color = Color(0.52, 0.72, 0.85)

	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	
	# Fog leve e cristalino (sem parede cinza)
	env.fog_enabled = false

	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
