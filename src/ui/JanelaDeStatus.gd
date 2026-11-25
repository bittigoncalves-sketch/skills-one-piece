class_name JanelaDeStatus
extends PanelContainer
## Editor de janelas (05/10/2026): o id desta janela no layout salvo.
const ID_DO_LAYOUT := "status"
signal pediu_reset_total
# ============================================================================
#  JANELA DE STATUS — tecla M no Modo História. Seção 12 do documento de
#  progressão (docs/references/modo_historia/modohistoriaplanejamento.pdf).
#
#  Só MOSTRA e PEDE: a regra (XP, barreira, pontos) mora em `ProgressaoDoPersonagem`.
#
#  ⚠️ PONTOS SÓ SAEM NO "CONFIRMAR". O documento não prevê redistribuir, então um
#  clique errado no "+" seria permanente. Os "+"/"−" montam um pedido pendente; nada
#  é gravado até confirmar, e "Descartar" volta tudo.
#
#  VISUAL (30/09/2026, pedido do dono): interface final de jogo, não ferramenta de
#  depuração. Larga e horizontal — prévia 3D do personagem à esquerda
#  (`PreviaDoPersonagem`, a mesma da Customização), informações à direita —, fundo
#  azul-petróleo quase preto, títulos dourados, barras de XP/Vida/Energia com o
#  MESMO `BarraHud` do HUD (paralelogramo e contorno do `Estilo`). Nada de ícone:
#  tudo é texto, cor, barra e forma simples. Rola só se a tela não comportar.
#  As ferramentas de teste (+XP, missão, boneco, fruta) saíram daqui para a F8
#  (`FerramentasDeTeste`).
# ============================================================================

## Cor do aviso de nível da HUD (`HistoriaHud`), que continua sendo esta.
const COR_TITULO := Color(1.0, 0.85, 0.3)

## Paleta da janela. O dourado é o do aviso, menos saturado: título, não alarme.
const DOURADO := EstiloDaHistoria.DOURADO
const TEXTO := EstiloDaHistoria.TEXTO
const TEXTO_2 := EstiloDaHistoria.TEXTO_2
const TEXTO_3 := EstiloDaHistoria.TEXTO_3
const ALERTA := Color(1.0, 0.45, 0.35)
const FUNDO := EstiloDaHistoria.FUNDO
const FUNDO_CABECA := EstiloDaHistoria.FUNDO_CABECA
const FUNDO_LINHA := EstiloDaHistoria.FUNDO_LINHA

## Medidas. Largura em 1280×720 (a base do projeto); em tela menor encolhe até caber.
const LARGURA := 1040.0
const MARGEM_DA_TELA := 24.0
const FRACAO_DA_PREVIA := 0.31
const MARGEM_INTERNA := 28.0

const DICAS := {
	"forca": "Efeito Força do Minecraft: +3 de dano físico por nível, somado ao golpe ou arma. Vem do nível do personagem (PlayerPhysicalAbility do Mine Piece).",
	"resistencia": "Efeito Resistência do Minecraft: −20 % do dano por nível (já com a armadura). Vem do nível do personagem.",
	"vida": "Efeito Aumento de Vida do Minecraft: +4 HP por nível sobre os 20 base. Vem do nível do personagem.",
	"armadura": "Armadura e tenacidade do Minecraft, até 30. Reduz o dano com a fórmula do jogo original. Vem do nível do personagem.",
}
## O que cada atributo faz, escrito NA linha. As DICAS acima seguem no tooltip, com o detalhe.
const RESUMOS := {
	"forca": "Aumenta o dano de socos, chutes e espadas (+3 por nível).",
	"resistencia": "Reduz o dano recebido (−20 % por nível).",
	"vida": "Vida máxima em pontos de vida (HP).",
	"armadura": "Reduz o dano recebido, até 30.",
}
const NOMES := {"forca": "Força", "resistencia": "Resistência", "vida": "Vida", "armadura": "Armadura"}


