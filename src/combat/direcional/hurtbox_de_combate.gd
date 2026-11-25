class_name HurtboxDeCombate
extends RefCounted
# ============================================================================
#  HURTBOX DE COMBATE — o volume que o golpe ACERTA, separado do que o corpo
#  ESBARRA ao andar (01/10/2026).
#
#  No Modo História o jogador e o boneco andam de CÁPSULA (pés no chão em encosta,
#  decisão do dono). Mas o combate direcional acerta pela varredura de física contra
#  o corpo, e todos os golpes (arcos dos ganchos, alcance dos jabs) foram afinados
#  contra a CAIXA 1 × 1,6 × 1 de antes: com a cápsula, mais estreita, os ganchos
#  laterais passaram a errar (test_contato_historia: 8 de 20 golpes sem contato).
#
#  A hurtbox devolve ao combate o volume de antes sem tocar no movimento: um
#  StaticBody3D filho do corpo, na CAMADA 21 (que nenhum movimento, câmera ou efeito
#  usa), sem `take_damage` (efeito de fruta nenhum a acerta em dobro). Só a varredura
#  do combate (`SwordSweep`) a enxerga, e troca o acerto nela pelo DONO.
# ============================================================================

## Camada 21 do painel de física. A 20 é a do clique do editor de mapa.
const CAMADA := 1 << 20
const NOME := "Hurtbox"


## Pendura (ou reaproveita) a hurtbox em `corpo`, com o tamanho de caixa dado.
static func instalar(corpo: CollisionObject3D, tamanho: Vector3) -> StaticBody3D:
	var hb := corpo.get_node_or_null(NOME) as StaticBody3D
	if hb == null:
		hb = StaticBody3D.new()
		hb.name = NOME
		hb.collision_layer = CAMADA
		hb.collision_mask = 0
		hb.set_meta("hurtbox_de", corpo)
		var cs := CollisionShape3D.new()
		cs.name = "Forma"
		cs.shape = BoxShape3D.new()
		hb.add_child(cs)
		corpo.add_child(hb)
	redimensionar(corpo, tamanho)
	return hb


static func redimensionar(corpo: Node, tamanho: Vector3, deslocamento_y := 0.0) -> void:
	var hb := corpo.get_node_or_null(NOME) as StaticBody3D
	if hb == null:
		return
	var cs := hb.get_node("Forma") as CollisionShape3D
	(cs.shape as BoxShape3D).size = tamanho
	cs.position.y = deslocamento_y


## Leva a hurtbox para onde o corpo está AGORA, direto no servidor de física.
## ⚠️ Chamar logo depois de mover o corpo: um corpo estático filho de um corpo que
## se move fica UM QUADRO atrás no servidor (medido em 01/10/2026 — teleporte e
## `move_and_slide`), e um quadro basta para desempatar uma troca de golpes que com a
## caixa antiga caía no mesmo quadro (test_contato_historia, "troca de frente").
static func sincronizar(corpo: Node3D) -> void:
	var hb := corpo.get_node_or_null(NOME) as StaticBody3D
	if hb != null:
		PhysicsServer3D.body_set_state(hb.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, hb.global_transform)


## O dono de um corpo acertado: a própria hurtbox aponta para ele; qualquer outro
## corpo é ele mesmo.
static func dono_de(no: Object) -> Object:
	if no != null and no.has_meta("hurtbox_de"):
		return no.get_meta("hurtbox_de")
	return no


static func e_hurtbox(no: Object) -> bool:
	return no != null and no.has_meta("hurtbox_de")


## RID da hurtbox do corpo (para o próprio golpe não se acertar), ou RID vazio.
static func rid_de(corpo: Node) -> RID:
	var hb := corpo.get_node_or_null(NOME) as StaticBody3D if corpo != null else null
	return hb.get_rid() if hb != null else RID()
