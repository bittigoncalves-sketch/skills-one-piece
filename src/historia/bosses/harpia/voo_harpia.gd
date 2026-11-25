extends RefCounted
## Voo da Harpia entre as pedras (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md).
##
## Pedido do dono: "garantir que ela se movimente adequadamente entre as pedras ... após
## a investida ela já ganha velocidade novamente voando ao redor dos picos". Antes ela
## ia em linha reta até um ponto (`move_and_collide`): encostou numa pedra, PAROU ali.
##
##   • `voar`: direção desejada → olha 0,8 s à frente com uma esfera do tamanho do corpo
##     (`cast_motion`); se vai bater, desvia PELA SUPERFÍCIE (desliza na normal e sobe);
##     mantém folga do chão; inércia (curva suave) e `move_and_slide`, que raspa em vez
##     de travar. Inclina o corpo na curva (asa de dentro baixa) e no mergulho/subida.
##   • `picos`: os pontos mais altos do território (raios numa grade sobre a área; máximos
##     locais a até 25 m do mais alto, separados ≥ 24 m). Mudou o mapa, mudam os picos.

const RAIO_DESVIO := 1.8            # m — a esfera que olha à frente (corpo de 7 m de asa, fechado)
const OLHAR := 0.8                  # s à frente
const FOLGA_DO_CHAO := 4.5          # m mínimos sobre o que estiver embaixo
const PASSO_GRADE := 6.0            # m entre raios na busca dos picos
const SEPARACAO := 24.0             # m entre dois picos
const ABAIXO_DO_MAIS_ALTO := 25.0   # m: só é pico o que chega perto do topo


## Voa `corpo` para `destino` a até `vel_max`. `agilidade` = quão rápido a velocidade vira
## a desejada (1/s). Devolve a velocidade do quadro. `excluir`: corpos que não desvia
## (o alvo da investida, o próprio jogador).
static func voar(corpo: CharacterBody3D, destino: Vector3, vel_max: float, delta: float,
		agilidade := 3.0, excluir: Array[RID] = []) -> Vector3:
	var pos := corpo.global_position
	var para := destino - pos
	var dist := para.length()
	var desejo := Vector3.ZERO
	if dist > 0.05:
		desejo = para / dist * minf(vel_max, dist * 2.5 + 1.5)          # freia chegando
	var espaco := corpo.get_world_3d().direct_space_state
	var fora: Array[RID] = excluir.duplicate()
	fora.append(corpo.get_rid())
	var hurt: Variant = corpo.get("_hurtbox")
	if hurt is CollisionObject3D:
		fora.append((hurt as CollisionObject3D).get_rid())
	for n in corpo.get_tree().get_nodes_in_group("player"):
		if n is CollisionObject3D:
			fora.append((n as CollisionObject3D).get_rid())
	var meio := _meio_do_corpo(corpo)
	# 1) Vai bater? Desvia pela superfície e sobe.
	if desejo.length_squared() > 0.01:
		var forma := SphereShape3D.new()
		forma.radius = RAIO_DESVIO
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = forma
		q.transform.origin = pos + meio
		q.motion = desejo * OLHAR
		q.collision_mask = 1
		q.exclude = fora
		var lim := espaco.cast_motion(q)
		if lim.size() >= 2 and lim[1] < 1.0:
			q.transform.origin += q.motion * lim[1]
			q.motion = Vector3.ZERO
			var info := espaco.get_rest_info(q)
			var n: Vector3 = info.get("normal", Vector3.UP)
			if n.length_squared() < 0.5:
				n = -desejo.normalized()
			var perto := 1.0 - lim[1]                                   # 1 = já encostando
			var desvio := desejo.slide(n) + (n * 0.55 + Vector3.UP * 0.85).normalized() * vel_max * (0.35 + perto)
			desejo = desvio.limit_length(vel_max)
	# 2) Folga do chão (raio para baixo no cenário).
	var r := PhysicsRayQueryParameters3D.create(pos + meio, pos + Vector3.DOWN * (FOLGA_DO_CHAO + 2.0), 1)
	r.exclude = fora
	var chao := espaco.intersect_ray(r)
	if not chao.is_empty():
		var falta := FOLGA_DO_CHAO - (pos.y - float(chao["position"].y))
		if falta > 0.0:
			desejo.y = maxf(desejo.y, falta * 3.0)
	var antes := corpo.velocity
	corpo.velocity = antes.lerp(desejo, 1.0 - exp(-agilidade * delta))
	corpo.move_and_slide()
	_inclinar(corpo, antes, corpo.velocity, delta)
	return corpo.velocity


