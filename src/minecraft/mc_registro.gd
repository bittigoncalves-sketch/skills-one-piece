class_name McRegistro
extends RefCounted
## `ForgeRegistries.X` / `BuiltInRegistries.X`: `getKey(objeto)` → id; `getValue(id)` → objeto da
## camada (o mesmo que `Mc.efeito`, `Mc.tipo_entidade`... devolvem, então `==` funciona).

var tipo := ""          # ENTITY_TYPES, MOB_EFFECTS, SOUND_EVENTS, PARTICLE_TYPES, ATTRIBUTES, ITEMS, BLOCKS


static func de(nome: String) -> McRegistro:
	var r := McRegistro.new()
	r.tipo = nome
	return r


func getKey(o: Variant) -> Variant:
	if o == null:
		return null
	if "id" in o:
		return String(o.id)
	return str(o)


func getValue(id: Variant) -> Variant:
	var chave := StringName(str(id))
	match tipo:
		"ENTITY_TYPES", "ENTITY_TYPE": return Mc.tipo_entidade(chave)
		"MOB_EFFECTS", "MOB_EFFECT": return Mc.efeito(chave)
		"ATTRIBUTES", "ATTRIBUTE": return Mc.atributo(chave)
		"SOUND_EVENTS", "SOUND_EVENT": return Mc.som(chave)
		"PARTICLE_TYPES", "PARTICLE_TYPE": return Mc.particula(chave)
		"ITEMS", "ITEM": return Mc.item(chave)
		"BLOCKS", "BLOCK": return Mc.bloco(chave)
	return Mc._falta("registro", tipo)


func containsKey(id: Variant) -> bool: return getValue(id) != null
## `registryOrThrow(DAMAGE_TYPE).getHolderOrThrow(ResourceKey)`: o "holder" é o próprio id (a fonte de
## dano guarda o tipo pelo id — `McFonteDeDano`).
func getHolderOrThrow(chave: Variant) -> Variant: return str(chave)
func getHolder(chave: Variant) -> McEntidade.Opcional:
	var o := McEntidade.Opcional.new()
	o.valor = str(chave)
	return o
func getOrThrow(chave: Variant) -> Variant: return getValue(chave)
