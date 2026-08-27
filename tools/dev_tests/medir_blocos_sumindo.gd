extends SceneTree
# ============================================================================
#  BLOCOS QUE SOMEM — a sonda que prova, em vez de opinar.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_blocos_sumindo.gd -- <pasta>
#
#  O dono relatou blocos ficando invisíveis. "Bloco invisível" quase sempre é
#  DESCARTE DE RENDERIZAÇÃO (culling) — o motor decide que o objeto não aparece
#  e não o desenha. Isso é traiçoeiro porque não gera erro nenhum: o bloco
#  simplesmente não está lá.
#
#  MÉTODO, e por que ele não deixa margem: todos os blocos são pintados de
#  VERMELHO PURO sem iluminação. Aí, para cada bloco e cada rumo da câmera:
#
#    1. `unproject_position` diz em que pixel o centro dele cai;
#    2. um RAIO da câmera até o centro dele diz se há alguma coisa NA FRENTE
#       (se houver, ele está legitimamente escondido e não conta);
#    3. se o bloco está na tela E desobstruído, TEM que haver vermelho naquele
#       pixel. Se não houver, ele sumiu — e isso é falha, não opinião.
#
#  Pintar de vermelho é o que remove a ambiguidade: bloco cinza contra chão
#  cinza é indistinguível por cor, e foi por isso que a inspeção a olho das
#  capturas não conseguiu decidir nada.
# ============================================================================

const RUMOS := 72        # de 5 em 5 graus
const ALCANCE := 100.0   # blocos além disto não interessam para o relato

