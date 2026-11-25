extends Node
# ============================================================================
#  DETECTOR DE ILHA (08/10/2026) — em qual ilha o jogador está.
#
#  A cada meio segundo, pela posição do jogador local e pelas placas do mapa
#  (`Ilhas.caixas`): marca `progressao.ilha` ("" no mar) e, quando ele PISA numa ilha
#  diferente da última, avisa (`chegou`). A primeira vez numa ilha a põe nas visitadas,
#  o que pode subir o teto de nível (Ilha dos Macacos: 20).
#  A ilha onde ele nasce não gera aviso.
# ============================================================================

signal chegou(ilha: String, primeira_vez: bool)
## A ilha em que o jogador está mudou (inclui a primeira, ao nascer). O mar não conta. Quem povoa a ilha ouve este.
signal ilha_atual(ilha: String)

const Ilhas := preload("res://src/historia/ilhas/ilhas.gd")
const INTERVALO := 0.5

var progressao: ProgressaoDoPersonagem
var jogador_de: Callable                 # → o jogador local (Node3D) ou null
var caixas := {}                         # id da ilha → Rect2 da placa
var _ultima := ""                        # última ilha pisada (o mar não conta)
var _relogio := 0.0


func ligar(mapa: Dictionary) -> void:
	caixas = Ilhas.caixas(mapa)


func _process(delta: float) -> void:
	_relogio -= delta
	if _relogio > 0.0:
		return
	_relogio = INTERVALO
	atualizar()


func atualizar() -> void:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if j == null or progressao == null:
		return
	var agora := Ilhas.ilha_em(caixas, j.global_position)
	progressao.ilha = agora
	if agora.is_empty() or agora == _ultima:
		return
	var nascendo := _ultima.is_empty()
	_ultima = agora
	ilha_atual.emit(agora)
	var primeira := progressao.visitar(agora)
	if not nascendo:
		chegou.emit(agora, primeira)