var progressao: ProgressaoDoPersonagem
var _botao_fruta: Button = null
## O corpo, para vida e energia AO VIVO (o dano muda a vida sem mudar o status).
var jogador: Node = null

## Os atributos vêm do nível (A6, 26/10/2026): a janela só mostra, não há pontos a distribuir.
var _rotulos := {}
var _barra_xp: BarraHud
var _barras := {}                   # "hp"/"energia" -> BarraHud
var _seletor_raca: OptionButton
var _linhas_atributo := {}          # atributo -> {valor: Label}
var _marcadores := {}               # skill -> Array[Marcador] (os quatro níveis)
var _previa: PreviaDoPersonagem
var _caixa_previa: Control
var _cabeca: Control
var _rolagem: ScrollContainer
var _corpo: Control
var _dialogo_reset: ConfirmationDialog
var _aguardando_reset := false
## Hospedada pela `CentralDeJanelas`: sem moldura, sem cabeçalho, sem se posicionar (ver `embutir`).
var embutida := false


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	prog.mudou.connect(atualizar)
	atualizar()


## Chamado pela HUD ao abrir: o corpo (vida e energia ao vivo) e a prévia com o
## personagem e o visual de AGORA — a customização pode ter mudado desde a última vez.
func abrir(corpo: Node) -> void:
	jogador = corpo
	if _previa != null:
		_previa.corpo_historia = progressao.corpo if progressao != null else ""
		_previa.tom_de_pele = progressao.tom_de_pele if progressao != null else "medio"
		_previa.aparencia_historia = progressao.aparencia.duplicate() if progressao != null else {}
		var vivo := corpo != null and is_instance_valid(corpo) and "character_id" in corpo
		_previa.remontar(String(corpo.character_id) if vivo else "")
	atualizar()


func _ready() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = FUNDO
	estilo.border_color = Color(DOURADO, 0.45)
	estilo.set_border_width_all(1)
	estilo.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", estilo)
	# Centrada e crescendo para os dois lados: o aviso de evolução bloqueada aparece e
	# some, e a janela tem de continuar no meio da tela quando muda de altura.
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var raiz := VBoxContainer.new()
	raiz.add_theme_constant_override("separation", 0)
	add_child(raiz)
	_cabeca = _montar_cabeca()
	raiz.add_child(_cabeca)

	var margem := MarginContainer.new()
	for lado in ["margin_left", "margin_right"]:
		margem.add_theme_constant_override(lado, int(MARGEM_INTERNA))
	margem.add_theme_constant_override("margin_top", 18)
	margem.add_theme_constant_override("margin_bottom", 22)
	raiz.add_child(margem)
	_rolagem = ScrollContainer.new()
	_rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margem.add_child(_rolagem)

	var corpo := HBoxContainer.new()
	corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corpo.add_theme_constant_override("separation", 28)
	_rolagem.add_child(corpo)
	_corpo = corpo
	_caixa_previa = _montar_previa()
	corpo.add_child(_caixa_previa)

	var direita := VBoxContainer.new()
	direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	direita.add_theme_constant_override("separation", 10)
	corpo.add_child(direita)
	direita.add_child(_montar_topo())
	direita.add_child(_divisoria())
	_montar_atributos(direita)
	direita.add_child(_divisoria())
	_montar_skills(direita)
	direita.add_child(_divisoria())
	var reset := _botao("Reset total da campanha…", pedir_reset_total)
	reset.name = "ResetTotal"
	reset.focus_mode = Control.FOCUS_ALL
	_estilizar(reset, false)
	reset.add_theme_color_override("font_color", ALERTA)
	direita.add_child(reset)
	_montar_confirmacao_reset()
	visibility_changed.connect(func():
		if not is_visible_in_tree():
			cancelar_reset_total())

	get_viewport().size_changed.connect(_ajustar)
	_ajustar()


