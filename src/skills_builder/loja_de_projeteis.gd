extends VBoxContainer
## LOJA DE PROJÉTEIS — a grade da seção Projéteis do Skills Builder (06/10/2026).
##
## Pedido do dono: "adicionar uma loja de projéteis na aba de projéteis a serem disparados
## no editor". Decisão dele: os PRONTOS (forma + rastro + valores) e os modelos .glb da
## loja do editor. O clique avisa `escolheu(valores)`; quem grava na skill é o editor
## (`_aplicar_edicao`), então desfazer/refazer e a validação valem como em qualquer campo.
##
## O painel é refeito a cada edição do inspetor: as fotos são pedidas ao gerador do
## editor (`miniaturas`, que vive mais) e chegam pelo sinal `pronta`.

signal escolheu(valores: Dictionary)

const Catalogo = preload("res://src/skills_builder/catalogo_de_projeteis.gd")
const Estilo = preload("res://src/skills_builder/estilo_builder.gd")
const PASTA_FOTOS := "user://miniaturas_projeteis"
## Sobe quando o desenho de um pronto muda: a foto velha deixa de ser usada.
const VERSAO_DA_FOTO := 4
## Brilho aditivo some em fundo transparente: as fotos dos prontos usam fundo escuro.
const FUNDO_DA_FOTO := Color("222c39")
const MAX_MODELOS := 36
## O conteúdo do inspetor tem 256 px (painel de 286): 2 colunas de 124 px cabem sem
## alargar o painel nem apertar a prévia; 3 colunas cortavam "Bala de canhão".
const CARTAO := Vector2(124, 118)
const COLUNAS := 2
## Quanto do raio a foto enquadra (forma comprida precisa de mais).
const ENQUADRAR := {"Flecha": 3.6, "Kunai": 3.1, "Estaca de gelo": 2.5, "Bomba": 1.6}
## De onde a foto olha: de lado para ver o comprimento (a frente é −Z); a shuriken, que é
## deitada, de cima.
const VISTA_PADRAO := Vector3(1.0, 0.45, 0.25)
const VISTA := {"Shuriken": Vector3(0.45, 1.0, 0.35)}

var miniaturas: GeradorDeMiniaturas = null
var biblioteca: BibliotecaDeModelos = null
var forma_atual := ""
var modelo_atual := ""
var cor := Color.WHITE

var _grade_modelos: GridContainer
var _busca: LineEdit
var _categoria: OptionButton
var _aviso_modelos: Label
var _esperando := {}          # chave da foto -> botão


func montar() -> void:
	name = "LojaDeProjeteis"
	add_theme_constant_override("separation", 6)
	add_child(Estilo.rotulo("Loja de projéteis", 15))
	var dica := Estilo.rotulo("Clique para usar: a forma, o rastro e os valores vão para os campos abaixo. Modelos da loja trocam só a forma.", 12, true)
	dica.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dica.custom_minimum_size.x = 1
	add_child(dica)
	if miniaturas != null and not miniaturas.pronta.is_connected(_foto_pronta):
		miniaturas.pronta.connect(_foto_pronta)
	var grade := GridContainer.new()
	grade.name = "Prontos"
	grade.columns = COLUNAS
	add_child(grade)
	for forma: String in Catalogo.PRONTOS:
		var b := _cartao(forma, str(Catalogo.PRONTOS[forma].texto), forma == forma_atual)
		b.name = "Pronto_" + forma.validate_node_name().replace(" ", "_")
		b.pressed.connect(_usar_pronto.bind(forma))
		grade.add_child(b)
		_foto_do_pronto(forma, b)
	if biblioteca == null:
		return
	add_child(Estilo.rotulo("Modelos da loja do editor", 14))
	var filtro := HBoxContainer.new()
	add_child(filtro)
	_categoria = OptionButton.new()
	_categoria.name = "CategoriaDosModelos"
	_categoria.add_item("Todas")
	_categoria.set_item_metadata(0, "")
	for c: Dictionary in biblioteca.categorias():
		_categoria.add_item(str(c.nome))
		_categoria.set_item_metadata(_categoria.item_count - 1, str(c.id))
	_categoria.item_selected.connect(_listar_modelos.unbind(1))
	filtro.add_child(_categoria)
	_busca = LineEdit.new()
	_busca.name = "BuscaDeModelo"
	_busca.placeholder_text = "Buscar modelo"
	_busca.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_busca.text_changed.connect(_listar_modelos.unbind(1))
	filtro.add_child(_busca)
	_grade_modelos = GridContainer.new()
	_grade_modelos.name = "Modelos"
	_grade_modelos.columns = COLUNAS
	add_child(_grade_modelos)
	_aviso_modelos = Estilo.rotulo("", 11, true)
	add_child(_aviso_modelos)
	if forma_atual == Catalogo.MODELO and biblioteca.tem(modelo_atual):
		_busca.text = str(biblioteca.info(modelo_atual).get("nome", modelo_atual))
	_listar_modelos()


