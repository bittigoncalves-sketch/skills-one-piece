class_name DummyToggleHud
extends Control
# ============================================================================
#  BONECOS DE TREINO — interruptor no canto inferior direito (2026-08-23).
#
#  Mostra os dois bonecos do mapa e se cada um está no ar. O estado de verdade
#  mora no `GameFlow` (e em `user://settings.cfg`); este painel é só a cara dele.
#
#  ---------------------------------------------- POR QUE TEM TECLA, E NÃO SÓ CLIQUE
#  Em partida o mouse fica CAPTURADO (a câmera é o mouse). Um painel que só
#  respondesse a clique seria decoração: o cursor está travado no centro da tela
#  e o clique esquerdo é soco. Então o acionamento de verdade é **F1 / F2**, e o
#  clique continua valendo para quando o cursor está livre (menu aberto). O
#  painel imprime a tecla ao lado de cada linha justamente porque, sem isso,
#  ninguém descobre que ela existe.
#
#  ------------------------------------------------------- POR QUE ESTE CANTO
#  Foi pedido assim. O canto inferior direito já é do `AmmoHud`, então ele
#  cede espaço: o `AmmoHud` sobe `ALTURA_TOTAL` pixels e os dois empilham em vez
#  de se sobreporem. A conta mora AQUI (e não lá) porque quem chegou por último
#  é quem tem de se apresentar — o `AmmoHud` só lê o número.
#
#  ------------------------------------------------------------- QUEM SÓ OLHA
#  Num jogo em rede o interruptor é do MUNDO (ver `Main.pedir_dummy`): quem
#  clica manda um pedido ao servidor. Não há caso "meu boneco / seu boneco".
# ============================================================================

const LARGURA := 250.0
const LINHA := 26.0
const MARGEM := 20.0
const PAD := 10.0
const ALTURA := PAD * 2.0 + LINHA * 2.0                 # duas linhas, sem título
const ALTURA_TOTAL := ALTURA + MARGEM                    # o que o AmmoHud reserva

const COR_FUNDO := Color(0.05, 0.05, 0.08, 0.62)
const COR_LIGADO := Color(0.45, 0.95, 0.55)
const COR_DESLIGADO := Color(0.55, 0.55, 0.60)
const COR_TECLA := Color(0.75, 0.78, 0.85)

# tecla -> tipo de boneco. A ORDEM desta lista é a ordem das linhas na tela.
const ATALHOS := [
	{"tecla": KEY_F1, "rotulo": "F1", "tipo": "TrainingDummy", "nome": "Boneco de treino"},
	{"tecla": KEY_F2, "rotulo": "F2", "tipo": "AutoDummy",     "nome": "Boneco automático"},
]

var _painel: ColorRect
var _linhas: Array = []      # [{ "raiz": Control, "marca": Label, "nome": Label }]

func _ready() -> void:
	# ⚠️ `set_anchors_and_offsets_preset`, NUNCA só `set_anchors_preset`. O
	# segundo recalcula as âncoras para MANTER o retângulo atual — que aqui é
	# (0,0) —, e aí toda conta de filho resolve contra zero: o painel ia parar em
	# (−270, −92), fora da tela pela esquerda e por cima. É a mesma armadilha que
	# o `MatchHud` documenta desde 2026-08-12; caí nela de novo e só apareceu na
	# captura de tela do jogo rodando, porque em nó nenhum ela vira erro.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# IGNORE na raiz e STOP só nas linhas: o painel inteiro não pode roubar o
	# clique de mira do resto da tela, mas cada linha precisa receber o dela.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_construir()
	_atualizar_visual()

# O painel é uma VISTA de `GameFlow.dummies`, e o estado muda por três caminhos:
# esta tela, o menu principal (ESC) e qualquer script. Só redesenhar no clique
# deixava a caixinha mentindo — medido: desligar pelo menu tirava o boneco do
# mapa e o canto continuava marcando `[x]`. Reler todo quadro é o que garante
# que a tela nunca discorde do estado; o cache evita repintar à toa.
var _ultimo: Array = []

func _process(_dt: float) -> void:
	var agora: Array = []
	for dados in ATALHOS:
		agora.append(GameFlow.dummy_ligado(str(dados["tipo"])))
	if agora != _ultimo:
		_ultimo = agora
		_atualizar_visual()

func _construir() -> void:
	# Ancorado no canto inferior direito por OFFSET, não por conta em `_process`:
	# assim ele acompanha redimensionamento de janela de graça.
	_painel = ColorRect.new()
	_painel.color = COR_FUNDO
	_painel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_painel.offset_left = -(LARGURA + MARGEM)
	_painel.offset_top = -(ALTURA + MARGEM)
	_painel.offset_right = -MARGEM
	_painel.offset_bottom = -MARGEM
	_painel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_painel)

	for i in ATALHOS.size():
		var dados: Dictionary = ATALHOS[i]
		var linha := Control.new()
		linha.position = Vector2(PAD, PAD + LINHA * i)
		linha.size = Vector2(LARGURA - PAD * 2.0, LINHA)
		linha.mouse_filter = Control.MOUSE_FILTER_STOP
		linha.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		linha.gui_input.connect(_on_linha_clicada.bind(str(dados["tipo"])))
		_painel.add_child(linha)

		var marca := Label.new()
		marca.text = "[x]"
		marca.add_theme_font_size_override("font_size", 14)
		linha.add_child(marca)

		var nome := Label.new()
		nome.text = str(dados["nome"])
		nome.position = Vector2(30, 0)
		nome.add_theme_font_size_override("font_size", 13)
		linha.add_child(nome)

		var tecla := Label.new()
		tecla.text = str(dados["rotulo"])
		tecla.position = Vector2(LARGURA - PAD * 2.0 - 24.0, 0)
		tecla.add_theme_font_size_override("font_size", 12)
		tecla.add_theme_color_override("font_color", COR_TECLA)
		linha.add_child(tecla)

		_linhas.append({"marca": marca, "nome": nome})

# F1/F2: o caminho que funciona com o mouse capturado. `_unhandled_input` e não
# `_input` para não passar na frente de um campo de texto (o ID da sala) nem de
# um menu aberto que já tenha consumido a tecla.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	for dados in ATALHOS:
		if event.keycode == dados["tecla"]:
			_alternar(str(dados["tipo"]))
			get_viewport().set_input_as_handled()
			return

func _on_linha_clicada(event: InputEvent, tipo: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_alternar(tipo)

func _alternar(tipo: String) -> void:
	var novo := not GameFlow.dummy_ligado(tipo)
	GameFlow.set_dummy(tipo, novo)      # grava a preferência E aplica no mundo
	_atualizar_visual()
	print("🎯 %s: %s" % [GameFlow.DUMMIES.get(tipo, tipo), "LIGADO" if novo else "DESLIGADO"])

func _atualizar_visual() -> void:
	for i in ATALHOS.size():
		var ligado := GameFlow.dummy_ligado(str(ATALHOS[i]["tipo"]))
		var cor := COR_LIGADO if ligado else COR_DESLIGADO
		var l: Dictionary = _linhas[i]
		l["marca"].text = "[x]" if ligado else "[ ]"
		l["marca"].add_theme_color_override("font_color", cor)
		l["nome"].add_theme_color_override("font_color", cor)
