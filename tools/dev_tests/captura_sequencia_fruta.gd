extends SceneTree
# Captura em SEQUÊNCIA de técnicas de uma fruta do mod, com duas câmeras (por trás e de lado), para julgar projéteis, extensões e invocações a olho.
#   DISPLAY=:1 godot --path . -s tools/dev_tests/captura_sequencia_fruta.gd -- <fruta> <teclas ex.: N,X,C> <pasta> [distancia_do_alvo=12] [tempos ex.: 0.15,0.4,0.8,1.3]
const TEMPOS_PADRAO := [0.15, 0.4, 0.8, 1.3]
var j: Node3D
var alvo: Node3D
var cam_tras: Camera3D
var cam_lado: Camera3D
var cam_jogador: Camera3D
var saida := "/tmp/seq"

func quadros(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void:
	rodar.call_deferred()
func foto(nome: String, cam: Camera3D) -> void:
	cam.make_current()
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
func rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var fruta: String = a[0]
	var teclas: PackedStringArray = (a[1] if a.size() > 1 else "Z").split(",")
	saida = a[2] if a.size() > 2 else saida
	var dist := float(a[3]) if a.size() > 3 else 12.0
	var tempos: Array = []
	for t in (a[4] if a.size() > 4 else "").split(",", false): tempos.append(float(t))
	if tempos.is_empty(): tempos = TEMPOS_PADRAO
	DirAccess.make_dir_recursive_absolute(saida)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_seq.json")
	root.get_node("GameFlow").start_story()
	await quadros(200)
	j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.max_energy = 4000.0
	var av = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for cr in d.criterios: av.award(d, cr)
	await quadros(10)
	alvo = PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = Vector3(0, 1, -dist)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	cam_jogador = root.get_viewport().get_camera_3d()      # a mira do jogo usa ESTA câmera: devolvê-la a `current` antes de cada golpe
	cam_tras = Camera3D.new(); cam_tras.fov = 65.0
	cam_lado = Camera3D.new(); cam_lado.fov = 55.0
	current_scene.add_child(cam_tras); current_scene.add_child(cam_lado)
	modo.equipar_fruta(j, "")
	await quadros(5)
	modo.equipar_fruta(j, fruta)
	await quadros(20)
	for tecla in teclas:
		var c = j.get_node_or_null("FrutaMinePiece")
		if c == null or not c.fruta_ativa():
			print("sem controlador para ", tecla); continue
		if c.ativo: c.cancelar()
		c.recarga = 0.0
		for n in c.recargas.keys(): c.recargas[n] = 0.0
		if "_recargas" in c:
			for n in c._recargas.keys(): c._recargas[n] = 0.0
		j.energy = j.max_energy
		j.global_position = Vector3(0, 1, 0)
		j.velocity = Vector3.ZERO
		alvo.position = Vector3(0, 1, -dist)
		if OS.get_environment("CAM_PERTO") != "":       # vista próxima do jogador (efeitos de corpo: rosquinha giratória, tentáculos…)
			cam_tras.global_position = Vector3(0, 2.0, 4.2)
			cam_tras.look_at(Vector3(0, 1.0, 0.5), Vector3.UP)
		else:
			cam_tras.global_position = Vector3(0, 3.0, 7.0)
			cam_tras.look_at(Vector3(0, 1.5, -dist * 0.5), Vector3.UP)
		cam_lado.global_position = Vector3(dist * 0.9, 3.0, -dist * 0.5)
		cam_lado.look_at(Vector3(0, 1.5, -dist * 0.5), Vector3.UP)
		if is_instance_valid(cam_jogador):
			cam_jogador.make_current()
		await quadros(15)
		var t0 := Time.get_ticks_msec()
		await foto("%s_%s_pre_lado" % [fruta, tecla], cam_lado)      # linha de base: a mesma vista SEM o golpe (medida de visibilidade do projétil)
		cam_jogador.make_current()
		await quadros(3)
		c.usar_tecla(tecla, true)
		await quadros(20)
		c.usar_tecla(tecla, false)
		var t1 := Time.get_ticks_msec()
		for t in tempos:
			while (Time.get_ticks_msec() - t1) / 1000.0 < t:
				await process_frame
			await foto("%s_%s_%03d_tras" % [fruta, tecla, int(t * 100)], cam_tras)
			await foto("%s_%s_%03d_lado" % [fruta, tecla, int(t * 100)], cam_lado)
		await create_timer(2.0).timeout
	print("capturas em ", saida)
	quit()
