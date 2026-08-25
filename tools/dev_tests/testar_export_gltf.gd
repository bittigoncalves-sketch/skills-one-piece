extends SceneTree
# PROVA de que o formato dos .res é o que impede a ida ao Blender.
#
#  A) quantas faixas do .res resolvem como NodePath real no rig?
#  B) reescrevendo o caminho para a forma HIERÁRQUICA, o mesmo clipe exporta
#     glTF inteiro — 13 canais de quaternion que o Blender importa nativo.
#
# ⚠️ Foi este script que mediu o achado 1 da `docs/AUDITORIA_ANIMACAO.md`: com o
# caminho PLANO antigo, (A) dava **1/13**. Depois do rebake de 2026-08-25 os
# `.res` já saem hierárquicos, então (A) dá 13/13 e (B) vira uma tautologia —
# ele fica como a prova reproduzível do diagnóstico, não como teste de regressão
# (esse é o `test_ida_e_volta_blender.gd`).
#
#   godot --headless --path . -s tools/dev_tests/testar_export_gltf.gd
const PAI := RigContrato.PAI
const CLIPE := "res://assets/animations/punching.res"

func _init() -> void:
	var anim: Animation = load(CLIPE)
	print("=== ENTRADA: ", CLIPE.get_file(), " — ", anim.get_track_count(), " faixas, %.2fs" % anim.length)
	print("    path[0] = ", anim.track_get_path(0), "  tipo=", anim.track_get_type(0), " (0 = TYPE_VALUE)")

	var root := Node3D.new()
	root.name = "CharacterRoot"
	var nos := {}
	for r in PAI:
		nos[r] = Node3D.new()
		(nos[r] as Node3D).name = r
	for r in PAI:
		if PAI[r] == "":
			root.add_child(nos[r])
		else:
			nos[PAI[r]].add_child(nos[r])
	get_root().add_child(root)

	var resolve := 0
	for i in anim.get_track_count():
		if root.get_node_or_null(NodePath(String(anim.track_get_path(i)).get_slice(":", 0))) != null:
			resolve += 1
	print("\nA) faixas do .res que resolvem como NodePath real: ", resolve, "/", anim.get_track_count())

	var conv := Animation.new()
	conv.length = anim.length
	var chaves_orig := 0
	for i in anim.get_track_count():
		var role := String(anim.track_get_path(i)).get_slice(":", 0)
		var ti := conv.add_track(Animation.TYPE_VALUE)
		conv.track_set_path(ti, RigContrato.faixa(role))
		conv.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		for k in anim.track_get_key_count(i):
			conv.track_insert_key(ti, anim.track_get_key_time(i, k), anim.track_get_key_value(i, k))
			chaves_orig += 1

	var lib := AnimationLibrary.new()
	lib.add_animation(CLIPE.get_file().get_basename(), conv)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.add_animation_library("", lib)
	ap.root_node = NodePath("..")
	for r in nos:
		(nos[r] as Node3D).owner = root
	ap.owner = root

	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	print("\nB) append_from_scene err=", doc.append_from_scene(root, st))
	var out := OS.get_user_data_dir() + "/export_gltf_teste.gltf"
	print("   write err=", doc.write_to_filesystem(st, out), " -> ", out)

	var st2 := GLTFState.new()
	var doc2 := GLTFDocument.new()
	if doc2.append_from_file(out, st2) == OK:
		var cena = doc2.generate_scene(st2)
		var ap2 = _find_ap(cena)
		if ap2:
			for c in ap2.get_animation_list():
				var a2: Animation = ap2.get_animation(c)
				var tot := 0
				for i in a2.get_track_count():
					tot += a2.track_get_key_count(i)
				print("   reimport '%s': faixas=%d dur=%.2fs chaves=%d (original %d)" % [
					c, a2.get_track_count(), a2.length, tot, chaves_orig])
				for i in mini(a2.get_track_count(), 4):
					print("     ", a2.track_get_path(i), " tipo=", a2.track_get_type(i),
						" (2 = TYPE_ROTATION_3D) chaves=", a2.track_get_key_count(i))
		else:
			print("   ✗ sem AnimationPlayer no reimport")
	quit()

func _find_ap(n):
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r:
			return r
	return null
