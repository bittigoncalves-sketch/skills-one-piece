extends SceneTree
## Fonte reproduzível dos clipes do dash; rotações em radianos sobre o rig do jogo.
## godot --headless --path . --script tools/gerar_dash_aereo.gd

const DIRETORIO := "res://assets/animations/dash_aereo/"
const PAPEIS := ["Torso", "Neck", "Head", "UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R", "Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R"]
const TEMPOS := [0.0, 0.045, 0.095, 0.17, 0.28]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIRETORIO))
	for direcao in ["frente", "tras", "esquerda", "direita"]:
		for alternada in [false, true]:
			var clip := Animation.new()
			clip.length = 0.28
			var poses := _poses(direcao)
			if alternada:
				for i in poses.size():
					poses[i] = _outra_perna(poses[i])
			for papel in PAPEIS:
				var faixa := clip.add_track(Animation.TYPE_VALUE)
				clip.track_set_path(faixa, NodePath(papel + ":rotation"))
				for i in TEMPOS.size():
					clip.track_insert_key(faixa, TEMPOS[i], poses[i].get(papel, Vector3.ZERO))
			var caminho: String = DIRETORIO + direcao + ("_alternado" if alternada else "") + ".tres"
			var err := ResourceSaver.save(clip, caminho)
			if err != OK:
				push_error("Erro ao salvar " + caminho + ": " + str(err))
				quit(1)
				return
	print("Clipes de dash criados em ", DIRETORIO)
	quit(0)


func _poses(direcao: String) -> Array[Dictionary]:
	# Antecipação, contato do pé, propulsão e recuperação. As pernas alternam;
	# o espelhamento lateral troca os membros e inverte a inclinação do corpo.
	# A pose da esquerda é espelhada abaixo; aqui partimos sempre da direita.
	var lado := 1.0
	var lateral := direcao in ["esquerda", "direita"]
	var tras := direcao == "tras"
	var tronco := Vector3(-0.32 if not tras else 0.26, 0.0, -0.34 * lado if lateral else 0.0)
	var recolhe := {
		"Torso": tronco * 0.55, "Head": -tronco * 0.20,
		"UpperArm_L": Vector3(-0.55, 0, 0.24), "ForeArm_L": Vector3(-0.55, 0, 0),
		"UpperArm_R": Vector3(0.42, 0, -0.24), "ForeArm_R": Vector3(-0.45, 0, 0),
		"Thigh_L": Vector3(-0.55 if not tras else 0.50, 0, 0.12 * lado if lateral else 0.0),
		"Shin_L": Vector3(-1.12, 0, 0), "Foot_L": Vector3(-0.25, 0, 0),
		"Thigh_R": Vector3(0.34, 0, -0.12 * lado if lateral else 0.0), "Shin_R": Vector3(-0.58, 0, 0),
	}
	var chute := recolhe.duplicate()
	chute["Torso"] = tronco
	# O pé empurra o ar para trás do movimento; o corpo segue em sentido oposto.
	chute["Thigh_L"] = Vector3(-1.05 if not tras else 1.05, 0, -0.72 * lado if lateral else 0.0)
	chute["Shin_L"] = Vector3(-0.12, 0, 0)
	chute["Foot_L"] = Vector3(0.32 if not tras else -0.30, 0, 0)
	chute["Thigh_R"] = Vector3(0.48 if not tras else -0.48, 0, 0.18 * lado if lateral else 0.0)
	chute["Shin_R"] = Vector3(-0.9, 0, 0)
	var voo := chute.duplicate()
	voo["Torso"] = tronco * 0.8
	voo["Thigh_L"] = (chute["Thigh_L"] as Vector3) * 0.70
	voo["Shin_L"] = Vector3(-0.32, 0, 0)
	var fim := {"Torso": tronco * 0.2, "Thigh_L": Vector3(-0.16, 0, 0), "Shin_L": Vector3(-0.25, 0, 0), "Thigh_R": Vector3(0.16, 0, 0), "Shin_R": Vector3(-0.25, 0, 0)}
	if direcao == "esquerda":
		recolhe = _trocar_lados(recolhe)
		chute = _trocar_lados(chute)
		voo = _trocar_lados(voo)
		fim = _trocar_lados(fim)
	return [{}, recolhe, chute, voo, fim]


func _trocar_lados(pose: Dictionary) -> Dictionary:
	var saida := {}
	for papel in pose:
		var destino: String = papel
		if papel.ends_with("_L"):
			destino = papel.trim_suffix("_L") + "_R"
		elif papel.ends_with("_R"):
			destino = papel.trim_suffix("_R") + "_L"
		var v: Vector3 = pose[papel]
		saida[destino] = Vector3(v.x, -v.y, -v.z)
	return saida


func _outra_perna(pose: Dictionary) -> Dictionary:
	# Preserva a direção do tronco e do chute: só troca o membro que empurra.
	var saida := pose.duplicate()
	for membro in ["Thigh", "Shin", "Foot"]:
		var esquerda: Vector3 = pose.get(membro + "_L", Vector3.ZERO)
		var direita: Vector3 = pose.get(membro + "_R", Vector3.ZERO)
		saida[membro + "_L"] = direita
		saida[membro + "_R"] = esquerda
	# Braços contrabalançam a perna oposta; não invertem a direção do tronco.
	for membro in ["UpperArm", "ForeArm"]:
		var esquerda: Vector3 = pose.get(membro + "_L", Vector3.ZERO)
		var direita: Vector3 = pose.get(membro + "_R", Vector3.ZERO)
		saida[membro + "_L"] = Vector3(direita.x, -direita.y, -direita.z)
		saida[membro + "_R"] = Vector3(esquerda.x, -esquerda.y, -esquerda.z)
	return saida
