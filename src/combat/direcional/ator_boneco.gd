class_name AtorBoneco
extends AtorDeCombate
# ============================================================================
#  ADAPTADOR DO BONECO DE DUELO para o executor do combate direcional.
#
#  Mesmo contrato do `AtorJogador`, outro corpo: é a prova de que o executor não
#  depende de input humano (plano, D1). Quem decide pelo boneco chama o executor
#  direto — um teste, ou um cérebro de IA.
# ============================================================================

var _boneco: BonecoDeDuelo


func _init(boneco: BonecoDeDuelo) -> void:
	_boneco = boneco


func corpo() -> Node3D:
	return _boneco


func modelo_visual() -> Node3D:
	return _boneco.modelo_visual() if is_instance_valid(_boneco) else null


func impedido(_contar_atordoamento := true) -> bool:
	return not is_instance_valid(_boneco) or _boneco.health <= 0.0
