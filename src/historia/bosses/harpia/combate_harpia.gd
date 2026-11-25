extends Node
## IA e movimento de habilidades. Efeitos e pose são apresentação, sem dano próprio.
##
## 10/10/2026 (pedido do dono): território maior; voa entre as pedras sem empacar
## (`voo_harpia.gd`); RONDA OS PICOS — devagar sozinha, rápido em combate; levou golpe,
## ALÇA VOO e investe contra quem bateu; depois da investida não pára: arremete e já
## volta a rondar os picos em velocidade; o tornado anda mais rápido.
##   Combate: rondar o pico mais perto do alvo → (ataque pronto) chegar até o alcance →
##   preparar → investida → arremeter → rondar. O vendaval: lança e volta a rondar
##   enquanto o tornado vive (nenhum ataque novo até ele acabar).
signal iniciou(habilidade: String)
signal terminou(habilidade: String)
var corpo: AnimalDaIlha
var config: Resource
var fase := ""
var habilidade := ""
var tempo_fase := 0.0
var tornado: Node3D
var _pose: Node
var _vento: Node3D
var _acentos: Node3D
var _alvo: Node3D
var _direcao := Vector3.FORWARD
var _acertados := {}
var _cast := 0
var _recarga_i := 0.0
var _recarga_v := 0.0
var _intervalo := 0.6
var _proxima := "investida"
var _avancou := 0.0
var _altura_antes := 0.0
const Voo := preload("res://src/historia/bosses/harpia/voo_harpia.gd")
var _picos: Array[Vector3] = []
var _pico := 0
var _ang := 0.0
var _sentido := 1.0
var _volta := 0.0
var _tempo := 0.0
var _reacao_livre_em := 0.0
var _reagir_contra: Node3D
var _forcada := false

func _ready() -> void:
	_pose = load("res://src/historia/bosses/harpia/pose_harpia.gd").new()
	_pose.montar(corpo._modelo)
	_vento = load("res://src/historia/bosses/harpia/vento_harpia.gd").new()
	add_child(_vento)
	_vento.limpar()
	_acentos = Node3D.new()
	_acentos.name = "AcentosDeAr"
	add_child(_acentos)

func ativo() -> bool:
	return not fase.is_empty() or is_instance_valid(tornado)

