extends SceneTree
## Cenário visual isolado dos NPCs novos; não carrega campanha nem cria Player.
const PASTA := "res://art_src/validation/sobrevivencia"
func _init() -> void: executar.call_deferred()
func executar() -> void:
	await process_frame
	root.size = Vector2i(1280, 800)
	var mundo := Node3D.new()
	root.add_child(mundo)
	WorldEnv.apply(mundo)
	var chao := MeshInstance3D.new()
	var plano := PlaneMesh.new()
	plano.size = Vector2(160, 160)
	chao.mesh = plano
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("9a9678")
	material.roughness = 0.95
	chao.material_override = material
	mundo.add_child(chao)
	var bib := BibliotecaDeModelos.padrao()
	var mapa := {"pecas": [peca("barracas", "market_stalls_compact", Vector3(-20, 2.62843, 0), Vector3(15.4637, 5.25686, 15.8837)), peca("ferreiro", "blacksmith", Vector3(20, 3.90444, 0), Vector3(10.1141, 7.80888, 8.53709))]}
	var raiz := MapaMontador.montar(mundo, mapa)
	var npcs := NpcsDaIlha.new()
	npcs.progressao = ProgressaoDoPersonagem.new()
	mundo.add_child(npcs)
	npcs.ligar_no_mapa(raiz, mapa, bib)
	var camera := Camera3D.new()
	mundo.add_child(camera)
	camera.fov = 55
	camera.current = true
	for npc in npcs.npcs:
		camera.position = npc.position + Vector3(5, 4.8, 10)
		camera.look_at(npc.position + Vector3(0, 1.8, -3))
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(PASTA.path_join(npc.tipo + ".png"))
		print("CAPTURA: " + npc.tipo + " posição=" + str(npc.position))
	quit()
func peca(id: String, modelo: String, posicao: Vector3, tamanho: Vector3) -> Dictionary:
	return {"id": id, "tipo": "modelo", "modelo": modelo, "posicao": posicao, "tamanho": tamanho, "rotacao_graus": Vector3.ZERO, "colisao": true, "cor": Color.WHITE, "material": "liso"}
