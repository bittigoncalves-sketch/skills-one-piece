extends SceneTree
## Akuma no Mi em voxel (25/11/2026): toda fruta do manifesto tem `assets/models/akuma_no_mi/<id>.glb` que carrega, e
## `TreeAndFruitGenerator.create_fruit_3d` usa o modelo próprio (nó "Modelo" + PickupArea), com tamanho de pickup.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_akuma_no_mi_modelos.gd
var falhas := 0
var total := 0


func ok(c: bool, m: String) -> void:
	total += 1
	if not c:
		falhas += 1
		print("FALHA ", m)


func _init() -> void:
	var dados: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art_src/akuma_no_mi/manifesto.json"))
	var frutas: Array = dados["frutas"]
	ok(frutas.size() >= 44, "manifesto com %d frutas" % frutas.size())
	ok(TreeAndFruitGenerator.id_do_modelo("hito_hito_nika") == "gomu_gomu", "Nika usa o modelo do Gomu Gomu")
	ok(TreeAndFruitGenerator.id_do_modelo("pika_pika_no_mi_mine_piece") == "pika_pika", "alias *_no_mi_mine_piece")
	ok(TreeAndFruitGenerator.id_do_modelo("goro_goro_mine_piece") == "goro_goro", "alias *_mine_piece")
	ok(frutas.any(func(f): return f["id"] == "magu_magu"), "magu_magu no manifesto")
	for f: Dictionary in frutas:
		var id := str(f["id"])
		var cena := load("res://assets/models/akuma_no_mi/%s.glb" % id) as PackedScene
		ok(cena != null, "%s: sem glb" % id)
		if TreeAndFruitGenerator.PICKUPS_AUTORAIS.has(id):
			continue                                     # pickup autoral (script próprio) tem prioridade; o glb fica de reserva
		var raiz := TreeAndFruitGenerator.create_fruit_3d({"id": id, "fruit_color": Color(f["cor"]), "fruit_glow": Color(f["brilho"])})
		ok(raiz.get_node_or_null("Modelo") != null, "%s: pickup não usa o modelo próprio" % id)
		ok(raiz.get_node_or_null("PickupArea") != null, "%s: sem PickupArea" % id)
		var caixa := AABB()
		var primeiro := true
		for mi in raiz.find_children("*", "MeshInstance3D", true, false):
			var a := (mi as MeshInstance3D).get_aabb()
			caixa = a if primeiro else caixa.merge(a)
			primeiro = false
		ok(not primeiro and caixa.size.y > 0.4 and caixa.size.y < 1.0 and caixa.size.x < 1.0, "%s: tamanho estranho %s" % [id, caixa.size])
		raiz.free()
	print("AKUMA_NO_MI %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
