extends AnimalDaIlha
## Especialização só do boss Harpia: conserva vida, território e respawn da fauna.
@export var habilidades: Resource = preload("res://src/historia/bosses/harpia/config_harpia.gd").new()
var combate: Node

func _ready() -> void:
	combate = load("res://src/historia/bosses/harpia/combate_harpia.gd").new()
	combate.name = "HabilidadesDaHarpia"
	combate.corpo = self
	combate.config = habilidades.duplicate()
	add_child(combate)

func _physics_process(delta: float) -> void:
	if (has_meta("captura_vento") and is_instance_valid(get_meta("captura_vento"))) or (has_meta("arremesso_vento") and is_instance_valid(get_meta("arremesso_vento"))):
		return
	if vivo() and is_instance_valid(combate) and combate.atualizar(delta):
		return
	super._physics_process(delta)

func _tentar_atacar(_quem: Node3D, _distancia: float) -> void:
	# O kit substitui o golpe genérico de garras, que não pode acertar em paralelo.
	pass

func _morrer() -> void:
	if is_instance_valid(combate):
		combate.cancelar()
	super._morrer()

func reviver(posicao: Vector3) -> void:
	if is_instance_valid(combate):
		combate.reiniciar()
	super.reviver(posicao)

func manter_ativo_para_lod() -> bool:
	return is_instance_valid(combate) and combate.ativo()
