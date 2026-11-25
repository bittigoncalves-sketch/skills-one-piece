class_name PropriedadesDoEditor
extends PanelContainer
# ============================================================================
#  PROPRIEDADES — os números da seleção, editáveis.
#
#    uma peça        forma, posição, rotação, tamanho, cor, material, grade, colisão
#    só o spawn      posição
#    várias peças    cor, material e colisão (valem para todas)
#
#  Os campos são RECONSTRUÍDOS quando a seleção muda e só ATUALIZADOS quando a
#  peça muda (arrastar no gizmo mexe na peça 60 vezes por segundo). ⚠️ Atualizar
#  pula o campo com foco: sem isso, o valor que a pessoa está digitando seria
#  sobrescrito pelo valor antigo no quadro seguinte.
#
#  Aceita vírgula decimal ("1,5"), que é como se digita em português.
# ============================================================================

signal alterar_pedido(campo: String, valor: Variant)
signal cor_ao_vivo(cor: Color)
signal cor_fechada
## Copiar a hitbox desta peça para todas as iguais (mesmo tipo/modelo).
signal aplicar_hitbox_pedido

var _corpo: VBoxContainer
var _campos := {}              # "posicao" -> [LineEdit, LineEdit, LineEdit], etc.
var _doc: DocumentoMapa
var _sel: SelecaoDoEditor
## Para mostrar nome e tamanho original das peças `modelo` (o editor fornece).
var biblioteca: BibliotecaDeModelos
## Os controles da hitbox, apagados quando a peça usa o volume automático.
var _hitbox_controles: Array[Control] = []


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDoEditor.painel())
	var coluna := VBoxContainer.new()
	add_child(coluna)
	coluna.add_child(EstiloDoEditor.rotulo("Propriedades"))
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)
	_corpo = VBoxContainer.new()
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_corpo.add_theme_constant_override("separation", 6)
	rolagem.add_child(_corpo)


func mostrar(doc: DocumentoMapa, sel: SelecaoDoEditor) -> void:
	_doc = doc
	_sel = sel
	for filho in _corpo.get_children():
		filho.queue_free()
	_campos.clear()
	_hitbox_controles.clear()
	var pecas := sel.pecas()
	if sel.vazia():
		_corpo.add_child(EstiloDoEditor.explicacao("Nada selecionado. Clique numa peça ou no Explorer."))
		return
	if sel.ids() == [SelecaoDoEditor.SPAWN]:
		_corpo.add_child(EstiloDoEditor.explicacao("Spawn — onde o jogador nasce"))
		_linha_vetor("Posição", "posicao")
	elif pecas.size() == 1 and not sel.tem_spawn() and doc.tem_grupo(pecas[0]):
		_corpo.add_child(EstiloDoEditor.rotulo("Grupo %s" % pecas[0]))
		_corpo.add_child(EstiloDoEditor.explicacao("%d peças. Posição = centro delas; mover move todas. Ctrl+G separa um nível."
			% doc.pecas_de(pecas[0]).size()))
		_linha_vetor("Posição", "posicao")
		_linha_aparencia(false)
	elif pecas.size() == 1 and not sel.tem_spawn():
		_corpo.add_child(EstiloDoEditor.rotulo(pecas[0]))
		var tipo: String = doc.peca(pecas[0])["tipo"]
		var e_modelo := tipo == "modelo"
		if e_modelo:
			_linha_modelo(doc.peca(pecas[0]))
		elif tipo == "terreno":
			_linha_terreno(doc.peca(pecas[0]))
		elif tipo == "area_animais":
			_linha_area_animais(doc.peca(pecas[0]))
		else:
			_linha_forma()
		_linha_vetor("Posição", "posicao")
		_linha_vetor("Rotação °", "rotacao_graus")
		_linha_vetor("Tamanho", "tamanho")
		if e_modelo or tipo == "terreno":
			_linha_colisao()
		elif tipo != "area_animais":
			_linha_aparencia(true)
		# Terreno não tem hitbox: a colisão dele É o relevo, e uma caixa no lugar
		# deixaria o jogador andando no ar sobre os vales. Área de animais não colide.
		if tipo != "terreno" and tipo != "area_animais":
			_linha_hitbox(e_modelo)
	else:
		_corpo.add_child(EstiloDoEditor.rotulo("%d itens selecionados" % sel.ids().size()))
		if pecas.is_empty():
			return
		_corpo.add_child(EstiloDoEditor.explicacao("Cor, material e colisão valem para todas as peças."))
		_linha_aparencia(false)
	atualizar()


