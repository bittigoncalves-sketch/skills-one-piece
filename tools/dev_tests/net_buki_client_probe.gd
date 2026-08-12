extends SceneTree
# ============================================================================
#  SONDA BUKI BUKI — LADO CLIENTE (2 processos). É quem AGE.
#
#  Roteiro (o host, que é o juiz, se sincroniza sozinho pelas trocas de arma):
#
#    A  saca a pistola (Z)   -> prova que o SAQUE replica          [item 1]
#    A2 guarda a pistola     -> prova que o GUARDAR replica        [item 2]
#    B  saca o canhão (X, 3 balas) e manda SEIS pedidos de tiro
#         mirados no corpo do host -> o servidor tem que aceitar 3
#         e recusar 3, e o alvo tem que PERDER VIDA        [itens 3 e 4]
#    C  saca a sniper (C, 5 balas) e usa o caminho de JOGO
#         (`_buki_atirar()`) -> 5 zonas e a arma cai sozinha    [item 3]
#    D  com as mãos livres, forja 5 pedidos de tiro -> zero zonas [item 3]
#    E  ACHADO: repete o saque pra provar que o servidor recarrega
#         o pente sem olhar recarga (relatado, não corrigido)
#
#  ⚠️ Headless não captura mouse nem tecla útil (`MOUSE_MODE_CAPTURED` é sempre
#  falso), então nada aqui passa por `Input`: os métodos do Player são chamados
#  direto, como já faz o test_buki_buki.gd.
#
#  Rode DEPOIS do host estar no ar (porta 24565 é fixa e única):
#    godot --headless --path . --script tools/dev_tests/net_buki_client_probe.gd
# ============================================================================

const RPCS_DO_ARSENAL := [
	"_net_buki_sacar_req", "_net_buki_sacar",
	"_net_buki_guardar_req", "_net_buki_guardar",
]

var _p: Node = null       # MEU corpo
var _host: Node = null    # corpo do host (peer 1), replicado até aqui
var _t0 := 0.0
var _pedidos := 0         # pedidos de tiro que EU mandei pro servidor

func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	var game_flow := get_root().get_node("GameFlow")
	print("[CLI] conectando em 127.0.0.1 ...")
	var ok: bool = game_flow.join_room("127.0.0.1")
	print("[CLI] join_room -> ", ok)
	if not ok:
		quit(2)
		return

	var meu_id := 0
	for i in 1800:
		await process_frame
		meu_id = root.multiplayer.get_unique_id()
		_p = _corpo(str(meu_id))
		if _p != null:
			break
	if _p == null:
		print("[CLI] ❌ meu corpo nunca apareceu (id=%d). Grupo player: %s"
			% [meu_id, str(get_nodes_in_group("player").map(func(n): return n.name))])
		quit(3)
		return
	for i in 600:
		await process_frame
		_host = _corpo("1")
		if _host != null:
			break
	print("[CLI] meu corpo='%s' (peer %d)  |  corpo do host='%s'"
		% [_p.name, meu_id, _host.name if _host else "<NÃO ACHEI>"])
	if _host == null:
		print("[CLI] ❌ sem o corpo do host não dá pra mirar em nada")
		quit(3)
		return

	# ---------------------------------------------------------------- preparo
	# `_do_server_buki_sacar` exige `_buki_ativa()` NA CÓPIA DO SERVIDOR, e lá o
	# `current_fruit_id` só chega pelo MultiplayerSynchronizer (Main.gd lista a
	# propriedade). Sem esperar essa replicação o servidor recusa todo saque em
	# silêncio — é exatamente o tipo de falha que 1 processo nunca mostra.
	_p.combat_mode = "fruit"
	_p.equip_fruit("buki_buki")
	await _esperar(2.0)
	print("[CLI][t=%6.2f] fruta equipada: '%s' (combat_mode='%s')  — esperei 2s pela replicação"
		% [_t(), _p.current_fruit_id, _p.combat_mode])

	print("\n[CLI] ===== os 4 RPCs do arsenal existem e estão configurados =====")
	# A config de `@rpc` mora no SCRIPT, não no Node (não existe
	# `Node.get_rpc_config()` — a primeira rodada desta sonda morreu nisso).
	var cfg = _p.get_script().get_rpc_config()
	for nome in RPCS_DO_ARSENAL:
		var tem: bool = _p.has_method(nome)
		var modo := "<sem config de rpc>"
		if cfg is Dictionary and cfg.has(nome):
			var c: Dictionary = cfg[nome]
			modo = "rpc_mode=%s call_local=%s transfer=%s" % [
				str(c.get("rpc_mode", "?")), str(c.get("call_local", "?")),
				str(c.get("transfer_mode", "?"))]
		print("   %-24s has_method=%s  %s" % [nome, tem, modo])

	await _teste_a()
	await _teste_b()
	await _teste_c()
	await _teste_d()
	await _teste_e()

	print("\n[CLI] ===== resumo do que EU mandei =====")
	print("   pedidos de tiro enviados ao servidor: %d" % _pedidos)
	print("   (quantos viraram DamageZone é o processo do HOST que diz)")
	print("\n[CLI] ===== fim — saindo (o host fecha o relatório dele) =====")
	await _esperar(1.0)
	quit(0)

