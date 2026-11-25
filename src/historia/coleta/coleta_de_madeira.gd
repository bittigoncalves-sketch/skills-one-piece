extends Node
## Registro só no runtime: o editor continua editando os mesmos modelos e colisões.
signal madeira_coletada(quantidade: int)
const VEGETACAO := preload("res://src/historia/coleta/vegetacao_coletavel.gd")
var plantas: Array[Node] = []
var progressao: ProgressaoDoPersonagem
var pomar: PomarDaIlha

static func tipo_do_modelo(id: String, bib: BibliotecaDeModelos) -> String:
	if id.begins_with("floresta_bush_"): return "arbusto"
	if "stump" in id or "toco" in id or "cut" in id or "fallen" in id: return ""
	if "arvores" in bib.categorias_do_modelo(id) or id in ["trees", "pine_trees"] or id.begins_with("palm_tree"):
		return "arvore"
	return ""

func ligar(raiz: Node3D, mapa: Dictionary, bib: BibliotecaDeModelos, prog: ProgressaoDoPersonagem, frutas: PomarDaIlha = null) -> void:
	progressao = prog
	pomar = frutas
	for p: Dictionary in mapa.pecas:
		if p.tipo != "modelo": continue
		var tipo := tipo_do_modelo(p.modelo, bib)
		if tipo.is_empty(): continue
		var corpo := raiz.get_node_or_null(NodePath(p.id)) as StaticBody3D
		if corpo == null or corpo.has_meta("vegetacao_coletavel"): continue
		var planta := VEGETACAO.new()
		planta.name = "VegetacaoColetavel"
		corpo.add_child(planta)
		planta.preparar(corpo, p, tipo == "arbusto")
		planta.colhida.connect(_ao_colher.bind(p.id, tipo == "arvore"))
		planta.regenerou.connect(_ao_regenerar.bind(p.id))
		plantas.append(planta)

## Depois de uma ilha ser descarregada: as plantas eram filhas das peças e saíram com elas.
func podar() -> void:
	plantas.assign(plantas.filter(func(p: Node) -> bool: return is_instance_valid(p) and not p.is_queued_for_deletion()))


func _ao_colher(quantidade: int, id: String, arvore := false) -> void:
	if pomar != null: pomar.disponibilizar_arvore(id, false)
	progressao.ganhar_madeira(quantidade)
	if arvore: progressao.contar_abate("arvore_cortada")
	madeira_coletada.emit(quantidade)

func _ao_regenerar(id: String) -> void:
	if pomar != null: pomar.disponibilizar_arvore(id, true)
