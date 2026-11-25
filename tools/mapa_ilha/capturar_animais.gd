extends SceneTree
# ============================================================================
#  CAPTURA DOS ANIMAIS — fotos com GPU de verdade (01/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_animais.gd -- \
#        [--saida res://art_src/validation/animais] [--so bird_2,eagle_-_animated_low_poly]
#
#  Monta o mapa vivo como o Modo História (MapaMontador + oceano + ambiente), solta a
#  `PopulacaoDeAnimais` e fotografa:
#    • cada espécie DE LADO, parada e apoiada, com a cápsula de 1,6 m do jogador ao
#      lado como régua (escala, pé no chão, frente para onde anda);
#    • vistas abertas (fazenda, vila, praia, covis dos chefes) com o LOD valendo.
#  Voador é fotografado DE BAIXO (como o jogador o vê): de perfil, um pássaro de
#  malha chata some. `--so` limita às espécies listadas e pula as vistas abertas.
#  Só LÊ o mapa.
# ============================================================================

const VISTAS_ABERTAS := [
	["00_fazenda", Vector3(150, 22, -112), Vector3(118, 4, -150)],
	["00_vila", Vector3(168, 14, 58), Vector3(138, 3, 22)],
	["00_praia_caranguejos", Vector3(90, 10, 222), Vector3(90, 0, 247)],
	["00_covil_gorila", Vector3(-170, 30, -100), Vector3(-205, 14, -118)],
	["00_covil_harpia", Vector3(-95, 45, -120), Vector3(-142, 35, -160)],
]

var saida := "res://art_src/validation/animais"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("A captura exige renderer real (rode sem --headless).")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	if args.find("--saida") >= 0:
		saida = args[args.find("--saida") + 1]
	var so: Array = []
	if args.find("--so") >= 0:
		so = args[args.find("--so") + 1].split(",")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = Vector2i(1280, 800)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var lido := MapaArquivo.carregar("res://mapas/historia/baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var raiz := MapaMontador.montar(mundo, mapa)
	var oceano: Node3D = load("res://src/world/oceano_historia.gd").new()
	mundo.add_child(oceano)
	oceano.configurar(mapa)
	var pop := PopulacaoDeAnimais.new()
	mundo.add_child(pop)
	pop.ligar(raiz, mapa, MapaMontador.biblioteca_em_uso())
	# "Jogador" de mentira: só um ponto que o LOD usa (vai junto com a câmera).
	var foco := Node3D.new()
	mundo.add_child(foco)
	pop.definir_jogador(foco)
	var regua := MeshInstance3D.new()
	var capsula := CapsuleMesh.new()
	capsula.radius = 0.5
	capsula.height = 1.6
	regua.mesh = capsula
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.6)
	regua.material_override = mat
	mundo.add_child(regua)
	var camera := Camera3D.new()
	camera.far = 3000.0
	mundo.add_child(camera)
	camera.make_current()
	for i in 30:
		await physics_frame
	print("ANIMAIS na cena: %d" % pop.animais.size())

	regua.visible = false
	for v in (VISTAS_ABERTAS if so.is_empty() else []):
		foco.global_position = v[2]
		pop.atualizar_detalhe()
		camera.position = v[1]
		camera.look_at(v[2])
		for i in 90:
			await physics_frame
		await _foto(v[0])

	# Uma de cada espécie, de lado, parada.
	var feitas := {}
	for a in pop.animais:
		if feitas.has(a.especie) or (not so.is_empty() and not so.has(a.especie)):
			continue
		feitas[a.especie] = true
		foco.global_position = a.global_position
		pop.atualizar_detalhe()
		for i in 40:
			await physics_frame
		a.estado = AnimalDaIlha.Estado.PARADO
		a.set("_relogio", 999.0)
		a.alvo = null
		for i in 50:
			await physics_frame
		var visual := a.get_node("Visual") as Node3D
		var lado := visual.global_transform.basis.x.normalized()
		var frente := visual.global_transform.basis.z.normalized()
		var h := maxf(a.altura(), 0.3)
		var dist := clampf(h * 3.2, 2.4, 26.0)
		var centro := a.global_position + Vector3.UP * h * 0.45
		# Régua ao lado (atrás do bicho, do ponto de vista da câmera), no chão.
		var p_regua := a.global_position - lado * maxf(h * 0.9, 1.0) - frente * maxf(h * 0.8, 1.2)
		var hit := mundo.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			p_regua + Vector3.UP * 60.0, p_regua + Vector3.DOWN * 60.0, 1, [a.get_rid()]))
		regua.visible = not FichaDeAnimal.voa(a.ficha)
		regua.global_position = (hit["position"] if not hit.is_empty() else p_regua) + Vector3.UP * 0.8
		if FichaDeAnimal.voa(a.ficha):
			camera.global_position = centro + lado * dist * 0.7 + frente * dist * 0.3 - Vector3.UP * dist * 0.8
		else:
			camera.global_position = centro + lado * dist + Vector3.UP * h * 0.25 + frente * dist * 0.15
		camera.look_at(centro)
		await _foto("%s_%s" % [a.ficha.get("comportamento", ""), a.especie])
	print("CAPTURA_ANIMAIS fotos=%d" % ((VISTAS_ABERTAS.size() if so.is_empty() else 0) + feitas.size()))
	quit()


func _foto(nome: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(nome + ".png")))
