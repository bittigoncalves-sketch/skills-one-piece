extends SceneTree
# ============================================================================
#  DIAGNÓSTICO DA REDE — este PC consegue receber conexão de fora?
#
#  ⚠️ SÓ OLHA, NÃO MEXE. Nenhuma porta é aberta aqui: `discover` e
#  `query_external_address` apenas perguntam ao roteador. Abrir mapeamento é
#  mudança que fica no roteador depois que o jogo fecha, e isso é decisão de
#  quem está usando a rede, não de um diagnóstico.
#
#      godot --headless --path . -s tools/dev_tests/diag_rede_publica.gd
# ============================================================================

func _init() -> void:
	await process_frame
	print("=== ESTE PC PODE SER SERVIDOR PARA FORA? ===\n")

	var porta := NetworkConfig.DEFAULT_PORT
	print("porta do jogo ........ %d (ENet/UDP)" % porta)
	print("farol de LAN ......... %d" % NetworkConfig.PORTA_FAROL)

	var locais: Array[String] = []
	for a in IP.get_local_addresses():
		var ip := String(a)
		if ip.count(".") == 3 and not ip.begins_with("127."):
			locais.append(ip)
	print("IPs locais ........... %s" % str(locais))

	print("\n-- perguntando ao roteador (UPnP) --")
	var upnp := UPNP.new()
	var t0 := Time.get_ticks_msec()
	var achou := upnp.discover()
	var ms := Time.get_ticks_msec() - t0
	print("discover ............. código %d em %d ms" % [achou, ms])
	if achou != UPNP.UPNP_RESULT_SUCCESS:
		print("\n❌ o roteador não respondeu ao UPnP.")
		print("   Ou ele não tem UPnP, ou está desligado nas configurações dele.")
		print("   Saída: ligar UPnP no roteador, ou encaminhar a porta %d à mão" % porta)
		print("   (UDP, e de preferência TCP junto) para o IP local desta máquina.")
		quit(1)
		return

	var gw := upnp.get_gateway()
	var valido := gw != null and gw.is_valid_gateway()
	print("gateway válido ....... %s" % str(valido))
	if not valido:
		print("\n❌ achei o roteador, mas ele não aceita encaminhar portas.")
		quit(1)
		return

	var externo := upnp.query_external_address()
	print("endereço externo ..... %s" % (externo if not externo.is_empty() else "(não informado)"))

	var privado := externo.is_empty() \
		or externo.begins_with("192.168.") or externo.begins_with("10.") \
		or externo.begins_with("100.64.") or externo.begins_with("172.16.")
	print("")
	if privado:
		print("⚠️  O ENDEREÇO EXTERNO AINDA É PRIVADO (%s)." % externo)
		print("   Isso é CGNAT: a operadora está entre você e a internet, e")
		print("   nenhuma porta sua é alcançável de fora. Abrir a porta no seu")
		print("   roteador não resolve — o pedido do amigo nem chega nele.")
		print("   Saídas: pedir IP público à operadora, ou usar um túnel/VPN.")
		quit(2)
		return

	print("✅ DÁ PARA HOSPEDAR PARA FORA.")
	print("   O roteador aceita UPnP e o endereço público é %s." % externo)
	print("   `GameFlow.create_room_publica()` abre a porta %d e gera o ID" % porta)
	print("   da sala já com esse endereço.")
	quit(0)
