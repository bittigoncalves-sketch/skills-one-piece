extends PanelContainer
## Três etapas com relógio local, sem timers que sobrevivam ao cancelamento.
signal concluiu
signal cancelou
var etapa := 0
var acertos := 0
var falhas := 0
var tempo := 0.0
var restante := 20.0
var ativa := true
var _titulo: Label
var _dica: Label
@export_range(0.5, 3.0, 0.1) var dificuldade := 1.0
var _barra: Control
var _alvos: HBoxContainer
var _botao: Button
var _alvo := 0
var _bancada: Control
const ORDEM := [1, 3, 0, 2]
const QUANTIDADE_DE_PONTOS := 4
var _cancelada := false

func _ready() -> void:
	GuiMinecraft.aplicar(self)    # fonte, botões e painéis do Minecraft (12/11/2026); sem as texturas locais, não faz nada
	custom_minimum_size = Vector2(620, 500)
	add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	var margem := MarginContainer.new()
	for lado in ["left", "top", "right", "bottom"]: margem.add_theme_constant_override("margin_" + lado, 20)
	add_child(margem)
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 12)
	margem.add_child(c)
	_titulo = EstiloDaHistoria.rotulo("", EstiloDaHistoria.DOURADO, 24)
	c.add_child(_titulo)
	_dica = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 16)
	c.add_child(_dica)
	_bancada = preload("res://src/ui/bancada_ferraria.gd").new()
	var bancada_e_medidor := HBoxContainer.new()
	c.add_child(bancada_e_medidor)
	_bancada.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bancada_e_medidor.add_child(_bancada)
	_bancada.custom_minimum_size.x = 440
	_bancada.martelou.connect(martelar)
	_barra = preload("res://src/ui/medidor_ferraria.gd").new()
	bancada_e_medidor.add_child(_barra)
	_alvos = HBoxContainer.new()
	c.add_child(_alvos)
	for i in QUANTIDADE_DE_PONTOS:
		var b := EstiloDaHistoria.botao(str(i + 1), func(): martelar(i))
		b.custom_minimum_size = Vector2(90, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_alvos.add_child(b)
	_botao = EstiloDaHistoria.botao("Acionar fole", acionar, true)
	c.add_child(_botao)
	c.add_child(EstiloDaHistoria.botao("Cancelar", func(): ativa = false; _cancelada = true; cancelou.emit()))
	_atualizar()

func _process(delta: float) -> void:
	if not ativa: return
	tempo += delta
	restante -= delta
	_atualizar_medidor()
	if restante <= 0:
		_esgotar()
	_atualizar_titulo()

func janela_correta() -> bool:
	var zona := zona_de_acerto()
	return posicao_do_marcador() >= zona.x and posicao_do_marcador() <= zona.y

func velocidade_do_marcador() -> float:
	# Resfriar exige mais precisão que aquecer. Dificuldade controla velocidade
	# e largura da faixa; desenho e validação consultam as mesmas funções.
	return (0.5 if etapa == 0 else 0.7) * clampf(dificuldade, 0.5, 3.0)

func zona_de_acerto() -> Vector2:
	var metade := (0.15 if etapa == 0 else 0.11) / sqrt(clampf(dificuldade, 0.5, 3.0))
	return Vector2(0.5 - metade, 0.5 + metade)

func posicao_do_marcador() -> float:
	return pingpong(tempo * velocidade_do_marcador(), 1.0)

func _atualizar_medidor() -> void:
	_barra.atualizar(posicao_do_marcador(), zona_de_acerto(), acertos, fmod(tempo * velocidade_do_marcador(), 2.0) < 1.0)

func _esgotar() -> void:
	ativa = false
	restante = 0
	_dica.text = "Tempo esgotado. Tente novamente sem perder itens."
	_botao.text = "Tentar novamente"
	_botao.show()
	for botao in _alvos.get_children(): botao.disabled = true

func acionar() -> void:
	if _cancelada or etapa >= 3: return
	if not ativa:
		etapa = 0; acertos = 0; falhas = 0; tempo = 0; restante = 20; ativa = true; _alvo = 0
		_atualizar()
		return
	if restante <= 0:
		_esgotar()
		return
	if etapa == 1: return
	_bancada.tocar(janela_correta())
	if janela_correta():
		acertos += 1
		# Reinicia o ciclo: spam de clique no mesmo intervalo não dá vários acertos.
		tempo = 0
		if acertos >= 3: _proxima()
	else:
		falhas += 1
		restante = maxf(0, restante - 2)
	_atualizar()

func martelar(indice: int) -> void:
	if not ativa or etapa != 1: return
	if restante <= 0:
		_esgotar()
		return
	_bancada.tocar(indice == ORDEM[_alvo], indice)
	if indice == ORDEM[_alvo]:
		acertos += 1
		_alvo += 1
		if _alvo >= ORDEM.size(): _proxima()
	else:
		falhas += 1
		restante = maxf(0, restante - 3)
	_atualizar()

func _proxima() -> void:
	etapa += 1
	acertos = 0
	tempo = 0
	restante = 20
	if etapa >= 3:
		ativa = false
		concluiu.emit()

func _atualizar_titulo() -> void:
	if etapa < 3: _titulo.text = "%d/3 · %s · %.1f s" % [etapa + 1, ["Acender a fornalha", "Martelar a lâmina", "Esfriar a lâmina"][etapa], maxf(0, restante)]

func _atualizar() -> void:
	if etapa >= 3: return
	_atualizar_titulo()
	_bancada.atualizar(etapa, ORDEM[mini(_alvo, ORDEM.size() - 1)])
	_barra.visible = etapa != 1
	_alvos.visible = etapa == 1
	_botao.visible = etapa != 1
	_botao.text = "Acionar fole" if etapa == 0 else "Mergulhar lâmina"
	_dica.text = "Acione quando o traço branco passar pela faixa verde.\nEspaço ou botão · %d/3 acertos · %s" % [acertos, "ritmo tranquilo" if etapa == 0 else "ritmo mais rápido"] if etapa != 1 else "Martele o ponto dourado antes que o tempo acabe.\nClique no ponto ou use 1, 2, 3, 4 · %d/4 acertos." % acertos
	_atualizar_medidor()
	for botao in _alvos.get_children(): botao.disabled = not ativa
	if etapa == 1:
		for i in QUANTIDADE_DE_PONTOS: EstiloDaHistoria.estilizar_botao(_alvos.get_child(i), i == ORDEM[_alvo])
	if restante <= 0: _esgotar()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or _cancelada or etapa >= 3: return
	var tecla: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	var indice := -1
	if tecla >= KEY_1 and tecla <= KEY_4: indice = tecla - KEY_1
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_4: indice = event.keycode - KEY_KP_1
	if indice < 0 and tecla not in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: return
	# Antes do GUI: Espaço não pode acionar o botão que ficou focado pelo mouse,
	# nem números trocar o equipamento enquanto a forja está aberta.
	get_viewport().set_input_as_handled()
	if not event.pressed or event.echo: return
	if indice >= 0: martelar(indice)
	else: acionar()
