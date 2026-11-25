extends CharacterBody3D
## Companheiro do modo história. A raiz resolve física; o visual encara de lado.
## Não é alvo de combate e não bloqueia o dono. Valores editáveis em cena.
##
## COMPORTAMENTOS (30/09/2026, pedido do dono — menu B, `ModoDoPet`): SEGUIR é o que
## ele sempre fez; LIVRE passeia devagar em volta de onde ficou livre; EM GUARDA e
## AGRESSIVO vão até o inimigo e BELISCAM com as pinças.
signal mudou_estado(estado: StringName)
signal soltou_bolhas
signal modo_mudou(modo: StringName)
## Vida acabou (01/10/2026, decisão do dono: pet que morre é apagado para sempre — quem
## apaga do progresso é a `Companhia`). Só bicho bravo fere pet: ele chama
## `take_damage` direto; os golpes do jogador não o acham (camada 0).
signal morreu(pet: Node3D)
signal beliscou(alvo: Node3D)
const ESPECIE := "caranguejo"
## A pinça: alcance (do centro do caranguejo ao do alvo, no plano), dano e recarga.
## Dano na escala da história (inimigo 250; o soco do jogador tira ~20).
const ALCANCE_PINCA := 2.4
const DANO_PINCA := 14.0
const RECARGA_PINCA := 1.3
const MODELO := "res://assets/models/pets/caranguejo_grande.glb"
const Animador := preload("res://src/historia/pets/animador_caranguejo.gd")
const Bolhas := preload("res://src/historia/pets/bolhas_caranguejo.gd")
@export var escala_modelo := Vector3.ONE
@export var velocidade_andar := 3.6
@export var velocidade_correr := 8.5
@export var distancia_parar := 3.2
@export var distancia_retomar := 4.1
@export var distancia_correr := 7.0
@export var impulso_salto := 11.5
@export var gravidade := 26.0
@export var intervalo_bolhas := Vector2(6.0, 12.0)
var alvo_de: Callable
var estado: StringName = &"idle"
var visual: Node3D
var animador: Node3D
var _seguindo := false
var _alvo_no_ar := false
var _salto_pendente := 0.0
var _recarga_salto := 0.0
var _relogio_bolhas := 0.0
var _preso := 0.0
var _sem_chao := 0.0
var _ultimo_alvo: PhysicsBody3D
var _sentido := 1.0
var modo: StringName = ModoDoPet.SEGUIR
var especie := ESPECIE
var nome_exibido := "Caranguejo grande"
## Vida do pet (120: na escala do bicho bravo que bate 3–7 por golpe).
var max_health := 120.0
var health := 120.0
## O chão de onde ele ficou livre: o passeio é em volta daqui.
var casa := Vector3.INF
var _recarga_pinca := 0.0
var _mirando := 0.0
var _inimigo: Node3D = null
var _livre_ponto := Vector3.INF
var _livre_parado := 0.0
var _livre_pausa := 3.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = .35
	floor_stop_on_slope = true
	var colisao := CollisionShape3D.new()
	colisao.name = "Colisao"
	colisao.shape = forma_do_corpo(escala_modelo)
	colisao.position.y = .53 * escala_modelo.y
	add_child(colisao)
	visual = (load(MODELO) as PackedScene).instantiate()
	visual.name = "Visual"
	visual.scale = escala_modelo
	add_child(visual)
	animador = Animador.new()
	animador.name = "Animador"
	add_child(animador)
	animador.montar(visual)
	_relogio_bolhas = randf_range(intervalo_bolhas.x, intervalo_bolhas.y)
	add_to_group("pets_historia")
	if casa == Vector3.INF:
		casa = global_position


## Troca o comportamento (menu B). Livre: passeia em volta de onde está agora.
func definir_modo(novo: StringName) -> void:
	if not ModoDoPet.valido(novo):
		return
	modo = novo
	if novo == ModoDoPet.LIVRE:
		casa = global_position
		_livre_ponto = Vector3.INF
	modo_mudou.emit(novo)

static func forma_do_corpo(escala := Vector3.ONE) -> CylinderShape3D:
	var forma := CylinderShape3D.new()
	forma.radius = .86 * maxf(escala.x, escala.z)
	forma.height = escala.y
	return forma