## Vira para onde voa; asa de dentro baixa na curva; bico para cima/baixo subindo/descendo.
static func _inclinar(corpo: Node3D, antes: Vector3, agora: Vector3, delta: float) -> void:
	var visual: Node3D = corpo.get("_visual")
	if visual == null:
		return
	var plano := Vector2(agora.x, agora.z)
	var giro := 0.0
	if plano.length() > 0.5:
		var yaw_antes: float = corpo.get("_yaw")
		var yaw := lerp_angle(yaw_antes, atan2(agora.x, agora.z), 1.0 - exp(-6.0 * delta))
		giro = wrapf(yaw - yaw_antes, -PI, PI) / maxf(delta, 0.001)
		corpo.set("_yaw", yaw)
		visual.rotation.y = yaw
	var rolar := clampf(-giro * 0.32, -0.7, 0.7)
	var arfar := clampf(-atan2(agora.y, maxf(plano.length(), 0.1)) * 0.55, -0.6, 0.6)
	visual.rotation.z = lerp_angle(visual.rotation.z, rolar, 1.0 - exp(-5.0 * delta))
	visual.rotation.x = lerp_angle(visual.rotation.x, arfar, 1.0 - exp(-5.0 * delta))


## Volta o corpo ao nível (fim do voo controlado).
static func nivelar(corpo: Node3D) -> void:
	var visual: Node3D = corpo.get("_visual")
	if visual != null:
		visual.rotation.z = 0.0
		visual.rotation.x = 0.0


static func _meio_do_corpo(corpo: Node3D) -> Vector3:
	var col := corpo.get_node_or_null("Colisao") as Node3D
	return Vector3.UP * (col.position.y if col != null else 1.0)


## Os picos do território do `corpo` (`area` do AnimalDaIlha). Topos, em ordem do mais alto.
static func picos(corpo: Node3D) -> Array[Vector3]:
	var area: Dictionary = corpo.get("area")
	var centro: Vector3 = area.get("centro", corpo.global_position)
	var meio: Vector3 = area.get("meio", Vector3(30, 20, 30))
	var base: Basis = area.get("base", Basis.IDENTITY)
	var espaco := corpo.get_world_3d().direct_space_state
	var fora: Array[RID] = [corpo.get_rid()]
	var nx := maxi(int(meio.x * 2.0 / PASSO_GRADE), 1)
	var nz := maxi(int(meio.z * 2.0 / PASSO_GRADE), 1)
	var alturas := {}
	var pontos := {}
	var topo := -INF
	for i in nx + 1:
		for k in nz + 1:
			var local := Vector3(-meio.x + i * PASSO_GRADE, 0.0, -meio.z + k * PASSO_GRADE)
			var p := centro + base * local
			var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, centro.y + meio.y + 80.0, p.z),
				Vector3(p.x, centro.y - meio.y - 80.0, p.z), 1)
			q.exclude = fora
			var hit := espaco.intersect_ray(q)
			if hit.is_empty() or hit["collider"] is CharacterBody3D:
				continue
			var h := float(hit["position"].y)
			alturas[Vector2i(i, k)] = h
			pontos[Vector2i(i, k)] = hit["position"]
			topo = maxf(topo, h)
	var candidatos: Array = []
	for c: Vector2i in alturas:
		var h: float = alturas[c]
		if h < topo - ABAIXO_DO_MAIS_ALTO:
			continue
		var maximo := true
		for di in range(-2, 3):
			for dk in range(-2, 3):
				var v := c + Vector2i(di, dk)
				if v != c and alturas.has(v) and float(alturas[v]) > h:
					maximo = false
		if maximo:
			candidatos.append(pontos[c])
	candidatos.sort_custom(func(a: Vector3, b: Vector3): return a.y > b.y)
	var saida: Array[Vector3] = []
	for p: Vector3 in candidatos:
		if saida.all(func(s: Vector3): return Vector2(s.x - p.x, s.z - p.z).length() >= SEPARACAO):
			saida.append(p)
		if saida.size() >= 4:
			break
	if saida.is_empty():
		saida.append(Vector3(centro.x, (topo if is_finite(topo) else centro.y), centro.z))
	return saida
