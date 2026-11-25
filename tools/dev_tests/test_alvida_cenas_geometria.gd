extends SceneTree
# Caça-bugs de GEOMETRIA das cenas da Alvida (22/11/2026), sem render: para cada plano de câmera, a linha de vista até o alvo está livre do casco? a câmera está dentro de parede/mastro?
# os atores pisam no convés e têm cabeça livre? os lutadores e a plateia caem no quadro da câmera do duelo? o barril passa por cima da amurada em TODA a trajetória (varredura fina)? Rodar:
#   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_alvida_cenas_geometria.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1
func frames(n: int) -> void:
	for i in n: await physics_frame

func _init() -> void: _rodar.call_deferred()

func _livre(espaco: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, PalcoDaAlvida.CAMADA_DA_CAMERA)
	q.hit_back_faces = true
	return espaco.intersect_ray(q).is_empty()

func _dentro_de_parede(espaco: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		if not _livre(espaco, p, p + d * 0.35): return true
	return false

func _rodar() -> void:
	await process_frame
	print("\n===== ALVIDA: GEOMETRIA DAS CENAS =====")
	var caminho := "user://teste_alvida_geo.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.missoes["desafio_dos_copos"] = {"estado": "entregue", "abates": 1}
	prog.sistemas["desafio_buggy"] = {"fase": "copos_certo"}
	prog.missoes["resgate_do_bau"] = {"estado": "entregue", "abates": 1}
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var m = null
	for i in 2400:
		await physics_frame
		if get_first_node_in_group("player") != null and current_scene != null and current_scene.get("missao_da_alvida") != null:
			m = current_scene.missao_da_alvida; break
	if m == null:
		ok("orquestrador existe", false); quit(1); return
	await frames(30)
	m.escala_de_tempo = 1.0
	m._montar_palco()
	await frames(3)
	var palco: PalcoDaAlvida = m.palco
	var espaco := palco.get_world_3d().direct_space_state
	var conves: float = palco.navio.global_position.y + PalcoDaAlvida.CONVES_Y

	print("-- atores no convés --")
	for a in [palco.alvida] + palco.tripulacao:
		var p: Vector3 = a.global_position
		ok("%s: pisa no convés (y %.2f ≈ %.2f)" % [a.name, p.y, conves], absf(p.y - conves) < 0.15)
		ok("%s: cabeça livre (nada a 2,3 m acima) e fora de parede" % a.name, _livre(espaco, p + Vector3.UP * 0.2, p + Vector3.UP * 2.3) and not _dentro_de_parede(espaco, p + Vector3.UP * 1.0))
	var jp: Vector3 = palco.lugar_do_jogador()
	ok("lugar do jogador: no convés, cabeça livre", absf(jp.y - conves) < 0.15 and _livre(espaco, jp + Vector3.UP * 0.2, jp + Vector3.UP * 2.3))

	print("-- câmeras de cada plano do barril (linha de vista e parede) --")
	var planos: Array[Dictionary] = m._planos_do_barril()
	var nomes := ["1 barril no mar (3ª pessoa)", "2 içando", "3 Alvida manda abrir", "4 tampa salta", "5 Alvida: invasor"]
	for i in planos.size():
		var pl: Dictionary = planos[i]
		var ruins := 0
		var vistas := 0
		for k in [0.0, 0.25, 0.5, 0.75, 1.0]:
			var de: Vector3 = (pl["de"] as Vector3).lerp(pl.get("de_fim", pl["de"]), k)
			var para: Vector3 = (pl["para"] as Vector3).lerp(pl.get("para_fim", pl["para"]), k)
			vistas += 1
			if i == 0:
				if de.y < palco.agua_y + 0.5: ruins += 1               # câmera submersa
			elif _dentro_de_parede(espaco, de): ruins += 1
			elif i >= 2 and not _livre(espaco, de, para): ruins += 1       # algo do casco entre a câmera e o rosto/barril
		ok("plano %s: %d/%d amostras sem câmera em parede nem alvo escondido" % [nomes[i], vistas - ruins, vistas], ruins == 0)

	print("-- içar: varredura fina do barril (k de 0 a 1, passo 0,005) --")
	var anterior := Vector3.INF
	var batidas := 0
	var passo_max := 0.0
	var k := 0.0
	while k <= 1.0001:
		palco.colocar_barril(k)
		var pos: Vector3 = palco.barril.global_position
		if anterior != Vector3.INF:
			passo_max = maxf(passo_max, pos.distance_to(anterior))
			for dx in [-0.85, 0.0, 0.85]:
				for dz in [-0.85, 0.0, 0.85]:
					for dy in [0.0, 1.0, 1.6]:
						if not _livre(espaco, anterior + Vector3(dx, dy, dz), pos + Vector3(dx, dy, dz)): batidas += 1
		anterior = pos
		k += 0.005
	ok("o barril (corpo de 1,7 m) não bate no casco em nenhum ponto do caminho (%d batidas)" % batidas, batidas == 0)
	ok("sem saltos: passo máximo %.2f m por 0,5%% do trajeto (suave)" % passo_max, passo_max < 0.6)
	palco.colocar_barril(0.0)
	ok("o barril começa na água (y ≈ linha d'água) e termina no convés", absf(palco.barril.global_position.y - (palco.agua_y + 0.25)) < 0.5)
	palco.colocar_barril(1.0)
	ok("termina no convés (y %.2f ≈ %.2f)" % [palco.barril.global_position.y, conves], absf(palco.barril.global_position.y - conves) < 0.3)

	print("-- câmera do duelo: quadro --")
	var cam: Dictionary = palco.plano_aberto_do_duelo()
	var c3 := Camera3D.new()
	root.add_child(c3)
	c3.fov = float(cam["fov"])
	c3.global_position = cam["de"]
	c3.look_at(cam["para"], Vector3.UP)
	await process_frame
	ok("câmera livre (não em fallback)", bool(cam.get("livre", false)))
	ok("jogador e Alvida dentro do quadro", c3.is_position_in_frustum(palco.lugar_do_jogador() + Vector3.UP * 1.0) and c3.is_position_in_frustum(palco.lugar_da_alvida() + Vector3.UP * 1.0))
	var no_quadro := 0
	for t in palco.tripulacao:
		if c3.is_position_in_frustum(t.global_position + Vector3.UP * 1.0): no_quadro += 1
	ok("a plateia aparece no quadro (%d/6 tripulantes)" % no_quadro, no_quadro >= 4)
	var atras := 0
	for t in palco.tripulacao:
		if (t.global_position - c3.global_position).length() > (palco.ponto_da_arena() - c3.global_position).length() - 0.5: atras += 1
	ok("a plateia está ATRÁS dos lutadores em relação à câmera (%d/6) — 'no fundo'" % atras, atras >= 4)
	var d_cam: float = c3.global_position.distance_to(palco.ponto_da_arena())
	ok("distância da câmera ao duelo razoável (%.1f m: 4–11)" % d_cam, d_cam >= 4.0 and d_cam <= 11.0)
	c3.queue_free()

	print("-- aparência (sem render): materiais do navio --")
	var sem_textura_magenta := 0
	var malhas := 0
	for mi in palco.navio.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		if mm.mesh == null or not mm.is_visible_in_tree(): continue
		malhas += 1
		for sf in mm.mesh.get_surface_count():
			var mt := mm.get_active_material(sf) as BaseMaterial3D
			if mt != null and mt.albedo_texture == null and mt.albedo_color.r > 0.9 and mt.albedo_color.b > 0.9 and mt.albedo_color.g < 0.1: sem_textura_magenta += 1
	ok("navio: %d malha(s) visível(is) e nenhuma superfície magenta" % malhas, malhas >= 1 and sem_textura_magenta == 0)
	var visiveis_colisao := palco.navio.find_children("Colisao*", "MeshInstance3D", true, false).filter(func(n): return n.is_visible_in_tree())
	ok("nenhuma malha 'Colisao' visível por cima do navio", visiveis_colisao.is_empty())
	var vazios := 0
	for a in [palco.alvida] + palco.tripulacao:
		var tem := false
		for mi in a.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).is_visible_in_tree(): tem = true
		if not tem: vazios += 1
	ok("todo ator tem malha visível (nenhum invisível/caixa vazia) — %d sem" % vazios, vazios == 0)

	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
