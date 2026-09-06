extends SceneTree
# ============================================================================
#  PX IRON PUNCHES — o X do Pacifista.
#
#  Pedido do dono (2026-09-01): "uma sequência de socos, basicamente o braço
#  inteiro do jogador é clonado e disparado diversas vezes para frente, até 2
#  metros."
#
#  ⚠️ O QUE FALHA EM SILÊNCIO: "até 2 metros". Um golpe com alcance errado
#  continua bonito na tela e continua acertando o boneco de teste, que costuma
#  estar perto. Por isso aqui existe um alvo LONGE que NÃO pode apanhar — sem
#  ele, um alcance de 20 m passaria como acerto.
#
#      DISPLAY=:1 godot --path . -s tools/dev_tests/test_socos_de_ferro.gd
# ============================================================================

const CAMINHO := "res://src/combat/socos_de_ferro.gd"

var _ok_n := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		await process_frame

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return

	p.set_meta("damage_immune", true)
	p.combat_mode = "style"
	p.current_style_idx = 1
	p.energy = p.max_energy
	await _quadros(2)

	await _a_sequencia(p)
	await _o_alcance(p)

	print("\n%d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## 1. É UMA SEQUÊNCIA DE BRAÇOS CLONADOS — não um soco só.
func _a_sequencia(p: Node3D) -> void:
	print("=== 1. a sequência de braços clonados ===")
	var Socos = load(CAMINHO)
	_ok("são vários socos, não um", int(Socos.SOCOS) >= 3)
	_ok("o alcance declarado é 2 m", absf(float(Socos.ALCANCE) - 2.0) < 0.01)
	_ok("cada braço fica visível por pelo menos 7 quadros a 30 fps",
		float(Socos.IDA) * 30.0 >= 7.0)
	_ok("a cadência permite braços simultâneos", float(Socos.INTERVALO) < float(Socos.IDA))

	_soltar_x(p)
	await _quadros(3)
	var no := _no_de_socos(p)
	_ok("o X acende a sequência", no != null)
	if no == null:
		return

	# Conta os braços que existiram ao longo do golpe e mede o quanto o primeiro
	# deles avançou. Amostrar é obrigatório: cada braço vive ~0,13 s e some.
	var vistos := {}
	var avanco_max := 0.0
	var origem_do_primeiro := Vector3.ZERO
	var primeiro: Node3D = null
	var simultaneos_max := 0
	var achou_rastro_correto := false
	for i in 120:
		await process_frame
		if not is_instance_valid(no):
			break
		var simultaneos := 0
		for c in no.get_children():
			if not (c is Node3D) or not c.has_meta("iron_punch"):
				continue
			simultaneos += 1
			vistos[c.get_instance_id()] = true
			for filho in c.get_children():
				if filho.has_meta("iron_punch_trail"):
					var mat := filho.material_override as StandardMaterial3D
					achou_rastro_correto = mat != null and (
						mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED)
			if primeiro == null:
				primeiro = c
				origem_do_primeiro = c.global_position
		if is_instance_valid(primeiro):
			avanco_max = maxf(avanco_max, origem_do_primeiro.distance_to(primeiro.global_position))
		simultaneos_max = maxi(simultaneos_max, simultaneos)

	print("   braços clonados vistos: %d | avanço do 1º: %.2f m" % [vistos.size(), avanco_max])
	_ok("nasceu mais de um braço (é sequência)", vistos.size() >= 3)
	_ok("o braço percorre perto de 2 m", absf(avanco_max - 2.0) < 0.35)
	_ok("há pelo menos dois braços simultâneos", simultaneos_max >= 2)
	_ok("o rastro de movimento não usa billboard", achou_rastro_correto)

	# ⚠️ NÃO PODE SOBRAR BRAÇO NO AR. Um clone esquecido fica de enfeite no mapa
	# para sempre — e como ele carrega DamageZone, viraria uma armadilha invisível.
	await _esperar(1.5)
	_ok("nenhum braço fantasma fica no mapa", _no_de_socos(p) == null)


## 2. O ALCANCE É MESMO DE 2 m: perto apanha, longe não.
func _o_alcance(p: Node3D) -> void:
	print("\n=== 2. o alcance de 2 m ===")
	var alvo := _alvo_na_mira(p, 1.2)
	if alvo == null:
		_ok("havia um alvo para medir", false)
		return
	var vida0: float = float(alvo.get("health"))
	_soltar_x(p)
	await _esperar(1.6)
	var perdeu_perto: float = vida0 - float(alvo.get("health"))
	print("   alvo a 1,2 m do corpo perdeu %.0f de vida" % perdeu_perto)
	_ok("o alvo dentro do alcance apanha", perdeu_perto > 0.0)

	# O CONTROLE: mesmo golpe, alvo a 5 m. Se este também apanhar, o "até 2
	# metros" não existe — e o teste de cima estaria passando por sorte.
	_zerar_recarga(p)
	var _ignorado := _alvo_na_mira(p, 5.0)
	var vida1: float = float(alvo.get("health"))
	_soltar_x(p)
	await _esperar(1.6)
	var perdeu_longe: float = vida1 - float(alvo.get("health"))
	print("   alvo a 5,0 m do corpo perdeu %.0f de vida" % perdeu_longe)
	_ok("o alvo fora do alcance NÃO apanha", perdeu_longe <= 0.0)


# ------------------------------------------------------------------ apoio
## O X do Pacifista não é carregável: no jogo ele sai quando a tecla é SOLTA.
func _soltar_x(p: Node3D) -> void:
	_zerar_recarga(p)
	p.begin_charge("X")
	p.release_charge("X")


func _zerar_recarga(p: Node3D) -> void:
	p._skill_cooldowns["X"] = 0.0
	if p.get("_style_cooldowns") != null:
		p._style_cooldowns["X"] = 0.0


func _no_de_socos(p: Node3D) -> Node:
	for n in get_root().get_tree().get_nodes_in_group("player"):
		pass
	for n in _todos_os_nos(get_root()):
		var s = n.get_script()
		if s != null and s.resource_path == CAMINHO and not n.is_queued_for_deletion():
			return n
	return null


func _todos_os_nos(raiz: Node) -> Array:
	var fila: Array = [raiz]
	var saida: Array = []
	while not fila.is_empty():
		var n: Node = fila.pop_back()
		saida.append(n)
		for c in n.get_children():
			fila.append(c)
	return saida


## ⚠️ A DISTÂNCIA É MEDIDA DO CORPO, não de `mira_do_cast()["origem"]` — aquela
## origem já nasce 1,5 m À FRENTE do jogador, e usá-la punha o alvo "a 1,4 m" a
## quase 3 m do ombro de onde o braço parte. O golpe estava certo; a régua não.
func _alvo_na_mira(p: Node3D, dist: float) -> Node3D:
	var mira: Dictionary = p.mira_do_cast()
	var destino: Vector3 = p.global_position + Vector3.UP * 1.0 + mira["aim"] * dist
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and e.has_method("take_damage"):
			e.global_position = destino
			if e.get("max_health") != null:
				e.set("health", e.get("max_health"))
			return e
	return null


func _quadros(n: int) -> void:
	for i in n:
		await process_frame


func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond:
		_ok_n += 1
		print("   ✓ %s" % rotulo)
	else:
		_falhas += 1
		print("   ❌ %s" % rotulo)
