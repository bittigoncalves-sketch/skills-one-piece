extends SceneTree
# Captura (com GPU) das animações do mod no corpo do JOGADOR: um clipe por foto, no meio do clipe.
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_animacao_do_mod.gd -- <pasta> [clipe …]
const PADRAO := ["both_arm_up", "both_arm_front", "punch_right", "kick_right", "guard", "sword_to_right", "punch_gomu_pistol1", "gear_2"]
var saida := "/tmp/anim_mp"

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred(a.slice(1) if a.size() > 1 else PADRAO)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])

func _rodar(clipes: Array) -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_animacao_mp.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var ej := McEntidade.de(jogador)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 40
	cam.current = true
	var base: Vector3 = jogador.global_position
	cam.global_position = base + Vector3(-2.2, 1.3, -3.4)
	cam.look_at(base + Vector3(0, 0.8, 0), Vector3.UP)
	await quadros(30)
	await foto("00_repouso")
	var i := 1
	for c: String in clipes:
		var dur := PoseDoMod.duracao(c)
		McRede.instancia().send(null, Mc.novo(&"MinepieceModAnimationMessage", [c, ej.getId(), true]))
		var no: AnimacaoDoMod = jogador.get_node("AnimacaoDoMod")
		no.tempo = minf(dur * 0.6, 2.0)      # meio do clipe (clipes longos: 2 s)
		no.peso = 1.0
		await quadros(2)
		no.tempo = minf(dur * 0.6, 2.0)
		await foto("%02d_%s" % [i, c])
		no.parar()
		await quadros(20)
		i += 1
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
