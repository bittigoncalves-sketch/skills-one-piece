extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/captura_instrutor.gd
var p: Node3D
var boneco: Node3D
var treino
var prog
var passou := 0
var falhas := 0

const SAIDA := "res://art_src/validation/dialogo_cinematografico/"
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + nome + ".png"))

func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _rodar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_instrutor.json"))
	modo.set("progresso_forcado", "user://captura_instrutor.json")
	root.get_node("GameFlow").start_story()
	for i in 1800:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get_node_or_null("TreinoDeSoco") != null:
			break
	await frames(60)
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	p.global_position = Vector3(27.0, 6.0, -8.0)
	await frames(240)
	var instrutor: Node3D = null
	for n in current_scene.find_children("*", "NpcDaIlha", true, false):
		if n.tipo == "npc_treinador":
			instrutor = n
	var alvo := instrutor.global_position
	var frente := -instrutor.global_basis.z                                    # para onde o instrutor olha
	var cam := Camera3D.new()
	cam.fov = 38.0
	current_scene.add_child(cam)
	cam.make_current()
	p.global_position = alvo + Vector3(0, 30.0, 0)       # tira o jogador do quadro
	var quadros := [["anim_guarda", 1.0], ["anim_jab_esq", 5.15], ["anim_jab_dir", 5.77], ["anim_aponta", 9.0], ["anim_gancho", 12.2]]
	for q in quadros:
		var dir := frente.rotated(Vector3.UP, 0.8)
		cam.global_position = alvo + dir * 4.2 + Vector3(0, 1.2, 0)
		cam.look_at(alvo + Vector3(0, 0.95, 0), Vector3.UP)
		instrutor.set("_relogio", float(q[1]))
		await frames(12)
		instrutor.set("_relogio", float(q[1]))
		await frames(2)
		await foto(String(q[0]))
	# Ao lado do jogador, para comparar a altura.
	p.global_position = alvo + frente * 1.4 + frente.rotated(Vector3.UP, PI / 2.0) * 1.0
	cam.global_position = alvo + frente * 5.0 + Vector3(0, 1.3, 0)
	cam.look_at(alvo + Vector3(0, 0.9, 0), Vector3.UP)
	instrutor.set("_relogio", 1.0)
	await frames(60)
	await foto("anim_altura_ao_lado_do_jogador")
	print("CAPTURA_FALA ok")
	quit(0)
