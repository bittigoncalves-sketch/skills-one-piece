extends SceneTree
## Renderiza o base_v2 em IDLE e WALK, com e sem a camada RigDetalhado.
## godot --path . --display-server x11 -s tools/dev_tests/_probe_render.gd
const DT := 1.0 / 60.0
var cam: Camera3D

func _init() -> void:
	await process_frame
	var mundo := Node3D.new()
	root.add_child(mundo)
	var luz := DirectionalLight3D.new()
	luz.rotation_degrees = Vector3(-42, -145, 0)
	luz.light_energy = 1.5
	mundo.add_child(luz)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.85
	amb.environment = env
	mundo.add_child(amb)
	cam = Camera3D.new()
	mundo.add_child(cam)

	for caso in [["idle", Vector3.ZERO, false, 4.0], ["walk", Vector3(0,0,-4.2), false, 6.0]]:
		for detalhe in [false, true]:
			var d := CharacterBuilder.build_character("base")
			var m: Node3D = d["node"]
			mundo.add_child(m)
			var ab := PlayerModelKit.model_aabb(m)
			var ky: float = 1.5 / ab.size.y
			m.scale = Vector3(ky, ky, ky)
			m.position = Vector3(0, -ky * ab.position.y, 0)
			await process_frame
			var prof := BodyScanner.scan(m)
			if not detalhe:
				for r in prof.nodes.keys():
					if not BodyScanner.ROLES.has(r):
						prof.nodes.erase(r); prof.rest.erase(r)
			var anim := ProceduralAnimator.new()
			m.add_child(anim)
			anim.setup(prof)
			var quadros: int = int(float(caso[3]) / DT)
			for i in quadros:
				anim.update(caso[1], true, false, DT, 0.0, caso[2])
			var tag: String = "novo" if detalhe else "antes"
			# FRENTE do personagem = -Z, então a câmera vai para -Z. 3/4 à esquerda.
			for fase in 4:
				if fase > 0:
					for i in 9:                     # ~1/4 de ciclo do walk
						anim.update(caso[1], true, false, DT, 0.0, caso[2])
				cam.position = Vector3(1.35, 1.02, -2.15)
				cam.look_at(Vector3(0, 0.72, 0), Vector3.UP)
				cam.fov = 42
				await _capture("ab_%s_%s_%d.png" % [caso[0], tag, fase])
			# close de frente nas mãos e nos pés
			cam.position = Vector3(0.80, 0.55, -1.15)
			cam.look_at(Vector3(0, 0.38, 0), Vector3.UP)
			await _capture("ab_%s_%s_perto.png" % [caso[0], tag])
			m.queue_free()
			await process_frame
	quit()

func _capture(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png("res://art_src/previews/" + nome)
	print("CAPTURA ", nome)
