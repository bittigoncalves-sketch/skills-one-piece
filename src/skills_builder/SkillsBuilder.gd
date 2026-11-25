extends Control
## Editor de dados de habilidades com execução isolada. Não equipa skills na campanha.
const Dados = preload("res://src/skills_builder/dados_skill.gd")
const Estilo = preload("res://src/skills_builder/estilo_builder.gd")
const Arena = preload("res://src/skills_builder/arena_preview.gd")
const TesteNoJogo = preload("res://src/skills_builder/teste_no_jogo.gd")
const Timeline = preload("res://src/skills_builder/timeline_skill.gd")
const LojaDeProjeteis = preload("res://src/skills_builder/loja_de_projeteis.gd")
const CampoDeFruta = preload("res://src/skills_builder/campo_de_fruta.gd")
const SeletorTransformacao = preload("res://src/skills_builder/seletor_transformacao.gd")
const EVENTOS := ["animacao", "movimento", "hitbox", "projetil", "vfx", "audio", "camera", "transformacao"]
const TITULOS := ["Animação", "Movimento", "Hitbox", "Projétil", "VFX", "Áudio", "Câmera", "Transformação"]
const SECAO_EVENTO := {"hitbox": "hitboxes", "projetil": "projeteis"}

var skill: Dictionary = {}
var pasta_skills := "user://skills_builder"
var arena: Node3D
var timeline: Control
var _salvo: Dictionary = {}
var _caminho := ""
var _secao := "identificacao"
var _evento := ""
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _inspector: VBoxContainer
var _titulo: Label
var _status: Label
var _metricas: Label
var _aviso: Label
var _secoes: Dictionary = {}
var _lista_eventos: OptionButton
var _tipo_evento: OptionButton
var _desfazer: Button
var _refazer: Button
var _pausa: Button
var _subviewport: SubViewport
var _arrastando_camera := false
var _confirmacao: ConfirmationDialog
var _pendente: Callable
var _dialogo: FileDialog
var _exportando := false
var _biblioteca: AcceptDialog
var _lista_arquivos: ItemList
var _min_anterior := Vector2i.ZERO
var _contador_evento := 0
var _atualizando := false
var _miniaturas: GeradorDeMiniaturas

func _ready() -> void:
	_min_anterior = get_window().min_size
	get_window().min_size = Vector2i(1060, 680)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	theme = Estilo.tema()
	# Fotos da loja de projéteis: o gerador vive com o editor (o painel é refeito a
	# cada edição e não pode ser dono de uma foto pela metade).
	_miniaturas = GeradorDeMiniaturas.new()
	_miniaturas.name = "Miniaturas"
	_miniaturas.biblioteca = MapaMontador.biblioteca_em_uso()
	add_child(_miniaturas)
	_montar()
	_documento(Dados.novo())

