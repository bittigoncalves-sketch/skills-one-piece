class_name BarrasDeChefes
extends Control
# ============================================================================
#  VIDA DOS CHEFES NO TOPO DA TELA (Modo História, 08/10/2026).
#
#  Pedido do dono: "adicionar a capacidade do jogador ver no topo superior da tela
#  quanto de vida tem cada boss". Uma barra por chefe (nome, vida atual/máxima), do
#  mais perto para o mais longe, até `MAXIMO`. Aparece quando o chefe está vivo e a até
#  `ALCANCE` do jogador, ou em combate com ele (`em_combate()`: perseguindo / agressiva); some
#  quando ele morre ou sai de perto. Chefe = nó do grupo `chefes` com `health`,
#  `max_health`, `vivo()`, `em_combate()` e `nome_de_exibicao()` (gorila, harpia,
#  Sea Serpent).
#  Some junto com o HUD quando um menu/janela está aberto.
#
#  Mesma barra inclinada das de vida/energia do jogador (`BarraHud`), em vermelho.
# ============================================================================

const GRUPO := "chefes"
const MAXIMO := 3
const ALCANCE := 60.0
const LARGURA := 440.0
const ALTURA_DA_BARRA := 16.0
const COR := Color(0.86, 0.2, 0.22)

var _linhas: Array[Dictionary] = []
var _relogio := 0.0


func _ready() -> void:
	name = "BarrasDeChefes"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	offset_left = -LARGURA * 0.5
	offset_right = LARGURA * 0.5
	offset_top = 8.0
	var caixa := VBoxContainer.new()
	caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caixa.add_theme_constant_override("separation", 4)
	caixa.size.x = LARGURA
	add_child(caixa)
	for i in MAXIMO:
		var linha := VBoxContainer.new()
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		linha.add_theme_constant_override("separation", 0)
		var nome := Label.new()
		nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nome.add_theme_font_size_override("font_size", 15)
		nome.add_theme_color_override("font_shadow_color", Color.BLACK)
		nome.add_theme_constant_override("shadow_offset_x", 1)
		nome.add_theme_constant_override("shadow_offset_y", 1)
		var barra := BarraHud.new()
		barra.cor = COR
		barra.custom_minimum_size = Vector2(LARGURA, ALTURA_DA_BARRA)
		linha.add_child(nome)
		linha.add_child(barra)
		linha.visible = false
		caixa.add_child(linha)
		_linhas.append({"raiz": linha, "nome": nome, "barra": barra})


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = 0.1
	var hud := get_parent()
	visible = not (hud != null and hud.has_method("is_menu_open") and hud.call("is_menu_open"))
	var mostrar := chefes_a_mostrar()
	for i in _linhas.size():
		var linha: Dictionary = _linhas[i]
		(linha.raiz as Control).visible = i < mostrar.size()
		if i >= mostrar.size():
			continue
		var c: Node = mostrar[i]
		var vida := maxf(float(c.get("health")), 0.0)
		var maxima := maxf(float(c.get("max_health")), 1.0)
		(linha.nome as Label).text = "%s   ▮ %d/%d   %d / %d" % [c.call("nome_de_exibicao"), VidaEmBarras.barras_restantes(vida, maxima), VidaEmBarras.BARRAS, ceili(vida), roundi(maxima)]
		(linha.barra as BarraHud).valor(vida / maxima)


## Os chefes que aparecem agora, do mais perto ao mais longe (até `MAXIMO`).
func chefes_a_mostrar() -> Array[Node]:
	var jogador := get_tree().get_first_node_in_group("player") as Node3D
	var lista: Array[Dictionary] = []
	for c in get_tree().get_nodes_in_group(GRUPO):
		if not (c is Node3D) or not c.is_inside_tree() or not c.call("vivo"):
			continue
		var d := INF if jogador == null else (c as Node3D).global_position.distance_to(jogador.global_position)
		if d <= ALCANCE or bool(c.call("em_combate")):
			lista.append({"no": c, "d": d})
	lista.sort_custom(func(a, b): return a.d < b.d)
	var saida: Array[Node] = []
	for item in lista.slice(0, MAXIMO):
		saida.append(item.no)
	return saida