## Os números da hitbox. Sem hitbox própria, os campos mostram o volume AUTOMÁTICO
## que a física usa hoje — apagados, mas preenchidos: ligar a hitbox parte daí, e ver
## o número antes de mexer é metade do trabalho.
func _escrever_hitbox(p: Dictionary, foco: Control) -> void:
	var propria: bool = p.has("hitbox")
	(_campos["hitbox.usar"] as CheckBox).set_pressed_no_signal(propria)
	var h: Dictionary = p["hitbox"] if propria else OperacoesDoEditor.hitbox_de_partida(p)
	var i := MapaArquivo.FORMAS_HITBOX.find(h["forma"])
	(_campos["hitbox.forma"] as OptionButton).select(i)
	_escrever_vetor("hitbox.deslocamento", h["deslocamento"], foco)
	_escrever_vetor("hitbox.tamanho", h["tamanho"], foco)
	_escrever_vetor("hitbox.rotacao_graus", h["rotacao_graus"], foco)
	var liga: bool = propria and p["colisao"]
	for c in _hitbox_controles:
		if is_instance_valid(c):
			c.set("disabled", not liga) if c is Button or c is OptionButton else c.set("editable", liga)
	if _campos.has("hitbox.aplicar_botao"):
		(_campos["hitbox.aplicar_botao"] as Button).disabled = not liga


## Reescreve os valores sem reconstruir (e sem tocar no campo com foco).
func atualizar() -> void:
	if _doc == null or _campos.is_empty():
		return
	var foco := get_viewport().gui_get_focus_owner()
	if _sel.ids() == [SelecaoDoEditor.SPAWN]:
		_escrever_vetor("posicao", _doc.spawn, foco)
		return
	var itens := _sel.pecas()
	var todas := OperacoesDoEditor.pecas_da_selecao(_doc, _sel)
	if itens.is_empty() or todas.is_empty():
		return
	# Referência para cor/material/colisão com vários itens: a primeira peça.
	var p := _doc.peca(todas[0])
	var um_grupo := itens.size() == 1 and _doc.tem_grupo(itens[0])
	if um_grupo and _campos.has("posicao"):
		_escrever_vetor("posicao", OperacoesDoEditor.centro(_doc, _sel), foco)
	for campo in ["posicao", "rotacao_graus", "tamanho"]:
		if _campos.has(campo) and not um_grupo:
			_escrever_vetor(campo, p[campo], foco)
	if _campos.has("tipo"):
		(_campos["tipo"] as OptionButton).select(MapaArquivo.TIPOS_PRIMITIVOS.find(p["tipo"]))
	if _campos.has("cor"):
		(_campos["cor"] as ColorPickerButton).color = p["cor"]
	if _campos.has("material"):
		(_campos["material"] as OptionButton).select(MapaArquivo.MATERIAIS.find(p["material"]))
	if _campos.has("colisao"):
		(_campos["colisao"] as CheckBox).set_pressed_no_signal(p["colisao"])
	if _campos.has("hitbox.usar"):
		_escrever_hitbox(p, foco)
	if _campos.has("grade_celula"):
		var grade := _campos["grade_celula"] as LineEdit
		if grade != foco:
			grade.text = _numero(p["grade_celula"])
		(_campos["linha_grade"] as Control).visible = p["material"] == "grade"


# ------------------------------------------------------------------- linhas
func _linha_forma() -> void:
	var linha := _nova_linha("Forma")
	var escolha := OptionButton.new()
	escolha.focus_mode = Control.FOCUS_NONE
	escolha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Só as primitivas: modelo entra pela loja e terreno pelo gerador/duplicação.
	for tipo in MapaArquivo.TIPOS_PRIMITIVOS:
		escolha.add_item(OperacoesDoEditor.ROTULO_TIPO[tipo])
	escolha.item_selected.connect(func(i): alterar_pedido.emit("tipo", MapaArquivo.TIPOS_PRIMITIVOS[i]))
	linha.add_child(escolha)
	_campos["tipo"] = escolha


## Modelo não tem forma, cor nem material para trocar — tem de onde veio e o
## tamanho em que foi importado, para desfazer uma esticada torta.
func _linha_modelo(p: Dictionary) -> void:
	var linha := _nova_linha("Modelo")
	var existe := biblioteca != null and biblioteca.tem(p["modelo"])
	var nome := str(biblioteca.info(p["modelo"])["nome"]) if existe else "%s (fora da loja)" % p["modelo"]
	var rotulo := EstiloDoEditor.explicacao(nome)
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)
	if existe:
		# ↺ volta ao tamanho PADRÃO da loja (o tamanho certo no mundo), que só é
		# igual ao do arquivo quando o modelo não tem padrão próprio.
		var padrao: Vector3 = biblioteca.tamanho_padrao(p["modelo"])
		var voltar := EstiloDoEditor.botao("↺", "Voltar ao tamanho padrão (%s)" % str(padrao))
		voltar.pressed.connect(func(): alterar_pedido.emit("tamanho", padrao))
		linha.add_child(voltar)


