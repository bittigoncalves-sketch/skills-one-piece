class_name ChaveDePose
extends Resource
# ============================================================================
#  UMA POSE-CHAVE do combate direcional — um instante de um golpe (ou a guarda,
#  ou uma reação), escrito como DADO.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D7; decisão do dono de 16/09: poses como
#  dados agora, estúdio de animação depois pelo mesmo contrato).
#
#  --------------------------------------------------------- DUAS LINGUAGENS
#  • MÃOS por ALVO: onde o punho (nó `Wrist_*`) deve estar, no espaço do CORPO
#    (metros; origem nos pés; frente = −Z, +X = direita do personagem). Resolvido
#    por IK de dois ossos a cada quadro. O ponto de contato do soco vira um número
#    que se lê e se mede — e a hitbox bate com a pose por construção.
#  • PÉS por ALVO também: onde o tornozelo (nó `Foot_*`) fica, no mesmo espaço, e para
#    onde o joelho aponta; mais o deslocamento do QUADRIL (nó `Torso`). É o que deixa
#    o pé de apoio plantado enquanto o quadril desce e gira — rotação de coxa somada
#    não segura pé no chão.
#  • O RESTO por ROTAÇÃO: coluna, quadril, cabeça, antepé, dedos. Graus somados ao
#    repouso (todos os papéis do `base_v2` têm repouso zero — medido em 16/09).
#    Exceção declarada: com pés por alvo, `Foot_*` é a orientação do pé em relação ao
#    CORPO (não à canela) — `y` abre a ponta, `x` negativo tira o calcanhar do chão.
#    Convenção dos eixos do jogo: `x` leva a ponta de um membro que APONTA PARA
#    BAIXO para a frente (e a de um que aponta para cima, para trás); `y` positivo
#    leva o lado +X (ombro direito) para a frente; `z` positivo sobe o lado +X.
#
#  ⚠️ Padrões NEUTROS, como em `golpe_direcional.gd`: o Godot não grava no `.tres`
#  campo igual ao padrão, e número de pose escondido no código é o que se quer evitar.
# ============================================================================

enum Curva {
	SUAVE,       ## começa e termina devagar (smoothstep)
	ACELERA,     ## sai devagar e chega rápido — a chegada no contato
	DESACELERA,  ## sai rápido e chega devagar — o follow-through perdendo força
	LINEAR,
}

## Em que fase do golpe esta chave mora. Ignorado na guarda e nas reações.
@export var fase: GolpeDirecional.Fase = GolpeDirecional.Fase.PREPARO
## Posição dentro da fase: 0 = começo, 1 = fim.
@export_range(0.0, 1.0, 0.01) var fracao := 0.0
## Como o trecho que CHEGA nesta chave distribui o movimento no tempo.
@export var curva: Curva = Curva.SUAVE

@export_group("Mãos (alvo do punho, espaço do corpo, metros)")
@export var usa_mao_direita := false
@export var mao_direita := Vector3.ZERO
## Para onde o cotovelo aponta (direção no espaço do corpo). Decide o plano do braço.
@export var cotovelo_direito := Vector3.ZERO
@export var usa_mao_esquerda := false
@export var mao_esquerda := Vector3.ZERO
@export var cotovelo_esquerdo := Vector3.ZERO

@export_group("Pés e quadril (alvo do tornozelo, espaço do corpo, metros)")
@export var usa_pes := false
@export var pe_direito := Vector3.ZERO
## Para onde o joelho aponta (direção no espaço do corpo). Decide o plano da perna.
@export var joelho_direito := Vector3.ZERO
@export var pe_esquerdo := Vector3.ZERO
@export var joelho_esquerdo := Vector3.ZERO
## Deslocamento do quadril sobre o repouso (y negativo = joelhos dobram).
@export var quadril := Vector3.ZERO

@export_group("Rotações (graus, sobre o repouso)")
## papel (String, ex. "SpineMid") → Vector3 em graus.
@export var rotacoes: Dictionary = {}


## Instante desta chave dentro de um golpe, em segundos.
func tempo_em(golpe: GolpeDirecional) -> float:
	match fase:
		GolpeDirecional.Fase.PREPARO:
			return golpe.preparo * fracao
		GolpeDirecional.Fase.ATIVO:
			return golpe.preparo + golpe.ativo * fracao
		GolpeDirecional.Fase.RECUPERACAO:
			return golpe.preparo + golpe.ativo + golpe.recuperacao * fracao
	return golpe.duracao()


## `curva_id` é um `Curva` (recebido como int para servir a dados lidos de array).
static func aplicar_curva(curva_id: int, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	match curva_id:
		Curva.ACELERA:
			return u * u * u
		Curva.DESACELERA:
			var v := 1.0 - u
			return 1.0 - v * v * v
		Curva.LINEAR:
			return u
	return u * u * (3.0 - 2.0 * u)


func validar(rotulo: String) -> PackedStringArray:
	var erros := PackedStringArray()
	if fase == GolpeDirecional.Fase.FIM:
		erros.append("%s: chave na fase FIM (o fim é sempre a guarda)" % rotulo)
	if usa_mao_direita and cotovelo_direito == Vector3.ZERO:
		erros.append("%s: mão direita sem direção de cotovelo" % rotulo)
	if usa_mao_esquerda and cotovelo_esquerdo == Vector3.ZERO:
		erros.append("%s: mão esquerda sem direção de cotovelo" % rotulo)
	if usa_pes and (joelho_direito == Vector3.ZERO or joelho_esquerdo == Vector3.ZERO):
		erros.append("%s: pés sem direção de joelho" % rotulo)
	for papel in rotacoes:
		if not (rotacoes[papel] is Vector3):
			erros.append("%s: rotação de %s não é Vector3" % [rotulo, papel])
	return erros
