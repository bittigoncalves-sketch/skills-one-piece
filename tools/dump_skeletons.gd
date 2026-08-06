extends SceneTree
# Diagnóstico: lista ossos dos modelos SKINNADOS e a árvore de nós dos modelos
# GLB/SCN, para conferir o mapeamento nos 13 papéis canônicos do rig A.
# Uso: godot --headless --path . -s tools/dump_skeletons.gd

const SKINNED := {
	"ace": "res://assets/models/meshy_ace/ace_meshy.fbx",
	"nami": "res://assets/models/meshy_nami/meshy_nami.fbx",
}
const MESHES := {
	"base.scn": "res://assets/models/base.scn",
	"base.glb": "res://assets/models/base.glb",
	"buggy.scn": "res://assets/models/buggy.scn",
	"buggy.glb": "res://assets/models/buggy.glb",
}
const ROLES := [
	"Torso", "Neck", "Head",
	"UpperArm_L", "ForeArm_L", "UpperArm_R", "ForeArm_R",
	"Thigh_L", "Shin_L", "Foot_L", "Thigh_R", "Shin_R", "Foot_R",
]

func _init() -> void:
	for id in MESHES:
		print("\n========== ", id, " ==========")
		var p: String = MESHES[id]
		if not ResourceLoader.exists(p) and not FileAccess.file_exists(p):
			print("  (ausente)")
			continue
		var inst: Node = null
		if p.ends_with(".glb"):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(p, st) == OK:
				inst = doc.generate_scene(st)
		else:
			var packed = load(p)
			if packed:
				inst = packed.instantiate()
		if inst == null:
			print("  (falhou ao carregar)")
			continue
		get_root().add_child(inst)
		var names: Array[String] = []
		_collect(inst, names)
		var hit: Array[String] = []
		for r in ROLES:
			if names.has(r):
				hit.append(r)
		print("  papéis do rig A encontrados: ", hit.size(), "/13  -> ", hit)
		print("  nós: ", names)
		inst.queue_free()
	quit()

func _collect(n: Node, out: Array[String]) -> void:
	out.append(String(n.name))
	for c in n.get_children():
		_collect(c, out)
