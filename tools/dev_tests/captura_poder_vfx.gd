extends SceneTree
## Captura das 6 camadas do HTCS (`PoderVfx`) no Modo História. DISPLAY=:1 godot --path . -s tools/dev_tests/captura_poder_vfx.gd -- <pasta>
var saida := "/tmp/poder_vfx"
func _init() -> void:
	rodar.call_deferred()
func q(n: int) -> void:
	for i in n:
		await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(saida + "/" + nome + ".png")
func rodar() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_poder.json"))
	modo.set("progresso_forcado", "user://captura_poder.json")
	root.get_node("GameFlow").start_story()
	await q(150)
	var j: Node3D = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var frente := Vector3(0, 0, -1)
	var onde := j.global_position + frente * 6.0
	var cor := Color(0.7, 0.3, 1.0)
	# 1 carga no corpo inteiro e na mão
	PoderVfx.carga(j, j, Vector3(0, 1.0, 0), cor, 1.2, 1.6, 36)
	await q(40); await foto("1_carga")
	await q(40)
	# 2 feixe
	PoderVfx.feixe(j, j.global_position + Vector3(0, 1.2, -0.5), onde + Vector3(0, 1.2, 0), cor, 0.6, 0.6)
	await q(8); await foto("2_feixe")
	# 4/5/6 golpe: impacto + solo + tremor
	PoderVfx.golpe(j, onde, cor, 3.0, 0.9, PoderVfx.Forma.QUADRADO)
	await q(4); await foto("3_impacto_a")
	await q(14); await foto("3_impacto_b")
	await q(40); await foto("3_impacto_c")
	await q(120)
	PoderVfx.golpe(j, onde, Color(1, 0.6, 0.2), 3.0, 0.9, PoderVfx.Forma.TRIANGULO)
	await q(14); await foto("4_triangulo")
	# 3 rastro seguindo um nó que se move
	var pt := Node3D.new()
	current_scene.add_child(pt)
	pt.global_position = j.global_position + Vector3(-2, 1.5, -3)
	PoderVfx.rastro(j, pt, cor, 0.5, 0.8)
	for i in 30:
		pt.global_position += Vector3(0.15, 0.03 * sin(i * 0.4), 0.0)
		await q(1)
	await foto("5_rastro")
	quit()
