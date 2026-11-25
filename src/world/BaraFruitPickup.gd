extends Node3D
## Coletável autoral: três faixas fechadas; coleta e respawn pertencem ao FruitNet.

const MODEL_PATH := "res://assets/models/bara_bara/bara_bara_fruit.glb"
var _visual: Node3D
var _parts: Array[Node3D] = []
var _elapsed := 0.0

func _ready() -> void:
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("Bara Bara: modelo da fruta não importado: " + MODEL_PATH)
		return
	_visual = scene.instantiate() as Node3D
	_visual.name = "FrutaBara"
	add_child(_visual)
	for index in range(3):
		var part := _visual.find_child("Gomo_%d" % index, true, false) as Node3D
		if part != null:
			_parts.append(part)
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
	TreeAndFruitGenerator.pickup_fruit(body, "bara_bara")

func _process(delta: float) -> void:
	if not is_instance_valid(_visual) or not is_visible_in_tree():
		return
	_elapsed += delta
	_visual.rotation.y += delta * 0.38
	_visual.position.y = 0.16 + sin(_elapsed * 1.7) * 0.065
	# Uma breve abertura por ciclo sugere recomposição sem mover a área de coleta.
	var phase := fmod(_elapsed, 6.0)
	var pulse := sin(clampf((phase - 4.8) / 1.2, 0.0, 1.0) * PI)
	for index in range(_parts.size()):
		_parts[index].position = Vector3((1.0 if index == 1 else -0.5) * pulse * 0.012, (index - 1) * pulse * 0.018, 0.0)
