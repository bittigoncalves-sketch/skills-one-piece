extends SceneTree
# ============================================================================
#  TESTE DOS GRUPOS DO EDITOR (Ctrl+G) — pedido do dono em 16/09/2026:
#
#    • 2+ itens selecionados + Ctrl+G  → une num grupo;
#    • 1 grupo selecionado + Ctrl+G    → separa;
#    • grupo que foi unido com mais uma peça, ao separar, desfaz PRIMEIRO a
#      união mais recente (o grupo de dentro continua inteiro).
#
#  A. formato do arquivo; B. operações sem nó (agrupar, separar, desfazer, mover,
#  duplicar, apagar, renomear); C. o editor de verdade, com teclado e mouse.
#
#  Rodar:
#    godot --headless --path . --script tools/dev_tests/test_grupos_editor.gd
# ============================================================================

const FIXO := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const CAMINHO := "user://test_grupos_mapa.json"

var _falhas := 0


func _init() -> void:
	await process_frame
	print("\n===== GRUPOS DO EDITOR =====")
	_formato()
	_operacoes()
	await _editor()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAMINHO))
	print("\n===== %s =====" % ("TUDO OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)


func _ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond:
		_falhas += 1


func _mapa(pecas: Array, grupos: Variant = null) -> Dictionary:
	var m := {"formato": MapaArquivo.FORMATO, "versao": 1, "nome": "t", "spawn": {"posicao": [0, 1, 0]}, "pecas": pecas}
	if grupos != null:
		m["grupos"] = grupos
	return m


func _p(id: String, x: float, grupo := "") -> Dictionary:
	var d := {"id": id, "tipo": "caixa", "posicao": [x, 1, 0], "tamanho": [2, 2, 2]}
	if not grupo.is_empty():
		d["grupo"] = grupo
	return d


# ------------------------------------------------------------------ A. formato
func _formato() -> void:
	print("\n-- A. formato --")
	var bom := MapaArquivo.validar(_mapa([_p("a", 0, "casa"), _p("b", 3, "telhado"), _p("c", 6)],
		[{"id": "casa", "pai": ""}, {"id": "telhado", "pai": "casa"}]))
	_ok(bom["ok"], "grupo dentro de grupo é válido %s" % str(bom["erros"]))
	if bom["ok"]:
		var relido := MapaArquivo.ler_texto(MapaArquivo.para_texto(bom["mapa"]))
		_ok(relido["ok"] and relido["mapa"] == bom["mapa"], "grupos sobrevivem a gravar e ler")
	var sem := MapaArquivo.validar(_mapa([_p("a", 0)]))
	_ok(sem["ok"] and not MapaArquivo.para_texto(sem["mapa"]).contains("grupo"),
		"mapa sem grupo grava igual a antes (nem a chave \"grupos\" aparece)")
	_recusa(_mapa([_p("a", 0)], [{"id": "g", "pai": ""}, {"id": "g", "pai": ""}]), "repetido", "id de grupo repetido")
	_recusa(_mapa([_p("a", 0)], [{"id": "a", "pai": ""}]), "repetido", "grupo com o mesmo id de uma peça")
	_recusa(_mapa([_p("a", 0)], [{"id": "g", "pai": "fantasma"}]), "não existe", "pai que não existe")
	_recusa(_mapa([_p("a", 0, "fantasma")], []), "não existe", "peça num grupo que não existe")
	_recusa(_mapa([_p("a", 0)], [{"id": "g1", "pai": "g2"}, {"id": "g2", "pai": "g1"}]), "ancestral de si", "ciclo de grupos")


func _recusa(m: Dictionary, palavra: String, caso: String) -> void:
	var r := MapaArquivo.validar(m)
	_ok(not r["ok"] and " | ".join(r["erros"]).contains(palavra), "recusa %s → %s" % [caso, " | ".join(r["erros"])])


# --------------------------------------------------------------- B. operações
func _operacoes() -> void:
	print("\n-- B. agrupar e separar (sem nó) --")
	var doc := DocumentoMapa.de_mapa(MapaArquivo.validar(_mapa([_p("a", 0), _p("b", 3), _p("c", 6), _p("d", 9)]))["mapa"])
	var hist := HistoricoDeEdicao.new(doc)
	var sel := SelecaoDoEditor.new()

	sel.definir(["a", "b"] as Array[String])
	var g1 := OperacoesDoEditor.agrupar(doc, hist, sel)
	_ok(doc.tem_grupo(g1) and doc.pai_de("a") == g1 and doc.pai_de("b") == g1 and sel.ids() == [g1],
		"a + b → grupo \"%s\", e a seleção vira o grupo" % g1)
	sel.definir([g1, "c"] as Array[String])
	var g2 := OperacoesDoEditor.agrupar(doc, hist, sel)
	_ok(doc.pai_de(g1) == g2 and doc.pai_de("c") == g2 and doc.raiz_de("a") == g2,
		"(a+b) + c → \"%s\" contém o grupo anterior e c" % g2)
	_ok(doc.pecas_de(g2).size() == 3 and doc.pecas_de(g1).size() == 2, "contagem de peças por grupo (3 e 2)")

	sel.definir([g2] as Array[String])
	var filhos := OperacoesDoEditor.desagrupar(doc, hist, sel)
	_ok(not doc.tem_grupo(g2) and doc.tem_grupo(g1) and doc.pai_de("c") == "" and doc.pai_de("a") == g1,
		"separar o de fora desfaz PRIMEIRO a última união: c sai, (a+b) continua junto")
	_ok(filhos.size() == 2 and filhos.has(g1) and filhos.has("c") and sel.ids().size() == 2, "a seleção vira os filhos diretos")
	sel.definir([g1] as Array[String])
	OperacoesDoEditor.desagrupar(doc, hist, sel)
	_ok(doc.grupos_ids().is_empty() and doc.pai_de("a") == "" and doc.pai_de("b") == "", "separar de novo solta a e b")

	hist.desfazer()
	_ok(doc.tem_grupo(g1) and doc.pai_de("a") == g1, "Ctrl+Z refaz o grupo (a+b)")
	hist.desfazer()
	_ok(doc.tem_grupo(g2) and doc.pai_de(g1) == g2 and doc.pai_de("c") == g2, "Ctrl+Z de novo devolve a hierarquia inteira")
	hist.refazer()
	_ok(not doc.tem_grupo(g2) and doc.pai_de(g1) == "", "Ctrl+Y separa de novo")
	hist.desfazer()

	print("\n-- B2. grupo como uma coisa só --")
	sel.definir([g2] as Array[String])
	var foto := OperacoesDoEditor.foto(doc, sel)
	OperacoesDoEditor.aplicar_arraste(doc, foto, {"tipo": "seta", "eixo": 2, "sinal": 1, "eixo_mundo": Vector3.BACK, "centro": Vector3.ZERO}, 5.0, 1.0)
	_ok(doc.peca("a")["posicao"].z == 5.0 and doc.peca("c")["posicao"].z == 5.0 and doc.peca("d")["posicao"].z == 0.0,
		"arrastar o grupo move as 3 peças de dentro e só elas")
	var centro := OperacoesDoEditor.centro(doc, sel)
	OperacoesDoEditor.alterar(doc, hist, sel, "posicao", centro + Vector3(0, 0, -5))
	_ok(doc.peca("b")["posicao"].z == 0.0, "digitar a posição do grupo move o centro dele")

	var total := doc.quantidade()
	var copias := OperacoesDoEditor.duplicar(doc, hist, sel)
	var copia := copias[0] if not copias.is_empty() else ""
	_ok(doc.tem_grupo(copia) and doc.quantidade() == total + 3 and doc.pecas_de(copia).size() == 3 and doc.pecas_de(g2).size() == 3,
		"duplicar o grupo copia a subárvore (3 peças novas) e o original fica")
	var sub_copia := ""
	for filho in doc.filhos_de(copia):
		if doc.tem_grupo(filho):
			sub_copia = filho
	_ok(not sub_copia.is_empty() and sub_copia != g1 and doc.pecas_de(sub_copia).size() == 2, "a cópia tem o subgrupo copiado também")

	sel.definir([copia] as Array[String])
	var apagadas := OperacoesDoEditor.apagar(doc, hist, sel)
	_ok(apagadas == 3 and not doc.tem_grupo(copia) and not doc.tem_grupo(sub_copia) and doc.quantidade() == total,
		"apagar o grupo apaga as peças e os subgrupos")
	hist.desfazer()
	_ok(doc.tem_grupo(copia) and doc.tem_grupo(sub_copia) and doc.quantidade() == total + 3, "Ctrl+Z traz tudo de volta")

	sel.definir([g1] as Array[String])
	var motivo := OperacoesDoEditor.renomear(doc, hist, sel, g1, "telhado")
	_ok(motivo.is_empty() and doc.tem_grupo("telhado") and doc.pai_de("a") == "telhado" and doc.pai_de("telhado") == g2 and sel.ids() == ["telhado"],
		"renomear grupo atualiza filhos, pai e seleção")
	_ok(not OperacoesDoEditor.renomear(doc, hist, sel, "telhado", "d").is_empty(), "renomear grupo para o nome de uma peça é recusado")

	# Apagar as peças uma a uma: grupo que fica vazio some.
	sel.definir(["a", "b"] as Array[String])
	OperacoesDoEditor.apagar(doc, hist, sel)
	_ok(not doc.tem_grupo("telhado") and doc.tem_grupo(g2), "grupo que ficou sem peças some; o de fora (ainda com c) fica")

	sel.definir(["c", "d"] as Array[String])
	var dentro := OperacoesDoEditor.agrupar(doc, hist, sel)
	_ok(doc.pai_de(dentro) == "", "itens de pais diferentes agrupam no topo")


# --------------------------------------------------------------- C. editor real
func _editor() -> void:
	print("\n-- C. no editor, com Ctrl+G, clique e Alt+clique --")
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXO), ProjectSettings.globalize_path(CAMINHO))
	var ed: Node3D = load("res://src/editor_mapa/EditorDeMapa.gd").new()
	ed.caminho_do_mapa = CAMINHO
	get_root().add_child(ed)
	current_scene = ed
	await _quadros(6)
	var doc: DocumentoMapa = ed.doc
	var cam: CameraLivre = ed._camera
	cam.posicionar(Vector3(0, 16, 18), Vector3(0, 0, 0))
	var ids: Array[String] = []
	for x in [-6.0, 0.0, 6.0]:
		var id: String = ed.inserir("caixa")
		var p := doc.peca(id)
		p["posicao"] = Vector3(x, 1, 0)
		doc.definir_peca(id, p)
		ids.append(id)
	await _quadros(4)
	var tela := func(id: String) -> Vector2: return cam.unproject_position(doc.peca(id)["posicao"])

	ed.selecao.limpar()
	await _clicar(tela.call(ids[0]))
	await _clicar(tela.call(ids[1]), true)
	await _tecla(KEY_G, true)
	var g1: String = ed.selecao.ids()[0] if ed.selecao.ids().size() == 1 else ""
	_ok(doc.tem_grupo(g1) and doc.pai_de(ids[0]) == g1 and doc.pai_de(ids[1]) == g1, "clique + Ctrl+clique + Ctrl+G une as duas caixas")

	ed.selecao.limpar()
	await _clicar(tela.call(ids[0]))
	_ok(ed.selecao.ids() == [g1], "clicar numa peça do grupo seleciona o GRUPO")
	await _clicar(tela.call(ids[0]), false, true)
	_ok(ed.selecao.ids() == [ids[0]], "Alt+clique seleciona só a peça de dentro")

	await _clicar(tela.call(ids[1]))
	await _clicar(tela.call(ids[2]), true)
	await _tecla(KEY_G, true)
	var g2: String = ed.selecao.ids()[0] if ed.selecao.ids().size() == 1 else ""
	_ok(doc.tem_grupo(g2) and doc.pai_de(g1) == g2 and doc.pai_de(ids[2]) == g2, "grupo + caixa simples + Ctrl+G une de novo (aninhado)")
	await _quadros(2)
	var arvore: Tree = ed._explorer._arvore
	var item_g2: TreeItem = ed._explorer._itens.get(g2)
	_ok(item_g2 != null and item_g2.get_child_count() == 2 and item_g2.get_text(1).contains("3 peças"),
		"o Explorer mostra o grupo com 2 filhos e 3 peças")

	# Mover o grupo de fora pelo gizmo: as 3 caixas andam juntas.
	await _tecla(KEY_2, true)
	var gz: GizmoDoEditor = ed._gizmo
	var c := OperacoesDoEditor.centro(doc, ed.selecao)
	var s := gz._escala()
	var antes := doc.peca(ids[0])["posicao"] as Vector3
	await _arrastar(cam.unproject_position(c + Vector3.RIGHT * 0.6 * s), cam.unproject_position(c + Vector3.RIGHT * (0.6 * s + 2.0)))
	_ok(is_equal_approx((doc.peca(ids[0])["posicao"] as Vector3).x - antes.x, 2.0)
		and is_equal_approx((doc.peca(ids[2])["posicao"] as Vector3).x, 8.0), "arrastar o grupo move as 3 caixas 2 m")

	await _tecla(KEY_G, true)
	_ok(not doc.tem_grupo(g2) and doc.tem_grupo(g1) and doc.pai_de(ids[2]) == "",
		"Ctrl+G no grupo de fora separa a ÚLTIMA união: a caixa sai, o par continua unido")
	ed.selecao.definir([g1] as Array[String])
	await _tecla(KEY_G, true)
	_ok(doc.grupos_ids().is_empty(), "Ctrl+G no par separa as duas caixas")
	await _tecla(KEY_Z, true)
	_ok(doc.tem_grupo(g1), "Ctrl+Z desfaz a separação")

	_ok(ed.salvar() == OK, "salvar")
	var relido := MapaArquivo.carregar(CAMINHO)
	_ok(relido["ok"] and relido["mapa"]["grupos"].size() == 1 and relido["mapa"]["pecas"].filter(func(pp): return pp["grupo"] == g1).size() == 2,
		"o arquivo salvo tem o grupo e as 2 peças dentro dele")
	ed.selecao.definir([ids[2]] as Array[String])
	await _tecla(KEY_G, true)
	_ok(ed._status.text.contains("2 ou mais"), "Ctrl+G com uma peça solta explica que precisa de 2")
	ed.queue_free()
	await _quadros(2)


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame
	await process_frame


func _botao(pos: Vector2, apertado: bool, ctrl := false, alt := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.position = pos
	ev.global_position = pos
	ev.pressed = apertado
	ev.ctrl_pressed = ctrl
	ev.alt_pressed = alt
	get_root().push_input(ev, true)


func _clicar(pos: Vector2, ctrl := false, alt := false) -> void:
	_botao(pos, true, ctrl, alt)
	await process_frame
	_botao(pos, false, ctrl, alt)
	await _quadros(1)


func _arrastar(de: Vector2, para: Vector2) -> void:
	_botao(de, true)
	await process_frame
	for i in range(1, 9):
		var ev := InputEventMouseMotion.new()
		ev.position = de.lerp(para, i / 8.0)
		ev.global_position = ev.position
		get_root().push_input(ev, true)
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
	var solta := ev.duplicate() as InputEventKey
	solta.pressed = false
	get_root().push_input(solta, true)
	await _quadros(1)
