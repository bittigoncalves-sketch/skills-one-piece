extends MunicaoMinePiece
## EntityPartisan e EntityBird (Mine Piece v14), as duas com a AIEntityBirdProcedure:
## lança 8 blocos/tick (some com cnt1 > 15 ou cnt2 > 10), pássaro 4 (cnt1 > 30, cnt2 > 20).
## Fere 15/20 × CNT6 com o efeito 12 (congela); congelar alguém a desfaz (Effect12).
const Gelo := preload("res://src/combat/frutas_mine_piece/gelo_hie.gd")
const PASTA := "res://assets/mine_piece/frutas/hie/"

var passaro := false


func _configurar() -> void:
	var ficha: Dictionary = Balance.MINE_PIECE_HIE
	# EntityType.sized: partisan 1,0 × 0,5; bird 3,0 × 2,4.
	largura_base = 3.0 if passaro else 1.0
	altura_base = 2.4 if passaro else 0.5
	velocidade = 4.0 if passaro else 8.0
	fator_alcance = 1.2
	dano_base = float(ficha.passaro if passaro else ficha.partisan)
	empurrao = 0.65
	fator_extra = 1.25 if passaro else 0.5
	mede_do_meio = passaro
	limite_cnt1 = 30 if passaro else 15
	limite_cnt2 = 20 if passaro else 10
	modelo = PASTA + ("mp_passaro.glb" if passaro else "mp_partisan.glb")
	grupo = "lanca_de_gelo_hie_mine_piece"


func _ataque(k6: float, t: float) -> MundoMinePiece.Ataque:
	var a := super(k6, t)
	a.ao_ferir = _congelar
	return a


## Effect12 com esta munição como atacante: congela e a munição some.
func _congelar(alvo: Node) -> void:
	Gelo.congelar(self, c.ator, alvo as Node3D, cnt6, altura_b(), largura_b())
	queue_free()


## BlockDestroyAllDirection vira gelo partido no lugar (sem quebrar o mapa), com o som e
## as partículas do mod.
func _impacto(passo_b: Vector3) -> void:
	var alcance := maxf(0.25 * largura_b(), 0.5)
	var onde := _ponto() + passo_b * B.m(0.5 * alcance)
	VfxFrutaMinePiece.particulas(self, PASTA + "particle_ice.png", 12, onde, int(round(6.0 * alcance)),
		Vector3.ONE * B.m(alcance), 0.2 * B.VELOCIDADE * 0.25)
	VfxGoroMinePiece.fumaca(self, onde, int(round(6.0 * alcance)), B.m(alcance), 1.0)
	VfxFrutaMinePiece.som(self, PASTA + "sons/hie_impacto.wav", onde, 2.0 * alcance, randf_range(0.85, 1.2))