func atualizar(delta: float) -> bool:
	if not corpo.vivo():
		cancelar()
		return false
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return false
	_tempo += delta
	_recarga_i = maxf(0, _recarga_i - delta)
	_recarga_v = maxf(0, _recarga_v - delta)
	_intervalo = maxf(0, _intervalo - delta)
	if fase.is_empty():
		# Levou golpe: alça voo e vai investir contra quem bateu.
		if _vivo(_reagir_contra):
			var quem_bateu := _reagir_contra
			_reagir_contra = null
			_alvo = quem_bateu
			corpo.oponente = quem_bateu
			corpo.estado = AnimalDaIlha.Estado.PERSEGUINDO
			_forcada = true
			_trocar_fase("decolar")
			return true
		var quem := corpo.oponente if _vivo(corpo.oponente) else corpo.alvo
		if not _pode_enfrentar(quem):
			# Ninguém no território: ronda os picos devagar.
			if corpo.estado == AnimalDaIlha.Estado.PERSEGUINDO:
				corpo.oponente = null
			corpo.estado = AnimalDaIlha.Estado.PASSEANDO
			_orbitar(delta, null, false)
			return true
		corpo.oponente = quem
		corpo.estado = AnimalDaIlha.Estado.PERSEGUINDO
		var pronta := _intervalo <= 0 and not ativo() and (_recarga_i <= 0 or _recarga_v <= 0)
		if pronta and _proxima == "vendaval" and _recarga_v <= 0 and _linha_livre(quem):
			iniciar_vendaval(quem)
		elif pronta and _recarga_i <= 0:
			_alvo = quem
			_forcada = false
			_trocar_fase("aproximar")
		elif pronta and _recarga_v <= 0 and _linha_livre(quem):
			iniciar_vendaval(quem)
		else:
			_orbitar(delta, quem, true)
		return true
	tempo_fase += delta
	corpo._golpe_alvo = null
	if not fase in ["decolar", "aproximar"]:            # essas animam o voo elas mesmas
		corpo.animador.animar(delta, Vector3.ZERO, 1, 1, "planando", 0)
	match fase:
		"decolar":
			# Alça voo: sobe batendo as asas, virando para quem bateu.
			corpo.animador.exclusivo = false
			if not _vivo(_alvo):
				_finalizar()
				return true
			var para := _alvo.global_position - corpo.global_position
			para.y = 0.0
			var sobe := corpo.global_position + Vector3.UP * 7.0 - para.normalized() * 2.0
			Voo.voar(corpo, sobe, 12.0, delta, 6.0, _excluir_alvo())
			corpo.animador.animar(delta, Vector3(0, 0, 8), 6.0, 12.0, "voando", 0.0)
			if tempo_fase >= config.decolar:
				_trocar_fase("aproximar")
		"aproximar":
			# Chega até o alcance da investida (pelas pedras) e investe.
			corpo.animador.exclusivo = false
			if not _vivo(_alvo) or tempo_fase > 5.0:
				_finalizar()
				return true
			var alcance: float = config.velocidade_investida * config.duracao_investida * 0.85
			var c := _centro()
			var ca := _centro_alvo(_alvo)
			if c.distance_to(ca) <= alcance and _linha_livre(_alvo):
				fase = ""
				if not iniciar_investida(_alvo, _forcada):
					_finalizar()
				return true
			var longe := corpo.global_position - _alvo.global_position
			longe.y = 0.0
			if longe.length_squared() < .01:
				longe = Vector3.BACK
			var ponto := _alvo.global_position + longe.normalized() * 11.0 + Vector3.UP * 5.0
			var v := Voo.voar(corpo, ponto, config.velocidade_ataque, delta, 3.5, _excluir_alvo())
			corpo.animador.animar(delta, Vector3(0, 0, v.length()), 6.0, 12.0, "voando", 0.0)
		"arremeter":
			# Depois da investida: abre as asas e já sai em velocidade para os picos.
			_apresentar("recuperar", tempo_fase / config.saida)
			var ganho := clampf(tempo_fase / config.saida, 0.0, 1.0)
			var vel: float = lerpf(config.velocidade_saida, config.velocidade_orbita, ganho)
			Voo.voar(corpo, _ponto_de_saida(), vel, delta, 5.0, _excluir_alvo())
			if tempo_fase >= config.saida:
				_finalizar()
		"preparar_investida":
			if not _vivo(_alvo):
				cancelar()
				return true
			if tempo_fase < maxf(config.preparo_investida - .2, 0.0):
				_mirar(_alvo)
			# Chegou voando: freia no ar (antes parava seco) e encara.
			corpo.velocity = corpo.velocity.lerp(Vector3.ZERO, 1.0 - exp(-7.0 * delta))
			corpo.move_and_slide()
			_encarar(_direcao, delta)
			_apresentar("preparar_investida", tempo_fase / config.preparo_investida)
			if tempo_fase >= config.preparo_investida:
				_trocar_fase("investida")
				_vento.configurar("investida", config.raio_impacto, 4.0)
				_emitir_pulso(_centro(), 1.0, false)
		"investida":
			_encarar(_direcao, delta, true)
			var inicio := _centro()
			var restante: float = config.velocidade_investida * config.duracao_investida - _avancou
			var passo: Vector3 = _direcao * minf(config.velocidade_investida * delta, maxf(restante, 0))
			corpo.velocity = _direcao * config.velocidade_investida
			var colisao := corpo.move_and_collide(passo)
			_avancou += passo.length() if colisao == null else colisao.get_travel().length()
			_varrer(inicio, _centro())
			if colisao != null:
				_atingir(HurtboxDeCombate.dono_de(colisao.get_collider()))
			_apresentar("investida", tempo_fase / config.duracao_investida)
			if colisao != null or tempo_fase >= config.duracao_investida or restante <= .001:
				_arremeter(colisao != null)
		"preparar_vendaval":
			if not _vivo(_alvo):
				cancelar()
				return true
			_mirar(_alvo)
			_encarar(_direcao, delta)
			_apresentar("preparar_vendaval", tempo_fase / config.preparo_vendaval)
			if tempo_fase >= config.preparo_vendaval:
				_lancar_tornado()
		"vendaval":
			_apresentar("lancar_vendaval", clampf(tempo_fase / .7, 0, 1))
			# Cinco segundos pertencem ao tornado; morrer/sair da cena é cancelamento.
			# Lançado (0,7 s de pose), ela volta a rondar os picos; nenhum ataque novo
			# começa enquanto o tornado vive (`ativo`).
			if not is_instance_valid(tornado) or tornado.is_queued_for_deletion():
				tornado = null
				_recuperar()
			elif tempo_fase >= .7:
				_vento.limpar()
				CombatResolver.encerrar(_cast)
				_cast = 0
				_finalizar()
		"recuperar":
			_apresentar("recuperar", tempo_fase / config.recuperacao)
			corpo._visual.rotation.x = lerp_angle(corpo._visual.rotation.x, 0, 1.0 - exp(-8 * delta))
			if tempo_fase >= config.recuperacao:
				_finalizar()
	_sincronizar_hurtbox()
	return true

