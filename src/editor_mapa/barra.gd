class_name BarraDoEditor
extends PanelContainer
# ============================================================================
#  BARRA DE FERRAMENTAS do editor de mapa (topo da tela).
#
#  Só emite pedidos; quem executa é o `EditorDeMapa`. Os atalhos de teclado são
#  do Roblox Studio (Ctrl+1..4, Ctrl+D, Ctrl+Z/Y, Ctrl+S) e aparecem na dica de
#  cada botão — o botão é para quem ainda não decorou.
# ============================================================================

signal ferramenta_escolhida(ferramenta: int)
signal inserir_pedido(tipo: String)
signal passo_escolhido(passo: float)
signal desfazer_pedido
signal refazer_pedido
signal salvar_pedido
signal testar_pedido
signal sair_pedido
## Tecla H: ver as hitboxes do mapa inteiro (a da seleção aparece sempre).
signal hitboxes_pedido
## J: troca o 3D pelo EDITOR DE JANELAS (05/10/2026).
signal janelas_pedido

const PASSOS := [0.0, 0.25, 0.5, 1.0, 2.0, 4.0]
const PASSO_INICIAL := 1.0

var _ferramentas: Array[Button] = []
var _desfazer: Button
var _refazer: Button
var _salvar: Button
var _hitboxes: Button
var _janelas: Button


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 4)
	add_child(linha)

	var grupo := ButtonGroup.new()
	var nomes := {
		GizmoDoEditor.Ferramenta.SELECIONAR: ["Selecionar", "Ctrl+1 — clicar e arrastar um retângulo"],
		GizmoDoEditor.Ferramenta.MOVER: ["Mover", "Ctrl+2 — setas"],
		GizmoDoEditor.Ferramenta.ESCALAR: ["Escalar", "Ctrl+3 — bolinhas nas faces (uma peça)"],
		GizmoDoEditor.Ferramenta.GIRAR: ["Girar", "Ctrl+4 — anéis, de 15 em 15°"],
		GizmoDoEditor.Ferramenta.RELEVO: ["Relevo", "Ctrl+5 — pincel no relevo: clique ergue, Shift afunda, [ ] raio"],
	}
	for f in nomes:
		var b := EstiloDoEditor.botao(nomes[f][0], nomes[f][1] + ("" if f == GizmoDoEditor.Ferramenta.RELEVO else ". Shift solta a grade."))
		b.toggle_mode = true
		b.button_group = grupo
		b.pressed.connect(func(): ferramenta_escolhida.emit(f))
		linha.add_child(b)
		_ferramentas.append(b)

	linha.add_child(VSeparator.new())
	for tipo in ["caixa", "esfera", "cilindro", "cunha"]:
		var b := EstiloDoEditor.botao("+ " + OperacoesDoEditor.ROTULO_TIPO[tipo],
			"Insere no centro da tela, em cima do que estiver lá")
		b.pressed.connect(func(): inserir_pedido.emit(tipo))
		linha.add_child(b)
	var animais := EstiloDoEditor.botao("+ Animais",
		"Área onde uma espécie da categoria Animais nasce (espécie e quantidade no painel). Invisível no jogo")
	animais.name = "InserirAreaDeAnimais"
	animais.pressed.connect(func(): inserir_pedido.emit("area_animais"))
	linha.add_child(animais)

	linha.add_child(VSeparator.new())
	_hitboxes = EstiloDoEditor.botao("Hitboxes",
		"H — mostra o volume de colisão de TODAS as peças. A da peça selecionada aparece sempre.")
	_hitboxes.toggle_mode = true
	_hitboxes.pressed.connect(func(): hitboxes_pedido.emit())
	linha.add_child(_hitboxes)
	_janelas = EstiloDoEditor.botao("Janelas",
		"J — troca o 3D pelas JANELAS do jogo: escolha uma na lista e edite como num canvas (posição, tamanho, texto, cores)")
	_janelas.name = "Janelas"
	_janelas.toggle_mode = true
	_janelas.pressed.connect(func(): janelas_pedido.emit())
	linha.add_child(_janelas)

	linha.add_child(VSeparator.new())
	linha.add_child(EstiloDoEditor.rotulo("Grade", true))
	var grade := OptionButton.new()
	grade.focus_mode = Control.FOCUS_NONE
	grade.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	for passo in PASSOS:
		grade.add_item("livre" if passo == 0.0 else "%s m" % PropriedadesDoEditor._numero(passo).replace(".", ","))
	grade.select(PASSOS.find(PASSO_INICIAL))
	grade.item_selected.connect(func(i): passo_escolhido.emit(PASSOS[i]))
	linha.add_child(grade)

	linha.add_child(VSeparator.new())
	_desfazer = EstiloDoEditor.botao("↶", "Desfazer (Ctrl+Z)")
	_desfazer.pressed.connect(func(): desfazer_pedido.emit())
	linha.add_child(_desfazer)
	_refazer = EstiloDoEditor.botao("↷", "Refazer (Ctrl+Y)")
	_refazer.pressed.connect(func(): refazer_pedido.emit())
	linha.add_child(_refazer)

	linha.add_child(VSeparator.new())
	_salvar = EstiloDoEditor.botao("Salvar", "Ctrl+S — grava o arquivo do mapa")
	_salvar.pressed.connect(func(): salvar_pedido.emit())
	linha.add_child(_salvar)
	var testar := EstiloDoEditor.botao("▶ Testar", "F5 — joga no mapa como está agora. ESC volta")
	testar.pressed.connect(func(): testar_pedido.emit())
	linha.add_child(testar)
	var sair := EstiloDoEditor.botao("Sair", "Volta ao menu principal")
	sair.pressed.connect(func(): sair_pedido.emit())
	linha.add_child(sair)


func marcar_janelas(ligado: bool) -> void:
	if _janelas:
		_janelas.set_pressed_no_signal(ligado)


func marcar_hitboxes(ligado: bool) -> void:
	if _hitboxes:
		_hitboxes.set_pressed_no_signal(ligado)


## Com o gizmo apontado para a HITBOX, o botão vira aviso: sem isto a pessoa arrasta
## a peça achando que está ajustando o volume.
func marcar_alvo_hitbox(ligado: bool) -> void:
	if _hitboxes:
		_hitboxes.text = "Hitbox ✎" if ligado else "Hitboxes"


func marcar_ferramenta(ferramenta: int) -> void:
	for i in _ferramentas.size():
		_ferramentas[i].set_pressed_no_signal(i == ferramenta)


func atualizar_historico(hist: HistoricoDeEdicao) -> void:
	_desfazer.disabled = not hist.pode_desfazer()
	_refazer.disabled = not hist.pode_refazer()
	_desfazer.tooltip_text = "Desfazer %s (Ctrl+Z)" % hist.nome_do_desfazer()
	_refazer.tooltip_text = "Refazer %s (Ctrl+Y)" % hist.nome_do_refazer()


func marcar_sujo(sujo: bool) -> void:
	_salvar.text = "Salvar •" if sujo else "Salvar"