## Relê tudo do status. Chamado a cada mudança dele e ao abrir.
func atualizar() -> void:
	if progressao == null or _barra_xp == null:
		return
	var p := progressao
	_seletor_raca.select(ProgressaoDoPersonagem.RACAS.find(p.raca))
	(_rotulos["nivel"] as Label).text = "%d — %s" % [p.nivel, p.titulo()]
	(_rotulos["ouro"] as Label).text = _milhar(p.ouro)
	(_rotulos["xp"] as Label).text = "%s / %s" % [_milhar(p.xp), _milhar(p.xp_necessario())]
	(_rotulos["proximo"] as Label).text = "%d — %s" % [p.nivel + 1, p.titulo(p.nivel + 1)]
	_barra_xp.valor(float(mini(p.xp, p.xp_necessario())) / maxf(float(p.xp_necessario()), 1.0))
	_rotulos["bloqueio"].visible = false
	for skill in ProgressaoDoPersonagem.SKILLS:
		var n := int(p.skills[skill])
		(_rotulos["skill_" + skill + "_n"] as Label).text = "%d/%d" % [n, ProgressaoDoPersonagem.SKILL_MAXIMO]
		(_rotulos["skill_" + skill] as Label).text = ProgressaoDoPersonagem.NOMES_SKILL[n]
		(_rotulos["skill_" + skill] as Label).add_theme_color_override("font_color", TEXTO if n > 0 else TEXTO_3)
		var marcas: Array = _marcadores[skill]
		for i in marcas.size():
			(marcas[i] as Marcador).acender(i < n)
	# Linha da fruta: qual é e se está ligada; o botão só existe com fruta comida.
	if _botao_fruta != null:
		_botao_fruta.visible = p.tem_fruta()
		_botao_fruta.text = "Desligar" if p.fruta_ativa else "Ligar"
		if p.tem_fruta():
			var rotulo := _rotulos["skill_fruta"] as Label
			rotulo.text = "%s · %s" % [p.fruta.capitalize(), "ligada" if p.fruta_ativa else "desligada"]
			rotulo.add_theme_color_override("font_color", TEXTO if p.fruta_ativa else TEXTO_3)
	_atualizar_atributos()
	_atualizar_recursos()
	_ajustar.call_deferred()


func _montar_confirmacao_reset() -> void:
	_dialogo_reset = ConfirmationDialog.new()
	_dialogo_reset.name = "ConfirmacaoResetTotal"
	_dialogo_reset.title = "Reset total da campanha"
	_dialogo_reset.dialog_text = "Voltar ao nível 1 e começar a campanha novamente?\n\nSerão apagados XP, ouro, atributos, skills, frutas, materiais,\npets adquiridos, barcos, missões e desbloqueios.\nVocê receberá novamente os itens iniciais.\n\nO mapa criado, a aparência e as configurações serão preservados.\nEsta ação não pode ser desfeita."
	_dialogo_reset.ok_button_text = "Apagar progresso e reiniciar"
	_dialogo_reset.cancel_button_text = "Cancelar"
	_dialogo_reset.exclusive = true
	_dialogo_reset.confirmed.connect(_confirmar_reset_total)
	_dialogo_reset.canceled.connect(cancelar_reset_total)
	add_child(_dialogo_reset)
	_estilizar(_dialogo_reset.get_ok_button(), false)
	_estilizar(_dialogo_reset.get_cancel_button(), true)


func pedir_reset_total() -> void:
	if progressao == null or _aguardando_reset:
		return
	_aguardando_reset = true
	_dialogo_reset.popup_centered()
	_dialogo_reset.get_cancel_button().grab_focus()


func cancelar_reset_total() -> void:
	_aguardando_reset = false
	if _dialogo_reset != null:
		_dialogo_reset.hide()


func confirmacao_reset_aberta() -> bool:
	return _aguardando_reset


func _confirmar_reset_total() -> void:
	if not _aguardando_reset:
		return
	cancelar_reset_total()
	pediu_reset_total.emit()


func _process(_delta: float) -> void:
	if visible:
		_atualizar_recursos()


