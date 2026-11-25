extends SceneTree
# Captura (com GPU) dos BLOCOS do mod numa ilha REAL do Modo História: blocos novos (gelo, areia, fogo, lava…),
# cratera que se refaz (medindo a refeitura da malha) e entulho que cai.
#
#   DISPLAY=:1 "$(./find_godot.sh)" --path . -s tools/dev_tests/captura_blocos_mine_piece.gd -- <pasta>

var saida := "/tmp/blocos_mp"
var cam: Camera3D
const B := 0.88


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


func olhar(de: Vector3, para: Vector3) -> void:
	cam.global_position = de
	cam.look_at(para, Vector3.UP)


func rodar_ticks(mundo: McMundo, n: int) -> void:
	for i in n:
		mundo.tick()
		await physics_frame


func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://captura_blocos_mp.json")
	root.get_node("GameFlow").start_story()
	await quadros(300)
	var jogador: CharacterBody3D = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var base := jogador.global_position
	var corpo: StaticBody3D = null
	var menor := INF
	for n in get_nodes_in_group(RelevoEmBlocos.GRUPO):
		var r: RelevoEmBlocos = n.get_meta(RelevoEmBlocos.META)
		var d := absf(r.altura(base.x, base.z) - base.y) if not is_nan(r.altura(base.x, base.z)) else INF
		if d < menor:
			menor = d
			corpo = n
	print("ILHA ", corpo.get_meta("ilha") if corpo else "?", " jogador=", base)
	var r: RelevoEmBlocos = corpo.get_meta(RelevoEmBlocos.META)
	var mundo := Mc.mundo(self)
	mundo.relevo.tempo_para_refazer = 20 * 8
	jogador.process_mode = Node.PROCESS_MODE_DISABLED
	jogador.visible = false
	cam = Camera3D.new()
	current_scene.add_child(cam)
	cam.fov = 55
	cam.current = true
	# Ponto de chão a 6 blocos à frente (+Z) do jogador.
	var cx := floori(base.x / B)
	var cz := floori(base.z / B) + 6
	var topo := r.altura((cx + 0.5) * B, (cz + 0.5) * B)
	var cy := int(round(topo / B))
	print("ALVO bloco ", Vector3i(cx, cy, cz), " topo=", topo)
	olhar(base + Vector3(-7.0, 4.0, 1.0), Vector3((cx + 3) * B, topo, (cz) * B))
	await quadros(10)
	await foto("00_antes")

	# 1. blocos novos em fila sobre o chão
	var ids := [&"minecraft:ice", &"minecraft:packed_ice", &"minecraft:sand", &"minecraft:red_sand", &"minecraft:fire", &"minecraft:soul_fire", &"minecraft:lava", &"minecraft:water"]
	for i in ids.size():
		mundo.setBlock(McVec3.de(float(cx + i), float(cy), float(cz)), McBloco.Estado.de(Mc.bloco(ids[i])), 3)
		mundo.setBlock(McVec3.de(float(cx + i), float(cy + 1), float(cz)), McBloco.Estado.de(Mc.bloco(&"minecraft:packed_ice" if i % 2 == 0 else &"minecraft:sand")), 3)
	await quadros(8)
	await foto("01_blocos_novos")

	# 2. cratera esférica de raio 3,5 blocos centrada no chão, depois de limpar os blocos
	mundo.blocos.limpar()
	var centro := Vector3i(cx + 3, cy, cz + 4)
	var t0 := Time.get_ticks_msec()
	var n_cel := 0
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			for dz in range(-4, 5):
				if Vector3(dx, dy, dz).length() <= 3.5:
					mundo.setBlock(McVec3.de(float(centro.x + dx), float(centro.y + dy), float(centro.z + dz)), McBloco.Estado.de(Mc.bloco(&"minecraft:air")), 3)
					n_cel += 1
	await physics_frame
	await physics_frame
	var ate := Time.get_ticks_msec()
	while mundo.relevo.ocupado() and Time.get_ticks_msec() - ate < 8000:
		mundo.tick()
		await physics_frame
	print("CRATERA %d chamadas setBlock; refeitura da ilha em %d ms (fim a fim, %d quadros de jogo sem travar)" % [n_cel, Time.get_ticks_msec() - t0, Engine.get_physics_frames()])
	olhar(base + Vector3(-7.0, 5.0, 3.0), Vector3(centro.x * B, topo - 1.0, centro.z * B))
	await quadros(8)
	await foto("02_cratera")

	# 3. entulho que cai
	for k in 14:
		var q: McEntidade = Mc.tipo_entidade(&"minecraft:falling_block").create(mundo, null, null, McVec3.de(centro.x + randf_range(-1.5, 1.5), centro.y + 7.0 + randf() * 3.0, centro.z + randf_range(-1.5, 1.5)))
		if q != null:
			q.setDeltaMovement(randf_range(-0.2, 0.2), 0.3, randf_range(-0.2, 0.2))
	await quadros(18)
	await foto("03_entulho_caindo")
	await quadros(120)
	await foto("04_entulho_pousado")

	# 4. a ilha se refaz
	await rodar_ticks(mundo, 20 * 9)
	var ate2 := Time.get_ticks_msec()
	while mundo.relevo.ocupado() and Time.get_ticks_msec() - ate2 < 8000:
		await physics_frame
	await quadros(10)
	await foto("05_refeita")
	print("FIM topo no centro depois: ", r.altura(centro.x * B, centro.z * B), " (antes ", topo, ")")
	modo.set("progresso_forcado", "")
	quit()
