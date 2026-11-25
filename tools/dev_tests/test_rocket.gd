extends SceneTree
## Integração offline: Player/rig/DamageZone reais, sem ocupar a porta da arena.
const CASA := Vector3(0, 100.82, 0)
var jogador: CharacterBody3D
var alvo: CharacterBody3D
var mundo: Node3D
var falhas := 0
var checks := 0
var identidade := 100

func _init() -> void:
	await process_frame
	create_timer(90).timeout.connect(func(): quit(2))
	mundo = Node3D.new()
	root.add_child(mundo)
	current_scene = mundo
	_caixa(Vector3(0, 99.7, 0), Vector3(100, 0.6, 100))
	jogador = load("res://Player.gd").new()
	jogador.name = "RocketPlayer"
	mundo.add_child(jogador)
	jogador.global_position = CASA
	jogador.equip_fruit("rocket")
	jogador.combat_mode = "fruit"
	alvo = load("res://src/entities/TrainingDummy.gd").new()
	mundo.add_child(alvo)
	alvo.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _esperar(0.15)
	_ok(jogador._rocket != null, "controlador montado no Player real")
	await _custos()
	await _soco()
	await _crash()
	await _barragem()
	await _ultimate()
	await _ciclo_de_vida()
	print("ROCKET: %d verificações, %d falhas" % [checks, falhas])
	mundo.queue_free()
	await process_frame
	await process_frame
	quit(0 if falhas == 0 else 1)

func _reset() -> void:
	jogador._rocket.cancelar()
	await _esperar(0.85)
	jogador.equip_fruit("rocket")
	jogador.combat_mode = "fruit"
	jogador.global_position = CASA
	jogador.velocity = Vector3.ZERO
	jogador.health = jogador.max_health
	jogador.energy = jogador.max_energy
	jogador._fruit_damage_lock_timer = 0
	jogador._hitstop_timer = 0
	jogador._fsm.transition_to("Idle")
	jogador._fruit_cooldowns.clear()
	jogador._server_cast_next_ms.clear()
	alvo.global_position = CASA + Vector3(20, 0, 0)
	alvo.health = alvo.MAX_HP
	await _esperar(0.1)

func _cast(slot: String, dir := Vector3.FORWARD) -> void:
	identidade += 1
	jogador._do_server_cast(slot, dir, jogador.global_position + Vector3.UP,
		0.0, identidade, "fruit", "rocket")

func _custos() -> void:
	await _reset()
	var energia: float = jogador.energy
	_cast("Z", Vector3(NAN, 0, 0))
	_ok(jogador.energy == energia and not jogador._rocket.ocupado(), "mira NaN recusada sem custo")
	jogador._do_server_cast("X", Vector3.FORWARD, CASA + Vector3.RIGHT * 40,
		0, identidade + 1, "fruit", "rocket")
	_ok(jogador.energy == energia, "origem forjada recusada")
	jogador.energy = 0
	_cast("C")
	_ok(not jogador._rocket.ocupado(), "energia insuficiente recusa C")
	jogador.energy = energia
	_cast("Z")
	_ok(is_equal_approx(jogador.energy, energia - jogador.ENERGY_SKILL), "custo cobrado uma vez")
	_ok(is_equal_approx(jogador._fruit_cooldowns.Z, 5), "cooldown Z usa registro")
	var apos: float = jogador.energy
	jogador._do_server_cast("Z", Vector3.FORWARD, CASA, 0, identidade, "fruit", "rocket")
	_ok(jogador.energy == apos, "replay de token não duplica custo")
	await _esperar(0.6)
	_cast("Z")
	_ok(not jogador._rocket.ocupado(), "recarga recusa novo Z após recuperar")

