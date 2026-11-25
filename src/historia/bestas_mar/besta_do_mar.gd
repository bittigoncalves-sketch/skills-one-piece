extends CharacterBody3D
## Animais marinhos colocados pela loja: rotina costeira ou boss de projéteis.
## Origem no chão; só este componente move o corpo. Clipes sem root motion.
signal morreu(besta: Node3D)
signal disparou(bolha: Node3D)
const Animador := preload("res://src/historia/bestas_mar/animador.gd")
const Bolha := preload("res://src/historia/bestas_mar/bolha_de_agua.gd")
const Compressor := preload("res://src/historia/bestas_mar/raio_compressor.gd")
const Preparo := preload("res://src/historia/bestas_mar/preparo_de_agua.gd")
const BOLHAS_POR_SALVA := 5
const ABERTURA_BOLHAS := 6.0
const Perfis := preload("res://src/historia/bestas_mar/perfis.json")
const Sweep := preload("res://src/combat/SwordSweep.gd")
const ACAO := ["irritado", "atacando", "recebendo_dano", "disparando_ataque"]
const DISPARO_EM := 0.54
const ESQUECER_EM := 5.0
## Postura de foca e leão-marinho (08/10/2026). Pedido do dono: "na terra, quando a
## besta estiver dormindo, ela deve estar com o corpo completamente deitado, e o corpo
## deve estar deitado quando estiver nadando no mar também". Quais clipes deitam:
## `Animador.DEITADOS`; os demais ficam em pé (boiar, ameaçar, morder).
## Graus por segundo para virar ("lenta na terra, ágil na água", escolha do dono).
const GIRO_TERRA := 35.0
const GIRO_AGUA := 120.0
## Nadando deitada, o corpo inclina para dentro da curva (rad por rad/s de giro; teto).
const INCLINA_NA_CURVA := 0.45
const INCLINACAO_MAX := 0.5
## Fundura da origem abaixo da superfície, em unidades do modelo (× escala): em pé só
## cabeça e pescoço saem; deitada o dorso aflora e a cabeça erguida fica fora (medido).
const CALADO_EM_PE := 3.2
const CALADO_DEITADA := 3.5
## Altura do eixo do corpo deitado (pivô da inclinação), em unidades do modelo.
const EIXO_DEITADA := 2.0
## Sem limite de fôlego (pedido do dono): fica embaixo d'água este tempo, padrão.
const SUBMERSO_PADRAO := 60.0

var especie := ""
var ficha: Dictionary
var health := 0.0
var max_health := 0.0
var estado := "idle"
var nadando := false
var agressiva := false
var origem := Vector3.ZERO
var praia := Vector3.ZERO
var mar := Vector3.INF
var alvo_de: Callable
var alvo: Node3D
var modelo: Node3D
var animador := Animador.new()
var _escala := Vector3.ONE
var _altura := 10.0
var _calado := 3.2
var _raio := 1.5
var _hurtbox: StaticBody3D
var _destino := Vector3.ZERO
var _rotina := 0.0
var _recarga := 0.0
var _perdido := 0.0
var _acertou := false
var ataque_atual := "bolhas"
var _proximo_compressor := false
var _preparo_agua: Node3D
var _raio_agua: Node3D
var _empurrao := Vector3.ZERO
var _voltando := false
var _banho := false
var _passeando := false
var _etapa_praia := 0
var _tempo_mar := 0.0
var _mergulhou := false
var _profundidade := 0.0
var _lado_passeio := 1.0
var _apos_dano := "irritado"
var _tempo_morto := 0.0
var _yaw_inicial := 0.0
var _rng := RandomNumberGenerator.new()
var _giro := 0.0            # rad/s de agora (vira com aceleração e inclina na curva)
var _virou := false         # alguém pediu rumo desde o último quadro
var _pivo: Node3D           # gira o corpo no próprio eixo (inclinação na curva)
var _forma_dano: BoxShape3D
var _no_dano: CollisionShape3D
var _relogio_dano := 0.0
var _max_inclina := 0.0     # (medição) maior inclinação na curva; usado pelos testes