## Modelos da loja que casam com a categoria e a busca (no máximo MAX_MODELOS cartões).
func modelos_filtrados() -> Array[String]:
	var achados: Array[String] = []
	var termo := _busca.text.strip_edges().to_lower() if _busca != null else ""
	var cat := str(_categoria.get_item_metadata(_categoria.selected)) if _categoria != null else ""
	for id in biblioteca.ids():
		if not cat.is_empty() and not biblioteca.categorias_do_modelo(id).has(cat):
			continue
		var nome := str(biblioteca.info(id).get("nome", id))
		if termo.is_empty() or termo in nome.to_lower() or termo in id.to_lower():
			achados.append(id)
	return achados


func _listar_modelos() -> void:
	for filho in _grade_modelos.get_children():
		_grade_modelos.remove_child(filho)
		filho.queue_free()
	var achados := modelos_filtrados()
	for id in achados.slice(0, MAX_MODELOS):
		var nome := str(biblioteca.info(id).get("nome", id))
		var b := _cartao(nome, id, forma_atual == Catalogo.MODELO and id == modelo_atual)
		b.name = "Modelo_" + id
		b.pressed.connect(_usar_modelo.bind(id))
		_grade_modelos.add_child(b)
		if miniaturas != null:
			var foto := miniaturas.em_cache(id)
			if foto != null:
				b.icon = foto
			else:
				_esperando[id] = b
				miniaturas.pedir(id)
	_aviso_modelos.text = "%d modelo%s" % [achados.size(), "" if achados.size() == 1 else "s"] \
		+ (" — mostrando %d; refine a busca" % MAX_MODELOS if achados.size() > MAX_MODELOS else "")


func _usar_pronto(forma: String) -> void:
	escolheu.emit(Catalogo.valores_do_pronto(forma))


func _usar_modelo(id: String) -> void:
	escolheu.emit(Catalogo.valores_do_modelo(id))


func _cartao(texto: String, dica: String, ativo: bool) -> Button:
	var b := Button.new()
	b.text = texto
	b.tooltip_text = dica
	b.toggle_mode = true
	b.set_pressed_no_signal(ativo)
	b.custom_minimum_size = CARTAO
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.clip_text = true
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_stylebox_override("normal", Estilo.caixa(Estilo.CAMPO, 4))
	b.add_theme_stylebox_override("hover", Estilo.caixa(Estilo.PAINEL, 4))
	var marcado := Estilo.caixa(Estilo.PAINEL, 4)
	marcado.border_color = Estilo.ACENTO
	marcado.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", marcado)
	b.add_theme_stylebox_override("hover_pressed", marcado)
	return b


func _foto_do_pronto(forma: String, botao: Button) -> void:
	if miniaturas == null:
		return
	var caminho := PASTA_FOTOS.path_join("%s-%s-v%d.png" % [forma.validate_filename().replace(" ", "_"), cor.to_html(false), VERSAO_DA_FOTO])
	var foto := miniaturas.foto_salva(caminho)
	if foto != null:
		botao.icon = foto
		return
	var valores := Catalogo.valores_do_pronto(forma)
	var raio := float(valores.raio) * float(ENQUADRAR.get(forma, 1.3))
	var chave := "projetil:" + caminho
	_esperando[chave] = botao
	miniaturas.pedir_cena(chave, Callable(Catalogo, "criar").bind(valores, cor), Vector3.ZERO, raio, caminho,
		VISTA.get(forma, VISTA_PADRAO), FUNDO_DA_FOTO, true)


func _foto_pronta(chave: String, foto: Texture2D) -> void:
	var b: Variant = _esperando.get(chave)
	_esperando.erase(chave)
	if is_instance_valid(b):
		(b as Button).icon = foto
