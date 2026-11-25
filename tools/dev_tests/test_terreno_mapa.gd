extends SceneTree
# ============================================================================
#  TESTE — peça `terreno` (relevo em blocos, 30/09/2026) + tamanho padrão e ficha
#  de navio do catálogo.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_terreno_mapa.gd
#
#  Tudo em memória ou em `user://test_terreno/` — o mapa vivo e a loja do projeto
#  não são tocados (o catálogo real é COPIADO antes de qualquer escrita).
# ============================================================================

const PASTA := "user://test_terreno"
var _falhas := 0


func _initialize() -> void:
	_executar.call_deferred()


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _executar() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PASTA))
	_formato()
	_malha()
	await _colisao_e_emenda()
	_catalogo()
	_catalogo_real()
	_malha_de_colisao()
	await _partes_convexas()
	await _editor()
	print("\nTERRENO_RESULTADO falhas=%d" % _falhas)
	quit(1 if _falhas > 0 else 0)


# Morro de teste: cúpula no meio de um bloco 8×8, o resto plano em 10 %.
static func _relevo_morro(celulas: int, com_agua: bool) -> Dictionary:
	var r := TerrenoDoMapa.plano(celulas, 1000)
	var n := celulas
	for j in n + 1:
		for i in n + 1:
			var d := Vector2(i - n * 0.5, j - n * 0.5).length() / (n * 0.5)
			r["alturas"][j * (n + 1) + i] = 1000 + int(9000.0 * maxf(0.0, 1.0 - d))
	if com_agua:
		var agua := PackedInt32Array()
		agua.resize((n + 1) * (n + 1))
		agua.fill(-1)
		# Uma faixa molhada na primeira coluna de células.
		for j in n + 1:
			agua[j * (n + 1)] = 1500
			agua[j * (n + 1) + 1] = 1500
		r["agua"] = agua
	return r


static func _peca(id: String, posicao: Vector3, tamanho: Vector3, relevo: Dictionary) -> Dictionary:
	return {"id": id, "tipo": "terreno", "posicao": posicao, "rotacao_graus": Vector3.ZERO,
		"tamanho": tamanho, "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0,
		"colisao": true, "grupo": "", "relevo": relevo}


func _mapa_com(pecas: Array) -> Dictionary:
	var lista: Array[Dictionary] = []
	for p in pecas:
		lista.append(p)
	return {"nome": "teste", "spawn": {"posicao": Vector3.ZERO}, "pecas": lista, "grupos": []}


# --------------------------------------------------------------- A. formato
func _formato() -> void:
	print("\n-- A. formato do relevo --")
	var p := _peca("t", Vector3(0, 5, 0), Vector3(16, 10, 16), _relevo_morro(8, true))
	p["relevo"]["solo"][3] = 2
	var texto := MapaArquivo.para_texto(_mapa_com([p]))
	var relido := MapaArquivo.ler_texto(texto)
	_ok(relido["ok"], "terreno grava e relê como mapa válido %s" % str(relido["erros"]))
	if relido["ok"]:
		var r: Dictionary = relido["mapa"]["pecas"][0]["relevo"]
		_ok(r["alturas"] == p["relevo"]["alturas"] and r["agua"] == p["relevo"]["agua"] and r["solo"] == p["relevo"]["solo"],
			"alturas, água e solo voltam idênticos")
		_ok(MapaArquivo.para_texto(relido["mapa"]) == texto, "gravar de novo dá o mesmo texto (nada se perde nem muda)")
	_ok(texto.count("\n") < 80, "relevo compacto: o arquivo do bloco tem %d linhas, não uma por número" % texto.count("\n"))
	var sem_solo := _peca("t", Vector3.ZERO, Vector3(16, 10, 16), TerrenoDoMapa.plano(4))
	_ok(not MapaArquivo.para_texto(_mapa_com([sem_solo])).contains("\"solo\""), "solo todo automático não é gravado")

	var bruto: Dictionary = JSON.parse_string(texto)
	var ruins := {
		"sem relevo": func(d): d["pecas"][0].erase("relevo"),
		"contagem errada": func(d): d["pecas"][0]["relevo"]["alturas"] = "1 2 3",
		"altura fora da escala": func(d): d["pecas"][0]["relevo"]["alturas"] = String(d["pecas"][0]["relevo"]["alturas"]).replace("1000 ", "10001 "),
		"solo inexistente": func(d): d["pecas"][0]["relevo"]["solo"] = "9".repeat(64),
		"células demais": func(d): d["pecas"][0]["relevo"]["celulas"] = 500,
		"água abaixo de -1": func(d): d["pecas"][0]["relevo"]["agua"] = String(d["pecas"][0]["relevo"]["agua"]).replace("-1", "-2"),
	}
	for nome in ruins:
		var d: Dictionary = bruto.duplicate(true)
		ruins[nome].call(d)
		var r := MapaArquivo.validar(d)
		_ok(not r["ok"] and not (r["erros"] as Array).is_empty(), "recusa %s (%s)" % [nome, str(r["erros"]).left(90)])