func montar(bib: BibliotecaDeModelos, id: String, peca: Dictionary) -> void:
	especie = id
	ficha = Perfis.data[id].duplicate(true)
	max_health = float(ficha.vida)
	health = max_health
	var info := bib.info(id)
	var medidas: Vector3 = peca["tamanho"]
	_escala = medidas / (info["tamanho"] as Vector3)
	_altura = medidas.y
	_raio = maxf(0.3, 1.6 * minf(_escala.x, _escala.z))
	_calado = 3.2 * _escala.y
	modelo = bib.instanciar(id)
	modelo.name = "Modelo"
	modelo.scale = _escala
	var centro: Vector3 = info["centro"]
	# O modelo fica num pivô na altura do eixo do corpo deitado: a inclinação na curva
	# gira o corpo em volta dele mesmo, não do ponto no chão.
	_pivo = Node3D.new()
	_pivo.name = "Pivo"
	_pivo.position = Vector3.UP * EIXO_DEITADA * _escala.y
	add_child(_pivo)
	modelo.position = -centro * _escala + Vector3.UP * medidas.y * 0.5 - _pivo.position
	_pivo.add_child(modelo)
	var cs := CollisionShape3D.new()
	cs.name = "Colisao"
	var forma := CapsuleShape3D.new()
	forma.radius = _raio
	forma.height = maxf(4.0 * _escala.y, _raio * 2)
	cs.shape = forma
	cs.position.y = forma.height * 0.5
	add_child(cs)
	collision_layer = 1
	collision_mask = 1
	_hurtbox = StaticBody3D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = HurtboxDeCombate.CAMADA
	_hurtbox.collision_mask = 0
	_hurtbox.set_meta("hurtbox_de", self)
	var h := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = medidas * Vector3(.6, .95, .75)
	h.shape = caixa
	h.position.y = medidas.y * .48
	_hurtbox.add_child(h)
	_forma_dano = caixa
	_no_dano = h
	add_child(_hurtbox)
	set_meta("hurtbox", _hurtbox)
	rotation.y = deg_to_rad((peca["rotacao_graus"] as Vector3).y)
	_yaw_inicial = rotation.y
	_rng.randomize()
	max_slides = 3
	add_to_group("bestas_do_mar")
	add_to_group(AlvosDeGolpe.GRUPO)
	if boss():
		add_to_group(BarrasDeChefes.GRUPO)   # vida no topo da tela (08/10/2026)
	if boss():
		add_to_group("enemy")
	if boss():
		animador.boca_local = Vector3(0, 7.16, -3.02)
	animador.corpo = self
	animador.montar(modelo)


func boss() -> bool:
	return bool(ficha.get("boss", false))


func vivo() -> bool:
	return health > 0.0


func nome_de_exibicao() -> String:
	return str(ficha.get("nome", "Besta do mar"))


func em_combate() -> bool:
	return agressiva


func centro_do_corpo() -> Vector3:
	# O meio da área de dano, que acompanha a postura (deitada, o corpo vai à frente).
	if _no_dano and _no_dano.is_inside_tree():
		return _no_dano.global_position
	return global_position + Vector3.UP * minf(_altura * .3, 5.0)


## O estado da IA × o clipe tocado. Na água a besta boia em pé (como a foca "de
## garrafa") e nada deitada; na areia anda e fica parada ERETA, como antes.
func clipe_do_estado(e: String) -> String:
	match e:
		"idle": return "boiando" if nadando else "idle"
		"nadando_walk": return "nadando_walk" if nadando else "andando_terra"
		"nadando_run": return "nadando_run" if nadando else "correndo_terra"
	return e


func deitada() -> bool:
	return animador.deitada()


