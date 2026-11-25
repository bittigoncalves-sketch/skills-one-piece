extends SceneTree
# ============================================================================
#  TESTE DO EDITOR DE MAPA (etapa 2 do Modo História).
#
#  A. formas novas no arquivo e no montador;
#  A2. hitbox própria da peça: formato, validação e a forma de física que sai dela;
#  A3. editar a hitbox: campos do painel, desfazer e aplicar nas peças iguais;
#  A4. arrastar a hitbox pelo gizmo, inclusive com a peça girada;
#  B. documento + histórico (desfazer/refazer) + seleção, sem nó nenhum;
#  C. matemática do gizmo: arrastar X metros move X metros, girar gira, esticar a
#     face mantém a oposta parada;
#  D. o editor de verdade: sobe a cena, insere, move pelo gizmo, desfaz, salva,
#     testa com o jogador e volta.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_editor_mapa.gd
# ============================================================================

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== EDITOR DE MAPA =====")
	_formas()
	_hitbox()
	_hitbox_edicao()
	_hitbox_gizmo()
	_documento_e_historico()
	_selecao()
	_matematica()
	var editor_script := "res://src/editor_mapa/EditorDeMapa.gd"
	if ResourceLoader.exists(editor_script):
		await _editor_de_verdade()
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _mapa_com(pecas: Array) -> Dictionary:
	return {"formato": MapaArquivo.FORMATO, "versao": 1, "nome": "t",
		"spawn": {"posicao": [0, 1, 0]}, "pecas": pecas}


# ------------------------------------------------------------------ A. formas
func _formas() -> void:
	print("\n-- A. formas: esfera, cilindro, cunha --")
	var r := MapaArquivo.validar(_mapa_com([
		{"id": "e", "tipo": "esfera", "posicao": [0, 0, 0], "tamanho": [3, 3, 3]},
		{"id": "c", "tipo": "cilindro", "posicao": [5, 0, 0], "tamanho": [2, 6, 2]},
		{"id": "w", "tipo": "cunha", "posicao": [10, 0, 0], "tamanho": [4, 2, 3]},
	]))
	_ok(r["ok"], "as três formas válidas carregam %s" % str(r["erros"]))
	var esticada := MapaArquivo.validar(_mapa_com([{"id": "e", "tipo": "esfera", "posicao": [0, 0, 0], "tamanho": [3, 1, 3]}]))
	_ok(not esticada["ok"] and " ".join(esticada["erros"]).contains("x = y = z"), "esfera esticada é recusada")
	var oval := MapaArquivo.validar(_mapa_com([{"id": "c", "tipo": "cilindro", "posicao": [0, 0, 0], "tamanho": [2, 5, 3]}]))
	_ok(not oval["ok"] and " ".join(oval["erros"]).contains("x = z"), "cilindro oval é recusado")
	if not r["ok"]:
		return

	var raiz := Node3D.new()
	get_root().add_child(raiz)
	MapaMontador.montar(raiz, r["mapa"])
	var e := raiz.get_node("Mapa/e/Colisao") as CollisionShape3D
	var c := raiz.get_node("Mapa/c/Colisao") as CollisionShape3D
	var w := raiz.get_node("Mapa/w/Colisao") as CollisionShape3D
	_ok(e.shape is SphereShape3D and is_equal_approx((e.shape as SphereShape3D).radius, 1.5), "esfera: raio 1,5 para diâmetro 3")
	_ok(c.shape is CylinderShape3D and is_equal_approx((c.shape as CylinderShape3D).height, 6.0), "cilindro: altura 6")
	var aabb := (raiz.get_node("Mapa/w/Malha") as MeshInstance3D).get_aabb()
	_ok(w.shape is ConvexPolygonShape3D and aabb.size.is_equal_approx(Vector3(4, 2, 3)), "cunha: forma convexa e malha 4 × 2 × 3")
	# A rampa tem que ser a MESMA na malha e na colisão: face em pé em −X.
	var pontos := (w.shape as ConvexPolygonShape3D).points
	var topo_em_menos_x := true
	for pt in pontos:
		if pt.y > 0.0 and pt.x > -1.99:
			topo_em_menos_x = false
	_ok(topo_em_menos_x, "cunha: os vértices de cima ficam todos em −X (rampa desce para +X)")

	# Arrastar só a posição NÃO pode recriar malha e forma (é chamado a cada
	# movimento do mouse); mudar o tamanho tem que recriar.
	var corpo := raiz.get_node("Mapa/e") as StaticBody3D
	var malha_antes := (corpo.get_node("Malha") as MeshInstance3D).mesh
	var forma_antes := (corpo.get_node("Colisao") as CollisionShape3D).shape
	var movida: Dictionary = r["mapa"]["pecas"][0].duplicate(true)
	movida["posicao"] = Vector3(7, 0, 0)
	MapaMontador.atualizar_peca(corpo, movida)
	_ok(is_same((corpo.get_node("Malha") as MeshInstance3D).mesh, malha_antes)
		and is_same((corpo.get_node("Colisao") as CollisionShape3D).shape, forma_antes)
		and corpo.position == Vector3(7, 0, 0), "mover reaproveita malha e forma (sem alocação por quadro)")
	movida["tamanho"] = Vector3(5, 5, 5)
	MapaMontador.atualizar_peca(corpo, movida)
	_ok(not is_same((corpo.get_node("Malha") as MeshInstance3D).mesh, malha_antes)
		and is_equal_approx(((corpo.get_node("Colisao") as CollisionShape3D).shape as SphereShape3D).radius, 2.5),
		"mudar o tamanho recria malha e forma")

	# Atualizar troca a forma no MESMO nó e desliga a colisão.
	var dado: Dictionary = r["mapa"]["pecas"][0].duplicate(true)
	dado["tipo"] = "caixa"
	dado["colisao"] = false
	MapaMontador.atualizar_peca(corpo, dado)
	_ok((corpo.get_node("Malha") as MeshInstance3D).mesh is BoxMesh and corpo.get_node_or_null("Colisao") == null,
		"atualizar troca esfera por caixa e remove a colisão no mesmo nó")
	raiz.free()



