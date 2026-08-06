extends SceneTree
# Mede a INCLINAÇÃO do tronco e da cabeça andando e correndo, no espaço do
# personagem. Positivo = inclinado pra FRENTE.
# Uso: godot --headless --path . -s tools/dev_tests/debug_inclinacao.gd

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	for cid in ["base", "nami"]:
		print("\n========== ", cid.to_upper(), " ==========")
		var data := CharacterBuilder.build_character(cid)
		var modelo: Node3D = data["node"]
		get_root().add_child(modelo)
		var skinnado: bool = data.get("skinned", false)
		var prof := BodyScanner.scan(modelo)
		var anim := ProceduralAnimator.new()
		modelo.add_child(anim)
		anim.setup(prof)
		var nodes: Dictionary = prof["nodes"]

		for caso in [["andando", false], ["correndo", true]]:
			var sprint: bool = caso[1]
			var vel := Vector3(0, 0, -4.2 if not sprint else -7.0)
			for i in 40:
				anim.update(vel, true, false, 1.0 / 60.0, 0.0, sprint)
			var soma_t := 0.0
			var soma_c := 0.0
			for i in 60:
				anim.update(vel, true, false, 1.0 / 60.0, 0.0, sprint)
				soma_t += -(nodes["Torso"] as Node3D).rotation.x
				soma_c += -(nodes["Head"] as Node3D).rotation.x
			# rot.x NEGATIVO = inclina pra frente -> inverti o sinal acima
			var tronco := rad_to_deg(soma_t / 60.0)
			var cabeca_local := rad_to_deg(soma_c / 60.0)
			print("  %-9s tronco %+.1f°   cabeça (local) %+.1f°   olhar resultante %+.1f°" % [
				caso[0], tronco, cabeca_local, tronco + cabeca_local])
		modelo.queue_free()
	print("\n(+ = pra frente. Alvo: tronco ~10° andando, ~19° correndo;")
	print(" olhar resultante perto de 0 pra não correr encarando o chão.)")
	quit()
