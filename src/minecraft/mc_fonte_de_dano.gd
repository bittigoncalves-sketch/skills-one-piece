class_name McFonteDeDano
extends RefCounted
## `DamageSource` do Minecraft: o tipo de dano e quem causou (o tipo ainda não muda nada no jogo;
## o funil de dano é o `take_damage` do corpo).

var tipo: StringName = &"minecraft:generic"
var atacante: McEntidade = null
var direto: McEntidade = null


static func de(t: Variant, quem: McEntidade = null, direto_: McEntidade = null) -> McFonteDeDano:
	var f := McFonteDeDano.new()
	f.tipo = StringName(str(t)) if t != null else &"minecraft:generic"
	f.atacante = quem
	f.direto = direto_ if direto_ != null else quem
	return f


func getEntity() -> McEntidade: return atacante
func getDirectEntity() -> McEntidade: return direto
## `DamageSource.is(ResourceKey)` compara o tipo; `is(TagKey)` consulta as tags de dano do mod
## (forge:combat, forge:animation…). A guarda desses dois é o que impede o handler de dano do
## mod, que fere de dentro do evento, de reentrar sem fim.
func is_(t: Variant) -> bool:
	if Mc.tem_tag(t, "tags_de_dano"):
		return Mc.tag_contem(t, tipo, "tags_de_dano")
	return str(t) == String(tipo)


## `entity.damageSources()` / `level.damageSources()`.
class Fontes:
	extends RefCounted
	func generic() -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:generic")
	func magic() -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:magic")
	func mobAttack(e: McEntidade) -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:mob_attack", e)
	func playerAttack(e: McEntidade) -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:player_attack", e)
	func explosion(a: McEntidade = null, b: McEntidade = null) -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:explosion", b, a)
	func drown() -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:drown")
	func inFire() -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:in_fire")
	func fall() -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:fall")
	func lightningBolt() -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:lightning_bolt")
	func indirectMagic(a: McEntidade, b: McEntidade) -> McFonteDeDano: return McFonteDeDano.de(&"minecraft:indirect_magic", b, a)
	func source(t: Variant, a: McEntidade = null, b: McEntidade = null) -> McFonteDeDano: return McFonteDeDano.de(t, b if b != null else a, a)
