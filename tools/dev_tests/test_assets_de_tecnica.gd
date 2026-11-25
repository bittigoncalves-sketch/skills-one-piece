extends SceneTree
# ============================================================================
#  ASSETS 3D DAS TÉCNICAS DAS LOGIAS (24/11/2026): a técnica dispara o projétil com o asset do Blender (`AssetsDeTecnica`), não o plano genérico.
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_assets_de_tecnica.gd
#  Suna · Desert Dagger (Z): sai uma adaga de areia, que anda (é disparada). Mede também que todo .glb da tabela existe e tem malha e textura.
# ============================================================================
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func tecla(codigo: Key, apertou: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = codigo
	e.physical_keycode = codigo
	e.pressed = apertou
	Input.parse_input_event(e)

func com_asset() -> Array:
	var saida := []
	for n in get_nodes_in_group("mc_corpos_do_mod"):
		if n.get_node_or_null("Desenho/Asset") != null:
			saida.append(n)
	return saida

func rodar() -> void:
	# ---- a tabela e os arquivos
	for chave: String in AssetsDeTecnica.TABELA:
		var f: Dictionary = AssetsDeTecnica.TABELA[chave]
		var caminho: String = AssetsDeTecnica.PASTA + str(f.glb) + ".glb"
		var cena := load(caminho) as PackedScene if ResourceLoader.exists(caminho) else null
		var no := cena.instantiate() if cena != null else null
		var malhas: Array = no.find_children("*", "MeshInstance3D", true, false) if no != null else []
		var textura := false
		for m in malhas:
			var mat := (m as MeshInstance3D).get_active_material(0) as StandardMaterial3D
			textura = textura or (mat != null and mat.albedo_texture != null)
		ok(no != null and malhas.size() > 0 and textura, "%s: asset %s existe, tem malha e textura" % [chave, f.glb])
		if no != null:
			no.free()
	# ---- o jogo
	MundoMinePiece.FATOR_DE_PROJETIL = 1.0
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_assets_de_tecnica.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var jogador = get_first_node_in_group("player")
	jogador.set_meta("damage_immune", true)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = jogador.global_position + Vector3(0, 0, -14)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	await quadros(10)
	var prog: ProgressaoDoPersonagem = current_scene.progressao
	prog.dar_fruta_de_teste("suna_suna", 1)
	prog.comer_fruta("suna_suna")
	await quadros(15)
	jogador.max_energy = 100000.0
	jogador.energy = jogador.max_energy
	for _i in 4:
		var mira: Vector3 = alvo.global_position + Vector3.UP - jogador._cam.global_position
		jogador._yaw = RosaDosVentos.yaw_para(Vector3(mira.x, 0, mira.z).normalized())
		jogador._pitch = asin(mira.normalized().y)
		jogador._update_pivot()
		await quadros(3)
	tecla(KEY_Z, true)
	await quadros(12)
	tecla(KEY_Z, false)
	var vistos := 0
	var andou := false
	var p0 := Vector3.ZERO
	for i in 40:
		await physics_frame
		var l := com_asset()
		if l.size() > 0:
			vistos = maxi(vistos, l.size())
			if p0 == Vector3.ZERO:
				p0 = (l[0] as Node3D).global_position
			elif ((l[0] as Node3D).global_position - p0).length() > 1.0:
				andou = true
	ok(vistos >= 1, "Suna · Desert Dagger: o projétil nasce com o asset de adaga (%d)" % vistos)
	ok(andou, "e a adaga é disparada (anda mais de 1 m)")
	# ---- cada entrada da tabela, disparada de verdade: o corpo que a técnica cria nasce com o asset
	var por_fruta := {}
	for chave: String in AssetsDeTecnica.TABELA:
		var partes := chave.split("|")
		if not por_fruta.has(partes[0]):
			por_fruta[partes[0]] = []
		(por_fruta[partes[0]] as Array).append([int(partes[1]), partes[2]])
	var avancos = McEntidade.de(jogador).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	for fruta: String in por_fruta:
		prog.tirar_fruta()
		await quadros(5)
		prog.dar_fruta_de_teste(fruta, 1)
		prog.comer_fruta(fruta)
		await quadros(15)
		var c = jogador.get_node_or_null("FrutaMinePiece")
		var mapa: Dictionary = c.mapa_de_teclas() if c != null else {}
		for par: Array in por_fruta[fruta]:
			var letra := ""
			for l: String in mapa:
				if int(mapa[l]) == int(par[0]):
					letra = l
			if letra.is_empty():
				ok(false, "%s %d: sem tecla no mapa" % [fruta, par[0]])
				continue
			c = jogador.get_node_or_null("FrutaMinePiece")
			for k in c._recargas.keys():
				c._recargas[k] = 0.0
			jogador.max_energy = 100000.0   # comer a fruta devolve o teto do nível (600): as técnicas de 1000 ficariam travadas
			jogador.energy = jogador.max_energy
			jogador.global_position = Vector3(0, 1.0, 0)
			for outro in get_nodes_in_group("mc_corpos_do_mod"):
				outro.queue_free()
			await quadros(5)
			var kc := OS.find_keycode_from_string(letra)
			tecla(kc, true)
			await quadros(80 if int(par[0]) >= 26 else 14)   # as técnicas grandes (Flame Emperor, Dark Matter) carregam mais antes de criar o corpo
			tecla(kc, false)
			var achou := false
			for i in 200:
				await physics_frame
				for n in get_nodes_in_group("mc_corpos_do_mod"):
					if n.get_node_or_null("Desenho/Asset") != null and n.name.contains(str(par[1])):
						achou = true
				if achou:
					break
			ok(achou, "%s · técnica %d (%s): o corpo %s nasce com o asset" % [fruta, par[0], letra, par[1]])
			await quadros(40)
	# ---- Pika · flecha de luz (Yasakani, executor próprio): o dardo 3D vai na flecha
	prog.tirar_fruta()
	await quadros(5)
	prog.dar_fruta_de_teste("pika_pika_mine_piece", 1)
	prog.comer_fruta("pika_pika_mine_piece")
	await quadros(20)
	var cp = jogador.get_node_or_null("FrutaMinePiece")
	jogador.max_energy = 100000.0
	jogador.energy = jogador.max_energy
	var letra_y := ""
	var mapa_p: Dictionary = cp.mapa_de_teclas()
	for l: String in mapa_p:
		if int(mapa_p[l]) == 29:
			letra_y = l
	var com_dardo := 0
	if not letra_y.is_empty():
		var kp := OS.find_keycode_from_string(letra_y)
		tecla(kp, true)
		await quadros(60)
		tecla(kp, false)
		for i in 120:
			await physics_frame
			for n in current_scene.get_children():
				var sc: Script = n.get_script()
				if sc != null and sc.resource_path.ends_with("luz_pika.gd") and n.get_node_or_null("Asset") != null:
					com_dardo += 1
			if com_dardo > 0:
				break
	ok(com_dardo > 0, "Pika · Yasakani (%s): a flecha de luz nasce com o dardo 3D (%d)" % [letra_y, com_dardo])
	print("\nASSETS %d/%d" % [total - falhas, total])
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)
