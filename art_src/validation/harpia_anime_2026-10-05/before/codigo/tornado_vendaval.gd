extends Node3D
## Relógio único de cinco segundos: capturar alguém nunca reinicia o tornado.
const Captura := preload("res://src/historia/bosses/harpia/captura_vento.gd")
const DURACAO := 5.0
var duracao := DURACAO
var tempo := 0.0
var velocidade := 8.0
var raio := 2.5
var altura := 7.0
var conjurador: Node3D
var direcao := Vector3.FORWARD
var capturas: Array[Node] = []
var _capturados := {}
var _terminado := false
var _visual: Node3D
var _volume := CylinderShape3D.new()


func configurar(dono: Node3D, rumo: Vector3) -> void:
	conjurador = dono
	direcao = Vector3(rumo.x, 0, rumo.z).normalized()
	if direcao.is_zero_approx():
		direcao = Vector3.FORWARD
	if is_instance_valid(conjurador) and not conjurador.tree_exiting.is_connected(cancelar):
		conjurador.tree_exiting.connect(cancelar, CONNECT_ONE_SHOT)


func _ready() -> void:
	add_to_group("tornados_harpia")
	_volume.radius = raio
	_volume.height = altura
	var caminho := "res://src/historia/bosses/harpia/vento_harpia.gd"
	if ResourceLoader.exists(caminho):
		_visual = load(caminho).new()
		add_child(_visual)
		_visual.configurar("tornado", raio, altura)


func _physics_process(delta: float) -> void:
	if _terminado:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	if not is_instance_valid(conjurador) or conjurador.is_queued_for_deletion() \
		or (conjurador.get("health") != null and float(conjurador.get("health")) <= 0.0):
		cancelar()
		return
	var passo := minf(delta, maxf(0.0, DURACAO - tempo))
	var antes := global_position
	var vivos := Captura.seres_vivos(get_tree())
	var excluidos: Array[RID] = []
	for alvo in vivos:
		if alvo is CollisionObject3D:
			excluidos.append(alvo.get_rid())
		var hb := HurtboxDeCombate.rid_de(alvo)
		if hb.is_valid():
			excluidos.append(hb)
	_mover(passo, excluidos)
	for alvo in vivos:
		if alvo == conjurador or _capturados.has(alvo.get_instance_id()):
			continue
		if _atravessou(alvo, antes, global_position, excluidos):
			var captura := Captura.tomar(alvo, self, capturas.size())
			if captura != null:
				_capturados[alvo.get_instance_id()] = true
				capturas.append(captura)
	tempo += passo
	for captura in capturas:
		if is_instance_valid(captura) and captura.em_orbita:
			captura.orbitar(global_position, tempo, passo)
	if _visual != null:
		_visual.atualizar(tempo, minf(tempo / .2, (DURACAO - tempo) / .3))
	if tempo >= DURACAO - .00001:
		_terminar(true)


func _mover(delta: float, excluidos: Array[RID]) -> void:
	var espaco := get_world_3d().direct_space_state
	var movimento := direcao * velocidade * delta
	var proximo := global_position + movimento
	var ray := PhysicsRayQueryParameters3D.create(proximo + Vector3.UP * 3.0, proximo + Vector3.DOWN * 8.0, 1)
	ray.exclude = excluidos
	var piso := espaco.intersect_ray(ray)
	if not piso.is_empty() and (piso["normal"] as Vector3).y > .5:
		movimento.y = clampf(float(piso["position"].y) + .08 - global_position.y, -3.0 * delta, 3.0 * delta)
	else:
		var agua := AguaDoMundo.nivel_em(proximo.x, proximo.z)
		if not is_nan(agua):
			movimento.y = clampf(agua + .08 - global_position.y, -3.0 * delta, 3.0 * delta)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = _volume
	consulta.transform.origin = global_position + Vector3.UP * (altura * .5 + .08)
	consulta.motion = movimento
	consulta.collision_mask = 1
	consulta.exclude = excluidos
	var limite := espaco.cast_motion(consulta)
	if limite.size() >= 1:
		global_position += movimento * maxf(0.0, limite[0] - .001)


func _atravessou(alvo: Node3D, de: Vector3, ate: Vector3, excluidos: Array[RID]) -> bool:
	var p := Captura.centro(alvo)
	if p.y < minf(de.y, ate.y) - .2 or p.y > maxf(de.y, ate.y) + altura:
		return false
	var inicio := Vector2(de.x, de.z)
	var segmento := Vector2(ate.x - de.x, ate.z - de.z)
	var ponto := Vector2(p.x, p.z)
	var f := clampf((ponto - inicio).dot(segmento) / maxf(segmento.length_squared(), .000001), 0.0, 1.0)
	if ponto.distance_to(inicio + segmento * f) > raio:
		return false
	var origem_raio := de.lerp(ate, f)
	origem_raio.y = clampf(p.y, origem_raio.y + .2, origem_raio.y + altura)
	if origem_raio.distance_squared_to(p) < .00001:
		return true
	var consulta := PhysicsRayQueryParameters3D.create(origem_raio, p, 1)
	consulta.exclude = excluidos
	return get_world_3d().direct_space_state.intersect_ray(consulta).is_empty()


func cancelar() -> void:
	_terminar(false)


func _terminar(lancar: bool) -> void:
	if _terminado:
		return
	_terminado = true
	if is_instance_valid(conjurador) and conjurador.tree_exiting.is_connected(cancelar):
		conjurador.tree_exiting.disconnect(cancelar)
	for captura in capturas:
		if not is_instance_valid(captura) or not captura.em_orbita:
			continue
		var impulso := Vector3.ZERO
		if lancar and is_instance_valid(captura.alvo):
			var fora: Vector3 = captura.alvo.global_position - global_position
			fora.y = 0.0
			if fora.length_squared() < .01:
				fora = direcao
			impulso = fora.normalized() * 18.0 + Vector3.UP * 8.0
		captura.soltar(impulso)
	capturas.clear()
	set_physics_process(false)
	queue_free()


func _exit_tree() -> void:
	_terminar(false)
