extends SceneTree
## Integração real: GLB/rig/skin, deformação de mandíbula, registro idempotente,
## filtro da loja, inserção, salvar e reabrir o editor. Não toca no mapa do dono.
## godot --headless --path . --script tools/dev_tests/test_bestas_mar.gd

const Registro := preload("res://tools/registrar_bestas_mar.gd")
var _falhas := 0
var _temporario := ""


func _init() -> void:
	await process_frame
	_temporario = "user://test_bestas_mar_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_temporario))
	for id: String in Registro.MODELOS:
		_testar_asset(id)
	var bib := BibliotecaDeModelos.new(_temporario.path_join("modelos"))
	# Sentinela: o registro deve conservar itens e categorias alheios.
	var categoria := bib.criar_categoria("Sentinela")
	_ok(categoria["ok"], "biblioteca temporária criada")
	var sentinela := {"id": "sentinela", "nome": "Não alterar", "sha256": "sentinela",
		"centro": Vector3.ZERO, "tamanho": Vector3.ONE, "triangulos": 0,
		"categorias": [categoria.get("id", "")], "comportamento": ""}
	_ok(bib.adicionar(sentinela) == OK, "sentinela no catálogo")
	var r := Registro.registrar(bib)
	_ok(r["ok"], "registro: %s" % r["erro"])
	if r["ok"]:
		var catalogo := bib.raiz.path_join(BibliotecaDeModelos.ARQUIVO_CATALOGO)
		var antes := FileAccess.get_file_as_string(catalogo)
		var repetido := Registro.registrar(bib)
		_ok(repetido["ok"] and FileAccess.get_file_as_string(catalogo) == antes,
			"reexecutar mantém catálogo idêntico, sem duplicar modelos")
		var relida := BibliotecaDeModelos.new(bib.raiz)
		_ok(relida.ids().size() == 5 and relida.info("sentinela") == sentinela
			and relida.tem_categoria(categoria["id"]), "outros itens e categorias preservados")
		for id: String in Registro.MODELOS:
			var info := relida.info(id)
			_ok(relida.categorias_do_modelo(id).has(r["categoria"])
				and not info.has("animal") and relida.comportamento_do_modelo(id) == "besta_do_mar",
				"%s: comportamento marinho sem ficha terrestre" % id)
			_ok(relida.tamanho_padrao(id).is_equal_approx(info["tamanho"]), "%s: tamanho padrão nativo" % id)
		await _testar_editor(relida, r["categoria"])
	MapaMontador.biblioteca = null
	_limpar(_temporario)
	print("BESTAS DO MAR: %s" % ("TUDO OK" if _falhas == 0 else "%d FALHAS" % _falhas))
	quit(0 if _falhas == 0 else 1)


func _ok(condicao: bool, mensagem: String) -> void:
	print(("  OK " if condicao else "  FALHA ") + mensagem)
	if not condicao:
		_falhas += 1


