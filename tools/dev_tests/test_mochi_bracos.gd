extends SceneTree
# MOCHI MOCHI — as rosquinhas e os braços esticados (15/11/2026).
# Unstoppable Donuts (N) cria 2 `entity_muso_donatsu` atrás do usuário; em tom creme (não azul). Punch Mochi (X) / Elephant Gun (C), com as rosquinhas ativas, esticam um
# braço de massa (cilindro + punho) de CADA rosquinha e da mão até o alvo, que depois recolhe sozinho.
#   godot --headless --path . --script tools/dev_tests/test_mochi_bracos.gd
var _ok_n := 0
var _falhas := 0
func _ok(c: bool, r: String) -> void:
	if c: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if c else "❌", r])
func quadros(n: int) -> void:
	for i in n: await physics_frame
func _bracos() -> int:
	var n := 0
	for m in current_scene.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh is CylinderMesh and (m as MeshInstance3D).material_override is StandardMaterial3D \
				and ((m as MeshInstance3D).material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color(1.0, 0.93, 0.82)):
			n += 1
	return n
func _init() -> void:
	rodar.call_deferred()
func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_mochi_bracos.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_mochi_bracos.json"))
	root.get_node("GameFlow").start_story()
	await quadros(200)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.max_energy = 4000.0
	var av = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for cr in d.criterios: av.award(d, cr)
	await quadros(10)
	var alvo := PersonagemMinePiece.new()
	alvo.montar(DadosEastBlue.ficha("arlong"), "mp_arlong")
	alvo.position = Vector3(0, 1, -10)
	alvo.ponto_de_origem = alvo.position
	current_scene.add_child(alvo)
	alvo.max_health = 1000000.0
	modo.equipar_fruta(j, "")
	await quadros(5)
	modo.equipar_fruta(j, "mochi_mochi")
	await quadros(20)
	var c = j.get_node_or_null("FrutaMinePiece")
	_ok(c != null and c.fruta_ativa(), "a Mochi Mochi equipa")
	j.energy = j.max_energy
	c.usar_tecla("N", true)
	await quadros(20)
	c.usar_tecla("N", false)
	await quadros(60)
	var donuts := get_nodes_in_group("invocados_do_jogador").filter(func(n): return McAliadoDoMod.id_de(n) == "entity_muso_donatsu")
	_ok(donuts.size() == 2, "Unstoppable Donuts cria 2 rosquinhas (%d)" % donuts.size())
	var atras := 0
	for d in donuts:
		if (d as Node3D).global_position.z > j.global_position.z:
			atras += 1
	_ok(atras == 2, "as duas ficam ATRÁS do usuário (z maior que o dele, que olha para -Z): %d de 2" % atras)
	var creme := 0
	for d in donuts:
		for m in (d as Node).find_children("*", "MeshInstance3D", true, false):
			var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
			if mat != null and mat.albedo_color.is_equal_approx(Color(1.0, 0.93, 0.82)):
				creme += 1
				break
	_ok(creme == 2, "as rosquinhas têm o tom creme de mochi (não azul): %d de 2" % creme)
	_ok(_bracos() == 0, "antes do soco não há braço esticado")
	c.recarga = 0.0
	for n in c.recargas.keys(): c.recargas[n] = 0.0
	j.energy = j.max_energy
	c.usar_tecla("X", true)
	await quadros(20)
	c.usar_tecla("X", false)
	var maximo := 0
	for i in 30:
		await physics_frame
		maximo = maxi(maximo, _bracos())
	_ok(maximo >= 3, "o Punch Mochi estica um braço da mão e de cada rosquinha (pico: %d braços)" % maximo)
	await create_timer(1.2).timeout
	_ok(_bracos() == 0, "os braços recolhem e somem sozinhos")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nMOCHI_BRACOS %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
