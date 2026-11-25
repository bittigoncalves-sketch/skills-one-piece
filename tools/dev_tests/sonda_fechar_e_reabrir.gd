extends SceneTree
## Fecha o jogo na Ilha dos Macacos pelo caminho REAL de fechar a janela e, noutro processo, reabre e diz onde o jogador nasce.
## Save no caminho padrão (user://), por isso rode com XDG_DATA_HOME apontando para uma pasta temporária.
##   ... --script tools/dev_tests/sonda_fechar_e_reabrir.gd -- fechar|reabrir
func q(n: int) -> void:
	for i in n: await physics_frame
func _init() -> void:
	_rodar.call_deferred()
func _rodar() -> void:
	var fase := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "reabrir"
	var Ilhas = load("res://src/historia/ilhas/ilhas.gd")
	var mapa: Dictionary = MapaArquivo.carregar("res://mapas/historia/baseplate.json")["mapa"]
	var caixas: Dictionary = Ilhas.caixas(mapa)
	root.get_node("GameFlow").start_story()
	await q(400)
	var p = get_first_node_in_group("player")
	print("SONDA[", fase, "] nasceu em ", p.global_position, " -> ", Ilhas.ilha_em(caixas, p.global_position, 0.0))
	if fase == "fechar":
		var destino: Rect2 = caixas[Ilhas.MACACOS]
		var c := destino.get_center()
		await current_scene.garantir_ilha(Ilhas.MACACOS)
		p.global_position = Vector3(c.x + 30.0, 12.0, c.y)
		await q(240)
		print("SONDA[fechar] andando na Ilha dos Macacos em ", p.global_position, " no chão=", p.is_on_floor(), " ilha=", Ilhas.ilha_em(caixas, p.global_position, 0.0))
		print("SONDA[fechar] FECHANDO a janela (pedido de fechar do sistema)")
		notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
		await q(10)
		quit()
	else:
		quit()