func iniciar_rotina() -> void:
	_proximo_compressor = false
	agressiva = false
	alvo = null
	_perdido = 0.0
	_banho = false
	_passeando = false
	_profundidade = 0.0
	_etapa_praia = 0
	_voltando = global_position.distance_to(praia) > 3.0 and not boss()
	_destino = praia
	if not boss():
		remove_from_group("enemy")
	mudar("nadando_walk" if _voltando else "idle" if boss() else "dormindo")
	_rotina = _rng.randf_range(9, 17)


func mudar(novo: String) -> void:
	if novo != "disparando_ataque":
		_limpar_agua()
	elif estado != novo:
		_preparo_agua = Preparo.new()
		_preparo_agua.atirador = self
		_preparo_agua.compressor = ataque_atual == "compressor"
		add_child(_preparo_agua)
		_preparo_agua.global_position = animador.boca()
	estado = novo
	_acertou = false
	if novo != "morto":
		animador.mudar(clipe_do_estado(novo))


func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not vivo():
		_tempo_morto += delta
		modelo.visible = _tempo_morto < 1.5
		if not boss() and _tempo_morto > 60.0:
			reviver()
		return
	var dt := delta * Lentidao.fator(self)
	_recarga = maxf(0.0, _recarga - dt)
	var nivel := AguaDoMundo.nivel_em(global_position.x, global_position.z)
	nadando = not is_nan(nivel)
	# Entrou ou saiu da água: o mesmo estado troca de clipe (nadar ↔ se arrastar).
	animador.mudar(clipe_do_estado(estado))
	animador.avancar(dt)
	_postura(dt)
	if get_meta("is_frozen", false) or get_meta("in_black_hole", false):
		velocity = Vector3.ZERO
		return
	if estado in ACAO:
		_atualizar_acao()
		_mover(Vector3.ZERO, 0.0, dt, nivel)
		return
	if boss() and not agressiva:
		var j: Node3D = alvo_de.call() if alvo_de.is_valid() else null
		if _valido(j) and global_position.distance_to(j.global_position) < float(ficha.visao) and _visivel(j):
			alvo = j
			agressiva = true
			mudar("irritado")
	if agressiva:
		_perseguir(dt, nivel)
	elif boss():
		# Vigilância tem prioridade: o boss não entra na rotina de descanso/mergulho.
		mudar_se_preciso("idle")
		_mover(Vector3.ZERO, 0.0, dt, nivel)
	else:
		_rotina_pacifica(dt, nivel)


func _valido(no: Node3D) -> bool:
	return is_instance_valid(no) and no.is_inside_tree() and no.get("health") != null and float(no.get("health")) > 0.0


func _visivel(no: Node3D) -> bool:
	var excluir: Array[RID] = [get_rid(), _hurtbox.get_rid()]
	return Sweep.visible(get_world_3d().direct_space_state, centro_do_corpo(), AlvosDeGolpe.centro(no), 1, excluir)


func _perseguir(delta: float, nivel: float) -> void:
	if not _valido(alvo):
		iniciar_rotina()
		return
	var ate := alvo.global_position - global_position
	var distancia := Vector2(ate.x, ate.z).length()
	var longe := distancia > float(ficha.visao) or global_position.distance_to(origem) > float(ficha.perseguicao)
	_perdido = _perdido + delta if longe or not _visivel(alvo) else 0.0
	if _perdido >= ESQUECER_EM:
		iniciar_rotina()
		return
	if estado == "irritado":
		_mover(Vector3.ZERO, 0.0, delta, nivel)
		return
	_encarar(ate, delta)
	if nadando and AguaDoMundo.superficie_em(global_position.x, global_position.z) - _calado - global_position.y > 1.0:
		_profundidade = 0.0
		mudar_se_preciso("emergindo")
		_mover(ate, float(ficha.nadar), delta, nivel)
		return
	var alcance := float(ficha.alcance)
	var frente := -global_basis.z
	var alinhada := Vector2(frente.x, frente.z).normalized().dot(Vector2(ate.x, ate.z).normalized()) > .94
	if distancia <= alcance and _recarga <= 0.0 and _visivel(alvo) and alinhada:
		ataque_atual = "compressor" if _proximo_compressor else "bolhas"
		_proximo_compressor = not _proximo_compressor
		mudar("disparando_ataque")
		_mover(Vector3.ZERO, 0.0, delta, nivel)
	elif distancia > alcance * .8:
		mudar_se_preciso("nadando_run")
		_mover(ate, float(ficha.correr) if nadando else float(ficha.andar) * 1.6, delta, nivel)
	else:
		mudar_se_preciso("idle")
		_mover(Vector3.ZERO, 0.0, delta, nivel)