# --------------------------------------------------- A: sacar e guardar (Z)
func _teste_a() -> void:
	print("\n[CLI] ===== A: SACAR A PISTOLA (Z) — item 1 =====")
	_zerar_recargas()
	_p._buki_empunhar("Z")
	print("   [dono] logo após empunhar: arma='%s' municao=%d visual='%s'"
		% [_p.buki_arma(), _p.buki_municao(), str(_p.get("_buki_visual"))])
	await _esperar(1.5)
	var vis := str(_p.get("_buki_visual"))
	print("   [dono] depois do ida-e-volta: arma='%s' municao=%d visual='%s'"
		% [_p.buki_arma(), _p.buki_municao(), vis])
	# `_buki_visual` só vira != "" por `_net_buki_sacar`. Aqui EU não sou o
	# servidor, então isso é a volta do broadcast: o RPC fechou o circuito.
	print("   %s _buki_visual='%s' no MEU processo => `_net_buki_sacar` voltou do servidor"
		% ["✅" if vis == "Z" else "❌", vis])

	print("\n[CLI] ===== A2: GUARDAR A PISTOLA (mesma tecla) — item 2 =====")
	_p._buki_empunhar("Z")      # mesmo slot = guardar
	await _esperar(1.5)
	print("   [dono] arma='%s' municao=%d visual='%s'  (recarga de Z = %.1fs)"
		% [_p.buki_arma(), _p.buki_municao(), str(_p.get("_buki_visual")),
			float(_p._skill_cooldowns["Z"])])

# ------------------------------- B: canhão (3 balas) e SEIS pedidos mirados
func _teste_b() -> void:
	print("\n[CLI] ===== B: CANHÃO (X, 3 balas) x 6 PEDIDOS — itens 3 e 4 =====")
	_zerar_recargas()
	# Me posiciono a ~6 m do host, no eixo Z, pra o projétil ter trajeto de
	# verdade (o canhão é o mais lento e mais gordo do arsenal: 22 m/s, raio
	# 0,55 — o que sobra de margem pra Area3D não passar batido entre quadros).
	_p.global_position = _host.global_position + Vector3(0.0, 0.3, 6.0)
	await _esperar(0.6)
	_p._buki_empunhar("X")
	await _esperar(1.5)
	print("   [dono] arma='%s' municao=%d visual='%s'"
		% [_p.buki_arma(), _p.buki_municao(), str(_p.get("_buki_visual"))])
	print("   [dono] eu=%s  alvo(host)=%s  dist=%.2f m"
		% [_v(_p.global_position), _v(_host.global_position),
			_p.global_position.distance_to(_host.global_position)])

	# ⚠️ A MIRA É FORÇADA, e isso é proposital. Em headless não há mouse
	# capturado, então `_buki_atirar()` mandaria o tiro pra onde a câmera parada
	# aponta e o item 4 (dano de verdade) viraria loteria. O pedido segue pelo
	# MESMO ponto de entrada do servidor que o jogo usa — `_net_bullet_req` ->
	# `_do_server_bullet` -> `_net_bullet_play` — só a direção é minha.
	for i in 6:
		var alvo: Vector3 = _host.global_position + Vector3.UP * 0.9
		var origem: Vector3 = _p.global_position + Vector3.UP * 1.2
		var aim: Vector3 = (alvo - origem).normalized()
		origem += aim * 1.0
		_p._net_bullet_req.rpc_id(1, aim, origem, "X")
		_pedidos += 1
		print("   -> pedido %d/6 de tiro 'X' (aim=%s)" % [i + 1, _v(aim)])
		await _esperar(0.12)
	await _esperar(2.5)
	print("   [dono] o SERVIDOR só devia ter aceitado 3 (pente do canhão). Quem conta é o host.")

	print("\n[CLI] --- B2: guardo o canhão ---")
	_p._buki_empunhar("X")      # mesmo slot = guardar
	await _esperar(1.5)
	print("   [dono] arma='%s' visual='%s'" % [_p.buki_arma(), str(_p.get("_buki_visual"))])

