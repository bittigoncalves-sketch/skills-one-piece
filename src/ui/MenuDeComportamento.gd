class_name MenuDeComportamento
extends PanelContainer
## A aba PETS da central do M (era a tecla B): a central da tripulação. O nome da classe conserva referências/layouts antigos.
signal escolheu(pet: Node, modo: StringName)
const ID_DO_LAYOUT := "pets"
const P := preload("res://src/historia/tripulantes/provisoes.gd")
const Celula := preload("res://src/ui/celula_tripulacao.gd")
var pet: Node
var progressao: ProgressaoDoPersonagem
var sistema: Node
var _coluna: VBoxContainer
var _lista: VBoxContainer
var _vagas: HBoxContainer
var _resumo: Label
var _deposito: SpinBox
var _selecionado := ""
var _linhas := {}
var _tempo := 0.0
## Hospedado pela `CentralDeJanelas` (ver `embutir`).
var embutido := false
var _cabeca: Control

func _ready() -> void:
	add_theme_stylebox_override("panel", EstiloDaHistoria.painel())
	custom_minimum_size = Vector2(900, 0)
	_coluna = VBoxContainer.new()
	_coluna.add_theme_constant_override("separation", 10)
	add_child(_coluna)
	_cabeca = EstiloDaHistoria.cabeca("TRIPULAÇÃO", ["M", "ESC"] as Array[String])
	_coluna.add_child(_cabeca)
	_resumo = EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 16)
	_coluna.add_child(_resumo)
	_vagas = HBoxContainer.new()
	_vagas.add_theme_constant_override("separation", 8)
	_coluna.add_child(_vagas)
	_coluna.add_child(EstiloDaHistoria.rotulo("Arraste um membro para um cargo. Ou selecione na lista e clique no +. Clique em um cargo ocupado para recolher.", EstiloDaHistoria.TEXTO_2, 12))
	var suprimentos := HFlowContainer.new()
	_coluna.add_child(suprimentos)
	for id in P.ITENS:
		var item := str(id)
		suprimentos.add_child(EstiloDaHistoria.botao("Consumir " + str(P.ITENS[id].nome), func(): P.consumir(progressao, item)))
	_deposito = SpinBox.new()
	_deposito.min_value = 1
	_deposito.max_value = 1000000
	_deposito.value = 20
	_deposito.custom_minimum_size.x = 100
	suprimentos.add_child(_deposito)
	suprimentos.add_child(EstiloDaHistoria.botao("Depositar", func(): P.depositar(progressao, int(_deposito.value))))
	var comandos := HBoxContainer.new()
	_coluna.add_child(comandos)
	comandos.add_child(EstiloDaHistoria.rotulo("Comandante", EstiloDaHistoria.TEXTO_2, 14))
	var alinhamento := OptionButton.new()
	for a in ["Amigável", "Neutro", "Maligno"]: alinhamento.add_item(a)
	alinhamento.select(1)
	alinhamento.item_selected.connect(func(i: int):
		P.estado(progressao).alinhamento = ["amigavel", "neutro", "maligno"][i]
		progressao.mudou.emit())
	alinhamento.name = "Alinhamento"
	comandos.add_child(alinhamento)
	var politica := OptionButton.new()
	for a in ["Roubar NPCs", "Matar NPCs", "Escravizar NPCs"]: politica.add_item(a)
	politica.item_selected.connect(func(i: int):
		P.estado(progressao).politica = ["roubar", "matar", "escravizar"][i]
		progressao.mudou.emit())
	politica.name = "Politica"
	comandos.add_child(politica)
	comandos.add_child(EstiloDaHistoria.rotulo("Sem comandante: defender. Amigável: acompanhar. Neutro: combater inimigos.", EstiloDaHistoria.TEXTO_3, 12))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 250
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_coluna.add_child(scroll)
	_lista = VBoxContainer.new()
	_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lista)

func ligar(prog: ProgressaoDoPersonagem, controle: Node) -> void:
	progressao = prog
	sistema = controle
	prog.mudou.connect(func(): atualizar.call_deferred())

func abrir_tripulacao() -> void:
	visible = true
	atualizar()
	if embutido:
		return
	reset_size()
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	# Em janela pequena a UI inteira continua acessível, sem recortar as seis vagas.
	scale = Vector2.ONE * minf(1, (get_viewport_rect().size.x - 24) / 900)

## A central dá moldura, título (as abas), tamanho e posição; fica só a margem do conteúdo.
func embutir() -> void:
	embutido = true
	var st := StyleBoxEmpty.new()
	st.content_margin_left = 24
	st.content_margin_right = 24
	st.content_margin_top = 14
	st.content_margin_bottom = 20
	add_theme_stylebox_override("panel", st)
	custom_minimum_size = Vector2.ZERO
	_cabeca.visible = false


func abrir(alvo: Node) -> void:
	pet = alvo
	abrir_tripulacao()

func escolher(indice: int) -> void:
	if is_instance_valid(pet) and indice >= 0 and indice < ModoDoPet.ORDEM.size():
		pet.call("definir_modo", ModoDoPet.ORDEM[indice])
		escolheu.emit(pet, ModoDoPet.ORDEM[indice])

func _limpar(no: Node) -> void:
	for c in no.get_children():
		no.remove_child(c)
		c.queue_free()