func _soco() -> void:
	for altura in [0.0, 3.0]:
		await _reset()
		jogador.global_position.y += altura
		alvo.global_position = jogador.global_position + Vector3.FORWARD * 2
		await _esperar(0.03)
		_cast("Z")
		await _esperar(0.5)
		_ok(is_equal_approx(alvo.MAX_HP - alvo.health, 88), "Z acerta uma vez em altura %.1f" % altura)
		_ok(not jogador._rocket.ocupado(), "Z libera corpo")
	await _reset()
	alvo.global_position = CASA + Vector3.FORWARD * 2.5
	var parede := _caixa(CASA + Vector3.FORWARD * 1.2, Vector3(5, 5, 0.25))
	await _esperar(0.05)
	_cast("Z")
	await _esperar(0.6)
	_ok(alvo.health == alvo.MAX_HP, "Z não fere atrás da parede")
	parede.queue_free()
	await _reset()
	_cast("Z", Vector3.RIGHT)
	await _esperar(0.6)
	_ok(not jogador._rocket.ocupado(), "Z sem alvo termina mirando lateralmente")

func _crash() -> void:
	for altura in [0.0, 3.0]:
		await _reset()
		jogador.global_position.y += altura
		_cast("X")
		await _esperar(1.1)
		_ok(jogador.global_position.z < -10 and jogador.global_position.z > -12,
			"X completa percurso no chão/ar %.1f: %.2f" % [altura, jogador.global_position.z])
	await _reset()
	var parede := _caixa(CASA + Vector3.FORWARD * 4, Vector3(5, 8, 0.25))
	await _esperar(0.04)
	_cast("X")
	await _esperar(1)
	_ok(jogador.global_position.z > -3.5, "X para antes da parede fina")
	parede.queue_free()
	await _reset()
	alvo.global_position = CASA + Vector3.FORWARD * 5
	await _esperar(0.05)
	_cast("X")
	await _esperar(1)
	_ok(is_equal_approx(alvo.MAX_HP-alvo.health,160), "X atinge inimigo com 160")
	_ok(jogador.global_position.z > -5, "X termina ao colidir com inimigo")
	await _reset()
	var rampa := _caixa(CASA + Vector3(0,-0.3,-4), Vector3(6,0.4,7))
	rampa.rotation.x = 0.18
	await _esperar(0.05)
	_cast("X")
	await _esperar(1.3)
	_ok(jogador.global_position.y > 100 and not jogador._rocket.ocupado(), "X em rampa não atravessa o terreno")
	rampa.queue_free()

func _barragem() -> void:
	await _reset()
	_cast("C")
	await _esperar(1.6)
	_ok(not jogador._rocket.ocupado(), "C sem inimigo encerra")
	await _reset()
	alvo.global_position = CASA + Vector3.FORWARD * 8
	await _esperar(0.05)
	_cast("C")
	await _esperar(1.5)
	_ok(is_equal_approx(alvo.MAX_HP-alvo.health,320), "C oito impactos reais totalizam 320")
	await _reset()
	var outro: Node3D = load("res://src/entities/TrainingDummy.gd").new()
	mundo.add_child(outro)
	outro.set_physics_process(false)
	alvo.global_position = CASA + Vector3(0,0,-8)
	outro.global_position = CASA + Vector3(0.9,0,-8)
	await _esperar(0.05)
	_cast("C")
	await _esperar(1.5)
	_ok(alvo.health < alvo.MAX_HP and outro.health < outro.MAX_HP, "C atinge vários alvos na área")
	_ok(alvo.MAX_HP-alvo.health <=320 and outro.MAX_HP-outro.health <=320, "teto C é por alvo")
	outro.queue_free()
	await _reset()
	alvo.global_position = CASA + Vector3.FORWARD * 5
	var parede := _caixa(CASA + Vector3.FORWARD * 3.8, Vector3(5,5,0.2))
	await _esperar(0.05)
	_cast("C")
	await _esperar(1.5)
	_ok(alvo.health == alvo.MAX_HP, "C próximo de parede respeita cobertura das explosões")
	parede.queue_free()

