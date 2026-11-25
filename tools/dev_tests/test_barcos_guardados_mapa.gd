extends SceneTree
## Montagem do mapa real, sem servidor nem progresso pessoal. Conferência de
## barcos estacionados e cavalo guardado; captura opcional com -- <pasta>.
const Comando := preload("res://src/historia/navios/comando.gd")
const Companhia := preload("res://src/historia/pets/companhia.gd")
const Oceano := preload("res://src/world/oceano_historia.gd")
var falhas := 0

func _init() -> void:
	_executar.call_deferred()

func _ok(condicao: bool, mensagem: String) -> void:
	print(("PASS " if condicao else "❌ ") + mensagem)
	if not condicao:
		falhas += 1

func _executar() -> void:
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var mundo := Node3D.new()
	root.add_child(mundo)
	var raiz := MapaMontador.montar(mundo, mapa)
	var mar := Oceano.new()
	mundo.add_child(mar)
	mar.configurar(mapa)
	AguaDoMundo.registrar(mapa, mar)
	var bib := MapaMontador.biblioteca_em_uso()
	var companhia := Companhia.new()
	companhia.progressao = ProgressaoDoPersonagem.new()
	mundo.add_child(companhia)
	companhia.ligar_no_mapa(raiz, mapa, bib)
	var nav := Comando.new()
	mundo.add_child(nav)
	nav.ligar_no_mapa(raiz, mapa, bib)
	# 10/10/2026 (pedido do dono): nenhum barco no mapa; a frota é a comprada no vendedor
	# do porto e atraca ao lado dele ao abrir o jogo.
	_ok(nav.barcos.is_empty(), "mapa vivo não tem barcos (%d)" % nav.barcos.size())
	var npcs := NpcsDaIlha.new()
	mundo.add_child(npcs)
	npcs.ligar_no_mapa(raiz, mapa, bib)
	var dono := ProgressaoDoPersonagem.new()
	dono.barcos = {"boat": true, "small_ship": true, "ship": true}
	await nav.ligar_frota(dono)
	_ok(nav.barcos.size() == 3, "a frota comprada atraca no cais do vendedor (%d)" % nav.barcos.size())
	var poses: Array[Transform3D] = []
	for b in nav.barcos:
		poses.append(b.global_transform)
		_ok(not b.is_physics_processing(), "%s inicia sem simulação" % b.name)
	var cavalos := 0
	for id in companhia.progressao.pets:
		if companhia.progressao.especie_do_pet(id) == "cavalo_da_vila_leve":
			cavalos += 1
	_ok(cavalos == 1 and companhia.quantos_fora() == 0, "mapa real concede um cavalo guardado")
	_ok(raiz.get_node_or_null(NodePath(Companhia.CAVALO_DA_VILA)) == null, "cavalo não cria corpo seguidor no mapa")
	for i in 180:
		await physics_frame
	for i in nav.barcos.size():
		var b := nav.barcos[i]
		_ok(b.global_transform.is_equal_approx(poses[i]) and b.velocity.is_zero_approx() and b._esteira._malha.get_surface_count() == 0, "%s permanece parado e sem espuma" % b.name)
	var args := OS.get_cmdline_user_args()
	if not args.is_empty() and DisplayServer.get_name() != "headless":
		var ambiente := WorldEnvironment.new()
		ambiente.environment = Environment.new()
		ambiente.environment.background_mode = Environment.BG_COLOR
		ambiente.environment.background_color = Color(.44,.68,.88)
		ambiente.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		ambiente.environment.ambient_light_color = Color(.78,.84,1)
		ambiente.environment.ambient_light_energy = .7
		mundo.add_child(ambiente)
		var sol := DirectionalLight3D.new()
		sol.rotation_degrees = Vector3(-48,-30,0)
		mundo.add_child(sol)
		var cam := Camera3D.new()
		mundo.add_child(cam)
		cam.position = Vector3(337,28,66)
		cam.look_at(Vector3(288,2,29))
		cam.make_current()
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(args[0])
		root.get_texture().get_image().save_png(args[0].path_join("barcos_estacionados.png"))
	AguaDoMundo.esquecer()
	mundo.free()
	print("BARCOS_GUARDADOS_MAPA falhas=", falhas)
	quit(1 if falhas else 0)
