class_name BodyScanner
extends RefCounted
# Fase 0 do sistema de animação procedural: VARRE o rig do personagem e mede o
# corpo, devolvendo um "SkeletonProfile" que o ProceduralAnimator usa para
# escalar passada, balanço e IK ao porte real do personagem.
#
# Papéis esperados (nomes dos nós do rig articulado):
# A lista mora em `src/anim/RigContrato.gd` (fonte única: papéis + hierarquia
# + aliases de osso). Aqui fica só o apelido que o resto do código já usava.
const ROLES := RigContrato.PAPEIS

# Devolve: { nodes:{papel:Node3D}, rest:{papel:Vector3(rot)}, metrics:{...},
#            driver:SkeletonDriver|null }
#
# Dois tipos de corpo, MESMO contrato de saída:
#  - voxel (.scn/.glb): os nós já se chamam Torso/UpperArm_L/… — usa direto.
#  - skinnado (Skeleton3D, ex. Meshy AI): não há nós pra girar, então o
#    SkeletonDriver cria 13 proxies e depois copia a rotação deles pros ossos.
# O ProceduralAnimator recebe os dois iguais e não sabe a diferença.
static func scan(model_root: Node3D) -> Dictionary:
	var found: Dictionary = {}
	_collect(model_root, found)

	var nodes: Dictionary = {}
	var rest: Dictionary = {}
	var driver: SkeletonDriver = null

	if found.is_empty():
		var skel := _find_skeleton(model_root)
		if skel:
			driver = SkeletonDriver.new()
			driver.name = "SkeletonDriver"
			model_root.add_child(driver)
			nodes = driver.setup(skel, model_root)
			if not driver.is_valid():
				push_warning("[BodyScanner] Skeleton3D sem ossos reconhecíveis: " + String(model_root.name))
				driver = null
				nodes = {}
	else:
		for role in ROLES:
			if found.has(role):
				nodes[role] = found[role]

	for role in nodes:
		rest[role] = (nodes[role] as Node3D).rotation   # pose de descanso (offset base)

	var metrics := _measure(nodes)
	return {"nodes": nodes, "rest": rest, "metrics": metrics, "driver": driver}

static func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skeleton(c)
		if r:
			return r
	return null

static func _collect(n: Node, out: Dictionary) -> void:
	if n is Node3D and ROLES.has(String(n.name)):
		out[String(n.name)] = n
	for c in n.get_children():
		_collect(c, out)

static func _measure(nodes: Dictionary) -> Dictionary:
	var m: Dictionary = {}
	# comprimentos dos segmentos (distância entre pivôs, no mundo)
	m["thigh_len"] = _dist(nodes, "Thigh_L", "Shin_L", 0.35)
	m["shin_len"]  = _dist(nodes, "Shin_L", "Foot_L", 0.35)
	m["upper_arm"] = _dist(nodes, "UpperArm_L", "ForeArm_L", 0.30)
	m["leg_len"]   = m["thigh_len"] + m["shin_len"]
	# altura do quadril (Torso) e largura dos ombros — úteis p/ amplitude/IK
	if nodes.has("Torso"):
		m["hip_h"] = (nodes["Torso"] as Node3D).global_position.y
	if nodes.has("UpperArm_L") and nodes.has("UpperArm_R"):
		m["shoulder_w"] = (nodes["UpperArm_L"] as Node3D).global_position.distance_to(
			(nodes["UpperArm_R"] as Node3D).global_position)
	return m

static func _dist(nodes: Dictionary, a: String, b: String, fallback: float) -> float:
	if nodes.has(a) and nodes.has(b):
		var d := (nodes[a] as Node3D).global_position.distance_to((nodes[b] as Node3D).global_position)
		if d > 0.01:
			return d
	return fallback
