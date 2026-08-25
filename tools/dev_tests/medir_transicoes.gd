extends SceneTree
# MEDE A FLUIDEZ das transições do rig: quanto cada junta SALTA (graus num
# frame) quando o animador troca de regime. Um salto muito acima do movimento
# normal daquele frame é um ESTALO visível em jogo.
#
#   godot --headless --path . -s tools/dev_tests/medir_transicoes.gd
const DT := 1.0 / 60.0
const ROLES := ["Torso","Neck","Head","UpperArm_L","ForeArm_L","UpperArm_R","ForeArm_R",
	"Thigh_L","Shin_L","Foot_L","Thigh_R","Shin_R","Foot_R"]

var _nodes: Dictionary
var _anim

func _init() -> void:
	_run()

func _pose() -> Dictionary:
	var p := {}
	for r in _nodes:
		p[r] = (_nodes[r] as Node3D).rotation
	p["_torso_y"] = (_nodes["Torso"] as Node3D).position.y if _nodes.has("Torso") else 0.0
	return p

# maior deslocamento angular GEODÉSICO entre duas poses, em graus
func _delta(a: Dictionary, b: Dictionary) -> Array:
	var pior := 0.0
	var papel := ""
	for r in a:
		if r.begins_with("_"):
			continue
		var d: Basis = Basis.from_euler(a[r]).inverse() * Basis.from_euler(b[r])
		var g := rad_to_deg(d.get_rotation_quaternion().get_angle())
		if g > pior:
			pior = g
			papel = r
	return [pior, papel]

func _normaliza(modelo: Node3D) -> void:
	var ab := PlayerModelKit.model_aabb(modelo)
	var ky: float = 1.5 / maxf(ab.size.y, 0.01)
	modelo.scale = Vector3(ky, ky, ky)

func _run() -> void:
	await process_frame
	var data := CharacterBuilder.build_character("base")
	var modelo: Node3D = data["node"]
	get_root().add_child(modelo)
	_normaliza(modelo)
	await process_frame
	var prof := BodyScanner.scan(modelo)
	_nodes = prof["nodes"]
	_anim = ProceduralAnimator.new()
	modelo.add_child(_anim)
	_anim.setup(prof)

	var vel := Vector3(0, 0, -4.2)
	# 1) regime permanente de caminhada: qual é o passo normal por frame?
	for i in 180:
		_anim.update(vel, true, false, DT, 0.0, false)
	var normal := 0.0
	for i in 60:
		var a := _pose()
		_anim.update(vel, true, false, DT, 0.0, false)
		var d := _delta(a, _pose())
		normal = maxf(normal, float(d[0]))
	print("=== REGIME PERMANENTE (andando 4,2 m/s) ===")
	print("maior giro de junta num frame: %.2f°/frame" % normal)

	# 2) ENTRADA num clipe assado
	var clipe: Animation = load("res://assets/animations/punching.res")
	var antes := _pose()
	var torso_antes: float = antes["_torso_y"]
	_anim.play_baked(clipe)
	_anim.update(vel, true, false, DT, 0.0, false)
	var depois := _pose()
	var din := _delta(antes, depois)
	print("\n=== ENTRADA no clipe 'punching' (play_baked) ===")
	print("salto no 1º frame: %.2f° (%s)  -> %.1fx o passo normal" % [din[0], din[1], din[0] / maxf(normal, 0.001)])

	# 3) durante o clipe: o bob do torso congela?
	for i in int(clipe.length / DT) - 2:
		_anim.update(vel, true, false, DT, 0.0, false)
	var meio := _pose()
	print("torso.y  antes=%.4f  durante=%.4f  (congelado: %s)" % [
		torso_antes, meio["_torso_y"], "sim" if absf(torso_antes - meio["_torso_y"]) < 1e-6 else "nao"])

	# 4) SAÍDA do clipe (volta para a locomoção)
	var pre_saida := _pose()
	var saltos := []
	for i in 20:
		var a := _pose()
		_anim.update(vel, true, false, DT, 0.0, false)
		saltos.append(_delta(a, _pose()))
	var pior_saida := 0.0
	var papel_saida := ""
	var frame_saida := -1
	for i in saltos.size():
		if float(saltos[i][0]) > pior_saida:
			pior_saida = float(saltos[i][0])
			papel_saida = String(saltos[i][1])
			frame_saida = i
	print("\n=== SAÍDA do clipe (volta para locomoção) ===")
	print("maior salto nos 20 frames seguintes: %.2f° (%s) no frame +%d -> %.1fx o normal" % [
		pior_saida, papel_saida, frame_saida, pior_saida / maxf(normal, 0.001)])

	# 5) IDLE -> CORRIDA (transição só de peso, sem clipe)
	for i in 200:
		_anim.update(Vector3.ZERO, true, false, DT, 0.0, false)
	var pior_loco := 0.0
	var papel_loco := ""
	for i in 60:
		var a := _pose()
		_anim.update(Vector3(0, 0, -7.0), true, false, DT, 0.0, true)
		var d := _delta(a, _pose())
		if float(d[0]) > pior_loco:
			pior_loco = float(d[0])
			papel_loco = String(d[1])
	print("\n=== IDLE -> SPRINT (blend procedural) ===")
	print("maior salto: %.2f° (%s) -> %.1fx o normal" % [pior_loco, papel_loco, pior_loco / maxf(normal, 0.001)])
	quit()