func _testar_asset(id: String) -> void:
	var caminho := Registro.ORIGEM.path_join(id + ".glb")
	var verificado := ImportadorDeModelos.verificar(caminho)
	_ok(verificado["ok"], "%s: GLB autocontido e válido" % id)
	if not verificado["ok"]:
		return
	var cena := BibliotecaDeModelos.carregar_glb(caminho)
	_ok(cena != null, "%s: Godot gera a cena" % id)
	if cena == null:
		return
	get_root().add_child(cena)
	var medida := BibliotecaDeModelos.medir(cena)
	var tamanho: Vector3 = medida["aabb"].size
	_ok(tamanho.y >= 10.0 and tamanho.y <= 24.0 and medida["triangulos"] > 0,
		"%s: escala gigante %s, %d triângulos" % [id, tamanho, medida["triangulos"]])
	var esqueletos := cena.find_children("*", "Skeleton3D", true, false)
	_ok(esqueletos.size() == 1, "%s: um esqueleto embutido" % id)
	if esqueletos.size() != 1:
		cena.free()
		return
	var esqueleto := esqueletos[0] as Skeleton3D
	_ok(esqueleto.get_bone_count() >= 14, "%s: %d ossos" % [id, esqueleto.get_bone_count()])
	for nome in ["corpo", "cabeca", "mandibula", "cauda_01"]:
		_ok(esqueleto.find_bone(nome) >= 0, "%s: osso %s" % [id, nome])
	_testar_animacoes(cena, id)
	var malhas := cena.find_children("*", "MeshInstance3D", true, false)
	var pesos_validos := not malhas.is_empty()
	var vertices := 0
	var mandibula := esqueleto.find_bone("mandibula")
	var amostras: Array[Dictionary] = []
	for no in malhas:
		var mi := no as MeshInstance3D
		if mi.mesh == null or mi.skin == null or mi.get_node_or_null(mi.skeleton) != esqueleto:
			pesos_validos = false
			continue
		for superficie in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(superficie)
			var pontos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var pesos: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			vertices += pontos.size()
			var influencias := 8 if mi.mesh.surface_get_format(superficie) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS else 4
			if indices.size() != pontos.size() * influencias or pesos.size() != indices.size():
				pesos_validos = false
				continue
			for v in pontos.size():
				var soma := 0.0
				var afeta_mandibula := false
				for j in influencias:
					var k := v * influencias + j
					var peso := pesos[k]
					if not is_finite(peso) or peso < 0.0 or indices[k] < 0 or indices[k] >= mi.skin.get_bind_count():
						pesos_validos = false
						continue
					soma += peso
					var osso := _osso_do_bind(esqueleto, mi.skin, indices[k])
					if peso > 0.0 and (osso < 0 or osso >= esqueleto.get_bone_count()):
						pesos_validos = false
					if osso == mandibula and peso > 0.05:
						afeta_mandibula = true
				if absf(soma - 1.0) > 0.001:
					pesos_validos = false
				if afeta_mandibula and amostras.size() < 128:
					amostras.append({"ponto": pontos[v], "skin": mi.skin,
						"indices": indices.slice(v * influencias, (v + 1) * influencias),
						"pesos": pesos.slice(v * influencias, (v + 1) * influencias)})
	_ok(pesos_validos, "%s: %d vértices com skin, índices válidos e pesos normalizados" % [id, vertices])
	var deslocamento := 0.0
	if mandibula >= 0 and not amostras.is_empty():
		esqueleto.reset_bone_poses()
		esqueleto.force_update_all_bone_transforms()
		var repouso: Array[Vector3] = []
		for amostra in amostras:
			repouso.append(_deformar(esqueleto, amostra))
		var rotacao_de_repouso := esqueleto.get_bone_pose_rotation(mandibula)
		esqueleto.set_bone_pose_rotation(mandibula, rotacao_de_repouso * Quaternion(Vector3.RIGHT, 0.3))
		esqueleto.force_update_all_bone_transforms()
		for n in amostras.size():
			deslocamento = maxf(deslocamento, repouso[n].distance_to(_deformar(esqueleto, amostras[n])))
	_ok(deslocamento > 0.01, "%s: rotação da mandíbula deforma vértices %.3f m (skinning CPU)" % [id, deslocamento])
	cena.free()


func _testar_animacoes(cena: Node3D, id: String) -> void:
	var players := cena.find_children("*", "AnimationPlayer", true, false)
	_ok(players.size() == 1, "%s: AnimationPlayer embutido" % id)
	if players.size() != 1:
		return
	var player := players[0] as AnimationPlayer
	for nome in ["repouso", "ameaca", "idle", "dormindo", "nadando_walk", "nadando_run", "mergulhando", "nadando_submerso", "emergindo", "irritado", "atacando", "recebendo_dano", "disparando_ataque", "comendo"]:
		_ok(player.has_animation(nome), "%s: clipe %s importado" % [id, nome])
		if player.has_animation(nome):
			var clipe := player.get_animation(nome)
			_ok(clipe.length > 0.0 and clipe.get_track_count() > 0,
				"%s: clipe %s com duração e canais" % [id, nome])
	if not player.has_animation("ameaca"):
		return
	var ameaca := player.get_animation("ameaca")
	var abertura := 0.0
	for track in ameaca.get_track_count():
		if ameaca.track_get_type(track) != Animation.TYPE_ROTATION_3D \
				or ameaca.track_get_path(track).get_concatenated_subnames() != "mandibula" \
				or ameaca.track_get_key_count(track) < 2:
			continue
		var primeira: Quaternion = ameaca.track_get_key_value(track, 0)
		for chave in ameaca.track_get_key_count(track):
			var rotacao: Quaternion = ameaca.track_get_key_value(track, chave)
			abertura = maxf(abertura, primeira.angle_to(rotacao))
	_ok(abertura > 0.1, "%s: ameaça anima mandíbula em %.3f rad" % [id, abertura])


