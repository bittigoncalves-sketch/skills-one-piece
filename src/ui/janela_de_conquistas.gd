class_name JanelaDeConquistas
extends VBoxContainer
## JANELA DE CONQUISTAS. As 123 conquistas do Mine Piece (09/11/2026, item 10 da auditoria) eram concedidas e travavam golpes, mas o jogador não via nenhuma;
## desde 11/11/2026 a aba mostra a ÁRVORE DE RAÍZES (`ArvoreDeConquistas`): o caminho entre as conquistas, a dificuldade em cor e forma, o que já foi
## aceso. Aqui só moram o cabeçalho (total feito) e os botões da vista. Só LÊ: o estado é `ProgressaoDoPersonagem.conquistas_mod` ({id: [critérios
## feitos]}) e as definições são `McConquistas`. As de gatilho `tick` (concedidas sozinhas, sem aviso) não contam no total: não são conquistas que o jogador "faz".

var progressao: ProgressaoDoPersonagem
var arvore: ArvoreDeConquistas
var _cabecalho: Label


func ligar(prog: ProgressaoDoPersonagem) -> void:
	progressao = prog
	if is_node_ready():
		_ligar_progressao()


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	var topo := HBoxContainer.new()
	topo.add_theme_constant_override("separation", 8)
	add_child(topo)
	_cabecalho = EstiloDaHistoria.rotulo("", EstiloDaHistoria.DOURADO, 18)
	_cabecalho.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topo.add_child(_cabecalho)
	arvore = ArvoreDeConquistas.new()
	arvore.name = "Arvore"
	for par in [["Ver tudo", func(): arvore.ver_tudo()], ["Centralizar", func(): arvore.centralizar()]]:
		var b := Button.new()
		b.text = par[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(par[1])
		topo.add_child(b)
	add_child(arvore)
	if progressao != null:
		_ligar_progressao()


func _ligar_progressao() -> void:
	arvore.ligar(progressao)
	if not progressao.mudou.is_connected(_ao_mudar):
		progressao.mudou.connect(_ao_mudar)
	atualizar()


func _ao_mudar() -> void:
	if is_visible_in_tree():
		atualizar()


## Conquistas que o jogador faz: definidas, com título e que não são as automáticas do primeiro tick.
static func visiveis() -> Array:
	var saida := []
	for id: String in McConquistas.definicoes():
		var d: Variant = McConquistas.definicoes()[id]
		if d != null and d.titulo != "" and d.gatilho != "tick":
			saida.append(d)
	return saida


static func feita(prog: ProgressaoDoPersonagem, d) -> bool:
	if prog == null:
		return false
	var feitos: Array = prog.conquistas_mod.get(d.id, [])
	return not d.criterios.is_empty() and d.criterios.all(func(c): return feitos.has(c))


func atualizar() -> void:
	if arvore == null:
		return
	arvore.atualizar()
	var todas := visiveis()
	var feitas := todas.filter(func(d): return feita(progressao, d))
	_cabecalho.text = "CONQUISTAS  ·  %d / %d" % [feitas.size(), todas.size()]
