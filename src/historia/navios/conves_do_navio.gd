extends AnimatableBody3D
## Convés andável de um navio do Mine Piece (ver `Barco._criar_conves_do_modelo`). Golpe ou
## projétil que acerta o convés acerta o NAVIO: o dano vai para o casco.

var barco: Node


func take_damage(amount: float, from_pos := Vector3.ZERO, knockback := Vector3.ZERO, hitstun := 0.3) -> void:
	if is_instance_valid(barco):
		barco.take_damage(amount, from_pos, knockback, hitstun)
