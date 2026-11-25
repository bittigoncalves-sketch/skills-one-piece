extends RefCounted
## Tronco inclinado e cabeça nivelada, com passos curtos e joelhos articulados.
## A proporção do Minecraft é adaptada ao rig humano sem achatar o modelo.
var peso := 0.0
var _fase := 0.0
var _solas: Array[MeshInstance3D] = []
var _mediu_solas := false


func atualizar(ativo: bool, delta: float) -> void:
	peso = lerpf(peso, 1.0 if ativo else 0.0, 1.0 - exp(-20.0 * delta))
	if peso < 0.0001:
		peso = 0.0


func aplicar(anim, off: Dictionary, velocidade: Vector3, delta: float, preservar_bracos := false) -> void:
	if peso <= 0.0:
		return
	var l1: float = maxf(anim._m.get("thigh_len", 0.3), 0.05)
	var l2: float = maxf(anim._m.get("shin_len", 0.3), 0.05)
	var perna := l1 + l2
	var andando := Vector2(velocidade.x, velocidade.z).length()
	_fase += andando * delta * 5.0
	var passo := smoothstep(0.02, 0.4, andando)
	var pose := {
		"Torso": Vector3(-0.5, 0, 0),
		"Neck": Vector3(0.15, 0, 0),
		"Head": Vector3(0.35, 0, 0),
		"UpperArm_L": Vector3(0.35 + sin(_fase) * 0.12 * passo, 0, -0.05),
		"UpperArm_R": Vector3(0.35 - sin(_fase) * 0.12 * passo, 0, 0.05),
		"ForeArm_L": Vector3(0.08, 0, 0),
		"ForeArm_R": Vector3(0.08, 0, 0),
	}
	for lado in ["L", "R"]:
		var fase := _fase + (PI if lado == "R" else 0.0)
		var frente := sin(fase) * perna * 0.18 * passo
		var altura := perna * (0.74 - maxf(cos(fase), 0.0) * 0.06 * passo)
		var d2 := altura * altura + frente * frente
		var joelho := -acos(clampf((d2 - l1*l1 - l2*l2) / (2.0*l1*l2), -1, 1))
		var coxa := atan2(frente, altura) - atan2(l2*sin(joelho), l1 + l2*cos(joelho))
		pose["Thigh_" + lado] = Vector3(coxa + 0.5, 0, 0)
		pose["Shin_" + lado] = Vector3(joelho, 0, 0)
		pose["Foot_" + lado] = Vector3(-coxa - joelho, 0, 0)
	for papel in pose:
		if preservar_bracos and ("Arm" in papel or papel in ["Head", "Neck"]):
			continue
		if preservar_bracos and papel == "Torso":
			var tronco: Vector3 = off.get(papel, Vector3.ZERO)
			pose[papel] = Vector3(tronco.x - 0.5, tronco.y, tronco.z)
		off[papel] = (off.get(papel, Vector3.ZERO) as Vector3).lerp(pose[papel], peso)

func sobrepor_clipe(anim, delta: float) -> void:
	if peso <= 0.0:
		return
	var off := {}
	for papel in anim._n:
		off[papel] = (anim._n[papel] as Node3D).rotation - (anim._rest.get(papel, Vector3.ZERO) as Vector3)
	aplicar(anim, off, Vector3.ZERO, delta, true)
	for papel in off:
		(anim._n[papel] as Node3D).rotation = (anim._rest.get(papel, Vector3.ZERO) as Vector3) + off[papel]
	apoiar(anim)
	if anim._driver:
		anim._driver.push()


func apoiar(anim) -> void:
	if peso <= 0.0 or anim._driver != null or not anim._n.has("Torso"):
		return
	var dono = anim.get_parent()
	if dono == null or not is_instance_valid(dono.get("_colisor")):
		return
	if not _mediu_solas:
		_mediu_solas = true
		for papel in ["Foot_L", "Foot_R"]:
			if anim._n.has(papel):
				var pe: Node3D = anim._n[papel]
				if pe is MeshInstance3D:
					_solas.append(pe)
				for malha in pe.find_children("*", "MeshInstance3D", true, false):
					_solas.append(malha)
	if _solas.is_empty():
		return
	# O rig detalhado tem tornozelo, calcanhar e dedos: dois ângulos de IK não
	# bastam para medir a sola real. Corrige a translação, nunca a escala.
	var torso: Node3D = anim._n.Torso
	var espaco: Node3D = torso.get_parent()
	var inversa := espaco.global_transform.affine_inverse()
	var minimo := INF
	for malha in _solas:
		var caixa := malha.get_aabb()
		var matriz := inversa * malha.global_transform
		for i in 8:
			minimo = minf(minimo, (matriz * caixa.get_endpoint(i)).y)
	var col: CollisionShape3D = dono._colisor
	var altura: float = col.shape.size.y if col.shape is BoxShape3D else col.shape.height
	var apoio := inversa * (col.global_transform * Vector3(0, -altura * 0.5, 0))
	torso.position.y += (apoio.y - minimo) * peso
