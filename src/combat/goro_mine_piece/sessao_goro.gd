class_name SessaoGoroMinePiece
extends RefCounted
## Uma técnica EM CURSO da Goro Goro (Mine Piece). Refatoração de 24/11/2026: o controlador tinha um único
## `D` (o `skill`/`cnt*` do mod), então uma técnica travava as outras. Agora cada técnica tem o seu `D`, o seu
## `TecnicasGoroMinePiece` e o seu `z` (tecla segurada); o controlador só soma o efeito no corpo.
##
## É a `c` que `TecnicasGoroMinePiece` enxerga: o que é do corpo/mira/efeitos repassa ao controlador; o que é
## estado da técnica (`D`, `z`, `encerrar`) é daqui. A Mamaragan/tempestade segue no `tecnicas` do controlador.
const B := preload("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")

var ctl: GoroGoroMinePiece
var D := {"skill": 0}
var numero := 0
var z := true            # a tecla desta técnica segurada
var tecnicas: TecnicasGoroMinePiece

var r: float:
	get:
		return ctl.r
var s: bool:
	get:
		return ctl.s
var shift: bool:
	get:
		return ctl.shift
var ator: Player:
	get:
		return ctl.ator


func _init(controlador: GoroGoroMinePiece, numero_da_tecnica: int, extra := {}) -> void:
	ctl = controlador
	numero = numero_da_tecnica
	D = {"skill": numero_da_tecnica}
	D.merge(extra)
	tecnicas = TecnicasGoroMinePiece.new(self)


func ativa() -> bool:
	return int(D.skill) != 0


func passo() -> void:
	if ativa():
		tecnicas.executar(int(D.skill))


func encerrar() -> void:
	D = {"skill": 0}


# ---- o corpo, a mira e os efeitos são do controlador
func pe() -> Vector3:
	return ctl.pe()

func olhar(com_pitch := true) -> Vector3:
	return ctl.olhar(com_pitch)

func frente(blocos: float, altura: float, com_pitch := true, giro := 0.0) -> Vector3:
	return ctl.frente(blocos, altura, com_pitch, giro)

func alvo_na_mira(passos: int, passo_b: float, lado_b: float) -> Vector3:
	return ctl.alvo_na_mira(passos, passo_b, lado_b)

func chao_da_coluna(topo: Vector3, lado_b: float, maximo: float) -> float:
	return ctl.chao_da_coluna(topo, lado_b, maximo)

func solido(onde: Vector3, altura_b := B.ALTURA_JOGADOR, largura_b := B.LARGURA_JOGADOR) -> bool:
	return ctl.solido(onde, altura_b, largura_b)

func teleportar(novo_pe: Vector3) -> void:
	ctl.teleportar(novo_pe)

func atacar(centro: Vector3, a: MundoMinePiece.Ataque, origem: Variant = null) -> int:
	return ctl.atacar(centro, a, origem)

func travar() -> void:
	ctl.travar()

func parar() -> void:
	ctl.parar()

func invisivel(segundos: float) -> void:
	ctl.invisivel(segundos)

func criar_onda(onde: Vector3, cnt6: float) -> void:
	ctl.criar_onda(onde, cnt6)

func criar_meteoro(base: Vector3) -> void:
	ctl.criar_meteoro(base)

func pose(nome: String) -> void:
	ctl.pose(nome)

func iniciar_mamaragan() -> void:
	ctl.iniciar_mamaragan()

func fx_faiscas(onde: Vector3, n: int, espalhar: float, vel := 2.0) -> void:
	ctl.fx_faiscas(onde, n, espalhar, vel)

func fx_fumaca(onde: Vector3, n: int, espalhar: float, vel := 1.0) -> void:
	ctl.fx_fumaca(onde, n, espalhar, vel)

func fx_clarao(onde: Vector3, raio: float, duracao := 0.15) -> void:
	ctl.fx_clarao(onde, raio, duracao)

func fx_som(onde: Vector3, nome: String, volume := -6.0) -> void:
	ctl.fx_som(onde, nome, volume)

func fx_marca(onde: Vector3, raio: float) -> void:
	ctl.fx_marca(onde, raio)

func fx_raio(pontos: PackedVector3Array, largura: float) -> void:
	ctl.fx_raio(pontos, largura)

func fx_relampago(de_p: Vector3, ate: Vector3) -> void:
	ctl.fx_relampago(de_p, ate)

func fx_feixe(de_p: Vector3, ate: Vector3, largura: float) -> void:
	ctl.fx_feixe(de_p, ate, largura)

func fx_descarga(centro: Vector3, raio: float) -> void:
	ctl.fx_descarga(centro, raio)

func fx_raio_do_ceu(onde: Vector3) -> void:
	ctl.fx_raio_do_ceu(onde)
