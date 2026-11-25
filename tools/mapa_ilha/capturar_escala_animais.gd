extends SceneTree
# ============================================================================
#  ESCALA DOS ANIMAIS x PERSONAGEM — fotos lado a lado (01/10/2026).
#
#    "$(./find_godot.sh)" --path . --script tools/mapa_ilha/capturar_escala_animais.gd -- [--saida res://art_src/validation/escala_animais]
#
#  Pedido do dono: "o tamanho de alguns animais está incoerente em relação ao jogador".
#  Abre o Modo História, monta um palco plano no céu (fundo limpo) e põe o PERSONAGEM
#  DE VERDADE (o modelo, não a cápsula) no meio de cada grupo de animais — os animais
#  como no jogo (`AnimalDaIlha`, parados e animados). Imprime a tabela de alturas.
# ============================================================================

const PALCO_Y := 400.0
const GRUPOS := [
	["01_grandes", ["cow", "horse", "bufalo", "bizon", "bear", "deer", "deer-blt2gjhppt"]],
	["02_medios", ["sheep", "sheep_-_animated_low_poly", "pelican_-_animated_low_poly", "monkey_-_animated_low_poly", "fox", "caranguejo_grande"]],
	["03_caes_e_gato", ["beagle", "corgi", "dog", "dog-9bqpcxoyrk", "dog_final_", "cat"]],
	["04_pequenos", ["chicken", "chick", "duck", "rabbit", "frog", "lizard"]],
	["05_aves", ["bird_2", "bird-h5izaudltz", "eagle_-_animated_low_poly"]],
	["06_chefes", ["gorilla_-_animated_low_poly", "harpia_-_animated_low_poly"]],
]
const PROGRESSO := "user://escala_animais_progresso.json"
var saida := "res://art_src/validation/escala_animais"


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(saida))
	root.size = Vector2i(1600, 800)
	var modo_script: Script = load("res://src/historia/ModoHistoria.gd")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo_script.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 160:
		await process_frame
	var modo := current_scene
	var hud: Node = modo.get("_hud")
	hud.set("visible", false)
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var bib := MapaMontador.biblioteca_em_uso()
	# Palco: chão plano e cinza claro, com colisão.
	var palco := StaticBody3D.new()
	palco.name = "PalcoDeEscala"
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(400, 1, 60)
	forma.shape = caixa
	palco.add_child(forma)
	var malha := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = caixa.size
	malha.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#c9c4b6")
	malha.material_override = mat
	palco.add_child(malha)
	modo.add_child(palco)
	palco.global_position = Vector3(0, PALCO_Y - 0.5, 0)
	var camera := Camera3D.new()
	camera.fov = 40.0
	modo.add_child(camera)
	camera.make_current()
	# Altura do MODELO do personagem (o que se vê), não da cápsula.
	jogador.global_position = Vector3(0, PALCO_Y + 1.0, 0)
	jogador.velocity = Vector3.ZERO
	for i in 40:
		await physics_frame
	var h_jogador := _altura_visivel(jogador, jogador.global_position.y - 0.8)
	print("JOGADOR modelo visível %.2f m (cápsula 1,60)" % h_jogador)
	var x0 := -150.0
	for g in GRUPOS:
		var nome: String = g[0]
		var ids: Array = g[1]
		var animais: Array[AnimalDaIlha] = []
		var x := x0
		var meio := ids.size() / 2
		for i in ids.size():
			if i == meio:
				jogador.global_position = Vector3(x + 0.6, PALCO_Y + 1.0, 0)
				x += 2.0
			var id: String = ids[i]
			var a := AnimalDaIlha.new()
			a.montar(bib, id, bib.ficha_de_animal(id), {})
			modo.add_child(a)
			var largura := maxf(a.tamanho_da_hitbox().z / 1.3, a.tamanho_da_hitbox().x / 1.3)
			a.global_position = Vector3(x + largura * 0.5, PALCO_Y + (8.0 if FichaDeAnimal.voa(a.ficha) else 0.2), 0)
			a.estado = AnimalDaIlha.Estado.PARADO
			a.set("_relogio", 9999.0)
			a.set("_yaw", PI * 0.5)        # de lado para a câmera (olham para +X)
			animais.append(a)
			x += largura + 1.0
		jogador.velocity = Vector3.ZERO
		for i in 60:
			await physics_frame
		for a in animais:
			if FichaDeAnimal.voa(a.ficha):
				a.global_position.y = PALCO_Y + 0.6        # voador pousado ao lado, para comparar
			a.set_physics_process(false)
			a.animador.animar(0.016, Vector3.ZERO, float(a.ficha.get("passeio", 1.0)),
				float(a.ficha.get("corrida", 4.0)), "parado", 0.0)   # como `animal_da_ilha.gd` (assinatura de 04/10)
			print("ANIMAL %-28s %-22s altura %.2f m  comprimento %.2f m  (%.0f%% do personagem)" % [a.especie,
				a.nome_de_exibicao(), a.altura(), a.get("_comprimento"), a.altura() / h_jogador * 100.0])
		var centro := Vector3((x0 + x) * 0.5, PALCO_Y + 1.2, 0)
		var largura_total := x - x0
		camera.global_position = centro + Vector3(0, 0.6, maxf(largura_total * 1.25, 7.0))
		camera.look_at(centro)
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path(saida.path_join(nome + ".png")))
		print("FOTO %s" % nome)
		for a in animais:
			a.queue_free()
		x0 = x + 30.0
	modo_script.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	quit()


## Altura das malhas visíveis do personagem acima do chão do palco.
func _altura_visivel(no: Node3D, chao: float) -> float:
	var topo := -INF
	for mi: MeshInstance3D in no.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var c := mi.global_transform * mi.get_aabb()
		topo = maxf(topo, c.end.y)
	return topo - chao
