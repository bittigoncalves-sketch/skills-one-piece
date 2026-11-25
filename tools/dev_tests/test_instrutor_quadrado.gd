extends SceneTree
# Instrutor do treino em corpo de CAIXAS estilo Minecraft (21/11/2026). Rodar:
#   godot --headless --path . --script tools/dev_tests/test_instrutor_quadrado.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _init() -> void:
	await process_frame
	print("\n===== INSTRUTOR QUADRADO =====")
	var n := NpcDaIlha.new()
	n.tipo = "npc_treinador"
	root.add_child(n)
	await process_frame
	var corpo := n.get_node("Corpo")
	ok("corpo marcado como corpo_historia", corpo.has_meta("corpo_historia"))
	var malhas := n.find_children("*", "MeshInstance3D", true, false)
	var visiveis := malhas.filter(func(m): return m.is_visible_in_tree())
	ok("há malhas", visiveis.size() > 10)
	ok("faixa ocre presente", n.find_child("FaixaOcre", true, false) != null)
	ok("ataduras nos dois punhos", n.find_children("Atadura", "MeshInstance3D", true, false).size() == 2)
	var mangas := n.find_children("Manga", "MeshInstance3D", true, false)
	ok("sem mangas (colete)", mangas.all(func(m): return not m.visible))
	ok("sem pistoleiras", n.find_child("MeraPistolHolsters", true, false) == null or not n.find_child("MeraPistolHolsters", true, false).visible)
	# tamanho: pés no chão e altura entre 1,8 e 2,1 m
	var lo := 1e9; var hi := -1e9
	for m in visiveis:
		var a: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).mesh.get_aabb()
		lo = min(lo, a.position.y); hi = max(hi, a.end.y)
	print("  altura %.2f m, sola em y=%.3f" % [hi - lo, lo])
	ok("pés no chão (±3 cm)", absf(lo) < 0.03)
	ok("altura entre 1,8 e 2,1 m", hi - lo > 1.8 and hi - lo < 2.1)
	# animações: função pura
	var V := load("res://src/historia/treino/visual_do_instrutor.gd")
	var guarda: Dictionary = V.pose_animada(1.0, false)
	var combo: Dictionary = V.pose_animada(5.15, false)
	var aponta: Dictionary = V.pose_animada(9.0, false)
	var gancho: Dictionary = V.pose_animada(12.2, false)
	var fala: Dictionary = V.pose_animada(1.0, true)
	ok("a pose tem os ossos do rig", guarda.has("UpperArm_R") and guarda.has("Thigh_L") and guarda.has("Head"))
	ok("jab esquerdo estende o braço E (ombro > 60°)", (combo["UpperArm_L"] as Vector3).x > deg_to_rad(60.0) and (guarda["UpperArm_L"] as Vector3).x < deg_to_rad(45.0))
	ok("aponta: braço D na horizontal", (aponta["UpperArm_R"] as Vector3).x > deg_to_rad(80.0))
	ok("gancho gira o tronco além da guarda", (gancho["Torso"] as Vector3).y > (guarda["Torso"] as Vector3).y + deg_to_rad(10.0))
	ok("falando muda a pose (braço E relaxa)", (fala["UpperArm_L"] as Vector3).x < (guarda["UpperArm_L"] as Vector3).x - deg_to_rad(15.0))
	var finito := true
	for i in 1400:
		for osso in V.pose_animada(i * 0.01, i % 2 == 0):
			var v: Vector3 = V.pose_animada(i * 0.01, i % 2 == 0)[osso]
			finito = finito and is_finite(v.x + v.y + v.z) and v.length() < 3.0
	ok("pose finita e sem salto absurdo em todo o ciclo", finito)
	var t0: Dictionary = V.pose_animada(0.0, false)
	var t14: Dictionary = V.pose_animada(AnimacoesDoInstrutor.PERIODO, false)
	ok("ciclo fecha (t=0 e t=período iguais)", (t0["Torso"] as Vector3).distance_to(t14["Torso"]) < 0.02)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