## Liga/desliga a Akuma no Mi (o progresso salva; o Modo História reaplica no corpo).
func alternar_fruta() -> void:
	if progressao != null and progressao.tem_fruta():
		progressao.definir_fruta_ativa(not progressao.fruta_ativa)


# ------------------------------------------------------------------- internos
func _atualizar_atributos() -> void:
	for atributo in _linhas_atributo:
		var valor := (_linhas_atributo[atributo] as Dictionary)["valor"] as Label
		var v := progressao.valor_do_atributo(atributo)
		match atributo:
			"forca": valor.text = "%d (+%d)" % [v, roundi(progressao.RegrasDosAtributos.bonus_fisico(progressao.nivel))]
			"resistencia": valor.text = "%d (−%d%%)" % [v, mini(v * 20, 100)]
			"vida": valor.text = "%d HP" % v
			_: valor.text = "%d" % v


func _atualizar_recursos() -> void:
	if progressao == null or _barra_xp == null:
		return
	var vivo := jogador != null and is_instance_valid(jogador)
	var hp_max: float = jogador.max_health if vivo else float(progressao.hp_maximo())
	var hp: float = jogador.health if vivo else hp_max
	var en_max: float = jogador.max_energy if vivo else float(progressao.energia_maxima())
	var en: float = jogador.energy if vivo else en_max
	(_rotulos["hp"] as Label).text = "%d / %d" % [VidaEnergiaHud.vida_exibida(hp), roundi(hp_max)]
	(_rotulos["energia"] as Label).text = "%d / %d" % [floori(en), roundi(en_max)]
	(_barras["hp"] as BarraHud).valor(hp / maxf(hp_max, 1.0))
	(_barras["energia"] as BarraHud).valor(en / maxf(en_max, 1.0))


## Largura pela tela (até `LARGURA`), prévia com ~31% dela, e a altura da área de
## conteúdo = a natural, ou o que sobra da tela (aí, e só aí, a rolagem aparece).
func _ajustar() -> void:
	if not is_inside_tree() or _corpo == null:
		return
	if embutida:
		_caixa_previa.custom_minimum_size.x = roundf(CentralDeJanelas.LARGURA * FRACAO_DA_PREVIA)
		return
	var tela := get_viewport_rect().size
	var largura := minf(LARGURA, tela.x - 2.0 * MARGEM_DA_TELA)
	custom_minimum_size = Vector2(largura, 0.0)
	_caixa_previa.custom_minimum_size.x = roundf(largura * FRACAO_DA_PREVIA)
	var natural := _corpo.get_combined_minimum_size().y
	var sobra := tela.y - 2.0 * MARGEM_DA_TELA - _cabeca.get_combined_minimum_size().y - 40.0
	_rolagem.custom_minimum_size.y = clampf(natural, 120.0, maxf(120.0, sobra))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	LayoutDeJanelas.aplicar(ID_DO_LAYOUT, self)


## A central é quem dá moldura, título (as abas), tamanho e posição; a janela só preenche o corpo
## e rola por dentro quando o conteúdo é maior.
func embutir() -> void:
	embutida = true
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	custom_minimum_size = Vector2.ZERO
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cabeca.visible = false
	var margem := _rolagem.get_parent() as Control
	margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rolagem.custom_minimum_size = Vector2.ZERO
	_ajustar()


# -------------------------------------------------------------------- montagem
func _montar_cabeca() -> Control:
	var faixa := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = FUNDO_CABECA
	st.border_color = Color(DOURADO, 0.55)
	st.border_width_bottom = 2
	st.corner_radius_top_left = 8
	st.corner_radius_top_right = 8
	st.content_margin_left = MARGEM_INTERNA
	st.content_margin_right = MARGEM_INTERNA
	st.content_margin_top = 12
	st.content_margin_bottom = 12
	faixa.add_theme_stylebox_override("panel", st)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	faixa.add_child(linha)
	var titulo := _rotulo("PERSONAGEM", DOURADO, 24)
	titulo.add_theme_color_override("font_outline_color", Estilo.LINHA)
	titulo.add_theme_constant_override("outline_size", 4)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(titulo)
	# Teclas como plaquinhas com a letra: forma + texto, sem ícone.
	linha.add_child(_tecla("M"))
	linha.add_child(_tecla("ESC"))
	var fechar := _rotulo("fechar", TEXTO_3, 14)
	fechar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	linha.add_child(fechar)
	return faixa


