extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/captura_treino.gd
var p: Node3D
var boneco: Node3D
var treino
var prog
var passou := 0
var falhas := 0

const SAIDA := "res://art_src/validation/treino/"
func foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SAIDA + nome + ".png"))

func tecla_letra(letra: String) -> void:
	tecla(OS.find_keycode_from_string(letra), true)
	await frames(1)
	tecla(OS.find_keycode_from_string(letra), false)

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://captura_treino.json"))
	modo.set("progresso_forcado", "user://captura_treino.json")
	root.get_node("GameFlow").start_story()
	for i in 1800:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get_node_or_null("TreinoDeSoco") != null:
			break
	await frames(60)
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAIDA))
	treino = current_scene.get_node("TreinoDeSoco")
	p.global_position = Vector3(29.43, 5.5, -7.5)
	await frames(240)
	var achou: Array = current_scene.find_children("boneco_de_treino*", "Node3D", true, false)
	print("BONECOS ", achou.size(), " fantasma ", p.global_position)
	await foto("0_antes")
	var erro: String = treino.pedir_inicio()
	print("INICIO ", erro)
	await frames(50)
	await foto("1_prompt")
	var ordem := ["Z", "X", "C", "Z", "X", "C"]
	var i := 0
	var guarda := 0
	while treino.fase != 4 and treino.fase != 0 and guarda < 3000:
		guarda += 1
		if treino.fase == 2:
			var letra: String = treino.tecla_atual
			await tecla_letra(letra)
			await frames(5)
			await foto("golpe_%d_%s" % [i, letra])
			await frames(4)
			await foto("golpe_%d_%s_b" % [i, letra])
			i += 1
		else:
			await physics_frame
	await frames(20)
	await foto("9_fim")
	await frames(200)
	await foto("10_depois")
	modo.set("progresso_forcado", "")
	print("CAPTURA_TREINO ok")
	quit(0)
