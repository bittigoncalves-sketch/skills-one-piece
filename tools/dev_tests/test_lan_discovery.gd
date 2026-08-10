extends SceneTree
# Testa a descoberta automatica na LAN. Precisa de DOIS processos:
#   Terminal 1: godot --headless --path . --script tools/dev_tests/test_lan_discovery.gd -- farol
#   Terminal 2: godot --headless --path . --script tools/dev_tests/test_lan_discovery.gd -- buscar

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var papel: String = args[0] if args.size() > 0 else "buscar"
	var raiz := Node.new()
	get_root().add_child(raiz)

	if papel == "farol":
		var d := LanDiscovery.new()
		raiz.add_child(d)
		d.iniciar_farol(24565, "TESTE01")
		print("[FAROL] anunciando em: ", d._enderecos_de_difusao())
		var fim := Time.get_ticks_msec() + 25000
		while Time.get_ticks_msec() < fim:
			await process_frame
		d.parar_farol()
		print("[FAROL] fim")
	else:
		print("[BUSCA] procurando host na rede local...")
		var t0 := Time.get_ticks_msec()
		var achado: Dictionary = await LanDiscovery.procurar(raiz, 8.0)
		var dt := Time.get_ticks_msec() - t0
		if achado.is_empty():
			print("  ❌ nao achei nenhum host em %d ms" % dt)
		else:
			print("  ✅ achei em %d ms -> ip=%s porta=%d sala=%s" % [
				dt, achado["ip"], achado["porta"], achado["sala"]])
	quit()
