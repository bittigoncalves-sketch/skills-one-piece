extends SceneTree
# Captura (com GPU) das PARTÍCULAS pedidas por COMANDO (`particle …`) pelas procedures do mod, uma por foto,
# com o mesmo comando em texto que o mod usa; e toca o som do `playsound` para provar que há áudio carregado.
#
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_comandos_mine_piece.gd -- <pasta>

const COMANDOS := [
	"particle minecraft:cloud ~ ~1.2 ~ 0.5 0.5 0.5 0.1 20",
	"particle minecraft:explosion ~ ~1.2 ~ 0 0 0 0 1",
	"particle minecraft:flash ~ ~1.2 ~ 0 0 0 0 1",
	"particle minecraft:flame ~ ~1 ~ 0.4 0.4 0.4 0.05 30",
	"particle minecraft:large_smoke ~ ~1 ~ 0.4 0.4 0.4 0.05 20",
	"particle dust 1 0.2 0 2 ~ ~1.2 ~ 0.4 0.4 0.4 0 40",
	"particle minepiece:particle_thunder_black ~ ~1.2 ~ 0.5 0.5 0.5 0.2 20",
	"particle minepiece:particle_flame ~ ~1 ~ 0.4 0.4 0.4 0.05 30",
	"particle minepiece:particle_big_smoke ~ ~1 ~ 0.4 0.4 0.4 0.05 15",
	"particle minepiece:particle_thunder_blue ~ ~1.2 ~ 0.5 0.5 0.5 0.2 20",
	"particle minepiece:particle_flash_red ~ ~1.2 ~ 0 0 0 0 1 force",
	"particle minepiece:particle_flower_pink ~ ~1.5 ~ 0.6 0.4 0.6 0.02 30",
	"particle minepiece:particle_ice ~ ~1.2 ~ 0.5 0.5 0.5 0.05 30",
	"particle minepiece:particle_fire_fly ~ ~1.2 ~ 0.6 0.6 0.6 0.02 20",
]
var saida := "/tmp/cmd_mp"
var cam: Camera3D


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])


func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://captura_cmd_mp.json")
	root.get_node("GameFlow").start_story()
	await quadros(150)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.global_position = Vector3(0, 1, 9)
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	# O boneco de referência (1,8 bloco) dá a escala da partícula; fica parado, sem IA.
	var ref := PersonagemMinePiece.new()
	ref.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	ref.position = Vector3(0, 1, 0)
	ref.ponto_de_origem = ref.position
	ref.set_meta("mc_sem_ia", true)
	current_scene.add_child(ref)
	await quadros(10)
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 45
	cam.current = true
	cam.global_position = Vector3(0, 1.6, -4.2)
	cam.look_at(Vector3(0, 1.1, 0), Vector3.UP)
	var ent := McEntidade.de(ref)
	var mundo := Mc.mundo(self)
	var fonte := McComandos.Fonte.new()
	fonte.mundo = mundo
	fonte.entidade = ent
	fonte.posicao = ent.position()
	var i := 0
	for c: String in COMANDOS:
		var feitos := McComandos.executar(fonte, c)
		print("CMD %02d -> %d  %s" % [i, feitos, c])
		await quadros(10)
		await foto("%02d" % i)
		await quadros(50)
		i += 1
	for s in ["entity.wither.spawn", "minepiece:punch", "ui.toast.challenge_complete"]:
		print("SOM ", s, " -> ", McComandos.executar(fonte, "playsound %s master @a" % s))
	await quadros(5)
	var players := 0
	for n in root.get_children():
		if n is AudioStreamPlayer3D:
			players += 1
	print("AUDIO players ativos: ", players)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit()
