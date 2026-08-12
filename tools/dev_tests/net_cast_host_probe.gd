extends SceneTree
# ============================================================================
#  SONDA DO CANAL DE CAST — LADO HOST (2 processos). É o JUIZ: observa, não age.
#
#  O buraco que ela fecha: `_net_cast` / `_net_play_cast` só eram exercitados
#  pelo `test_frutas.gd`, que roda UM processo só. Num processo só o cliente
#  É o servidor, então o caminho que quebra de verdade — o golpe do cliente
#  chegar ao servidor e virar dano — nunca era testado.
#
#  É a assinatura de um bug que já aconteceu aqui (docs/erros.md, 2026-08-10):
#  a `DamageZone` nascia no cliente e NÃO feria ninguém, porque zona de dano só
#  machuca no servidor. No host tudo funcionava, e por isso demorou a aparecer.
#
#  O que este processo mede:
#    • cada `DamageZone` que NASCE na cena, com o dono (caster) e o dano
#    • a vida do corpo do HOST, antes e depois
#
#  Rode ANTES do cliente (porta 24565 é fixa e única):
#    godot --headless --path . --script tools/dev_tests/net_cast_host_probe.gd
# ============================================================================

var _eu: Node = null            # corpo do host (o alvo)
var _cliente: Node = null       # corpo do cliente, cópia autoritativa
# ⚠️ O NOME é guardado como texto: o cliente sai antes de o host fechar o
# relatório, e aí o nó já foi liberado — dereferenciar dá
# "Invalid access to property 'name' on a previously freed object".
var _nome_cliente := ""
var _zonas_vistas := {}
var _nascimentos: Array = []    # {t, dano, caster}
var _hp_inicial := 0.0
var _t0 := 0.0

func _init() -> void:
	await process_frame
	_t0 = Time.get_ticks_msec() / 1000.0
	get_root().get_node("GameFlow").create_room()
	print("[HOST] sala criada — esperando o cliente...")

	for i in 1200:
		await process_frame
		_eu = _corpo("1")
		if _eu != null:
			break
	if _eu == null:
		print("[HOST] ❌ meu proprio corpo nunca apareceu"); quit(2); return
	_hp_inicial = float(_eu.health)
	print("[HOST] meu corpo='%s'  hp=%.1f" % [_eu.name, _hp_inicial])

	# Ignora o que ja existia antes de eu comecar a contar.
	_sincronizar_zonas()

	var esperou := 0
	while _cliente == null and esperou < 3000:
		await process_frame
		esperou += 1
		for n in get_nodes_in_group("player"):
			if n.name != "1":
				_cliente = n
	if _cliente == null:
		print("[HOST] ❌ o cliente nunca conectou"); quit(3); return
	_nome_cliente = str(_cliente.name)
	print("[HOST][t=%6.2f] cliente conectado -> corpo '%s'" % [_t(), _nome_cliente])

	# Observa por 45 s (o roteiro do cliente cabe nisso com folga).
	var fim := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < fim:
		await process_frame
		_varrer_zonas()

	_relatorio()
	quit(0 if _falhas() == 0 else 1)

# ------------------------------------------------------------------ medicao
func _varrer_zonas() -> void:
	var cena := current_scene
	if cena == null:
		return
	for c in cena.get_children():
		if c is DamageZone and not _zonas_vistas.has(c.get_instance_id()):
			_zonas_vistas[c.get_instance_id()] = true
			var dono := "?"
			var cst = c.get("caster")
			if cst != null and is_instance_valid(cst):
				dono = str(cst.name)
			var dano: float = float(c.get("damage")) if c.get("damage") != null else 0.0
			_nascimentos.append({"t": _t(), "dano": dano, "caster": dono})
			print("[HOST][t=%6.2f] 💥 DamageZone nasceu — dano=%.1f caster='%s'" % [_t(), dano, dono])

func _sincronizar_zonas() -> void:
	var cena := current_scene
	if cena == null:
		return
	for c in cena.get_children():
		if c is DamageZone:
			_zonas_vistas[c.get_instance_id()] = true

# ---------------------------------------------------------------- relatorio
func _do_cliente() -> Array:
	return _nascimentos.filter(func(z): return z["caster"] == _nome_cliente)

func _falhas() -> int:
	var f := 0
	if _do_cliente().is_empty(): f += 1
	if _eu.health >= _hp_inicial: f += 1
	return f

func _relatorio() -> void:
	var do_cli := _do_cliente()
	print("\n╔══════════════════════════════════════════════════════════════════╗")
	print("║  CANAL DE CAST EM REDE — MEDIDO NO PROCESSO DO HOST               ║")
	print("╚══════════════════════════════════════════════════════════════════╝")
	print("   DamageZone nascidas no total ...: %d" % _nascimentos.size())
	print("   ...delas, do CLIENTE ...........: %d" % do_cli.size())

	print("\n-- ITEM 1: O GOLPE DO CLIENTE CHEGA AO SERVIDOR E VIRA HITBOX --")
	if do_cli.is_empty():
		print("   ❌ ZERO DamageZone do cliente — o golpe dele nao fere ninguem")
		print("      (e a assinatura do bug de 2026-08-10: zona nascendo so no cliente)")
	else:
		var danos: Array = do_cli.map(func(z): return "%.1f" % z["dano"])
		print("   ✅ %d zona(s) do cliente nasceram NESTE processo — danos: %s"
			% [do_cli.size(), str(danos)])

	print("\n-- ITEM 2: O GOLPE DO CLIENTE FERE DE VERDADE --")
	var delta: float = _eu.health - _hp_inicial
	if delta < 0.0:
		print("   ✅ vida do corpo do HOST caiu %.1f -> %.1f  (Δ = %.1f)"
			% [_hp_inicial, _eu.health, delta])
	else:
		print("   ❌ a vida do host NAO mudou (%.1f) — a zona nasceu mas nao acertou"
			% _eu.health)

	print("\n%s" % ("✅ CANAL DE CAST OK" if _falhas() == 0 else "❌ %d FALHA(S)" % _falhas()))

# ----------------------------------------------------------------- auxiliares
func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null

func _t() -> float:
	return Time.get_ticks_msec() / 1000.0 - _t0
