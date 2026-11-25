extends SceneTree
## Menu -> editor -> editar/salvar/abrir -> Rodar -> menu, sem progresso de campanha.
const Dados := preload("res://src/skills_builder/dados_skill.gd")
var falhas := 0
var editor: Control
var pasta := "/tmp/skills_builder_ui_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]

func _init() -> void:
	rodar.call_deferred()

func ok(cond: bool, msg: String) -> void:
	print(("  ✅ " if cond else "  ❌ ") + msg)
	if not cond: falhas += 1

func quadros(n: int = 3) -> void:
	for i in n: await process_frame

func mouse_timeline(pos: Vector2, pressionado: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressionado
	e.position = pos
	editor.timeline._gui_input(e)

func mover_timeline(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	editor.timeline._gui_input(e)

func rodar() -> void:
	root.get_node("GameFlow").start_skills_builder()
	await quadros(6)
	editor = current_scene
	editor.pasta_skills = pasta
	ok(editor.name == "SkillsBuilder", "GameFlow abre o editor pelo caminho de produção")
	ok(editor._secoes.size() == 13, "treze seções configuráveis e timeline própria")
	for id in editor._secoes.keys():
		editor._mostrar_secao(id)
		await quadros(1)
		ok(editor._inspector.get_child_count() >= 3, "propriedades editáveis: " + str(id))
	editor._mostrar_secao("dano")
	var dano: float = editor.skill.dano.valor
	ok(editor.editar_campo("dano", "valor", 55.0), "edição válida chega ao documento")
	ok(editor.skill.dano.valor == 55.0 and editor.arena.skill.dano.valor == 55.0, "arena recebe a habilidade editada")
	editor.desfazer()
	ok(editor.skill.dano.valor == dano, "desfazer recupera valor anterior")
	editor.refazer()
	ok(editor.skill.dano.valor == 55.0, "refazer reaplica valor")
	editor._mostrar_secao("identificacao")
	ok(not editor.editar_campo("identificacao", "id", "../fora"), "ID com travessia é recusado no editor")
	await quadros()
	ok(editor.skill.identificacao.id == "nova_skill", "erro não substitui documento válido")
	editor._salvar()
	var caminho: String = pasta.path_join("nova_skill.json")
	ok(FileAccess.file_exists(caminho), "Salvar grava na biblioteca")
	editor._mostrar_secao("dano")
	editor.editar_campo("dano", "valor", 80.0)
	ok(editor.carregar_habilidade(caminho) and editor.skill.dano.valor == 55.0, "Abrir restaura a habilidade salva")
	var exportado := pasta.path_join("exportada.json")
	editor._exportando = true
	editor._arquivo_escolhido(exportado)
	ok(FileAccess.file_exists(exportado), "Exportar grava JSON pela interface")
	editor.editar_campo("dano", "valor", 99.0)
	editor._exportando = false
	editor._arquivo_escolhido(exportado)
	ok(editor.skill.dano.valor == 55.0, "Importar repõe os dados exportados")
	editor._duplicar()
	ok(editor.skill.identificacao.id != "nova_skill" and editor.skill.dano.valor == 55.0, "Duplicar cria ID próprio e preserva parâmetros")
	editor._salvar()
	ok(Dados.listar(pasta).size() == 3, "cópia salva sem substituir original")
	editor.carregar_habilidade(caminho)
	var antes: int = editor.skill.eventos.size()
	editor.adicionar_evento()
	ok(editor.skill.eventos.size() == antes + 1, "adicionar cria um evento de timeline")
	var id: String = editor._evento
	editor._mover_evento(id, .1, .3)
	ok(is_equal_approx(editor._evento_por_id(id).inicio, .1), "timeline escreve início e duração no documento")
	editor.remover_evento(id)
	ok(editor.skill.eventos.size() == antes, "remover evento atualiza documento")
	await quadros()
	var tl: Control = editor.timeline
	var bloco: Rect2 = tl._retangulo_evento(editor._evento_por_id("hitbox_1"))
	var origem := bloco.position + Vector2(9, 8)
	var destino := origem + Vector2(tl._largura_util() / float(editor.skill.configuracoes.duracao) * .2, 0)
	mouse_timeline(origem, true)
	mover_timeline(destino)
	mouse_timeline(destino, false)
	ok(is_equal_approx(editor._evento_por_id("hitbox_1").inicio, .55), "arrastar bloco aplica snap e altera o início")
	ok(editor._evento == "hitbox_1", "clicar no bloco seleciona seu inspector")
	bloco = tl._retangulo_evento(editor._evento_por_id("hitbox_1"))
	origem = bloco.end - Vector2(2, 8)
	destino = origem + Vector2(tl._largura_util() / float(editor.skill.configuracoes.duracao) * .15, 0)
	mouse_timeline(origem, true)
	mover_timeline(destino)
	mouse_timeline(destino, false)
	ok(is_equal_approx(editor._evento_por_id("hitbox_1").duracao, .4), "arrastar borda redimensiona o evento")
	bloco = tl._retangulo_evento(editor._evento_por_id("hitbox_1"))
	origem = bloco.position + Vector2(9, 8)
	mouse_timeline(origem, true)
	mover_timeline(origem + Vector2(50, 0))
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	tl._gui_input(esc)
	mouse_timeline(origem + Vector2(50, 0), false)
	ok(is_equal_approx(editor._evento_por_id("hitbox_1").inicio, .55), "Escape cancela arraste sem modificar documento")
	mouse_timeline(Vector2(tl._x_de_tempo(.6), 10), true)
	mouse_timeline(Vector2(tl._x_de_tempo(.6), 10), false)
	ok(editor.arena.pausado and is_equal_approx(editor.arena.tempo, .6), "régua busca instante e pausa a prévia")
	editor.desfazer()
	editor.desfazer()
	editor.arena.reiniciar()
	editor.find_child("Rodar", true, false).pressed.emit()
	ok(editor.arena.rodando, "botão Rodar inicia o executor")
	editor.arena.buscar(.6)
	ok(editor.arena.vida_alvo < 1000.0, "prévia executa hitbox/dano da skill editada")
	editor.arena.parar()
	ok(not editor.arena.rodando, "Parar encerra a execução")
	editor.arena.reiniciar()
	ok(editor.arena.vida_alvo == 1000.0, "reiniciar restaura vida do alvo")
	editor._voltar()
	await quadros(6)
	var b := current_scene.find_child("SkillsBuilder", true, false) as Button
	ok(b != null, "menu principal apresenta botão Skills Builder")
	if b != null:
		b.pressed.emit()
		await quadros(6)
		ok(current_scene.name == "SkillsBuilder", "botão do menu reabre o editor")
	for arquivo in Dados.listar(pasta): DirAccess.remove_absolute(arquivo)
	DirAccess.remove_absolute(pasta)
	current_scene.queue_free()
	await quadros()
	print("SKILLS_BUILDER_UI_RESULTADO falhas=%d" % falhas)
	quit(1 if falhas else 0)
