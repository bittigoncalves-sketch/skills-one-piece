extends SceneTree
# ============================================================================
#  POSES BÁSICAS DO SKILLS BUILDER — medidas no rig (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_poses_basicas.gd
#
#  Pedido do dono: "adicionar poses básicas ao criador de skills". Cada pose é aplicada
#  no Base (o rig do jogador) como o editor aplica (repouso + graus) e as MÃOS, os PÉS e a
#  cabeça são medidos no espaço do modelo (frente = −Z, direita = +X, chão ≈ 0). A pose
#  tem de fazer o que o nome diz (a convenção dos braços já trocou de sinal antes neste
#  projeto: mãos para trás na escalada — `feedback_convencao_bracos_rig`). E o botão
#  "Poses básicas" do editor põe a escolhida na skill.
# ============================================================================

const Basicas := preload("res://src/skills_builder/poses_basicas.gd")

var _ok_n := 0
var _falhas := 0
var nos: Dictionary
var rest: Dictionary
var base: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modelo: Node3D = CharacterBuilder.build_character("base").node
	root.add_child(modelo)
	await process_frame
	var rig := BodyScanner.scan(modelo)
	nos = rig.nodes
	rest = rig.rest
	base = (nos.Torso as Node3D).get_parent() as Node3D
	_ok("12 poses básicas (%s)" % str(Basicas.nomes()), Basicas.nomes().size() == 12)
	var criterios := {
		"Guarda": func(m): return m.md.z < -0.1 and m.me.z < -0.1 and m.md.y > 1.2 and m.me.y > 1.2 and absf(m.md.x) < 0.35 and absf(m.me.x) < 0.35,
		"Soco direito": func(m): return m.md.z < -0.55 and m.md.y > 1.25 and m.md.y < 1.65 and m.me.y > 1.15,
		"Soco esquerdo": func(m): return m.me.z < -0.55 and m.me.y > 1.25 and m.me.y < 1.65 and m.md.y > 1.15,
		"Chute frontal": func(m): return m.pd.z < -0.5 and m.pd.y > 0.6,
		"Apontar": func(m): return m.md.z < -0.55 and m.md.y > 1.3 and m.md.y < 1.6,
		"Braços abertos": func(m): return m.md.x > 0.8 and m.me.x < -0.8 and m.md.y > 1.25 and m.me.y > 1.25,
		"Mãos ao céu": func(m): return m.md.y > 1.9 and m.me.y > 1.9,
		"Defesa cruzada": func(m): return m.md.z < -0.15 and m.me.z < -0.15 and m.md.y > 1.2 and m.me.y > 1.2 and m.md.x < 0.12 and m.me.x > -0.12,
		"Base baixa": func(m): return m.pd.y < 0.5 and m.pe.y < 0.5 and m.md.z < -0.1 and m.me.z < -0.1,
		"Investida": func(m): return m.md.z > 0.1 and m.me.z > 0.1 and m.pd.z > 0.1 and m.pe.z < -0.1,
		"Carregar (mãos juntas)": func(m): return absf(m.md.x) < 0.18 and absf(m.me.x) < 0.18 and m.md.z < -0.2 and m.md.y > 0.95 and m.md.y < 1.5,
		"Arremessar": func(m): return m.md.y > 1.6 and m.md.z > -0.3 and m.me.z < -0.4,
	}
	for nome in Basicas.nomes():
		var m := _medir(Basicas.ossos(nome))
		var cond: Callable = criterios.get(nome, func(_m): return false)
		_ok("%-22s mãoD %s mãoE %s péD %s péE %s" % [nome, _v(m.md), _v(m.me), _v(m.pd), _v(m.pe)], cond.call(m))

	# O botão do editor.
	root.get_node("GameFlow").start_skills_builder()
	for i in 60:
		await process_frame
	var ed := current_scene
	ed.call("_mostrar_secao", "poses")
	for i in 3:
		await process_frame
	var menu := ed.find_child("PosesBasicas", true, false)
	_ok("a seção Poses tem o botão \"Poses básicas\"", menu != null)
	if menu != null:
		menu.call("emit_signal", "escolhida", "Braços abertos") if menu.has_signal("escolhida") else ed.get("_poses").call("adicionar_basica", "Braços abertos")
		for i in 3:
			await process_frame
		var poses: Array = (ed.get("skill") as Dictionary).get("poses", [])
		var achou := false
		for p in poses:
			achou = achou or (str(p.nome) == "Braços abertos" and (p.ossos as Dictionary).get("UpperArm_R", [0, 0, 0])[2] == 85)
		_ok("escolher \"Braços abertos\" põe a pose na skill (%d poses)" % poses.size(), achou)
	print("\nPOSES_BASICAS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _medir(ossos: Dictionary) -> Dictionary:
	for papel in nos:
		(nos[papel] as Node3D).rotation = rest.get(papel, Vector3.ZERO)
	for papel in ossos:
		if nos.has(papel):
			var g: Array = ossos[papel]
			(nos[papel] as Node3D).rotation = (rest.get(papel, Vector3.ZERO) as Vector3) \
				+ Vector3(deg_to_rad(float(g[0])), deg_to_rad(float(g[1])), deg_to_rad(float(g[2])))
	var inv := base.global_transform.affine_inverse()
	return {"md": inv * ((nos.ForeArm_R as Node3D).global_transform * Vector3(0, -0.36, 0.02)),
		"me": inv * ((nos.ForeArm_L as Node3D).global_transform * Vector3(0, -0.36, 0.02)),
		"pd": inv * (nos.Foot_R as Node3D).global_position, "pe": inv * (nos.Foot_L as Node3D).global_position}


func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
