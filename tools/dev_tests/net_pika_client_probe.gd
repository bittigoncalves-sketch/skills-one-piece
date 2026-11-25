extends SceneTree
# ============================================================================
#  PIKA REFEITA NO BUILDER, EM REDE — LADO CLIENTE (2 processos). É quem AGE
#  (06/10/2026).
#
#  Recebe a Pika do servidor e usa Z, X e C pela entrada de verdade
#  (`begin_charge`/`release_charge`) contra o host; confere DAQUI que a vida do host
#  caiu o dano da arena (a vida é do servidor e tem de atravessar a rede):
#    Z = 98 (raio único; rodada 2, 07/10/2026: CARREGA mirando para o lado e solta
#        mirando o host — a mira do soltar atravessa a rede);
#    X = 160 (o cliente começa a 21 m e 5 m ao lado: a esfera do fim cai no host);
#    C ≥ 1 estouro de 40 (chuva na área mirada — mira o host e segura o C inteiro; a queda
#        é sorteada, então o mínimo prova a rede, não a sorte).
#
#    (depois do host) godot --headless --path . --script tools/dev_tests/net_pika_client_probe.gd
# ============================================================================

const PASTA := "user://net_pika_skills"

var _p: Node = null
var _host: Node = null
var _falhas: Array[String] = []


func _init() -> void:
	await process_frame
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	if not get_root().get_node("GameFlow").join_room("127.0.0.1"):
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
	for i in 600:
		await process_frame
		if str(_p.current_fruit_id) == "pika_pika":
			break
	_ok("o servidor entregou a Pika ('%s')" % _p.current_fruit_id, str(_p.current_fruit_id) == "pika_pika")
	_p.combat_mode = "fruit"
	await _esperar(0.8)

	# Z: carrega olhando para o LADO (nada sai), gira para o host e solta: o raio sai
	# para a mira do soltar, a 10 m.
	await _lugar(_host.global_position + Vector3(0, 0, 10.0), PI * 0.5)
	var vida := float(_host.health)
	_p.energy = _p.max_energy
	(_p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	_p.begin_charge("Z")
	await _esperar(0.6)
	var segurando := vida - float(_host.health)
	await _mirar_em(_host.global_position + Vector3.UP * 0.3)
	_p.release_charge("Z")
	await _esperar(1.5)
	var z := vida - float(_host.health)
	_ok("Z: segurando não fere (%.1f); solto mirando o host, a vida dele caiu 98 aqui (caiu %.1f)" % [segurando, z],
		segurando < 0.5 and absf(z - 98.0) < 3.0)

	# X: o fim do zigue-zague é 21 m à frente e 5 m à ESQUERDA da partida; escolhe o rumo
	# em que a partida tem chão (a arena tem buracos) e começa lá, olhando reto.
	await _esperar(1.0)
	var partida := _partida_do_x()
	await _lugar(partida.p, partida.yaw)
	print("[CLI] X parte de %s (yaw %.0f°)" % [partida.p.snapped(Vector3.ONE * 0.1), rad_to_deg(partida.yaw)])
	vida = float(_host.health)
	await _tecla("X")
	await _esperar(2.5)
	var x := vida - float(_host.health)
	_ok("X: a esfera do fim do zigue-zague cai no host, 160 (caiu %.1f)" % x, absf(x - 160.0) < 5.0)

	# C: chuva na área mirada — mira o host a 12 m, segura 1,1 s e solta (o que saiu cai).
	await _esperar(1.5)
	await _lugar(_host.global_position + Vector3(0, 0, 12.0), 0.0)
	await _mirar_em(_host.global_position)
	vida = float(_host.health)
	_p.energy = _p.max_energy
	(_p.get("_fruit_cooldowns") as Dictionary)["C"] = 0.0
	# Segura o C INTEIRO (8 ondas = 112 bolinhas): a queda é sorteada por igual num círculo
	# de 9 m e, com 1,1 s (70 bolinhas), um alvo no meio leva ~4 estouros em média — mas 1
	# ou menos em ~11 % das vezes (07/10/2026: 0,8 numa bateria). O que a REDE tem de provar
	# é que o servidor fere quem foi mirado: pelo menos um estouro.
	_p.begin_charge("C")
	await _esperar(2.0)
	_p.release_charge("C")
	await _esperar(1.8)
	var c := vida - float(_host.health)
	_ok("C: a chuva cai no host mirado, %.1f estouros de 40 (caiu %.1f)" % [c / 40.0, c], c >= 40.0 - 1.0)

	# F (rodada 3): voo de luz — segura 0,8 s e solta; o cliente anda pela mira.
	await _esperar(1.5)
	await _lugar(_host.global_position + Vector3(0, 0, 20.0), PI)
	_p._pitch = 0.1
	_p.call("_update_pivot")
	var de: Vector3 = _p.global_position
	_p.energy = _p.max_energy
	(_p.get("_fruit_cooldowns") as Dictionary)["F"] = 0.0
	_p.begin_charge("F")
	await _esperar(0.8)
	_p.release_charge("F")
	var voou: float = (_p.global_position - de).length()
	_ok("F: voou %.1f m em 0,8 s pela mira" % voou, voou > 15.0)
	await _esperar(1.0)
	print("%s" % ("✅ PIKA EM REDE OK (cliente)" if _falhas.is_empty() else "❌ %d falha(s): %s" % [_falhas.size(), str(_falhas)]))
	await _esperar(1.0)
	SkillsPublicadas.pasta_forcada = ""
	quit(0 if _falhas.is_empty() else 1)


## Rumo (yaw) e partida do X para a esfera cair no host, com chão na partida.
func _partida_do_x() -> Dictionary:
	var alvo: Vector3 = _host.global_position
	for k in 8:
		var yaw := k * TAU / 8.0
		var frente := Vector3(-sin(yaw), 0, -cos(yaw))
		var esquerda := -frente.cross(Vector3.UP).normalized()
		var p0 := alvo - frente * 21.0 - esquerda * 5.0
		var q := PhysicsRayQueryParameters3D.create(p0 + Vector3.UP * 4.0, p0 + Vector3.DOWN * 4.0, 1)
		var hit := (_p as Node3D).get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and absf((hit.position as Vector3).y - (alvo.y - 0.8)) < 0.6:
			return {"p": Vector3(p0.x, alvo.y, p0.z), "yaw": yaw}
	return {"p": alvo + Vector3(5.0, 0, 21.0), "yaw": 0.0}


func _mirar_em(ponto: Vector3) -> void:
	var cam: Camera3D = _p.get("_cam")
	for i in 30:
		var d := (ponto - cam.global_position).normalized()
		_p._yaw = atan2(-d.x, -d.z)
		_p._pitch = asin(clampf(d.y, -1.0, 1.0))
		_p.call("_update_pivot")
		await process_frame


func _lugar(pos: Vector3, yaw: float) -> void:
	_p.global_position = pos
	_p.velocity = Vector3.ZERO
	_p._yaw = yaw
	_p._pitch = -0.05
	_p.call("_update_pivot")           # a mira do golpe sai da câmera: sem isto ela fica na antiga
	await _esperar(0.6)


func _tecla(slot: String) -> void:
	_p.energy = _p.max_energy
	(_p.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
	_p.begin_charge(slot)
	await process_frame
	_p.release_charge(slot)


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