func _physics_process(delta: float) -> void:
	var alvo: Node3D = alvo_de.call() if alvo_de.is_valid() else null
	_recarga_salto = maxf(0, _recarga_salto - delta)
	_salto_pendente = maxf(0, _salto_pendente - delta)
	_recarga_pinca = maxf(0, _recarga_pinca - delta)
	_mirando = maxf(0, _mirando - delta)
	var desejada := Vector3.ZERO
	var distancia := 0.0
	if is_instance_valid(alvo):
		if alvo is PhysicsBody3D and alvo != _ultimo_alvo:
			_ultimo_alvo = alvo
			add_collision_exception_with(alvo)
		# O que ele persegue depende do comportamento: o inimigo (em guarda/agressivo),
		# um ponto do passeio (livre) ou o dono (seguir, e os outros sem inimigo).
		_inimigo = ModoDoPet.alvo(modo, alvo, self)
		var foco: Vector3 = alvo.global_position
		var parar := distancia_parar
		var retomar := distancia_retomar
		if _inimigo != null:
			foco = _inimigo.global_position
			parar = ALCANCE_PINCA * 0.75
			retomar = ALCANCE_PINCA
		elif modo == ModoDoPet.LIVRE:
			foco = _ponto_livre(delta)
			parar = 0.5
			retomar = 1.2
		var diferenca := foco - global_position
		diferenca.y = 0
		distancia = diferenca.length()
		if distancia > retomar:
			_seguindo = true
		elif distancia < parar:
			_seguindo = false
		if _inimigo != null and distancia <= ALCANCE_PINCA and _recarga_pinca <= 0:
			_beliscar(_inimigo)
		var atras_do_dono := _inimigo == null and modo != ModoDoPet.LIVRE
		var no_ar := atras_do_dono and alvo is CharacterBody3D and not (alvo as CharacterBody3D).is_on_floor()
		if no_ar and not _alvo_no_ar and (alvo as CharacterBody3D).velocity.y > 2.0:
			_salto_pendente = .65
		_alvo_no_ar = no_ar
		if _seguindo:
			var direcao := diferenca.normalized()
			var rapidez := velocidade_correr if distancia > distancia_correr else velocidade_andar
			if modo == ModoDoPet.LIVRE and _inimigo == null:
				rapidez = velocidade_andar * 0.6   # passeio, sem pressa
			# Desacelera antes de chegar, sem oscilar entre idle e walk a cada quadro.
			rapidez = minf(rapidez, maxf(0, distancia - parar) * 3.0)
			desejada = _desviar(direcao) * rapidez
		if is_on_floor() and _recarga_salto <= 0 and (_salto_pendente > 0 or _degrau(desejada)):
			velocity.y = impulso_salto
			_recarga_salto = 1.0
			_salto_pendente = 0
	else:
		_seguindo = false
	var aceleracao := 12.0 if is_on_floor() else 5.0
	velocity.x = move_toward(velocity.x, desejada.x, aceleracao * delta)
	velocity.z = move_toward(velocity.z, desejada.z, aceleracao * delta)
	if not is_on_floor():
		velocity.y -= gravidade * delta
	move_and_slide()
	var real := get_real_velocity()
	var rapidez_real := Vector2(real.x, real.z).length()
	if rapidez_real > .12:
		var direcao_real := Vector3(real.x, 0, real.z).normalized()
		# Escolhe a pata que lidera sem girar 180° a cada retorno do jogador.
		if absf(visual.basis.x.dot(direcao_real)) > .35:
			_sentido = signf(visual.basis.x.dot(direcao_real))
		var yaw := atan2(-direcao_real.z * _sentido, direcao_real.x * _sentido)
		visual.rotation.y = lerp_angle(visual.rotation.y, yaw, minf(1, delta * 9.0))
	# Beliscando: vira a FRENTE (as pinças) para o inimigo, não o lado.
	if _mirando > 0 and is_instance_valid(_inimigo):
		var para := _inimigo.global_position - global_position
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-para.x, -para.z), minf(1, delta * 14.0))
	var novo: StringName = &"jump" if not is_on_floor() else (&"run" if rapidez_real > velocidade_andar + .4 else (&"walk" if rapidez_real > .12 else &"idle"))
	if novo != estado:
		estado = novo
		mudou_estado.emit(estado)
	animador.animar(delta, visual.basis.inverse() * real, is_on_floor(), velocity.y)
	_relogio_bolhas -= delta
	if _relogio_bolhas <= 0:
		soltar_bolhas()
		_relogio_bolhas = randf_range(intervalo_bolhas.x, intervalo_bolhas.y)
	# Mapas do editor não têm navmesh. Um bloqueio prolongado ou respawn do dono
	# recupera o companheiro em chão verificado; não atravessa paredes caminhando.
	_preso = _preso + delta if _seguindo and rapidez_real < .15 else 0.0
	_sem_chao = 0.0 if is_on_floor() else _sem_chao + delta
	if modo == ModoDoPet.LIVRE and _preso > 5.0 and _sem_chao <= 4.0:
		# Passeando e travado: escolhe outro ponto em vez de pular para o dono.
		_livre_ponto = Vector3.INF
		_preso = 0
	elif is_instance_valid(alvo) and (distancia > 35 or _preso > 5.0 or _sem_chao > 4.0):
		var ponto: Variant = ponto_seguro(alvo, self)
		if ponto is Vector3:
			global_position = ponto
			velocity = Vector3.ZERO
		_preso = 0
		_sem_chao = 0