# Postos de observacao. Culling depende de ONDE a camera esta, nao so do rumo —
# por isso o teste de pe no centro (que passou limpo) nao encerra o assunto.
# Inclui alturas de PULO, porque o dono relatou o defeito ao pular.
const POSTOS := [
	Vector3(0, 2.0, 0),       # centro, no chao
	Vector3(0, 8.0, 0),       # centro, no alto do pulo
	Vector3(0, 16.0, 0),      # centro, bem alto (pulo longo/parkour)
	Vector3(60, 2.0, 60),     # perto da borda da plataforma
	Vector3(60, 12.0, 60),    # borda, no ar
	Vector3(-70, 2.0, 30),    # outro canto
]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/blocos"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	_esconder_2d(get_root())

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	p.velocity = Vector3.ZERO

	# Pinta TODO bloco de vermelho puro, sem luz. Cinza contra cinza não decide.
	var vermelho := StandardMaterial3D.new()
	vermelho.albedo_color = Color(1, 0, 0)
	vermelho.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var blocos: Array = []
	for n in _todos(get_root()):
		if not (n is StaticBody3D) or n.name == "Plataforma":
			continue
		var malhas: Array = []
		for f in n.get_children():
			if f is MeshInstance3D:
				f.material_override = vermelho
				malhas.append(f)
		if malhas.size() > 0:
			blocos.append(n)
	print("blocos pintados: %d" % blocos.size())

	# O CHAO tambem entra no teste. As lajes sao um MultiMesh (1 draw call para
	# a plataforma inteira) e MultiMesh tem AABB PROPRIO: se ele ficar menor que
	# a geometria, pedacos inteiros de chao somem sem erro nenhum. Verde puro
	# pelo mesmo motivo do vermelho — cinza contra cinza nao decide nada.
	var verde := StandardMaterial3D.new()
	verde.albedo_color = Color(0, 1, 0)
	verde.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lajes: MultiMeshInstance3D = null
	for n in _todos(get_root()):
		if n is MultiMeshInstance3D and n.name == "Lajes":
			lajes = n
			lajes.material_override = verde
			break

	var cam: Camera3D = p._camera.camera()
	var espaco := (get_root().world_3d as World3D).direct_space_state
	var sumidos: Array = []
	var chao_sumido: Array = []
	var testados := 0
	var testados_chao := 0

	# ⚠️ De pe no centro, 788 testes nao acharam nada. O relato fala em PULAR,
	# entao o ponto de vista importa: culling depende de onde a camera esta, nao
	# so de para onde ela olha. Estes sao os postos de observacao.
	for posto in POSTOS:
		p.global_position = posto
		for i in RUMOS:
			var yaw := TAU * float(i) / float(RUMOS)
			p._yaw = yaw
			p._pitch = -0.15
			p._camera.apontar(yaw, -0.15)
			var t := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t < 90:
				await process_frame
			var img := get_root().get_texture().get_image()
			var larg := img.get_width()
			var alt := img.get_height()

			# --- o chao: cinco pontos espalhados pela metade de baixo da tela ---
			for frac in [0.30, 0.45, 0.60, 0.75, 0.90]:
				var px := Vector2(larg * 0.5, alt * (0.55 + frac * 0.4))
				if px.y >= alt - 4:
					continue
				var de := cam.project_ray_origin(px)
				var dir := cam.project_ray_normal(px)
				var pr := PhysicsRayQueryParameters3D.create(de, de + dir * 400.0)
				var h2 := espaco.intersect_ray(pr)
				if h2.is_empty():
					continue
				var quem: Node = h2["collider"]
				if quem.name != "Plataforma":
					continue
				testados_chao += 1
				var c := img.get_pixel(int(px.x), int(px.y))
				# ⚠️ DOMINÂNCIA DE CANAL, não limiar absoluto. A primeira versão exigia
				# `g > 0.35`, e a névoa escurece o chão distante bem abaixo disso: a 130 m
				# o verde puro chega como (0,00 · 0,22 · 0,04) — ainda inconfundivelmente
				# verde, mas reprovado pelo limiar. Isso gerava FALSO POSITIVO de "o chão
				# sumiu" na beirada da plataforma, longe da câmera. Dominância não depende
				# do brilho: só pergunta se o verde manda no pixel, e por isso atravessa
				# a névoa.
				if not (c.g > c.r * 1.6 and c.g > c.b * 1.6 and c.g > 0.04):
					# ⚠️ MARGEM DE SILHUETA. Raio e rasterizador decidem coisas diferentes:
					# o raio acerta se a linha CRUZA o sólido; o pixel é pintado por COBERTURA,
					# e na quina a cobertura é parcial. Some a isso o `Contorno`, que pinta
					# uma linha escura por cima da silhueta — os últimos pixels da beirada
					# da laje são contorno, não chão.
					#
					# Medido: no pixel discordante, andar 2 px para a esquerda ou 4 para cima
					# já acha chão desenhado, e a cor lida é (0,00 · 0,00 · 0,03) — preto de
					# contorno. Discordar A 5 mm DA QUINA é o comportamento correto dos dois.
					#
					# Então: só conta como "o chão sumiu" se o buraco tiver CORPO — nenhum
					# chão desenhado num raio de 6 px. Sem isso a sonda acusa a própria
					# borda da geometria.
					var perto_da_borda := false
					for d: Vector2i in [Vector2i(6,0), Vector2i(-6,0), Vector2i(0,6), Vector2i(0,-6)]:
						var vx: int = clampi(int(px.x) + d.x, 0, larg - 1)
						var vy: int = clampi(int(px.y) + d.y, 0, alt - 1)
						var cc := img.get_pixel(vx, vy)
						if cc.g > cc.r * 1.6 and cc.g > cc.b * 1.6 and cc.g > 0.04:
							perto_da_borda = true
							break
					if perto_da_borda:
						continue
					chao_sumido.append({"posto": posto, "yaw": rad_to_deg(yaw),
						"tela": px, "mundo": h2["position"], "cor": c})
					img.save_png("%s/chao_sumiu_y%03d_p%d.png" % [saida, int(rad_to_deg(yaw)), int(posto.y)])

			for b in blocos:
				var centro: Vector3 = (b as Node3D).global_position
				if cam.global_position.distance_to(centro) > ALCANCE:
					continue
				if cam.is_position_behind(centro):
					continue
				var tela := cam.unproject_position(centro)
				# Margem de 24 px: bloco encostando na borda pode ser recortado por
				# motivo legítimo, e não é disso que o relato trata.
				if tela.x < 24 or tela.y < 24 or tela.x > larg - 24 or tela.y > alt - 24:
					continue
				# Alguma coisa na frente? Então ele está escondido de verdade.
				var par := PhysicsRayQueryParameters3D.create(cam.global_position, centro)
				par.collide_with_areas = false
				var hit := espaco.intersect_ray(par)
				if hit.is_empty() or hit["collider"] != b:
					continue
				testados += 1
				if not _tem_vermelho(img, tela, 10):
					sumidos.append({"bloco": (b as Node3D).name, "yaw": rad_to_deg(yaw),
						"pos": centro, "tela": tela,
						"dist": cam.global_position.distance_to(centro)})
					img.save_png("%s/sumiu_%s_yaw%03d.png" % [saida, (b as Node3D).name, int(rad_to_deg(yaw))])

	print("\n=== chao: %d pontos conferidos ===" % testados_chao)
	if chao_sumido.is_empty():
		print("✓ o chao nunca sumiu")
	else:
		print("❌ %d pontos onde o RAIO acerta a Plataforma mas a tela nao mostra chao:" % chao_sumido.size())
		for s2 in chao_sumido.slice(0, 12):
			print("   posto %s | rumo %6.1f° | mundo %s | cor lida %s" % [
				str(s2["posto"]), s2["yaw"], str(s2["mundo"]), str(s2["cor"])])

	print("\n=== blocos visíveis e desobstruídos testados: %d ===" % testados)
	if sumidos.is_empty():
		print("✓ nenhum bloco sumiu — culling não é a causa")
	else:
		print("❌ %d casos de bloco que DEVERIA aparecer e não apareceu:" % sumidos.size())
		for s in sumidos:
			print("   %s | rumo %6.1f° | dist %5.1f | tela (%4d,%4d) | mundo %s" % [
				s["bloco"], s["yaw"], s["dist"],
				int(s["tela"].x), int(s["tela"].y), str(s["pos"])])
	quit()

# Procura vermelho numa janelinha em volta do pixel. Vermelho puro sem luz
# atravessa o tonemap ainda claramente vermelho (r bem acima de g e b).
func _tem_vermelho(img: Image, centro: Vector2, raio: int) -> bool:
	var x0 := maxi(0, int(centro.x) - raio)
	var x1 := mini(img.get_width() - 1, int(centro.x) + raio)
	var y0 := maxi(0, int(centro.y) - raio)
	var y1 := mini(img.get_height() - 1, int(centro.y) + raio)
	for y in range(y0, y1 + 1, 2):
		for x in range(x0, x1 + 1, 2):
			var c := img.get_pixel(x, y)
			if c.r > 0.35 and c.r > c.g * 1.8 and c.r > c.b * 1.8:
				return true
	return false

func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children():
		out.append_array(_todos(f))
	return out

func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem:
			f.visible = false
		else:
			_esconder_2d(f)