# ---------------------- C: sniper pelo caminho de JOGO (`_buki_atirar()`)
func _teste_c() -> void:
	print("\n[CLI] ===== C: SNIPER (C, 5 balas) PELO CAMINHO DE JOGO — item 3 =====")
	_zerar_recargas()
	_p._buki_empunhar("C")
	await _esperar(1.5)
	print("   [dono] arma='%s' municao=%d visual='%s'"
		% [_p.buki_arma(), _p.buki_municao(), str(_p.get("_buki_visual"))])
	for i in 7:
		var antes: int = _p.buki_municao()
		_p._buki_atirar()      # o método de verdade: debita bala e manda o RPC
		var depois: int = _p.buki_municao()
		if depois < antes:
			_pedidos += 1
		print("   -> _buki_atirar() %d/7: municao %d -> %d  arma='%s' %s"
			% [i + 1, antes, depois, _p.buki_arma(),
				"(mandou pedido)" if depois < antes else "(NÃO mandou — sem bala/sem arma)"])
		await _esperar(0.25)
	await _esperar(2.0)
	print("   [dono] fim: arma='%s' municao=%d visual='%s'  (recarga de C = %.1fs)"
		% [_p.buki_arma(), _p.buki_municao(), str(_p.get("_buki_visual")),
			float(_p._skill_cooldowns["C"])])

# ------------------------------------- D: mãos livres + pedidos forjados
func _teste_d() -> void:
	print("\n[CLI] ===== D: DE MÃOS LIVRES, 5 PEDIDOS FORJADOS — item 3 =====")
	print("   [dono] arma na mão agora = '%s' (tem que estar vazio)" % _p.buki_arma())
	for i in 5:
		var alvo: Vector3 = _host.global_position + Vector3.UP * 0.9
		var origem: Vector3 = _p.global_position + Vector3.UP * 1.2
		var aim: Vector3 = (alvo - origem).normalized()
		_p._net_bullet_req.rpc_id(1, aim, origem + aim, "C")
		_pedidos += 1
		await _esperar(0.12)
	print("   -> 5 pedidos 'C' enviados sem arma sacada. O host tem que criar ZERO zonas.")
	await _esperar(2.5)

# ------------------- E: achado — o saque recarrega o pente sem ver recarga
func _teste_e() -> void:
	print("\n[CLI] ===== E: ACHADO — saque repetido recarrega o pente (munição infinita?) =====")
	# Simulo o cliente adulterado: a recarga do slot Z está QUENTE (é o que
	# travaria o jogador honesto em `_buki_empunhar`), mas eu falo direto com o
	# RPC do servidor. Se `_do_server_buki_sacar` reenche o pente mesmo assim, a
	# penalidade da fruta (a munição) não existe pra quem trapaceia.
	_p._skill_cooldowns["Z"] = 5.0
	print("   [dono] recarga local de Z = %.1fs (o cliente honesto estaria travado aqui)"
		% float(_p._skill_cooldowns["Z"]))
	_p._net_buki_sacar_req.rpc_id(1, "Z")   # saque forjado: pente = 12
	await _esperar(1.2)
	for rodada in 2:
		print("   -- rodada %d: gasto 3 balas e peço o saque de novo --" % [rodada + 1])
		for i in 3:
			var alvo: Vector3 = _host.global_position + Vector3.UP * 0.9
			var origem: Vector3 = _p.global_position + Vector3.UP * 1.2
			var aim: Vector3 = (alvo - origem).normalized()
			_p._net_bullet_req.rpc_id(1, aim, origem + aim, "Z")
			_pedidos += 1
			await _esperar(0.15)
		await _esperar(0.6)
		_p._net_buki_sacar_req.rpc_id(1, "Z")   # sem trocar de arma: só reenche
		print("      -> saque 'Z' forjado de novo (recarga local ainda em %.1fs)"
			% float(_p._skill_cooldowns["Z"]))
		await _esperar(1.2)
	print("   [dono] se o host registrar 'PENTE RECARREGADO' aqui, o servidor não checa recarga")
	print("          e a munição — que é A penalidade da fruta — é opcional pra quem trapaceia.")

# ------------------------------------------------------------------ utilidades
func _corpo(nome: String) -> Node:
	for p in get_nodes_in_group("player"):
		if str(p.name) == nome:
			return p
	return null

func _zerar_recargas() -> void:
	for k in _p._skill_cooldowns.keys():
		_p._skill_cooldowns[k] = 0.0

func _v(v: Vector3) -> String:
	return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]

func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0

func _esperar(secs: float) -> void:
	# TEMPO REAL: em headless os process_frame correm bem mais rápido que 1/60,
	# então contar quadros mede errado (o net_client_probe já caiu nessa).
	var fim := Time.get_ticks_msec() + int(secs * 1000.0)
	while Time.get_ticks_msec() < fim:
		await process_frame
