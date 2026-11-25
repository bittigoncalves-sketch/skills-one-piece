extends SceneTree
# ============================================================================
#  CAPTURA — recifes no jogo de verdade (14/10/2026, docs/MAR_HISTORIA_PLANO.md, E2).
#  Precisa de GPU (sem --headless). Abre uma janela; o mouse é solto.
#
#    "$(./find_godot.sh)" --path . --script tools/dev_tests/capturar_recifes.gd -- --rotulo=e2
#
#  Modo História com o MAPA VIVO (só leitura) e progresso de TESTE. Acha pelo próprio
#  `RelevoMarinho` o miolo de recife mais denso perto da ilha inicial e fotografa: perto,
#  aberto e de cima; depois uma VITRINE com as espécies lado a lado na areia (nós
#  temporários, só nesta captura). Fotos em art_src/validation/mar/recifes_<rotulo>_*.png.
# ============================================================================

const PROGRESSO := "user://capturar_recifes_progresso.json"
const PASTA := "res://art_src/validation/mar"

var rotulo := "e2"


func _initialize() -> void:
	_executar.call_deferred()


func _executar() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rotulo="):
			rotulo = a.trim_prefix("--rotulo=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	root.size = Vector2i(1280, 720)
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://mapas/historia/baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	for i in 200:
		await process_frame
	var jogador: CharacterBody3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	var mar := current_scene.get_node_or_null("Mar")
	if jogador == null or mar == null:
		push_error("sem jogador ou sem Mar")
		quit(1)
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	jogador.set_meta("damage_immune", true)
	var relevo: RelevoMarinho = mar.get("relevo")
	var recifes: Node3D = mar.get("recifes")
	# Miolo de recife: maior soma da máscara num raio de 12 m, na plataforma leste/norte.
	var melhor := Vector2.ZERO
	var nota := -1.0
	for x in range(300, 420, 6):
		for z in range(-240, 240, 6):
			var soma := 0.0
			for k in 8:
				var o := Vector2(12, 0).rotated(k * TAU / 8.0)
				soma += relevo.recife(x + o.x, z + o.y)
			soma += relevo.recife(x, z) * 2.0
			if soma > nota:
				nota = soma
				melhor = Vector2(x, z)
	print("RECIFE miolo em %s (nota %.2f, profundidade %.1f m)" % [melhor, nota, relevo.profundidade(melhor.x, melhor.y)])
	recifes.call("montar_em_volta", melhor, 160.0)
	var cardumes: Node3D = mar.get("cardumes")
	if cardumes != null:
		cardumes.call("montar_em_volta", melhor, 110.0)
		print("RECIFE cardumes montados: %d" % int(cardumes.call("cardumes_montados")))
	var fundo := relevo.altura(melhor.x, melhor.y)
	# perto: 9 m a oeste do miolo, 3 m acima do fundo, olhando para ele
	await _foto(jogador, Vector3(melhor.x - 9.0, fundo + 3.0, melhor.y), -PI / 2.0, -0.25, "perto")
	await _foto(jogador, Vector3(melhor.x - 22.0, minf(fundo + 6.0, relevo.nivel - 1.5), melhor.y + 6.0), -PI / 2.0, -0.3, "aberto")
	await _foto(jogador, Vector3(melhor.x, minf(fundo + 12.0, relevo.nivel - 1.5), melhor.y + 4.0), 0.0, -1.2, "olhando_para_cima")
	# Areia rasa vista de cima (cáusticas, E7), com câmera própria: a de terceira pessoa
	# não obedece a ângulos extremos de forma previsível.
	var livre := Camera3D.new()
	current_scene.add_child(livre)
	var alvo := Vector3(melhor.x - 16.0, relevo.altura(melhor.x - 16.0, melhor.y), melhor.y)
	livre.global_position = alvo + Vector3(-3.0, 3.2, 0.5)
	livre.look_at(alvo, Vector3.UP)
	livre.make_current()
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join("recifes_%s_areia_de_cima.png" % rotulo)))
	print("RECIFE foto areia_de_cima em %s" % livre.global_position)
	livre.queue_free()
	# Vitrine: as espécies em fila na areia, num ponto plano sem recife.
	var areia := Vector2(melhor.x + 40.0, melhor.y)
	for tentativa in 40:
		if relevo.recife(areia.x, areia.y) < 0.02 and relevo.amostra(areia.x, areia.y).y < 0.2:
			break
		areia += Vector2(0, 7)
	var y0 := relevo.altura(areia.x, areia.y)
	var vitrine := Node3D.new()
	current_scene.add_child(vitrine)
	var especies: Array = recifes.get("ESPECIES").keys()
	var malhas: Dictionary = recifes.get("_malhas")
	var materiais: Dictionary = recifes.get("_materiais")
	for k in especies.size():
		var nome: String = especies[k]
		for v in 2:                                # duas paletas por espécie
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = malhas[nome]
			mm.instance_count = 1
			var x := areia.x + (k - especies.size() * 0.5) * 1.9
			var z := areia.y - v * 2.6
			mm.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(x, relevo.altura(x, z), z)))
			mm.set_instance_custom_data(0, Color(0.1 + v * 0.5, 0.3, 1.0, 1.0))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = materiais[nome]
			vitrine.add_child(mmi)
	await _foto(jogador, Vector3(areia.x - 0.9, y0 + 1.8, areia.y + 7.5), 0.0, -0.12, "vitrine")
	print("RECIFE blocos montados: %d" % int(recifes.call("blocos_montados")))
	# E6: cardume de perto (o mais próximo do miolo), de lado.
	if cardumes != null:
		var perto: Node3D = null
		for n in cardumes.get_children():
			if n is MultiMeshInstance3D and (perto == null or (n as Node3D).global_position.distance_to(Vector3(melhor.x, 0, melhor.y)) < perto.global_position.distance_to(Vector3(melhor.x, 0, melhor.y))):
				perto = n
		if perto != null:
			for i in 30:
				await process_frame
			var c := perto.global_position
			var lado := perto.global_basis.x.normalized()
			var olho := c + lado * 5.5 + Vector3.UP * 0.4
			olho.y = minf(olho.y, relevo.nivel - 2.2)
			var para := c - olho
			await _foto(jogador, olho - Vector3.UP * 1.6, atan2(-para.x, -para.z), -0.05, "cardume")
			print("RECIFE cardume %s em %s" % [perto.name, c])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	quit()


func _foto(jogador: CharacterBody3D, pos: Vector3, yaw: float, pitch: float, nome: String) -> void:
	jogador.global_position = pos
	jogador.velocity = Vector3.ZERO
	jogador.set("_yaw", yaw)
	jogador.set("_pitch", pitch)
	jogador.call("_update_pivot")
	for i in 40:
		await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA.path_join("recifes_%s_%s.png" % [rotulo, nome])))
	print("RECIFE foto %s em %s" % [nome, pos])