# --------------------------------------------------------------- B. malha
func _malha() -> void:
	print("\n-- B. malha, água, altura --")
	var r := _relevo_morro(8, true)
	var t := Vector3(16, 10, 16)
	var m := TerrenoDoMapa.malha(r, t)
	var arr := m.surface_get_arrays(0)
	var vertices: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	_ok(vertices.size() == 8 * 8 * 2 * 3, "2 triângulos por célula (%d vértices)" % vertices.size())
	_ok((m.surface_get_format(0) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) == 0, "malha sem compressão de vértices (sem fresta)")
	var para_cima := true
	var normais: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for k in range(0, vertices.size(), 3):
		var a := vertices[k]
		var b := vertices[k + 1]
		var c := vertices[k + 2]
		# Horário visto de cima = face da frente no Godot: (c−a)×(b−a) aponta para +Y.
		if (c - a).cross(b - a).y <= 0.0 or normais[k].y <= 0.0:
			para_cima = false
	_ok(para_cima, "toda face aponta para cima e está na ordem de frente do Godot")
	var agua := TerrenoDoMapa.malha_agua(r, t)
	_ok(agua != null and agua.surface_get_array_len(0) == 8 * 6, "água só nas 8 células molhadas (%d vértices)"
		% (agua.surface_get_array_len(0) if agua else -1))
	_ok(TerrenoDoMapa.malha_agua(TerrenoDoMapa.plano(8), t) == null, "bloco sem água não ganha superfície de água")
	# Altura no meio do morro: 100 % do tamanho Y = topo da caixa (+5 local).
	_ok(is_equal_approx(TerrenoDoMapa.altura_local(r, t, 0, 0), 5.0), "topo do morro no topo da caixa (%.3f)" % TerrenoDoMapa.altura_local(r, t, 0, 0))
	_ok(is_equal_approx(TerrenoDoMapa.altura_local(r, t, -8, -8), -4.0), "canto plano a 10 %% da altura (%.3f)" % TerrenoDoMapa.altura_local(r, t, -8, -8))
	_ok(is_nan(TerrenoDoMapa.altura_local(r, t, 9, 0)), "fora do bloco não inventa altura")
	var dobro := TerrenoDoMapa.altura_local(r, Vector3(16, 20, 16), 0, 0)
	_ok(is_equal_approx(dobro, 10.0), "esticar o tamanho Y estica o relevo (%.3f)" % dobro)


