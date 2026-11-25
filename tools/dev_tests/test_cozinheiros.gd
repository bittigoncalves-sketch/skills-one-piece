extends SceneTree
## Valida os GLBs e o caminho real GameFlow → história → NPCs, com save/fixture próprios.
const EXPOSICAO = preload("res://src/historia/npcs/exposicao_cozinheiros.gd")
const FIXTURE := "user://test_cozinheiros_mapa.json"
const SAVE := "user://test_cozinheiros_progresso.json"
var _falhas := 0
var _certos := 0

func _initialize() -> void:
	_executar.call_deferred()

func _ok(condicao: bool, texto: String) -> void:
	if condicao:
		_certos += 1
		print("OK ", texto)
	else:
		_falhas += 1
		print("❌ ", texto)

func _executar() -> void:
	var bib := BibliotecaDeModelos.padrao()
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	var vivo: Dictionary = MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]
	var i := 0
	for id: String in EXPOSICAO.NOMES:
		_ok(bib.tem(id) and bib.categorias_do_modelo(id).has("npcs"), id + " na biblioteca NPCs")
		var original := bib.instanciar(id)
		_ok(original != null, id + " importa")
		if original == null:
			continue
		root.add_child(original)
		var esqueletos := original.find_children("*", "Skeleton3D", true, false)
		var players := original.find_children("*", "AnimationPlayer", true, false)
		_ok(esqueletos.size() == 1 and players.size() == 1, id + " um esqueleto e AnimationPlayer")
		if esqueletos.size() != 1 or players.size() != 1:
			original.free()
			continue
		var sk := esqueletos[0] as Skeleton3D
		var ap := players[0] as AnimationPlayer
		_ok(sk.get_bone_count() == 30, id + " 30 ossos")
		var skins_ok := true
		for m in original.find_children("*", "MeshInstance3D", true, false):
			skins_ok = skins_ok and m.skin != null and m.skin.get_bind_count() >= 30
		_ok(skins_ok, id + " corpo e utensílios ligados ao skin")
		for clipe: String in ["descanso", "caminhada", "saudacao", "cozinhar"]:
			_ok(ap.has_animation(clipe), id + " / " + clipe)
			if not ap.has_animation(clipe):
				continue
			ap.play(clipe)
			ap.seek(0.0, true)
			sk.force_update_all_bone_transforms()
			var antes: Array[Quaternion] = []
			var pe_antes := sk.get_bone_global_pose(sk.find_bone("Foot_R")).origin
			for b in sk.get_bone_count():
				antes.append(sk.get_bone_pose_rotation(b))
			ap.seek(ap.get_animation(clipe).length * 0.23, true)
			sk.force_update_all_bone_transforms()
			var movimento := 0.0
			var finito := true
			for b in sk.get_bone_count():
				movimento = maxf(movimento, antes[b].angle_to(sk.get_bone_pose_rotation(b)))
				finito = finito and sk.get_bone_global_pose(b).origin.is_finite()
			_ok(finito and movimento > 0.005, "%s/%s move ossos (%.3f rad)" % [id, clipe, movimento])
			_ok(sk.get_bone_pose_position(sk.find_bone("Root")).length() < 0.001, id + "/" + clipe + " sem deriva de raiz")
			if clipe in ["descanso", "cozinhar"]:
				var pe := sk.find_bone("Foot_R")
				_ok(sk.get_bone_pose_rotation(pe).angle_to(antes[pe]) < 0.001
					and sk.get_bone_global_pose(pe).origin.distance_to(pe_antes) < 0.001, id + "/" + clipe + " pé apoiado")
		original.free()
		var tam := bib.tamanho_padrao(id)
		mapa["pecas"].append({"id": "teste_" + id, "modelo": id, "tipo": "modelo",
			"posicao": Vector3(i * 2.2 - 4.4, tam.y * 0.5, -5), "tamanho": tam,
			"rotacao_graus": Vector3.ZERO, "cor": Color.WHITE, "material": "liso", "colisao": true})
		var encontradas: Array = vivo["pecas"].filter(func(p: Dictionary): return p.get("modelo", "") == id)
		_ok(encontradas.size() == 1, id + " exatamente uma peça na cidade")
		if encontradas.size() == 1:
			var p: Dictionary = encontradas[0]
			var pos: Vector3 = p["posicao"]
			var altura := NAN
			for terreno: Dictionary in vivo["pecas"]:
				if terreno["tipo"] == "terreno":
					var origem: Vector3 = terreno["posicao"]
					var y := TerrenoDoMapa.altura_local(terreno["relevo"], terreno["tamanho"], pos.x-origem.x, pos.z-origem.z)
					if not is_nan(y):
						altura = origem.y + y
						break
			_ok(not is_nan(altura) and absf(pos.y - tam.y/2 - altura) < 0.02, id + " no chão do relevo")
			_ok(Vector2(pos.x-152, pos.z-20).length() < 12.0, id + " perto do nascimento")
		i += 1
	_ok(MapaArquivo.salvar(FIXTURE, mapa) == OK, "fixture isolada gravada")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", FIXTURE)
	modo.set("progresso_forcado", SAVE)
	root.get_node("GameFlow").start_story()
	for frame in 100:
		await physics_frame
	var grupo := get_nodes_in_group("cozinheiros_exposicao")
	_ok(grupo.size() == 5, "os cinco nascem pelo fluxo real do modo história")
	for peca in grupo:
		var controlador: Node = peca.get_node("ApresentacaoCozinheiro")
		_ok(controlador.animador.is_playing(), str(peca.name) + " animação automática ativa")
		# Observar avanço REAL na árvore; is_playing sozinho não prova deformação.
		controlador.set_process(false)
		controlador.mostrar("cozinhar")
		var sk := peca.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		for quadro in 24:
			await physics_frame
		var mao := sk.find_bone("Hand_R")
		var pose_antes := sk.get_bone_global_pose(mao)
		for quadro in 24:
			await physics_frame
		var pose_depois := sk.get_bone_global_pose(mao)
		_ok(not pose_antes.is_equal_approx(pose_depois), str(peca.name) + " mão anima no mapa sem advance manual")
		_ok(peca.has_node("NomeCozinheiro"), str(peca.name) + " nome visível")
		var visuais := peca.find_children("*", "GeometryInstance3D", true, false)
		_ok(visuais.all(func(n): return (n.layers & MapaMontador.CAMADA_CENARIO) == 0), str(peca.name) + " visual fora da camada de cenário/gelo")
		var colisoes := peca.find_children("*", "CollisionShape3D", false, false)
		_ok(not colisoes.is_empty() and colisoes[0].shape is CapsuleShape3D, str(peca.name) + " colisão corporal")
		controlador.set_process(false)
		controlador.mostrar("cozinhar")
		var utensilios := peca.find_children("Utensilio*", "MeshInstance3D", true, false)
		_ok(utensilios.size() == 5 and utensilios.all(func(n): return n.visible), str(peca.name) + " cinco partes dos utensílios na culinária")
		controlador.mostrar("descanso")
		_ok(utensilios.all(func(n): return not n.visible), str(peca.name) + " mãos livres no descanso")
		var dono := peca.get_parent() as Node3D
		EXPOSICAO.ligar(dono, mapa, bib)
		_ok(peca.find_children("ApresentacaoCozinheiro", "", false, false).size() == 1, str(peca.name) + " ligação idempotente")
	print("COZINHEIROS_RESULTADO ok=%d falhas=%d" % [_certos, _falhas])
	quit(0 if _falhas == 0 else 1)
