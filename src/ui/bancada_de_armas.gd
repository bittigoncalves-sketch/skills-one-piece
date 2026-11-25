class_name BancadaDeArmas
extends VBoxContainer
## BANCADA (12/11/2026) — a aba da central que fabrica as armas do Epic Fight pelas receitas do mod (`BancadaEpicFight`): o padrão 3×3 do mod desenhado com os ícones dos ingredientes,
## quantos a mochila tem × quantos o padrão pede, e o botão FABRICAR (consome os ingredientes, entrega a arma, restaura a durabilidade). Os ingredientes (barras, gravetos, espadas
## vanilla…) saem da aba BLOCOS (seção "Materiais") enquanto o jogo não tem como obtê-los jogando.

var progressao: ProgressaoDoPersonagem
var _linhas := {}                 # id → {botao, rotulo}


func _init() -> void:
	name = "BancadaDeArmas"
	add_theme_constant_override("separation", 6)


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	if not _linhas.is_empty():
		atualizar()
		return
	add_child(EstiloDaHistoria.rotulo("Receitas do Epic Fight · padrão 3×3 do mod · os ingredientes saem da aba BLOCOS (Materiais)", EstiloDaHistoria.TEXTO_2, 14))
	for id in BancadaEpicFight.ids():
		add_child(_linha(id))
	prog.inventario.mudou.connect(atualizar)
	prog.mudou.connect(atualizar)
	atualizar()


func _linha(id: String) -> Control:
	var caixa := EstiloDaHistoria.linha_de_lista()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	caixa.add_child(h)
	h.add_child(_grade(id))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var d := LaminasEpicFight.dados(id)
	info.add_child(EstiloDaHistoria.rotulo(str(d.get("nome", id)), EstiloDaHistoria.DOURADO, 16))
	var req := EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO_2, 14)
	info.add_child(req)
	h.add_child(info)
	var botao := EstiloDaHistoria.botao("Fabricar", func(): fabricar(id), true)
	botao.name = "Fabricar_" + id
	h.add_child(botao)
	_linhas[id] = {"botao": botao, "rotulo": req}
	return caixa


## O padrão 3×3 do mod: cada letra vira o ícone do ingrediente (primeira alternativa da tag).
func _grade(id: String) -> Control:
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 1)
	g.add_theme_constant_override("v_separation", 1)
	var r: Dictionary = BancadaEpicFight.receitas().get(id.trim_prefix("ef_"), {})
	var padrao: Array = r.get("padrao", [])
	for y in 3:
		var linha := str(padrao[y]) if y < padrao.size() else ""
		for x in 3:
			var c := linha[x] if x < linha.length() else " "
			var cel := TextureRect.new()
			cel.custom_minimum_size = Vector2(28, 28)
			cel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			if c != " ":
				var alt := BancadaEpicFight.alternativas(BancadaEpicFight.ingrediente(id, c))
				if not alt.is_empty():
					cel.texture = RegrasDeItens.icone(alt[0])
			var fundo := ColorRect.new()
			fundo.color = Color(0, 0, 0, 0.35)
			fundo.custom_minimum_size = Vector2(28, 28)
			fundo.add_child(cel)
			cel.set_anchors_preset(Control.PRESET_FULL_RECT)
			g.add_child(fundo)
	return g


var _suja := false


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _suja and is_visible_in_tree():
		atualizar()


func atualizar() -> void:
	if progressao == null:
		return
	if not is_visible_in_tree():
		_suja = true                       # rolar a hotbar emite `mudou`: fechada, não recalcula as 25 receitas (3 ms a cada troca)
		return
	_suja = false
	for id in _linhas:
		var partes: Array[String] = []
		var cont := BancadaEpicFight.contagem(id)
		for chave in cont:
			var ing := BancadaEpicFight.ingrediente(id, str(chave))
			var alt := BancadaEpicFight.alternativas(ing)
			var nome := (alt[0] if not alt.is_empty() else "?").trim_prefix("minecraft:") if ing.has("item") else str(ing.get("tag", "")).trim_prefix("minecraft:")
			partes.append("%d/%d %s" % [BancadaEpicFight.tem(progressao.inventario, ing), int(cont[chave]), nome])
		var tem_a_arma: bool = progressao.equipamentos.has(id)
		(_linhas[id].rotulo as Label).text = ", ".join(partes) + ("  ·  você já tem (fabricar restaura a durabilidade)" if tem_a_arma else "")
		(_linhas[id].botao as Button).disabled = not BancadaEpicFight.pode_fabricar(progressao.inventario, id)


func fabricar(id: String) -> bool:
	var ok_ := BancadaEpicFight.fabricar(progressao, id)
	if ok_:
		atualizar()
	return ok_