# ------------------------------------------------------------------ A2. hitbox
## HITBOX PRÓPRIA (23/09/2026). Antes disto a colisão era sempre derivada do tipo e
## do tamanho da peça: não havia deslocamento, forma nem giro próprios, e um modelo
## pesado virava uma caixa crua. O que se prova aqui é o DADO e a FÍSICA — ver e
## arrastar são as fases seguintes.
func _hitbox() -> void:
	print("\n-- A2. hitbox própria --")
	var mapa := _mapa_com([
		{"id": "arvore", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [4, 6, 4],
			"hitbox": {"forma": "cilindro", "deslocamento": [0, 1.5, 0],
				"tamanho": [1.2, 3, 1.2], "rotacao_graus": [0, 45, 0]}},
		{"id": "poste", "tipo": "caixa", "posicao": [8, 0, 0], "tamanho": [1, 4, 1],
			"hitbox": {"forma": "capsula", "tamanho": [0.8, 4, 0.8]}},
		{"id": "simples", "tipo": "caixa", "posicao": [16, 0, 0], "tamanho": [2, 2, 2]},
	])
	var r := MapaArquivo.validar(mapa)
	_ok(r["ok"], "mapa com hitbox carrega %s" % str(r["erros"]))
	if not r["ok"]:
		return
	var arvore: Dictionary = r["mapa"]["pecas"][0]
	_ok(arvore.get("hitbox", {}).get("forma", "") == "cilindro"
			and (arvore["hitbox"]["deslocamento"] as Vector3).is_equal_approx(Vector3(0, 1.5, 0)),
			"a hitbox chega normalizada na peça")
	_ok(not r["mapa"]["pecas"][2].has("hitbox"),
			"peça sem hitbox não ganha a chave (ausente = automático)")

	# IDA E VOLTA. O que mais importa aqui é o mapa SEM hitbox continuar saindo como
	# sempre saiu: é isso que mantém o mapa vivo do dono intocado ao abrir e salvar.
	var texto := MapaArquivo.para_texto(r["mapa"])
	var volta := MapaArquivo.ler_texto(texto)
	_ok(volta["ok"] and MapaArquivo.para_texto(volta["mapa"]) == texto,
			"ida e volta é estável (salvar duas vezes dá o mesmo texto)")
	var h2: Dictionary = volta["mapa"]["pecas"][0].get("hitbox", {}) if volta["ok"] else {}
	_ok(h2.get("forma", "") == "cilindro" and (h2.get("rotacao_graus", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(0, 45, 0)),
			"a hitbox sobrevive ao arquivo")
	var so_simples := MapaArquivo.validar(_mapa_com([
		{"id": "simples", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [2, 2, 2]}]))
	_ok(so_simples["ok"] and not MapaArquivo.para_texto(so_simples["mapa"]).contains("hitbox"),
			"mapa sem hitbox não escreve a chave no arquivo")

	# CONTROLES QUE REPROVAM. Sem eles esta seção não sabe distinguir hitbox aceita
	# de validador que aceita qualquer coisa.
	var forma_ruim := MapaArquivo.validar(_mapa_com([
		{"id": "a", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [2, 2, 2],
			"hitbox": {"forma": "banana", "tamanho": [1, 1, 1]}}]))
	_ok(not forma_ruim["ok"] and " ".join(forma_ruim["erros"]).contains("forma"),
			"controle: forma de hitbox inexistente é recusada")
	var esfera_ruim := MapaArquivo.validar(_mapa_com([
		{"id": "a", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [2, 2, 2],
			"hitbox": {"forma": "esfera", "tamanho": [3, 1, 3]}}]))
	_ok(not esfera_ruim["ok"] and " ".join(esfera_ruim["erros"]).contains("x = y = z"),
			"controle: hitbox de esfera esticada é recusada")
	var grande := MapaArquivo.validar(_mapa_com([
		{"id": "a", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [2, 2, 2],
			"hitbox": {"forma": "caixa", "tamanho": [MapaArquivo.TAMANHO_MAX * 2, 1, 1]}}]))
	_ok(not grande["ok"], "controle: hitbox maior que o limite do arquivo é recusada")

	# A FÍSICA que sai da hitbox.
	var raiz := Node3D.new()
	get_root().add_child(raiz)
	MapaMontador.montar(raiz, r["mapa"])
	var col := raiz.get_node("Mapa/arvore/Colisao") as CollisionShape3D
	_ok(col.shape is CylinderShape3D
			and is_equal_approx((col.shape as CylinderShape3D).radius, 0.6)
			and is_equal_approx((col.shape as CylinderShape3D).height, 3.0),
			"a forma de física vem da HITBOX (cilindro 1,2 × 3), não do tamanho da peça (4 × 6 × 4)")
	_ok(col.position.is_equal_approx(Vector3(0, 1.5, 0))
			and is_equal_approx(col.rotation_degrees.y, 45.0),
			"o volume fica deslocado e girado como a ficha pede")
	_ok((raiz.get_node("Mapa/arvore/Malha") as MeshInstance3D).mesh is BoxMesh,
			"a APARÊNCIA não muda: a malha continua a da peça")
	var capsula := (raiz.get_node("Mapa/poste/Colisao") as CollisionShape3D).shape
	_ok(capsula is CapsuleShape3D and is_equal_approx((capsula as CapsuleShape3D).height, 4.0),
			"cápsula existe como hitbox (altura total 4) e não como tipo de peça")
	_ok(not MapaArquivo.TIPOS.has("capsula") and MapaArquivo.FORMAS_HITBOX.has("capsula"),
			"controle: cápsula está na lista de hitbox e FORA da lista de tipos de peça")

	# Mexer SÓ na hitbox tem que refazer a forma (ela entra na chave de cache), e
	# tirar a hitbox tem que devolver o volume ao centro do corpo.
	var corpo := raiz.get_node("Mapa/arvore") as StaticBody3D
	var antes := (corpo.get_node("Colisao") as CollisionShape3D).shape
	var mexida: Dictionary = r["mapa"]["pecas"][0].duplicate(true)
	mexida["hitbox"] = {"forma": "cilindro", "deslocamento": Vector3(0, 1.5, 0),
		"tamanho": Vector3(2, 3, 2), "rotacao_graus": Vector3(0, 45, 0)}
	MapaMontador.atualizar_peca(corpo, mexida)
	var depois := (corpo.get_node("Colisao") as CollisionShape3D).shape
	_ok(not is_same(depois, antes) and is_equal_approx((depois as CylinderShape3D).radius, 1.0),
			"mudar só a hitbox refaz a forma (ela entra na chave de cache)")
	var sem: Dictionary = r["mapa"]["pecas"][0].duplicate(true)
	sem.erase("hitbox")
	MapaMontador.atualizar_peca(corpo, sem)
	var volta_col := corpo.get_node("Colisao") as CollisionShape3D
	_ok(volta_col.shape is BoxShape3D and volta_col.position.is_zero_approx()
			and volta_col.rotation_degrees.is_zero_approx(),
			"tirar a hitbox volta ao automático, sem deslocamento nem giro sobrando")
	raiz.free()

	# O VOLUME COMO DADO — é o que a física monta E o que o editor desenha. Uma conta
	# só: se estas duas leituras discordassem, o editor mostraria um volume e o
	# jogador esbarraria em outro.
	var v_propria := MapaMontador.volume_de_colisao(r["mapa"]["pecas"][0])
	_ok(v_propria.get("origem", "") == "propria"
			and (v_propria["local"] as Transform3D).origin.is_equal_approx(Vector3(0, 1.5, 0)),
			"volume_de_colisao: hitbox própria vira forma + transform local")
	var v_prim := MapaMontador.volume_de_colisao(r["mapa"]["pecas"][2])
	_ok(v_prim.get("origem", "") == "primitiva"
			and (v_prim["tamanho"] as Vector3).is_equal_approx(Vector3(2, 2, 2))
			and (v_prim["local"] as Transform3D) == Transform3D.IDENTITY,
			"volume_de_colisao: peça sem hitbox usa o próprio tipo e tamanho")
	var v_modelo := MapaMontador.volume_de_colisao({"tipo": "modelo", "modelo": "nao_existe",
		"tamanho": Vector3(3, 3, 3), "colisao": true})
	_ok(v_modelo.get("origem", "") == "caixa_do_modelo",
			"volume_de_colisao: modelo sem colisão de malha vira a CAIXA que a física usa")

	# O DESENHO. Peça sem colisão não desenha: ela não colide com nada.
	var doc := DocumentoMapa.de_mapa(r["mapa"])
	var vista := VistaDoMapa.new()
	get_root().add_child(vista)
	vista.ligar(doc)
	var linhas := (vista.get_node("Hitboxes") as MeshInstance3D).mesh as ImmediateMesh
	vista.desenhar_hitboxes(["arvore"] as Array[String])
	_ok(linhas.get_surface_count() == 1, "a hitbox da peça selecionada é desenhada")
	_ok((vista.get_node("VolumeDaHitbox") as MeshInstance3D).visible,
			"uma peça só selecionada ganha também o volume cheio")
	var apagada := doc.peca("arvore")
	apagada["colisao"] = false
	doc.definir_peca("arvore", apagada)
	vista.desenhar_hitboxes(["arvore"] as Array[String])
	_ok(linhas.get_surface_count() == 0,
			"controle: peça com a colisão DESLIGADA não desenha hitbox nenhuma")
	vista.ver_todas_as_hitboxes(true)
	_ok(linhas.get_surface_count() == 1 and vista.vendo_todas_as_hitboxes(),
			"a tecla H desenha as outras peças do mapa (a apagada continua de fora)")
	vista.free()


# ----------------------------------------------------------------- A3. editar
## EDITAR A HITBOX pelos campos do painel. Tudo passa por `OperacoesDoEditor.alterar`,
## que é o mesmo caminho de qualquer propriedade — é isso que faz o desfazer/refazer
## funcionar sem código próprio.
func _hitbox_edicao() -> void:
	print("\n-- A3. editar a hitbox --")
	var lido := MapaArquivo.validar(_mapa_com([
		{"id": "a1", "tipo": "cilindro", "posicao": [0, 0, 0], "tamanho": [2, 6, 2]},
		{"id": "a2", "tipo": "cilindro", "posicao": [5, 0, 0], "tamanho": [2, 6, 2]},
		{"id": "a3", "tipo": "cilindro", "posicao": [10, 0, 0], "tamanho": [2, 6, 2]},
		{"id": "outra", "tipo": "caixa", "posicao": [15, 0, 0], "tamanho": [2, 2, 2]},
	]))
	var doc := DocumentoMapa.de_mapa(lido["mapa"])
	var hist := HistoricoDeEdicao.new(doc)
	var sel := SelecaoDoEditor.new()
	sel.definir(["a1"])

	# Ligar a hitbox parte do volume que a física JÁ usa: o primeiro ajuste é pequeno.
	OperacoesDoEditor.alterar(doc, hist, sel, "hitbox.usar", true)
	var h: Dictionary = doc.peca("a1").get("hitbox", {})
	_ok(h.get("forma", "") == "cilindro" and (h.get("tamanho", Vector3.ZERO) as Vector3).is_equal_approx(Vector3(2, 6, 2)),
			"ligar a hitbox parte do volume automático de hoje, e não do zero")

	OperacoesDoEditor.alterar(doc, hist, sel, "hitbox.forma", "esfera")
	OperacoesDoEditor.alterar(doc, hist, sel, "hitbox.tamanho", Vector3(3, 1, 3))
	var esf: Dictionary = doc.peca("a1")["hitbox"]
	var t: Vector3 = esf["tamanho"]
	_ok(is_equal_approx(t.x, t.y) and is_equal_approx(t.x, t.z),
			"esfera não fica esticada: o tamanho é normalizado como o da peça (%s)" % str(t))
	OperacoesDoEditor.alterar(doc, hist, sel, "hitbox.deslocamento", Vector3(0, 2.5, 0))
	OperacoesDoEditor.alterar(doc, hist, sel, "hitbox.rotacao_graus", Vector3(0, 30, 0))
	_ok((doc.peca("a1")["hitbox"]["deslocamento"] as Vector3).is_equal_approx(Vector3(0, 2.5, 0)),
			"deslocamento e giro entram na ficha")

	hist.desfazer()
	_ok(is_zero_approx((doc.peca("a1")["hitbox"]["rotacao_graus"] as Vector3).y),
			"Ctrl+Z desfaz um campo da hitbox de cada vez")
	while hist.pode_desfazer():
		hist.desfazer()
	_ok(not doc.peca("a1").has("hitbox"), "desfazer até o fim volta ao volume automático")
	while hist.pode_refazer():
		hist.refazer()
	_ok(doc.peca("a1").has("hitbox"), "refazer traz a hitbox de volta")

	# APLICAR NAS IGUAIS — sem isto ninguém ajusta trinta cópias da mesma árvore.
	var iguais := OperacoesDoEditor.iguais_a(doc, "a1")
	_ok(iguais.size() == 3 and not iguais.has("outra"),
			"as peças iguais são as do mesmo tipo (3), e a caixa fica de fora")
	var quantas := OperacoesDoEditor.aplicar_hitbox_em_iguais(doc, hist, "a1")
	_ok(quantas == 3 and doc.peca("a2").has("hitbox") and doc.peca("a3").has("hitbox"),
			"aplicar copia a hitbox para as cópias")
	_ok(not doc.peca("outra").has("hitbox"),
			"controle: peça de outro tipo NÃO recebe a hitbox")
	hist.desfazer()
	_ok(not doc.peca("a2").has("hitbox") and not doc.peca("a3").has("hitbox")
			and doc.peca("a1").has("hitbox"),
			"as 3 cópias voltam com UM Ctrl+Z, e a peça de origem fica como estava")

	# Tirar a hitbox vale para a seleção inteira, como cor e material.
	OperacoesDoEditor.aplicar_hitbox_em_iguais(doc, hist, "a1")
	sel.definir(["a1", "a2", "a3"])
	OperacoesDoEditor.alterar(doc, hist, sel, "hitbox.remover", true)
	_ok(not doc.peca("a1").has("hitbox") and not doc.peca("a3").has("hitbox"),
			"tirar a hitbox vale para todas as peças selecionadas")

# ---------------------------------------------------------------- A4. arrastar
## ARRASTAR A HITBOX pelas alças. O gizmo fala em MUNDO e a hitbox mora em espaço
## LOCAL da peça: a peça girada 45° é o caso que denuncia erro de sinal na volta.
func _hitbox_gizmo() -> void:
	print("\n-- A4. arrastar a hitbox pelo gizmo --")
	var lido := MapaArquivo.validar(_mapa_com([
		{"id": "reta", "tipo": "caixa", "posicao": [0, 0, 0], "tamanho": [2, 2, 2]},
		{"id": "torta", "tipo": "caixa", "posicao": [10, 0, 0], "rotacao_graus": [0, 45, 0],
			"tamanho": [2, 2, 2]},
	]))
	var doc := DocumentoMapa.de_mapa(lido["mapa"])
	var sel := SelecaoDoEditor.new()

	# MOVER: arrastar 3 m no X do mundo tem que deslocar o volume 3 m no X do mundo.
	sel.definir(["reta"])
	var foto := OperacoesDoEditor.foto(doc, sel)
	OperacoesDoEditor.aplicar_arraste_hitbox(doc, foto,
		{"tipo": "seta", "eixo": 0, "eixo_mundo": Vector3.RIGHT, "sinal": 1, "centro": Vector3.ZERO}, 3.0, 0.0)
	_ok((doc.peca("reta")["hitbox"]["deslocamento"] as Vector3).is_equal_approx(Vector3(3, 0, 0)),
			"mover a alça X desloca o volume 3 m (peça sem giro)")
	_ok((doc.peca("reta")["posicao"] as Vector3).is_zero_approx(),
			"a PEÇA não anda junto: quem se mexeu foi só o volume")

	# A mesma alça do MUNDO numa peça girada 45°: em espaço local o deslocamento tem
	# que ser o vetor girado de volta, e o centro em mundo cair onde se arrastou.
	sel.definir(["torta"])
	var foto2 := OperacoesDoEditor.foto(doc, sel)
	OperacoesDoEditor.aplicar_arraste_hitbox(doc, foto2,
		{"tipo": "seta", "eixo": 0, "eixo_mundo": Vector3.RIGHT, "sinal": 1, "centro": Vector3.ZERO}, 3.0, 0.0)
	var pose := OperacoesDoEditor.pose_da_hitbox(doc, "torta")
	_ok((pose["centro"] as Vector3).is_equal_approx(Vector3(13, 0, 0)),
			"peça girada 45°: arrastar 3 m no X do MUNDO põe o volume em x = 13 (%s)" % str(pose["centro"]))
	var d: Vector3 = doc.peca("torta")["hitbox"]["deslocamento"]
	_ok(not d.is_equal_approx(Vector3(3, 0, 0)) and is_equal_approx(d.length(), 3.0),
			"e o deslocamento GRAVADO é local (3 m girados, %s)" % str(d))

	# ESCALAR pela face: a face oposta fica parada, como na peça.
	sel.definir(["reta"])
	var foto3 := OperacoesDoEditor.foto(doc, sel)
	OperacoesDoEditor.aplicar_arraste_hitbox(doc, foto3,
		{"tipo": "face", "eixo": 1, "eixo_mundo": Vector3.UP, "sinal": 1, "centro": Vector3.ZERO}, 2.0, 0.0)
	var h3: Dictionary = doc.peca("reta")["hitbox"]
	_ok(is_equal_approx((h3["tamanho"] as Vector3).y, 4.0)
			and is_equal_approx((h3["deslocamento"] as Vector3).y, 1.0),
			"esticar a face de cima em 2 m dá altura 4 e sobe o centro 1 (a face de baixo fica)")

	# GIRAR: o volume gira em torno de si mesmo, sem escapar da peça.
	var antes_centro: Vector3 = OperacoesDoEditor.pose_da_hitbox(doc, "reta")["centro"]
	var foto4 := OperacoesDoEditor.foto(doc, sel)
	OperacoesDoEditor.aplicar_arraste_hitbox(doc, foto4,
		{"tipo": "anel", "eixo": 1, "eixo_mundo": Vector3.UP, "sinal": 1, "centro": Vector3.ZERO}, deg_to_rad(90), 0.0)
	var depois := OperacoesDoEditor.pose_da_hitbox(doc, "reta")
	_ok(is_equal_approx(absf((doc.peca("reta")["hitbox"]["rotacao_graus"] as Vector3).y), 90.0),
			"girar o anel Y em 90° gira o volume 90°")
	_ok((depois["centro"] as Vector3).is_equal_approx(antes_centro),
			"girar NÃO arrasta o volume para longe da peça (gira em torno do próprio centro)")

	# Controle: o arraste da hitbox exige uma peça só.
	sel.definir(["reta", "torta"])
	var foto5 := OperacoesDoEditor.foto(doc, sel)
	var antes_h: Vector3 = doc.peca("torta")["hitbox"]["deslocamento"]
	OperacoesDoEditor.aplicar_arraste_hitbox(doc, foto5,
		{"tipo": "seta", "eixo": 0, "eixo_mundo": Vector3.RIGHT, "sinal": 1, "centro": Vector3.ZERO}, 5.0, 0.0)
	_ok((doc.peca("torta")["hitbox"]["deslocamento"] as Vector3).is_equal_approx(antes_h),
			"controle: com duas peças selecionadas o arraste de hitbox não faz nada")
# ------------------------------------------------- B. documento e histórico
func _doc_base() -> DocumentoMapa:
	var lido := MapaArquivo.validar(_mapa_com([
		{"id": "chao", "tipo": "caixa", "posicao": [0, -1, 0], "tamanho": [20, 2, 20]},
	]))
	return DocumentoMapa.de_mapa(lido["mapa"])


func _documento_e_historico() -> void:
	print("\n-- B. documento e desfazer/refazer --")
	var doc := _doc_base()
	var hist := HistoricoDeEdicao.new(doc)
	var eventos := []
	doc.peca_adicionada.connect(func(id): eventos.append("+" + id))
	doc.peca_removida.connect(func(id): eventos.append("-" + id))

	_ok(doc.novo_id("caixa") == "caixa_1", "novo_id começa em _1")
	hist.executar("Inserir", func(): doc.definir_peca("caixa_1", DocumentoMapa.peca_padrao("caixa", "caixa_1", Vector3(0, 1, 0))))
	_ok(doc.novo_id("caixa_1") == "caixa_2", "cópia não empilha sufixo (caixa_1 → caixa_2)")
	_ok(doc.tem("caixa_1") and doc.sujo and hist.tamanho() == 1, "inserir cria a peça, suja o documento e vira 1 passo")

	# Um arraste com 30 movimentos vira UM passo.
	hist.iniciar("Mover")
	for i in 30:
		var p := doc.peca("caixa_1")
		p["posicao"] = Vector3(i * 0.1, 1, 0)
		doc.definir_peca("caixa_1", p)
	hist.concluir()
	_ok(hist.tamanho() == 2, "30 movimentos de um arraste = 1 passo (%d)" % hist.tamanho())

	# Mexer num dicionário devolvido não pode vazar para dentro do documento.
	var copia := doc.peca("caixa_1")
	copia["posicao"] = Vector3(999, 999, 999)
	_ok(doc.peca("caixa_1")["posicao"] != Vector3(999, 999, 999), "peca() devolve cópia (valor imutável)")

	var ids := hist.desfazer()
	_ok(doc.peca("caixa_1")["posicao"] == Vector3(0, 1, 0) and ids == ["caixa_1"], "desfazer o arraste volta ao início")
	hist.desfazer()
	_ok(not doc.tem("caixa_1"), "desfazer a inserção apaga a peça")
	hist.refazer()
	hist.refazer()
	_ok(doc.tem("caixa_1") and is_equal_approx(doc.peca("caixa_1")["posicao"].x, 2.9), "refazer duas vezes devolve peça e posição")

	# Apagar e desfazer devolve a peça no MESMO lugar da ordem.
	hist.executar("Inserir", func(): doc.definir_peca("caixa_2", DocumentoMapa.peca_padrao("caixa", "caixa_2", Vector3.ZERO)))
	var ordem_antes := doc.ids()
	hist.executar("Apagar", func(): doc.remover_peca("caixa_1"))
	hist.desfazer()
	_ok(doc.ids() == ordem_antes, "desfazer apagar restaura a ordem %s" % str(doc.ids()))

	# Nova edição depois de desfazer mata o refazer.
	hist.desfazer()
	hist.executar("Spawn", func(): doc.definir_spawn(Vector3(5, 5, 5)))
	_ok(not hist.pode_refazer(), "editar depois de desfazer limpa o refazer")
	hist.desfazer()
	_ok(doc.spawn == Vector3(0, 1, 0), "desfazer move o spawn de volta")

	# Transação sem mudança não vira passo; cancelar devolve.
	var n := hist.tamanho()
	hist.executar("Nada", func(): pass)
	_ok(hist.tamanho() == n, "transação sem mudança não cria passo")
	hist.iniciar("Arraste cancelado")
	var q := doc.peca("chao")
	q["tamanho"] = Vector3(1, 1, 1)
	doc.definir_peca("chao", q)
	hist.cancelar()
	_ok(doc.peca("chao")["tamanho"] == Vector3(20, 2, 20) and hist.tamanho() == n, "cancelar devolve o estado e não cria passo")

	# O que sai do documento relê igual pelo arquivo.
	var relido := MapaArquivo.ler_texto(MapaArquivo.para_texto(doc.para_mapa()))
	_ok(relido["ok"] and relido["mapa"] == doc.para_mapa(), "documento → arquivo → documento é idêntico")

	# Regras de tamanho aplicadas pelo editor.
	_ok(DocumentoMapa.normalizar_tamanho("esfera", Vector3(3, 1, 2), 0) == Vector3(3, 3, 3), "esfera: o eixo arrastado manda nos três")
	_ok(DocumentoMapa.normalizar_tamanho("cilindro", Vector3(3, 5, 1), 2) == Vector3(1, 5, 1), "cilindro: mexer no Z acerta o X")
	_ok(DocumentoMapa.normalizar_tamanho("caixa", Vector3(0, 1, 9999)) == Vector3(MapaArquivo.TAMANHO_MIN, 1, MapaArquivo.TAMANHO_MAX), "tamanho preso aos limites do arquivo")
	_ok(DocumentoMapa.normalizar_rotacao(Vector3(270, -190, 89.99999)) == Vector3(-90, 170, 90), "rotação normalizada em [−180, 180] sem ruído")


func _selecao() -> void:
	print("\n-- B2. seleção --")
	var s := SelecaoDoEditor.new()
	var avisos := [0]
	s.mudou.connect(func(): avisos[0] += 1)
	s.definir(["a", "b", "a"])
	_ok(s.ids() == ["a", "b"], "definir remove repetidos")
	s.alternar("a")
	s.alternar(SelecaoDoEditor.SPAWN)
	_ok(s.ids() == ["b", SelecaoDoEditor.SPAWN] and s.pecas() == ["b"] and s.tem_spawn(), "alternar e spawn separado das peças")
	s.definir(["b", SelecaoDoEditor.SPAWN])
	_ok(avisos[0] == 3, "definir o mesmo conjunto não avisa de novo (%d avisos)" % avisos[0])
	var doc := _doc_base()
	s.definir(["chao", "sumiu", SelecaoDoEditor.SPAWN])
	s.podar(doc)
	_ok(s.ids() == ["chao", SelecaoDoEditor.SPAWN], "podar tira o que não existe e mantém o spawn")


# -------------------------------------------------------------- C. matemática
func _matematica() -> void:
	print("\n-- C. matemática do gizmo --")
	# Câmera olhando o eixo X de lado: o raio passa por x = 3.
	var t := GizmoMatematica.parametro_no_eixo(Vector3(3, 5, 10), Vector3(0, -0.5, -1).normalized(),
		Vector3.ZERO, Vector3.RIGHT)
	_ok(is_equal_approx(t, 3.0), "raio sobre x = 3 dá t = 3 no eixo X (%.4f)" % t)
	var paralelo := GizmoMatematica.parametro_no_eixo(Vector3(0, 0, 10), Vector3(-1, 0, 0), Vector3.ZERO, Vector3.RIGHT)
	_ok(is_nan(paralelo), "olhando o eixo de ponta devolve NAN (sem salto)")

	var a0 := GizmoMatematica.angulo_no_plano(Vector3(1, 10, 0), Vector3.DOWN, Vector3.ZERO, Vector3.UP)
	var a1 := GizmoMatematica.angulo_no_plano(Vector3(0, 10, -1), Vector3.DOWN, Vector3.ZERO, Vector3.UP)
	var giro := rad_to_deg(GizmoMatematica.diferenca_angular(a0, a1))
	_ok(is_equal_approx(absf(giro), 90.0), "de +X para −Z no anel Y são 90° (%.2f)" % giro)
	_ok(is_equal_approx(rad_to_deg(GizmoMatematica.diferenca_angular(deg_to_rad(170), deg_to_rad(-170))), 20.0), "diferença angular pega o caminho curto")
	_ok(GizmoMatematica.grudar(1.37, 0.5) == 1.5 and GizmoMatematica.grudar(1.37, 0.0) == 1.37, "grudar ao passo; passo 0 é livre")

	var gp := GizmoMatematica.girar_em_torno(Vector3(2, 0, 0), Vector3.ZERO, Vector3.ZERO, Vector3.UP, deg_to_rad(90))
	_ok((gp[0] as Vector3).is_equal_approx(Vector3(0, 0, -2)) and (gp[1] as Vector3).is_equal_approx(Vector3(0, 90, 0)),
		"girar 90° no Y em torno da origem: (2,0,0) → (0,0,−2), rotação Y = 90 (%s, %s)" % [gp[0], gp[1]])
	# Aplicar a rotação num nó de verdade tem que dar a mesma base (ordem YXZ).
	var composta := GizmoMatematica.girar_em_torno(Vector3.ZERO, Vector3(30, 0, 0), Vector3.ZERO, Vector3.UP, deg_to_rad(45))
	var no := Node3D.new()
	no.rotation_degrees = composta[1]
	var esperado := Basis(Vector3.UP, deg_to_rad(45)) * Basis.from_euler(Vector3(deg_to_rad(30), 0, 0))
	_ok(no.basis.is_equal_approx(esperado), "rotação composta volta igual num Node3D (ordem YXZ)")
	no.free()

	var caixa := DocumentoMapa.peca_padrao("caixa", "c", Vector3.ZERO)
	var ef := GizmoMatematica.esticar_face(caixa, 0, 1, 3.0)
	_ok((ef[1] as Vector3) == Vector3(5, 2, 2) and (ef[0] as Vector3).is_equal_approx(Vector3(1.5, 0, 0)),
		"esticar a face +X em 3 m: tamanho 5, centro anda 1,5 (face −X parada)")
	var girada := caixa.duplicate(true)
	girada["rotacao_graus"] = Vector3(0, 90, 0)
	var eg := GizmoMatematica.esticar_face(girada, 0, 1, 2.0)
	_ok((eg[0] as Vector3).is_equal_approx(Vector3(0, 0, -1)), "peça girada estica no eixo LOCAL (%s)" % eg[0])
	var minimo := GizmoMatematica.esticar_face(caixa, 1, -1, -50.0)
	_ok(is_equal_approx((minimo[1] as Vector3).y, MapaArquivo.TAMANHO_MIN), "encolher além do mínimo para no mínimo do arquivo")


# ------------------------------------------------------- D. editor de verdade
# Eventos entram por `Viewport.push_input`: passam pelos painéis (GUI) antes de
# chegar ao editor, exatamente como um clique de verdade. Clique em cima da barra
# tem que ficar com a barra — o teste confere isso também.
const CAMINHO_TESTE := "user://test_editor_mapa.json"

func _editor_de_verdade() -> void:
	print("\n-- D1. abrir --")
	# Mapa FIXO de teste (ver o ⚠️ do test_modo_historia): o do projeto é vivo.
	DirAccess.copy_absolute(ProjectSettings.globalize_path("res://tools/dev_tests/fixtures/mapa_baseplate.json"),
		ProjectSettings.globalize_path(CAMINHO_TESTE))
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = CAMINHO_TESTE
	get_root().add_child(ed)
	current_scene = ed
	await _quadros(10)
	var doc: DocumentoMapa = ed.doc
	_ok(doc != null and doc.quantidade() == 1, "abre a cópia do mapa com 1 peça")
	if doc == null:
		return
	var sel_bp := ed.get_node_or_null("Vista/Mapa/baseplate/Selecao") as StaticBody3D
	_ok(sel_bp != null and sel_bp.collision_layer == VistaDoMapa.CAMADA_SELECAO, "a peça ganhou forma de seleção só na camada 20")
	var cam: CameraLivre = ed._camera
	cam.posicionar(Vector3(0, 9, 11), Vector3(0, 1, 0))
	await _quadros(3)

	print("\n-- D2. inserir e selecionar --")
	var id: String = ed.inserir("caixa")
	var p := doc.peca(id)
	_ok(doc.tem(id) and ed.selecao.ids() == [id], "inserir cria \"%s\" e já seleciona" % id)
	_ok(is_equal_approx(p["posicao"].y, 1.0), "a caixa nasce apoiada na baseplate (y = %.2f)" % p["posicao"].y)
	await _quadros(4)
	var tela := cam.unproject_position(p["posicao"])
	ed.selecao.limpar()
	await _clicar(tela)
	_ok(ed.selecao.ids() == [id], "clique na caixa seleciona a caixa (%s)" % str(ed.selecao.ids()))
	await _clicar(Vector2(tela.x, 20))
	_ok(ed.selecao.ids() == [id], "clique em cima da BARRA não mexe na seleção")
	await _clicar(Vector2(40, 60) if cam.unproject_position(Vector3(0, -1, 0)).distance_to(Vector2(40, 60)) > 1 else Vector2(60, 80))
	await _clicar(tela)
	ed.selecao.limpar()
	await _arrastar_esquerdo(tela - Vector2(18, 18), tela + Vector2(18, 18))
	_ok(ed.selecao.ids() == [id], "retângulo em volta da caixa seleciona só ela (%s)" % str(ed.selecao.ids()))
	_ok(ed._explorer._arvore.get_root().get_child_count() == 3, "Explorer lista spawn + 2 peças")

	print("\n-- D3. mover pelo gizmo, desfazer, refazer --")
	await _tecla(KEY_2, true)
	var gz: GizmoDoEditor = ed._gizmo
	var c: Vector3 = p["posicao"]
	var s := gz._escala()
	var passos_antes: int = ed.historico.tamanho()
	await _arrastar_esquerdo(cam.unproject_position(c + Vector3.RIGHT * 0.6 * s),
		cam.unproject_position(c + Vector3.RIGHT * (0.6 * s + 3.2)))
	var x: float = doc.peca(id)["posicao"].x
	_ok(is_equal_approx(x, 3.0), "arrastar a seta X ~3,2 m move 3 m (grade de 1 m): x = %.3f" % x)
	_ok(ed.historico.tamanho() == passos_antes + 1 and doc.sujo, "o arraste inteiro virou 1 passo e sujou o mapa")
	await _tecla(KEY_Z, true)
	_ok(is_equal_approx(doc.peca(id)["posicao"].x, 0.0), "Ctrl+Z devolve a caixa para x = 0")
	await _tecla(KEY_Y, true)
	_ok(is_equal_approx(doc.peca(id)["posicao"].x, 3.0), "Ctrl+Y refaz (x = 3)")

	print("\n-- D4. escalar e girar pelo gizmo --")
	await _tecla(KEY_3, true)
	p = doc.peca(id)
	c = p["posicao"]
	s = gz._escala()
	var bola := c + Vector3.UP * ((p["tamanho"] as Vector3).y * 0.5 + 0.35 * s)
	await _arrastar_esquerdo(cam.unproject_position(bola), cam.unproject_position(bola + Vector3.UP * 2.0))
	p = doc.peca(id)
	_ok(is_equal_approx(p["tamanho"].y, 4.0) and is_equal_approx(p["posicao"].y, 2.0),
		"puxar a bolinha +Y 2 m: altura 4, base continua no chão (tam %s, pos %s)" % [p["tamanho"], p["posicao"]])
	await _tecla(KEY_4, true)
	c = doc.peca(id)["posicao"]
	s = gz._escala()
	var u := GizmoMatematica._perpendicular(Vector3.UP)
	var v := Vector3.UP.cross(u)
	# A 45° do anel: em 0° o ponto cai no cruzamento com o anel X, e a pega
	# (corretamente) escolheria o primeiro dos dois.
	var no_anel := func(graus: float) -> Vector3:
		return c + (u * cos(deg_to_rad(graus)) + v * sin(deg_to_rad(graus))) * s
	await _arrastar_esquerdo(cam.unproject_position(no_anel.call(45.0)), cam.unproject_position(no_anel.call(135.0)))
	var rot: Vector3 = doc.peca(id)["rotacao_graus"]
	_ok(is_equal_approx(rot.y, 90.0) and is_zero_approx(rot.x) and is_zero_approx(rot.z),
		"arrastar um quarto do anel Y gira +90° só no Y (%s)" % rot)

	print("\n-- D5. propriedades e Explorer --")
	ed._propriedades.alterar_pedido.emit("cor", Color("#cc3333"))
	ed._propriedades.alterar_pedido.emit("material", "grade")
	_ok(doc.peca(id)["cor"] == Color("#cc3333") and doc.peca(id)["material"] == "grade", "painel troca cor e material")
	ed._propriedades.alterar_pedido.emit("tipo", "esfera")
	var t: Vector3 = doc.peca(id)["tamanho"]
	_ok(doc.peca(id)["tipo"] == "esfera" and is_equal_approx(t.x, t.y) and is_equal_approx(t.y, t.z), "trocar para esfera iguala os três eixos (%s)" % t)
	ed._explorer.renomear_pedido.emit(id, "torre")
	await _quadros(2)
	_ok(doc.tem("torre") and not doc.tem(id) and ed.selecao.ids() == ["torre"] and ed.get_node_or_null("Vista/Mapa/torre") != null,
		"renomear pelo Explorer troca id, seleção e nó")
	ed._explorer.renomear_pedido.emit("torre", "com espaço")
	_ok(doc.tem("torre") and ed._status.text.contains("inválido"), "nome inválido é recusado com motivo")
	ed._explorer.selecao_pedida.emit(["baseplate"] as Array[String])
	_ok(ed.selecao.ids() == ["baseplate"], "clicar no Explorer seleciona na cena")

	print("\n-- D5b. área de animais --")
	var area_id: String = ed.inserir("area_animais")
	var area := doc.peca(area_id)
	_ok(area["tipo"] == "area_animais" and area["colisao"] == false and area["especie"] == DocumentoMapa.ESPECIE_PADRAO
		and area["quantidade"] == 3, "\"+ Animais\" cria a área sem colisão, %s ×3" % area["especie"])
	await _quadros(2)
	var escolha := ed._propriedades.find_child("Especie", true, false) as OptionButton
	_ok(escolha != null and escolha.item_count >= 30 and escolha.get_item_text(escolha.selected).begins_with("Coelho"),
		"painel lista os animais da loja pelo nome (%d; selecionado \"%s\")" % [
			escolha.item_count if escolha else 0, escolha.get_item_text(escolha.selected) if escolha else "?"])
	ed._propriedades.alterar_pedido.emit("especie", "bear")
	ed._propriedades.alterar_pedido.emit("quantidade", 99)
	_ok(doc.peca(area_id)["especie"] == "bear" and doc.peca(area_id)["quantidade"] == MapaArquivo.QUANTIDADE_MAX,
		"troca a espécie e limita a quantidade a %d" % MapaArquivo.QUANTIDADE_MAX)
	await _tecla(KEY_Z, true)
	await _tecla(KEY_Z, true)
	_ok(doc.peca(area_id)["especie"] == DocumentoMapa.ESPECIE_PADRAO and doc.peca(area_id)["quantidade"] == 3,
		"Ctrl+Z desfaz espécie e quantidade")
	var corpo_area := ed.get_node_or_null("Vista/Mapa/" + area_id) as Node3D
	_ok(corpo_area != null and corpo_area.visible, "no editor a área aparece (volume translúcido)")
	await _tecla(KEY_DELETE, false)
	_ok(not doc.tem(area_id), "Delete apaga a área")
	# Modelo atravessável (plantação) entra com a colisão desligada; os outros, ligada.
	var planta: String = ed.inserir_modelo("crops")
	var casa: String = ed.inserir_modelo("hut")
	_ok(not planta.is_empty() and doc.peca(planta)["colisao"] == false and doc.peca(casa)["colisao"] == true,
		"plantação (atravessável) entra sem colisão; casa entra com colisão")
	ed.selecao.definir([planta, casa] as Array[String])
	await _tecla(KEY_DELETE, false)
	ed.selecao.definir(["torre"] as Array[String])

	print("\n-- D6. formas, duplicar, apagar, várias peças --")
	cam.posicionar(Vector3(0, 30, 30), Vector3(0, 0, 0))
	await _quadros(3)
	var ids_novos: Array[String] = []
	for tipo in ["esfera", "cilindro", "cunha"]:
		ids_novos.append(ed.inserir(tipo))
		var dado := doc.peca(ids_novos.back())
		dado["posicao"] = Vector3(-8 + ids_novos.size() * 5, 1, -4)
		doc.definir_peca(dado["id"], dado)
	_ok(doc.quantidade() == 5, "inseriu esfera, cilindro e cunha (5 peças)")
	ed.selecao.definir(ids_novos)
	await _tecla(KEY_D, true)
	_ok(doc.quantidade() == 8 and ed.selecao.ids().size() == 3 and not ed.selecao.contem(ids_novos[0]), "Ctrl+D duplica as 3 e seleciona as cópias")
	await _tecla(KEY_DELETE, false)
	_ok(doc.quantidade() == 5 and ed.selecao.vazia(), "Delete apaga as 3 cópias")
	await _tecla(KEY_Z, true)
	_ok(doc.quantidade() == 8, "Ctrl+Z devolve as 3")
	await _tecla(KEY_Z, true)
	ed.selecao.definir(ids_novos)
	await _quadros(2)
	await _tecla(KEY_2, true)
	var antes_a: Vector3 = doc.peca(ids_novos[0])["posicao"]
	var antes_b: Vector3 = doc.peca(ids_novos[2])["posicao"]
	c = OperacoesDoEditor.centro(doc, ed.selecao)
	s = gz._escala()
	await _arrastar_esquerdo(cam.unproject_position(c + Vector3.BACK * 0.6 * s),
		cam.unproject_position(c + Vector3.BACK * (0.6 * s + 2.0)))
	var da: Vector3 = doc.peca(ids_novos[0])["posicao"] - antes_a
	var db: Vector3 = doc.peca(ids_novos[2])["posicao"] - antes_b
	_ok(da.is_equal_approx(db) and is_equal_approx(da.z, 2.0), "3 peças selecionadas andam juntas 2 m em Z (%s)" % da)
	var so_a_primeira: Array[String] = [ids_novos[0]]
	ed.selecao.definir(so_a_primeira)
	await _clicar(cam.unproject_position(doc.peca(ids_novos[2])["posicao"]), true)
	_ok(ed.selecao.ids().size() == 2, "Ctrl+clique soma à seleção (%s)" % str(ed.selecao.ids()))

	print("\n-- D7. spawn --")
	ed.selecao.limpar()
	await _quadros(2)
	await _clicar(cam.unproject_position(doc.spawn))
	_ok(ed.selecao.ids() == [SelecaoDoEditor.SPAWN], "clique no marcador seleciona o spawn")
	var spawn_antes := doc.spawn
	s = gz._escala()
	await _arrastar_esquerdo(cam.unproject_position(doc.spawn + Vector3.RIGHT * 0.6 * s),
		cam.unproject_position(doc.spawn + Vector3.RIGHT * (0.6 * s + 4.0)))
	_ok(is_equal_approx(doc.spawn.x - spawn_antes.x, 4.0), "arrastar move o spawn 4 m (%s)" % doc.spawn)
	await _tecla(KEY_DELETE, false)
	_ok(ed._status.text.contains("spawn não pode"), "o spawn não se apaga")

	print("\n-- D8. salvar --")
	var erro: Error = ed.salvar()
	var relido := MapaArquivo.carregar(CAMINHO_TESTE)
	_ok(erro == OK and relido["ok"] and relido["mapa"] == doc.para_mapa() and not doc.sujo,
		"salvar grava um arquivo válido idêntico ao documento e limpa o •")
	# Não compara o arquivo inteiro: o dono pode estar salvando o mapa real enquanto
	# a bateria roda. A peça "torre" só existe neste teste.
	_ok(not FileAccess.get_file_as_string("res://mapas/historia/baseplate.json").contains("\"torre\""),
		"o que o teste salvou não foi parar no mapa real do jogo")

	print("\n-- D9. testar com o jogador e voltar --")
	ed.selecao.definir(["baseplate"] as Array[String])
	await _tecla(KEY_F5, false)
	await _quadros(90)
	var j: Node = ed.jogador_do_teste()
	_ok(ed.modo == ed.Modo.TESTANDO and is_instance_valid(j), "F5 entra no teste com um jogador")
	if is_instance_valid(j):
		# Campanha nova (`ProgressaoDoPersonagem.new()`): desde 30/09/2026, Combate 1.
		_ok(j.capacidades.can_attack and not j.capacidades.can_dash and j.is_on_floor(),
			"é o Civil de campanha nova (já bate, sem dash), em pé no mapa (y = %.2f)" % j.global_position.y)
		_ok(Vector2(j.global_position.x, j.global_position.z).distance_to(Vector2(doc.spawn.x, doc.spawn.z)) < 0.5,
			"nasceu no spawn movido pelo editor, lido do documento em memória")
	_ok(sel_bp.collision_layer == 0 and not ed._interface.visible and not gz.visible_alcas(), "no teste: seleção sem camada, painéis e alças escondidos")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	get_root().push_input(esc, true)
	await _quadros(5)
	_ok(ed.modo == ed.Modo.EDITANDO and not is_instance_valid(j) and ed._interface.visible
		and sel_bp.collision_layer == VistaDoMapa.CAMADA_SELECAO and cam.current,
		"ESC do jogador volta ao editor: jogador some, painéis e seleção voltam")

	print("\n-- D10. sair com alterações pendentes --")
	ed.inserir("caixa")
	ed.sair()
	var dialogo: ConfirmationDialog = null
	for filho in ed.get_children():
		if filho is ConfirmationDialog:
			dialogo = filho
	_ok(dialogo != null and doc.sujo, "sair com alterações não salvas pergunta antes")
	ed.queue_free()
	await _quadros(3)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO_TESTE))


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _botao(pos: Vector2, apertado: bool, ctrl := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = apertado
	ev.ctrl_pressed = ctrl
	get_root().push_input(ev, true)


func _mover(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_root().push_input(ev, true)


func _clicar(pos: Vector2, ctrl := false) -> void:
	_botao(pos, true, ctrl)
	await process_frame
	_botao(pos, false, ctrl)
	await _quadros(1)


func _arrastar_esquerdo(de: Vector2, para: Vector2) -> void:
	_botao(de, true)
	await process_frame
	for i in range(1, 9):
		_mover(de.lerp(para, i / 8.0))
		await process_frame
	_botao(para, false)
	await _quadros(1)


func _tecla(code: int, ctrl: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.ctrl_pressed = ctrl
	ev.pressed = true
	get_root().push_input(ev, true)
	await process_frame
	ev = ev.duplicate()
	ev.pressed = false
	get_root().push_input(ev, true)
	await _quadros(1)
