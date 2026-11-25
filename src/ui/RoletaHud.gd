class_name RoletaHud
extends Control
# ============================================================================
#  A ROLETA DO BARBA NEGRA (15/10/2026) — a roda que gira ao pagar as 100 moedas.
#
#  A roda mostra as três raridades na proporção do sorteio (comum / incomum / lendário,
#  pesos do `CatalogoDeTripulantes`); o resultado JÁ foi sorteado e pago antes de ela
#  girar (a progressão grava na hora: fechar a janela no meio não perde o prêmio). Aqui
#  só se anima: a roda gira e para com o ponteiro da raridade que saiu, e o cartão
#  revela o nome do tripulante.
#
#  Depois que a roda para ela some e o sorteado aparece no CENTRO da tela por `exibicao`
#  segundos (1 s, pedido do dono 15/10/2026): o personagem em 3D girando, o nome e a raridade.
#  `girar({id, nome, raridade})`. `duracao`/`exibicao` e os sinais existem para o teste.
# ============================================================================

## A roda parou (o sorteado vai aparecer).
signal terminou(id: String)
## O sorteado já ficou o tempo todo na tela e tudo sumiu.
signal encerrou(id: String)

const LADO := 300.0
const LADO_DO_SORTEADO := 300
var duracao := 3.6
## Quanto o personagem sorteado fica na tela depois da roda (pedido do dono: 1 s).
var exibicao := 1.0
var biblioteca: BibliotecaDeModelos

var _fundo: ColorRect
var _roda: Roda
var _painel_da_roda: PanelContainer
var _sorteado: Control
var _vitrine_do_sorteado: Control
var _resultado: Label
var _raridade: Label
var _giro := {}
var _total := 0.0
var _girando := false
var _tween: Tween


func _ready() -> void:
	GuiMinecraft.aplicar(self)    # fonte, botões e painéis do Minecraft (12/11/2026); sem as texturas locais, não faz nada
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_fundo = ColorRect.new()
	_fundo.color = Color(0, 0, 0, 0.72)
	_fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fundo)
	# Tudo no CENTRO da tela: um CenterContainer do tamanho da tela é o que garante isso
	# (um painel ancorado no centro lê a própria medida antes do layout e nasce torto).
	var centro := CenterContainer.new()
	centro.name = "Centro"
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	_painel_da_roda = PanelContainer.new()
	_painel_da_roda.name = "PainelDaRoda"
	_painel_da_roda.add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	centro.add_child(_painel_da_roda)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 8)
	_painel_da_roda.add_child(coluna)
	coluna.add_child(EstiloDaHistoria.cabeca("ROLETA DO BARBA NEGRA", [] as Array[String]))
	var margem := MarginContainer.new()
	for lado in ["margin_left", "margin_right", "margin_bottom"]:
		margem.add_theme_constant_override(lado, 28)
	coluna.add_child(margem)
	_roda = Roda.new()
	_roda.custom_minimum_size = Vector2(LADO, LADO + 24)
	margem.add_child(_roda)
	# O sorteado: sem moldura de janela, só o personagem, o nome e a raridade.
	_sorteado = VBoxContainer.new()
	_sorteado.name = "Sorteado"
	_sorteado.visible = false
	_sorteado.alignment = BoxContainer.ALIGNMENT_CENTER
	_sorteado.add_theme_constant_override("separation", 6)
	centro.add_child(_sorteado)
	_resultado = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 40)
	_resultado.name = "Resultado"
	_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_resultado.add_theme_constant_override("outline_size", 8)
	_resultado.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_raridade = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 22)
	_raridade.name = "Raridade"
	_raridade.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_raridade.add_theme_constant_override("outline_size", 6)
	_raridade.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_sorteado.add_child(_resultado)
	_sorteado.add_child(_raridade)


func esta_girando() -> bool:
	return _girando


