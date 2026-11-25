extends RefCounted
## A viagem de uma skill do Builder acabando antes (07/10/2026, X da Pika).
##
## Pedido do dono: "X caso detecte algum inimigo próximo ou embaixo da técnica ela é
## encerrada em cima daquele inimigo"; e, sem inimigo, a viagem "pára antes do vazio"
## (o zigue-zague de 21 m terminava sobre os buracos da arena e o jogador caía).
## Contas puras, usadas pelo `ExecutorDeSkill` em cada quadro dos blocos de Movimento
## no plano (a subida "Acima" não conta).

## Até onde se procura chão embaixo (m). Sem chão até aqui = vazio. O fundo do mar da
## história fica a −30 m: mar não é vazio.
const FUNDO := 60.0
## "Embaixo": o inimigo não pode estar mais alto do que isto acima do pé do ator (m).
const ACIMA_MAX := 1.5


## O inimigo vivo mais perto NO PLANO (até `raio`), na altura do ator ou abaixo dele.
## Inimigo = outro jogador ou um corpo do grupo "enemy" (não os bichos nem os pets).
static func inimigo_embaixo(ator: Node3D, pe: Vector3, raio: float) -> Node3D:
	var melhor: Node3D = null
	var menor := raio
	for grupo in ["player", "enemy"]:
		for n in ator.get_tree().get_nodes_in_group(grupo):
			if n == ator or not (n is Node3D) or not is_instance_valid(n):
				continue
			if "health" in n and float(n.get("health")) <= 0.0:
				continue
			var c := AlvosDeGolpe.centro(n as Node3D)
			if c.y > pe.y + ACIMA_MAX:
				continue
			var d := Vector2(c.x - pe.x, c.z - pe.z).length()
			if d <= menor:
				menor = d
				melhor = n as Node3D
	return melhor


## Há chão (cenário) embaixo de `ponto`, até `FUNDO` metros?
static func tem_chao(mundo: World3D, ponto: Vector3, excluir: Array[RID]) -> bool:
	if mundo == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(ponto + Vector3.UP * 0.5, ponto + Vector3.DOWN * FUNDO, 1, excluir)
	return not mundo.direct_space_state.intersect_ray(q).is_empty()