func _ultimate() -> void:
	await _reset()
	_cast("V")
	_ok(jogador._rocket.fase == "carga", "V inicia em preparação")
	await _esperar(0.5)
	_ok(jogador._rocket.buff > 5.7 and not jogador._rocket.ocupado(), "V libera movimento após carga")
	_ok(jogador._rocket.fator_velocidade() == 1.3 and jogador._rocket.fator_aceleracao() == 1.6, "V compõe buffs de velocidade/aceleração")
	_cast("Z")
	await _esperar(0.36)
	_ok(not jogador._rocket.ocupado(), "Z acelerado termina em menos de 0.36 s")
	_cast("X")
	await _esperar(1.2)
	_ok(jogador.global_position.z < -14 and jogador.global_position.z > -16, "X estendido percorre 15 m")
	alvo.global_position = jogador.global_position + Vector3.RIGHT * 2
	var base: float = jogador.global_position.y
	var max_y := base
	for _i in 420:
		await physics_frame
		max_y = maxf(max_y, jogador.global_position.y)
	_ok(max_y > base + 6, "final V sobe usando propulsão")
	_ok(is_equal_approx(alvo.MAX_HP-alvo.health,576), "final V causa 576 ao alvo próximo")
	_ok(jogador.global_position.y >= 100.75, "mergulho não atravessa piso")
	_ok(jogador._rocket.buff == 0 and not jogador._rocket.ocupado(), "V termina e retira buffs")
	await _reset()
	var rampa := _caixa(CASA + Vector3(0,-0.15,0), Vector3(8,0.5,8))
	rampa.rotation.z = 0.12
	await _esperar(0.1)
	_cast("V")
	await _esperar(8)
	_ok(jogador.global_position.y > 100 and not jogador._rocket.ocupado(), "V final em terreno inclinado respeita solo")
	rampa.queue_free()

func _ciclo_de_vida() -> void:
	await _reset()
	_cast("V")
	await _esperar(0.6)
	jogador.equip_fruit("ope_ope")
	await _esperar(1)
	_ok(jogador._rocket.buff == 0 and get_nodes_in_group("rocket_vfx").is_empty(), "troca de fruta limpa buff e partículas")
	await _reset()
	_cast("C")
	await _esperar(0.3)
	jogador.take_damage(10, CASA + Vector3.RIGHT, Vector3.ZERO, 0.1)
	await _esperar(1)
	_ok(not jogador._rocket.ocupado() and get_nodes_in_group("rocket_hitbox").is_empty(), "dano cancela C e hitboxes")
	await _reset()
	_cast("X")
	jogador._cast.abortar()
	await _esperar(1)
	_ok(not jogador._rocket.ocupado(), "interrupção explícita libera corpo")
	await _reset()
	_cast("V")
	await _esperar(0.6)
	jogador.health = 0
	await _esperar(1)
	_ok(jogador._rocket.buff == 0 and not jogador._rocket.ocupado(), "morte durante V cancela final")
	await _reset()
	var base := get_node_count()
	for _i in 5:
		jogador._fruit_cooldowns.clear()
		jogador._server_cast_next_ms.clear()
		_cast("C")
		await _esperar(2.3)
	_ok(get_nodes_in_group("rocket_hitbox").is_empty() and get_nodes_in_group("rocket_vfx").is_empty(), "cinco casts não deixam efeitos permanentes")
	_ok(get_node_count() <= base, "nós retornam à base: %d → %d" % [base,get_node_count()])

func _caixa(at: Vector3, tamanho: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = tamanho
	col.shape = shape
	body.add_child(col)
	mundo.add_child(body)
	body.global_position = at
	return body

func _esperar(segundos: float) -> void:
	for _i in ceili(segundos * 60): await physics_frame

func _ok(condicao: bool, texto: String) -> void:
	checks += 1
	if not condicao: falhas += 1
	print(("✅ " if condicao else "❌ ") + texto)