## O próximo ponto do passeio livre: a até 5 m de casa, com uma pausa em cada um.
func _ponto_livre(delta: float) -> Vector3:
	if _livre_ponto == Vector3.INF:
		_livre_ponto = casa + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
		_livre_parado = 0.0
	if Vector2(_livre_ponto.x - global_position.x, _livre_ponto.z - global_position.z).length() < 0.8:
		_livre_parado += delta
		if _livre_parado > _livre_pausa:
			_livre_ponto = Vector3.INF
			_livre_pausa = randf_range(3.0, 7.0)
	return _livre_ponto if _livre_ponto != Vector3.INF else global_position


func _beliscar(inimigo: Node3D) -> void:
	_recarga_pinca = RECARGA_PINCA
	_mirando = 0.5
	var para := inimigo.global_position - global_position
	para.y = 0
	var dir := para.normalized() if para.length_squared() > 0.0001 else Vector3.FORWARD
	# Estocada curta para dentro do golpe.
	velocity += dir * 4.0
	animador.beliscar()
	inimigo.take_damage(DANO_PINCA, global_position, dir * 3.0, 0.2)
	AudioFX.impact(self, inimigo.global_position, 1.1)
	beliscou.emit(inimigo)


func _raio(de: Vector3, ate: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1)
	q.exclude = [get_rid()]
	if is_instance_valid(_ultimo_alvo):
		q.exclude.append(_ultimo_alvo.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(q)

func _degrau(direcao: Vector3) -> bool:
	if direcao.length_squared() < .01:
		return false
	var frente := direcao.normalized() * 1.4
	return not _raio(global_position + Vector3.UP * .25, global_position + Vector3.UP * .25 + frente).is_empty() \
		and _raio(global_position + Vector3.UP * 1.4, global_position + Vector3.UP * 1.4 + frente).is_empty()

func _desviar(direcao: Vector3) -> Vector3:
	if not is_on_floor():
		return direcao
	for angulo in [0.0, .65, -.65, 1.2, -1.2]:
		var rumo := direcao.rotated(Vector3.UP, angulo)
		var origem := global_position + Vector3.UP * .9
		var parede := _raio(origem, origem + rumo * 1.65)
		var piso := _raio(global_position + rumo * 1.65 + Vector3.UP, global_position + rumo * 1.65 - Vector3.UP * 1.4)
		if parede.is_empty() and not piso.is_empty() and (piso.normal as Vector3).y > .6:
			return rumo
	return Vector3.ZERO

func soltar_bolhas() -> void:
	animador.preparar_bolhas()
	for emissor in animador.emissores:
		if not is_instance_valid(emissor):
			continue
		var efeito := Bolhas.new()
		efeito.name = "BolhasCaranguejo"
		# Filho do pet, mas top_level: flutua no lugar da emissão enquanto ele anda.
		add_child(efeito)
		efeito.top_level = true
		efeito.global_transform = emissor.global_transform.orthonormalized()
	soltou_bolhas.emit()

## Não nasce em queda livre nem dentro de uma parede. Retorna null sem chão livre.
static func ponto_seguro(alvo: Node3D, pet: PhysicsBody3D = null) -> Variant:
	var espaco := alvo.get_world_3d().direct_space_state
	var escala: Vector3 = pet.escala_modelo if is_instance_valid(pet) else Vector3.ONE
	var excluir: Array[RID] = []
	if alvo is PhysicsBody3D:
		excluir.append((alvo as PhysicsBody3D).get_rid())
	if is_instance_valid(pet):
		excluir.append(pet.get_rid())
	for raio in [4.0, 5.5, 3.0]:
		for i in 12:
			var angulo := float(i) * TAU / 12.0
			var p: Vector3 = alvo.global_position + Vector3(cos(angulo), 0, sin(angulo)) * float(raio)
			var consulta := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 2.0, p - Vector3.UP * 8.0, 1)
			consulta.exclude = excluir
			var solo := espaco.intersect_ray(consulta)
			if solo.is_empty() or (solo.normal as Vector3).y < .7:
				continue
			p = solo.position + Vector3.UP * .05
			var volume := PhysicsShapeQueryParameters3D.new()
			volume.shape = forma_do_corpo(escala)
			volume.transform.origin = p + Vector3.UP * .53 * escala.y
			volume.collision_mask = 1
			volume.exclude = excluir
			if espaco.intersect_shape(volume, 1).is_empty():
				return p
	return null


func take_damage(amount: float, _from_pos: Vector3 = Vector3.ZERO, _knockback: Vector3 = Vector3.ZERO, _hitstun: float = 0.0) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	if preload("res://src/historia/tripulantes/socorro.gd").proteger(self, amount): return
	health = maxf(health - amount, 0.0)
	FxUtil.flash_red(visual if visual != null else self)
	if health <= 0.0:
		morreu.emit(self)
