extends CharacterBody3D
## Corpo de campo dos humanos; o visual é o mesmo dos tripulantes de bordo.
const P := preload("res://src/historia/tripulantes/provisoes.gd")
var alvo_de: Callable
var sistema: Node
var id := ""
var health := 100.0
var max_health := 100.0
var visual: TripulanteHumano
var _ataque := 0.0
var _alvo: Node3D
var _golpe_em := 0.0
var _golpe_alvo: Node3D
var _andando := false
const ZONA_PARADA := 0.9        # m até o ponto: dentro disso o aliado fica parado
const GANHO_DE_SEGUIR := 4.0    # (m/s) por metro de distância além da zona
const ACELERACAO := 18.0        # m/s²: suaviza partida e parada

func montar(personagem: String, bib: BibliotecaDeModelos) -> void:
	alvo_de = sistema.jogador_de
	add_to_group("pets_historia")
	add_to_group("alvo_de_besta")
	collision_layer = 0
	collision_mask = 1
	var col := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.height = 1.8
	capsula.radius = 0.35
	col.shape = capsula
	col.position.y = 0.9
	add_child(col)
	visual = TripulanteHumano.new()
	add_child(visual)
	var recrutado := Tripulacao.ficha_recrutada(sistema.progressao, personagem)
	visual.montar(personagem, bib, recrutado)
	if not recrutado.is_empty():
		max_health = maxf(1, float(recrutado.get("vida", 100)))
		health = max_health
	HurtboxDeCombate.instalar(self, Vector3(0.7, 1.8, 0.7))
	HurtboxDeCombate.redimensionar(self, Vector3(0.7, 1.8, 0.7), 0.9)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(sistema) or health <= 0: return
	var dono: Node3D = sistema.jogador_de.call()
	if dono == null: return
	var d := P.estado(sistema.progressao)
	if _golpe_em > 0:
		_golpe_em -= delta
		if _golpe_em <= 0 and is_instance_valid(_golpe_alvo) and global_position.distance_to(_golpe_alvo.global_position) < 2.6:
			if _golpe_alvo.is_in_group("npc"):
				_crime(_golpe_alvo, d)
			elif _golpe_alvo.has_method("take_damage"):
				CombatResolver.aplicar(_golpe_alvo, 10, 0, 0, global_position, Vector3.ZERO, 0.2, 0, false, self)
	_ataque = maxf(0, _ataque - delta)
	var hostil: bool = P.tem_cargo(sistema.progressao, 4) and d.alinhamento == "maligno"
	var defender: bool = not P.tem_cargo(sistema.progressao, 4) or d.alinhamento != "amigavel"
	_alvo = Tripulacao.inimigo_mais_proximo(get_tree(), dono.global_position, 15) if defender else null
	if hostil and _alvo == null:
		for n in get_tree().get_nodes_in_group("npc"):
			if n is Node3D and not bool(n.get_meta("capturado", false)) and not bool(n.get_meta("morto", false)) and global_position.distance_to(n.global_position) < 10:
				_alvo = n
				break
	var vaga: int = d.vagas.find(id)
	var destino := dono.global_position + Vector3((vaga % 3 - 1) * 2, 0, 2 + vaga / 3 * 2)
	if is_instance_valid(_alvo): destino = _alvo.global_position
	var dir := destino - global_position
	dir.y = 0
	var distancia := dir.length()
	if distancia > 45 and _alvo == null: global_position = destino + Vector3.UP
	# Seguir o dono: velocidade PROPORCIONAL à distância do ponto (nunca liga/desliga a 5,5 m/s, que fazia o aliado alcançar,
	# parar, ficar para trás e arrancar de novo a cada passo do jogador andando, alternando descanso/caminhada). Com alvo
	# de combate mantém o avanço direto.
	var vmax := 5.5
	if _alvo == null:
		var v_dono := Vector2(dono.velocity.x, dono.velocity.z).length() if "velocity" in dono else 0.0
		vmax = maxf(5.5, v_dono * 1.15)
	var desejada := vmax if _alvo != null and distancia > 1.8 else 0.0
	if _alvo == null:
		desejada = clampf((distancia - ZONA_PARADA) * GANHO_DE_SEGUIR, 0.0, vmax)
	var d_n := dir.normalized()
	var atual := Vector2(velocity.x, velocity.z)
	atual = atual.move_toward(Vector2(d_n.x, d_n.z) * desejada, ACELERACAO * delta)
	velocity.x = atual.x
	velocity.z = atual.y
	if not is_on_floor(): velocity.y -= 24 * delta
	else: velocity.y = 0
	EscaladaDeMob.ajudar(self, delta)
	move_and_slide()
	if visual != null:
		# Histerese na animação: só volta ao descanso abaixo de 0,3 m/s e só caminha acima de 0,6 (evita tremer na fronteira).
		var vel := Vector2(velocity.x, velocity.z).length()
		_andando = vel > (0.3 if _andando else 0.6)
		visual.definir_velocidade(vel if _andando else 0.0)
		visual.virar_para(dir, minf(1, delta * 8))
	if _alvo != null and distancia < 2.2 and _ataque <= 0:
		_ataque = 1.2
		_golpe_em = 0.22
		_golpe_alvo = _alvo
		if visual != null: visual.golpear()

func _crime(npc: Node3D, d: Dictionary) -> void:
	if not d.get("vitimas") is Dictionary: d["vitimas"] = {}
	var chave := str(npc.name)
	if d.vitimas.has(chave): return
	# Política explícita selecionável no B: roubar, matar ou escravizar NPCs.
	var politica := str(d.get("politica", "roubar"))
	d.vitimas[chave] = politica
	if politica == "roubar":
		sistema.progressao.ouro += 5
		npc.set_meta("capturado", true) # impede repetir a mesma vítima na sessão
	elif politica == "matar":
		npc.set_meta("morto", true)
		npc.hide()
		npc.collision_layer = 0
	else:
		npc.set_meta("capturado", true)
		npc.set_meta("escravizado", true)
		npc.set("_fala_ate", 0)
		npc.call("falar", "Capturado pela tripulação")
	sistema.aviso.emit("Comandante maligno: %s — %s." % [politica, npc.call("nome")])
	sistema.progressao.mudou.emit()

func take_damage(amount: float, _from := Vector3.ZERO, _kb := Vector3.ZERO, _hitstun := 0.0) -> void:
	if bool(get_meta("dano_do_jogador", false)): return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server(): return
	if amount <= 0 or health <= 0: return
	if sistema.proteger(self, amount): return
	health = maxf(0, health - amount)
	P.estado(sistema.progressao).membros[id].vida = health
	if health <= 0:
		sistema.registrar_morte(id)
		queue_free()