func _rotina_pacifica(delta: float, nivel: float) -> void:
	_rotina -= delta
	if _passeando:
		_passear_no_mar(delta, nivel)
		return
	if _voltando or _banho:
		var ate := _destino - global_position
		ate.y = 0.0
		if ate.length() < 2.0 or _rotina < -20.0:
			if _banho:
				_banho = false
				if nadando and ate.length() < 2.0:
					_passeando = true
					_tempo_mar = 0.0
					_mergulhou = false
					_destino_de_passeio()
				else:
					_voltar_a_praia()
			else:
				if nadando or ate.length() >= 2.0:
					# Um obstáculo não deve fazer a criatura dormir no meio do oceano.
					_rotina = 15.0
				else:
					_voltando = false
					_etapa_praia = 0
					mudar("dormindo")
					_rotina = _rng.randf_range(10, 20)
		else:
			_encarar(ate, delta)
			mudar_se_preciso("nadando_walk")
			_mover(ate, float(ficha.nadar) if nadando else float(ficha.andar), delta, nivel)
			return
	if _rotina <= 0.0:
		_etapa_praia += 1
		if mar != Vector3.INF and _etapa_praia >= 3:
			_banho = true
			_destino = mar
			_rotina = global_position.distance_to(mar) / maxf(float(ficha.nadar), 1.0) + 15.0
		else:
			mudar("idle" if _etapa_praia == 1 else "comendo" if _etapa_praia == 2 else "dormindo")
			_rotina = _rng.randf_range(4, 7) if _etapa_praia < 3 else _rng.randf_range(10, 18)
			if _etapa_praia >= 3: _etapa_praia = 0
	_mover(Vector3.ZERO, 0.0, delta, nivel)


func _voltar_a_praia() -> void:
	_passeando = false
	_banho = false
	_voltando = true
	_profundidade = 0.0
	_destino = praia
	_rotina = global_position.distance_to(praia) / maxf(float(ficha.nadar), 1.0) + 15.0
	mudar_se_preciso("nadando_walk")


func _destino_de_passeio() -> void:
	var rumo := (mar - praia).normalized()
	_lado_passeio *= -1.0
	_destino = mar + Vector3(-rumo.z, 0, rumo.x) * 9.0 * _lado_passeio


func _limite_de_mergulho() -> float:
	var nivel := AguaDoMundo.superficie_em(global_position.x, global_position.z)
	if is_nan(nivel): return 0.0
	var q := PhysicsRayQueryParameters3D.create(Vector3(global_position.x, nivel + .5, global_position.z),
		Vector3(global_position.x, nivel - _altura - 40.0, global_position.z), 1, [get_rid(), _hurtbox.get_rid()])
	var fundo := get_world_3d().direct_space_state.intersect_ray(q)
	# Sem fundo conhecido, não autorizar mergulho; manter passeio de superfície.
	if fundo.is_empty() or fundo.collider.has_method("take_damage"): return 0.0
	return maxf(0.0, minf(_altura - _calado + 1.5, nivel - _calado - fundo.position.y - .8))


