class_name McAtributo
extends RefCounted
## `Attribute` do Minecraft (o TIPO, com padrão e limites) e, em `McAtributo.Instancia`, o valor de
## uma entidade com os modificadores. 702 arquivos do mod usam atributos.
## Conta do `AttributeInstance.calculateValue` (1.20.1):
##   d = base + Σ ADDITION;  e = d + Σ (d × MULTIPLY_BASE);  e ×= (1 + MULTIPLY_TOTAL) para cada um;
##   e limitado a [mínimo, máximo] do atributo.

## Padrão, mínimo e máximo dos atributos vanilla (RangedAttribute) e dos do mod
## (MinepieceModAttributes: SIZE, FORM, ANIMATION_...). Ausente: padrão 0, sem limite.
const FAIXAS := {
	&"minecraft:generic.max_health": [20.0, 1.0, 1024.0],
	&"minecraft:generic.follow_range": [32.0, 0.0, 2048.0],
	&"minecraft:generic.knockback_resistance": [0.0, 0.0, 1.0],
	&"minecraft:generic.movement_speed": [0.7, 0.0, 1024.0],
	&"minecraft:generic.flying_speed": [0.4, 0.0, 1024.0],
	&"minecraft:generic.attack_damage": [2.0, 0.0, 2048.0],
	&"minecraft:generic.attack_knockback": [0.0, 0.0, 5.0],
	&"minecraft:generic.attack_speed": [4.0, 0.0, 1024.0],
	&"minecraft:generic.armor": [0.0, 0.0, 30.0],
	&"minecraft:generic.armor_toughness": [0.0, 0.0, 20.0],
	&"minepiece:size": [1.0, 0.0, 1024.0],
}
## Nome do campo Java (`Attributes.MAX_HEALTH`) → id do registro.
const DO_CAMPO := {
	"max_health": &"minecraft:generic.max_health", "follow_range": &"minecraft:generic.follow_range",
	"knockback_resistance": &"minecraft:generic.knockback_resistance",
	"movement_speed": &"minecraft:generic.movement_speed", "flying_speed": &"minecraft:generic.flying_speed",
	"attack_damage": &"minecraft:generic.attack_damage", "attack_knockback": &"minecraft:generic.attack_knockback",
	"attack_speed": &"minecraft:generic.attack_speed", "armor": &"minecraft:generic.armor",
	"armor_toughness": &"minecraft:generic.armor_toughness",
}

var id: StringName
var padrao := 0.0
var minimo := -INF
var maximo := INF


func getDefaultValue() -> float: return padrao
## `ForgeMod.SWIM_SPEED.get()` chega como `Mc.obter0(atributo)`.
func obter() -> McAtributo: return self
func sanitizeValue(v: float) -> float: return clampf(v, minimo, maximo)
func _to_string() -> String: return String(id)


class Modificador:
	extends RefCounted
	var uuid := ""
	var nome := ""
	var valor := 0.0
	var operacao: StringName = &"ADDITION"      # ADDITION | MULTIPLY_BASE | MULTIPLY_TOTAL

	func getId() -> String: return uuid
	func getAmount() -> float: return valor
	func getOperation() -> StringName: return operacao


class Instancia:
	extends RefCounted
	var atributo: McAtributo
	var base := 0.0
	var modificadores := {}                     # uuid → Modificador
	## Quem é avisado quando o valor muda (o adaptador leva vida/escala para o corpo).
	var ao_mudar := Callable()

	func getAttribute() -> McAtributo: return atributo
	func getBaseValue() -> float: return base

	func setBaseValue(v: float) -> void:
		if base == v:
			return
		base = v
		_mudou()

	func getValue() -> float:
		var d := base
		for m: Modificador in modificadores.values():
			if m.operacao == &"ADDITION":
				d += m.valor
		var e := d
		for m: Modificador in modificadores.values():
			if m.operacao == &"MULTIPLY_BASE":
				e += d * m.valor
		for m: Modificador in modificadores.values():
			if m.operacao == &"MULTIPLY_TOTAL":
				e *= 1.0 + m.valor
		return atributo.sanitizeValue(e)

	func hasModifier(m: Variant) -> bool:
		return modificadores.has(m.uuid if m is Modificador else str(m))

	func getModifier(uuid: Variant) -> Modificador: return modificadores.get(str(uuid))

	func addTransientModifier(m: Modificador) -> void:
		modificadores[m.uuid] = m
		_mudou()

	func addPermanentModifier(m: Modificador) -> void: addTransientModifier(m)

	func removePermanentModifier(m: Variant) -> void: removeModifier(m)

	func removeModifier(m: Variant) -> void:
		modificadores.erase(m.uuid if m is Modificador else str(m))
		_mudou()

	func removeModifiers() -> void:
		modificadores.clear()
		_mudou()

	func _mudou() -> void:
		if ao_mudar.is_valid():
			ao_mudar.call(self)
