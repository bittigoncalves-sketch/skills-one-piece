class_name CaixaDeFalaCinematografica
extends Control
# ============================================================================
#  CAIXA DE FALA CINEMATOGRÁFICA (21/11/2026) — a conversa com NPC como cena de filme: tarjas pretas finas (letterbox) em cima e embaixo da tela e uma
#  faixa de legenda larga logo ACIMA da barra de nível (o XP do `HudMinecraft`), com o nome de quem fala e o texto em máquina de escrever.
#
#  Controles (decisão do dono, 21/11): E, Enter, Espaço ou clique → completa a linha; de novo → próxima; ESC → pula tudo.
#  Uso: `tocar(linhas, ao_fim)`; `linhas` = [{falante, texto}] (`DialogosDeNpc`). `ao_fim` roda UMA vez, ao acabar OU ao pular.
#  Posição: `barra` (a hotbar) dá a âncora; sem ela a faixa fica a 150 px da base. `ativa()` entra no `is_menu_open` da HUD (o jogador para de andar).
#  GATILHO: retrato do falante → um `TextureRect` à esquerda da faixa, preenchido por `falante` (hoje só o nome).
# ============================================================================
signal terminou
signal linha_mudou(indice: int, linha: Dictionary)      # cada linha que começa (o orquestrador troca a expressão do falante)
signal pediu_pular          # só no modo cena: o jogador apertou ESC

const CPS := 38.0                      # caracteres por segundo da máquina de escrever
const ALTURA_TARJA := 0.085            # fração da altura da tela
const ALTURA_FAIXA := 116.0      # altura FIXA (nome + 2 linhas de 20 px + dica): o conteúdo não pode esticar a faixa para cima do XP
const MARGEM_SOBRE_XP := 14.0          # espaço entre a faixa e o número do nível
const LARGURA_MAX := 880.0
const COR_FAIXA := Color(0.02, 0.03, 0.05, 0.93)
const COR_FIO := Color(0.95, 0.79, 0.40)           # o dourado da campanha (`EstiloDaHistoria.DOURADO`)
const ENTRADA := 0.28                  # segundos de entrada/saída (tarjas e faixa)

var barra: Control = null              # a hotbar: ancora a faixa acima do XP
var _linhas: Array[Dictionary] = []
var _indice := 0
var _revelado := 0.0                   # caracteres já visíveis (float: acumula por quadro)
var _ao_fim: Callable = Callable()
var _tocando := false
var _entrada := 0.0                    # 0..1: animação de entrada/saída
var _saindo := false
var _modo_cena := false                # cutscene: tarjas fixas, legendas sem avanço do jogador (`entrar_em_cena`)

var _tarja_cima: ColorRect
var _tarja_baixo: ColorRect
var _faixa: PanelContainer
var _nome: Label
var _texto: Label
var _dica: Label


func _ready() -> void:
	name = "CaixaDeFalaCinematografica"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_tarja_cima = _tarja("TarjaCima")
	_tarja_baixo = _tarja("TarjaBaixo")
	_faixa = PanelContainer.new()
	_faixa.name = "Faixa"
	_faixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.custom_minimum_size = Vector2(0.0, ALTURA_FAIXA)
	_faixa.clip_contents = true
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COR_FAIXA
	estilo.border_color = COR_FIO
	estilo.border_width_top = 2
	estilo.content_margin_left = 28.0
	estilo.content_margin_right = 28.0
	estilo.content_margin_top = 12.0
	estilo.content_margin_bottom = 10.0
	_faixa.add_theme_stylebox_override("panel", estilo)
	add_child(_faixa)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 4)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_faixa.add_child(coluna)
	_nome = _rotulo(16, COR_FIO)
	coluna.add_child(_nome)
	_texto = _rotulo(20, Color(0.96, 0.97, 0.98))
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.size_flags_vertical = Control.SIZE_EXPAND_FILL
	coluna.add_child(_texto)
	_dica = _rotulo(13, Color(0.66, 0.76, 0.82))
	_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coluna.add_child(_dica)


func _tarja(nome: String) -> ColorRect:
	var t := ColorRect.new()
	t.name = nome
	t.color = Color.BLACK
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(t)
	return t


