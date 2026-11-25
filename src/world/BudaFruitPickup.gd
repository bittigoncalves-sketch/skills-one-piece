extends Node3D
## Visual autoral voxel; coleta e respawn usam o contrato existente.
const MODEL_PATH := "res://assets/models/buda/buda_voxel.tscn"
var _visual: Node3D
var _tempo := 0.0

func _ready() -> void:
	_visual = (load(MODEL_PATH) as PackedScene).instantiate()
	add_child(_visual)
	var area := Area3D.new()
	area.name = "PickupArea"
	var colisao := CollisionShape3D.new()
	colisao.name = "CollisionShape3D"
	var esfera := SphereShape3D.new()
	esfera.radius = 1.6
	colisao.shape = esfera
	area.add_child(colisao)
	add_child(area)
	area.body_entered.connect(_coletar)

func _coletar(corpo: Node) -> void:
	TreeAndFruitGenerator.pickup_fruit(corpo, "hito_hito_daibutsu")

func _process(delta: float) -> void:
	if not is_instance_valid(_visual) or not visible:
		return
	_tempo += delta
	_visual.rotation.y += delta * 0.42
	_visual.position.y = sin(_tempo * 1.8) * 0.065
