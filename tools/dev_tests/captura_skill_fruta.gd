extends SceneTree
# Captura quadros de UM golpe de fruta do jogo (as 16 de SkillSystem) numa vista lateral
# e noutra por tras do jogador, para julgar o VFX a olho.
#
# Uso:
#   DISPLAY=:1 <godot> --path . -s tools/dev_tests/captura_skill_fruta.gd -- <fruta> <slot|todos> <pasta>
# Ex.: ... -- bomu_bomu Z /tmp/cap

const INSTANTES := [0.15, 0.4, 0.8, 1.4, 2.4]

var p: Node3D
var lateral: Camera3D
var traseira: Camera3D
var saida := "/tmp/cap_fruta"


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var fruta: String = a[0] if a.size() > 0 else "bomu_bomu"
	var slots: String = a[1] if a.size() > 1 else "Z"
	if a.size() > 2:
		saida = a[2]
	DirAccess.make_dir_recursive_absolute(saida)
	_executar.call_deferred(fruta, slots)


func _executar(fruta: String, slots: String) -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	for i in 180:
		await process_frame
	p = get_first_node_in_group("player")
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	p.set_meta("damage_immune", true)
	p.equip_fruit(fruta)
	for i in 30:
		await process_frame
	p._get_skills_container()
	lateral = Camera3D.new(); lateral.fov = 80.0      # largo: golpes que sobem (Entei, Mamaragan) saíam do quadro
	traseira = Camera3D.new(); traseira.fov = 70.0
	current_scene.add_child(lateral)
	current_scene.add_child(traseira)
	var lista: Array = ["Z", "X", "C", "V"] if slots == "todos" else [slots]
	for s in lista:
		await _golpe(fruta, s)
	print("capturas em ", saida)
	quit()


func _golpe(fruta: String, slot: String) -> void:
	var decl: Dictionary = SkillSystem.get_fruit_skills().get(fruta, {}).get(slot, {})
	if bool(decl.get("desabilitado", false)):
		print("%s desabilitado" % slot)
		return
	var base: Vector3 = p.global_position
	var alvo := BonecoDeDuelo.new()
	alvo.position = base + Vector3(0, 0.2, -7)
	current_scene.add_child(alvo)
	lateral.global_position = base + Vector3(8.5, 3.0, -3.0)      # mais perto (era 14 m): golpe pequeno ao redor do jogador não sumia no quadro
	lateral.look_at(base + Vector3(0, 2.6, -3.0), Vector3.UP)
	traseira.global_position = base + Vector3(0, 3.2, 6.5)
	traseira.look_at(base + Vector3(0, 1.5, -6), Vector3.UP)
	p._skill_cooldowns[slot] = 0.0
	await _foto("%s_%s_pre_lat" % [fruta, slot], lateral)      # linha de base (mesma vista, sem o golpe) para medir a visibilidade
	p.set_meta("is_casting", false)
	p._cast.abortar()
	p.lock_movement(0.0, "")
	p.energy = p.max_energy
	# Caminho REAL da tecla (como `test_frutas_acertam_npcs`): apertar, SEGURAR e soltar. `_fire_skill` direto pulava a carga e os golpes carregáveis
	# (Mera V, Goro X, Yami X) nem começavam — a medição de 15/11/2026 dava ~0% para eles por defeito do harness. O V segura 1,5 s; os outros, um toque.
	if fruta == "ope_ope" and slot != "Z":
		p.begin_charge("Z")
		await process_frame
		p.release_charge("Z")
		for i in 70: await physics_frame
		p._skill_cooldowns[slot] = 0.0
		p.energy = p.max_energy
	p.begin_charge(slot)
	for i in (90 if slot == "V" else 24): await physics_frame
	p.release_charge(slot)
	var t0 := Time.get_ticks_msec()
	for t in INSTANTES:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t:
			await process_frame
		await _foto("%s_%s_%03d_lat" % [fruta, slot, int(t * 100)], lateral)
		await _foto("%s_%s_%03d_tras" % [fruta, slot, int(t * 100)], traseira)
	await create_timer(5.0).timeout
	if is_instance_valid(alvo):
		alvo.queue_free()


func _foto(nome: String, cam: Camera3D) -> void:
	cam.make_current()
	await process_frame
	await process_frame
	get_root().get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