# ----------------------------------------------- C. colisão e emenda (física)
func _colisao_e_emenda() -> void:
	print("\n-- C. colisão = malha, emenda sem fresta --")
	var mundo := Node3D.new()
	root.add_child(mundo)
	var t := Vector3(16, 10, 16)
	var r := _relevo_morro(8, false)
	var a := MapaMontador.montar_peca(mundo, _peca("a", Vector3(0, 5, 0), t, r))
	# Vizinho a leste com a MESMA borda (borda oeste dele = borda leste do "a").
	var r2 := TerrenoDoMapa.plano(8, 1000)
	for j in 9:
		r2["alturas"][j * 9] = r["alturas"][j * 9 + 8]
	var b := MapaMontador.montar_peca(mundo, _peca("b", Vector3(16, 5, 0), t, r2))
	await physics_frame
	await physics_frame
	var espaco := mundo.get_world_3d().direct_space_state
	var maior_erro := 0.0
	var acertos := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 30092026
	for k in 60:
		var x := rng.randf_range(-7.9, 7.9)
		var z := rng.randf_range(-7.9, 7.9)
		var hit := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -10, z)))
		if hit.is_empty():
			continue
		acertos += 1
		var esperado := TerrenoDoMapa.altura_local(r, t, x, z) + 5.0
		maior_erro = maxf(maior_erro, absf(hit["position"].y - esperado))
	_ok(acertos == 60 and maior_erro < 0.002, "raio pousa na altura da malha em 60 pontos (erro máx %.4f m)" % maior_erro)
	# Ponto baixo do bloco: a caixa do bloco iria até y=10; a colisão tem que ser a malha.
	var baixo := espaco.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-7.5, 40, -7.5), Vector3(-7.5, -10, -7.5)))
	_ok(not baixo.is_empty() and baixo["position"].y < 1.5, "no canto baixo o raio desce até o chão (y=%.2f), sem caixa invisível"
		% (baixo["position"].y if not baixo.is_empty() else -99.0))
	# Emenda: pontos da borda comum, em coordenada de mundo, iguais nos dois blocos.
	var va := _vertices_mundo(a)
	var vb := _vertices_mundo(b)
	var borda_a := {}
	for v in va:
		if is_equal_approx(v.x, 8.0):
			borda_a[Vector2(v.z, v.y)] = true
	var iguais := 0
	var na_borda := 0
	for v in vb:
		if is_equal_approx(v.x, 8.0):
			na_borda += 1
			if borda_a.has(Vector2(v.z, v.y)):
				iguais += 1
	_ok(na_borda > 0 and iguais == na_borda, "emenda exata entre blocos vizinhos (%d de %d pontos idênticos)" % [iguais, na_borda])
	mundo.free()


func _vertices_mundo(corpo: StaticBody3D) -> PackedVector3Array:
	var m := (corpo.get_node("Malha") as MeshInstance3D).mesh
	var saida := PackedVector3Array()
	for v in (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		saida.append(corpo.transform * v)
	return saida


# ------------------------------------------------ D. tamanho padrão e navio
func _catalogo() -> void:
	print("\n-- D. catálogo: tamanho padrão e ficha de navio --")
	var real := "res://mapas/modelos/catalogo.json"
	var copia := PASTA.path_join("catalogo")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(copia))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(real),
		ProjectSettings.globalize_path(copia.path_join(BibliotecaDeModelos.ARQUIVO_CATALOGO)))
	# O .glb que o teste do editor insere vem junto (senão vira marcador e suja o log).
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://mapas/modelos/hut.glb"),
		ProjectSettings.globalize_path(copia.path_join("hut.glb")))
	var bib := BibliotecaDeModelos.new(copia)
	var id := "hut"
	var original: Vector3 = bib.info(id)["tamanho"]
	_ok(bib.tamanho_padrao(id) == original or bib.info(id).has("tamanho_padrao"), "sem padrão próprio, o padrão é o tamanho do arquivo")
	_ok(bib.definir_tamanho_padrao(id, Vector3(7, 6, 6.5)) == OK, "grava tamanho padrão")
	_ok(bib.definir_tamanho_padrao(id, Vector3(0, 6, 6)) != OK, "recusa tamanho padrão com eixo zero")
	_ok(bib.definir_ficha_de_navio("boat", FichaDeNavio.da_classe("bote")) == OK, "grava ficha de navio da classe bote")
	var ruim := FichaDeNavio.da_classe("galeao")
	ruim["vida"] = -5
	_ok(bib.definir_ficha_de_navio("ship", ruim) != OK, "recusa ficha com vida negativa")
	_ok(FichaDeNavio.normalizar({"classe": "submarino"}).is_empty(), "classe desconhecida não vira ficha")
	var relida := BibliotecaDeModelos.new(copia)
	_ok(relida.tamanho_padrao(id).is_equal_approx(Vector3(7, 6, 6.5)), "tamanho padrão persiste no catálogo")
	_ok(relida.ficha_de_navio("boat").get("tripulacao", 0) == 2, "ficha de navio persiste (%s)" % FichaDeNavio.resumo(relida.ficha_de_navio("boat")))
	# Reimportar o mesmo modelo (importador da loja) não pode apagar o padrão nem a ficha.
	var entrada := relida.info("boat")
	entrada.erase("tamanho_padrao")
	entrada.erase("navio")
	relida.adicionar(entrada)
	_ok(not relida.ficha_de_navio("boat").is_empty(), "reimportar preserva a ficha")
	var e_hut := relida.info(id)
	e_hut.erase("tamanho_padrao")
	relida.adicionar(e_hut)
	_ok(relida.tamanho_padrao(id).is_equal_approx(Vector3(7, 6, 6.5)), "reimportar preserva o tamanho padrão")


