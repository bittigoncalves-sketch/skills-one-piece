extends Control
## Timeline do Skills Builder. Trabalha sobre uma cópia do documento: o pai
## aplica alterou/excluir_pedido ao modelo e chama configurar() após a edição.

signal selecionou(id: String)
signal alterou(id: String, inicio: float, duracao: float)
signal buscou(tempo: float)
signal excluir_pedido(id: String)

const FAIXAS: Array[String] = ["hitbox", "movimento", "projetil", "animacao", "vfx", "audio", "camera", "transformacao"]
const NOMES: Array[String] = ["Hitboxes", "Movimento", "Projéteis", "Animação", "VFX", "Áudio", "Câmera", "Transformação"]
const CORES: Array[Color] = [Color("edba60"), Color("68b9e7"), Color("df8c69"), Color("b7a1e7"), Color("75cdb1"), Color("d798bc"), Color("9ebbd0"), Color("e0b8ff")]
const MARGEM: float = 120.0
const REGUA: float = 28.0
const ALTURA_FAIXA: float = 26.0
const SNAP: float = 0.05

var selecionado: String = "":
	set(valor):
		selecionado = valor
		queue_redraw()
var tempo: float = 0.0:
	set(valor):
		tempo = clampf(valor, 0.0, _duracao)
		queue_redraw()

var _documento: Dictionary = {}
var _eventos: Array = []
var _duracao: float = 2.0
var _arraste: String = ""
var _id_arrastado: String = ""
var _origem_mouse: float = 0.0
var _inicio_original: float = 0.0
var _duracao_original: float = 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	focus_entered.connect(queue_redraw)
	focus_exited.connect(_perdeu_foco)
	mouse_exited.connect(_saiu_mouse)


func _get_minimum_size() -> Vector2:
	return Vector2(500.0, REGUA + ALTURA_FAIXA * FAIXAS.size() + 20.0)


func configurar(documento: Dictionary) -> void:
	_documento = documento.duplicate(true)
	var configuracoes: Dictionary = _documento.get("configuracoes", {})
	_duracao = maxf(SNAP, float(configuracoes.get("duracao", 2.0)))
	_eventos = _documento.get("eventos", [])
	_arraste = ""
	_id_arrastado = ""
	if _evento_por_id(selecionado).is_empty():
		selecionado = ""
	tempo = tempo
	queue_redraw()