func _montar_previa() -> Control:
	var caixa := PanelContainer.new()
	caixa.name = "Previa"
	caixa.size_flags_vertical = Control.SIZE_FILL
	caixa.custom_minimum_size = Vector2(300, 380)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.0, 0.03, 0.04, 0.55)
	st.border_color = Color(DOURADO, 0.16)
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	caixa.add_theme_stylebox_override("panel", st)
	var pilha := VBoxContainer.new()
	pilha.add_theme_constant_override("separation", 0)
	caixa.add_child(pilha)
	_previa = PreviaDoPersonagem.new()
	_previa.name = "Personagem"
	# O modelo só é montado ao ABRIR (`abrir`): a janela nasce escondida e passa a
	# sessão assim; montar agora gastaria um personagem inteiro sem ninguém ver.
	_previa.montar_ao_entrar = false
	_previa.cor_da_base = Color(0.03, 0.10, 0.12)
	_previa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_previa.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pilha.add_child(_previa)
	var dica := _rotulo("arraste para girar", TEXTO_3, 12)
	dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilha.add_child(dica)
	var respiro := Control.new()
	respiro.custom_minimum_size = Vector2(0, 8)
	pilha.add_child(respiro)
	return caixa


## Raça, nível e XP à esquerda; vida, energia e ouro à direita. Lado a lado é o que
## deixa a janela inteira caber em 720 px de altura sem rolar.
func _montar_topo() -> Control:
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 36)

	var geral := VBoxContainer.new()
	geral.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	geral.size_flags_stretch_ratio = 1.2
	geral.add_theme_constant_override("separation", 10)
	topo.add_child(geral)
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 24)
	grade.add_theme_constant_override("v_separation", 6)
	geral.add_child(grade)
	for par in [["raca", "Raça"], ["nivel", "Nível"]]:
		var nome := _rotulo(par[1], TEXTO_2, 15)
		nome.custom_minimum_size = Vector2(70, 0)
		grade.add_child(nome)
		if par[0] == "raca":
			_seletor_raca = OptionButton.new()
			_seletor_raca.name = "EscolherRaca"
			_seletor_raca.add_item("Humano")
			_seletor_raca.add_item("Sharkman")
			_seletor_raca.tooltip_text = "Sharkman: respiração infinita; nado normal na velocidade da corrida; Shift nada ao dobro e gasta energia."
			_seletor_raca.item_selected.connect(func(i: int):
				if progressao != null: progressao.definir_raca(ProgressaoDoPersonagem.RACAS[i]))
			grade.add_child(_seletor_raca)
			continue
		var valor := _rotulo("", TEXTO, 17)
		grade.add_child(valor)
		_rotulos[par[0]] = valor

	var xp := VBoxContainer.new()
	xp.add_theme_constant_override("separation", 6)
	geral.add_child(xp)
	var cabeca_xp := HBoxContainer.new()
	xp.add_child(cabeca_xp)
	var nome_xp := _rotulo("EXPERIÊNCIA", TEXTO_2, 13)
	nome_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabeca_xp.add_child(nome_xp)
	_rotulos["xp"] = _rotulo("", TEXTO, 15)
	cabeca_xp.add_child(_rotulos["xp"])
	_barra_xp = _barra(DOURADO, 14.0)
	xp.add_child(_barra_xp)
	var proximo := HBoxContainer.new()
	proximo.add_theme_constant_override("separation", 6)
	xp.add_child(proximo)
	proximo.add_child(_rotulo("Próximo nível:", TEXTO_3, 13))
	_rotulos["proximo"] = _rotulo("", TEXTO_2, 13)
	proximo.add_child(_rotulos["proximo"])
	_rotulos["bloqueio"] = _rotulo("", ALERTA, 13)
	_rotulos["bloqueio"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rotulos["bloqueio"].visible = false
	geral.add_child(_rotulos["bloqueio"])

	var recursos := VBoxContainer.new()
	recursos.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recursos.add_theme_constant_override("separation", 12)
	topo.add_child(recursos)
	_recurso(recursos, "hp", "VIDA", Estilo.VIDA)
	_recurso(recursos, "energia", "ENERGIA", Estilo.ENERGIA)
	var ouro := HBoxContainer.new()
	recursos.add_child(ouro)
	var nome_ouro := _rotulo("OURO", TEXTO_2, 13)
	nome_ouro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nome_ouro.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ouro.add_child(nome_ouro)
	_rotulos["ouro"] = _rotulo("", DOURADO, 18)
	ouro.add_child(_rotulos["ouro"])
	return topo


func _recurso(pai: VBoxContainer, chave: String, nome: String, cor: Color) -> void:
	var bloco := VBoxContainer.new()
	bloco.add_theme_constant_override("separation", 5)
	pai.add_child(bloco)
	var linha := HBoxContainer.new()
	bloco.add_child(linha)
	var rotulo := _rotulo(nome, TEXTO_2, 13)
	rotulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linha.add_child(rotulo)
	_rotulos[chave] = _rotulo("", TEXTO, 15)
	linha.add_child(_rotulos[chave])
	_barras[chave] = _barra(cor, 12.0)
	(_barras[chave] as BarraHud).cor_pela_vida = chave == "hp"
	bloco.add_child(_barras[chave])


func _montar_atributos(pai: VBoxContainer) -> void:
	pai.add_child(_secao("ATRIBUTOS · pelo nível"))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 4)
	pai.add_child(lista)
	for atributo in ProgressaoDoPersonagem.ATRIBUTOS:
		_linha_atributo(lista, atributo)


