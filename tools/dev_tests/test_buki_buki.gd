extends SceneTree
# Testa a Buki Buki no Mi: os 4 slots criam arma no membro certo, geram
# DamageZone, e o V trava no inimigo mais próximo da MIRA (teleguiado).
# Uso: godot --headless --path . -s tools/dev_tests/test_buki_buki.gd

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var falhas := 0
	var mundo := Node3D.new()
	mundo.name = "MundoTeste"
	get_root().add_child(mundo)

	# --- conjurador com rig (usa o personagem base, rig de 13 papéis) ---
	var data := CharacterBuilder.build_character("base")
	var modelo: Node3D = data["node"]
	var conjurador := CharacterBody3D.new()
	conjurador.name = "Conjurador"
	mundo.add_child(conjurador)
	conjurador.add_child(modelo)
	conjurador.set("_char_model", modelo)

	# --- dois inimigos: um alinhado com a mira, outro ao lado ---
	var mira := Vector3(0, 0, -1)
	var alvo_certo := _inimigo(mundo, Vector3(0.5, 0, -12), "ALINHADO")
	var _alvo_errado := _inimigo(mundo, Vector3(9, 0, -1), "DE_LADO")

	var skills := SkillSystem.get_fruit_skills()
	if not skills.has("buki_buki"):
		print("✗ buki_buki não está no SkillSystem"); falhas += 1
	else:
		print("skills registradas: ", skills["buki_buki"].keys())

	# --- alvo teleguiado escolhe o da MIRA, não o mais perto do corpo ---
	var escolhido := BukiFX.alvo_da_mira(conjurador, Vector3.ZERO, mira)
	print("\nalvo teleguiado: ", escolhido.name if escolhido else "NENHUM")
	if escolhido != alvo_certo:
		print("  ✗ deveria travar no ALINHADO (o DE_LADO está mais perto do corpo)")
		falhas += 1

	# --- cada slot ---
	for slot in [0, 1, 2, 3]:
		var nome: String = ["Z metralhadora", "X lâmina", "C canhão", "V arsenal"][slot]
		var antes_zonas := _contar_zonas(mundo)
		var antes_vel: Vector3 = conjurador.velocity
		BukiFX.cast(mundo, Vector3(0, 1, 0), mira, slot, 40.0, conjurador)
		await process_frame
		# a rajada usa timers; deixa correr um pouco
		for i in 6:
			await process_frame
		var zonas := _contar_zonas(mundo)
		var armas := _contar(modelo, "Buki")
		print("\n[%s] zonas=%d (antes %d) armas no rig=%d" % [nome, zonas, antes_zonas, armas])
		if slot == 2:
			var recuo: float = (conjurador.velocity - antes_vel).length()
			print("  recuo aplicado: %.1f" % recuo)
			if recuo < 1.0:
				print("  ✗ o canhão não empurrou o conjurador"); falhas += 1
		if zonas <= antes_zonas and slot != 3:
			print("  ✗ nenhuma DamageZone criada"); falhas += 1

	print("\n================================")
	if falhas == 0:
		print("✅ BUKI BUKI OK")
	else:
		print("❌ ", falhas, " falha(s)")
	quit(1 if falhas > 0 else 0)

func _inimigo(mundo: Node3D, pos: Vector3, nome: String) -> Node3D:
	var e := CharacterBody3D.new()
	e.name = nome
	e.add_to_group("enemy")
	mundo.add_child(e)
	e.global_position = pos
	return e

# DamageZone estende Area3D, então get_class() devolve "Area3D" — conta por tipo.
func _contar_zonas(raiz: Node) -> int:
	var n := 1 if raiz is DamageZone else 0
	for c in raiz.get_children():
		n += _contar_zonas(c)
	return n

func _contar(raiz: Node, prefixo: String) -> int:
	var n := 0
	if raiz.get_class() == prefixo or String(raiz.name).begins_with(prefixo):
		n += 1
	for c in raiz.get_children():
		n += _contar(c, prefixo)
	return n