## Área de animais: qual espécie (os modelos da categoria Animais da loja) e quantos.
func _linha_area_animais(p: Dictionary) -> void:
	var linha := _nova_linha("Espécie")
	var escolha := OptionButton.new()
	escolha.name = "Especie"
	escolha.focus_mode = Control.FOCUS_NONE
	escolha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ids: Array[String] = []
	if biblioteca != null:
		for id in biblioteca.ids():
			if biblioteca.categorias_do_modelo(id).has("animais"):
				ids.append(id)
	if not ids.has(String(p["especie"])):
		ids.append(String(p["especie"]))   # espécie que saiu da loja continua visível
	for id in ids:
		var nome := str(biblioteca.info(id)["nome"]) if biblioteca != null and biblioteca.tem(id) else "%s (fora da loja)" % id
		var ficha := biblioteca.ficha_de_animal(id) if biblioteca != null and biblioteca.tem(id) else {}
		if not str(ficha.get("nome", "")).is_empty():
			nome = str(ficha["nome"])         # o nome em português que o jogador vê
		if not ficha.is_empty():
			nome += "  ·  %s%s" % [ficha["comportamento"], " · CHEFE" if ficha.get("boss", false) else ""]
		escolha.add_item(nome)
	escolha.select(ids.find(String(p["especie"])))
	escolha.item_selected.connect(func(i): alterar_pedido.emit("especie", ids[i]))
	linha.add_child(escolha)
	var linha_q := _nova_linha("Quantidade")
	var q := EstiloDoEditor.campo()
	q.name = "Quantidade"
	q.text = str(p["quantidade"])
	q.text_submitted.connect(func(_t): alterar_pedido.emit("quantidade", q.text.to_int()))
	q.focus_exited.connect(func(): alterar_pedido.emit("quantidade", q.text.to_int()))
	linha_q.add_child(q)
	_corpo.add_child(EstiloDoEditor.explicacao("Nascem em pontos aleatórios do chão dentro da área e renascem em 30 s num ponto novo; o chefe volta ao covil em 5 min. Invisível no jogo."))


## Bloco de relevo: o que ele é, em números. Esticar no gizmo estica o relevo.
func _linha_terreno(p: Dictionary) -> void:
	var linha := _nova_linha("Terreno")
	var r: Dictionary = p["relevo"]
	var celula: float = (p["tamanho"] as Vector3).x / float(r["celulas"])
	var maior := 0
	for v in (r["alturas"] as PackedInt32Array):
		maior = maxi(maior, v)
	var texto := "%d×%d células de %.1f m · ponto mais alto %.1f m" % [r["celulas"], r["celulas"],
		celula, float(maior) / TerrenoDoMapa.ESCALA * (p["tamanho"] as Vector3).y]
	if not (r["agua"] as PackedInt32Array).is_empty():
		texto += " · tem rio"
	var rotulo := EstiloDoEditor.explicacao(texto)
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)


func _linha_vetor(rotulo: String, campo: String) -> void:
	var linha := _nova_linha(rotulo)
	var trio: Array[LineEdit] = []
	for eixo in 3:
		var c := EstiloDoEditor.campo()
		c.placeholder_text = "XYZ"[eixo]
		c.tooltip_text = "%s %s" % [rotulo, "XYZ"[eixo]]
		c.text_submitted.connect(func(_t): _enviar_vetor(campo))
		c.focus_exited.connect(func(): _enviar_vetor(campo))
		linha.add_child(c)
		trio.append(c)
	_campos[campo] = trio


func _linha_aparencia(uma_peca: bool) -> void:
	var linha_cor := _nova_linha("Cor")
	var cor := ColorPickerButton.new()
	cor.edit_alpha = false
	cor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cor.custom_minimum_size = Vector2(0, 24)
	# Ao vivo enquanto o seletor está aberto; um passo de desfazer só ao fechar.
	cor.color_changed.connect(func(c): cor_ao_vivo.emit(c))
	cor.popup_closed.connect(func(): cor_fechada.emit())
	linha_cor.add_child(cor)
	_campos["cor"] = cor

	var linha_mat := _nova_linha("Material")
	var mat := OptionButton.new()
	mat.focus_mode = Control.FOCUS_NONE
	mat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mat.add_item("Liso")
	mat.add_item("Grade")
	mat.item_selected.connect(func(i): alterar_pedido.emit("material", MapaArquivo.MATERIAIS[i]))
	linha_mat.add_child(mat)
	_campos["material"] = mat

	if uma_peca:
		var linha_grade := _nova_linha("Célula da grade")
		var grade := EstiloDoEditor.campo()
		grade.text_submitted.connect(func(_t): _enviar_numero("grade_celula", grade))
		grade.focus_exited.connect(func(): _enviar_numero("grade_celula", grade))
		linha_grade.add_child(grade)
		_campos["grade_celula"] = grade
		_campos["linha_grade"] = linha_grade

	_linha_colisao()


