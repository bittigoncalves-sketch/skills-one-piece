extends Node3D
## Modelo autoral; o contrato de coleta/respawn continua em FruitNet.

const MODEL_PATH := "res://assets/models/ope_ope/ope_ope_fruit.glb"
var _visual: Node3D
var _elapsed := 0.0

func _ready() -> void:
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("Ope Ope: modelo da fruta não importado: " + MODEL_PATH)
		return
	_visual = scene.instantiate() as Node3D
	_visual.name = "CoracaoOpe"
	add_child(_visual)
	var area := Area3D.new()
	area.name = "PickupArea"
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	collision.shape = sphere
	area.add_child(collision)
	add_child(area)
	area.body_entered.connect(_pickup)

func _pickup(body: Node) -> void:
	TreeAndFruitGenerator.pickup_fruit(body, "ope_ope")

func _process(delta: float) -> void:
	if not is_instance_valid(_visual) or not visible:
		return
	_elapsed += delta
	_visual.rotation.y += delta * 0.42
	_visual.position.y = 0.16 + sin(_elapsed * 1.8) * 0.065
