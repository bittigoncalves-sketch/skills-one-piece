extends SceneTree
# Moradores da vila no corpo em caixas, do tamanho do jogador (21/11/2026). Rodar:
#   godot --headless --path . --script tools/dev_tests/test_moradores_quadrados.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _altura(n: Node) -> Array:
	var lo := 1e9; var hi := -1e9
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or str(mi.name) == "Nome": continue
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		lo = min(lo, a.position.y); hi = max(hi, a.end.y)
	return [lo, hi]

func _init() -> void:
	await process_frame
	print("\n===== MORADORES QUADRADOS =====")
	# jogador de referência: o corpo da campanha montado como o NPC (sem ficha), altura do rig de 1,5 m
	var x := 0.0
	for tipo in VisualDeMorador.APARENCIAS:
		var n := NpcDaIlha.new(); n.tipo = tipo; n.position = Vector3(x, 0, 0); x += 3.0
		root.add_child(n)
		await process_frame
		var corpo := n.get_node("Corpo")
		var h := _altura(corpo)
		var esc := (corpo as Node3D).scale.x
		var f := NpcDaIlha.ficha(tipo)
		var instrutor := f.has("tamanho")
		print("  %s: h=%.2f sola=%.3f escala=%.2f" % [tipo, h[1] - h[0], h[0], esc])
		ok("%s: corpo em caixas" % tipo, corpo.has_meta("corpo_historia"))
		ok("%s: tamanho do jogador (corpo 1,5–1,9 m com cabelo/chapéu)" % tipo, esc == 1.0 and (h[1] - h[0]) > 1.45 and (h[1] - h[0]) < 1.95)
		ok("%s: pés no chão (±4 cm)" % tipo, absf(h[0]) < 0.04)
		# a capa da ficha pintou o peito
		var peito := n.find_child("Peito", true, false) as MeshInstance3D
		if peito != null and f.has("capa"):
			var m := peito.get_surface_override_material(0) as StandardMaterial3D
			ok("%s: peito na cor da capa" % tipo, m != null and m.albedo_color.is_equal_approx(f["capa"]))
	var barba := NpcDaIlha.new(); barba.tipo = "npc_barba_negra"; root.add_child(barba); await process_frame
	ok("Barba Negra continua com o rig dele (sem corpo quadrado)", not barba.get_node("Corpo").has_meta("corpo_historia"))
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
