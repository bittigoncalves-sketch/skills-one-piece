class_name McItem
extends RefCounted
## `Item` do Minecraft (o TIPO: minepiece:kiribachi, minepiece:item_devil_fruit_gomu_gomu…), um
## por id (`Mc.item`), então `==` funciona. E, em `McItem.Pilha`, o `ItemStack`.

var id: StringName


func getDescriptionId() -> String: return "item." + String(id).replace(":", ".")
func getDefaultInstance() -> Pilha: return pilha(self, 1)
func _to_string() -> String: return String(id)


static func pilha(item: McItem, quantidade: int = 1) -> Pilha:
	var p := Pilha.new()
	p.item = item
	p.quantidade = quantidade if item != null else 0
	return p


## `ItemStack`: item + quantidade + NBT. `ItemStack.EMPTY` = sem item.
class Pilha:
	extends RefCounted
	var item: McItem = null
	var quantidade := 0
	var tag: McNbt = null
	var dano := 0

	func getItem() -> McItem: return item
	func isEmpty() -> bool: return item == null or quantidade <= 0
	func getCount() -> int: return quantidade
	func setCount(n: int) -> void: quantidade = n
	func grow(n: int) -> void: quantidade += n
	func shrink(n: int) -> void: quantidade = maxi(quantidade - n, 0)
	func getDamageValue() -> int: return dano
	func setDamageValue(n: int) -> void: dano = n
	func hasTag() -> bool: return tag != null and not tag.isEmpty()
	func getTag() -> McNbt: return tag
	func getOrCreateTag() -> McNbt:
		if tag == null:
			tag = McNbt.new()
		return tag
	func getDisplayName() -> McTexto: return McTexto.de(String(item.id) if item != null else "")
	func getHoverName() -> McTexto: return getDisplayName()
	## `stack.is(Item)` ou `stack.is(TagKey)`.
	func is_(o: Variant) -> bool:
		if o is McItem:
			return item == o
		return item != null and Mc.tag_contem(o, item.id, "tags_de_item")

	func copy() -> Pilha:
		var p := McItem.pilha(item, quantidade)
		p.tag = tag.copy() if tag != null else null
		p.dano = dano
		return p
