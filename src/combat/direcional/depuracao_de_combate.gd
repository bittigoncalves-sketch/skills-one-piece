class_name DepuracaoDeCombate
extends CanvasLayer
# ============================================================================
#  DEPURAÇÃO DO COMBATE DIRECIONAL — painel opcional com o estado do executor.
#
#  DESLIGADO por padrão. Liga com F10 no jogo, ou `SOP_COMBATE_DEBUG=1` no
#  ambiente para já nascer visível num teste com tela. Desligado ele não roda
#  `_process` nenhum: custo zero de quadro.
#
#  Desenho 3D da varredura: fica para quando a leitura em texto não bastar
#  (gatilho: ajuste de alcance na Fase 6).
# ============================================================================

const TECLA := KEY_F10

var _executor: ExecutorCorpoACorpo
var _rotulo: Label
var _ultimo_contato := "—"


static func ligada_por_ambiente() -> bool:
	return OS.get_environment("SOP_COMBATE_DEBUG") == "1"


func montar(executor: ExecutorCorpoACorpo) -> void:
	_executor = executor
	executor.contato.connect(_ao_contato)


func _ao_contato(id: int, alvo: Node3D, resultado: int, lado: int, _posicao: Vector3, golpe: GolpeDirecional) -> void:
	_ultimo_contato = "#%d %s → %s  %s pelo lado %s" % [id, golpe.id, alvo.name,
		ResolucaoDeContato.Resultado.keys()[resultado], ResolucaoDeContato.Lado.keys()[lado]]


func _ready() -> void:
	layer = 90
	var fundo := PanelContainer.new()
	# Abaixo das barras de vida/energia e do aviso de nível do Modo História (y 100–136).
	fundo.position = Vector2(12, 150)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	_rotulo = Label.new()
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rotulo.add_theme_font_size_override("font_size", 14)
	fundo.add_child(_rotulo)
	_mostrar(ligada_por_ambiente())


func _unhandled_key_input(evento: InputEvent) -> void:
	var k := evento as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == TECLA:
		_mostrar(not visible)
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_rotulo.text = texto()


## O conteúdo do painel. Separado do desenho para o teste conferir sem tela.
func texto() -> String:
	if not is_instance_valid(_executor):
		return "Combate: sem executor"
	var e := _executor
	var linhas := PackedStringArray()
	linhas.append("Combate: %s" % ExecutorCorpoACorpo.Estado.keys()[e.estado])
	if e.golpe_atual != null:
		var g := e.golpe_atual
		linhas.append("Golpe: %s (%s)" % [g.id, GolpeDirecional.Direcao.keys()[g.direcao]])
		linhas.append("Fase: %s  %.2f / %.2f s" % [GolpeDirecional.Fase.keys()[e.fase()],
			e.tempo_da_acao(), g.duracao()])
	linhas.append("Ação #%d   buffer: %s" % [e.id_acao, "SIM" if e.tem_buffer() else "não"])
	linhas.append("Movimento ×%.2f   giro máx %s" % [e.fator_de_movimento(),
		"livre" if is_inf(e.giro_maximo()) else "%.0f°/s" % rad_to_deg(e.giro_maximo())])
	linhas.append("Pose ×%.2f   hitstop: %s" % [e.peso_da_pose(), "SIM" if e.em_hitstop() else "não"])
	if e.estilo != null:
		linhas.append("Postura %.0f / %.0f   guarda pedida: %s" % [e.postura, e.estilo.postura_maxima,
			"SIM" if e.guarda_pedida() else "não"])
		linhas.append("Aparo: %s   riposte: %s   finta: %s" % ["ABERTO" if e.aparando() else "—",
			"ABERTO" if e.janela_de_riposte_aberta() else ("em curso" if e.golpe_e_riposte() else "—"),
			"pode" if e.pode_fintar() else "—"])
	linhas.append("Último contato: %s" % _ultimo_contato)
	return "\n".join(linhas)


func _mostrar(ligar: bool) -> void:
	visible = ligar
	set_process(ligar)
