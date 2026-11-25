extends RefCounted
## O campo FRUTA da Identificação do Skills Builder (06/10/2026): a lista (Kit do Builder,
## as frutas do Builder e as do jogo refeitas aqui), "Criar fruta" e "Refazer fruta do
## jogo" (a Pika: as teclas publicadas trocam as dela; as vazias seguem o código).
## Saiu do `SkillsBuilder.gd` pelo teto de 900 linhas; escreve na skill pelo editor
## (`editar_campo`: desfazer e validação valem igual).

const Estilo = preload("res://src/skills_builder/estilo_builder.gd")


static func montar(ed: Control, atual: String) -> void:
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 3)
	ed._inspector.add_child(coluna)
	coluna.add_child(Estilo.rotulo("Fruta", 13, true))
	var op := OptionButton.new()
	op.name = "fruta"
	op.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	op.add_item(KitDoBuilder.NOME)
	op.set_item_metadata(0, "")
	for f in SkillsPublicadas.frutas():
		# A da arena refeita aqui (Pika): as teclas sem skill seguem o jogo.
		op.add_item(str(f.nome) + ("  (da arena: teclas vazias seguem o jogo)" if bool(f.get("reconstroi", false)) else ""))
		op.set_item_metadata(op.item_count - 1, str(f.id))
		if str(f.id) == atual:
			op.select(op.item_count - 1)
	op.item_selected.connect(_escolher_fruta.bind(ed, op))
	coluna.add_child(op)
	var nova := HBoxContainer.new()
	coluna.add_child(nova)
	var nome := LineEdit.new()
	nome.name = "NomeDaNovaFruta"
	nome.placeholder_text = "Nova fruta (ex.: Noro Noro no Mi)"
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nova.add_child(nome)
	var cor := ColorPickerButton.new()
	cor.name = "CorDaNovaFruta"
	cor.color = Color("#ff7ad9")
	cor.edit_alpha = false
	cor.custom_minimum_size = Vector2(34, 30)
	nova.add_child(cor)
	var criar := Estilo.botao("Criar fruta", _criar_fruta.bind(ed, nome, cor))
	criar.name = "CriarFruta"
	nova.add_child(criar)
	# Refazer uma fruta DO JOGO aqui (06/10/2026, a Pika): as teclas publicadas trocam as
	# dela; as que ficarem vazias seguem o código do jogo.
	var refazer := HBoxContainer.new()
	coluna.add_child(refazer)
	var jogo := OptionButton.new()
	jogo.name = "FrutaDoJogo"
	jogo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in PerfilDeFrutas.frutas_da_arena():
		jogo.add_item(PerfilDeFrutas.nome_da_fruta(id))
		jogo.set_item_metadata(jogo.item_count - 1, id)
	refazer.add_child(jogo)
	var botao := Estilo.botao("Refazer fruta do jogo", _refazer_fruta.bind(ed, jogo), "As teclas publicadas aqui trocam as da fruta; as vazias seguem o jogo")
	botao.name = "RefazerFruta"
	refazer.add_child(botao)
	# Preço na loja do Modo História (07/10/2026): o "Publicar na loja" grava junto.
	var reconstruida := SkillsPublicadas.e_reconstruida(atual)
	if not reconstruida:
		var linha := HBoxContainer.new()
		coluna.add_child(linha)
		linha.add_child(Estilo.rotulo("Preço na loja (moedas)", 13, true))
		var preco := SpinBox.new()
		preco.name = "PrecoNaLoja"
		preco.min_value = 0
		preco.max_value = maxf(SkillsPublicadas.PRECO_MAXIMO, float(PerfilDeFrutas.PRECO_POR_PODER.back()))
		preco.step = 1
		preco.value = float(ed.get("_preco_na_loja")) if int(ed.get("_preco_na_loja")) >= 0 \
			else float(SkillsPublicadas.preco(atual if not atual.is_empty() else SkillsPublicadas.ID_DO_KIT))
		if not atual.is_empty():
			preco.value = PerfilDeFrutas.preco_na_loja(atual)
			preco.editable = false
			preco.tooltip_text = "Preço definido pela tabela de frutas do Modo História."
		preco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preco.value_changed.connect(func(v: float) -> void: ed.set("_preco_na_loja", int(v)))
		linha.add_child(preco)
	ed._explicacao("Publicar na loja põe esta skill na tecla %s da fruta escolhida e a fruta à venda no vendedor de frutas do Modo História%s." % [
		str(ed.skill.ativacao.tecla), " (a fruta da arena já é vendida)" if reconstruida else ""])


static func _escolher_fruta(i: int, ed: Control, op: OptionButton) -> void:
	ed.set("_preco_na_loja", -1)        # o campo de preço volta a mostrar o da fruta escolhida
	ed.editar_campo("identificacao", "fruta", str(op.get_item_metadata(i)))


static func _criar_fruta(ed: Control, nome: LineEdit, cor: ColorPickerButton) -> void:
	var r := SkillsPublicadas.criar_fruta(nome.text, "#" + cor.color.to_html(false))
	if not r.ok:
		ed._avisar("Fruta não criada: " + "; ".join(r.erros), true)
		return
	if ed.editar_campo("identificacao", "fruta", str(r.id)):
		ed._construir_inspector.call_deferred()
	ed._avisar("Fruta criada: %s (%s). Publique as skills dela." % [nome.text.strip_edges(), r.id])


static func _refazer_fruta(ed: Control, jogo: OptionButton) -> void:
	if jogo.item_count == 0:
		return
	var id := str(jogo.get_item_metadata(jogo.selected))
	var r := SkillsPublicadas.reconstruir_fruta_da_arena(id, PerfilDeFrutas.nome_da_fruta(id), "#ffd23f")
	if not r.ok:
		ed._avisar("Não deu para refazer: " + "; ".join(r.erros), true)
		return
	if ed.editar_campo("identificacao", "fruta", id):
		ed._construir_inspector.call_deferred()
	ed._avisar("%s refeita no Builder: as teclas publicadas aqui trocam as dela." % PerfilDeFrutas.nome_da_fruta(id))
