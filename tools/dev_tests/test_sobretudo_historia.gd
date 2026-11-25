extends SceneTree
## Sobretudo e estampa de imagem na customização do Modo História (19/11/2026).
##   godot --headless --path . --script tools/dev_tests/test_sobretudo_historia.gd
var _falhas := 0


func _init() -> void:
	call_deferred("_executar")


func _ok(c: bool, m: String) -> void:
	print(("  ✅ " if c else "  ❌ ") + m)
	if not c:
		_falhas += 1


func _cor_da_peca(peca: Node, parte: String) -> Color:
	for m: MeshInstance3D in peca.find_children("*", "MeshInstance3D", true, false):
		for i in m.mesh.get_surface_count():
			var nome := m.mesh.surface_get_material(i).resource_name
			if nome.contains(parte):
				var mat := m.get_surface_override_material(i)
				return (mat as BaseMaterial3D).albedo_color if mat is BaseMaterial3D else (mat as ShaderMaterial).get_shader_parameter("cor") as Color
	return Color(-1, -1, -1)


func _executar() -> void:
	var Cat = load("res://src/player/aparencia_historia.gd")
	var Corpo = load("res://src/player/corpo_historia.gd")
	print("\n-- catálogo e validação --")
	_ok(Cat.normalizar({"roupa": "sobretudo"}).roupa == "sobretudo", "a roupa 'sobretudo' existe no catálogo")
	for ruim in ["../../etc/passwd", "ABCDEF0123456789", "abc", "0123456789abcdeg", "0123456789abcdef0", 42, null]:
		_ok(Cat.normalizar({"estampa": ruim}).estampa == "original", "id de estampa inválido é descartado (%s)" % str(ruim))
	_ok(Cat.normalizar({"estampa": "0123456789abcdef"}).estampa == "0123456789abcdef", "id de 16 hex é aceito")
	_ok(EstampasHistoria.caminho_do_id("../x").is_empty() and EstampasHistoria.caminho_do_id("0123456789abcdef").begins_with("user://estampas/"), "só um id válido vira caminho, e dentro da pasta de estampas")
	_ok(Cat.cor_do_sobretudo({}) == Color(Cat.COR_DO_SOBRETUDO) and Cat.cor_do_sobretudo({"cor_roupa": "azul"}) == Color(Cat.CORES_ROUPA.azul), "cor do sobretudo: cinza da referência, ou a cor da roupa")

	print("\n-- importar imagem --")
	_ok(EstampasHistoria.importar("/tmp/nao_existe.png").is_empty() and EstampasHistoria.ultimo_erro != "", "arquivo inexistente é recusado com motivo")
	_ok(EstampasHistoria.importar("/etc/passwd").is_empty(), "arquivo que não é imagem (extensão) é recusado")
	var grande := Image.create(1000, 500, false, Image.FORMAT_RGBA8)
	grande.fill(Color(0.8, 0.1, 0.1, 1))
	var origem := ProjectSettings.globalize_path("user://teste_estampa_origem.png")
	grande.save_png(origem)
	var id := EstampasHistoria.importar(origem)
	_ok(Cat.id_de_estampa_valido(id) and EstampasHistoria.existe(id), "uma imagem válida vira uma estampa guardada (%s)" % id)
	var t := EstampasHistoria.textura(id)
	_ok(t != null and maxi(t.get_width(), t.get_height()) == EstampasHistoria.LADO_GUARDADO and is_equal_approx(EstampasHistoria.proporcao(id), 2.0), "é reduzida a %d px mantendo a proporção (%dx%d)" % [EstampasHistoria.LADO_GUARDADO, t.get_width() if t else 0, t.get_height() if t else 0])
	_ok(EstampasHistoria.importar(origem) == id, "a mesma imagem dá o mesmo id (não duplica)")
	_ok(EstampasHistoria.textura("0000000000000000") == null, "id válido sem arquivo: sem estampa, sem erro")

	print("\n-- corpo com sobretudo (masculino e feminino) --")
	for tipo in ["masculino", "feminino"]:
		var base: Node3D = Corpo.construir(tipo, "medio", {})["node"]
		_ok(base.find_children("Sobretudo_*", "Node3D", true, false).is_empty() and base.find_child("EstampaDaRoupa", true, false) == null, "%s sem opção: nada de sobretudo nem estampa" % tipo)
		base.free()
		var raiz: Node3D = Corpo.construir(tipo, "medio", {"roupa": "sobretudo", "cor_roupa": "azul", "estampa": id, "estampa_local": "costas"})["node"]
		var peito := raiz.find_child("Chest", true, false)
		var quadril := raiz.find_child("Torso", true, false)
		_ok(peito.get_node_or_null("Sobretudo_tronco") != null, "%s: tronco no Chest (ombros e costas)" % tipo)
		_ok(quadril.get_node_or_null("Sobretudo_saia") != null, "%s: saia no Torso (fixa, não balança com as pernas)" % tipo)
		var mangas := 0
		for lado in ["L", "R"]:
			mangas += int(raiz.find_child("UpperArm_" + lado, true, false).get_node_or_null("Sobretudo_manga_sup") != null)
			mangas += int(raiz.find_child("ForeArm_" + lado, true, false).get_node_or_null("Sobretudo_manga_inf") != null)
		_ok(mangas == 4, "%s: 4 mangas (braço e antebraço dos dois lados)" % tipo)
		var tronco := peito.get_node("Sobretudo_tronco")
		var cor: Color = Color(Cat.CORES_ROUPA.azul)
		_ok(_cor_da_peca(tronco, "Manto").is_equal_approx(cor), "%s: a cor da roupa vale para o sobretudo" % tipo)
		_ok(_cor_da_peca(tronco, "Forro").v < cor.v and _cor_da_peca(raiz.find_child("ForeArm_L", true, false).get_node("Sobretudo_manga_inf"), "Punho").v > cor.v, "%s: forro mais escuro e punho mais claro" % tipo)
		var est := peito.get_node_or_null("EstampaDaRoupa") as MeshInstance3D
		_ok(est != null and est.position.z > 0.14, "%s: a estampa fica atrás, por cima do sobretudo (z %.3f)" % [tipo, est.position.z if est else 0.0])
		_ok(est != null and (est.mesh as QuadMesh).size.x > (est.mesh as QuadMesh).size.y, "%s: a estampa mantém a proporção 2:1" % tipo)
		raiz.free()
		var so_peito: Node3D = Corpo.construir(tipo, "medio", {"estampa": id, "estampa_local": "peito"})["node"]
		var e2 := so_peito.find_child("EstampaDaRoupa", true, false) as MeshInstance3D
		_ok(e2 != null and e2.position.z < -0.1 and so_peito.find_children("Sobretudo_*", "Node3D", true, false).is_empty(), "%s: estampa no peito sem sobretudo (z %.3f)" % [tipo, e2.position.z if e2 else 0.0])
		so_peito.free()

	print("\n-- fichas 'AA Roupas': moletom, calça branca larga, sapatos, cueca, óculos --")
	for tipo in ["masculino", "feminino"]:
		var conj: Node3D = Corpo.construir(tipo, "medio", {"roupa": "moletom", "calca": "pregueada", "sapatos": "pretos", "oculos": "escuros", "roupa_intima": "cueca"})["node"]
		var n := func(no: String, nome: String) -> bool: return conj.find_child(no, true, false).get_node_or_null(nome) != null
		_ok(n.call("Chest", "Moletom_moletom_tronco") and n.call("UpperArm_L", "Moletom_moletom_manga_sup") and n.call("ForeArm_R", "Moletom_moletom_manga_inf"), "%s: moletom no peito e nas mangas" % tipo)
		_ok(n.call("Torso", "Calca_calca_cintura") and n.call("Thigh_L", "Calca_calca_coxa") and n.call("Shin_R", "Calca_calca_canela"), "%s: calça branca larga em cintura, coxas e canelas" % tipo)
		_ok(n.call("Foot_L", "Sapato_sapato") and n.call("Foot_R", "Sapato_sapato"), "%s: sapatos pretos nos dois pés" % tipo)
		_ok(n.call("Head", "Oculos_oculos"), "%s: óculos escuros na cabeça" % tipo)
		_ok(n.call("Torso", "Cueca_cueca_quadril") and n.call("Thigh_R", "Cueca_cueca_coxa"), "%s: cueca no quadril e nas coxas" % tipo)
		_ok(_cor_da_peca(conj.find_child("Chest", true, false).get_node("Moletom_moletom_tronco"), "Principal").is_equal_approx(Color(Cat.COR_DO_MOLETOM)), "%s: moletom preto por padrão" % tipo)
		_ok(_cor_da_peca(conj.find_child("Thigh_L", true, false).get_node("Calca_calca_coxa"), "Principal").is_equal_approx(Color(Cat.COR_DA_CALCA_BRANCA)), "%s: calça branca por padrão" % tipo)
		conj.free()
		var tingido: Node3D = Corpo.construir(tipo, "medio", {"roupa": "moletom", "cor_roupa": "vermelho", "calca": "pregueada", "cor_calca": "azul"})["node"]
		_ok(_cor_da_peca(tingido.find_child("Chest", true, false).get_node("Moletom_moletom_tronco"), "Principal").is_equal_approx(Color(Cat.CORES_ROUPA.vermelho)) and _cor_da_peca(tingido.find_child("Thigh_L", true, false).get_node("Calca_calca_coxa"), "Principal").is_equal_approx(Color(Cat.CORES_ROUPA.azul)), "%s: 'cor da roupa' pinta o moletom e 'cor da calça' pinta a calça" % tipo)
		tingido.free()
	_ok(Cat.normalizar({"oculos": "x", "roupa_intima": 3}).oculos == "original", "óculos/roupa de baixo inválidos voltam ao original")

	print("\n-- acessórios importados do customizador antigo --")
	var antigos := ["chapeu_palha", "aureola", "coroa", "cartola", "mascara_caveira", "mascara_peste", "mascara_covid", "chinelo", "capa_marinha", "luffy_camisa", "luffy_calcao", "espadas_zoro"]
	var no_catalogo := 0
	for categoria in Cat.OPCOES:
		if str(categoria).begins_with("acc_"):
			for aid in Cat.OPCOES[categoria]:
				if aid in Cat.ACESSORIOS_NOVOS:
					# Peças modeladas a partir das imagens do Codex (tools/blender/customizacao_codex.py): fora do catálogo antigo, mas o GLB e o encaixe precisam existir.
					_ok(FileAccess.file_exists(Acessorios.BASE + aid + ".glb") and preload("res://src/player/detalhes_historia.gd").ENCAIXE_DE_ACESSORIOS.has(aid), "'%s' (novo) tem GLB e encaixe" % aid)
				elif aid != "original":
					no_catalogo += 1
					_ok(Acessorios.CATALOGO.has(aid) and Acessorios.parte_de(aid) == str(categoria).trim_prefix("acc_"), "'%s' é do catálogo antigo e está na parte certa (%s)" % [aid, categoria])
	_ok(no_catalogo == antigos.size(), "os %d acessórios do menu antigo (fora cabelo e boca) foram importados (%d)" % [antigos.size(), no_catalogo])
	for tipo in ["masculino", "feminino"]:
		var todos := {"acc_cabeca": "chapeu_palha", "acc_rosto": "mascara_caveira", "acc_costas": "capa_marinha", "acc_tronco": "luffy_camisa", "acc_cintura": "espadas_zoro", "acc_pernas": "luffy_calcao", "acc_pes": "chinelo"}
		var vestido: Node3D = Corpo.construir(tipo, "medio", todos)["node"]
		var achados := vestido.find_children("Acessorio_*", "Node3D", true, false)
		var ids := {}
		for no in achados:
			ids[str(no.get_meta("acessorio_historia", ""))] = true
		for aid in ["chapeu_palha", "mascara_caveira", "capa_marinha", "luffy_camisa", "espadas_zoro", "luffy_calcao", "chinelo"]:
			_ok(ids.has(aid), "%s: '%s' aparece no corpo" % [tipo, aid])
		_ok(vestido.find_child("Foot_L", true, false).get_node_or_null("Acessorio_chinelo") != null and vestido.find_child("Foot_R", true, false).get_node_or_null("Acessorio_chinelo") != null, "%s: um chinelo em cada pé" % tipo)
		_ok(vestido.find_child("Thigh_L", true, false).get_node_or_null("Acessorio_luffy_calcao_tecido") != null, "%s: calção pendura nas coxas (acompanha as pernas)" % tipo)
		vestido.free()
	for aid in ["aureola", "coroa", "cartola", "mascara_peste", "mascara_covid"]:
		var c: Node3D = Corpo.construir("masculino", "medio", {"acc_cabeca" if Acessorios.parte_de(aid) == "cabeca" else "acc_rosto": aid})["node"]
		_ok(c.find_child("Head", true, false).get_node_or_null("Acessorio_" + aid) != null, "'%s' aparece na cabeça" % aid)
		c.free()
	_ok(Cat.normalizar({"acc_cabeca": "mascara_caveira"}).acc_cabeca == "original", "acessório na parte errada é descartado")

	print("\n-- a camisa de baixo não é tingida pela cor do sobretudo --")
	var Atlas = load("res://src/player/atlas_personalizado.gd")
	var com: Texture2D = Atlas.textura("masculino", "medio", {"roupa": "sobretudo", "cor_roupa": "vermelho"})
	var sem: Texture2D = Atlas.textura("masculino", "medio", {"roupa": "sobretudo"})
	_ok(com != null and sem != null and com.get_image().get_data() == sem.get_image().get_data(), "com sobretudo, 'cor da roupa' não muda o atlas (a cor vai para o casaco)")

	DirAccess.remove_absolute(origem)
	print("\n%s" % ("TUDO CERTO" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)