func _osso_do_bind(esqueleto: Skeleton3D, skin: Skin, indice: int) -> int:
	var nome := skin.get_bind_name(indice)
	return esqueleto.find_bone(nome) if not nome.is_empty() else skin.get_bind_bone(indice)


func _deformar(esqueleto: Skeleton3D, amostra: Dictionary) -> Vector3:
	var ponto := Vector3.ZERO
	var skin: Skin = amostra["skin"]
	for j in amostra["indices"].size():
		var peso: float = amostra["pesos"][j]
		if peso <= 0.0:
			continue
		var indice: int = amostra["indices"][j]
		var osso := _osso_do_bind(esqueleto, skin, indice)
		if osso >= 0 and osso < esqueleto.get_bone_count():
			ponto += (esqueleto.get_bone_global_pose(osso) * skin.get_bind_pose(indice) * (amostra["ponto"] as Vector3)) * peso
	return ponto


func _testar_editor(bib: BibliotecaDeModelos, categoria: String) -> void:
	var mapa := _temporario.path_join("mapa.json")
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tools/dev_tests/fixtures/mapa_baseplate.json"),
		ProjectSettings.globalize_path(mapa))
	var editor: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	editor.caminho_do_mapa = mapa
	editor.biblioteca = bib
	get_root().add_child(editor)
	current_scene = editor
	await _quadros(3)
	editor._loja.filtrar(categoria)
	_ok(editor._loja.quantidade_visivel() == 4, "loja filtra as quatro Bestas do mar")
	var inseridos: Dictionary = {}
	for id: String in Registro.MODELOS:
		var peca: String = editor.inserir_modelo(id)
		inseridos[id] = peca
		_ok(not peca.is_empty(), "%s: inserido pelo editor" % id)
		if not peca.is_empty():
			_ok(editor.doc.peca(peca)["tamanho"].is_equal_approx(bib.tamanho_padrao(id)), "%s: inserção preserva escala" % id)
	_ok(editor.salvar() == OK, "editor salva o mapa temporário")
	editor.free()
	await _quadros(2)
	var reaberto: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	reaberto.caminho_do_mapa = mapa
	reaberto.biblioteca = BibliotecaDeModelos.new(bib.raiz)
	get_root().add_child(reaberto)
	current_scene = reaberto
	await _quadros(3)
	for id: String in inseridos:
		var peca: String = inseridos[id]
		var modelo := reaberto.get_node_or_null("Vista/Mapa/%s/Modelo" % peca) as Node3D
		_ok(modelo != null and not modelo.get_meta("marcador", false), "%s: modelo reaparece após reabrir" % id)
		if modelo != null:
			_ok(modelo.scale.is_equal_approx(Vector3.ONE)
				and not modelo.find_children("*", "Skeleton3D", true, false).is_empty(),
				"%s: escala 1 e esqueleto mantidos no mapa" % id)
	reaberto.free()
	await _quadros(2)


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _limpar(pasta: String) -> void:
	var dir := DirAccess.open(pasta)
	if dir == null:
		return
	for sub in dir.get_directories():
		_limpar(pasta.path_join(sub))
	for arquivo in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta.path_join(arquivo)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(pasta))
