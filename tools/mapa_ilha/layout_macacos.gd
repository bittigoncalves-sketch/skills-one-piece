extends RefCounted
## Layout da Ilha dos Macacos v2 (22/11/2026) — a fonte única para os geradores
## (`gerar_ilha_dos_macacos.gd`, `gerar_floresta_macacos.gd`, `colocar_construcoes_macacos.gd`).
## Coordenadas LOCAIS à ilha (centro do mundo em (1500, 0)). Plano: docs/ILHA_DOS_MACACOS_V2_PLANO.md.

const CENTRO := Vector2(1500, 0)
const LARGURA_ESTRADA := 2.6            # metade da largura: a estrada tem 5,2 m

## Vila dos Macacos: praça plana.
const VILA := Vector2(-12, 4)
const VILA_RAIO_PLANO := 30.0
const VILA_ALTURA := 2.4
## Raio sem árvores em volta da vila.
const VILA_RAIO_LIVRE := 46.0

## Sítios planos: `centro`, `plano` (raio totalmente plano), `transicao` (raio até o relevo original),
## `altura` (-1 = a do relevo no centro), `solo` (código do solo do disco: 0 grama, 4 rocha...).
const SITIOS := {
	"bananal": {"centro": Vector2(-62, -40), "plano": 12.0, "transicao": 26.0, "altura": 3.6, "solo": 0},
	"curandeiro": {"centro": Vector2(-58, 56), "plano": 11.0, "transicao": 24.0, "altura": 3.6, "solo": 0},
	"totens": {"centro": Vector2(42, 78), "plano": 13.0, "transicao": 26.0, "altura": 4.6, "solo": 0},
	"trono": {"centro": Vector2(62, -60), "plano": 18.0, "transicao": 34.0, "altura": 10.0, "solo": 4},
}

## Estradas: pontos de controle (a curva passa por eles).
const ESTRADAS := {
	"cais": [Vector2(-128, 0), Vector2(-100, -5), Vector2(-72, 5), Vector2(-44, 0), Vector2(-12, 4)],
	"trono": [Vector2(-12, 4), Vector2(12, -8), Vector2(30, -24), Vector2(46, -42), Vector2(62, -60)],
	"bananal": [Vector2(-12, 4), Vector2(-30, -12), Vector2(-48, -28), Vector2(-62, -40)],
	"curandeiro": [Vector2(-12, 4), Vector2(-30, 22), Vector2(-46, 42), Vector2(-58, 56)],
	"totens": [Vector2(-12, 4), Vector2(8, 30), Vector2(26, 56), Vector2(42, 78)],
}


## O ponto `l` (local) está a menos de `folga` m de algum sítio, da vila ou de uma estrada (aproximada pelos pontos de controle)?
static func ocupado(l: Vector2, folga: float = 0.0) -> bool:
	if l.distance_to(VILA) < VILA_RAIO_LIVRE + folga:
		return true
	for nome in SITIOS:
		var s: Dictionary = SITIOS[nome]
		if l.distance_to(s["centro"]) < float(s["plano"]) + 8.0 + folga:
			return true
	return false
