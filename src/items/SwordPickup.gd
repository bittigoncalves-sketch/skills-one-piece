class_name SwordPickup
extends Area3D

var _visual_node: Node3D
var _collider: CollisionShape3D

func _ready() -> void:
	# Área de colisão (1 metro de raio) para detecção de passagem
	_collider = CollisionShape3D.new()
	var shape = SphereShape3D.new()
	shape.radius = 1.0
	_collider.shape = shape
	add_child(_collider)
	
	# Construção visual da espada
	_visual_node = Node3D.new()
	_visual_node.name = "SwordVisual"
	
	# Cabo (Hilt)
	var hilt = MeshInstance3D.new()
	var hilt_mesh = CylinderMesh.new()
	hilt_mesh.top_radius = 0.03
	hilt_mesh.bottom_radius = 0.03
	hilt_mesh.height = 0.3
	hilt.mesh = hilt_mesh
	hilt.position = Vector3(0, -0.15, 0) # desloca para que a origem seja perto do centro da mão
	
	var hilt_mat = StandardMaterial3D.new()
	hilt_mat.albedo_color = Color(0.3, 0.2, 0.1)
	hilt.material_override = hilt_mat
	_visual_node.add_child(hilt)
	
	# Guarda (Guard)
	var guard = MeshInstance3D.new()
	var guard_mesh = BoxMesh.new()
	guard_mesh.size = Vector3(0.25, 0.05, 0.05)
	guard.mesh = guard_mesh
	
	var guard_mat = StandardMaterial3D.new()
	guard_mat.albedo_color = Color(0.8, 0.7, 0.1)
	guard.material_override = guard_mat
	_visual_node.add_child(guard)
	
	# Lâmina (Blade)
	var blade = MeshInstance3D.new()
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 1.2, 0.02)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, 0.6, 0)
	
	var blade_mat = StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.8, 0.8, 0.85)
	blade_mat.metallic = 0.9
	blade_mat.roughness = 0.2
	blade.material_override = blade_mat
	_visual_node.add_child(blade)
	
	add_child(_visual_node)
	
	# Conecta colisão
	body_entered.connect(_on_body_entered)
	
	# Fica flutuando e girando no mapa se solta
	set_process(true)

func _process(delta: float) -> void:
	# Gira e flutua enquanto estiver no mapa
	if not _collider.disabled:
		rotation.y += delta * 2.0
		position.y += sin(Time.get_ticks_msec() * 0.003) * 0.002

func _on_body_entered(body: Node3D) -> void:
	if _collider.disabled: return
	
	# Usa check se tem o método
	if body.has_method("equip_item"):
		# Desabilita lógica de mapa
		_collider.disabled = true
		set_process(false)
		
		# Retorna a rotação e posição da base ao normal para grudar na mão
		rotation = Vector3.ZERO
		
		# Equipa a arma
		body.equip_item(self)
		
		# Ajuste visual da espada para encaixar na mão e apontar para frente (no eixo Z ou Y dependendo da pose)
		_visual_node.rotation = Vector3(-PI/2, 0, 0)
		_visual_node.position = Vector3(0, 0, 0)
		
		print("[SwordPickup] " + body.name + " pegou a espada!")
