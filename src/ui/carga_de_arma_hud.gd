class_name CargaDeArmaHud
extends Control
## BARRA DA HABILIDADE INATA da arma do Epic Fight (12/11/2026): a carga (soma do dano dos golpes que acertam) até o `consumption` da habilidade (`HabilidadesDeArma`).
## Só aparece com uma arma do mod na mão que tenha habilidade. Cheia, o rótulo avisa a tecla R. Lê `EspadaDaHistoria` do jogador por grupo (sem sinal: uma barra só, leitura barata).
const LARGURA := 300.0
const ALTURA := 16.0

var _barra: BarraHud
var _rotulo: Label
var _ultimo := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(64.0, 118.0)
	size = Vector2(LARGURA, ALTURA + 18.0)
	_barra = BarraHud.new()
	_barra.cor = Color(0.95, 0.65, 0.2)
	_barra.position = Vector2(0.0, 18.0)
	_barra.size = Vector2(LARGURA, ALTURA)
	add_child(_barra)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 16)
	_rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rotulo)
	visible = false


func _process(_d: float) -> void:
	var j := get_tree().get_first_node_in_group("player")
	var arma := j.get_node_or_null("EspadaDaHistoria") if j != null else null
	if arma == null or arma.lamina_ef == "" or arma.carga_max <= 0.0:
		visible = false
		return
	visible = true
	var f: float = arma.carga / arma.carga_max
	if is_equal_approx(f, _ultimo) and not arma.modo_ativo():
		return
	_ultimo = f
	_barra.valor(f)
	_barra.cor = Color(0.4, 1.0, 0.5) if arma.carga_cheia() else Color(0.95, 0.65, 0.2)
	var nome := str(arma.habilidade.get("nome", ""))
	if arma.modo_ativo():
		_rotulo.text = "%s  ·  ATIVA" % nome
	elif arma.carga_cheia():
		_rotulo.text = "%s  ·  PRONTA  [R]" % nome
	else:
		_rotulo.text = "%s  ·  %d / %d" % [nome, int(arma.carga), int(arma.carga_max)]