## `forcada`: a reação a golpe (10/10/2026) investe mesmo com a recarga correndo.
func iniciar_investida(quem: Node3D, forcada := false) -> bool:
	if not _pode_iniciar(quem, forcada) or (_recarga_i > 0 and not forcada):
		return false
	if _centro().distance_to(_centro_alvo(quem)) > config.velocidade_investida * config.duracao_investida:
		return false
	_preparar(quem, "investida")
	_recarga_i = config.recarga_investida
	_proxima = "vendaval"
	_vento.configurar("preparacao", 2.0, 3.0)
	_trocar_fase("preparar_investida")
	return true

func iniciar_vendaval(quem: Node3D) -> bool:
	if not _pode_iniciar(quem) or _recarga_v > 0:
		return false
	_preparar(quem, "vendaval")
	_recarga_v = config.recarga_vendaval
	_proxima = "investida"
	_vento.configurar("preparacao", 3.0, 4.0)
	_trocar_fase("preparar_vendaval")
	return true

func _preparar(quem: Node3D, acao: String) -> void:
	_alvo = quem
	habilidade = acao
	_acertados.clear()
	_avancou = 0.0
	_cast = CombatResolver.novo_cast()
	corpo._golpe_alvo = null
	corpo.animador.exclusivo = true
	corpo.animador.atualizar_base_exclusiva()
	_mirar(quem)
	iniciou.emit(acao)

## `forcada` (reação a golpe): vale com o tornado ainda no ar, desde que ele não esteja
## carregando justamente esse alvo.
func _pode_iniciar(quem: Node3D, forcada := false) -> bool:
	var livre := not ativo() or (forcada and fase.is_empty() and not _capturado(quem))
	return livre and corpo.vivo() and _vivo(quem) and _linha_livre(quem) \
		and not (corpo.has_meta("captura_vento") and is_instance_valid(corpo.get_meta("captura_vento"))) \
		and not (corpo.has_meta("arremesso_vento") and is_instance_valid(corpo.get_meta("arremesso_vento")))

func _pode_enfrentar(quem: Node3D) -> bool:
	if not _vivo(quem) or not corpo._dentro_da_area(quem.global_position, 0):
		return false
	var d := Vector2(quem.global_position.x - corpo.global_position.x, quem.global_position.z - corpo.global_position.z).length()
	# Território maior (10/10/2026): enfrenta até `raio_de_combate`, não só o alerta curto
	# da ficha (22 m) — rondando os picos ela fica longe do chão.
	return d < maxf(float(config.raio_de_combate), float(corpo.ficha.get("alerta", 22)) * (1.6 if corpo.estado == AnimalDaIlha.Estado.PERSEGUINDO else 1.0))

func _mirar(quem: Node3D) -> void:
	_direcao = (_centro_alvo(quem) - _centro()).normalized()
	if _direcao.is_zero_approx():
		_direcao = Vector3.FORWARD