func _linha_colisao() -> void:
	var linha_col := _nova_linha("Colisão")
	var col := CheckBox.new()
	col.focus_mode = Control.FOCUS_NONE
	col.text = "o jogador esbarra"
	col.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	col.toggled.connect(func(v): alterar_pedido.emit("colisao", v))
	linha_col.add_child(col)
	_campos["colisao"] = col


## HITBOX (23/09/2026) — o volume que o jogador esbarra, separado da aparência.
## Automática = o que sempre foi (a forma sai do tipo/tamanho da peça, e no modelo
## da malha dele). Própria = o volume que o dono desenha aqui ou arrasta no 3D.
func _linha_hitbox(e_modelo: bool) -> void:
	_corpo.add_child(EstiloDoEditor.rotulo("Hitbox"))
	var linha := _nova_linha("Volume")
	var usar := CheckBox.new()
	usar.focus_mode = Control.FOCUS_NONE
	usar.text = "própria"
	usar.tooltip_text = "Desligada, a colisão sai do tipo e do tamanho da peça" \
		+ (" (ou da malha do modelo)" if e_modelo else "") + ". Ctrl+H arrasta o volume no 3D."
	usar.add_theme_font_size_override("font_size", EstiloDoEditor.FONTE)
	usar.toggled.connect(func(v): alterar_pedido.emit("hitbox.usar", v))
	linha.add_child(usar)
	_campos["hitbox.usar"] = usar

	var linha_forma := _nova_linha("Forma")
	var escolha := OptionButton.new()
	escolha.focus_mode = Control.FOCUS_NONE
	escolha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for forma in MapaArquivo.FORMAS_HITBOX:
		escolha.add_item(forma.capitalize())
	escolha.item_selected.connect(func(i):
		alterar_pedido.emit("hitbox.forma", MapaArquivo.FORMAS_HITBOX[i]))
	linha_forma.add_child(escolha)
	_campos["hitbox.forma"] = escolha
	_hitbox_controles.append(escolha)

	for par in [["Desloc.", "hitbox.deslocamento"], ["Medida", "hitbox.tamanho"],
			["Giro °", "hitbox.rotacao_graus"]]:
		_linha_vetor(par[0], par[1])
		for c in (_campos[par[1]] as Array):
			_hitbox_controles.append(c as Control)

	var linha_botoes := _nova_linha("")
	var aplicar := EstiloDoEditor.botao("Aplicar nas iguais",
		"Copia esta hitbox para todas as peças do mesmo tipo/modelo, num passo só de desfazer")
	aplicar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aplicar.pressed.connect(func(): aplicar_hitbox_pedido.emit())
	linha_botoes.add_child(aplicar)
	_hitbox_controles.append(aplicar)
	_campos["hitbox.aplicar_botao"] = aplicar


func _nova_linha(rotulo: String) -> HBoxContainer:
	var linha := HBoxContainer.new()
	var r := EstiloDoEditor.rotulo(rotulo, true)
	r.custom_minimum_size = Vector2(82, 0)
	linha.add_child(r)
	_corpo.add_child(linha)
	return linha


# ----------------------------------------------------------------- envio
func _enviar_vetor(campo: String) -> void:
	if not _campos.has(campo):
		return
	var trio: Array = _campos[campo]
	var v := Vector3.ZERO
	for eixo in 3:
		var n := _ler((trio[eixo] as LineEdit).text)
		if is_nan(n):
			atualizar.call_deferred()      # texto inválido: devolve o valor atual
			return
		v[eixo] = n
	alterar_pedido.emit(campo, v)


func _enviar_numero(campo: String, c: LineEdit) -> void:
	var n := _ler(c.text)
	if is_nan(n):
		atualizar.call_deferred()
		return
	alterar_pedido.emit(campo, n)


func _escrever_vetor(campo: String, v: Vector3, foco: Control) -> void:
	var trio: Array = _campos[campo]
	for eixo in 3:
		var c := trio[eixo] as LineEdit
		if c != foco:
			c.text = _numero(v[eixo])


static func _ler(texto: String) -> float:
	var t := texto.strip_edges().replace(",", ".")
	return float(t) if t.is_valid_float() else NAN


static func _numero(v: float) -> String:
	var s := str(snappedf(v, 0.001))
	return "0" if s == "-0" or s == "-0.0" else s.trim_suffix(".0")
