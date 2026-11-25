extends CharacterBody3D
# ============================================================================
#  GAIVOTA — pet do Modo História que VOA (30/09/2026).
#
#  Pedido do dono: gaivota low poly com comportamento completo próprio — em vez de só
#  rodear o jogador, ela vive por conta própria e só segue quando o jogador muda o
#  comportamento dela (menu B, `ModoDoPet`). Mora no inventário (tecla N).
#
#  ------------------------------------------------------------------ ESTADOS
#    VOANDO       livre: plana e bate asa em volta de CASA, trocando de ponto
#    POUSANDO     desce para um chão firme perto de casa (ou do dono), freando
#    NO_CHAO      anda um pouco, olha em volta, bica o chão; em LIVRE foge (decola)
#                 se o jogador chegar perto; em SEGUIR fica até o dono andar
#    DECOLANDO    batida forte para cima
#    SEGUINDO     acompanha o dono por trás e por cima; circula quando ele para e
#                 pousa ao lado se ele ficar parado
#    MERGULHANDO  (em guarda / agressivo) desce em linha no alvo e bica
#    SUBINDO      depois da bicada, sobe para longe antes do próximo mergulho
#
#  Voo sem navmesh: vai reto com curva limitada, escorrega em parede e nunca desce
#  abaixo de `ALTURA_MINIMA` do chão (ou da água, que não tem colisão).
#  Não é alvo de combate e não bloqueia o dono (camada 0), como o caranguejo.
# ============================================================================

signal mudou_estado(estado: StringName)
signal modo_mudou(modo: StringName)
## Vida acabou (01/10/2026, decisão do dono: pet que morre é apagado para sempre — quem
## apaga do progresso é a `Companhia`). Só bicho bravo fere pet: ele chama
## `take_damage` direto; os golpes do jogador não o acham (camada 0).
signal morreu(pet: Node3D)
signal bicou(alvo: Node3D)

const MODELO := "res://assets/models/pets/gaivota.glb"
const Animador := preload("res://src/historia/pets/animador_gaivota.gd")
const MIRA := preload("res://src/combat/mira_de_rocket.gd")
const ESPECIE := "gaivota"

enum Estado { VOANDO, POUSANDO, NO_CHAO, DECOLANDO, SEGUINDO, MERGULHANDO, SUBINDO }

## A gaivota do modelo tem 0,62 m do bico à cauda; um pouco maior lê melhor na câmera.
@export var escala_modelo := 1.25
@export var velocidade_voo := 6.5
@export var velocidade_rapida := 11.0
@export var velocidade_andar := 0.9
## Curva: rad/s que o rumo gira atrás do destino (faz arco, não vira na hora).
@export var giro := 2.4
## Livre: altura sobre o chão e distância de casa dos pontos de voo.
@export var altura_livre := Vector2(4.0, 8.0)
@export var raio_livre := Vector2(4.0, 10.0)
## Livre: quanto tempo voa antes de pousar, e quanto fica no chão.
@export var tempo_no_ar := Vector2(10.0, 20.0)
@export var tempo_no_chao := Vector2(5.0, 12.0)
## Livre, no chão: o jogador mais perto que isto a espanta.
@export var distancia_de_fuga := 3.5
## Seguindo: onde ela fica em relação ao dono.
@export var altura_seguir := 2.8
@export var raio_circulo := 3.2
## Seguindo: dono parado por este tempo → ela pousa ao lado.
@export var espera_para_pousar := 6.0
@export var dano_bicada := 8.0
@export var recarga_bicada := 1.6

const ALTURA_MINIMA := 1.2
const CHEGOU := 0.6
const LONGE_DEMAIS := 60.0

var alvo_de: Callable
var modo: StringName = ModoDoPet.LIVRE
var especie := ESPECIE
var nome_exibido := "Gaivota"
## Vida do pet (40: na escala do bicho bravo que bate 3–7 por golpe).
var max_health := 40.0
var health := 40.0
var estado: Estado = Estado.VOANDO
## O chão do lugar onde ela ficou livre (onde saiu do inventário ou recebeu a ordem).
var casa := Vector3.ZERO
var visual: Node3D
var animador: Node3D

