class_name ResolucaoDeContato
extends RefCounted
# ============================================================================
#  RESOLUÇÃO DE CONTATO — o que um golpe que tocou um corpo VIRA.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D6). Funções PURAS: recebem geometria e
#  estado, devolvem uma decisão. Quem aplica dano, reação e efeito é o executor.
#
#  A defesa é resolvida AQUI, ANTES do dano — e não dentro da `DamageZone` ou do
#  `CombatResolver`: aqueles servem a arena e as frutas, e um bloqueio decidido
#  depois do dano ainda contaria como acerto (derrubada gravada, `hit_landed`).
#  Acerto, bloqueio e quebra de guarda desde a Fase 4; aparo desde a Fase 5.
#  Contra-ataque e choque ficam reservados (V2/V3).
# ============================================================================

enum Resultado { ACERTO, BLOQUEIO, APARO, QUEBRA_DE_GUARDA }

## De que lado o DEFENSOR foi atingido, no corpo dele.
enum Lado { FRENTE, ESQUERDA, DIREITA, COSTAS }

## Atacante a mais que isto atrás do defensor (cosseno) = golpe pelas costas.
const COSSENO_COSTAS := -0.35
## Movimento lateral pelo menos esta fração do frontal = golpe de lado.
const DOMINANCIA_LATERAL := 0.7


## O lado do impacto, pela GEOMETRIA — nunca pelo nome do golpe.
##
## `viagem` é para onde o efetor andava no instante do contato (mundo). Um golpe
## que viaja para a DIREITA do defensor veio da ESQUERDA dele. O nome do golpe não
## entra na conta de propósito: "golpe esquerdo" já significou origem e destino
## neste projeto, e só o vetor não tem essa ambiguidade.
##
## `base_defensor` é a base SEM escala do corpo visível do defensor (frente = −Z).
static func lado_do_impacto(viagem: Vector3, pos_atacante: Vector3, pos_defensor: Vector3,
		base_defensor: Basis) -> Lado:
	var para_atacante := base_defensor.inverse() * (pos_atacante - pos_defensor)
	para_atacante.y = 0.0
	# Frente do defensor é −Z: atacante em +Z local está atrás.
	if para_atacante.length_squared() > 0.0001 and -para_atacante.normalized().z < COSSENO_COSTAS:
		return Lado.COSTAS
	var local := base_defensor.inverse() * viagem
	local.y = 0.0
	if absf(local.x) >= absf(local.z) * DOMINANCIA_LATERAL and absf(local.x) > 0.0001:
		return Lado.ESQUERDA if local.x > 0.0 else Lado.DIREITA
	return Lado.FRENTE


## O atacante está dentro da guarda do defensor? Cone de `cone_graus` centrado na
## frente dele (−Z), medido no plano do chão.
static func no_cone(pos_atacante: Vector3, pos_defensor: Vector3, base_defensor: Basis, cone_graus: float) -> bool:
	var local := base_defensor.inverse() * (pos_atacante - pos_defensor)
	local.y = 0.0
	if local.length_squared() < 0.0001:
		return true   # colado no corpo: sem direção para julgar, a guarda vale
	return -local.normalized().z >= cos(deg_to_rad(cone_graus) * 0.5)


## O que o contato vira — função PURA (sem nó), para o teste cobrir a tabela inteira.
##   sem guarda ou fora do cone ............ ACERTO
##   na janela de aparo, golpe aparável .... APARO (a postura nem entra na conta)
##   na guarda, postura aguenta ............ BLOQUEIO
##   na guarda, postura não aguenta ........ QUEBRA_DE_GUARDA
static func resolver(golpe: GolpeDirecional, pos_atacante: Vector3, em_guarda: bool, aparando: bool,
		postura: float, cone_graus: float, pos_defensor: Vector3, base_defensor: Basis) -> Resultado:
	if not em_guarda or not no_cone(pos_atacante, pos_defensor, base_defensor, cone_graus):
		return Resultado.ACERTO
	if aparando and golpe.aparavel:
		return Resultado.APARO
	if postura - golpe.dano_de_postura <= 0.0:
		return Resultado.QUEBRA_DE_GUARDA
	return Resultado.BLOQUEIO


## Atalho que lê o estado do defensor. `defensor` nulo (alvo sem combate direcional,
## como o inimigo estático do mapa) é sempre acerto.
## TÉCNICA DE FRUTA contra a guarda (22/09/2026). Não existe APARO contra técnica
## (decisão do dono, 21/09): o que decide é o cone da guarda e a postura. Quem chama
## reduz o dano quando o resultado é BLOQUEIO — a técnica não some, ela é segurada.
static func resolver_tecnica(pos_da_explosao: Vector3, defensor: ExecutorCorpoACorpo,
		dano_de_postura: float) -> Resultado:
	if defensor == null or defensor.ator == null or defensor.estilo == null:
		return Resultado.ACERTO
	var corpo := defensor.ator.corpo()
	if corpo == null or not defensor.em_guarda():
		return Resultado.ACERTO
	if not no_cone(pos_da_explosao, corpo.global_position, defensor.ator.base_do_corpo(),
			defensor.estilo.cone_da_guarda):
		return Resultado.ACERTO
	if defensor.postura - dano_de_postura <= 0.0:
		return Resultado.QUEBRA_DE_GUARDA
	return Resultado.BLOQUEIO


static func resolver_entre(golpe: GolpeDirecional, pos_atacante: Vector3, defensor: ExecutorCorpoACorpo) -> Resultado:
	if defensor == null or defensor.ator == null or defensor.estilo == null:
		return Resultado.ACERTO
	return resolver(golpe, pos_atacante, defensor.em_guarda(), defensor.aparando(), defensor.postura, defensor.estilo.cone_da_guarda,
		defensor.ator.corpo().global_position, defensor.ator.base_do_corpo())