## Começa a girar para o `giro` ({id, nome, raridade}). Gira de novo se já estava aberta.
func girar(giro: Dictionary) -> void:
	_giro = giro
	var cor := CatalogoDeTripulantes.cor_da_raridade(StringName(str(giro["raridade"])))
	visible = true
	_painel_da_roda.visible = true
	_sorteado.visible = false
	_roda.angulo = 0.0
	_roda.queue_redraw()
	_girando = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var alvo := _angulo_do_ponteiro(StringName(str(giro["raridade"])))
	_total = TAU * 5.0 - alvo        # voltas inteiras e o ponteiro para na fatia sorteada
	_tween = create_tween()
	_tween.tween_property(_roda, "angulo", _total, maxf(duracao, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func(): _revelar(cor))


## O ângulo (no sentido horário a partir do topo) de um ponto DENTRO da fatia da raridade,
## sem encostar nas bordas, para o ponteiro não parar na linha entre duas cores.
func _angulo_do_ponteiro(raridade: StringName) -> float:
	var inicio := 0.0
	var total := float(Roda.soma_dos_pesos())
	for r in CatalogoDeTripulantes.ORDEM_DAS_RARIDADES:
		var fatia := TAU * float(CatalogoDeTripulantes.RARIDADES[r]["peso"]) / total
		if r == raridade:
			return inicio + fatia * randf_range(0.2, 0.8)
		inicio += fatia
	return 0.0


func _revelar(cor: Color) -> void:
	_girando = false
	terminou.emit(str(_giro.get("id", "")))
	# A roda some e o sorteado ocupa o centro da tela pelo tempo combinado.
	_painel_da_roda.visible = false
	_resultado.text = str(_giro.get("nome", ""))
	_resultado.add_theme_color_override("font_color", cor)
	_raridade.text = CatalogoDeTripulantes.nome_da_raridade(StringName(str(_giro["raridade"]))).to_upper()
	_raridade.add_theme_color_override("font_color", cor)
	if is_instance_valid(_vitrine_do_sorteado):
		_sorteado.remove_child(_vitrine_do_sorteado)
		_vitrine_do_sorteado.queue_free()
	var vitrine := JanelaDaTripulacao.Vitrine.new()
	vitrine.name = "Vitrine"
	vitrine.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sorteado.add_child(vitrine)
	_sorteado.move_child(vitrine, 0)
	vitrine.montar(str(_giro.get("id", "")), biblioteca, LADO_DO_SORTEADO)
	_vitrine_do_sorteado = vitrine
	_sorteado.visible = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(maxf(exibicao, 0.0))
	_tween.tween_callback(_encerrar)


func _encerrar() -> void:
	var id := str(_giro.get("id", ""))
	fechar()
	encerrou.emit(id)


func sorteado_na_tela() -> bool:
	return visible and _sorteado.visible


## Pula a animação (clicar na roda): mostra o resultado já.
func pular() -> void:
	if _girando and _tween != null and _tween.is_valid():
		_tween.kill()
		_roda.angulo = _total         # já na posição final: o ponteiro confere com o resultado
		_revelar(CatalogoDeTripulantes.cor_da_raridade(StringName(str(_giro["raridade"]))))


func fechar() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_girando = false
	visible = false
	if _sorteado != null:
		_sorteado.visible = false


func _gui_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		pular()


## A roda: fatias coloridas, o nome de cada raridade e o ponteiro fixo no topo.
class Roda extends Control:
	var angulo := 0.0:
		set(v):
			angulo = v
			queue_redraw()

	static func soma_dos_pesos() -> int:
		var t := 0
		for r in CatalogoDeTripulantes.ORDEM_DAS_RARIDADES:
			t += int(CatalogoDeTripulantes.RARIDADES[r]["peso"])
		return t

	func _draw() -> void:
		var centro := Vector2(size.x * 0.5, LADO * 0.5 + 24.0)
		var raio := LADO * 0.5 - 4.0
		var total := float(soma_dos_pesos())
		var inicio := -PI * 0.5 + angulo
		for r in CatalogoDeTripulantes.ORDEM_DAS_RARIDADES:
			var fatia := TAU * float(CatalogoDeTripulantes.RARIDADES[r]["peso"]) / total
			var cor: Color = CatalogoDeTripulantes.RARIDADES[r]["cor"]
			var pts := PackedVector2Array([centro])
			var passos := maxi(int(fatia / TAU * 64.0), 4)
			for j in passos + 1:
				var a := inicio + fatia * float(j) / passos
				pts.append(centro + Vector2(cos(a), sin(a)) * raio)
			draw_colored_polygon(pts, Color(cor, 0.9))
			draw_polyline(pts, Color(0.04, 0.08, 0.1), 2.0, true)
			# O nome no meio da fatia, para a roda se ler sem legenda.
			var meio := inicio + fatia * 0.5
			var ponto := centro + Vector2(cos(meio), sin(meio)) * raio * 0.62
			var fonte: Font = FonteMinecraft.fonte() if GuiMinecraft.disponivel() else ThemeDB.fallback_font
			var nome: String = CatalogoDeTripulantes.RARIDADES[r]["nome"]
			var largura := fonte.get_string_size(nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			draw_string(fonte, ponto - Vector2(largura * 0.5, -5.0), nome, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.05, 0.08, 0.1))
			inicio += fatia
		draw_arc(centro, raio, 0.0, TAU, 72, EstiloDaHistoria.DOURADO, 4.0, true)
		draw_circle(centro, 16.0, Color(0.05, 0.1, 0.12))
		draw_arc(centro, 16.0, 0.0, TAU, 24, EstiloDaHistoria.DOURADO, 2.0, true)
		# Ponteiro fixo no topo, apontando para dentro.
		var topo := centro + Vector2(0, -raio - 2.0)
		draw_colored_polygon(PackedVector2Array([topo + Vector2(0, 22), topo + Vector2(-13, -6), topo + Vector2(13, -6)]),
			EstiloDaHistoria.DOURADO)
