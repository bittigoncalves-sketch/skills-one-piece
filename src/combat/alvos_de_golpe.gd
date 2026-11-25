class_name AlvosDeGolpe
extends RefCounted
# ============================================================================
#  ALVOS DE GOLPE — quem um golpe de fruta pode PROCURAR (05/10/2026).
#
#  O código das frutas achava alvo nos grupos "player" e "enemy". Na arena isso é
#  todo mundo; no Modo História não: o animal manso não é "enemy" (é esse grupo que
#  manda o pet em guarda atacar e a visão do E destacar) e ficava de fora da Ope C/V,
#  do Kurouzu, dos vaga-lumes da Pika, da mão da Bara… Pedido do dono: as frutas
#  trazidas para a história afetam TODOS os NPCs que lutam ou vivem.
#
#  Um grupo a mais, só de ALVO: `GRUPO`. Entram os animais da ilha (chefes também),
#  os inimigos do mapa e o boneco de duelo. Não entram os NPCs de loja nem os pets do
#  jogador (decisão do dono). Na arena o grupo fica vazio — nada muda lá.
# ============================================================================

const GRUPO := "alvo_de_golpe"


## Todos os alvos possíveis, sem repetição: jogadores, inimigos e NPCs-alvo.
static func todos(arvore: SceneTree) -> Array[Node]:
	var saida: Array[Node] = []
	if arvore == null:
		return saida
	var vistos := {}
	for grupo in ["player", "enemy", GRUPO]:
		for n in arvore.get_nodes_in_group(grupo):
			if not vistos.has(n):
				vistos[n] = true
				saida.append(n)
	return saida


## Só os NPCs (sem os jogadores): para quem antes procurava apenas "enemy".
static func npcs(arvore: SceneTree) -> Array[Node]:
	var saida: Array[Node] = []
	for n in todos(arvore):
		if not n.is_in_group("player"):
			saida.append(n)
	return saida


## O meio do corpo do alvo. Jogador, boneco e inimigo do mapa têm a origem no centro;
## o animal tem no pé e responde `centro_do_corpo()`.
static func centro(no: Node3D) -> Vector3:
	if no.has_method("centro_do_corpo"):
		return no.call("centro_do_corpo")
	return no.global_position


## O ponto que o RETÍCULO marca: o primeiro corpo na linha da mira (que sai de
## `origem`, na linha da câmera) até `alcance`; sem nada na frente, o fim. Golpe que
## sai de OUTRO ponto do corpo (ombro, mão) mira até aqui — com a direção da câmera
## ele seguia uma reta paralela à do retículo e errava o alvo (Bara, Gomu; 05/10/2026).
static func ponto_mirado(mundo: World3D, origem: Vector3, rumo: Vector3, alcance: float, excluir: Array[RID] = []) -> Vector3:
	var ate := origem + rumo.normalized() * alcance
	if mundo == null:
		return ate
	var raio := PhysicsRayQueryParameters3D.create(origem, ate, 15, excluir)
	var hit := mundo.direct_space_state.intersect_ray(raio)
	return hit["position"] if not hit.is_empty() else ate


## Distância de `ponto` até o CORPO do alvo (0 se estiver dentro). Alvo grande — a
## besta do mar tem dezenas de metros — não pode ser medido pelo centro: um golpe
## que o toca na pele fica a 5-10 m do meio e "errava". Usa a forma do `Hurtbox`
## (caixa, esfera ou cápsula); sem ele, cai na distância ao centro.
static func distancia_ao_corpo(no: Node3D, ponto: Vector3) -> float:
	var hb := no.get_node_or_null("Hurtbox")
	if hb != null:
		for filho in hb.get_children():
			var cs := filho as CollisionShape3D
			if cs == null or cs.disabled or cs.shape == null:
				continue
			var l := cs.global_transform.affine_inverse() * ponto
			var fora := Vector3.ZERO
			if cs.shape is BoxShape3D:
				fora = (l.abs() - (cs.shape as BoxShape3D).size * .5).max(Vector3.ZERO)
			elif cs.shape is SphereShape3D:
				fora = l.normalized() * maxf(0.0, l.length() - (cs.shape as SphereShape3D).radius)
			elif cs.shape is CapsuleShape3D:
				var c := cs.shape as CapsuleShape3D
				var eixo := maxf(0.0, c.height * .5 - c.radius)
				var q := Vector3(0, clampf(l.y, -eixo, eixo), 0)
				fora = (l - q).normalized() * maxf(0.0, (l - q).length() - c.radius)
			else:
				continue
			# Escala do nó: a distância local só vale em escala uniforme.
			return (fora * cs.global_transform.basis.get_scale()).length()
	return centro(no).distance_to(ponto)


static func e_alvo(no: Node) -> bool:
	return no != null and (no.is_in_group("player") or no.is_in_group("enemy") or no.is_in_group(GRUPO))
