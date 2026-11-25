extends SceneTree
## ENet real: o servidor roda o mod e manda `MinepieceModAnimationMessage`; o clipe tem de tocar nos DOIS peers (corpo do host e
## corpo do cliente). Rodar pelo `test_animacao_do_mod_rede.py` (host + cliente, mesma SOP_PORTA).
var host := false
var checks := 0
var falhas := 0
var host_player: Node3D
var remote_player: Node3D

func ok(c: bool, m: String) -> void:
	checks += 1
	falhas += 0 if c else 1
	print(("PASS " if c else "FAIL ") + m)

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if not ("host" in args or "client" in args):
		print("PULADO: use -- host e -- client")
		quit(0)
		return
	host = "host" in args
	create_timer(60).timeout.connect(func():
		push_error("ANIM REDE TIMEOUT")
		quit(2))
	var flow := root.get_node("GameFlow")
	flow.dummies["TrainingDummy"] = false
	flow.dummies["AutoDummy"] = false
	if host:
		flow.create_room()
	else:
		flow.join_room("127.0.0.1")
	while host_player == null or remote_player == null:
		await process_frame
		for p in get_nodes_in_group("player"):
			if p.get_multiplayer_authority() == 1:
				host_player = p
			else:
				remote_player = p
	await create_timer(2.0).timeout
	var nomes := PoseDoMod.nomes()
	var clipe_a: String = nomes[0]
	var clipe_b: String = nomes[1]
	if host:
		for par in [[host_player, clipe_a], [remote_player, clipe_b]]:
			var m := McRede.Animacao.new()
			m.clipe = par[1]
			m.alvo = par[0].get_instance_id()
			m.sobrescrever = true
			McRede.instancia().send(null, m)
		await create_timer(0.5).timeout
	else:
		for _i in 40:
			var h := host_player.get_node_or_null("AnimacaoDoMod") as AnimacaoDoMod
			var r := remote_player.get_node_or_null("AnimacaoDoMod") as AnimacaoDoMod
			if h != null and r != null and clipe_a in h.historico and clipe_b in r.historico:
				break
			await create_timer(0.1).timeout
	var no_h := host_player.get_node_or_null("AnimacaoDoMod") as AnimacaoDoMod
	var no_r := remote_player.get_node_or_null("AnimacaoDoMod") as AnimacaoDoMod
	var papel := "HOST" if host else "CLIENTE"
	ok(no_h != null and clipe_a in no_h.historico, "%s: o corpo do host tocou '%s'" % [papel, clipe_a])
	ok(no_r != null and clipe_b in no_r.historico, "%s: o corpo do cliente tocou '%s'" % [papel, clipe_b])
	print("ANIM REDE %s: %d checks, %d falhas" % [papel, checks, falhas])
	if host:
		await create_timer(8.0).timeout       # fica de pé até o cliente conferir (a saída do host libera os corpos)
	await create_timer(0.5).timeout
	quit(0 if falhas == 0 else 1)
