extends SceneTree
## Capturas da Ilha do East Blue no mapa vivo (17/10/2026): uma vista aérea e uma por zona.
##   "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_ilha_east_blue.gd
## Saída: art_src/validation/east_blue/ilha_<zona>.png

const PASTA := "res://art_src/validation/east_blue"
const CENTRO := Vector3(3000, 0, 0)
const ZONAS := {
	"loguetown": Vector2(0, 0), "porto": Vector2(-150, 0), "ruivo": Vector2(-105, -65),
	"bandidos": Vector2(-125, -140), "alvida": Vector2(-5, -150), "shells_town": Vector2(120, -110),
	"orange_town": Vector2(150, 25), "vila_syrup": Vector2(105, 140), "baratie": Vector2(-25, 155),
	"arlong_park": Vector2(-135, 120),
}


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func _rodar() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://capturar_ilha_east_blue.json")
	root.get_node("GameFlow").start_story()
	await frames(240)
	var p: Node3D = get_first_node_in_group("player")
	# O jogador longe (no mar a oeste), para ninguém entrar em combate durante as fotos.
	p.global_position = CENTRO + Vector3(-260, 3, 0)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.far = 1500.0
	cam.global_position = CENTRO + Vector3(0, 260, 230)
	cam.look_at(CENTRO)
	await frames(30)
	await _foto("ilha_aerea")
	for zid in ZONAS:
		var c: Vector2 = ZONAS[zid]
		var alvo := CENTRO + Vector3(c.x, 2.0, c.y)
		cam.global_position = alvo + Vector3(-14, 9, 18)
		cam.look_at(alvo)
		await frames(20)
		await _foto("ilha_" + zid)
		# De perto: a 7 m do chefe da zona (o personagem mais perto do centro).
		var chefe: Node3D = null
		var menor := INF
		for pers in get_nodes_in_group("personagens_east_blue"):
			var d := (pers as Node3D).global_position.distance_to(alvo)
			if d < menor:
				menor = d
				chefe = pers
		if chefe != null:
			var frente := -chefe.global_transform.basis.z
			cam.global_position = chefe.global_position + frente * 6.0 + Vector3(2.0, 2.2, 0)
			cam.look_at(chefe.global_position + Vector3.UP * 1.2)
			await frames(5)
			await _foto("perto_" + zid)
	modo.set("progresso_forcado", "")
	quit()


func _foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [PASTA, nome])
