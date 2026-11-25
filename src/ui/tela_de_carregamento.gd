class_name TelaDeCarregamento
extends CanvasLayer
# ============================================================================
#  TELA DE CARREGAMENTO (28/10/2026). Mostra o que o `MonitorDeCarga` está medindo, ao vivo:
#    • a etapa de agora (e o que ela faz) e uma barra de progresso;
#    • à esquerda, as etapas JÁ CONCLUÍDAS com o tempo de cada uma;
#    • à direita, os arquivos/modelos lidos do disco (nome, tempo, tamanho);
#    • no rodapé, tempo decorrido, nós na árvore, memória e quantos modelos já estavam em cache.
#  Fica por cima de tudo (camada 128) e some com um fade quando a carga termina. Quem a cria é `MonitorDeCarga.comecar`.
# ============================================================================

const LINHAS := 16
const FUNDO := Color(0.04, 0.05, 0.08)
const PAINEL := Color(0.09, 0.11, 0.16)
const DESTAQUE := Color(0.32, 0.86, 0.78)
const TEXTO := Color(0.88, 0.9, 0.93)
const TEXTO_2 := Color(0.58, 0.63, 0.7)

var titulo := "Carregando":
	set(v):
		titulo = v
		if _titulo != null:
			_titulo.text = v.to_upper()
var _titulo: Label
var _fundo: ColorRect
var _barra: ProgressBar
var _etapa: Label
var _detalhe: Label
var _feitas: RichTextLabel
var _arquivos: RichTextLabel
var _rodape: Label
var _linhas_feitas: Array[String] = []
var _linhas_arquivos: Array[String] = []
var _nome_da_etapa := ""
var _etapas_feitas := 0
var _total_estimado := 28
var _pontos := 0.0
var _concluida := false


func _init() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = "TelaDeCarregamento"
	_montar()


func _montar() -> void:
	_fundo = ColorRect.new()
	_fundo.color = FUNDO
	_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fundo.add_child(centro)
	var coluna := VBoxContainer.new()
	coluna.custom_minimum_size = Vector2(1000, 0)
	coluna.add_theme_constant_override("separation", 12)
	centro.add_child(coluna)
	_titulo = _rotulo(titulo.to_upper(), 44, TEXTO)
	_titulo.name = "Titulo"
	coluna.add_child(_titulo)
	coluna.add_child(_rotulo("CARREGANDO", 16, DESTAQUE))
	_barra = ProgressBar.new()
	_barra.custom_minimum_size = Vector2(0, 14)
	_barra.show_percentage = false
	_barra.max_value = 100.0
	var cheia := StyleBoxFlat.new()
	cheia.bg_color = DESTAQUE
	cheia.set_corner_radius_all(7)
	var vazia := StyleBoxFlat.new()
	vazia.bg_color = PAINEL
	vazia.set_corner_radius_all(7)
	_barra.add_theme_stylebox_override("fill", cheia)
	_barra.add_theme_stylebox_override("background", vazia)
	coluna.add_child(_barra)
	_etapa = _rotulo("Preparando…", 26, TEXTO)
	_etapa.name = "Etapa"
	coluna.add_child(_etapa)
	_detalhe = _rotulo("", 15, TEXTO_2)
	_detalhe.name = "Detalhe"
	coluna.add_child(_detalhe)
	var colunas := HBoxContainer.new()
	colunas.add_theme_constant_override("separation", 16)
	coluna.add_child(colunas)
	_feitas = _lista("ETAPAS CONCLUÍDAS")
	colunas.add_child(_feitas.get_parent().get_parent())   # o pai do texto é o VBox; o painel é o avô (antes: erro 'already has a parent' e listas fora da tela)
	_arquivos = _lista("ARQUIVOS LIDOS DO DISCO")
	colunas.add_child(_arquivos.get_parent().get_parent())
	_rodape = _rotulo("", 14, TEXTO_2)
	_rodape.name = "Rodape"
	coluna.add_child(_rodape)


func _rotulo(texto: String, tamanho: int, cor: Color) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	l.clip_text = true
	return l


## Painel com título e uma lista de linhas (RichTextLabel sem rolagem: mostra as últimas `LINHAS`).
func _lista(cabeca: String) -> RichTextLabel:
	var painel := PanelContainer.new()
	painel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = PAINEL
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(12)
	painel.add_theme_stylebox_override("panel", estilo)
	var v := VBoxContainer.new()
	painel.add_child(v)
	v.add_child(_rotulo(cabeca, 13, DESTAQUE))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = false
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(0, 20 * LINHAS)
	rt.add_theme_font_size_override("normal_font_size", 14)
	rt.add_theme_color_override("default_color", TEXTO)
	v.add_child(rt)
	return rt


# ------------------------------------------------------------------ chamadas do MonitorDeCarga
func etapa_aberta(nome: String, detalhe: String, feitas: int, total: int) -> void:
	_nome_da_etapa = nome
	_etapas_feitas = feitas
	_total_estimado = maxi(total, feitas + 1)
	_etapa.text = nome
	_detalhe.text = detalhe
	_barra.value = clampf(100.0 * float(feitas) / float(_total_estimado), 0.0, 97.0)


func andamento(fracao: float, texto := "") -> void:
	_barra.value = clampf(100.0 * (float(_etapas_feitas) + fracao) / float(_total_estimado), 0.0, 97.0)
	if not texto.is_empty():
		_detalhe.text = texto


func etapa_fechada(e: Dictionary) -> void:
	_linhas_feitas.append("[color=#52dcc8]✔[/color] [color=#9aa3b2]%5d ms[/color]  %s" % [e.ms, e.nome])
	_atualizar_lista(_feitas, _linhas_feitas)


func recurso_carregado(tipo: String, nome: String, ms: float, bytes: int) -> void:
	_linhas_arquivos.append("[color=#9aa3b2]%s[/color] %s  [color=#9aa3b2]%d ms · %.1f MB[/color]" % [tipo, nome, ms, bytes / 1048576.0])
	_atualizar_lista(_arquivos, _linhas_arquivos)


func _atualizar_lista(rt: RichTextLabel, linhas: Array[String]) -> void:
	rt.text = "\n".join(linhas.slice(maxi(linhas.size() - LINHAS, 0)))


func concluir(total_ms: int) -> void:
	_concluida = true
	_barra.value = 100.0
	_etapa.text = "Pronto"
	_detalhe.text = "%.1f s · %d modelos lidos do disco" % [total_ms / 1000.0, MonitorDeCarga.modelos_lidos()]
	var t := create_tween()
	t.set_ignore_time_scale(true)
	t.tween_interval(0.35)
	t.tween_property(_fundo, "modulate:a", 0.0, 0.45)
	t.tween_callback(queue_free)


func _process(delta: float) -> void:
	_pontos += delta * 3.0
	if not _concluida:
		_etapa.text = _nome_da_etapa + ".".repeat(int(_pontos) % 4)
	var memoria := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	_rodape.text = "tempo %.1f s   ·   nós %d   ·   memória %.0f MB   ·   modelos lidos %d   ·   já em cache %d" % [
		MonitorDeCarga.tempo_decorrido_ms() / 1000.0, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), memoria,
		MonitorDeCarga.modelos_lidos(), MonitorDeCarga.modelos_em_cache()]
