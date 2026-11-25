extends RefCounted
static func proteger(corpo: Node, dano: float) -> bool:
	if not corpo.is_inside_tree() or not corpo.has_meta("membro_tripulacao"): return false
	var s := corpo.get_tree().get_first_node_in_group("sobrevivencia_historia")
	return s != null and s.proteger(corpo, dano)

static func marcar(alvo: Node, autor: Node) -> void:
	var boss := is_instance_valid(autor) and (autor.is_in_group("boss") or autor.is_in_group("chefes"))
	alvo.set_meta("dano_do_jogador", is_instance_valid(autor) and autor.is_in_group("player"))
	alvo.set_meta("dano_de_boss", boss)
	alvo.set_meta("dano_de_npc", is_instance_valid(autor) and not autor.is_in_group("player"))
	# Quem bateu DE VERDADE (18/10/2026): sem isto o alvo adivinhava pelo mais perto do
	# golpe — e a rajada de um pirata "vinha do jogador" cercado, furando o "mesmo bando
	# não fere" (medido na raid: bandidos derrubando bandidos).
	if is_instance_valid(autor):
		alvo.set_meta("autor_do_dano", autor.get_instance_id())

static func limpar(alvo: Node) -> void:
	if is_instance_valid(alvo):
		alvo.remove_meta("dano_do_jogador")
		alvo.remove_meta("dano_de_boss")
		alvo.remove_meta("dano_de_npc")
		alvo.remove_meta("autor_do_dano")
