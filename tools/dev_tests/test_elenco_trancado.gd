extends SceneTree
# Prova que a trava de elenco resiste por TODOS os caminhos, não só pelo menu.
#
# O furo que motivou este teste: o Main equipa "suna_suna" ao nascer, e o
# equip_fruit() troca a aparência automaticamente conforme a fruta — chamando
# _setup_character_model() direto. O jogo abria com o Crocodile mesmo com o
# elenco trancado no base.
#
# Uso: godot --headless --path . -s tools/dev_tests/test_elenco_trancado.gd

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var falhas := 0
	# Player.gd não tem class_name (é script de cena), então carrega-se o script.
	var PlayerScript = load("res://Player.gd")
	var liberado: String = PlayerScript.ELENCO_LIBERADO[0]
	print("elenco liberado: ", PlayerScript.ELENCO_LIBERADO)

	var p = PlayerScript.new()
	get_root().add_child(p)
	await process_frame

	print("\n1. personagem inicial")
	falhas += _checa(p.character_id == liberado,
		"nasceu como '%s' (esperado '%s')" % [p.character_id, liberado])

	print("\n2. troca automática pela FRUTA (foi por aqui que vazou)")
	for fruta in ["suna_suna", "yami_yami", "goro_goro", "mera_mera", "bara_bara"]:
		p.equip_fruit(fruta)
		await process_frame
		falhas += _checa(p.character_id == liberado,
			"equip_fruit('%s') virou '%s'" % [fruta, p.character_id])

	print("\n3. set_character com id trancado")
	for cid in ["crocodile", "ace", "nami", "blackbeard", "buggy"]:
		p.set_character(cid)
		await process_frame
		falhas += _checa(p.character_id == liberado,
			"set_character('%s') virou '%s'" % [cid, p.character_id])

	print("\n4. chamada DIRETA no _setup_character_model (como o menu faz)")
	p._setup_character_model("crocodile")
	await process_frame
	falhas += _checa(p.character_id == liberado,
		"_setup_character_model('crocodile') virou '%s'" % p.character_id)

	print("\n================================")
	if falhas == 0:
		print("✅ ELENCO TRANCADO EM: ", liberado)
	else:
		print("❌ ", falhas, " vazamento(s)")
	quit(1 if falhas > 0 else 0)

func _checa(ok: bool, msg: String) -> int:
	if ok:
		print("   ✓")
		return 0
	print("   ✗ ", msg)
	return 1
