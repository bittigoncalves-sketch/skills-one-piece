extends Node3D
# ============================================================================
#  MAR DO MODO HISTÓRIA — o que vive no mar, ligado num ponto só
#  (14/10/2026, docs/MAR_HISTORIA_PLANO.md). O `ModoHistoria` chama `montar` uma vez,
#  depois do `FundoDoMar`; cada etapa do plano entra AQUI, não no `ModoHistoria`:
#    caranguejos gigantes da fossa (15/10/2026) · E2 recifes · E3/E4 naufrágios e tesouro · E5 encontros com bestas · E6 cardumes ·
#    E7 visão submersa.
#  O relevo (`RelevoMarinho`) é o MESMO objeto dos fundos: fonte única de altura e
#  máscaras para tudo que é plantado no fundo.
# ============================================================================

const Recifes := preload("res://src/historia/mar/recifes.gd")
const Naufragios := preload("res://src/historia/mar/naufragios.gd")
const Encontros := preload("res://src/historia/mar/encontros_no_mar.gd")
const Cardumes := preload("res://src/historia/mar/cardumes.gd")
const CaranguejosGigantes := preload("res://src/historia/mar/caranguejos_gigantes.gd")
const VisaoSubmersa := preload("res://src/historia/mar/visao_submersa.gd")

var relevo: RelevoMarinho
var jogador_de: Callable
var recifes: Node3D
var naufragios: Node3D
var encontros: Node3D
var cardumes: Node3D
var caranguejos: Node3D
var visao: Node3D


## `contexto`: {"raiz": raiz do mapa montado, "mapa", "bib": BibliotecaDeModelos,
## "progressao", "hud", "navegacao": Callable → Navegacao, "ao_abater_besta": Callable}
## — um dicionário para a assinatura não mudar a cada etapa.
func montar(campo: RelevoMarinho, jogador: Callable, contexto: Dictionary = {}) -> void:
	relevo = campo
	jogador_de = jogador
	recifes = Recifes.new()
	recifes.name = "Recifes"
	add_child(recifes)
	recifes.configurar(relevo)
	naufragios = Naufragios.new()
	naufragios.name = "Naufragios"
	add_child(naufragios)
	naufragios.ligar(contexto, relevo, jogador_de)
	encontros = Encontros.new()
	encontros.name = "Encontros"
	add_child(encontros)
	encontros.ligar(contexto, relevo, jogador_de)
	cardumes = Cardumes.new()
	cardumes.name = "Cardumes"
	add_child(cardumes)
	cardumes.ligar(contexto, relevo, jogador_de)
	caranguejos = CaranguejosGigantes.new()
	caranguejos.name = "CaranguejosGigantes"
	add_child(caranguejos)
	caranguejos.ligar(contexto, relevo, jogador_de)
	# Por último: os outros já puseram seus nós no grupo "so_submerso".
	visao = VisaoSubmersa.new()
	visao.name = "VisaoSubmersa"
	add_child(visao)
	visao.ligar(relevo)


## F8 › "Besta do mar no barco": força um encontro com o barco pilotado.
func forcar_encontro() -> void:
	var motivo: String = encontros.forcar()
	if not motivo.is_empty() and encontros.hud != null:
		encontros.hud.avisar(motivo)
