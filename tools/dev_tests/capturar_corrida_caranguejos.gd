extends SceneTree
# ============================================================================
#  CORRIDA DE CARANGUEJOS — fotos com GPU, pela câmera do jogo (06/10/2026).
#
#    DISPLAY=:1 "$(./find_godot.sh)" --fixed-fps 60 --path . --script tools/dev_tests/capturar_corrida_caranguejos.gd -- <pasta>
#
#  0_organizador  o NPC da corrida na ilha (mapa de TESTE com ele posto)
#  1_largada      contagem no grid, rivais e o semáforo do arco
#  1b_grid_de_frente  os seis caranguejos de frente (cores sorteadas dos rivais)
#  2..7           logo depois de entrar em cada trecho (ilhotas, martelos, braços,
#                 plataformas, paredes, impulsos), com a HUD
#  8_chegada      painel do resultado
#  9_aerea        a pista inteira vista do alto
#  O caranguejo do jogador é pilotado pela mesma IA dos rivais.
# ============================================================================

const MAPA := "user://capturar_corrida_mapa.json"
const PROGRESSO := "user://capturar_corrida.json"
const Piloto := preload("res://src/historia/corrida/piloto_de_caranguejo.gd")
## Portão → [nome da foto, quadros depois de passar por ele] (o obstáculo à vista).
const FOTOS := {3: ["2_ilhotas", 40], 6: ["3_martelos", 170], 8: ["4_bracos", 115], 11: ["5_plataformas", 210],
	12: ["6_paredes", 150], 14: ["7_impulsos", 120]}

var saida := ""


func _init() -> void:
	_ir.call_deferred()


func _ir() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else OS.get_user_data_dir()
	root.size = Vector2i(1600, 900)
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	var mapa: Dictionary = lido["mapa"]
	var bib := BibliotecaDeModelos.padrao()
	var npc_id := ""
	for id in bib.ids():
		if bib.comportamento_do_modelo(id) == "npc_corrida":
			npc_id = id
	(mapa.pecas as Array).append({"id": "organizador", "tipo": "modelo", "modelo": npc_id, "posicao": Vector3(0, 0.99, -4.0),
		"rotacao_graus": Vector3(0, 180, 0), "tamanho": bib.tamanho_padrao(npc_id), "cor": Color.WHITE, "material": "liso",
		"grade_celula": 4.0, "colisao": true, "hitbox": {}, "grupo": ""})
	MapaArquivo.salvar(MAPA, mapa)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _quadros(150)
	var p: Node3D = get_first_node_in_group("player")
	p.global_position = Vector3(0, 1.2, 1.5)
	p.set("_yaw", 0.0)
	p.set("_pitch", -0.12)
	p.call("_update_pivot")
	await _quadros(40)
	await _foto("0_organizador")

	var corrida: Node = current_scene.get("corrida")
	var piloto := Piloto.new()
	piloto.configurar(42, 0.0, 0.0)
	corrida.piloto_do_jogador = piloto
	corrida.mostra_resultado = 30.0
	print("largada: '%s'" % corrida.pedir_largada())
	await _quadros(100)
	await _foto("1_largada")
	# De frente para o grid: os seis caranguejos lado a lado (as cores sorteadas).
	var frente := Camera3D.new()
	corrida.add_child(frente)
	frente.global_position = corrida._origem + Vector3(0, 3.2, -24.0)
	frente.look_at(corrida._origem + Vector3(0, 0.8, -10.5))
	frente.fov = 55.0
	frente.make_current()
	await _quadros(3)
	await _foto("1b_grid_de_frente")
	(p.get("_cam") as Camera3D).make_current()
	frente.queue_free()
	var eu: Dictionary = corrida.corredores[0]
	var tiradas := {}
	var guarda := 0
	while corrida.estado != CorridaDeCaranguejos.Estado.RESULTADO and guarda < 60 * 300:
		await process_frame
		guarda += 1
		var passou := int(eu.proximo) - 1
		for g: int in FOTOS:
			if passou >= g and not tiradas.has(g):
				tiradas[g] = guarda + int(FOTOS[g][1])
		for g: int in tiradas.keys():
			if int(tiradas[g]) == guarda:
				await _foto(str(FOTOS[g][0]))
	await _quadros(30)
	await _foto("8_chegada")
	for hud in [current_scene.get("_hud"), corrida.get("_hud")]:
		if hud != null:
			hud.visible = false
	var aerea := Camera3D.new()
	corrida.add_child(aerea)
	var o: Vector3 = corrida._origem
	# De cima, ortográfica: o circuito inteiro (≈ 345 × 345 m) sem a névoa da distância.
	aerea.projection = Camera3D.PROJECTION_ORTHOGONAL
	aerea.size = 400.0
	aerea.global_position = o + Vector3(170, 140, -133)
	aerea.rotation = Vector3(-PI * 0.5, 0, 0)
	aerea.near = 1.0
	aerea.far = 300.0
	aerea.make_current()
	await _quadros(6)
	await _foto("9_aerea")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("fotos em ", saida)
	quit(0)


func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(saida.path_join(nome + ".png"))


func _quadros(n: int) -> void:
	for i in n:
		await process_frame