func _montar() -> void:
	var bg := ColorRect.new()
	bg.color = Estilo.FUNDO
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margem := MarginContainer.new()
	margem.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for lado in ["left", "right", "top", "bottom"]: margem.add_theme_constant_override("margin_" + lado, 12)
	add_child(margem)
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 10)
	margem.add_child(pilha)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 7)
	pilha.add_child(topo)
	topo.add_child(Estilo.rotulo("SKILLS BUILDER", 21))
	_titulo = Estilo.rotulo("", 14, true)
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	topo.add_child(_titulo)
	var novo := MenuButton.new()
	novo.text = "Nova"
	for nome in ["Golpe", "Projétil", "Área de vento"]: novo.get_popup().add_item(nome)
	novo.get_popup().id_pressed.connect(func(i: int): _proteger(func(): _novo(i)))
	topo.add_child(novo)
	topo.add_child(Estilo.botao("Abrir", _abrir_biblioteca, "Abrir habilidade salva"))
	var salvar := Estilo.botao("Salvar", _salvar, "Ctrl+S")
	salvar.name = "Salvar"
	topo.add_child(salvar)
	# "Publicar na loja" (07/10/2026, pedido do dono): além de levar ao jogo, a fruta (ou o
	# Kit) fica à venda no vendedor de frutas do Modo História, pelo preço do campo Fruta.
	var publicar := Estilo.botao("Publicar na loja", _publicar, "Leva ao jogo (res://mapas/skills) e põe a fruta à venda no vendedor de frutas do Modo História")
	publicar.name = "Publicar"
	topo.add_child(publicar)
	topo.add_child(Estilo.botao("Duplicar", _duplicar, "Cria uma cópia com outro identificador"))
	topo.add_child(Estilo.botao("Importar", func(): _proteger(func(): _arquivo(false))))
	topo.add_child(Estilo.botao("Exportar", func(): _arquivo(true)))
	topo.add_child(Estilo.botao("Menu", func(): _proteger(_voltar)))
	var corpo := HBoxContainer.new()
	corpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 10)
	pilha.add_child(corpo)
	var lateral := PanelContainer.new()
	lateral.custom_minimum_size.x = 164
	corpo.add_child(lateral)
	var nav := VBoxContainer.new()
	nav.add_theme_constant_override("separation", 4)
	lateral.add_child(nav)
	nav.add_child(Estilo.rotulo("COMPONENTES", 12, true))
	var scroll_nav := ScrollContainer.new()
	scroll_nav.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(scroll_nav)
	var itens := VBoxContainer.new()
	itens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_nav.add_child(itens)
	for secao: Dictionary in Dados.secoes():
		var id := str(secao.id)
		var b := Estilo.botao(str(secao.nome), func(): _mostrar_secao(id))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.add_theme_font_size_override("font_size", 13)
		itens.add_child(b)
		_secoes[id] = b
	# EDITOR DE POSES (06/10/2026): fora de `_secoes` (que são as seções do contrato).
	_botao_poses = Estilo.botao("Poses", func(): _mostrar_secao("poses"), "Crie as poses do personagem para os blocos de Animação")
	_botao_poses.name = "Poses"
	_botao_poses.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_botao_poses.toggle_mode = true
	_botao_poses.add_theme_font_size_override("font_size", 13)
	itens.add_child(_botao_poses)
	nav.add_child(Estilo.botao("Timeline", func(): timeline.grab_focus(), "Arraste os blocos para ordenar a habilidade"))
	var historico := HBoxContainer.new()
	nav.add_child(historico)
	_desfazer = Estilo.botao("Desfazer", desfazer, "Ctrl+Z")
	_refazer = Estilo.botao("Refazer", refazer, "Ctrl+Shift+Z")
	for b in [_desfazer, _refazer]:
		b.add_theme_font_size_override("font_size", 11)
		historico.add_child(b)
	var centro := VBoxContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_child(centro)
	var transporte := HBoxContainer.new()
	transporte.add_theme_constant_override("separation", 6)
	centro.add_child(transporte)
	var rodar := Estilo.botao("▶ Rodar", executar, "F5 • Executa a habilidade na arena")
	rodar.name = "Rodar"
	var verde := Estilo.caixa(Color("275b4e"), 8)
	rodar.add_theme_stylebox_override("normal", verde)
	transporte.add_child(rodar)
	# ▶ Testar no jogo (07/10/2026, pedido do dono): o jogador de verdade numa plataforma
	# de teste, com a skill aberta; Esc volta. Nada do jogo de verdade é tocado.
	var testar := Estilo.botao("▶ Testar no jogo", _testar_no_jogo, "Joga a skill com o jogador de verdade numa plataforma de teste (Esc volta ao editor)")
	testar.name = "TestarNoJogo"
	transporte.add_child(testar)
	_pausa = Estilo.botao("Pausar", func(): arena.pausar())
	transporte.add_child(_pausa)
	transporte.add_child(Estilo.botao("Parar", func(): arena.parar()))
	transporte.add_child(Estilo.botao("Reiniciar alvo", func(): arena.reiniciar()))
	var caixas := CheckButton.new()
	caixas.text = "Hitboxes"
	caixas.button_pressed = true
	caixas.toggled.connect(func(v: bool): arena.definir_hitboxes(v))
	transporte.add_child(caixas)
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "Arena"
	viewport_container.stretch = true
	viewport_container.custom_minimum_size = Vector2(400, 180)
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.gui_input.connect(_camera_input)
	centro.add_child(viewport_container)
	_subviewport = SubViewport.new()
	_subviewport.own_world_3d = true
	_subviewport.size = Vector2i(640, 360)
	_subviewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_subviewport.handle_input_locally = false
	viewport_container.add_child(_subviewport)
	arena = Arena.new()
	_subviewport.add_child(arena)
	var simulacao := HFlowContainer.new()
	simulacao.add_theme_constant_override("separation", 8)
	centro.add_child(simulacao)
	simulacao.add_child(Estilo.rotulo("Alvo (m)", 12, true))
	var distancia := _numero(1, 30, .5, 4)
	distancia.custom_minimum_size.x = 70
	distancia.value_changed.connect(func(v: float): arena.distancia_alvo = v; arena.reiniciar())
	simulacao.add_child(distancia)
	simulacao.add_child(Estilo.rotulo("Nível", 12, true))
	var nivel := _numero(1, 100, 1, 1)
	nivel.custom_minimum_size.x = 64
	nivel.value_changed.connect(func(v: float): arena.nivel = int(v))
	simulacao.add_child(nivel)
	var chao := CheckButton.new()
	chao.text = "No chão"
	chao.button_pressed = true
	chao.toggled.connect(func(v: bool): arena.no_chao = v)
	simulacao.add_child(chao)
	var movel := CheckButton.new()
	movel.text = "Alvo móvel"
	movel.toggled.connect(func(v: bool): arena.alvo_movel = v; arena.reiniciar())
	simulacao.add_child(movel)
	simulacao.add_child(Estilo.rotulo("Vida (%)", 12, true))
	var vida_ator := _numero(0, 100, 1, 100)
	vida_ator.custom_minimum_size.x = 70
	vida_ator.value_changed.connect(func(v: float): arena.vida = v)
	simulacao.add_child(vida_ator)
	_metricas = Estilo.rotulo("", 12, true)
	_metricas.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centro.add_child(_metricas)
	var trilha := PanelContainer.new()
	centro.add_child(trilha)
	var timeline_box := VBoxContainer.new()
	trilha.add_child(timeline_box)
	var comandos := HBoxContainer.new()
	timeline_box.add_child(comandos)
	comandos.add_child(Estilo.rotulo("TIMELINE", 12, true))
	_tipo_evento = OptionButton.new()
	for nome in TITULOS: _tipo_evento.add_item(nome)
	comandos.add_child(_tipo_evento)
	comandos.add_child(Estilo.botao("+ Evento", adicionar_evento))
	comandos.add_child(Estilo.botao("Excluir", func(): remover_evento(_evento)))
	_lista_eventos = OptionButton.new()
	_lista_eventos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista_eventos.item_selected.connect(func(i: int): selecionar_evento(str(_lista_eventos.get_item_metadata(i))))
	comandos.add_child(_lista_eventos)
	timeline = Timeline.new()
	timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timeline.selecionou.connect(selecionar_evento)
	timeline.alterou.connect(_mover_evento)
	timeline.buscou.connect(func(t: float): arena.buscar(t))
	if timeline.has_signal("excluir_pedido"): timeline.excluir_pedido.connect(remover_evento)
	timeline_box.add_child(timeline)
	var painel := PanelContainer.new()
	painel.custom_minimum_size.x = 286
	corpo.add_child(painel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	painel.add_child(sc)
	_inspector = VBoxContainer.new()
	_inspector.custom_minimum_size.x = 256
	_inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inspector.add_theme_constant_override("separation", 10)
	sc.add_child(_inspector)
	_status = Estilo.rotulo("", 12, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pilha.add_child(_status)
	_dialogos()

func _dialogos() -> void:
	_confirmacao = ConfirmationDialog.new()
	_confirmacao.title = "Alterações não salvas"
	_confirmacao.ok_button_text = "Descartar"
	_confirmacao.confirmed.connect(func():
		var acao := _pendente
		_pendente = Callable()
		if acao.is_valid(): acao.call())
	add_child(_confirmacao)
	_dialogo = FileDialog.new()
	_dialogo.access = FileDialog.ACCESS_FILESYSTEM
	_dialogo.filters = PackedStringArray(["*.json ; Habilidade JSON"])
	_dialogo.file_selected.connect(_arquivo_escolhido)
	add_child(_dialogo)
	_biblioteca = AcceptDialog.new()
	_biblioteca.title = "Habilidades salvas"
	_biblioteca.ok_button_text = "Abrir selecionada"
	_lista_arquivos = ItemList.new()
	_lista_arquivos.custom_minimum_size = Vector2(460, 260)
	_biblioteca.add_child(_lista_arquivos)
	_biblioteca.confirmed.connect(_abrir_selecionada)
	_lista_arquivos.item_activated.connect(func(_i: int): _abrir_selecionada(); _biblioteca.hide())
	add_child(_biblioteca)

func _mostrar_secao(id: String, manter_evento: bool = false) -> void:
	_secao = id
	if not manter_evento:
		_evento = ""
		timeline.selecionado = ""
		timeline.queue_redraw()
	_construir_inspector()

func _construir_inspector() -> void:
	_atualizando = true
	for filho in _inspector.get_children():
		_inspector.remove_child(filho)
		filho.queue_free()
	for id in _secoes: _secoes[id].set_pressed_no_signal(id == _secao)
	if _botao_poses: _botao_poses.set_pressed_no_signal(_secao == "poses")
	if _secao == "poses":
		_poses.construir()
		_atualizando = false
		return
	if is_instance_valid(arena) and not str(arena.get("pose_em_edicao")).is_empty():
		arena.mostrar_pose("")
	var evento := _evento_por_id(_evento)
	for s: Dictionary in Dados.secoes():
		if str(s.id) != _secao: continue
		_inspector.add_child(Estilo.rotulo(str(s.nome), 19))
		if not evento.is_empty():
			_explicacao("Evento selecionado: " + str(evento.id) + "\nOs valores abaixo valem para este bloco.")
			_campo_evento(evento)
		else:
			_explicacao("Valores padrão usados pelos eventos desta categoria.")
		if _secao == "identificacao":
			_explicacao("Destino define a autoria. Salvar guarda o rascunho na sua biblioteca. Publicar na loja leva a skill ao jogo (res://mapas/skills): com Usuário Jogador ela entra na tecla da fruta (ou do Kit do Builder) e a fruta fica à venda no vendedor de frutas do Modo História, pelo preço do campo Fruta.")
		if _secao == "ativacao":
			_explicacao("Rodar / F5 simula a carga completa. Pela tecla escolhida, segure até carregar; soltar antes cancela. Automática repete até Parar. Atalhos não atuam durante edição de texto.")
		if _secao == "hitboxes":
			_explicacao("Metros relativos ao ator: X lateral, Y altura e Z negativo para frente. Dano é aplicado durante o bloco ativo.")
		if _secao == "condicoes":
			_explicacao("A arena verifica estas condições antes de iniciar. Ajuste nível, distância e estado de chão nos controles abaixo da prévia.")
		var valores: Dictionary = skill[_secao] if evento.is_empty() else Dados.parametros(skill, evento)
		if _secao == "projeteis":
			_loja_de_projeteis(valores)
		if _secao == "transformacao":
			_explicacao("Troca só o visual. O bloco define início e duração; ao terminar, restaura o alvo. Raio medido do usuário; até 32 alvos. Na prévia há dois objetos para testar a área.")
			var seletor := SeletorTransformacao.new()
			seletor.biblioteca = _miniaturas.biblioteca
			seletor.atual = valores
			_inspector.add_child(seletor)
			seletor.montar()
			seletor.escolheu.connect(_usar_transformacao)
		for campo: Dictionary in s.campos:
			if _secao == "transformacao" and campo.id in ["visual", "modelo"]: continue
			if _secao == "identificacao" and str(campo.id) == "fruta":
				if str(valores.get("dono", "Jogador")) == "Jogador":
					_campo_fruta(str(valores.get("fruta", "")))
				continue
			if _secao == "identificacao" and str(campo.id) == "atribuida_a":
				_campo_quem_usa(str(valores.get("dono", "Jogador")), str(valores.get("atribuida_a", "")))
				continue
			if _secao == "animacao" and str(campo.id) == "pose":
				_campo_de_pose(str(valores.get("pose", "")))
				continue
			if _secao == "identificacao" and str(campo.id) == "dono":
				_adicionar_campo(campo, valores.get("dono", "Jogador"), func(valor: Variant): _editar_dono(str(valor)))
				continue
			_adicionar_campo(campo, valores.get(campo.id, campo.get("padrao")), func(valor: Variant): editar_campo(_secao, str(campo.id), valor))
	_atualizando = false

## Loja de projéteis (pedido do dono, 06/10/2026): prontos + modelos da loja do editor.
## Vale para a seção (sem bloco aberto) ou para o bloco de Projétil aberto, como os campos.
func _loja_de_projeteis(valores: Dictionary) -> void:
	var loja := LojaDeProjeteis.new()
	loja.miniaturas = _miniaturas
	loja.biblioteca = _miniaturas.biblioteca
	loja.forma_atual = str(valores.get("visual", LojaDeProjeteis.Catalogo.PADRAO))
	loja.modelo_atual = str(valores.get("modelo", ""))
	loja.cor = Color(str(skill.vfx.cor))
	_inspector.add_child(loja)
	loja.montar()
	loja.escolheu.connect(_usar_projetil)

func _usar_transformacao(valores: Dictionary) -> void:
	var novo := skill.duplicate(true)
	var evento := _evento_por_id(_evento, novo)
	if evento.is_empty(): (novo.transformacao as Dictionary).merge(valores, true)
	else: (evento.parametros as Dictionary).merge(valores, true)
	if _aplicar_edicao(novo, false): _construir_inspector.call_deferred()


func _usar_projetil(valores: Dictionary) -> void:
	var novo := skill.duplicate(true)
	var evento := _evento_por_id(_evento, novo)
	if evento.is_empty(): (novo.projeteis as Dictionary).merge(valores, true)
	else: (evento.parametros as Dictionary).merge(valores, true)
	if _aplicar_edicao(novo, false):
		_avisar("Projétil: %s. Rodar mostra o disparo." % (str(valores.visual) if valores.visual != LojaDeProjeteis.Catalogo.MODELO else str(valores.modelo)))
		_construir_inspector.call_deferred()

## "Quem usa" (decisão do dono, 06/10/2026): a atribuição mora na skill. Jogador vai para
## a tecla no kit; Inimigo/Chefe/Animal escolhem QUAL na lista do catálogo.
func _campo_quem_usa(dono: String, atual: String) -> void:
	if dono == "Jogador":
		_explicacao("Quem usa: o jogador, pela tecla %s do Kit do Builder (seção Ativação)." % str(skill.ativacao.tecla))
		return
	var opcoes := QuemUsaSkill.opcoes(dono)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	_inspector.add_child(coluna)
	coluna.add_child(Estilo.rotulo("Quem usa", 13, true))
	var op := OptionButton.new()
	op.name = "atribuida_a"
	op.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op.add_item("— escolha —")
	op.set_item_metadata(0, "")
	for o: Dictionary in opcoes:
		op.add_item(str(o.nome))
		op.set_item_metadata(op.item_count - 1, str(o.id))
		if str(o.id) == atual:
			op.select(op.item_count - 1)
	op.item_selected.connect(func(i: int): editar_campo("identificacao", "atribuida_a", str(op.get_item_metadata(i))))
	coluna.add_child(op)
	if opcoes.is_empty():
		_explicacao("Nenhuma opção no catálogo da loja para %s." % dono)
	if not QuemUsaSkill.usada_pela_ia(dono):
		_explicacao("%s: a atribuição fica guardada; a IA ainda não usa (próxima etapa)." % dono)


## FRUTA (06/10/2026, decisão do dono): a skill de Jogador vai para uma fruta do Builder
## (ou para o Kit). "Criar fruta" põe uma fruta nova no catálogo do jogo.
func _campo_fruta(atual: String) -> void:
	CampoDeFruta.montar(self, atual)


## Trocar o Usuário limpa um "Quem usa" que não vale mais e redesenha o painel.
func _editar_dono(dono: String) -> void:
	if _atualizando: return
	var novo := skill.duplicate(true)
	novo.identificacao.dono = dono
	var validos: Array = QuemUsaSkill.opcoes(dono).map(func(o: Dictionary): return str(o.id))
	if not str(novo.identificacao.get("atribuida_a", "")) in validos:
		novo.identificacao.atribuida_a = ""
	if _aplicar_edicao(novo, false):
		_construir_inspector.call_deferred()


# ------------------------------------------------------------ poses
# A seção Poses mora em `editor_de_poses.gd` (06/10/2026, teto de 900 linhas).
const EditorDePoses = preload("res://src/skills_builder/editor_de_poses.gd")
var _botao_poses: Button = null
var _poses = EditorDePoses.new(self)


## "Pose" de um bloco de Animação: as poses da skill (ou o clipe, sem pose).
func _campo_de_pose(atual: String) -> void:
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	_inspector.add_child(coluna)
	coluna.add_child(Estilo.rotulo("Pose", 13, true))
	var op := OptionButton.new()
	op.name = "pose"
	op.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op.add_item("— clipe (sem pose) —")
	op.set_item_metadata(0, "")
	for p: Dictionary in skill.get("poses", []):
		op.add_item(str(p.nome))
		op.set_item_metadata(op.item_count - 1, str(p.id))
		if str(p.id) == atual:
			op.select(op.item_count - 1)
	op.item_selected.connect(_escolher_pose_do_bloco.bind(op))
	coluna.add_child(op)
	if (skill.get("poses", []) as Array).is_empty():
		_explicacao("Crie poses na seção Poses (lista à esquerda).")


func _escolher_pose_do_bloco(i: int, op: OptionButton) -> void:
	editar_campo("animacao", "pose", str(op.get_item_metadata(i)))


func _explicacao(texto: String) -> void:
	var l := Estilo.rotulo(texto, 12, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 1
	_inspector.add_child(l)

func _campo_evento(e: Dictionary) -> void:
	var habilitado := CheckButton.new()
	habilitado.text = "Evento habilitado"
	habilitado.button_pressed = e.habilitado
	habilitado.toggled.connect(func(v: bool): _editar_evento("habilitado", v))
	_inspector.add_child(habilitado)
	_adicionar_campo({"id": "inicio", "nome": "Início (s)", "tipo": "numero", "min": 0, "max": skill.configuracoes.duracao}, e.inicio, func(v: Variant): _mover_evento(_evento, float(v), float(e.duracao)))
	_adicionar_campo({"id": "duracao", "nome": "Duração (s)", "tipo": "numero", "min": .01, "max": skill.configuracoes.duracao}, e.duracao, func(v: Variant): _mover_evento(_evento, float(e.inicio), float(v)))
	_inspector.add_child(Estilo.botao("Usar padrões da categoria", func(): _editar_evento("parametros", {})))

func _adicionar_campo(c: Dictionary, valor: Variant, alterar: Callable) -> void:
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	_inspector.add_child(coluna)
	coluna.add_child(Estilo.rotulo(str(c.nome), 13, true))
	var campo: Control
	match str(c.tipo):
		"numero", "inteiro":
			var spin := _numero(float(c.get("min", 0)), float(c.get("max", 10000)), 1 if c.tipo == "inteiro" else .01, float(valor))
			spin.value_changed.connect(func(v: float): alterar.call(int(v) if c.tipo == "inteiro" else v))
			campo = spin
		"bool":
			var check := CheckButton.new()
			check.text = "Ativado"
			check.button_pressed = bool(valor)
			check.toggled.connect(func(v: bool): alterar.call(v))
			campo = check
		"enum":
			var op := OptionButton.new()
			for v in c.opcoes: op.add_item(str(c.get("rotulos", {}).get(v, v)))   # rótulo: só o que aparece
			op.select(maxi(0, c.opcoes.find(c.get("aceita", {}).get(valor, valor))))   # nome antigo: mostra o atual
			op.item_selected.connect(func(i: int): alterar.call(c.opcoes[i]))
			campo = op
		"cor":
			var cor := ColorPickerButton.new()
			cor.color = Color(str(valor))
			cor.edit_alpha = false
			cor.custom_minimum_size.y = 34
			cor.popup_closed.connect(func(): alterar.call("#" + cor.color.to_html(false)))
			campo = cor
		"longo":
			var texto := TextEdit.new()
			texto.text = str(valor)
			texto.custom_minimum_size.y = 94
			texto.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
			texto.focus_exited.connect(func(): alterar.call(texto.text))
			campo = texto
		_:
			var linha := LineEdit.new()
			linha.text = str(valor)
			linha.max_length = 80
			linha.select_all_on_focus = true
			linha.text_submitted.connect(func(_t: String): linha.release_focus())
			linha.focus_exited.connect(func(): alterar.call(linha.text))
			campo = linha
	campo.name = str(c.id)
	campo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	coluna.add_child(campo)

func _numero(minimo: float, maximo: float, passo: float, valor: float) -> SpinBox:
	var n := SpinBox.new()
	n.min_value = minimo
	n.max_value = maximo
	n.step = passo
	n.value = valor
	n.custom_minimum_size.x = 110
	return n

func editar_campo(secao: String, chave: String, valor: Variant) -> bool:
	if _atualizando: return false
	var novo := skill.duplicate(true)
	var evento := _evento_por_id(_evento, novo)
	if evento.is_empty(): novo[secao][chave] = valor
	else: evento.parametros[chave] = valor
	return _aplicar_edicao(novo, false)

func _aplicar_edicao(novo: Dictionary, reconstruir: bool = true) -> bool:
	if novo == skill: return true
	var r: Dictionary = Dados.validar(novo)
	if not r.ok:
		_avisar("Não aplicado: " + "; ".join(r.erros), true)
		_construir_inspector.call_deferred()
		return false
	_undo.append(skill.duplicate(true))
	if _undo.size() > 80: _undo.pop_front()
	_redo.clear()
	skill = r.skill
	_sincronizar(reconstruir)
	_avisar("Alteração aplicada. Rodar executa a versão editada.")
	return true

func _documento(d: Dictionary, caminho: String = "") -> void:
	skill = d.duplicate(true)
	_caminho = caminho
	_salvo = skill.duplicate(true)
	_undo.clear()
	_redo.clear()
	_evento = ""
	_sincronizar()
	_avisar("Arraste a timeline para ordenar eventos. Botão direito na arena: orbitar • Roda: zoom.")

func _sincronizar(reconstruir: bool = true) -> void:
	_titulo.text = str(skill.identificacao.nome) + (" • alterada" if skill != _salvo else "")
	_desfazer.disabled = _undo.is_empty()
	_refazer.disabled = _redo.is_empty()
	timeline.configurar(skill)
	timeline.selecionado = _evento
	arena.configurar(skill)
	_lista_eventos.clear()
	for e: Dictionary in skill.eventos:
		_lista_eventos.add_item(str(e.id))
		var i := _lista_eventos.item_count - 1
		_lista_eventos.set_item_metadata(i, e.id)
		if e.id == _evento: _lista_eventos.select(i)
	if reconstruir: _construir_inspector()

func _evento_por_id(id: String, documento: Dictionary = {}) -> Dictionary:
	var fonte := skill if documento.is_empty() else documento
	for e: Dictionary in fonte.get("eventos", []):
		if str(e.id) == id: return e
	return {}

func selecionar_evento(id: String) -> void:
	var e := _evento_por_id(id)
	if e.is_empty(): return
	_evento = id
	timeline.selecionado = id
	timeline.queue_redraw()
	_mostrar_secao(str(SECAO_EVENTO.get(e.tipo, e.tipo)), true)
	for i in _lista_eventos.item_count:
		if _lista_eventos.get_item_metadata(i) == id: _lista_eventos.select(i)

func adicionar_evento() -> void:
	var tipo: String = EVENTOS[_tipo_evento.selected]
	var novo := skill.duplicate(true)
	_contador_evento += 1
	var id := tipo + "_" + str(_contador_evento)
	while not _evento_por_id(id).is_empty():
		_contador_evento += 1
		id = tipo + "_" + str(_contador_evento)
	var total := float(skill.configuracoes.duracao)
	var inicio := clampf(arena.tempo, 0, total - .01)
	novo.eventos.append({"id": id, "tipo": tipo, "inicio": inicio, "duracao": minf(.4, total-inicio), "habilitado": true, "parametros": {}})
	if _aplicar_edicao(novo): selecionar_evento(id)

func remover_evento(id: String) -> void:
	if id.is_empty(): return
	var novo := skill.duplicate(true)
	for i in range(novo.eventos.size()-1, -1, -1):
		if novo.eventos[i].id == id: novo.eventos.remove_at(i)
	_evento = ""
	_aplicar_edicao(novo)

func _mover_evento(id: String, inicio: float, duracao: float) -> void:
	var novo := skill.duplicate(true)
	var e := _evento_por_id(id, novo)
	if e.is_empty(): return
	e.inicio = snappedf(inicio, .001)
	e.duracao = snappedf(duracao, .001)
	_aplicar_edicao(novo)

func _editar_evento(chave: String, valor: Variant) -> void:
	var novo := skill.duplicate(true)
	var e := _evento_por_id(_evento, novo)
	if e.is_empty(): return
	e[chave] = valor
	_aplicar_edicao(novo)

func desfazer() -> void:
	if _undo.is_empty(): return
	_redo.append(skill.duplicate(true))
	skill = _undo.pop_back()
	if _evento_por_id(_evento).is_empty(): _evento = ""
	_sincronizar()

func refazer() -> void:
	if _redo.is_empty(): return
	_undo.append(skill.duplicate(true))
	skill = _redo.pop_back()
	_sincronizar()

func executar(manual: bool = false) -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco: foco.release_focus()
	var erro: String = arena.rodar(manual)
	_avisar(erro if not erro.is_empty() else "Executando a habilidade na arena de teste.", not erro.is_empty())

func _process(_delta: float) -> void:
	if not is_instance_valid(arena) or skill.is_empty(): return
	timeline.tempo = arena.tempo
	timeline.queue_redraw()
	var e: Dictionary = arena.estado()
	_metricas.text = "%s%s • %.2f / %.2f s • Alvo %.0f HP\nEnergia %.0f • Recarga %.1f s • Acertos %d" % [e.status, " %.1f s" % float(e.carga) if float(e.carga) > 0 else "", arena.tempo, float(skill.configuracoes.duracao), arena.vida_alvo, arena.energia, float(e.get("recarga", 0)), int(e.get("acertos", 0))]
	_pausa.text = "Continuar" if arena.pausado else "Pausar"

func _camera_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_RIGHT: _arrastando_camera = e.pressed
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP: arena.zoom(-1)
		elif e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN: arena.zoom(1)
	elif e is InputEventMouseMotion and _arrastando_camera:
		arena.orbitar(e.relative)

func _input(e: InputEvent) -> void:
	# Receber a soltura mesmo quando o foco mudou durante a carga.
	if e is InputEventKey and not e.pressed and e.keycode == OS.find_keycode_from_string(str(skill.ativacao.tecla)):
		arena.soltar()
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT and not e.pressed:
		_arrastando_camera = false

func _unhandled_key_input(e: InputEvent) -> void:
	if not e is InputEventKey or not e.pressed or e.echo: return
	if _dialogo.visible or _confirmacao.visible or _biblioteca.visible: return
	var foco := get_viewport().gui_get_focus_owner()
	if foco is LineEdit or foco is TextEdit: return
	if e.ctrl_pressed or e.meta_pressed:
		match e.keycode:
			KEY_S: _salvar()
			KEY_Z:
				if e.shift_pressed: refazer()
				else: desfazer()
			_: return
	elif e.keycode == KEY_F5: executar()
	elif e.keycode == OS.find_keycode_from_string(str(skill.ativacao.tecla)): executar(true)
	else: return
	get_viewport().set_input_as_handled()

func _shortcut_input(e: InputEvent) -> void:
	# Salvar também confirma um campo de texto ainda em edição.
	if e is InputEventKey and e.pressed and not e.echo and (e.ctrl_pressed or e.meta_pressed) and e.keycode == KEY_S:
		if not (_dialogo.visible or _confirmacao.visible or _biblioteca.visible):
			_salvar()
			get_viewport().set_input_as_handled()

func _salvar() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco: foco.release_focus()
	var destino := pasta_skills.path_join(str(skill.identificacao.id) + ".json")
	if FileAccess.file_exists(destino) and destino != _caminho:
		_confirmar("Substituir habilidade", "Já existe uma habilidade com este ID. Substituir o arquivo salvo?", "Substituir", _gravar)
	else: _gravar()

func _gravar() -> void:
	var r: Dictionary = Dados.salvar(skill, pasta_skills)
	if not r.ok:
		_avisar("Falha ao salvar: " + "; ".join(r.erros), true)
		return
	_caminho = str(r.caminho)
	_salvo = skill.duplicate(true)
	_titulo.text = str(skill.identificacao.nome)
	_avisar("Salva: " + _caminho)

## Publicar no jogo (06/10/2026): a skill vai para `res://mapas/skills` e, sendo do
## Jogador, para a tecla dela no Kit do Builder. Tecla ocupada por outra pede confirmação.
func _publicar() -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco: foco.release_focus()
	var v: Dictionary = Dados.validar(skill)
	if not v.ok:
		_avisar("Não publicada: " + "; ".join(v.erros), true)
		return
	if str(skill.identificacao.dono) == SkillsPublicadas.DONO_DO_KIT:
		var tecla := str(skill.ativacao.tecla)
		var fruta := str(skill.identificacao.get("fruta", ""))
		var ocupante := SkillsPublicadas.dono_da_tecla(tecla) if fruta.is_empty() \
			else str((SkillsPublicadas.fruta(fruta).get("teclas", {}) as Dictionary).get(tecla, ""))
		if not ocupante.is_empty() and ocupante != str(skill.identificacao.id):
			_confirmar("Substituir na tecla", "A tecla %s %s é da skill \"%s\". Publicar esta no lugar?" % [tecla,
				("da " + KitDoBuilder.nome(fruta)) if not fruta.is_empty() else "do Kit do Builder", ocupante], "Publicar", _gravar_publicacao)
			return
	_gravar_publicacao()

func _gravar_publicacao() -> void:
	var r: Dictionary = SkillsPublicadas.publicar(skill)
	if not r.ok:
		_avisar("Falha ao publicar: " + "; ".join(r.erros), true)
		return
	var texto := "Publicada no jogo: " + str(r.caminho)
	if str(skill.identificacao.dono) == SkillsPublicadas.DONO_DO_KIT:
		texto = _por_na_loja(str(skill.identificacao.get("fruta", "")))
	var dono := str(skill.identificacao.dono)
	var quem := str(skill.identificacao.get("atribuida_a", ""))
	if not str(r.tecla).is_empty():
		texto += " · tecla %s %s" % [str(r.tecla), ("da " + KitDoBuilder.nome(str(r.fruta))) if not str(r.get("fruta", "")).is_empty() else "do Kit do Builder"]
	elif quem.is_empty():
		texto += " · %s sem \"Quem usa\": ninguém usa ainda" % dono
	else:
		texto += " · %s: %s%s" % [dono, quem, "" if QuemUsaSkill.usada_pela_ia(dono) else " (IA ainda não usa)"]
	_avisar(texto)

## A fruta da skill (ou o Kit) à venda no vendedor de frutas do Modo História, pelo preço
## do campo (07/10/2026). Devolve o começo do aviso.
var _preco_na_loja := -1    # −1 = o preço que a fruta já tem

func _por_na_loja(fruta: String) -> String:
	if SkillsPublicadas.e_reconstruida(fruta):
		return "Publicada: %s já é vendida (fruta da arena)" % KitDoBuilder.nome(fruta)
	var alvo := fruta if not fruta.is_empty() else SkillsPublicadas.ID_DO_KIT
	if alvo == SkillsPublicadas.ID_DO_KIT:
		var preco := _preco_na_loja if _preco_na_loja >= 0 else SkillsPublicadas.preco(alvo)
		var r := SkillsPublicadas.definir_preco(alvo, preco)
		if not r.ok:
			return "Publicada, mas o preço não gravou (%s)" % "; ".join(r.erros)
	return "À venda no vendedor de frutas (Modo História): %s por %s" % [KitDoBuilder.nome(fruta) if not fruta.is_empty() else KitDoBuilder.NOME,
		LojaDeNpc.moedas(PerfilDeFrutas.preco_na_loja(alvo))]

func _testar_no_jogo() -> void:
	var motivo: String = TesteNoJogo.abrir(self)
	if not motivo.is_empty():
		_avisar(motivo, true)

func _abrir_biblioteca() -> void:
	_lista_arquivos.clear()
	for caminho: String in Dados.listar(pasta_skills):
		_lista_arquivos.add_item(caminho.get_file().get_basename())
		_lista_arquivos.set_item_metadata(_lista_arquivos.item_count - 1, caminho)
	if _lista_arquivos.item_count == 0:
		_avisar("Nenhuma habilidade salva. Use Salvar ou Importe um JSON.")
		return
	_lista_arquivos.select(0)
	_biblioteca.popup_centered(Vector2i(500, 330))

func _abrir_selecionada() -> void:
	if _lista_arquivos.get_selected_items().is_empty(): return
	var p := str(_lista_arquivos.get_item_metadata(_lista_arquivos.get_selected_items()[0]))
	_proteger(func(): carregar_habilidade(p))

func carregar_habilidade(caminho: String) -> bool:
	var r: Dictionary = Dados.carregar(caminho)
	if not r.ok:
		_avisar("Arquivo recusado: " + "; ".join(r.erros), true)
		return false
	_documento(r.skill, caminho if caminho.begins_with(pasta_skills + "/") else "")
	return true

func _arquivo(exportar: bool) -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco: foco.release_focus()
	_exportando = exportar
	_dialogo.file_mode = FileDialog.FILE_MODE_SAVE_FILE if exportar else FileDialog.FILE_MODE_OPEN_FILE
	_dialogo.title = "Exportar habilidade" if exportar else "Importar habilidade"
	if exportar: _dialogo.current_file = str(skill.identificacao.id) + ".json"
	_dialogo.popup_centered_ratio(.7)

func _arquivo_escolhido(caminho: String) -> void:
	if not _exportando:
		carregar_habilidade(caminho)
		return
	var validado: Dictionary = Dados.validar(skill)
	if not validado.ok:
		_avisar("Corrija os campos antes de exportar.", true)
		return
	var resultado: Dictionary = Dados.salvar_em(skill, caminho)
	if not resultado.ok:
		_avisar("Falha na exportação: " + "; ".join(resultado.erros), true)
		return
	_avisar("Exportada: " + caminho)

func _id_livre(base: String) -> String:
	var id := base.left(45)
	var i := 1
	while FileAccess.file_exists(pasta_skills.path_join(id + ".json")) or id == str(skill.get("identificacao", {}).get("id", "")):
		i += 1
		id = base.left(45) + "_" + str(i)
	return id

func _duplicar() -> void:
	var copia := skill.duplicate(true)
	copia.identificacao.id = _id_livre(str(skill.identificacao.id) + "_copia")
	copia.identificacao.nome = (str(skill.identificacao.nome) + " — cópia").left(80)
	_caminho = ""
	_aplicar_edicao(copia)

func _novo(tipo: int) -> void:
	var d: Dictionary = Dados.novo()
	d.identificacao.id = _id_livre("nova_skill")
	if tipo == 1:
		d.identificacao.nome = "Projétil de energia"
		d.configuracoes.duracao = 2.5
		d.eventos = [{"id":"disparo", "tipo":"projetil", "inicio":.3, "duracao":1.8, "habilitado":true, "parametros":{}}, {"id":"som", "tipo":"audio", "inicio":.3, "duracao":.3, "habilitado":true, "parametros":{"som":"Disparo"}}]
	elif tipo == 2:
		d.identificacao.nome = "Área de vento"
		d.identificacao.modelo = "Harpia"
		d.identificacao.dono = "Chefe"
		d.configuracoes.duracao = 3.0
		d.vfx.estilo = "Tornado"
		d.hitboxes.raio = 3.0
		d.hitboxes.z = -3.0
		d.eventos = [{"id":"asa", "tipo":"animacao", "inicio":0.0, "duracao":1.2, "habilitado":true, "parametros":{"clipe":"Vendaval"}}, {"id":"vento", "tipo":"vfx", "inicio":.6, "duracao":2.0, "habilitado":true, "parametros":{}}, {"id":"area", "tipo":"hitbox", "inicio":.6, "duracao":1.0, "habilitado":true, "parametros":{}}]
	_documento(d)

func _proteger(acao: Callable) -> void:
	var foco := get_viewport().gui_get_focus_owner()
	if foco: foco.release_focus()
	if skill != _salvo:
		_confirmar("Alterações não salvas", "Descartar as alterações desta habilidade e continuar?", "Descartar", acao)
	else: acao.call()

func _confirmar(titulo: String, texto: String, botao: String, acao: Callable) -> void:
	_pendente = acao
	_confirmacao.title = titulo
	_confirmacao.dialog_text = texto
	_confirmacao.ok_button_text = botao
	_confirmacao.popup_centered(Vector2i(440, 160))

func _avisar(texto: String, erro: bool = false) -> void:
	_status.text = texto
	_status.add_theme_color_override("font_color", Color("ffb4a3") if erro else Estilo.SUAVE)

func _voltar() -> void:
	arena.parar()
	get_tree().root.get_node("GameFlow").back_to_menu()

func _exit_tree() -> void:
	if is_instance_valid(arena) and arena.is_inside_tree(): arena.parar()
	if get_window(): get_window().min_size = _min_anterior
