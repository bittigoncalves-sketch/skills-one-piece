extends SceneTree
# ============================================================================
#  KIT DO BUILDER EM REDE — LADO CLIENTE (2 processos). É quem AGE (06/10/2026).
#
#  Pede o kit pelo caminho do botão do M (`pedir_kit_do_builder`), cola no host e
#  usa o Z pela entrada de verdade (`begin_charge`/`release_charge`). Confere do
#  lado dele: o kit equipou, o golpe apareceu AQUI (presentation) e a vida do host
#  caiu (a vida é do servidor e tem de atravessar a rede).
#  Depois troca para a NORO NORO no Mi (fechamento da Z, 06/10/2026): segura a Z por
#  1,3 s (o feixe sairia em 0,75 s se o "segurar" não valesse em rede) e solta; confere
#  que o host NÃO fica lento enquanto segura e fica 5× lento AQUI depois de soltar — o
#  acerto só existe no servidor, então só o RPC da lentidão traz isso a este processo.
#  Headless não captura tecla: chama-se `begin_charge` direto, que é o ponto de
#  entrada do input.
#
#    (depois do host) godot --headless --path . --script tools/dev_tests/net_kit_client_probe.gd
# ============================================================================

const PASTA := "user://net_kit_skills"
const DANO := 150.0

var _p: Node = null
var _host: Node = null
var _falhas: Array[String] = []


func _init() -> void:
	await process_frame
	SkillsPublicadas.pasta_forcada = PASTA      # a mesma pasta que o host publicou
	SkillsPublicadas.recarregar()
	var gf := get_root().get_node("GameFlow")
	if not gf.join_room("127.0.0.1"):
		print("[CLI] ❌ join_room falhou"); quit(2); return
	for i in 1800:
		await process_frame
		_p = _corpo(str(root.multiplayer.get_unique_id()))
		if _p != null:
			break
	for i in 600:
		await process_frame
		_host = _corpo("1")
		if _host != null:
			break
	if _p == null or _host == null:
		print("[CLI] ❌ corpos não apareceram"); quit(3); return
	await _esperar(1.0)

	_p.pedir_kit_do_builder()
	await _esperar(2.5)
	_ok("o kit equipou pelo servidor ('%s', modo '%s')" % [_p.current_fruit_id, _p.combat_mode],
		_p.current_fruit_id == KitDoBuilder.ID and _p.combat_mode == "fruit")

	_p.global_position = _host.global_position + Vector3(0, 0, 2.5)
	_p._yaw = 0.0
	_p._pitch = 0.0
	await _esperar(0.8)
	var vida_antes := float(_host.health)
	_p.energy = _p.max_energy
	var energia_antes := float(_p.energy)
	_p.begin_charge("Z")
	await process_frame
	var viu := not current_scene.find_children("SkillBuilder_*", "", true, false).is_empty()
	_p.release_charge("Z")
	_ok("energia: 5 %% de %.0f = %.1f (gastou %.1f)" % [_p.max_energy, 0.05 * float(_p.max_energy), energia_antes - float(_p.energy)],
		absf((energia_antes - float(_p.energy)) - 0.05 * float(_p.max_energy)) < 1.0)
	for i in 30:
		await process_frame
		viu = viu or not current_scene.find_children("SkillBuilder_*", "", true, false).is_empty()
	_ok("o golpe aparece neste processo (o executor rodou aqui)", viu)
	await _esperar(3.0)
	var caiu := vida_antes - float(_host.health)
	_ok("a vida do host caiu aqui também, %.0f (caiu %.1f)" % [DANO, caiu], absf(caiu - DANO) < 3.0)
	await _noro()
	print("%s" % ("✅ KIT EM REDE OK (cliente)" if _falhas.is_empty() else "❌ %d falha(s): %s" % [_falhas.size(), str(_falhas)]))
	await _esperar(1.0)
	SkillsPublicadas.pasta_forcada = ""
	quit(0 if _falhas.is_empty() else 1)


func _noro() -> void:
	_p.pedir_fruta_do_builder("noro_noro")
	await _esperar(2.5)
	_ok("a Noro Noro no Mi equipou pelo servidor ('%s')" % _p.current_fruit_id, _p.current_fruit_id == "noro_noro")
	_p.global_position = _host.global_position + Vector3(0, 0, 6.0)
	_p._yaw = 0.0
	_p._pitch = 0.0
	await _esperar(0.8)
	var vida := float(_host.health)
	_p.energy = _p.max_energy
	_p.begin_charge("Z")
	await _esperar(1.3)
	_ok("segurando a Z: o host segue livre aqui (fator %.2f)" % Lentidao.fator(_host), is_equal_approx(Lentidao.fator(_host), 1.0))
	_p.release_charge("Z")
	var menor := 1.0
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 1500:
		await process_frame
		menor = minf(menor, Lentidao.fator(_host))
	_ok("soltou: o host fica 5× lento AQUI, vindo da rede (%.2f, aura %s)" % [menor, _host.get_node_or_null(Lentidao.AURA) != null],
		is_equal_approx(menor, 0.2) and _host.get_node_or_null(Lentidao.AURA) != null)
	_ok("o raio não fere (%.1f → %.1f)" % [vida, float(_host.health)], float(_host.health) >= vida - 1.0)


func _ok(rotulo: String, cond: bool) -> void:
	print("   %s %s" % ["✅" if cond else "❌", rotulo])
	if not cond:
		_falhas.append(rotulo)


func _corpo(nome: String) -> Node:
	for n in get_nodes_in_group("player"):
		if n.name == nome:
			return n
	return null


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