func _rotulo(tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fonte := FonteMinecraft.fonte()
	if fonte != null:
		l.add_theme_font_override("font", fonte)
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	return l


func ativa() -> bool:
	return _tocando


## Começa a cena. Sem linhas válidas, `ao_fim` roda na hora (nada a mostrar não pode travar o fluxo).
func tocar(linhas: Array[Dictionary], ao_fim: Callable = Callable()) -> void:
	if _tocando:
		pular()
	_ao_fim = ao_fim
	_linhas = linhas
	_indice = 0
	if _linhas.is_empty():
		_finalizar()
		return
	_tocando = true
	_saindo = false
	_entrada = 0.0
	visible = true
	_mostrar_linha()
	_posicionar()


## CUTSCENE (21/11/2026): as tarjas entram e ficam; a faixa só aparece quando há `legenda`. O jogador só pode apertar ESC (`pediu_pular`).
func entrar_em_cena() -> void:
	if _tocando:
		pular()
	_modo_cena = true
	_linhas = [{"falante": "", "texto": ""}]
	_indice = 0
	_ao_fim = Callable()
	_tocando = true
	_saindo = false
	_entrada = 0.0
	visible = true
	_mostrar_linha()
	_posicionar()


## Legenda da cena (vazia = some a faixa, ficam só as tarjas).
func legenda(falante: String, texto: String) -> void:
	if not (_tocando and _modo_cena):
		return
	_linhas = [{"falante": falante, "texto": texto}]
	_indice = 0
	_mostrar_linha()


func sair_de_cena() -> void:
	if _tocando and _modo_cena and not _saindo:
		_saindo = true


func em_cena() -> bool:
	return _tocando and _modo_cena


## Primeiro acionamento completa a linha; o segundo vai para a próxima (ou encerra).
func avancar() -> void:
	if not _tocando or _saindo:
		return
	if _revelado < float(_texto_atual().length()):
		_revelado = float(_texto_atual().length())
		_atualizar_texto()
		return
	_indice += 1
	if _indice >= _linhas.size():
		_encerrar()
	else:
		_mostrar_linha()


func pular() -> void:
	if _tocando and not _saindo:
		_encerrar()


func linha_atual() -> Dictionary:
	return _linhas[_indice] if _tocando and _indice < _linhas.size() else {}


func completa() -> bool:
	return _tocando and _revelado >= float(_texto_atual().length())


func _texto_atual() -> String:
	return str(_linhas[_indice].get("texto", "")) if _indice < _linhas.size() else ""


func _mostrar_linha() -> void:
	_revelado = 0.0
	var falante := str(_linhas[_indice].get("falante", ""))
	_nome.text = falante
	_nome.visible = not falante.is_empty()
	linha_mudou.emit(_indice, _linhas[_indice])
	_atualizar_texto()
	_atualizar_dica()


func _atualizar_texto() -> void:
	_texto.text = _texto_atual().substr(0, int(_revelado))
	_atualizar_dica()


func _atualizar_dica() -> void:
	var ultima := _indice >= _linhas.size() - 1
	if _modo_cena:
		_dica.text = ""
		return
	_dica.text = ("E — continuar" if not ultima else "E — fechar") + "   ·   ESC — pular" if completa() else ""


## A saída anima as tarjas e a faixa; o callback roda no fim dela, com o jogador já liberado visualmente.
func _encerrar() -> void:
	_saindo = true


func _finalizar() -> void:
	_modo_cena = false
	_tocando = false
	_saindo = false
	visible = false
	var cb := _ao_fim
	_ao_fim = Callable()
	_linhas = []
	terminou.emit()
	if cb.is_valid():
		cb.call()


func _process(delta: float) -> void:
	if not _tocando:
		return
	if _saindo:
		_entrada = maxf(_entrada - delta / ENTRADA, 0.0)
		if _entrada <= 0.0:
			_finalizar()
			return
	else:
		_entrada = minf(_entrada + delta / ENTRADA, 1.0)
		if _revelado < float(_texto_atual().length()):
			_revelado = minf(_revelado + CPS * delta, float(_texto_atual().length()))
			_atualizar_texto()
	_posicionar()


## Tarjas deslizam para dentro; a faixa sobe de baixo até ficar acima do número do nível. Easing suave (saída cúbica).
func _posicionar() -> void:
	var tela := get_viewport_rect().size
	var e := 1.0 - pow(1.0 - clampf(_entrada, 0.0, 1.0), 3.0)
	var h_tarja := tela.y * ALTURA_TARJA
	_tarja_cima.size = Vector2(tela.x, h_tarja)
	_tarja_cima.position = Vector2(0.0, -h_tarja * (1.0 - e))
	_tarja_baixo.size = Vector2(tela.x, h_tarja)
	_tarja_baixo.position = Vector2(0.0, tela.y - h_tarja * e)
	var largura := minf(LARGURA_MAX, tela.x - 48.0)
	_faixa.size = Vector2(largura, ALTURA_FAIXA)
	var fundo_y := _topo_do_nivel() - MARGEM_SOBRE_XP
	var x := (tela.x - largura) * 0.5
	var y_final := fundo_y - ALTURA_FAIXA
	_faixa.position = Vector2(x, lerpf(tela.y, y_final, e))
	_faixa.modulate.a = e
	_faixa.visible = not (_modo_cena and _texto_atual().is_empty())


## Topo do número do nível (acima do XP): a hotbar sobe 22 px, mais 16 px vanilla (nível + XP) na escala do `HudMinecraft`.
func _topo_do_nivel() -> float:
	var tela := get_viewport_rect().size
	if barra == null or not is_instance_valid(barra):
		return tela.y - 150.0
	var r := barra.get_global_rect()
	return r.position.y + 22.0 - 16.0 * HudMinecraft.ESCALA


func _input(evento: InputEvent) -> void:
	if not _tocando or _saindo:
		return
	var tecla := evento as InputEventKey
	if _modo_cena:
		if tecla != null and tecla.pressed and not tecla.echo and tecla.keycode == KEY_ESCAPE:
			pediu_pular.emit()
			get_viewport().set_input_as_handled()
		elif evento is InputEventMouseButton or tecla != null:
			get_viewport().set_input_as_handled()          # a cena não deixa o jogador agir por baixo
		return
	if tecla != null and tecla.pressed and not tecla.echo:
		if tecla.keycode == KEY_ESCAPE:
			pular()
			get_viewport().set_input_as_handled()
		elif tecla.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] or tecla.physical_keycode == KEY_E:
			avancar()
			get_viewport().set_input_as_handled()
		return
	var clique := evento as InputEventMouseButton
	if clique != null and clique.pressed and clique.button_index == MOUSE_BUTTON_LEFT:
		avancar()
		get_viewport().set_input_as_handled()
