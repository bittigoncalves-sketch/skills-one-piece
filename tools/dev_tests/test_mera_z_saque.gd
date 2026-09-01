extends SceneTree
## Mera Mera Z — prova o ciclo visual completo:
## coldres durante a carga -> mãos ao completar -> arma some após a rajada.
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

	player.begin_charge("Z")
	await _esperar(0.35)
	_verificar(rig.pistolas_em_saque(), "pistolas ficam visíveis durante a carga")
	for gun in rig.pistolas():
		_verificar(gun.visible and gun.get_parent().name == "MeraPistolHolsters",
			"pistola começa no coldre da cintura")
	_verificar(player._cast.progresso_mera_z() > 0.0 and player._cast.progresso_mera_z() < 1.0,
		"progresso da animação acompanha o carregamento")

	# A carga completa leva 0,5 s; esta margem também cobre o frame que transfere
	# as pistolas do coldre para as mãos antes da primeira bala.
	await _esperar(0.35)
	for gun in rig.pistolas():
		_verificar(gun.visible and String(gun.get_parent().name).begins_with("ForeArm_"),
			"pistola foi transferida para a mão antes do disparo")
	_verificar(player._rapid_fire, "carga completa inicia a rajada animada do Player")

	await _esperar(2.85)
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
