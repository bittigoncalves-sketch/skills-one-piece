extends SceneTree
## Fotos do Gorila-rei NO JOGO (modelo real, textura do Codex, avisos vermelhos, fúria). Weston isolado (docs/MODO_HISTORIA.md):
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . --script tools/dev_tests/capturar_gorila_rei.gd -- <pasta>
const Aviso := preload("res://src/historia/bosses/gorila_rei/aviso_vermelho.gd")
var saida := "res://art_src/validation/ilha_macacos/gorila_rei_jogo"


func q(n: int) -> void:
	for i in n:
		await physics_frame


func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(nome + ".png")))


func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_gorila.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_gorila.json"))
	root.get_node("GameFlow").start_story()
	await q(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var bib := MapaMontador.biblioteca_em_uso()
	var boss: AnimalDaIlha = load("res://src/historia/bosses/gorila_rei/gorila_rei_da_ilha.gd").new()
	boss.montar(bib, "gorila_rei", bib.ficha_de_animal("gorila_rei"), {"id": "g", "especie": "gorila_rei", "quantidade": 1, "centro": Vector3(0, 0, -20), "meio": Vector3(60, 30, 60), "base": Basis.IDENTITY, "ficha": bib.ficha_de_animal("gorila_rei")})
	boss.position = Vector3(0, 1.0, -20)
	boss.ponto_de_origem = boss.position
	current_scene.add_child(boss)
	boss._yaw = 0.0
	boss._visual.rotation.y = 0.0
	j.global_position = Vector3(0, 1, 40)
	await q(30)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.current = true
	cam.fov = 55
	var vistas := [["frente", Vector3(0, 4.5, -4), Vector3(0, 3, -20)], ["tres_quartos", Vector3(9, 5, -9), Vector3(0, 3, -20)], ["costas", Vector3(0, 5, -36), Vector3(0, 3, -20)], ["lado", Vector3(13, 4, -20), Vector3(0, 3, -20)]]
	for v in vistas:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await q(20)
		await foto("idle_" + v[0])
	# aviso do soco no chão, vista do alto-lado
	boss.combate.iniciar("soco_chao", j)
	cam.global_position = Vector3(10, 8, -9)
	cam.look_at(Vector3(0, 1.5, -17))
	await q(40)
	await foto("aviso_soco")
	await q(120)
	boss.combate.iniciar("pulo_esmagar", j)
	cam.global_position = Vector3(14, 10, 8)
	cam.look_at(Vector3(0, 1, 30))
	j.global_position = Vector3(0, 1, 30)
	await q(30)
	await foto("aviso_pulo")
	await q(150)
	boss.combate.iniciar("investida", j)
	cam.global_position = Vector3(12, 8, -6)
	cam.look_at(Vector3(0, 1, 0))
	await q(30)
	await foto("aviso_investida")
	await q(180)
	boss.health = boss.max_health * 0.5
	boss.estado = AnimalDaIlha.Estado.PERSEGUINDO
	boss.oponente = j
	await q(45)
	var b := boss.global_position
	print("FURIA boss em ", b, " estado ", boss.estado, " golpe ", boss.combate.golpe, " vivo ", boss.vivo())
	cam.global_position = b + Vector3(0, 3.6, 9.0)
	cam.look_at(b + Vector3(0, 3.8, 0))
	await q(5)
	await foto("furia_olhos_e_anel")
	print("CAPTURA_GORILA fotos -> ", saida)
	quit()