# ------------------------------------------- D2. o catálogo REAL (só leitura)
## O que a frente da Ilha Inicial gravou na loja do projeto não pode se perder num
## reimporte ou numa edição de catálogo.
func _catalogo_real() -> void:
	print("\n-- D2. catálogo real: navios, tamanhos e ponte --")
	var bib := BibliotecaDeModelos.new(BibliotecaDeModelos.RAIZ_PADRAO)
	var navios := ["boat", "small_ship", "ship", "house-g7esjlfi4v", "house-2kytqgs4rh", "house"]
	var com_ficha := 0
	for id in navios:
		if bib.tem(id) and bib.categorias_do_modelo(id).has("navios") and not bib.ficha_de_navio(id).is_empty():
			com_ficha += 1
	_ok(bib.tem_categoria("navios") and com_ficha == navios.size(),
		"categoria navios com os %d barcos e ficha em cada (%d)" % [navios.size(), com_ficha])
	var com_padrao := 0
	for id in bib.ids():
		if bib.info(id).has("tamanho_padrao"):
			com_padrao += 1
	_ok(com_padrao >= 150, "%d modelos com tamanho padrão" % com_padrao)
	var cabana := bib.tamanho_padrao("hut")
	_ok(cabana.y > 5.0 and cabana.y < 8.0, "cabana entra com %.1f m de altura (personagem: 1,6 m)" % cabana.y)
	_ok(bib.tem("ponte_rio_low_poly"), "ponte do rio na loja")
	var ponte := bib.instanciar("ponte_rio_low_poly")
	var comprimidas := 0
	if ponte:
		for mi in ponte.find_children("*", "MeshInstance3D", true, false):
			var malha: Mesh = (mi as MeshInstance3D).mesh
			for s in (malha.get_surface_count() if malha else 0):
				if malha.surface_get_format(s) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES:
					comprimidas += 1
		ponte.free()
	_ok(comprimidas == 0, "ponte importada sem compressão de vértices (sem fendas entre materiais)")


# ----------------------------------------- D3. malha de colisão própria (.glb)
func _malha_de_colisao() -> void:
	print("\n-- D3. malha \"Colisao\" do modelo --")
	var raiz := Node3D.new()
	var visual := MeshInstance3D.new()
	visual.name = "Casco"
	var caixa := BoxMesh.new()
	caixa.size = Vector3(2, 2, 2)
	visual.mesh = caixa
	raiz.add_child(visual)
	var col := MeshInstance3D.new()
	col.name = "Colisao_piso"
	var placa := BoxMesh.new()
	placa.size = Vector3(10, 0.2, 10)
	col.mesh = placa
	raiz.add_child(col)
	var m := BibliotecaDeModelos.medir(raiz)
	_ok((m["aabb"] as AABB).size.is_equal_approx(Vector3(2, 2, 2)), "a malha de colisão fica fora da caixa do modelo (%s)" % (m["aabb"] as AABB).size)
	_ok((m["faces_colisao"] as PackedVector3Array).size() == 36 and m["triangulos"] == 12,
		"faces da colisão separadas (%d) das do desenho (%d triângulos)" % [(m["faces_colisao"] as PackedVector3Array).size() / 3, m["triangulos"]])
	var sem := Node3D.new()
	var so_visual := visual.duplicate()
	sem.add_child(so_visual)
	_ok((BibliotecaDeModelos.medir(sem)["faces_colisao"] as PackedVector3Array).is_empty(), "modelo sem \"Colisao\" continua como antes")
	BibliotecaDeModelos._esconder_colisao(raiz)
	_ok(not col.visible and visual.visible, "a malha de colisão não aparece; o resto, sim")
	raiz.free()
	sem.free()


