extends SceneTree
## -- <antes.json> <depois.json>. Usa cópia user:// para edição/desfazer/salvar.
const Floresta := preload("res://tools/mapa_ilha/floresta_da_loja.gd")
var total := 0
var falhas := 0
func _init() -> void: rodar.call_deferred()
func ok(c: bool, msg: String) -> void:
	total += 1
	if not c: falhas += 1
	print(("OK " if c else "FALHA ") + msg)
func rodar() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Uso: -- <mapa anterior> <mapa candidato>")
		quit(1)
		return
	var antes := MapaArquivo.carregar(args[0])
	var depois := MapaArquivo.carregar(args[1])
	ok(antes.ok and depois.ok, "ambos os mapas passam no formato do editor")
	if not antes.ok or not depois.ok:
		quit(1)
		return
	var bib := BibliotecaDeModelos.padrao()
	var ferramenta := Floresta.new()
	var r := ferramenta.refazer(antes.mapa, bib)
	var antigas: Array = antes.mapa.pecas.filter(Floresta.e_antiga)
	var novas: Array = depois.mapa.pecas.filter(func(p): return str(p.id).begins_with(Floresta.PREFIXO))
	ok(not antigas.is_empty() and novas.size() > antigas.size(), "aglomerados foram trocados por peças individuais")
	ok(not depois.mapa.pecas.any(Floresta.e_antiga), "nenhum aglomerado antigo permanece na floresta")
	ok(antes.mapa.pecas.filter(func(p): return not Floresta.e_antiga(p)) == depois.mapa.pecas.filter(func(p): return not str(p.id).begins_with(Floresta.PREFIXO)),
		"todas as peças fora da substituição foram preservadas integralmente")
	ok(antes.mapa.spawn == depois.mapa.spawn and antes.mapa.grupos == depois.mapa.grupos, "nascimento e grupos preservados")
	ok(ferramenta.refazer(depois.mapa, bib).novas == 0, "reexecutar não duplica nem replantará a floresta")
	# Refazer de novo restaura a consulta do relevo e verifica a semente.
	r = ferramenta.refazer(antes.mapa, bib)
	var prova := "user://floresta_determinismo.json"
	MapaArquivo.salvar(prova, r.mapa)
	ok(MapaArquivo.carregar(prova).mapa == depois.mapa, "mesmo mapa e catálogo geram o mesmo resultado")
	var solo_ok := true
	var apoio_ok := true
	var catalogo_ok := true
	var atravessavel_ok := true
	var tipos := {}
	var maior_erro := 0.0
	for p in novas:
		var chao: Dictionary = ferramenta.chao_em(Vector2(p.posicao.x, p.posicao.z))
		solo_ok = solo_ok and not chao.is_empty() and chao.solo == 5 and not chao.molhado
		var diferenca: float = chao.altura - (p.posicao.y - p.tamanho.y * .5)
		maior_erro = maxf(maior_erro, absf(diferenca))
		apoio_ok = apoio_ok and diferenca >= -.02 and diferenca < .8
		catalogo_ok = catalogo_ok and bib.tem(p.modelo) and str(p.modelo).begins_with("floresta_")
		atravessavel_ok = atravessavel_ok and p.colisao == not bib.atravessavel(p.modelo)
		tipos[p.modelo] = true
	ok(solo_ok, "plantio fica no solo de mata, fora de água e estradas")
	ok(apoio_ok, "bases acompanham relevo; maior rebaixo %.3f m" % maior_erro)
	ok(catalogo_ok and tipos.size() >= 10, "modelos da loja: %d tipos" % tipos.size())
	ok(atravessavel_ok, "arbustos/capim atravessáveis e troncos sólidos respeitam catálogo")
	# Editor de produção montando a cópia: selecionar, editar e desfazer.
	var arquivo := "user://floresta_edicao.json"
	MapaArquivo.salvar(arquivo, depois.mapa)
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = arquivo
	root.add_child(ed)
	current_scene = ed
	for i in 8: await process_frame
	ok(ed.doc.quantidade() == depois.mapa.pecas.size(), "editor abre todas as %d peças" % depois.mapa.pecas.size())
	var p: Dictionary = novas[0]
	var no := ed.get_node("Vista/Mapa/" + str(p.id))
	ok(no.get_node("Selecao").collision_layer == VistaDoMapa.CAMADA_SELECAO, "árvore nova pode ser selecionada no editor")
	ok(no.get_node_or_null("Colisao") != null and no.get_node("Colisao").shape != null, "árvore nova tem colisão de jogo")
	var selecionados: Array[String] = [str(p.id)]
	ed.selecao.definir(selecionados)
	OperacoesDoEditor.alterar(ed.doc, ed.historico, ed.selecao, "posicao", p.posicao + Vector3.RIGHT)
	ok(ed.doc.peca(p.id).posicao == p.posicao + Vector3.RIGHT, "árvore pode ser movida como item individual")
	ed.historico.desfazer()
	ok(ed.doc.peca(p.id).posicao == p.posicao, "desfazer restaura posição")
	ed.salvar()
	ok(MapaArquivo.carregar(arquivo).mapa == depois.mapa, "salvar/reabrir no editor conserva floresta e resto do mapa")
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1600, 900)
		ed._camera.posicionar(p.posicao + Vector3(18, 9, 22), p.posicao)
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://art_src/validation/floresta_loja_2026-10-08/editor.png")
	ed.queue_free()
	current_scene = null
	for i in 8: await process_frame
	print("FLORESTA VALIDACAO: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
