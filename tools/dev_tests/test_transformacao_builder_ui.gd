extends SceneTree
const Dados := preload("res://src/skills_builder/dados_skill.gd")
const PASTA := "res://art_src/validation/transformacao_builder_2026-10-07"
var total := 0
var falhas := 0
var editor: Control
var tela := false

func _init() -> void: rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("OK " if cond else "FALHA ") + msg)

func quadros(n := 3) -> void:
	for i in n: await process_frame

func foto(nome: String) -> void:
	if not tela: return
	await quadros(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA + "/" + nome + ".png")

func rodar() -> void:
	await process_frame
	tela = OS.get_cmdline_user_args().has("--tela")
	root.get_node("GameFlow").start_skills_builder()
	await quadros(6)
	editor = current_scene
	editor.pasta_skills = "user://teste_transformacao_ui"
	var s := Dados.novo()
	s.identificacao.id = "transformacao_teste"
	s.identificacao.nome = "Forma elemental"
	s.configuracoes.duracao = 3.0
	s.eventos.clear()
	editor._documento(s)
	var indice: int = editor.EVENTOS.find("transformacao")
	ok(indice >= 0 and editor._secoes.has("transformacao"), "editor oferece seção e evento Transformação")
	editor._tipo_evento.select(indice)
	editor.adicionar_evento()
	var id: String = editor._evento
	ok(editor._evento_por_id(id).tipo == "transformacao", "Adicionar coloca transformação na timeline")
	editor._mover_evento(id, .2, 1.8)
	await quadros()
	var seletor: Node = editor._inspector.get_node("SeletorTransformacao")
	seletor.find_child("Luz", true, false).pressed.emit()
	await quadros()
	ok(Dados.parametros(editor.skill, editor._evento_por_id(id)).visual == "Luz", "botão Luz edita parâmetros do bloco")
	editor.desfazer()
	ok(Dados.parametros(editor.skill, editor._evento_por_id(id)).visual == "Fumaça", "desfazer restaura forma anterior")
	editor.refazer()
	ok(Dados.parametros(editor.skill, editor._evento_por_id(id)).visual == "Luz", "refazer recupera transformação")
	editor.arena.buscar(.9)
	ok(editor.arena.ator.has_meta("transformacoes_visuais"), "prévia do usuário se transforma em luz")
	await foto("usuario_luz")
	editor._usar_transformacao({"visual": "Fumaça", "modelo": ""})
	await quadros()
	editor.arena.buscar(.9)
	await foto("usuario_fumaca")
	var alvo: Node3D = editor.arena.alvo
	editor.editar_campo("transformacao", "alvo", "Inimigo mais próximo")
	editor.arena.buscar(.9)
	ok(alvo.has_meta("transformacoes_visuais") and not editor.arena.ator.has_meta("transformacoes_visuais"), "seleção de inimigo troca somente o alvo")
	await foto("inimigo_fumaca")
	editor._mostrar_secao("transformacao", true)
	await quadros()
	seletor = editor._inspector.get_node("SeletorTransformacao")
	var modelos: OptionButton = seletor.get_node("ModelosTransformacao")
	var barril := -1
	for i in modelos.item_count:
		if modelos.get_item_metadata(i) == "barrel": barril = i
	ok(barril >= 0, "seletor lista modelos reais da loja")
	if barril >= 0:
		modelos.select(barril)
		modelos.item_selected.emit(barril)
	await quadros()
	ok(Dados.parametros(editor.skill, editor._evento_por_id(id)).modelo == "barrel", "escolher barril grava o asset do bloco")
	editor.arena.buscar(.9)
	await foto("inimigo_barril")
	editor.editar_campo("transformacao", "alvo", "Assets ao redor")
	editor._usar_transformacao({"visual": "Luz", "modelo": ""})
	await quadros()
	editor.arena.buscar(.9)
	ok(editor.arena.get_node("AssetDeEnsaio0").has_meta("transformacoes_visuais"), "assets da prévia recebem a forma")
	await foto("assets_luz")
	editor.arena.buscar(2.5)
	ok(not alvo.has_meta("transformacoes_visuais") and not editor.arena.get_node("AssetDeEnsaio0").has_meta("transformacoes_visuais"), "fim da duração restaura todos os visuais")
	await foto("restaurado")
	editor._salvar()
	var arquivo: String = editor.pasta_skills.path_join("transformacao_teste.json")
	ok(FileAccess.file_exists(arquivo), "Salvar grava documento de transformação")
	editor.editar_campo("transformacao", "raio", 2.0)
	ok(editor.carregar_habilidade(arquivo), "Abrir recupera documento salvo")
	var p: Dictionary = Dados.parametros(editor.skill, editor.skill.eventos[0])
	ok(p.alvo == "Assets ao redor" and p.visual == "Luz" and p.raio == 8.0, "reabertura conserva asset, alvo e alcance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(arquivo))
	print("TRANSFORMACAO UI: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
