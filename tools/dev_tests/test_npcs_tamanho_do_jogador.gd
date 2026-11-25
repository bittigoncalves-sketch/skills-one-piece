extends SceneTree
# TODOS os NPCs da ilha compatíveis com o tamanho do jogador (22/11/2026, pedido do dono). Mede a altura visível de cada ficha de `NpcDaIlha.FICHAS`
# contra a do corpo do jogador (a mesma montagem em caixas). Exceções DECLARADAS: o instrutor (1,13×, pedido do dono) e o Barba Negra (rig próprio 1,5×).
#   godot --headless --path . --script tools/dev_tests/test_npcs_tamanho_do_jogador.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print(("  ok  " if c else "  FALHA  ") + m)
	if not c: _f += 1

func _altura(n: Node) -> Array:
	var lo := 1e9; var hi := -1e9
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or str(mi.name) in ["Nome", "BocaFalante", "Quadro"]: continue
		var a: AABB = mi.global_transform * mi.mesh.get_aabb()
		lo = min(lo, a.position.y); hi = max(hi, a.end.y)
	return [lo, hi]

func _init() -> void:
	await process_frame
	print("\n===== NPCs × TAMANHO DO JOGADOR =====")
	var ref := NpcDaIlha.new(); ref.tipo = "npc_comida"; root.add_child(ref); await process_frame
	var h_ref: float = _altura(ref.get_node("Corpo"))[1] - _altura(ref.get_node("Corpo"))[0]
	print("  referência (corpo do jogador montado como NPC): %.2f m" % h_ref)
	var x := 3.0
	var excecoes := {"npc_treinador": [1.0, 1.3]}   # razão altura/jogador permitida (o instrutor: maior de propósito, pedido do dono; medido 1,26× com o cabelo)
	for tipo in NpcDaIlha.FICHAS:
		var n := NpcDaIlha.new(); n.tipo = tipo; n.position = Vector3(x, 0, 0); x += 3.0
		root.add_child(n); await process_frame; await process_frame
		if NpcDaIlha.ficha(tipo).has("rig"):
			# Barba Negra: rig PRÓPRIO (o mesmo da arena, 1,5× o jogador por decisão do dono em 15/10/2026); as malhas dele não são caixas medíveis aqui. Confere a ficha: escala ≥ 1 (nunca menor que o jogador).
			ok("%s: rig próprio, declarado MAIOR que o jogador (escala %.2f ≥ 1,0)" % [tipo, float(NpcDaIlha.ficha(tipo).get("escala", 1.0))], float(NpcDaIlha.ficha(tipo).get("escala", 1.0)) >= 1.0)
			continue
		var h := _altura(n.get_node("Corpo"))
		var r: float = (h[1] - h[0]) / h_ref
		var faixa: Array = excecoes.get(tipo, [0.9, 1.12])
		ok("%s: altura %.2f m = %.2f× o jogador (permitido %.2f–%.2f)" % [tipo, h[1] - h[0], r, faixa[0], faixa[1]], r >= faixa[0] and r <= faixa[1])
		ok("%s: pés no chão (±5 cm)" % tipo, absf(h[0]) < 0.05)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f))
	quit(1 if _f > 0 else 0)
