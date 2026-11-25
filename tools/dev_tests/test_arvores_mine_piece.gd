extends SceneTree
# ============================================================================
#  ÁRVORES DAS FRUTAS DO MINE PIECE NA ARENA (18/10/2026, docs/MINE_PIECE_SISTEMAS_PLANO.md, F4).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_arvores_mine_piece.gd
#
#  • as 4 frutas Mine Piece têm árvore e entram ALÉM das `TREE_COUNT` (as de antes ficam no
#    mesmo bloco e giro);
#  • na arena de verdade, encostar na fruta equipa a fruta Mine Piece.
# ============================================================================

const IDS := ["pika_pika_no_mi_mine_piece", "hie_hie_no_mi_mine_piece", "moku_moku_no_mi_mine_piece",
	"nikyu_nikyu_no_mi_mine_piece"]

var total := 0
var falhas := 0


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func _init() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	await process_frame
	var extras := TreeAndFruitGenerator.get_tree_definitions_mine_piece()
	ok(extras.map(func(d): return d["id"]) == IDS, "as 4 frutas Mine Piece têm árvore (%d)" % extras.size())

	# A distribuição de antes, refeita aqui (a conta do TreeScatter até 17/10), contra a nova.
	var blocos: Array = []
	for i in 40:
		blocos.append({"x": float(i * 5), "top": 1.0, "z": float(i % 7)})
	var defs := TreeAndFruitGenerator.get_tree_definitions()
	var rng := RandomNumberGenerator.new()
	rng.seed = 771026
	var idxs: Array = range(blocos.size())
	for i in range(idxs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = idxs[i]
		idxs[i] = idxs[j]
		idxs[j] = t
	var antes: Array = []
	for k in 11:
		antes.append([defs[k % defs.size()]["id"], blocos[idxs[k]]["x"], rng.randf_range(0.0, TAU)])
	var raiz := Node3D.new()
	root.add_child(raiz)
	TreeScatter.scatter(raiz, blocos, 11, 771026)
	var arvores := raiz.get_children()
	ok(arvores.size() == 15, "11 de sempre + 4 Mine Piece (%d)" % arvores.size())
	var iguais := true
	for k in 11:
		var a: Node3D = arvores[k]
		iguais = iguais and a.name == "Tree_" + str(antes[k][0]) and is_equal_approx(a.position.x, antes[k][1]) \
			and is_equal_approx(a.rotation.y, antes[k][2])
	ok(iguais, "as 11 de antes no mesmo bloco, fruta e giro")
	var nomes := arvores.slice(11).map(func(a): return String(a.name).trim_prefix("Tree_"))
	ok(nomes == IDS, "as 4 novas vêm depois, uma de cada (%s)" % str(nomes))
	raiz.free()

	print("\n-- arena de verdade --")
	root.get_node("GameFlow").start_singleplayer()
	for i in 240:
		await physics_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	var jogador: Node3D = null
	for p in get_nodes_in_group("player"):
		if p.is_multiplayer_authority():
			jogador = p
	ok(jogador != null, "jogador na arena")
	for id in IDS:
		var fruta := current_scene.find_child("Fruit3D_" + id, true, false) as Node3D
		ok(fruta != null, "fruta %s na arena" % id)
		if fruta == null or jogador == null:
			continue
		jogador.global_position = fruta.global_position + Vector3(0, 0.2, 0)
		jogador.set("velocity", Vector3.ZERO)
		var pegou := false
		for i in 60:
			await physics_frame
			if jogador.get("current_fruit_id") == id:
				pegou = true
				break
		ok(pegou, "encostar equipa %s (%s)" % [id, jogador.get("current_fruit_id")])
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