var _rumo := Vector3.FORWARD
var _curva := 0.0
var _destino := Vector3.ZERO
var _t := 0.0
var _duracao := 0.0
var _voo_livre := 0.0
var _recarga := 0.0
var _alvo_ataque: Node3D = null
var _dono_parado := 0.0
var _dono_antes := Vector3.INF
var _angulo := 0.0
var _andar_para := Vector3.INF


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var colisao := CollisionShape3D.new()
	colisao.name = "Colisao"
	var esfera := SphereShape3D.new()
	esfera.radius = 0.18 * escala_modelo
	colisao.shape = esfera
	colisao.position.y = 0.3 * escala_modelo
	add_child(colisao)
	visual = (load(MODELO) as PackedScene).instantiate()
	visual.name = "Visual"
	visual.scale = Vector3.ONE * escala_modelo
	add_child(visual)
	animador = Animador.new()
	animador.name = "Animador"
	add_child(animador)
	animador.montar(visual)
	animador.fixar(1.0)
	add_to_group("pets_historia")
	var chao := _chao_em(global_position, 40.0)
	casa = chao.position if not chao.is_empty() else global_position
	_angulo = randf() * TAU
	_entrar(Estado.VOANDO if modo == ModoDoPet.LIVRE else Estado.SEGUINDO)


## Troca o comportamento (menu B). Livre: a casa passa a ser onde ela está agora.
func definir_modo(novo: StringName) -> void:
	if not ModoDoPet.valido(novo):
		return
	modo = novo
	_alvo_ataque = null
	if novo == ModoDoPet.LIVRE:
		var chao := _chao_em(global_position, 40.0)
		if not chao.is_empty():
			casa = chao.position
		if estado != Estado.NO_CHAO:
			_entrar(Estado.VOANDO)
	elif estado == Estado.NO_CHAO:
		_entrar(Estado.DECOLANDO)
	else:
		_entrar(Estado.SEGUINDO)
	modo_mudou.emit(novo)


func dono() -> Node3D:
	return alvo_de.call() as Node3D if alvo_de.is_valid() else null


func nome_do_estado() -> StringName:
	return StringName(Estado.keys()[estado].to_lower())


func _entrar(novo: Estado) -> void:
	estado = novo
	_t = 0.0
	match novo:
		Estado.VOANDO:
			_duracao = 0.0
			if _voo_livre <= 0.0:
				_voo_livre = randf_range(tempo_no_ar.x, tempo_no_ar.y)
		Estado.NO_CHAO:
			_duracao = randf_range(tempo_no_chao.x, tempo_no_chao.y)
			_andar_para = Vector3.INF
			velocity = Vector3.ZERO
		Estado.DECOLANDO:
			_duracao = 0.55
			AudioFX.whoosh(self, global_position, 1.3)
		Estado.SUBINDO:
			_duracao = 0.7
	mudou_estado.emit(nome_do_estado())


func _physics_process(delta: float) -> void:
	_t += delta
	_recarga = maxf(0.0, _recarga - delta)
	var d := dono()
	if not is_instance_valid(d):
		d = null
	# Em guarda / agressivo: um alvo interrompe o que ela estiver fazendo.
	if d != null and _recarga <= 0.0 and estado not in [Estado.MERGULHANDO, Estado.SUBINDO]:
		var alvo := ModoDoPet.alvo(modo, d, self)
		if alvo != null:
			_alvo_ataque = alvo
			_entrar(Estado.MERGULHANDO)
	var alvos := {"voo": 1.0, "batida": 0.3}
	var andando := 0.0
	match estado:
		Estado.VOANDO:
			alvos = _voar_livre(delta)
		Estado.POUSANDO:
			alvos = _pousar(delta)
		Estado.NO_CHAO:
			andando = _no_chao(delta, d)
			alvos = {"voo": 0.0}
		Estado.DECOLANDO:
			velocity = _rumo * 3.0 + Vector3.UP * 4.0
			alvos = {"voo": 1.0, "batida": 1.0}
			if _t >= _duracao:
				_entrar(Estado.VOANDO if modo == ModoDoPet.LIVRE else Estado.SEGUINDO)
		Estado.SEGUINDO:
			alvos = _seguir(delta, d)
		Estado.MERGULHANDO:
			alvos = _mergulhar(delta, d)
		Estado.SUBINDO:
			velocity = -_rumo * 2.5 + Vector3.UP * 4.5
			alvos = {"voo": 1.0, "batida": 1.0}
			if _t >= _duracao:
				_entrar(Estado.SEGUINDO if modo != ModoDoPet.LIVRE else Estado.VOANDO)
	move_and_slide()
	_virar_visual(delta)
	animador.animar(delta, alvos, _curva, velocity.y, andando)
	# Segurança sem navmesh: presa longe do dono (ou caída no vazio) volta para perto.
	if d != null and modo != ModoDoPet.LIVRE and global_position.distance_to(d.global_position) > LONGE_DEMAIS:
		global_position = d.global_position + Vector3(2.0, altura_seguir, 2.0)
		velocity = Vector3.ZERO


