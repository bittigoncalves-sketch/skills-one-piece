extends SceneTree

func _init() -> void:
	print("--- INICIANDO TESTE AUTOMATIZADO DO GATLING (C) ---")
	var root = Node3D.new()
	root.name = "Root"
	root_set(root)
	
	var player = load("res://Player.gd").new()
	player.name = "Player"
	root.add_child(player)
	
	player.position = Vector3.ZERO
	# Força o _ready e aguarda
	player._ready()
	player.current_fruit_id = "gomu_gomu"
	player.combat_mode = "fruit"
	
	for i in range(5):
		root.propagate_notification(Node.NOTIFICATION_PROCESS)
		root.propagate_notification(Node.NOTIFICATION_PHYSICS_PROCESS)
		
	print("Pressionando C (Gatling)...")
	player._cast.comecar("C")
	
	for i in range(5):
		root.propagate_notification(Node.NOTIFICATION_PROCESS)
		root.propagate_notification(Node.NOTIFICATION_PHYSICS_PROCESS)
		
	var gatling_found = false
	for child in root.get_children():
		if child is GomuGatling:
			gatling_found = true
			break
	if gatling_found:
		print("SUCESSO: GomuGatling criado no inicio do pressionar!")
	else:
		print("FALHA: GomuGatling nao criado!")
		
	print("Soltando C (Abortar)...")
	player._cast.soltar("C")
	
	for i in range(5):
		root.propagate_notification(Node.NOTIFICATION_PROCESS)
		root.propagate_notification(Node.NOTIFICATION_PHYSICS_PROCESS)
		
	var gatling_still_there = false
	for child in root.get_children():
		if child is GomuGatling and not child.is_queued_for_deletion():
			gatling_still_there = true
	
	if not gatling_still_there:
		print("SUCESSO: GomuGatling deletado/abortado apos soltar C!")
	else:
		print("FALHA: GomuGatling continuou ativo apos soltar C!")

	print("--- TESTE CONCLUIDO ---")
	quit(0)

func root_set(r: Node):
	root.add_child(r)