func _encarar(dir: Vector3, delta: float, mergulho := false) -> void:
	var yaw := atan2(dir.x, dir.z)
	corpo._yaw = lerp_angle(corpo._yaw, yaw, 1.0 - exp(-10 * delta))
	corpo._visual.rotation.y = corpo._yaw
	if mergulho:
		corpo._visual.rotation.x = -atan2(dir.y, Vector2(dir.x, dir.z).length())

func _centro() -> Vector3:
	return corpo.global_position + Vector3.UP * (corpo.get_node("Colisao") as Node3D).position.y

func _centro_alvo(quem: Node3D) -> Vector3:
	return quem.global_position if quem.is_in_group("player") else quem.global_position + Vector3.UP * .8

func _linha_livre(quem: Node3D) -> bool:
	var q := PhysicsRayQueryParameters3D.create(_centro(), _centro_alvo(quem), 1)
	var excluidos: Array[RID] = [corpo.get_rid()]
	if quem is CollisionObject3D:
		excluidos.append(quem.get_rid())
	q.exclude = excluidos
	return corpo.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _varrer(de: Vector3, ate: Vector3) -> void:
	var forma := CapsuleShape3D.new()
	forma.radius = config.raio_impacto
	forma.height = de.distance_to(ate) + 2 * forma.radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.collision_mask = 1 | HurtboxDeCombate.CAMADA
	q.exclude = [corpo.get_rid(), corpo._hurtbox.get_rid()]
	q.transform.origin = (de + ate) * .5
	if de.distance_squared_to(ate) > .000001:
		q.transform.basis = Basis(Quaternion(Vector3.UP, (ate - de).normalized()))
	for resultado in corpo.get_world_3d().direct_space_state.intersect_shape(q, 64):
		_atingir(HurtboxDeCombate.dono_de(resultado["collider"]))

func _atingir(alvo: Node) -> void:
	if alvo == corpo or not alvo is Node3D or not _vivo(alvo) or not alvo.has_method("take_damage"):
		return
	if _acertados.has(alvo.get_instance_id()) or not _linha_livre(alvo):
		return
	var vida: Variant = alvo.get("health")
	if vida == null:
		return
	_acertados[alvo.get_instance_id()] = true
	CombatResolver.aplicar(alvo, config.dano_investida, _cast, config.dano_investida, corpo.global_position, Vector3.ZERO, .35, 0, false, null, corpo)
	if is_instance_valid(alvo) and float(alvo.get("health")) < float(vida):
		_emitir_pulso(_centro_alvo(alvo), 0.85, true)
	# Retorno do funil é o dano calculado, não confirmação; Player pode recusá-lo.
	if is_instance_valid(alvo) and float(alvo.get("health")) > 0 and float(alvo.get("health")) < float(vida):
		var para := Vector3(_direcao.x, 0, _direcao.z).normalized()
		if para.is_zero_approx():
			para = Vector3.FORWARD
		load("res://src/historia/bosses/harpia/captura_vento.gd").aplicar_arremesso(alvo, para * config.arremesso_horizontal + Vector3.UP * config.arremesso_vertical)

func _lancar_tornado() -> void:
	var frente := Vector3(_direcao.x, 0, _direcao.z).normalized()
	if frente.is_zero_approx():
		frente = Vector3.FORWARD
	var origem := corpo.global_position + frente * 2.0
	var q := PhysicsRayQueryParameters3D.create(origem + Vector3.UP * 3, origem + Vector3.DOWN * 40, 1)
	var excluidos: Array[RID] = [corpo.get_rid()]
	for n in get_tree().get_nodes_in_group("player"):
		if n is CollisionObject3D:
			excluidos.append(n.get_rid())
	q.exclude = excluidos
	var chao := corpo.get_world_3d().direct_space_state.intersect_ray(q)
	if not chao.is_empty():
		origem.y = chao["position"].y + .05
	tornado = load("res://src/historia/bosses/harpia/tornado_vendaval.gd").new()
	tornado.velocidade = config.velocidade_tornado
	tornado.position = origem
	get_tree().current_scene.add_child(tornado) if get_tree().current_scene != null else get_tree().root.add_child(tornado)
	tornado.configurar(corpo, frente)
	_emitir_pulso(_centro(), 1.8, false)
	_vento.limpar()
	_trocar_fase("vendaval")

