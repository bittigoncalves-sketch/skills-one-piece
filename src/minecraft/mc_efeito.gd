class_name McEfeito
extends RefCounted
## `MobEffect` (o TIPO: minecraft:slowness, minepiece:stun…) e, em `McEfeito.Instancia`, o
## `MobEffectInstance` (tipo + duração em ticks + amplificador). 575 arquivos do mod usam efeitos.
## Um tipo por id (`Mc.efeito`), então comparar com `==` funciona como no Java.

var id: StringName

## Nome do campo Java (`MobEffects.X`, em minúsculas) → id do registro do Minecraft 1.20.1.
const ALIAS := {
	&"minecraft:movement_speed": &"minecraft:speed", &"minecraft:movement_slowdown": &"minecraft:slowness",
	&"minecraft:dig_speed": &"minecraft:haste", &"minecraft:dig_slowdown": &"minecraft:mining_fatigue",
	&"minecraft:damage_boost": &"minecraft:strength", &"minecraft:heal": &"minecraft:instant_health",
	&"minecraft:harm": &"minecraft:instant_damage", &"minecraft:jump": &"minecraft:jump_boost",
	&"minecraft:confusion": &"minecraft:nausea", &"minecraft:damage_resistance": &"minecraft:resistance",
}

## Os efeitos que MEXEM EM ATRIBUTO no Minecraft 1.20.1 (`MobEffect.addAttributeModifier`): atributo, valor por nível
## (× (amplificador + 1)) e operação. Resistência, regeneração, veneno etc. agem no dano/tick, não aqui.
const MODIFICADORES := {
	&"minecraft:speed": [[&"minecraft:generic.movement_speed", 0.2, &"MULTIPLY_TOTAL"]],
	&"minecraft:slowness": [[&"minecraft:generic.movement_speed", -0.15, &"MULTIPLY_TOTAL"]],
	&"minecraft:haste": [[&"minecraft:generic.attack_speed", 0.1, &"MULTIPLY_TOTAL"]],
	&"minecraft:mining_fatigue": [[&"minecraft:generic.attack_speed", -0.1, &"MULTIPLY_TOTAL"]],
	&"minecraft:strength": [[&"minecraft:generic.attack_damage", 3.0, &"ADDITION"]],
	&"minecraft:weakness": [[&"minecraft:generic.attack_damage", -4.0, &"ADDITION"]],
	&"minecraft:health_boost": [[&"minecraft:generic.max_health", 4.0, &"ADDITION"]],
}

## Ganchos do efeito do mod (`mapas/east_blue/efeitos_do_mod.json`): procedures de tick (a cada
## `periodo` ticks; 0 = sem tick), ao começar e ao acabar. Efeito vanilla: nenhum.
const ARQUIVO := "res://mapas/east_blue/efeitos_do_mod.json"
static var _ganchos := {}


func ganchos() -> Dictionary:
	if _ganchos.is_empty():
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(ARQUIVO)) if FileAccess.file_exists(ARQUIVO) else null
		_ganchos = d["efeitos"] if d is Dictionary else {"_": {}}
	return _ganchos.get(String(id), {})


class Instancia:
	extends RefCounted
	var efeito: McEfeito
	var duracao := 0                 # ticks; −1 = infinita
	var amplificador := 0
	var ambiente := false
	var visivel := true
	var icone := true

	func getEffect() -> McEfeito: return efeito
	func getDuration() -> int: return duracao
	func getAmplifier() -> int: return amplificador
	func isAmbient() -> bool: return ambiente
	func isVisible() -> bool: return visivel
	func showIcon() -> bool: return icone
	func isInfiniteDuration() -> bool: return duracao == -1
	func endsWithin(ticks: int) -> bool: return duracao != -1 and duracao <= ticks

	## `MobEffectInstance.update`: amplificador maior troca tudo; igual, fica a duração maior.
	func atualizar(nova: Instancia) -> bool:
		if nova.amplificador > amplificador:
			amplificador = nova.amplificador
			duracao = nova.duracao
			return true
		if nova.amplificador == amplificador and (nova.duracao == -1 or (duracao != -1 and nova.duracao > duracao)):
			duracao = nova.duracao
			return true
		return false

	## Um tick: false quando acabou.
	func tick() -> bool:
		if duracao == -1:
			return true
		duracao -= 1
		return duracao > 0


static func instancia(efeito: McEfeito, duracao: int = 0, amplificador: int = 0, ambiente := false,
		visivel := true, icone := true) -> Instancia:
	var i := Instancia.new()
	i.efeito = efeito
	i.duracao = duracao
	i.amplificador = amplificador
	i.ambiente = ambiente
	i.visivel = visivel
	i.icone = icone
	return i


func getDescriptionId() -> String: return "effect." + String(id).replace(":", ".")
func _to_string() -> String: return String(id)