# ------------------------------------------------------------------ livre
func _voar_livre(delta: float) -> Dictionary:
	_voo_livre -= delta
	if _voo_livre <= 0.0:
		var pouso := _lugar_de_pouso(casa, 3.0)
		if pouso != Vector3.INF:
			_destino = pouso
			_entrar(Estado.POUSANDO)
			return {"voo": 1.0, "batida": 0.2}
		_voo_livre = 4.0   # sem chão bom agora: tenta de novo daqui a pouco
	if _duracao <= 0.0 or _t >= _duracao or _plana(_destino - global_position) < 1.5:
		_novo_ponto_livre()
	var subindo := _destino.y > global_position.y + 0.5
	_voar_para(_destino, velocidade_voo, delta)
	# Bate asa subindo; plana nivelada ou descendo (a gaivota planeia muito).
	return {"voo": 1.0, "batida": 0.85 if subindo else 0.15 + 0.1 * sin(_t * 0.7)}


func _novo_ponto_livre() -> void:
	var angulo := randf() * TAU
	var raio := randf_range(raio_livre.x, raio_livre.y)
	var ponto := casa + Vector3(cos(angulo), 0.0, sin(angulo)) * raio
	ponto.y = _referencia_do_chao(ponto) + randf_range(altura_livre.x, altura_livre.y)
	_destino = ponto
	_t = 0.0
	_duracao = randf_range(3.0, 6.0)


func _pousar(delta: float) -> Dictionary:
	if _t > 12.0:
		# Não conseguiu chegar (parede no caminho): desiste e volta a voar.
		_entrar(Estado.VOANDO if modo == ModoDoPet.LIVRE else Estado.SEGUINDO)
		return {"voo": 1.0, "batida": 0.6}
	var acima := _destino + Vector3.UP * 2.5
	var horizontal := _plana(_destino - global_position)
	if horizontal > 1.2:
		# Aproximação: chega por cima do ponto, já perdendo velocidade.
		_voar_para(acima, maxf(2.5, minf(velocidade_voo, horizontal * 1.5)), delta)
		return {"voo": 1.0, "batida": 0.25, "pouso": clampf(1.0 - horizontal / 5.0, 0.0, 1.0)}
	# Descida final, freando com as asas.
	var falta := global_position.y - _destino.y
	velocity = Vector3((_destino.x - global_position.x) * 2.0, -clampf(falta * 1.8, 0.6, 3.0),
		(_destino.z - global_position.z) * 2.0)
	if falta <= 0.05:
		global_position.y = _destino.y
		_entrar(Estado.NO_CHAO)
		return {"voo": 0.0}
	return {"voo": 1.0, "batida": 0.5, "pouso": 1.0}