func _apresentar(acao: String, progresso: float) -> void:
	_pose.atualizar(acao, clampf(progresso, 0, 1), get_physics_process_delta_time())
	_vento.global_position = _centro()
	_vento.global_basis = Basis.looking_at(_direcao, Vector3.UP if absf(_direcao.y) < .99 else Vector3.RIGHT)
	if fase.begins_with("preparar") or fase == "investida":
		_vento.atualizar(tempo_fase, lerpf(.15, .95, smoothstep(0.0, 1.0, progresso)) if fase.begins_with("preparar") else 1.0)

func _emitir_pulso(origem: Vector3, raio: float, impacto: bool) -> void:
	if not is_instance_valid(_acentos) or _acentos.get_child_count() >= 6:
		return
	var pulso := preload("res://src/historia/bosses/harpia/pulso_de_ar.gd").new()
	pulso.top_level = true
	_acentos.add_child(pulso)
	pulso.global_position = origem
	pulso.global_basis = Basis.looking_at(_direcao, Vector3.UP if absf(_direcao.y) < .99 else Vector3.RIGHT)
	pulso.montar(raio, impacto)

func _sincronizar_hurtbox() -> void:
	if corpo._hurtbox != null:
		PhysicsServer3D.body_set_state(corpo._hurtbox.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, corpo._hurtbox.global_transform)

func _trocar_fase(nova: String) -> void:
	fase = nova
	tempo_fase = 0.0

func _recuperar() -> void:
	corpo.velocity = Vector3.ZERO
	_vento.limpar()
	CombatResolver.encerrar(_cast)
	_cast = 0
	_trocar_fase("recuperar")

func _finalizar() -> void:
	var anterior := habilidade
	fase = ""
	habilidade = ""
	corpo._visual.rotation.x = 0
	corpo._visual.rotation.z = 0
	corpo.animador.exclusivo = false
	_pose.restaurar()
	_entrar_na_orbita()
	_vento.limpar()
	_intervalo = config.intervalo
	terminou.emit(anterior)

func cancelar() -> void:
	if is_instance_valid(_acentos):
		for efeito in _acentos.get_children():
			efeito.queue_free()
	if is_instance_valid(tornado):
		tornado.cancelar()
		tornado = null
	CombatResolver.encerrar(_cast)
	_cast = 0
	_acertados.clear()
	_alvo = null
	if is_instance_valid(_pose) and is_instance_valid(corpo):
		_finalizar()
	else:
		fase = ""
		habilidade = ""

func reiniciar() -> void:
	cancelar()
	_recarga_i = 0
	_recarga_v = 0
	_intervalo = .6
	_proxima = "investida"
	_reagir_contra = null
	_reacao_livre_em = 0.0

## Levou golpe de `quem` (o `HarpiaDaIlha.take_damage`). Fora da preparação/investida e
## com quem bateu fora do tornado dela, no máximo uma reação a cada `recarga_reacao`.
func reagir(quem: Node3D) -> void:
	if not _vivo(quem) or not corpo.vivo() or _tempo < _reacao_livre_em:
		return
	if fase in ["decolar", "preparar_investida", "investida", "preparar_vendaval"] or _capturado(quem):
		return
	_reacao_livre_em = _tempo + float(config.recarga_reacao)
	if not fase.is_empty():
		_finalizar()                  # aproximando/arremetendo: troca pela reação
	_reagir_contra = quem


