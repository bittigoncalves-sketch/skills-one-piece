extends SceneTree
## A LUTA NATIVA (A11, 30/10/2026): o Estilo de Combate Base (item "Luta") pelo controlador nativo, sem o Skills Builder. Z/X/C DIRETOS
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_treino_de_soco.gd
var p: Node3D
var boneco: Node3D
var treino
var prog
var passou := 0
var falhas := 0

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
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_treino_de_soco.json"))
	modo.set("progresso_forcado", "user://test_treino_de_soco.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	treino = current_scene.get_node("TreinoDeSoco")
	boneco = Node3D.new()
	boneco.name = "boneco_de_treino_t"
	current_scene.add_child(boneco)
	boneco.global_position = Vector3(0, 0, -5)
	p.global_position = Vector3(0, 1, 0)
	await frames(10)
	print("DBG antes yaw=", p._yaw, " modelo.rot.y=", p._char_model.rotation.y)
	treino.pedir_inicio()
	await frames(60)
	print("DBG viewport ", root.get_viewport().get_visible_rect().size)
	for r in [treino._rotulo_contagem, treino._caixa, treino._rotulo_feedback]:
		print("DBG ", r.name, " pos=", r.global_position, " size=", r.size, " text=", r.get("text"))
	quit()