func _linha_atributo(pai: VBoxContainer, atributo: String) -> void:
	# Faixa de fundo discreta por linha: o valor e os botões ficam longe um do outro
	# (os botões se alinham à direita, com "Pontos disponíveis"), e a faixa é o que
	# liga os dois ao olho.
	var faixa := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = FUNDO_LINHA
	st.set_corner_radius_all(4)
	st.content_margin_left = 12
	st.content_margin_right = 6
	st.content_margin_top = 3
	st.content_margin_bottom = 3
	faixa.add_theme_stylebox_override("panel", st)
	faixa.tooltip_text = "%s\n%s" % [NOMES[atributo], DICAS[atributo]]
	pai.add_child(faixa)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", 8)
	linha.mouse_filter = Control.MOUSE_FILTER_PASS
	faixa.add_child(linha)
	var nome := _rotulo(NOMES[atributo], TEXTO, 16)
	nome.custom_minimum_size = Vector2(170, 0)
	nome.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nome.mouse_filter = Control.MOUSE_FILTER_PASS
	linha.add_child(nome)
	var resumo := _rotulo(str(RESUMOS.get(atributo, "")), TEXTO_2, 13)
	resumo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resumo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	resumo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resumo.custom_minimum_size = Vector2(120, 0)
	resumo.mouse_filter = Control.MOUSE_FILTER_PASS
	linha.add_child(resumo)
	var valor := _rotulo("0", TEXTO, 17)
	valor.custom_minimum_size = Vector2(110, 0)
	valor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	valor.mouse_filter = Control.MOUSE_FILTER_PASS
	linha.add_child(valor)
	_linhas_atributo[atributo] = {"valor": valor}


