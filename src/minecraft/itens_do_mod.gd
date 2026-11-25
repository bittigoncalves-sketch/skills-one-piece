class_name ItensDoMod
extends RefCounted
## Itens do Mine Piece do JOGADOR (10/11/2026). A camada Minecraft não tem mochila: aqui moram só os itens que as técnicas das frutas
## entregam/gastam (hoje o biscoito do Bisu Bisu), guardados na progressão (`ProgressaoDoPersonagem.itens_do_mod`) e salvos com ela.
## GATILHO: trocar pela mochila fiel ao Minecraft (slots/crafting, decisão do dono) quando ela existir; esta API vira a fachada dela.
const BISCOITO := "minepiece:biscuit"


static func progressao(arvore: SceneTree) -> ProgressaoDoPersonagem:
	var cena: Node = arvore.current_scene if arvore != null else null
	var p: Variant = cena.get("progressao") if cena != null else null
	return p as ProgressaoDoPersonagem


static func quantidade(arvore: SceneTree, id: String) -> int:
	var p := progressao(arvore)
	return p.item_do_mod(id) if p != null else 0


static func dar(arvore: SceneTree, id: String, n: int) -> void:
	var p := progressao(arvore)
	if p != null:
		p.dar_item_do_mod(id, n)


static func gastar(arvore: SceneTree, id: String, n: int) -> bool:
	var p := progressao(arvore)
	return p != null and p.gastar_item_do_mod(id, n)
