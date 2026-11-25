extends Control
# ============================================================================
#  FOME E SEDE NO CANTO SUPERIOR DIREITO (pedido do dono, 18/11/2026).
#
#  As mesmas barras da vida e da energia (`BarraHud`, 340 × 28, espaço de 10), no espelho delas: fome na linha da vida, sede na linha da
#  energia, margem de 20 px à direita e o mesmo `y` da `VidaEnergiaHud`. Antes eram `ProgressBar`s finas de 14 px com um texto em cima.
#  O ícone de fome do Minecraft some junto (`HudMinecraft` não desenha mais a fileira de comidas).
# ============================================================================
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const LARGURA := VidaEnergiaHud.LARGURA
const ALTURA := VidaEnergiaHud.ALTURA
const ESPACO := VidaEnergiaHud.ESPACO
const MARGEM := VidaEnergiaHud.MARGEM
const COR_FOME := Color(0.85, 0.62, 0.22)
const COR_SEDE := Color(0.2, 0.65, 0.85)
var progressao: ProgressaoDoPersonagem
var _fome: BarraHud
var _sede: BarraHud
var _fome_rotulo: Label
var _sede_rotulo: Label
var _equipe: Label
var _tempo := 0.0
var _ultimo := PackedInt32Array([-1, -1])


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -(LARGURA + MARGEM)
	offset_right = -MARGEM
	offset_top = MARGEM + VidaEnergiaHud.FAIXA_DO_NIVEL
	offset_bottom = offset_top + ALTURA * 2.0 + ESPACO
	if ToqueHud.ativo():
		# Celular: os botões de golpe ocupam o canto direito; as barras saem da frente deles.
		offset_left -= 170
		offset_right -= 170
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fome = _barra(0.0, COR_FOME)
	_fome_rotulo = _rotulo(0.0)
	_sede = _barra(ALTURA + ESPACO, COR_SEDE)
	_sede_rotulo = _rotulo(ALTURA + ESPACO)
	_equipe = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 13)
	_equipe.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equipe.position = Vector2(0.0, ALTURA * 2.0 + ESPACO + 8.0)
	_equipe.custom_minimum_size.x = LARGURA
	add_child(_equipe)
	_atualizar()


func _barra(y: float, cor: Color) -> BarraHud:
	var b := BarraHud.new()
	b.cor = cor
	b.position = Vector2(-2.0, y - 2.0)       # o mesmo recuo da `VidaEnergiaHud`
	b.size = Vector2(LARGURA, ALTURA)
	add_child(b)
	return b


func _rotulo(y: float) -> Label:
	var l := Estilo.texto(16, Color(1, 1, 1))
	l.position = Vector2(14.0, y + 3.0)
	add_child(l)
	return l


func _process(delta: float) -> void:
	visible = not get_parent().is_menu_open()
	_tempo += delta
	if _tempo >= 0.25:
		_tempo = 0
		_atualizar()


func _atualizar() -> void:
	if progressao == null: return
	var d := P.estado(progressao)
	_fome.valor(float(d.fome) / P.FOME_MAX)
	_sede.valor(float(d.sede) / P.SEDE_MAX)
	var agora := PackedInt32Array([ceili(d.fome), ceili(d.sede)])
	if agora != _ultimo:
		_ultimo = agora
		_fome_rotulo.text = "FOME  %d / %d" % [agora[0], int(P.FOME_MAX)]
		_sede_rotulo.text = "SEDE  %d / %d" % [agora[1], int(P.SEDE_MAX)]
	var aviso := ""
	if float(d.fome) <= 0: aviso = "Sem comida: regeneração interrompida\n"
	if float(d.sede) <= 75: aviso += "Beba água potável!\n"
	var linhas: PackedStringArray = []
	for id in d.vagas:
		if not d.membros.has(id): continue
		var m: Dictionary = d.membros[id]
		linhas.append("%s · HP %d/%d" % [Tripulacao.aliado(progressao, null, id).get("nome", id), ceili(m.vida), ceili(m.vida_max)])
	_equipe.text = aviso + "\n".join(linhas)


func texto_da_fome() -> String:
	return _fome_rotulo.text


func texto_da_sede() -> String:
	return _sede_rotulo.text
