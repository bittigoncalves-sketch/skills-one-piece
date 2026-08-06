extends SceneTree
# Baker de animações Mixamo -> rig por-nós do jogo.
# Bakeia TODO .glb em res://assets/animations_glb/ para
# res://assets/animations/<nome>.res (Animation com faixas <Role>:rotation),
# tocável por ProceduralAnimator.play_baked().
#
# POR QUE GLB E NÃO FBX (descoberto em 2026-08-06): o importador FBX do Godot
# (ufbx) lê só 1 chave por osso de MEMBRO nos arquivos do Mixamo — as curvas
# existem no FBX, mas se perdem no import, e o bake saía todo ZERADO. Os .fbx
# são convertidos p/ .glb pelo Blender (tools/fbx_to_glb.py), que preserva as
# 520 fcurves, e o Godot lê glTF de forma confiável (57 chaves por osso).
#
# Pipeline completo:
#   1) blender --background --python tools/fbx_to_glb.py -- assets/animations assets/animations_glb
#   2) godot --headless --path . -s tools/bake_mixamo.gd

const MAP := {
	"Torso":["mixamorig_Spine1", ""], "Head":["mixamorig_Head","Torso"],
	"UpperArm_L":["mixamorig_LeftArm","Torso"], "ForeArm_L":["mixamorig_LeftForeArm","UpperArm_L"],
	"UpperArm_R":["mixamorig_RightArm","Torso"], "ForeArm_R":["mixamorig_RightForeArm","UpperArm_R"],
	"Thigh_L":["mixamorig_LeftUpLeg","Torso"], "Shin_L":["mixamorig_LeftLeg","Thigh_L"], "Foot_L":["mixamorig_LeftFoot","Shin_L"],
	"Thigh_R":["mixamorig_RightUpLeg","Torso"], "Shin_R":["mixamorig_RightLeg","Thigh_R"], "Foot_R":["mixamorig_RightFoot","Shin_R"],
}

const SRC_DIR := "res://assets/animations_glb/"
const OUT_DIR := "res://assets/animations/"

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var dir := DirAccess.open(SRC_DIR)
	if dir == null:
		print("✗ pasta ausente: ", SRC_DIR, " — rode antes o tools/fbx_to_glb.py")
		quit(1)
		return
	var ok := 0
	var fail := 0
	for f in dir.get_files():
		if not f.to_lower().ends_with(".glb"):
			continue
		var name := f.get_basename()
		if _bake_one(SRC_DIR + f, OUT_DIR + name + ".res"):
			ok += 1
		else:
			fail += 1
			print("  ✗ falhou: ", name)
	print("BAKE FINAL: ok=", ok, " fail=", fail)
	quit(1 if fail > 0 else 0)

func _bake_one(glb_path: String, out_path: String) -> bool:
	# GLTFDocument em runtime: pula o pipeline de import do editor.
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(glb_path), st) != OK:
		return false
	var scene = doc.generate_scene(st)
	if scene == null:
		return false
	get_root().add_child(scene)
	var skel: Skeleton3D = _find(scene, "Skeleton3D")
	var ap: AnimationPlayer = _find_ap(scene)
	if skel == null or ap == null or ap.get_animation_list().is_empty():
		scene.queue_free()
		return false
	# escolhe o clipe: prioriza "mixamo_com", senão o mais longo não-reset
	var clip := ""
	for c in ap.get_animation_list():
		if c == "mixamo_com":
			clip = c
	if clip == "":
		var best := 0.0
		for c in ap.get_animation_list():
			if c.to_lower().contains("reset"):
				continue
			if ap.get_animation(c).length >= best:
				best = ap.get_animation(c).length
				clip = c
	var src: Animation = ap.get_animation(clip)
	var dur: float = src.length
	# As faixas do glTF são "Armature/Skeleton3D:<osso>", relativas à RAIZ da
	# cena — não ao pai do esqueleto (isso quebrava a resolução das faixas).
	ap.root_node = ap.get_path_to(scene)

	var rest := {}
	for node in MAP:
		var bi := skel.find_bone(MAP[node][0])
		if bi >= 0:
			rest[node] = skel.get_bone_global_rest(bi).basis.orthonormalized()

	var fps := 30.0
	var n := int(dur * fps) + 1
	var out := Animation.new()
	out.length = dur
	var tracks := {}
	for node in MAP:
		var ti := out.add_track(Animation.TYPE_VALUE)
		out.track_set_path(ti, NodePath(node + ":rotation"))
		tracks[node] = ti
	var yflip := Basis(Vector3.UP, PI)
	ap.play(clip)
	for fr in range(n):
		var t: float = min(fr / fps, dur)
		ap.seek(t, true)
		var wdelta := {}
		for node in MAP:
			if not rest.has(node):
				continue
			var bi := skel.find_bone(MAP[node][0])
			# Compõe a pose global à mão a partir das poses LOCAIS: o
			# get_bone_global_pose() não é reavaliado logo após o seek() num
			# script headless e devolveria sempre a pose do t=0.
			var cur := _global_pose_basis(skel, bi)
			wdelta[node] = yflip * cur * rest[node].inverse() * yflip.inverse()
		for node in MAP:
			if not wdelta.has(node):
				continue
			var par: String = MAP[node][1]
			var local: Basis = wdelta[par].inverse() * wdelta[node] if (par != "" and wdelta.has(par)) else wdelta[node]
			out.track_insert_key(tracks[node], t, local.get_euler())
	var err := ResourceSaver.save(out, out_path)
	scene.queue_free()
	if err == OK:
		print("  ✓ ", out_path.get_file(), "  (", "%.2f" % dur, "s, ", n, "f)")
	return err == OK

# Pose global do osso, composta subindo a cadeia de pais pelas poses LOCAIS.
func _global_pose_basis(skel: Skeleton3D, idx: int) -> Basis:
	var b := skel.get_bone_pose(idx).basis
	var p := skel.get_bone_parent(idx)
	while p >= 0:
		b = skel.get_bone_pose(p).basis * b
		p = skel.get_bone_parent(p)
	return b.orthonormalized()

func _find(n, cls):
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r = _find(c, cls)
		if r:
			return r
	return null

func _find_ap(n):
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null
