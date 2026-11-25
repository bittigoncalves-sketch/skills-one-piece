extends SceneTree
# Repouso do esqueleto do Mixamo (.glb) × o "zero" do nosso rig (rotação nula em todos os
# papéis — é o que o clipe bakeado assume). Medição de 07/10/2026; não conserta.
#   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/medir_repouso_mixamo_x_rig.gd -- punching
const SEG := {
	"braço E": [["mixamorig_LeftArm", "mixamorig_LeftForeArm"], ["UpperArm_L", "ForeArm_L"]],
	"antebraço E": [["mixamorig_LeftForeArm", "mixamorig_LeftHand"], ["ForeArm_L", "#mao_L"]],
	"braço D": [["mixamorig_RightArm", "mixamorig_RightForeArm"], ["UpperArm_R", "ForeArm_R"]],
	"antebraço D": [["mixamorig_RightForeArm", "mixamorig_RightHand"], ["ForeArm_R", "#mao_R"]],
	"coxa E": [["mixamorig_LeftUpLeg", "mixamorig_LeftLeg"], ["Thigh_L", "Shin_L"]],
	"canela E": [["mixamorig_LeftLeg", "mixamorig_LeftFoot"], ["Shin_L", "Foot_L"]],
	"coluna": [["mixamorig_Hips", "mixamorig_Neck"], ["Torso", "Head"]],
	"ombros": [["mixamorig_LeftArm", "mixamorig_RightArm"], ["UpperArm_L", "UpperArm_R"]],
}

func _init() -> void:
	_ir.call_deferred()

func _ir() -> void:
	await process_frame
	var modelo: Node3D = CharacterBuilder.build_character("base").node
	root.add_child(modelo)
	await process_frame
	var rig := BodyScanner.scan(modelo)
	var nos: Dictionary = rig.nodes
	print("rest (euler) do nosso rig: ", rig.rest)
	for papel in nos:
		(nos[papel] as Node3D).rotation = Vector3.ZERO
	var base := (nos.Torso as Node3D).get_parent() as Node3D
	var clipe: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "punching"
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path("res://assets/animations_glb/%s.glb" % clipe), st)
	var cena: Node3D = doc.generate_scene(st)
	root.add_child(cena)
	await process_frame
	var skel: Skeleton3D = cena.find_children("*", "Skeleton3D", true, false)[0]
	var vira := Basis(Vector3.UP, PI)
	for s in SEG:
		var a := _rest(skel, SEG[s][0][0])
		var b := _rest(skel, SEG[s][0][1])
		var m := (vira * (b - a)).normalized()
		var o := (base.global_transform.basis.inverse() * (_p(nos, SEG[s][1][1]) - _p(nos, SEG[s][1][0]))).normalized()
		print("%-12s mixamo %s | nosso zero %s | %.0f°" % [s, _r(m), _r(o), rad_to_deg(m.angle_to(o))])
	quit(0)

func _rest(skel: Skeleton3D, nome: String) -> Vector3:
	var i := skel.find_bone(nome)
	var t := skel.get_bone_global_rest(i)
	return skel.global_transform * t.origin

func _p(nos: Dictionary, nome: String) -> Vector3:
	if nome.begins_with("#mao_"):
		return (nos["ForeArm_" + nome.right(1)] as Node3D).global_transform * Vector3(0, -0.36, 0.02)
	return (nos[nome] as Node3D).global_position

func _r(v: Vector3) -> String:
	return "(%+.2f %+.2f %+.2f)" % [v.x, v.y, v.z]