# ------------------------------------------------------------------ no chão
func _no_chao(_delta: float, d: Node3D) -> float:
	var chao := _chao_em(global_position, 1.5)
	if chao.is_empty():
		_entrar(Estado.DECOLANDO)
		return 0.0
	global_position.y = chao.position.y
	if d != null:
		var perto := _plana(d.global_position - global_position)
		if modo == ModoDoPet.LIVRE and perto < distancia_de_fuga:
			# Espantada: decola para o lado oposto ao jogador.
			_rumo = _plana_dir(global_position - d.global_position, _rumo)
			_entrar(Estado.DECOLANDO)
			return 0.0
		var dono_vel := (d as CharacterBody3D).velocity if d is CharacterBody3D else Vector3.ZERO
		if modo != ModoDoPet.LIVRE and (perto > 4.5 or Vector2(dono_vel.x, dono_vel.z).length() > 1.5):
			# Pousada ao lado do dono: ele andou, ela vai junto.
			_entrar(Estado.DECOLANDO)
			return 0.0
	if modo == ModoDoPet.LIVRE and _t >= _duracao:
		_entrar(Estado.DECOLANDO)
		return 0.0
	# Passinhos: de vez em quando escolhe um ponto a menos de 1,5 m e vai andando.
	if _andar_para == Vector3.INF and randf() < 0.004:
		var alvo := global_position + Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(-1.5, 1.5))
		var chao_alvo := _chao_em(alvo, 1.0)
		if not chao_alvo.is_empty() and (chao_alvo.normal as Vector3).y > 0.7:
			_andar_para = chao_alvo.position
	if _andar_para != Vector3.INF:
		var falta := _plana(_andar_para - global_position)
		if falta < 0.1:
			_andar_para = Vector3.INF
		else:
			var dir := _plana_dir(_andar_para - global_position, _rumo)
			_rumo = dir
			velocity = dir * velocidade_andar
			return velocidade_andar
	velocity = Vector3.ZERO
	return 0.0


# ------------------------------------------------------------------ seguindo
func _seguir(delta: float, d: Node3D) -> Dictionary:
	if d == null:
		_entrar(Estado.VOANDO)
		return {"voo": 1.0, "batida": 0.3}
	var andou := _dono_andou(d, delta)
	var dono_vel := (d as CharacterBody3D).velocity if d is CharacterBody3D else Vector3.ZERO
	var ponto: Vector3
	if Vector2(dono_vel.x, dono_vel.z).length() > 1.0:
		# Dono andando: por trás e por cima, um pouco para o lado (não tapa a câmera).
		var frente := _plana_dir(dono_vel, Vector3.FORWARD)
		var direita := frente.cross(Vector3.UP)
		ponto = d.global_position - frente * 2.5 + direita * 1.4 + Vector3.UP * altura_seguir
	else:
		# Dono parado: circula devagar em volta dele.
		_angulo += delta * 0.6
		ponto = d.global_position + Vector3(cos(_angulo), 0.0, sin(_angulo)) * raio_circulo + Vector3.UP * altura_seguir
		# Parado por um tempo: pousa ao lado dele.
		if _dono_parado >= espera_para_pousar and andou < 0.05:
			var pouso := _lugar_de_pouso(d.global_position, 2.2, 1.4)
			if pouso != Vector3.INF:
				_destino = pouso
				_entrar(Estado.POUSANDO)
	var distancia := global_position.distance_to(ponto)
	var rapidez := velocidade_rapida if distancia > 12.0 else clampf(distancia * 1.6, 2.0, velocidade_voo)
	_voar_para(ponto, rapidez, delta)
	return {"voo": 1.0, "batida": 0.9 if rapidez > velocidade_voo or ponto.y > global_position.y + 0.6 else 0.3}


# ------------------------------------------------------------------ ataque
func _mergulhar(delta: float, d: Node3D) -> Dictionary:
	var alvo := _alvo_ataque
	var ainda := d != null and ModoDoPet.no_raio(modo, d, alvo) and _t < 3.5
	if not ainda:
		_alvo_ataque = null
		_entrar(Estado.SUBINDO)
		return {"voo": 1.0, "batida": 1.0}
	var ponto := alvo.global_position + Vector3.UP * 0.4
	_voar_para(ponto, velocidade_rapida * 1.2, delta, giro * 2.2)
	if global_position.distance_to(ponto) < 0.9:
		var empurrao := _plana_dir(alvo.global_position - global_position, _rumo) * 1.5
		alvo.take_damage(dano_bicada, global_position, empurrao, 0.1)
		bicou.emit(alvo)
		AudioFX.impact(self, global_position, 1.6)
		_recarga = recarga_bicada
		_alvo_ataque = null
		_entrar(Estado.SUBINDO)
	return {"voo": 1.0, "batida": 0.0, "mergulho": 1.0}