func _draw() -> void:
	var fonte: Font = get_theme_default_font()
	var largura: float = _largura_util()
	var fim: float = REGUA + ALTURA_FAIXA * FAIXAS.size()
	draw_rect(Rect2(Vector2.ZERO, size), Color("111922"))
	draw_rect(Rect2(0.0, 0.0, size.x, REGUA), Color("1b2835"))
	draw_string(fonte, Vector2(10, 19), "TEMPO / s", HORIZONTAL_ALIGNMENT_LEFT, 88, 11, Color("9dadbd"))
	for indice: int in range(FAIXAS.size()):
		var y: float = REGUA + ALTURA_FAIXA * indice
		var fundo: Color = Color("18232e") if indice % 2 == 0 else Color("141e28")
		draw_rect(Rect2(0.0, y, size.x, ALTURA_FAIXA), fundo)
		draw_rect(Rect2(8.0, y + 9.0, 3.0, 8.0), CORES[indice])
		draw_string(fonte, Vector2(17.0, y + 17.0), NOMES[indice], HORIZONTAL_ALIGNMENT_LEFT, MARGEM - 22.0, 12, Color("d6e0e8"))
		draw_line(Vector2(MARGEM, y + ALTURA_FAIXA), Vector2(MARGEM + largura, y + ALTURA_FAIXA), Color("26323e"))
	var passo: float = _passo_regua()
	var marca: float = 0.0
	while marca <= _duracao + 0.0001:
		var x: float = _x_de_tempo(marca)
		draw_line(Vector2(x, REGUA - 5.0), Vector2(x, fim), Color("334351"), 1.0)
		var rotulo: String = "%.2f" % marca if passo < 0.1 else "%.1f" % marca
		if x + 34.0 < size.x:
			draw_string(fonte, Vector2(x + 4.0, 18.0), rotulo, HORIZONTAL_ALIGNMENT_LEFT, 43, 11, Color("a9bdcd"))
		marca += passo
	for item: Variant in _eventos:
		if not item is Dictionary:
			continue
		var evento: Dictionary = item
		var indice: int = FAIXAS.find(str(evento.get("tipo", "")))
		if indice < 0:
			continue
		var retangulo: Rect2 = _retangulo_evento(evento)
		var ativo: bool = evento.get("habilitado", true) == true
		var cor: Color = CORES[indice]
		if not ativo:
			cor = cor.darkened(0.6)
		draw_rect(retangulo, cor.darkened(0.65))
		draw_rect(Rect2(retangulo.position, Vector2(3.0, retangulo.size.y)), cor)
		var escolhido: bool = str(evento.get("id", "")) == selecionado
		draw_rect(retangulo, Color("edf7ff") if escolhido else cor.darkened(0.18), false, 2.0 if escolhido else 1.0)
		if retangulo.size.x >= 24.0:
			var parametros: Dictionary = evento.get("parametros", {})
			var titulo: String = str(evento.get("nome", parametros.get("nome", NOMES[indice])))
			if not ativo:
				titulo = "× " + titulo
			titulo = _abreviar(fonte, titulo, retangulo.size.x - 17.0)
			draw_string(fonte, retangulo.position + Vector2(7.0, 15.0), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("edf5fa") if ativo else Color("8c9aa7"))
		if retangulo.size.x >= 14.0:
			var puxador_x: float = retangulo.end.x - 5.0
			draw_line(Vector2(puxador_x, retangulo.position.y + 5.0), Vector2(puxador_x, retangulo.end.y - 5.0), cor, 2.0)
	var cursor_x: float = _x_de_tempo(tempo)
	draw_line(Vector2(cursor_x, REGUA - 1.0), Vector2(cursor_x, fim), Color("f1f8ff"), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(cursor_x - 5.0, REGUA - 8.0), Vector2(cursor_x + 5.0, REGUA - 8.0), Vector2(cursor_x, REGUA)]), Color("f1f8ff"))
	var ajuda: String = "Arraste: mover  ·  Borda: duração  ·  Shift: livre  ·  ← →: 0,05 s  ·  Del: excluir"
	draw_string(fonte, Vector2(10.0, fim + 15.0), _abreviar(fonte, ajuda, size.x - 20.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9badbd"))
	if has_focus():
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), Color("63b5dc"), false, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var botao: InputEventMouseButton = event
		if botao.button_index != MOUSE_BUTTON_LEFT:
			return
		if botao.pressed:
			grab_focus()
			if botao.position.y <= REGUA and botao.position.x >= MARGEM:
				_arraste = "tempo"
				_buscar(botao.position.x)
			else:
				var evento: Dictionary = _evento_no_ponto(botao.position)
				if not evento.is_empty():
					selecionado = str(evento.get("id", ""))
					_id_arrastado = selecionado
					_origem_mouse = botao.position.x
					_inicio_original = float(evento.get("inicio", 0.0))
					_duracao_original = float(evento.get("duracao", 0.0))
					var retangulo: Rect2 = _retangulo_evento(evento)
					var limite: float = minf(8.0, retangulo.size.x * 0.4)
					_arraste = "duracao" if botao.position.x >= retangulo.end.x - limite else "inicio"
					selecionou.emit(selecionado)
		else:
			_finalizar_arraste()
		accept_event()
	elif event is InputEventMouseMotion:
		var movimento: InputEventMouseMotion = event
		if _arraste == "tempo":
			_buscar(movimento.position.x)
		elif not _arraste.is_empty():
			_atualizar_arraste(movimento.position.x, movimento.shift_pressed)
		else:
			var evento: Dictionary = _evento_no_ponto(movimento.position)
			var borda: bool = false
			if not evento.is_empty():
				var retangulo: Rect2 = _retangulo_evento(evento)
				borda = movimento.position.x >= retangulo.end.x - minf(8.0, retangulo.size.x * 0.4)
			mouse_default_cursor_shape = Control.CURSOR_HSIZE if borda else Control.CURSOR_POINTING_HAND if not evento.is_empty() else Control.CURSOR_ARROW
		accept_event()
	elif event is InputEventKey:
		var tecla: InputEventKey = event
		if not tecla.pressed:
			return
		if tecla.keycode == KEY_ESCAPE and not _arraste.is_empty():
			_cancelar_arraste()
			accept_event()
			return
		if selecionado.is_empty() or not _arraste.is_empty():
			return
		if tecla.keycode == KEY_DELETE or tecla.keycode == KEY_BACKSPACE:
			excluir_pedido.emit(selecionado)
			accept_event()
		elif tecla.keycode == KEY_LEFT or tecla.keycode == KEY_RIGHT:
			var evento: Dictionary = _evento_por_id(selecionado)
			if evento.is_empty():
				return
			var antes: float = float(evento.get("inicio", 0.0))
			var duracao: float = clampf(float(evento.get("duracao", 0.0)), 0.0, _duracao)
			var direcao: float = -1.0 if tecla.keycode == KEY_LEFT else 1.0
			var inicio: float = clampf(antes + direcao * SNAP, 0.0, _duracao - duracao)
			if not is_equal_approx(inicio, antes):
				evento["inicio"] = inicio
				alterou.emit(selecionado, inicio, duracao)
				queue_redraw()
			accept_event()


func _get_tooltip(at_position: Vector2) -> String:
	var evento: Dictionary = _evento_no_ponto(at_position)
	if evento.is_empty():
		return "Clique na régua para buscar um instante. Arraste a borda direita de um evento para ajustar sua duração."
	return "%s · %s\nInício %.2f s · Duração %.2f s%s" % [str(evento.get("tipo", "")), str(evento.get("id", "")), float(evento.get("inicio", 0.0)), float(evento.get("duracao", 0.0)), "\nDesabilitado" if evento.get("habilitado", true) != true else ""]


func _atualizar_arraste(x: float, livre: bool) -> void:
	var evento: Dictionary = _evento_por_id(_id_arrastado)
	if evento.is_empty():
		return
	var delta: float = (x - _origem_mouse) / _largura_util() * _duracao
	if _arraste == "duracao":
		var nova: float = _duracao_original + delta
		if not livre:
			nova = snappedf(nova, SNAP)
		evento["duracao"] = clampf(nova, minf(SNAP, _duracao - _inicio_original), maxf(0.0, _duracao - _inicio_original))
	else:
		var novo: float = _inicio_original + delta
		if not livre:
			novo = snappedf(novo, SNAP)
		evento["inicio"] = clampf(novo, 0.0, maxf(0.0, _duracao - _duracao_original))
	queue_redraw()


func _finalizar_arraste() -> void:
	var evento: Dictionary = _evento_por_id(_id_arrastado)
	var mudou: bool = not evento.is_empty() and (not is_equal_approx(float(evento.get("inicio", 0.0)), _inicio_original) or not is_equal_approx(float(evento.get("duracao", 0.0)), _duracao_original))
	var id_final: String = _id_arrastado
	_arraste = ""
	_id_arrastado = ""
	if mudou:
		alterou.emit(id_final, float(evento.get("inicio", 0.0)), float(evento.get("duracao", 0.0)))
	queue_redraw()


func _cancelar_arraste() -> void:
	var evento: Dictionary = _evento_por_id(_id_arrastado)
	if not evento.is_empty():
		evento["inicio"] = _inicio_original
		evento["duracao"] = _duracao_original
	_arraste = ""
	_id_arrastado = ""
	queue_redraw()


func _perdeu_foco() -> void:
	_cancelar_arraste()
	queue_redraw()


func _saiu_mouse() -> void:
	if _arraste.is_empty():
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func _buscar(x: float) -> void:
	tempo = (x - MARGEM) / _largura_util() * _duracao
	buscou.emit(tempo)


func _largura_util() -> float:
	return maxf(1.0, size.x - MARGEM - 12.0)


func _x_de_tempo(valor: float) -> float:
	return MARGEM + clampf(valor / _duracao, 0.0, 1.0) * _largura_util()


func _retangulo_evento(evento: Dictionary) -> Rect2:
	var indice: int = FAIXAS.find(str(evento.get("tipo", "")))
	var inicio: float = clampf(float(evento.get("inicio", 0.0)), 0.0, _duracao)
	var duracao: float = maxf(0.0, float(evento.get("duracao", 0.0)))
	var x: float = _x_de_tempo(inicio)
	var largura: float = maxf(8.0, _x_de_tempo(inicio + duracao) - x)
	x = minf(x, MARGEM + _largura_util() - largura)
	return Rect2(x, REGUA + indice * ALTURA_FAIXA + 3.0, largura, ALTURA_FAIXA - 6.0)


func _evento_no_ponto(ponto: Vector2) -> Dictionary:
	for indice: int in range(_eventos.size() - 1, -1, -1):
		var item: Variant = _eventos[indice]
		if item is Dictionary and FAIXAS.has(str(item.get("tipo", ""))) and _retangulo_evento(item).has_point(ponto):
			return item
	return {}


func _evento_por_id(id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for item: Variant in _eventos:
		if item is Dictionary and str(item.get("id", "")) == id:
			return item
	return {}


func _passo_regua() -> float:
	var necessario: float = _duracao / maxf(1.0, _largura_util() / 60.0)
	var escala: float = pow(10.0, floor(log(necessario) / log(10.0)))
	for multiplicador: float in [1.0, 2.0, 5.0, 10.0]:
		if escala * multiplicador >= necessario:
			return escala * multiplicador
	return necessario


func _abreviar(fonte: Font, texto: String, largura: float) -> String:
	if largura < 9.0:
		return ""
	if fonte.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x <= largura:
		return texto
	while not texto.is_empty() and fonte.get_string_size(texto + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > largura:
		texto = texto.substr(0, texto.length() - 1)
	return texto + "…"
