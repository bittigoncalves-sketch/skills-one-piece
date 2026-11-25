class_name SessaoDeTecnicaMinePiece
extends Node
## Uma técnica EM CURSO de uma fruta "paralela" (ficha `"paralelo": true`).
##
## Por que existe: o controlador antigo tinha UM `ativo`/UM executor — enquanto uma técnica rodava,
## nenhuma outra começava (e a carga renovava a recarga global). Aqui cada tecla abre a sua sessão, com
## contadores, `segurando`, lentidão e recarga PRÓPRIOS; o controlador só soma o efeito no corpo.
##
## É a `c` que o executor enxerga: expõe a mesma superfície que ele usava no controlador
## (ator, tick, shift, imunidade, pe, olhar, pose, terminar, lentidao, recarga, recarga_total, segurando),
## então os executores traduzidos do mod (hie.gd…) não mudam de lógica.
## GATILHO: se um executor paralelo precisar de algo a mais do controlador (impulso, invisível), repassar aqui.
var ctl: ControladorFrutaMinePiece
var executor: Node
var numero := 0
var tecla := ""
var segurando := true
var lentidao := -1
var recarga := 0.0
var recarga_total := 0.0
var acabou := false
var acao_inicial := 0

var ator: Player:
	get:
		return ctl.ator
var tick: int:
	get:
		return ctl.tick
var shift: bool:
	get:
		return ctl.shift
var tras: bool:
	get:
		return ctl.tras
var imunidade: Dictionary:
	get:
		return ctl.imunidade
var toque: int:
	get:
		return ctl.toque


## Entidades que vivem além da técnica (lanças, pássaros) pertencem ao controlador, não à sessão.
func controlador() -> ControladorFrutaMinePiece:
	return ctl


func fruta_ativa() -> bool:
	return ctl.fruta_ativa()


func servidor() -> bool:
	return ctl.servidor()


func pe() -> Vector3:
	return ctl.pe()


func olhar() -> Vector3:
	return ctl.olhar()


func pose(nome: String, reiniciar := false) -> void:
	ctl.pose(nome, reiniciar)


func impulsionar(blocos_por_tick: Vector3) -> void:
	ctl.impulsionar(blocos_por_tick)


func invisivel(ligar: bool) -> void:
	ctl.invisivel(ligar)


func terminar() -> void:
	acabou = true
	segurando = false
	lentidao = -1


func passo() -> void:
	if not acabou:
		executor.passo()


func cancelar() -> void:
	if is_instance_valid(executor):
		executor.cancelar()
	terminar()
