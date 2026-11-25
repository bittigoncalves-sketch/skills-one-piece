extends Node3D
## Modelo autoral da Goro Goro; o contrato de coleta/respawn continua em FruitNet.
## Mesmo desenho do OpeFruitPickup — o que muda e o modelo e a cadencia da flutuacao.

const MODEL_PATH := "res://assets/models/goro_goro/goro_goro_fruit.glb"

## A fruta do trovao nao boia com a calma da Ope: o giro e mais rapido e a
## subida tem um segundo harmonico, para o movimento ficar levemente instavel.
const GIRO := 0.58
const ALTURA_BASE := 0.16
const AMPLITUDE := 0.055

var _visual: Node3D
var _elapsed := 0.0

func _ready() -> void:
	var scene := load(MODEL_PATH) as PackedScene
	if scene == null:
		push_error("Goro Goro: modelo da fruta não importado: " + MODEL_PATH)
		return
	_visual = scene.instantiate() as Node3D
	_visual.name = "BulboGoro"
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
	TreeAndFruitGenerator.pickup_fruit(body, "goro_goro")

func _process(delta: float) -> void:
	if not is_instance_valid(_visual) or not visible:
		return
	_elapsed += delta
	_visual.rotation.y += delta * GIRO
	# Dois senos em frequencias diferentes: a fruta nunca repete a mesma subida.
	_visual.position.y = ALTURA_BASE \
		+ sin(_elapsed * 1.9) * AMPLITUDE \
		+ sin(_elapsed * 4.7) * (AMPLITUDE * 0.22)
