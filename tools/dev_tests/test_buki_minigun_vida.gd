extends SceneTree
# Anti-lag do V (21/11/2026): as balas do minigun somem em ~0,8 s e o enfeite sai só a cada 3 tiros.
#   godot --headless --path . --fixed-fps 60 --script tools/dev_tests/test_buki_minigun_vida.gd
var _f := 0
func ok(m: String, c: bool) -> void:
	print("  %s %s" % ["ok " if c else "FALHA", m]); if not c: _f += 1

func _contar(raiz: Node, tipo: String) -> int:
	var n := 0
	for c in raiz.get_children():
		if c.get_class() == tipo or (c.get_script() != null and str(c.get_script().resource_path).ends_with(tipo)): n += 1
	return n

func _init() -> void:
	await process_frame
	var mundo := Node3D.new(); root.add_child(mundo)
	for i in 60:                                   # 60 tiros ≈ 3,6 s de rajada
		BukiFX.disparo(mundo, Vector3.ZERO + Vector3.UP * 50.0, Vector3.FORWARD, "V", 1.0, null)
		for k in 4: await physics_frame            # ~0,067 s
	var zonas := 0
	var particulas := 0
	for c in mundo.get_children():
		if c is DamageZone: zonas += 1
		if c is GPUParticles3D: particulas += 1
	print("  vivas agora: %d zonas, %d partículas" % [zonas, particulas])
	ok("no máximo ~13 balas vivas (0,8 s x 17/s), não 50", zonas <= 16)
	var antes := zonas
	for k in 90: await physics_frame
	zonas = 0
	for c in mundo.get_children():
		if c is DamageZone: zonas += 1
	ok("parou de atirar: todas as balas somem em 1,5 s (restam %d)" % zonas, zonas == 0 and antes > 0)
	var z := 0
	BukiFX._tiros_por_slot.clear()
	var m2 := Node3D.new(); root.add_child(m2)
	for i in 9: BukiFX.disparo(m2, Vector3.UP * 50.0, Vector3.FORWARD, "V", 1.0, null)
	for c in m2.get_children():
		if c is GPUParticles3D: z += 1
	ok("9 tiros do V: enfeite em 3 (clarão+estojo+fumaça=9 partículas), não em 9 (27)", z <= 12)
	print("\n" + ("TUDO OK" if _f == 0 else "%d FALHA(S)" % _f)); quit(1 if _f > 0 else 0)