func _passear_no_mar(delta: float, nivel: float) -> void:
	_tempo_mar += delta
	if not nadando:
		_voltar_a_praia()
		return
	var ate := _destino - global_position
	ate.y = 0.0
	if ate.length() < 2.0: _destino_de_passeio()
	_encarar(ate, delta)
	var imersao := AguaDoMundo.superficie_em(global_position.x, global_position.z) - _calado - global_position.y
	if not _mergulhou and _tempo_mar >= 3.0:
		_mergulhou = true
		_profundidade = _limite_de_mergulho()
		if _profundidade >= 2.0: mudar("mergulhando")
		else: _profundidade = 0.0
	if estado == "mergulhando":
		if imersao >= _profundidade - .5 and animador.tempo >= animador.duracao():
			mudar("nadando_submerso")
	elif estado == "nadando_submerso":
		if animador.tempo >= float(ficha.get("tempo_submerso", SUBMERSO_PADRAO)):
			_emergir()
	elif estado == "emergindo":
		if imersao < .5 and animador.tempo >= animador.duracao():
			_voltar_a_praia()
	elif _tempo_mar >= 15.0:
		_voltar_a_praia()
	else:
		mudar_se_preciso("nadando_walk")
	# Abortagem controlada se a rota rasa impedir a profundidade solicitada.
	if _tempo_mar > float(ficha.get("tempo_submerso", SUBMERSO_PADRAO)) + 30.0 and _profundidade > 0.0: _emergir()
	_mover(ate, float(ficha.nadar) * (.7 if _profundidade > 0.0 else 1.0), delta, nivel)


func _emergir() -> void:
	_profundidade = 0.0
	mudar_se_preciso("emergindo")


func mudar_se_preciso(novo: String) -> void:
	if estado != novo:
		mudar(novo)


## Vira para `direcao` com velocidade máxima e aceleração: pesada na areia, ágil na
## água (08/10/2026; antes um lerp exponencial virava quase 180° em menos de 1 s).
func _encarar(direcao: Vector3, delta: float) -> void:
	var maximo := deg_to_rad(GIRO_AGUA if nadando else GIRO_TERRA)
	var querida := 0.0
	if Vector2(direcao.x, direcao.z).length_squared() > .01:
		var falta := wrapf(atan2(-direcao.x, -direcao.z) - rotation.y, -PI, PI)
		querida = clampf(falta * 2.5, -maximo, maximo)     # desacelera chegando no rumo
	_giro = move_toward(_giro, querida, maximo * 3.0 * delta)
	rotation.y += _giro * delta
	_virou = true


## Postura por quadro: a fundura na água (em pé ou deitada), a inclinação do corpo na
## curva nadando e a área de dano acompanhando o corpo.
func _postura(delta: float) -> void:
	if not _virou:      # sem rumo pedido: o giro amortece (e a inclinação volta)
		_giro = move_toward(_giro, 0.0, deg_to_rad(GIRO_AGUA) * 3.0 * delta)
	_virou = false
	var calado := (CALADO_DEITADA if deitada() else CALADO_EM_PE) * _escala.y
	_calado = lerpf(_calado, calado, 1.0 - exp(-2.0 * delta))
	var inclina := clampf(_giro * INCLINA_NA_CURVA, -INCLINACAO_MAX, INCLINACAO_MAX) if nadando and deitada() else 0.0
	_pivo.rotation.z = lerpf(_pivo.rotation.z, inclina, 1.0 - exp(-4.0 * delta))
	_relogio_dano -= delta
	if _relogio_dano <= 0.0:
		_relogio_dano = 0.25
		_ajustar_area_de_dano()


