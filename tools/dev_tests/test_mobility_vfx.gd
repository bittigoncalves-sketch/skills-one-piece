extends SceneTree

## Verifica que os três componentes novos carregam isoladamente, sem precisar
## subir a cena inteira nem seus autoloads de rede.
func _init() -> void:
	var queda := preload("res://src/player/fall_impact_controller.gd").new()
	var ecos := preload("res://src/player/afterimage_trail.gd").new()
	var ferro := preload("res://src/player/iron_body_controller.gd").new()
	var corrida := preload("res://src/player/run_acceleration_controller.gd").new()
	assert(queda != null)
	assert(ecos != null)
	# A chama 2D do Lunariano é um quad cuja silhueta vem do shader. Eco troca
	# materiais por transparência neutra; logo a marca remove só a chama antes
	# disso, mantendo os demais adornos (ex.: asas) no rastro.
	var modelo := Node3D.new()
	var chama := MeshInstance3D.new()
	chama.set_meta("afterimage_excluir", true)
	var asa := MeshInstance3D.new()
	modelo.add_child(chama)
	modelo.add_child(asa)
	ecos._remover_elementos_sem_eco(modelo)
	assert(chama.get_parent() == null)
	assert(asa.get_parent() == modelo)
	modelo.queue_free()
	assert(ferro.pronto())
	assert(is_equal_approx(corrida.atualizar(1.5, true), 1.5))
	assert(is_equal_approx(corrida.atualizar(1.5, true), 2.0))
	assert(is_equal_approx(corrida.atualizar(0.0, false), 1.0))
	var alvo := Node.new()
	root.add_child(alvo)
	ferro.montar_em(alvo)
	ferro.ativar_confirmado()
	assert(alvo.get_meta("iron_body_active", false))
	assert(not ferro.pronto())
	ferro.atualizar(1.1)
	assert(not alvo.get_meta("iron_body_active", true))
	alvo.queue_free()
	print("[OK] controladores de queda, ecos (incluindo exclusão da chama lunar) e Corpo de Ferro carregaram")
	quit()
