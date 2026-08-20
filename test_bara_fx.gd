extends SceneTree

func _init():
	print("========================================")
	print("Iniciando testes automatizados BaraFX...")
	print("========================================")
	
	var root = Node3D.new()
	root.name = "TestRoot"
	get_root().add_child(root)
	
	var caster = CharacterBody3D.new()
	caster.name = "TestCaster"
	root.add_child(caster)
	
	print("\n--- Testando Corte Único (Z) ---")
	BaraFX.cast(root, Vector3.ZERO, Vector3.FORWARD, 0, 10.0, caster)
	await create_timer(0.2).timeout
	
	var dz = _find_damage_zone(root)
	if dz != null:
		print("[Z] DamageZone criado com sucesso.")
		if _find_mesh_type(dz, "TorusMesh"):
			print("[Z] TorusMesh (Corte) verificado na estilização extrema.")
		else:
			print("[Z-ERRO] Faltando TorusMesh!")
		dz.queue_free()
	else:
		print("[Z-ERRO] Falha ao criar Z.")
		
	print("\n--- Testando Buggy Ball / Fuga (X) ---")
	BaraFX.cast(root, Vector3.ZERO, Vector3.FORWARD, 1, 10.0, caster)
	await create_timer(0.2).timeout
	dz = _find_damage_zone(root)
	if dz != null:
		print("[X] DamageZone criado com sucesso.")
		if _find_mesh_type(dz, "SphereMesh"):
			print("[X] SphereMesh (Núcleo) verificado.")
		if _find_mesh_type(dz, "TorusMesh"):
			print("[X] TorusMeshes (Anéis mágicos) verificados na estilização extrema.")
		dz.queue_free()
	else:
		print("[X-ERRO] Falha ao criar X.")
		
	print("\n--- Testando Área Cortante (C) ---")
	caster.set_meta("bara_cleave_active", true)
	BaraFX.cast(root, Vector3.ZERO, Vector3.FORWARD, 2, 10.0, caster)
	await create_timer(0.5).timeout
	var cleave = caster.get_node_or_null("BaraCleaveController")
	if cleave != null:
		print("[C] BaraCleaveController associado ao caster.")
		var floor_quad = _find_mesh_type(cleave, "PlaneMesh")
		if floor_quad:
			print("[C] PlaneMesh (Piscina de sangue) verificado na estilização extrema.")
	else:
		print("[C-ERRO] BaraCleaveController não foi injetado no caster.")
	
	print("\n--- Testando Expansão de Domínio (V) ---")
	BaraFX.cast(root, Vector3.ZERO, Vector3.FORWARD, 3, 10.0, caster)
	await create_timer(0.2).timeout
	var dominio = root.get_node_or_null("BaraDomainController")
	if dominio != null:
		print("[V] BaraDomainController spawnado no World.")
		if _find_mesh_type(caster, "BoxMesh"):
			print("[V] BoxMesh (Base do Santuário) instanciado nas costas do caster.")
	else:
		print("[V-ERRO] BaraDomainController falhou.")

	print("\n========================================")
	print("Testes finalizados.")
	print("========================================")
	quit()

func _find_damage_zone(parent: Node) -> Node:
	for c in parent.get_children():
		if c.get_class() == "Area3D" or c is DamageZone:
			return c
	return null

func _find_mesh_type(parent: Node, type_name: String) -> bool:
	for c in parent.get_children():
		if c is MeshInstance3D and c.mesh and c.mesh.get_class() == type_name:
			return true
		if _find_mesh_type(c, type_name):
			return true
	return false