## A caixa de dano envolve os ossos do corpo posado (em pé: alta; deitada: comprida e
## baixa), com a grossura do corpo de margem.
func _ajustar_area_de_dano() -> void:
	var rig := animador.rig
	if rig == null or not is_inside_tree():
		return
	rig.force_update_all_bone_transforms()
	var para_mim := global_transform.affine_inverse() * rig.global_transform
	var caixa := AABB()
	var primeiro := true
	for i in rig.get_bone_count():
		var p := para_mim * rig.get_bone_global_pose(i).origin
		if primeiro:
			caixa = AABB(p, Vector3.ZERO)
			primeiro = false
		else:
			caixa = caixa.expand(p)
	caixa = caixa.grow(2.0 * maxf(_escala.x, _escala.y))
	var base := maxf(caixa.position.y, 0.0)
	caixa.size.y = caixa.end.y - base
	caixa.position.y = base
	_forma_dano.size = caixa.size
	_no_dano.position = caixa.get_center()


func _mover(direcao: Vector3, rapidez: float, delta: float, nivel: float) -> void:
	direcao.y = 0.0
	# Anda para onde OLHA, na medida em que já está virada para o rumo (não desliza de
	# lado nem de ré enquanto vira devagar na areia).
	var frente := -global_transform.basis.z
	frente.y = 0.0
	var alinhada := clampf(frente.normalized().dot(direcao.normalized()), 0.0, 1.0) if direcao.length_squared() > .0001 else 0.0
	var desejo := frente.normalized() * rapidez * alinhada
	velocity.x = move_toward(velocity.x, desejo.x + _empurrao.x, delta * 10)
	velocity.z = move_toward(velocity.z, desejo.z + _empurrao.z, delta * 10)
	_empurrao = _empurrao.move_toward(Vector3.ZERO, delta * 10)
	if not is_nan(nivel):
		# Mesma superfície das ondas usada pelos barcos; cabeça/pescoço fora da água.
		var superficie := AguaDoMundo.superficie_em(global_position.x, global_position.z)
		velocity.y = clampf((superficie - _calado - _profundidade - global_position.y) * 3.0, -5, 5)
	else:
		velocity.y = maxf(velocity.y - 22.0 * delta, -25.0)
	# Em água rasa, o fundo tem prioridade sobre o calado: antecipar a subida
	# evita prender a cápsula na faixa de transição do FundoDoMar.
	var proximo := global_position + Vector3(velocity.x, 0, velocity.z).normalized() * (_raio + .8)
	if nadando:
		var q := PhysicsRayQueryParameters3D.create(proximo + Vector3.UP * 15, proximo - Vector3.UP * 8, 1, [get_rid(), _hurtbox.get_rid()])
		var chao := get_world_3d().direct_space_state.intersect_ray(q)
		if not chao.is_empty() and not chao.collider.has_method("take_damage") \
				and chao.position.y + .15 > global_position.y \
				and chao.position.y - global_position.y < _calado + 1.0:
			velocity.y = maxf(velocity.y, clampf((chao.position.y + .15 - global_position.y) * 6, 0, 5))
	move_and_slide()
	HurtboxDeCombate.sincronizar(self)


func _atualizar_acao() -> void:
	var fracao: float = animador.tempo / maxf(animador.duracao(), .01)
	if estado == "disparando_ataque" and not _acertou and fracao >= DISPARO_EM:
		_acertou = true
		if is_instance_valid(_preparo_agua):
			_preparo_agua.queue_free()
		if _valido(alvo) and _visivel(alvo):
			var boca: Vector3 = animador.boca()
			var rumo := (AlvosDeGolpe.centro(alvo) - boca).normalized()
			if ataque_atual == "compressor":
				var raio := Compressor.new()
				raio.atirador = self
				raio.rumo = rumo
				raio.dano = float(ficha.dano) * 2.0
				raio.alcance = float(ficha.alcance)
				get_parent().add_child(raio)
				raio.global_position = boca
				_raio_agua = raio
				disparou.emit(raio)
			else:
				for i in BOLHAS_POR_SALVA:
					var bolha := Bolha.new()
					bolha.atirador = self
					bolha.dano = float(ficha.dano)
					bolha.rumo = rumo.rotated(Vector3.UP, deg_to_rad((i - 2) * ABERTURA_BOLHAS))
					get_parent().add_child(bolha)
					bolha.global_position = boca
					disparou.emit(bolha)
	if fracao >= 1.0:
		if estado in ["atacando", "disparando_ataque"]:
			_recarga = float(ficha.recarga)
		mudar(_apos_dano if estado == "recebendo_dano" else "idle")


