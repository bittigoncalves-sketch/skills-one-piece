class_name MenuDePausa
extends Control
# ============================================================================
#  MENU DE PAUSA DO MODO HISTÓRIA (25/11/2026, pedido do dono): o ESC não leva mais ao menu inicial com "Sair do jogo" — abre
#  "Configurações" (volume geral, tela cheia, sensibilidade do mouse, bonecos de treino) e a opção "Salvar e sair", que grava
#  o progresso e fecha o jogo. Mesma interface do `MainMenu` que a HUD usava (`setup/open_menu/close_menu/toggle/is_open`).
#  O jogo NÃO pausa (é multiplayer-capaz); só o mouse é solto e as janelas se fecham pela HUD.
# ============================================================================

const LARGURA := 460.0

var _open := false
var _hud_ref: Node = null
var _volume: HSlider
var _tela_cheia: CheckBox
var _sens: HSlider
var _bonecos := {}
var _salvando := false


func setup(hud: Node) -> void:
	_hud_ref = hud


func is_open() -> bool:
	return _open


func toggle() -> void:
	if _open:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	_sincronizar()
	_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_menu() -> void:
	_open = false
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	name = "MenuDePausa"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var fundo := ColorRect.new()
	fundo.color = Color(0, 0, 0, 0.55)
	fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundo)
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)
	var painel := PanelContainer.new()
	painel.name = "Painel"
	painel.add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	painel.custom_minimum_size = Vector2(LARGURA, 0)
	centro.add_child(painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, 24)
	painel.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)
	coluna.add_child(EstiloDaHistoria.rotulo("Configurações", EstiloDaHistoria.DOURADO, 26))
	_volume = _controle(coluna, "Volume geral", 0.0, 1.0, 0.05, func(v): _gf().call("set_volume", v))
	_volume.name = "Volume"
	_sens = _controle(coluna, "Sensibilidade do mouse", 0.25, 2.0, 0.05, func(v): _gf().call("set_sensibilidade", v))
	_sens.name = "Sensibilidade"
	_tela_cheia = CheckBox.new()
	_tela_cheia.name = "TelaCheia"
	_tela_cheia.text = "Tela cheia"
	_tela_cheia.toggled.connect(func(b): _gf().call("set_tela_cheia", b))
	coluna.add_child(_tela_cheia)
	for tipo in ["TrainingDummy", "AutoDummy"]:
		var cb := CheckBox.new()
		cb.name = "Boneco_" + tipo
		cb.text = str(_gf().get("DUMMIES").get(tipo, tipo))
		cb.toggled.connect(func(b): _gf().call("set_dummy", tipo, b))
		coluna.add_child(cb)
		_bonecos[tipo] = cb
	coluna.add_child(HSeparator.new())
	var continuar := EstiloDaHistoria.botao("Continuar", close_menu, true)
	continuar.name = "Continuar"
	coluna.add_child(continuar)
	var sair := EstiloDaHistoria.botao("Salvar e sair", salvar_e_sair, false)
	sair.name = "SalvarESair"
	coluna.add_child(sair)


func _controle(coluna: VBoxContainer, titulo: String, minimo: float, maximo: float, passo: float, ao_mudar: Callable) -> HSlider:
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 12)
	var rot := EstiloDaHistoria.rotulo(titulo, EstiloDaHistoria.TEXTO, 15)
	rot.custom_minimum_size = Vector2(190, 0)
	linha.add_child(rot)
	var s := HSlider.new()
	s.min_value = minimo
	s.max_value = maximo
	s.step = passo
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(160, 24)
	s.value_changed.connect(ao_mudar)
	linha.add_child(s)
	coluna.add_child(linha)
	return s


func _gf() -> Node:
	return get_node("/root/GameFlow")


func _sincronizar() -> void:
	if _volume == null:
		return
	var gf := _gf()
	_volume.set_value_no_signal(float(gf.get("volume")))
	_sens.set_value_no_signal(float(gf.get("sensibilidade")))
	_tela_cheia.set_pressed_no_signal(bool(gf.get("tela_cheia")))
	for tipo in _bonecos:
		(_bonecos[tipo] as CheckBox).set_pressed_no_signal(bool(gf.call("dummy_ligado", tipo)))


## Grava o progresso e fecha o jogo. Devolve true se gravou (os testes não fecham o programa: `fechar_o_jogo = false`).
var fechar_o_jogo := true


func salvar_e_sair() -> bool:
	if _salvando:
		return false
	_salvando = true
	var gravou := false
	var modo := get_tree().get_first_node_in_group("modo_historia")
	if modo != null:
		modo.call("gravar_local", true)               # posição + progresso (recusa jogador fora da árvore)
		var prog: ProgressaoDoPersonagem = modo.get("progressao")
		if prog != null:
			gravou = prog.salvar(str(modo.call("caminho_do_progresso"))) == OK     # garante o save mesmo sem ilha sob os pés
	if fechar_o_jogo:
		_gf().call("quit_game")
	_salvando = false
	return gravou