func atualizar() -> void:
	if not visible or progressao == null or _lista == null: return
	var d := P.estado(progressao)
	_limpar(_lista)
	_limpar(_vagas)
	_linhas.clear()
	var alinhamento := find_child("Alinhamento", true, false) as OptionButton
	alinhamento.select(maxi(0, ["amigavel", "neutro", "maligno"].find(d.alinhamento)))
	var politica := find_child("Politica", true, false) as OptionButton
	politica.select(maxi(0, ["roubar", "matar", "escravizar"].find(d.get("politica", "roubar"))))
	for i in P.CARGOS.size():
		var coluna := VBoxContainer.new()
		coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_vagas.add_child(coluna)
		var cargo := EstiloDaHistoria.rotulo(P.CARGOS[i], EstiloDaHistoria.TEXTO, 13)
		cargo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		coluna.add_child(cargo)
		var b := Celula.new()
		b.aceita = true
		b.custom_minimum_size = Vector2(136, 88)
		b.membro_id = str(d.vagas[i])
		b.text = "+" if b.membro_id.is_empty() else _nome(b.membro_id)
		b.add_theme_font_size_override("font_size", 36 if b.membro_id.is_empty() else 16)
		for cor in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: b.add_theme_color_override(cor, Color.BLACK)
		var estilo := StyleBoxFlat.new()
		estilo.bg_color = Color(0.57, 0.59, 0.61)
		for estado in ["normal", "hover", "pressed", "focus"]: b.add_theme_stylebox_override(estado, estilo)
		coluna.add_child(b)
		b.recebeu.connect(func(id: String): P.atribuir(progressao, id, i))
		b.pressed.connect(func():
			if not _selecionado.is_empty():
				P.atribuir(progressao, _selecionado, i)
				_selecionado = ""
			else:
				d.vagas[i] = ""
				progressao.mudou.emit())
	for id in d.membros:
		var membro := str(id)
		var linha := HBoxContainer.new()
		_lista.add_child(linha)
		var b := Celula.new()
		b.membro_id = membro
		b.text = _nome(membro)
		b.custom_minimum_size.x = 160
		b.pressed.connect(func(): _selecionado = membro; _resumo.text = "Selecionado: %s. Clique no + do cargo." % _nome(membro))
		linha.add_child(b)
		var status := EstiloDaHistoria.rotulo("", EstiloDaHistoria.TEXTO, 14)
		status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linha.add_child(status)
		_linhas[membro] = status
		if not Tripulacao.e_humano(membro):
			var modos := OptionButton.new()
			for m in ModoDoPet.ORDEM: modos.add_item(ModoDoPet.nome(m))
			modos.select(maxi(0, ModoDoPet.ORDEM.find(progressao.modo_do_pet(membro))))
			modos.disabled = P.tem_cargo(progressao, 4)
			modos.item_selected.connect(func(i: int):
				progressao.definir_modo_do_pet(membro, ModoDoPet.ORDEM[i])
				var corpo: Node = sistema.corpos.get(membro) if is_instance_valid(sistema) else null
				if is_instance_valid(corpo): corpo.call("definir_modo", ModoDoPet.ORDEM[i]))
			linha.add_child(modos)
		linha.add_child(EstiloDaHistoria.botao("Remover", func():
			for v in d.vagas.size():
				if d.vagas[v] == membro: d.vagas[v] = ""
			d.historico_membros[membro] = d.membros[membro].duplicate(true)
			d.membros.erase(membro)
			progressao.mudou.emit()))
	_lista.add_child(EstiloDaHistoria.rotulo("Disponíveis para entrar na tripulação", EstiloDaHistoria.DOURADO, 14))
	for a in Tripulacao.disponiveis(progressao):
		if d.membros.has(a.id): continue
		var id := str(a.id)
		var b := EstiloDaHistoria.botao("+ " + str(a.nome), func(): P.adicionar(progressao, id))
		b.disabled = d.membros.size() >= P.MAX_MEMBROS
		_lista.add_child(b)
	_atualizar_status()

func _process(delta: float) -> void:
	_tempo += delta
	if visible and _tempo >= 0.25:
		_tempo = 0
		_atualizar_status()

## "Pão 2 · Maçã 1 · Água potável 5": só o que há no estoque (a lista cresce com `Provisoes.ITENS`).
func _estoque_em_texto(d: Dictionary) -> String:
	var partes: PackedStringArray = []
	for id in P.ITENS:
		var n := int(d.estoque.get(id, 0))
		if n > 0: partes.append("%s %d" % [P.ITENS[id].nome, n])
	return " · ".join(partes) if not partes.is_empty() else "Sem provisões no estoque"

func _atualizar_status() -> void:
	if progressao == null: return
	var d := P.estado(progressao)
	var necessidade: Dictionary = sistema.necessidades() if is_instance_valid(sistema) else {"total": 0}
	_resumo.text = "%d/16 membros · Fome %d/200 · Sede %d/300 · %d moedas · Reserva %d · Necessidade %d\n%s" % [d.membros.size(), ceili(d.fome), ceili(d.sede), progressao.ouro, d.reserva, necessidade.total, _estoque_em_texto(d)]
	for id in _linhas:
		if not d.membros.has(id): continue
		var m: Dictionary = d.membros[id]
		_linhas[id].text = "%s · Vida %d/%d" % ["Morto" if bool(m.get("morto", false)) else ("Ativo" if d.vagas.has(id) else "Reserva"), ceili(m.vida), ceili(m.vida_max)]

func _nome(id: String) -> String:
	return str(Tripulacao.aliado(progressao, null, id).get("nome", id))
