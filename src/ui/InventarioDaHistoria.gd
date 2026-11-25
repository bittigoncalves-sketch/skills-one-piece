class_name InventarioDaHistoria
extends PanelContainer
# ============================================================================
#  INVENTÁRIO DO MODO HISTÓRIA — aba do M (era a tecla N; 30/10/2026 virou página da
#  `CentralDeJanelas`, que dá moldura, tamanho e posição).
#
#  Pedido do dono: o N é o inventário, destinado agora a GUARDAR PETS e ITENS DE PESCA.
#  Decisões dele: o personagem já começa com a gaivota e o caranguejo; tirar e guardar o
#  pet é aqui (saiu do M); o que está no inventário é salvo no progresso; a aba PESCA
#  existe vazia até a pesca existir. A loja virá depois, com um vendedor.
#
#  Só MOSTRA e PEDE: quem tira/guarda o corpo é a `Companhia`; quem sabe o que o
#  jogador tem é a `ProgressaoDoPersonagem`.
#
#  A aba FRUTAS acabou (25/11/2026, pedido do dono): Akuma no Mi e frutas do pomar são itens do
#  inventário normal (`ItensDeFruta`, hotbar/mochila). Botão direito na Akuma come; com a fruta do
#  pomar no slot selecionado ela fica na MÃO (`FrutaNaMao`) — com ela, Y tenta domar um herbívoro.
# ============================================================================

signal aviso(texto: String)

const LARGURA := 600.0
## Largura do painel quando mora na MOCHILA (19/11/2026): ao lado da grade de slots, dentro da central de 1040 px.
const LARGURA_NA_MOCHILA := 420.0
## A aba PETS saiu (10/11/2026, pedido do dono): fazia o mesmo que a TRIPULAÇÃO (`JanelaDaTripulacao`/`MenuDeComportamento`).
const ABAS := ["pesca", "armas", "materiais"]   # a aba FRUTAS acabou (25/11/2026): as frutas são itens do inventário (`ItensDeFruta`)
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "inventario"

var progressao: ProgressaoDoPersonagem
var companhia: Node = null
var mao: FrutaNaMao = null
var aba := "pesca"

var _lista_pesca: VBoxContainer
var _lista_materiais: VBoxContainer
var _lista_armas: VBoxContainer
var _botoes_aba := {}
## Akuma no Mi à espera do "Confirmar" (comer troca a fruta atual — 03/10/2026).
var _confirmando := ""
## Hospedado pela `CentralDeJanelas` (ver `embutir`).
var embutido := false
var _cabeca: Control
var _margem: MarginContainer


func ligar(prog: ProgressaoDoPersonagem, comp: Node, a_mao: FrutaNaMao = null) -> void:
	progressao = prog
	companhia = comp
	mao = a_mao
	if mao != null:
		mao.mudou.connect(atualizar)
	prog.mudou.connect(atualizar)
	atualizar()