func _montar_skills(pai: VBoxContainer) -> void:
	pai.add_child(_secao("SKILLS"))
	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 8)
	pai.add_child(lista)
	for skill in ProgressaoDoPersonagem.SKILLS:
		var linha := HBoxContainer.new()
		linha.add_theme_constant_override("separation", 14)
		lista.add_child(linha)
		var nome := _rotulo(skill.capitalize(), TEXTO, 16)
		nome.custom_minimum_size = Vector2(170, 0)
		linha.add_child(nome)
		# Os quatro níveis (§20) como quatro formas: acesa = aprendida.
		var nivel := HBoxContainer.new()
		nivel.add_theme_constant_override("separation", 5)
		nivel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		linha.add_child(nivel)
		var marcas: Array = []
		for i in ProgressaoDoPersonagem.SKILL_MAXIMO:
			var m := Marcador.new()
			nivel.add_child(m)
			marcas.append(m)
		_marcadores[skill] = marcas
		var n := _rotulo("", TEXTO_3, 14)
		n.custom_minimum_size = Vector2(40, 0)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		linha.add_child(n)
		_rotulos["skill_" + skill + "_n"] = n
		var estado := _rotulo("", TEXTO, 15)
		estado.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(estado)
		_rotulos["skill_" + skill] = estado
		if skill == "fruta":
			# Interruptor da Akuma no Mi (01/10/2026, decisão do dono): desligada, o
			# personagem fica como quem nunca comeu — sem técnicas E nadando.
			_botao_fruta = _botao("Desligar", alternar_fruta)
			_botao_fruta.name = "AlternarFruta"
			_botao_fruta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_estilizar(_botao_fruta, false)
			linha.add_child(_botao_fruta)


# ---------------------------------------------------------------- peças soltas
func _secao(texto: String) -> Label:
	var l := _rotulo(texto, DOURADO, 17)
	l.add_theme_color_override("font_outline_color", Estilo.LINHA)
	l.add_theme_constant_override("outline_size", 3)
	return l


func _divisoria() -> Control:
	var linha := ColorRect.new()
	linha.color = Color(DOURADO, 0.18)
	linha.custom_minimum_size = Vector2(0, 1)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return linha


func _tecla(texto: String) -> Control:
	return EstiloDaHistoria.tecla(texto)


func _barra(cor: Color, altura: float) -> BarraHud:
	var b := BarraHud.new()
	b.cor = cor
	b.custom_minimum_size = Vector2(0, altura)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b


func _rotulo(texto: String, cor: Color, tamanho: int) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_color_override("font_color", cor)
	l.add_theme_font_size_override("font_size", tamanho)
	return l


func _botao(texto: String, ao_clicar: Callable) -> Button:
	var b := Button.new()
	b.text = texto
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.pressed.connect(ao_clicar)
	return b


## Botões da janela: contorno dourado discreto; `primario` é cheio (o Confirmar).
## Desabilitado fica apagado de verdade — é o aviso de que a ação não cabe agora.
func _estilizar(b: Button, primario: bool) -> void:
	EstiloDaHistoria.estilizar_botao(b, primario)


## 8450 → "8.450", como no documento.
static func _milhar(n: int) -> String:
	var s := str(absi(n))
	var saida := ""
	while s.length() > 3:
		saida = "." + s.right(3) + saida
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + saida


## Um dos quatro níveis de uma skill: paralelogramo com o corte do `Estilo` (o mesmo
## das barras do HUD). Aceso = cheio de dourado; apagado = só o contorno.
class Marcador extends Control:
	var _aceso := false

	func _init() -> void:
		custom_minimum_size = Vector2(22, 14)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func acender(ligado: bool) -> void:
		if ligado == _aceso:
			return
		_aceso = ligado
		queue_redraw()

	func aceso() -> bool:
		return _aceso

	func _draw() -> void:
		var inclinacao := 5.0
		var h := size.y
		var w := size.x - inclinacao
		var p := PackedVector2Array([Vector2(inclinacao, 0), Vector2(w + inclinacao, 0),
			Vector2(w, h), Vector2(0, h)])
		draw_colored_polygon(p, DOURADO if _aceso else Color(1, 1, 1, 0.05))
		var contorno := PackedVector2Array([p[0], p[1], p[2], p[3], p[0]])
		draw_polyline(contorno, DOURADO if _aceso else Color(TEXTO_3, 0.8), 1.5, true)
