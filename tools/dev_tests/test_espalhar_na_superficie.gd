extends SceneTree
## `spreadplayers` pousa o alvo na superfície (Shakushi do Kuro "saia voando", 11/11/2026): chão a 6 m de altura ao longe, corpo parado no y 0.
func _initialize() -> void:
	var raiz := Node3D.new()
	root.add_child(raiz)
	var chao := StaticBody3D.new()
	chao.collision_layer = 1
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(400, 2, 400)
	cs.shape = caixa
	chao.add_child(cs)
	chao.position = Vector3(0, 5.0, 0)            # topo em y = 6
	raiz.add_child(chao)
	var corpo := CharacterBody3D.new()
	corpo.collision_layer = 2
	raiz.add_child(corpo)
	corpo.global_position = Vector3(0, 0.0, 0)    # abaixo do topo, como quem ficou para trás num morro
	await physics_frame
	await physics_frame
	var e := McEntidade.de(corpo)
	var y := McComandos._y_da_superficie(e, 10.0, 10.0, 0.0)
	var ok := absf(y * McEntidade.B - 6.05) < 0.1
	print("  %s y da superfície = %.2f m (esperado ~6.05)" % ["✅" if ok else "❌", y * McEntidade.B])
	var sem := McComandos._y_da_superficie(e, 10000.0, 10000.0, 3.0)
	print("  %s sem chão no raio fica o y de partida (%.2f)" % ["✅" if absf(sem - 3.0) < 0.001 else "❌", sem])
	quit(0 if ok else 1)