func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	custom_minimum_size = Vector2(LARGURA, 0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	_cabeca = EstiloDaHistoria.cabeca("INVENTÁRIO", ["M", "ESC"] as Array[String])
	raiz.add_child(_cabeca)

	var margem := MarginContainer.new()
	_margem = margem
	for lado in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(lado, 24)
	margem.add_theme_constant_override("margin_top", 14)
	margem.add_theme_constant_override("margin_bottom", 20)
	raiz.add_child(margem)
	var coluna := VBoxContainer.new()
	coluna.add_theme_constant_override("separation", 12)
	margem.add_child(coluna)

	var abas := HBoxContainer.new()
	abas.add_theme_constant_override("separation", 8)
	coluna.add_child(abas)
	for id in ABAS:
		var b := EstiloDaHistoria.botao(id.to_upper(), func(): mostrar_aba(id))
		b.name = "Aba_" + id
		b.custom_minimum_size = Vector2(110, 32)
		_botoes_aba[id] = b
		abas.add_child(b)

	_lista_pesca = VBoxContainer.new()
	_lista_pesca.name = "Pesca"
	_lista_pesca.add_theme_constant_override("separation", 8)
	coluna.add_child(_lista_pesca)
	_lista_armas = VBoxContainer.new()
	_lista_armas.name = "Armas"
	_lista_armas.add_theme_constant_override("separation", 8)
	coluna.add_child(_lista_armas)
	_lista_materiais = VBoxContainer.new()
	_lista_materiais.name = "Materiais"
	coluna.add_child(_lista_materiais)
	if embutido:
		_aplicar_embutido()
	mostrar_aba("pesca")
	if embutido:
		embutir()


func mostrar_aba(id: String) -> void:
	aba = id
	_lista_materiais.visible = id == "materiais"
	_lista_armas.visible = id == "armas"
	_lista_pesca.visible = id == "pesca"
	for chave in _botoes_aba:
		EstiloDaHistoria.estilizar_botao(_botoes_aba[chave], chave == id)
	atualizar()
	if embutido:
		return
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


## Painel de itens da MOCHILA (19/11/2026, pedido do dono: frutas, pesca, armas e materiais passam do inventário para a mochila).
## Sem moldura própria de janela: um quadro fino ao lado da grade, com abas estreitas para caber em `LARGURA_NA_MOCHILA`.
## Pode ser chamado antes ou depois do `_ready` (a central o chama já na árvore; a HUD monta a página antes de ela entrar): o que depende dos filhos espera o `_ready`.
func embutir() -> void:
	embutido = true
	if is_node_ready():
		_aplicar_embutido()


func _aplicar_embutido() -> void:
	var quadro := StyleBoxFlat.new()
	quadro.bg_color = Color(0, 0, 0, 0.22)
	quadro.border_color = Color(EstiloDaHistoria.DOURADO, 0.35)
	quadro.set_border_width_all(1)
	quadro.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", quadro)
	custom_minimum_size = Vector2(LARGURA_NA_MOCHILA, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	_cabeca.visible = false
	for lado in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		_margem.add_theme_constant_override(lado, 10)
	for id in _botoes_aba:
		var b: Button = _botoes_aba[id]
		b.custom_minimum_size = Vector2(84, 30)
		b.add_theme_font_size_override("font_size", 13)
		(b.get_parent() as HBoxContainer).add_theme_constant_override("separation", 6)


func _nome_do_pet(id: String) -> String:
	return progressao.nome_do_pet(id) if progressao != null else CatalogoDePets.nome(id)


func tirar(id: String) -> bool:
	if companhia == null:
		return false
	var ok: bool = companhia.chamar(id)
	if ok:
		aviso.emit("%s saiu do inventário" % _nome_do_pet(id))
	else:
		var motivo := str(companhia.get("motivo"))
		aviso.emit(motivo if not motivo.is_empty() else "Não há lugar livre por perto para %s" % _nome_do_pet(id))
	atualizar()
	return ok


func guardar(id: String) -> void:
	if companhia == null:
		return
	companhia.recolher(id)
	aviso.emit("%s guardado no inventário" % _nome_do_pet(id))
	atualizar()


## DESEMPENHO (12/11/2026, "lag extremo ao rolar a hotbar"): cada troca de slot emite `progressao.mudou`, e esta janela refazia TODAS as listas (inclusive 32 linhas das armas do
## Epic Fight, ~700 ms) mesmo fechada. Agora só refaz se está aberta; fechada, marca como suja e refaz ao abrir.
var _suja := false


func atualizar() -> void:
	if progressao == null or _lista_pesca == null:
		return
	if not is_visible_in_tree():
		_suja = true
		return
	_suja = false
	_atualizar_materiais()
	_atualizar_armas()
	_atualizar_pesca()
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _suja and is_visible_in_tree():
		atualizar()


func _atualizar_materiais() -> void:
	for filho in _lista_materiais.get_children():
		_lista_materiais.remove_child(filho)
		filho.queue_free()
	var quantidade := EstiloDaHistoria.rotulo("Madeira (tábuas) × %d" % progressao.madeira, EstiloDaHistoria.DOURADO, 18)
	quantidade.name = "QuantidadeMadeira"
	_lista_materiais.add_child(quantidade)


func _atualizar_armas() -> void:
	for filho in _lista_armas.get_children():
		_lista_armas.remove_child(filho)
		filho.queue_free()
	_atualizar_laminas_ef()
	if not progressao.equipamentos.has("espada"):
		return
	var linha := HBoxContainer.new()
	linha.name = "LinhaEspada"
	_lista_armas.add_child(linha)
	var nome := EstiloDaHistoria.rotulo("Espada", EstiloDaHistoria.DOURADO, 16)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(nome)
	var equipada := progressao.espada_equipada
	var botao := EstiloDaHistoria.botao("Desequipar" if equipada else "Equipar",
		func(): equipar_espada(not equipada), not equipada)
	botao.name = "EquiparEspada"
	linha.add_child(botao)
	var dica := EstiloDaHistoria.rotulo("Clique esquerdo: atacar  ·  Direito: defender\nMova o mouse antes do clique para escolher o corte.", EstiloDaHistoria.TEXTO_2, 13)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.custom_minimum_size = Vector2(LARGURA_NA_MOCHILA - 56.0, 0)
	_lista_armas.add_child(dica)


## Lâminas do Epic Fight para teste (10/11/2026): uma linha por lâmina, Equipar/Desequipar.
## No painel estreito da mochila a linha tem duas camadas: a ficha (quebra de linha) em cima, os botões embaixo.
func _atualizar_laminas_ef() -> void:
	for id in LaminasEpicFight.ids():
		if not progressao.equipamentos.has(id):
			continue
		var d := LaminasEpicFight.dados(id)
		var faixa := EstiloDaHistoria.linha_de_lista()
		faixa.name = "Linha_" + id
		_lista_armas.add_child(faixa)
		var coluna := VBoxContainer.new()
		coluna.add_theme_constant_override("separation", 4)
		faixa.add_child(coluna)
		var nome := EstiloDaHistoria.rotulo("%s  ·  dano %.0f  ·  vel. %.2f  ·  alcance %.2f m  ·  %d alvo(s)  ·  dur. %d/%d" % [d.nome, d.dano_do_mod, d.velocidade, d.ponta.y - d.base.y, d.max_alvos, progressao.durabilidade_de(id), LaminasEpicFight.durabilidade_maxima(id)], EstiloDaHistoria.DOURADO, 14)
		nome.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nome.custom_minimum_size = Vector2(LARGURA_NA_MOCHILA - 56.0, 0)
		coluna.add_child(nome)
		var botoes := HBoxContainer.new()
		botoes.add_theme_constant_override("separation", 6)
		coluna.add_child(botoes)
		var equipada := progressao.lamina_ef == id and progressao.espada_equipada
		var botao := EstiloDaHistoria.botao("Desequipar" if equipada else "Equipar",
			func(): equipar_lamina_ef(id, not equipada), not equipada)
		botao.name = "Equipar_" + id
		botoes.add_child(botao)
		# Estilo dual do mod: com uma adaga (ou espada) na mão, outra do mesmo tipo vai para a ESQUERDA.
		if progressao.espada_equipada and LaminasEpicFight.pode_dual(progressao.lamina_ef, id):
			var na_esquerda := progressao.lamina_ef_sec == id
			var b2 := EstiloDaHistoria.botao("Tirar da esquerda" if na_esquerda else "Mão esquerda",
				func(): equipar_secundaria_ef(id, not na_esquerda), na_esquerda)
			b2.name = "Esquerda_" + id
			botoes.add_child(b2)


func equipar_secundaria_ef(id: String, sim: bool) -> bool:
	if not progressao.equipar_lamina_secundaria(id, sim):
		return false
	aviso.emit("%s na mão esquerda  ·  estilo dual" % LaminasEpicFight.dados(id).nome if sim else "Segunda arma guardada")
	return true


func equipar_lamina_ef(id: String, sim: bool) -> bool:
	if not progressao.equipar_lamina(id, sim):
		return false
	if sim and mao != null:
		mao.guardar()
	aviso.emit("%s equipada  ·  clique para atacar; direito para defender" % LaminasEpicFight.dados(id).nome if sim else "Lâmina guardada")
	return true


func equipar_espada(sim: bool) -> bool:
	if not progressao.equipar_espada(sim):
		return false
	if sim and mao != null:
		mao.guardar()
	aviso.emit("Espada equipada  ·  clique para atacar; direito para defender" if sim else "Espada guardada")
	return true


func _atualizar_pesca() -> void:
	for filho in _lista_pesca.get_children():
		_lista_pesca.remove_child(filho)
		filho.queue_free()
	# VARA DE PESCA (03/10/2026): vem de graça com o pescador. Equipar põe na barra
	# de itens (1–6) já ATIVA; com ela ativa, clique pesca.
	if progressao.equipamentos.has("vara_de_pesca"):
		var faixa_vara := EstiloDaHistoria.linha_de_lista()
		faixa_vara.name = "LinhaVara"
		_lista_pesca.add_child(faixa_vara)
		var linha_vara := HBoxContainer.new()
		faixa_vara.add_child(linha_vara)
		var nome_vara := EstiloDaHistoria.rotulo("Vara de pesca", EstiloDaHistoria.DOURADO, 15)
		nome_vara.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha_vara.add_child(nome_vara)
		var equipada := progressao.vara_equipada
		var botao := EstiloDaHistoria.botao("Desequipar" if equipada else "Equipar",
			func(): equipar_vara(not equipada), not equipada)
		botao.name = "BotaoVara"
		linha_vara.add_child(botao)
	var peixes := 0
	var bib := MapaMontador.biblioteca_em_uso()
	for id in progressao.pesca:
		peixes += 1
		var faixa := EstiloDaHistoria.linha_de_lista()
		_lista_pesca.add_child(faixa)
		var linha := HBoxContainer.new()
		faixa.add_child(linha)
		var titulo := TabelaDePeixes.nome(id) if TabelaDePeixes.eh_peixe(id) \
			else (str(bib.info(id)["nome"]) if bib != null and bib.tem(id) else String(id).capitalize())
		var nome := EstiloDaHistoria.rotulo(titulo, EstiloDaHistoria.TEXTO, 15)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(nome)
		if TabelaDePeixes.eh_peixe(id):
			var r := TabelaDePeixes.raridade(id)
			linha.add_child(EstiloDaHistoria.rotulo(TabelaDePeixes.NOME_DA_RARIDADE[r], PescaHud.COR_RARIDADE[r], 13))
		linha.add_child(EstiloDaHistoria.rotulo("× %d" % int(progressao.pesca[id]), EstiloDaHistoria.TEXTO_2, 15))
	if peixes == 0 and not progressao.equipamentos.has("vara_de_pesca"):
		var vazio := EstiloDaHistoria.rotulo("Nenhum item de pesca ainda. O pescador dá a vara de graça.", EstiloDaHistoria.TEXTO_3, 14)
		vazio.name = "PescaVazia"
		vazio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vazio.custom_minimum_size = Vector2(LARGURA_NA_MOCHILA - 56.0, 0)      # sem largura mínima a quebra infla a altura (ver `FrutasVazia`)
		_lista_pesca.add_child(vazio)


## Equipar/desequipar a vara (botão do N e o teste chamam aqui).
func equipar_vara(sim: bool) -> bool:
	if not progressao.equipar_vara(sim):
		return false
	aviso.emit("Vara de pesca equipada  ·  ativa na barra; mire na água e clique" if sim else "Vara de pesca guardada")
	return true

