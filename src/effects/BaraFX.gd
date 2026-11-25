class_name BaraFX
extends RefCounted
## Entrada de compatibilidade para ferramentas: o kit antigo foi removido.
const CONTROLLER := preload("res://src/combat/BaraController.gd")

static func cast(world: Node, origin: Vector3, aim: Vector3, variant: int,
		damage: float, caster: Node3D, spec: DamageSpec = null) -> void:
	if variant < 0 or variant > 3 or not is_instance_valid(caster): return
	var slot: String = ["Z", "X", "C", "V"][variant]
	var actual := spec if spec != null else DamageSpec.avulso(damage).para_cast()
	CONTROLLER.cast(world, slot, aim, origin, caster, actual, 0)
