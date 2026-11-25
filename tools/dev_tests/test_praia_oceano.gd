extends SceneTree
## Contratos de asset, física e atualização real do documento/editor.
const OCEANO := preload("res://src/world/oceano_historia.gd")
var falhas := 0

func _initialize() -> void:
	_executar.call_deferred()

func verificar(condicao: bool, mensagem: String) -> void:
	print(("PASS " if condicao else "FAIL ") + mensagem)
	if not condicao:
		falhas += 1

func _executar() -> void:
	var mapa: Dictionary = MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")["mapa"]
	var mundo := Node3D.new()
	root.add_child(mundo)
	var bib := BibliotecaDeModelos.padrao()
	verificar(bib.tem("areia_praia_low_poly") and bib.categorias_do_modelo("areia_praia_low_poly").has("praia_mapa"), "areia disponível em praia mapa")
	var areia := bib.instanciar("areia_praia_low_poly")
	var medidas := BibliotecaDeModelos.medir(areia)
	verificar(medidas["triangulos"] == 550, "areia tem 550 triângulos")
	verificar((medidas["aabb"] as AABB).size.is_equal_approx(Vector3(32, 1.8, 24)), "escala em metros: 32 × 1,8 × 24")
	# Cada cor é uma superfície; comprimida, cada uma quantiza os vértices pelo próprio
	# AABB e abre fendas entre as cores (pontinhos pretos na areia, 30/09/2026).
	var comprimidas := 0
	for mi in areia.find_children("*", "MeshInstance3D", true, false):
		var malha: Mesh = (mi as MeshInstance3D).mesh
		for s in (malha.get_surface_count() if malha else 0):
			if malha.surface_get_format(s) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES:
				comprimidas += 1
	verificar(comprimidas == 0, "areia importada sem compressão de vértices (sem fendas entre cores)")
	areia.free()
	var dados := {"id": "areia_teste", "tipo": "modelo", "modelo": "areia_praia_low_poly",
		"posicao": Vector3(0, 5, 0), "rotacao_graus": Vector3.ZERO, "tamanho": Vector3(32, 1.8, 24),
		"cor": Color.WHITE, "material": "liso", "grade_celula": 4.0, "colisao": true}
	MapaMontador.montar_peca(mundo, dados)
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 10, 0), Vector3(0, 0, 0), 1)
	var hit := mundo.get_world_3d().direct_space_state.intersect_ray(ray)
	verificar(not hit.is_empty() and hit["position"].y > 4.8 and hit["position"].y < 5.4, "raycast acerta o relevo da areia, sem caixa invisível")
	var doc := DocumentoMapa.de_mapa(mapa)
	var vista := VistaDoMapa.new()
	mundo.add_child(vista)
	vista.ligar(doc)
	var oceano = vista.get_node("Oceano")
	verificar(oceano.visible and oceano.bases.size() == 1, "editor monta oceano com a baseplate")
	verificar(is_equal_approx(oceano.nivel, -0.65), "nível abaixo do topo da ilha")
	verificar(is_equal_approx(oceano.distancia_da_costa(Vector2(260, 0)), 4.0), "água rasa: 4 m além da base")
	verificar(is_equal_approx(oceano.distancia_da_costa(Vector2(456, 0)), 200.0), "mar aberto: 200 m além da base")
	verificar(oceano.distancia_da_costa(Vector2(260, 260)) > 5.6, "canto usa distância euclidiana")
	var p := doc.peca("baseplate")
	p["posicao"] = Vector3(100, -1, 0)
	p["tamanho"] = Vector3(80, 2, 40)
	p["rotacao_graus"] = Vector3(0, 90, 0)
	doc.definir_peca("baseplate", p)
	await process_frame
	verificar(is_equal_approx(oceano.distancia_da_costa(Vector2(130, 0)), 10.0), "mover/escalar/girar atualiza costa no editor")
	p = p.duplicate(true)
	p["id"] = "baseplate_1"
	p["posicao"] = Vector3(-200, -1, 0)
	doc.definir_peca("baseplate_1", p)
	await process_frame
	verificar(oceano.bases.size() == 2 and is_equal_approx(oceano.distancia_da_costa(Vector2(-170, 0)), 10.0), "duplicata define segunda ilha e costa própria")
	doc.remover_peca("baseplate")
	doc.remover_peca("baseplate_1")
	await process_frame
	verificar(not oceano.visible, "remover todas as bases oculta oceano")
	doc.definir_peca("baseplate_1", p)
	await process_frame
	verificar(oceano.visible and oceano.get_child_count() == 1, "restaurar base reusa superfície sem duplicar")
	verificar(oceano.find_children("*", "CollisionObject3D", true, false).is_empty(), "água não cria piso sólido invisível")
	print("PRAIA_RESULTADO falhas=", falhas)
	mundo.free()
	quit(1 if falhas else 0)
