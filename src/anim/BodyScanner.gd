class_name BodyScanner
extends RefCounted
# Fase 0 do sistema de animação procedural: VARRE o rig do personagem e mede o
# corpo, devolvendo um "SkeletonProfile" que o ProceduralAnimator usa para
# escalar passada, balanço e IK ao porte real do personagem.
#
# Papéis esperados (nomes dos nós do rig articulado):
const ROLES := [
	"Torso", "Neck", "Head",
	"UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R",
	"Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R",
]

# ------------------------------------------------------- RIG DETALHADO (v2)
# Os 13 papéis acima são o CONTRATO do rig A: é o que o SkeletonDriver mapeia em
# osso de Meshy, o que o `tools/bake_mixamo.gd` retargeta e o que todo golpe
# autoral escreve. Ele não muda.
#
# O `base_v2` (08/09/2026) trouxe coluna, cintura escapular, punho, mão com
# dedos e antepé. Esses papéis extras entram em `nodes` COMO OS OUTROS — o
# animador nem sabe que são de outra safra —, mas só quando a cadeia INTEIRA
# está presente (`RigDetalhado.tem_cadeia`). Duas razões para exigir a cadeia:
#
#  1. Meio-rig é pior que rig nenhum. A contra-rotação do tronco depende de
#     `Chest`; o desenrolar do pé depende de `Ball`. Aplicar um sem o outro dá
#     pose quebrada, não pose parcial.
#  2. Um nome solto pode ser de outra coisa. `Hand_R`, por exemplo, é o nome que
#     o `PlayerRig` dá à âncora de item nos rigs ANTIGOS — girá-lo lá levaria a
#     espada junto. Exigindo a cadeia, esse caso nunca é confundido com um rig
#     detalhado (medido: buggy resolve 8 de 36 nomes, todos do rig A; nami, 0).

# Devolve: { nodes:{papel:Node3D}, rest:{papel:Vector3(rot)}, metrics:{...},
#            driver:SkeletonDriver|null }
#
# Dois tipos de corpo, MESMO contrato de saída:
#  - voxel (.scn/.glb): os nós já se chamam Torso/UpperArm_L/… — usa direto.
#  - skinnado (Skeleton3D, ex. Meshy AI): não há nós pra girar, então o
#    SkeletonDriver cria 13 proxies e depois copia a rotação deles pros ossos.
# O ProceduralAnimator recebe os dois iguais e não sabe a diferença.
static func scan(model_root: Node3D) -> Dictionary:
	# DOIS dicionários, e a separação é obrigatória: é `found` (só o rig A) que
	# decide se este corpo é voxel ou skinnado, logo abaixo. Deixar as juntas
	# finas caírem nele faria um modelo com um nome parecido escapar do
	# SkeletonDriver e ficar sem animação nenhuma.
	var found: Dictionary = {}
	var finas: Dictionary = {}
	_collect(model_root, found, finas)

	var nodes: Dictionary = {}
	var rest: Dictionary = {}
	var driver: SkeletonDriver = null

	if found.is_empty():
		var skel := _find_skeleton(model_root)
		if skel:
			driver = SkeletonDriver.new()
			driver.name = "SkeletonDriver"
			model_root.add_child(driver)
			nodes = driver.setup(skel, model_root, model_root.get_meta("bone_map", {}))
			if not driver.is_valid():
				push_warning("[BodyScanner] Skeleton3D sem ossos reconhecíveis: " + String(model_root.name))
				driver = null
				nodes = {}
	else:
		for role in ROLES:
			if found.has(role):
				nodes[role] = found[role]
		if RigDetalhado.tem_cadeia(finas):
			for role in finas:
				nodes[role] = finas[role]

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

static func _collect(n: Node, rig_a: Dictionary, finas: Dictionary) -> void:
	if n is Node3D:
		var nome := String(n.name)
		if ROLES.has(nome):
			rig_a[nome] = n
		elif RigDetalhado.PAPEIS.has(nome):
			finas[nome] = n
	for c in n.get_children():
		_collect(c, rig_a, finas)

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
