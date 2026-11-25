extends MunicaoMinePiece
## FistEntity (Mine Piece v14) com DATA_move = −1 — o punho de fumaça do White Blow, na
## AIFistProcedure: 6 blocos/tick, cubo de 3 × tamanho × 1,25, 18 × CNT6, empurrão 1,0 + a
## metade da velocidade do punho; some com cnt1 > 15 ou cnt2 > 20. Rastro e estouro de nuvem.
const PASTA := "res://assets/mine_piece/frutas/moku/"
const FUMACA := PASTA + "particle_big_smoke.png"


func _configurar() -> void:
	largura_base = 0.7      # FIST: sized(0,7, 0,4)
	altura_base = 0.4
	velocidade = 6.0
	fator_alcance = 1.25
	dano_base = float(Balance.MINE_PIECE_MOKU.punho)
	empurrao = 1.0
	fator_extra = 0.5
	extra_pela_carga = false
	limite_cnt1 = 15
	limite_cnt2 = 20
	modelo = PASTA + "mp_punho.glb"
	grupo = "punho_moku_mine_piece"


func _alcance() -> float:
	return B.tamanho_municao(altura_b(), largura_b()) * fator_alcance


func _rastro(de: Vector3, _ate: Vector3) -> void:
	VfxFrutaMinePiece.particulas(self, FUMACA, 12, de, 2, Vector3.ONE * B.m(_alcance() * 0.5), 0.5, 0.6, 0.6)


## Estouro: nuvem e "explosion" do mod no ponto à frente (0,5 × alcance).
func _impacto(passo_b: Vector3) -> void:
	var alcance := _alcance()
	var onde := global_position + passo_b * B.m(0.5 * alcance)
	VfxFrutaMinePiece.particulas(self, FUMACA, 12, onde, int(round(4.0 * alcance)) + 2,
		Vector3.ONE * B.m(0.25 * alcance), 2.0, 0.7, 0.9)
	VfxGoroMinePiece.clarao(self, onde, B.m(alcance) * 0.6, 0.1)