# ------------------------------------------------------------------ voo
## Voa em direção a `ponto`: o rumo no plano gira com velocidade angular limitada
## (arco), a altura corrige por proporção, e nunca desce rente ao chão/água.
func _voar_para(ponto: Vector3, rapidez: float, delta: float, giro_maximo := -1.0) -> void:
	var quer := _plana_dir(ponto - global_position, _rumo)
	var angulo := _rumo.signed_angle_to(quer, Vector3.UP)
	var passo := clampf(angulo, -(giro if giro_maximo < 0.0 else giro_maximo) * delta,
		(giro if giro_maximo < 0.0 else giro_maximo) * delta)
	_rumo = _rumo.rotated(Vector3.UP, passo).normalized()
	_curva = passo / maxf(delta, 0.0001)
	var vy := clampf((ponto.y - global_position.y) * 1.6, -5.0, 4.5)
	var piso := _referencia_do_chao(global_position) + ALTURA_MINIMA
	if global_position.y < piso and estado != Estado.MERGULHANDO:
		vy = maxf(vy, 2.5)
	# Perto do ponto e virada para longe dele, não passa reto em círculos: desacelera.
	var alinhado := clampf(_rumo.dot(quer), 0.3, 1.0)
	velocity = _rumo * rapidez * alinhado + Vector3.UP * vy


## No ar o bico aponta para o RUMO (subindo de ré depois da bicada, continua virada
## para o alvo); no chão, para onde anda — parada, fica como está.
func _virar_visual(delta: float) -> void:
	var frente := _rumo
	if estado == Estado.NO_CHAO:
		var plano := Vector3(velocity.x, 0.0, velocity.z)
		if plano.length_squared() < 0.01:
			return
		frente = plano.normalized()
	var yaw := atan2(-frente.x, -frente.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))


# ------------------------------------------------------------------ mundo
func _dono_andou(d: Node3D, delta: float) -> float:
	if _dono_antes == Vector3.INF:
		_dono_antes = d.global_position
	var andou := _plana(d.global_position - _dono_antes)
	if andou > 0.05:
		_dono_parado = 0.0
		_dono_antes = d.global_position
	else:
		_dono_parado += delta
	return andou


## Um chão firme (plano, sem corpo por cima) a até `raio` de `centro`, ou INF.
func _lugar_de_pouso(centro: Vector3, raio: float, minimo := 0.0) -> Vector3:
	for i in 10:
		var angulo := randf() * TAU
		var r := randf_range(minimo, raio)
		var p := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * r
		var chao := _chao_em(p, 12.0)
		if chao.is_empty() or (chao.normal as Vector3).y < 0.8:
			continue
		var consulta := PhysicsShapeQueryParameters3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = 0.3
		consulta.shape = esfera
		consulta.transform = Transform3D(Basis.IDENTITY, chao.position + Vector3.UP * 0.4)
		consulta.collision_mask = 1
		consulta.exclude = [get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
			return chao.position
	return Vector3.INF


## Chão de verdade logo abaixo de `ponto` (corpo que toma dano não é chão).
func _chao_em(ponto: Vector3, alcance: float) -> Dictionary:
	if not is_inside_tree():
		return {}
	var fora: Array[RID] = [get_rid()]
	return MIRA.solo(get_world_3d(), ponto + Vector3.UP * 2.0, ponto + Vector3.DOWN * alcance, fora)


## A altura de referência embaixo de `ponto`: o chão, ou a água do oceano (que é só
## visual — sem colisão), ou a casa.
func _referencia_do_chao(ponto: Vector3) -> float:
	var chao := _chao_em(ponto, 60.0)
	if not chao.is_empty():
		return float(chao.position.y)
	var cena := get_tree().current_scene if is_inside_tree() else null
	var oceano := cena.get_node_or_null("Oceano") if cena != null else null
	if oceano != null and oceano.get("nivel") != null and is_finite(float(oceano.get("nivel"))):
		return float(oceano.get("nivel"))
	return casa.y


static func _plana(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


static func _plana_dir(v: Vector3, reserva: Vector3) -> Vector3:
	var p := Vector3(v.x, 0.0, v.z)
	return p.normalized() if p.length_squared() > 0.0001 else reserva


func take_damage(amount: float, _from_pos: Vector3 = Vector3.ZERO, _knockback: Vector3 = Vector3.ZERO, _hitstun: float = 0.0) -> void:
	if amount <= 0.0 or health <= 0.0:
		return
	if preload("res://src/historia/tripulantes/socorro.gd").proteger(self, amount): return
	health = maxf(health - amount, 0.0)
	FxUtil.flash_red(visual if visual != null else self)
	if health <= 0.0:
		morreu.emit(self)
