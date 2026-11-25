class_name PasseioNoConves
extends Node
# ============================================================================
#  PASSEIO NO CONVÉS (15/10/2026) — a tripulação e os bichos andam pelo barco em vez de
#  ficarem parados (pedido do dono).
#
#  Pendurado em quem passeia (um `TripulanteHumano` ou um pet terrestre), ambos FILHOS do
#  barco: o passeio é no referencial do casco, então acompanha o barco sozinho. Escolhe um
#  ponto do convés, anda até lá, para um pouco, escolhe outro.
#
#  O convés é um retângulo em volta do leme (`ALCANCE_X`/`ALCANCE_Z` da boca do casco); um
#  ponto só vale se um raio para baixo acha chão do barco na altura do convés (`TOLERANCIA`) —
#  assim ninguém sobe em cabine nem sai pela borda. Não há desvio de obstáculo no meio do
#  caminho (mastros): GATILHO para um navmesh do convés se algum barco tiver obstáculo no meio.
#
#  `parado` liga/desliga o passeio por quem precisa do corpo quieto (o Barba Negra, mirando).
# ============================================================================

const ALCANCE_X := 0.38           # fração da largura do casco
const ALCANCE_Z := 0.40           # fração do comprimento do casco
const TOLERANCIA := 0.35          # m: diferença de altura aceita no chão do convés
const TENTATIVAS := 12
const GIRO := 7.0                 # 1/s: suavidade ao virar para o caminho

var dono: Node3D                  # quem anda (filho do barco)
var barco: CharacterBody3D
var velocidade := 0.9             # m/s
var parado := false
var pausa := Vector2(1.5, 5.0)    # s parado em cada ponto
var distancia_percorrida := 0.0
var _destino := Vector3.INF
var _espera := 0.0
var _y_do_convez := 0.0


func _ready() -> void:
	_y_do_convez = dono.position.y if dono != null else 0.0
	_espera = randf_range(0.2, pausa.y)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(dono) or not is_instance_valid(barco) or not dono.is_inside_tree():
		return
	if parado:
		_andar_a(0.0)
		return
	if _destino == Vector3.INF:
		_espera -= delta
		_andar_a(0.0)
		if _espera <= 0.0:
			_destino = _escolher_ponto()
			if _destino == Vector3.INF:
				_espera = randf_range(pausa.x, pausa.y)
		return
	var falta := _destino - dono.position
	falta.y = 0.0
	var passo := velocidade * delta
	if falta.length() <= passo:
		dono.position.x = _destino.x
		dono.position.z = _destino.z
		_destino = Vector3.INF
		_espera = randf_range(pausa.x, pausa.y)
		_andar_a(0.0)
		return
	var dir := falta.normalized()
	dono.position += dir * passo
	distancia_percorrida += passo
	_virar(dir, delta)
	_andar_a(velocidade)


## Um ponto do convés (no referencial do barco) com chão firme, ou `Vector3.INF`.
func _escolher_ponto() -> Vector3:
	var tamanho: Vector3 = barco.get("tamanho_casco")
	for _i in TENTATIVAS:
		var local := Vector3(randf_range(-tamanho.x * ALCANCE_X, tamanho.x * ALCANCE_X), _y_do_convez,
			randf_range(-tamanho.z * ALCANCE_Z, tamanho.z * ALCANCE_Z))
		if _chao_do_convez(local):
			return local
	return Vector3.INF


## Há chão do barco, na altura do convés, debaixo de `local`?
func _chao_do_convez(local: Vector3) -> bool:
	if not barco.is_inside_tree():
		return false
	var de := barco.to_global(local + Vector3.UP * 2.5)
	var ate := barco.to_global(local + Vector3.DOWN * 1.0)
	var consulta := PhysicsRayQueryParameters3D.create(de, ate, 1)
	var h := barco.get_world_3d().direct_space_state.intersect_ray(consulta)
	if h.is_empty() or h["collider"] != barco:
		return false
	return absf(barco.to_local(h["position"]).y - _y_do_convez) <= TOLERANCIA


func _virar(dir_local: Vector3, delta: float) -> void:
	if dono.has_method("virar_para"):
		# O humano gira só o corpo (o `Corpo` olha −Z).
		dono.call("virar_para", barco.global_basis * dir_local, 1.0 - exp(-GIRO * delta))
	else:
		dono.rotation.y = lerp_angle(dono.rotation.y, atan2(-dir_local.x, -dir_local.z), 1.0 - exp(-GIRO * delta))


## Diz ao corpo a que ritmo anda: o rig/clipes do humano e a pata do caranguejo seguem.
func _andar_a(v: float) -> void:
	if dono.has_method("definir_velocidade"):
		dono.call("definir_velocidade", v)
	elif dono.get("animador") != null and dono.get("visual") != null and dono.animador.has_method("animar"):
		var local := Vector3(0, 0, -v)
		dono.animador.animar(get_physics_process_delta_time(), local, true, 0.0)