func _limpar_agua() -> void:
	for no in [_preparo_agua, _raio_agua]:
		if is_instance_valid(no): no.queue_free()
	_preparo_agua = null
	_raio_agua = null


## Esquiva com dash contra a Buki Buki (22/11/2026). O bicho é GRANDE: o dash vence o próprio raio (impulso v tal que v²/20 = 2,5 m + 1,2 x raio),
## senão sairia 3 m e continuaria na linha do tiro. Lado, recarga de 3 s e efeito: `EsquivaDeDisparo`.
func esquivar_de_disparo(rumo: Vector3, _chegada_em := 0.0) -> bool:
	if not vivo():
		return false
	var lateral := EsquivaDeDisparo.tentar(self, rumo)
	if lateral == Vector3.ZERO:
		return false
	var v := lateral * sqrt(20.0 * (2.5 + 1.2 * _raio))
	_empurrao += v
	velocity.x += v.x          # a velocidade só acelera 10 m/s² rumo ao `_empurrao`: sem este impulso o dash seria lento demais
	velocity.z += v.z
	return true


func take_damage(amount: float, from_pos := Vector3.ZERO, knockback := Vector3.ZERO, _hitstun := .3) -> void:
	if not vivo() or (multiplayer.has_multiplayer_peer() and not multiplayer.is_server()):
		return
	_empurrao += knockback * .25
	if amount <= 0.0:
		return
	IaUnificada.acordar_por_dano(self)      # IA dos animais: levar dano acorda (10/11/2026)
	if Vector2(knockback.x, knockback.z).length() < 0.1:
		_empurrao += KnockbackMinecraft.padrao(self, from_pos) * .25      # golpe cru: o empurrão do Minecraft
	if is_in_group(BarrasDeChefes.GRUPO):
		amount = VidaEmBarras.filtrar(self, amount, health, max_health)   # chefe: 10 barras (10/11/2026)
	health = maxf(0.0, health - amount)
	_profundidade = 0.0
	_passeando = false
	_banho = false
	_voltando = false
	FxUtil.flash_red(modelo)
	if not vivo():
		_concluir_derrota()
		return
	var atacante: Node3D = instance_from_id(int(get_meta(CombatResolver.META_CORPO_A_CORPO, 0))) as Node3D
	if not _valido(atacante):
		atacante = alvo_de.call() if alvo_de.is_valid() else null
	alvo = atacante
	_perdido = 0.0
	_apos_dano = "idle" if agressiva else "irritado"
	agressiva = true
	add_to_group("enemy")
	# (Sem virar de uma vez para o atacante: a perseguição vira no ritmo da besta.)
	# Receber dano cancela o preparo e o raio ativo; bolhas já lançadas seguem viagem.
	mudar("recebendo_dano")


func _concluir_derrota() -> void:
	_limpar_agua()
	estado = "morto"
	agressiva = false
	_tempo_morto = 0.0
	collision_layer = 0
	_hurtbox.collision_layer = 0
	remove_from_group("enemy")
	remove_from_group(AlvosDeGolpe.GRUPO)
	animador.mudar("recebendo_dano")
	morreu.emit(self)


func reviver() -> void:
	health = max_health
	global_position = origem
	rotation.y = _yaw_inicial
	velocity = Vector3.ZERO
	_empurrao = Vector3.ZERO
	_recarga = 0.0
	collision_layer = 1
	_hurtbox.collision_layer = HurtboxDeCombate.CAMADA
	modelo.visible = true
	add_to_group(AlvosDeGolpe.GRUPO)
	if boss():
		add_to_group("enemy")
	iniciar_rotina()