## Ronda o pico da vez (em combate, o mais perto de `quem`). Uma volta e troca de pico.
func _orbitar(delta: float, quem: Node3D, rapido: bool) -> void:
	if _picos.is_empty():
		_picos = Voo.picos(corpo)
		_entrar_na_orbita()
	var p := _picos[_pico]
	var raio: float = config.raio_orbita
	var vel: float = config.velocidade_orbita if rapido else config.velocidade_patrulha
	var alt: float = p.y + float(config.altura_orbita)
	if rapido and _vivo(quem):
		alt = maxf(alt, quem.global_position.y + 6.0)
	var w := vel / maxf(raio, 1.0)
	_ang += _sentido * w * delta
	_volta += w * delta
	var adiante := _ang + _sentido * 0.55
	var ponto := Vector3(p.x + cos(adiante) * raio, alt, p.z + sin(adiante) * raio)
	var v := Voo.voar(corpo, ponto, vel, delta, 2.6)
	corpo.animador.exclusivo = false
	corpo.animador.animar(delta, Vector3(0, 0, v.length()), 6.0, 12.0,
		"voando" if v.y > 1.5 or v.length() < vel * 0.6 else "planando", 0.0)
	_sincronizar_hurtbox()
	if _volta >= TAU:
		_volta = 0.0
		_trocar_pico(quem)


func _trocar_pico(quem: Node3D) -> void:
	if _picos.size() <= 1:
		_sentido = -_sentido
		return
	if _vivo(quem):
		var melhor := INF
		for i in _picos.size():
			var d := Vector2(_picos[i].x - quem.global_position.x, _picos[i].z - quem.global_position.z).length()
			if i != _pico and d < melhor:
				melhor = d
				_pico = i
	else:
		_pico = (_pico + 1) % _picos.size()
	_sentido = -_sentido               # oito entre os picos
	_entrar_na_orbita()


## Ângulo da órbita a partir de onde ela está (entra na roda sem dar ré).
func _entrar_na_orbita() -> void:
	if _picos.is_empty():
		return
	_pico = clampi(_pico, 0, _picos.size() - 1)
	var p := _picos[_pico]
	_ang = atan2(corpo.global_position.z - p.z, corpo.global_position.x - p.x)
	_volta = 0.0


## Para onde arremeter depois da investida: o ponto da órbita do pico mais perto, à frente.
func _ponto_de_saida() -> Vector3:
	if _picos.is_empty():
		_picos = Voo.picos(corpo)
	var perto := 0
	var melhor := INF
	for i in _picos.size():
		var d := corpo.global_position.distance_to(_picos[i])
		if d < melhor:
			melhor = d
			perto = i
	_pico = perto
	var p := _picos[_pico]
	var frente := Vector3(_direcao.x, 0, _direcao.z).normalized()
	if frente.is_zero_approx():
		frente = Vector3.FORWARD
	var lado := atan2(corpo.global_position.z - p.z, corpo.global_position.x - p.x) + 0.8 * _sentido
	return Vector3(p.x + cos(lado) * float(config.raio_orbita), p.y + float(config.altura_orbita), p.z + sin(lado) * float(config.raio_orbita)) \
		+ frente * 6.0


## Fim da investida: arremete (asas abrindo) em vez de parar 1 s no ar.
func _arremeter(bateu: bool) -> void:
	_vento.limpar()
	CombatResolver.encerrar(_cast)
	_cast = 0
	var frente := Vector3(_direcao.x, 0, _direcao.z).normalized()
	# Bateu em pedra/parede: sai para trás e para cima; senão, embalada para a frente.
	corpo.velocity = (-frente * 8.0 + Vector3.UP * 12.0) if bateu else (frente * float(config.velocidade_saida) + Vector3.UP * 6.0)
	_trocar_fase("arremeter")


static func _capturado(quem: Node) -> bool:
	return is_instance_valid(quem) and quem.has_meta("captura_vento") and is_instance_valid(quem.get_meta("captura_vento"))


func _excluir_alvo() -> Array[RID]:
	var fora: Array[RID] = []
	if _alvo is CollisionObject3D:
		fora.append((_alvo as CollisionObject3D).get_rid())
	return fora


func _exit_tree() -> void:
	cancelar()

static func _vivo(quem: Node) -> bool:
	if not is_instance_valid(quem) or not quem is Node3D or not quem.is_inside_tree() or quem.is_queued_for_deletion():
		return false
	var h: Variant = quem.get("health")
	return h == null or float(h) > 0
