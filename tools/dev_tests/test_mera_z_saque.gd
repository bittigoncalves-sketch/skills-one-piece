extends SceneTree
## Mera Mera Z — prova o ciclo visual completo, agora SEM CARGA:
## aperto -> pistolas já nas mãos e rajada correndo -> arma some ao fim do pente.
## Execute: godot --headless --path . -s tools/dev_tests/test_mera_z_saque.gd

var _falhas := 0

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(4.0)
	var player: Node = null
	for body in get_nodes_in_group("player"):
		if body.is_multiplayer_authority():
			player = body
	if player == null:
		_falhar("jogador local não foi criado")
		quit(1)
		return

	player.combat_mode = "fruit"
	player.equip_fruit("mera_mera")
	player.energy = player.max_energy
	player._skill_cooldowns["Z"] = 0.0
	# A arena pode acertar o jogador enquanto a sonda espera a carga. Aqui a
	# imunidade isola o ciclo visual; não faz parte da habilidade em jogo.
	player.set_meta("damage_immune", true)
	await _esperar(0.2)
	var rig: PlayerRig = player.get_node_or_null("PlayerRig") as PlayerRig
	_verificar(rig != null, "PlayerRig existe")
	_verificar(rig != null and rig.pistolas().size() == 2, "duas pistolas Mera foram criadas")
	for gun in rig.pistolas():
		var malhas: Array = []
		FxUtil._collect_meshes(gun, malhas)
		_verificar(not malhas.is_empty() and Visual.e_adorno(malhas[0]),
			"pistola é marcada para não receber a cor do personagem")

	# ⚠️ SEM CARGA — pedido do dono: "elimina a necessidade de tempo para desferir
	#   ataques de frutas na Mera Mera no Mi". O Z agora saca E atira no mesmo
	#   aperto, e as pistolas pulam o coldre: nascem direto nas mãos. A janela
	#   curta abaixo é de propósito — se a espera voltar, ela acusa na hora.
	player.begin_charge("Z")
	await _esperar(0.1)
	_verificar(rig.pistolas_em_saque(), "as pistolas aparecem no mesmo aperto")
	for gun in rig.pistolas():
		_verificar(gun.visible and String(gun.get_parent().name).begins_with("ForeArm_"),
			"pistola nasce na mão, sem passar pelo coldre")
	_verificar(player._rapid_fire, "a rajada começa sem carga nenhuma")
	# ⚠️ CONTROLE DO "SEM CARGA": se a Mera voltasse para `CARREGAVEIS`, o nó de
	#   carga marcaria progresso e a rajada só sairia meio segundo depois. Sem
	#   esta linha, um retorno da barra passaria despercebido.
	_verificar(player._cast.progresso_mera_z() == 0.0, "não existe mais barra de carga na Mera Z")

	await _esperar(3.4)
	_verificar(not rig.pistolas_em_saque(), "pistolas foram ocultadas após a rajada")
	_verificar(not player.has_meta("custom_pose"), "pose de saque foi limpa e não trava as próximas animações")
	player.remove_meta("damage_immune")
	print("\n===== %s =====" % ("MERA Z SAQUE OK" if _falhas == 0 else "%d FALHA(S)" % _falhas))
	quit(1 if _falhas > 0 else 0)

func _verificar(condicao: bool, mensagem: String) -> void:
	print(("  OK  " if condicao else "  XX  ") + mensagem)
	if not condicao:
		_falhas += 1

func _falhar(mensagem: String) -> void:
	print("  XX  " + mensagem)
	_falhas += 1

func _esperar(segundos: float) -> void:
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < int(segundos * 1000.0):
		await process_frame