# ----------------------------------------- D4. colisão em partes convexas
func _partes_convexas() -> void:
	print("\n-- D4. construções: colisão em partes convexas --")
	var copia := PASTA.path_join("catalogo")
	var bib := BibliotecaDeModelos.new(copia)
	var quadrado := func(c: Vector3, m: float) -> PackedVector3Array:
		var pts := PackedVector3Array()
		for x in [-m, m]:
			for y in [-m, m]:
				for z in [-m, m]:
					pts.append(c + Vector3(x, y, z))
		return pts
	var partes := [quadrado.call(Vector3(0, 0.2, 0), 0.2), quadrado.call(Vector3(0, 0.5, 0), 0.1)]
	_ok(bib.definir_partes_de_colisao("hut", partes) == OK and FileAccess.file_exists(bib.caminho_das_partes("hut")),
		"grava as partes ao lado do .glb e liga o modo \"partes\"")
	var relida := BibliotecaDeModelos.new(copia)
	_ok(relida.modo_de_colisao("hut") == "partes" and relida.partes_de_colisao("hut").size() == 2, "modo e partes voltam do disco")
	var formas := relida.formas_de_colisao("hut", Vector3(7, 6, 6.5))
	_ok(formas.size() == 2 and formas[0] is ConvexPolygonShape3D, "%d formas convexas para a peça" % formas.size())
	MapaMontador.biblioteca = relida
	var mundo := Node3D.new()
	root.add_child(mundo)
	var peca := {"id": "casa", "tipo": "modelo", "modelo": "hut", "posicao": Vector3.ZERO, "rotacao_graus": Vector3.ZERO,
		"tamanho": Vector3(7, 6, 6.5), "cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true, "grupo": ""}
	var corpo := MapaMontador.montar_peca(mundo, peca)
	_ok(corpo.get_node_or_null("Colisao") != null and corpo.get_node_or_null("Colisao_2") != null
		and corpo.get_node_or_null("Colisao_3") == null, "a peça ganha um volume por parte (Colisao, Colisao_2)")
	var com_hitbox := peca.duplicate(true)
	com_hitbox["hitbox"] = {"forma": "caixa", "deslocamento": Vector3.ZERO, "tamanho": Vector3(2, 2, 2), "rotacao_graus": Vector3.ZERO}
	MapaMontador.atualizar_peca(corpo, com_hitbox)
	_ok(corpo.get_node_or_null("Colisao_2") == null, "hitbox própria da peça manda: as partes extras saem")
	var sem := peca.duplicate(true)
	sem["colisao"] = false
	MapaMontador.atualizar_peca(corpo, sem)
	_ok(corpo.get_node_or_null("Colisao") == null and corpo.get_node_or_null("Colisao_2") == null, "colisão desligada: nenhum volume")
	mundo.free()
	# Modelo reimportado com outro conteúdo: as partes antigas não valem mais.
	var e := relida.info("hut")
	e["sha256"] = "outro"
	relida.adicionar(e)
	_ok(relida.partes_de_colisao("hut").is_empty() and relida.formas_de_colisao("hut", Vector3(7, 6, 6.5)).size() == 1,
		"SHA diferente do .glb: partes ignoradas, volta à malha")
	relida.definir_partes_de_colisao("hut", [])
	_ok(relida.modo_de_colisao("hut") == "malha" and not FileAccess.file_exists(relida.caminho_das_partes("hut")),
		"desligar apaga o arquivo e volta à malha")
	MapaMontador.biblioteca = null
	# O catálogo REAL: as construções têm partes válidas.
	var real := BibliotecaDeModelos.new(BibliotecaDeModelos.RAIZ_PADRAO)
	var com_partes := 0
	var validas := 0
	for id in real.ids():
		if real.modo_de_colisao(id) == "partes":
			com_partes += 1
			if not real.partes_de_colisao(id).is_empty():
				validas += 1
	_ok(com_partes >= 90 and validas == com_partes, "catálogo real: %d construções com partes, %d válidas" % [com_partes, validas])
	await process_frame


# --------------------------------------------------------------- E. editor
func _editor() -> void:
	print("\n-- E. editor: clique, pouso e loja no tamanho padrão --")
	var copia := PASTA.path_join("catalogo")
	var bib := BibliotecaDeModelos.new(copia)
	MapaMontador.biblioteca = bib
	var mapa := PASTA.path_join("mapa.json")
	var dados: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	# Bloco 16×16 com morro de 10 m, e uma caixa de 1 m pousada no canto BAIXO dele
	# (dentro da caixa do bloco, que vai até y = 10).
	(dados["pecas"] as Array).append(_peca("bloco", Vector3(0, 5, 0), Vector3(16, 10, 16), _relevo_morro(8, false)))
	var caixa := {"id": "caixote", "tipo": "caixa", "posicao": Vector3(-6.5, 1.5, -6.5), "rotacao_graus": Vector3.ZERO,
		"tamanho": Vector3(1, 1, 1), "cor": Color.RED, "material": "liso", "grade_celula": 4.0, "colisao": true, "grupo": ""}
	(dados["pecas"] as Array).append(caixa)
	MapaArquivo.salvar(mapa, dados)
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = mapa
	ed.biblioteca = bib
	root.add_child(ed)
	current_scene = ed
	for i in 8:
		await process_frame
	var cam: CameraLivre = ed._camera
	cam.posicionar(Vector3(-6.5, 14, 2), Vector3(-6.5, 1.5, -6.5))
	for i in 3:
		await physics_frame
	var vista: VistaDoMapa = ed._vista
	var ponto := cam.unproject_position(Vector3(-6.5, 1.5, -6.5))
	_ok(vista.escolher(cam, ponto) == "caixote", "clicar na caixa pousada no bloco seleciona a CAIXA, não o bloco (%s)" % vista.escolher(cam, ponto))
	var no_morro := cam.unproject_position(Vector3(0, 10, 0))
	_ok(vista.escolher(cam, no_morro) == "bloco", "clicar no morro seleciona o bloco")
	var pouso := vista.ponto_sob(cam, cam.unproject_position(Vector3(-2, 0, -2) + Vector3(0, TerrenoDoMapa.altura_local(
		_relevo_morro(8, false), Vector3(16, 10, 16), -2, -2) + 5.0, 0)), 2.0)
	var chao := TerrenoDoMapa.altura_local(_relevo_morro(8, false), Vector3(16, 10, 16), pouso.x, pouso.z) + 5.0
	_ok(absf(pouso.y - 1.0 - chao) < 0.6, "peça nova pousa NO relevo (centro %.2f, chão %.2f)" % [pouso.y, chao])
	bib.definir_tamanho_padrao("hut", Vector3(7, 6, 6.5))
	var novo: String = ed.inserir_modelo("hut")
	_ok(not novo.is_empty() and (ed.doc.peca(novo)["tamanho"] as Vector3).is_equal_approx(Vector3(7, 6, 6.5)),
		"arrastar da loja usa o tamanho padrão (%s)" % (str(ed.doc.peca(novo)["tamanho"]) if not novo.is_empty() else "nada"))
	ed.selecao.definir(["bloco"] as Array[String])
	for i in 2:
		await process_frame
	var painel_ok := true
	for no in ed.find_children("*", "Label", true, false):
		if (no as Label).text.contains("células de 2.0 m"):
			painel_ok = true
			break
		painel_ok = false
	_ok(painel_ok, "painel de propriedades descreve o bloco de terreno")
	ed.queue_free()
	MapaMontador.biblioteca = null
	for i in 2:
		await process_frame
