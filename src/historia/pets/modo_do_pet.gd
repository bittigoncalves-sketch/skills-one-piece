class_name ModoDoPet
extends RefCounted
# ============================================================================
#  OS COMPORTAMENTOS DE PET — livre, seguir, em guarda, agressivo (30/09/2026).
#
#  Pedido do dono, escolhido pela aba PETS do M (`MenuDeComportamento`; antes a tecla B) para o pet
#  mais perto. Decisões dele:
#    • LIVRE      — o pet vive por conta própria em volta de onde ficou livre;
#    • SEGUIR     — acompanha o jogador, não ataca;
#    • EM GUARDA  — acompanha e ataca só inimigo a até `RAIO_GUARDA` do JOGADOR;
#    • AGRESSIVO  — acompanha e caça inimigo a até `RAIO_CACA` do jogador, e volta.
#
#  Aqui só a REGRA comum (nomes e quem é alvo); como cada pet anda, voa e ataca é dele.
# ============================================================================

const LIVRE := &"livre"
const SEGUIR := &"seguir"
const GUARDA := &"guarda"
const AGRESSIVO := &"agressivo"
## A ordem do menu (teclas 1–4).
const ORDEM: Array[StringName] = [LIVRE, SEGUIR, GUARDA, AGRESSIVO]
const NOMES := {LIVRE: "Livre", SEGUIR: "Seguir", GUARDA: "Em guarda", AGRESSIVO: "Agressivo"}
const DESCRICOES := {
	LIVRE: "Vive por conta própria em volta de onde ficou.",
	SEGUIR: "Acompanha você e não ataca.",
	GUARDA: "Acompanha e ataca quem chegar perto de você.",
	AGRESSIVO: "Caça inimigos por perto e volta para você.",
}
## Em guarda: inimigo a até isto do JOGADOR vira alvo.
const RAIO_GUARDA := 6.0
## Agressivo: inimigo a até isto do jogador vira alvo.
const RAIO_CACA := 15.0
## O grupo dos inimigos (o mesmo da arena, da mira assistida e das técnicas de área).
const GRUPO_INIMIGO := "enemy"


static func valido(modo: Variant) -> bool:
	return ORDEM.has(StringName(str(modo)))


static func nome(modo: StringName) -> String:
	return String(NOMES.get(modo, str(modo)))


## Quem o pet deve atacar agora (`null` = ninguém). Livre e seguir nunca atacam.
## Em guarda escolhe o inimigo mais perto do DONO (quem o ameaça primeiro); agressivo,
## o mais perto do PET (o que ele alcança primeiro).
static func alvo(modo: StringName, dono: Node3D, pet: Node3D) -> Node3D:
	if modo != GUARDA and modo != AGRESSIVO:
		return null
	if not is_instance_valid(dono) or not is_instance_valid(pet) or not dono.is_inside_tree():
		return null
	var raio := RAIO_GUARDA if modo == GUARDA else RAIO_CACA
	var referencia: Node3D = dono if modo == GUARDA else pet
	var melhor: Node3D = null
	var melhor_d := INF
	for n in dono.get_tree().get_nodes_in_group(GRUPO_INIMIGO):
		var inimigo := n as Node3D
		if not inimigo_vivo(inimigo) or _plana(inimigo.global_position - dono.global_position) > raio:
			continue
		var d := _plana(inimigo.global_position - referencia.global_position)
		if d < melhor_d:
			melhor_d = d
			melhor = inimigo
	return melhor


## `inimigo` continua sendo alvo válido neste modo (vivo e dentro do raio do dono).
static func no_raio(modo: StringName, dono: Node3D, inimigo: Node3D) -> bool:
	if modo != GUARDA and modo != AGRESSIVO or not inimigo_vivo(inimigo) or not is_instance_valid(dono):
		return false
	return _plana(inimigo.global_position - dono.global_position) <= (RAIO_GUARDA if modo == GUARDA else RAIO_CACA)


## Vivo, na cena, visível e com vida: o inimigo adormecido (renascendo) não conta.
static func inimigo_vivo(n: Node3D) -> bool:
	if not is_instance_valid(n) or not n.is_inside_tree() or not n.visible or not n.has_method("take_damage"):
		return false
	var vida: Variant = n.get("health")
	return vida == null or float(vida) > 0.0


static func _plana(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()
