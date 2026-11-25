extends RefCounted
# ============================================================================
#  ESCALADA FRONTAL — fatia 3 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md (03/10/2026).
#
#  Pedido do dono (referência Mirror's Edge Catalyst + Assassin's Creed Unity):
#    "Corrida → salto → contato com parede → agarrar → escalar"; funciona como
#    uma ESCADA, com mãos e pés no cenário; no topo "agarrar borda → subir →
#    continuar correndo"; "Não deve existir teleporte para cima"; nem toda parede
#    escala — o mapa diz quais (campo `escalavel` da loja, meta no corpo da peça).
#
#  ESTADOS
#    "escalando"   colado na parede: W/S sobe/desce, A/D anda de lado (escada).
#    "borda"       as mãos chegaram ao topo: pendurado na borda. W sobe a borda.
#    "subindo"     subir a borda — TRAJETÓRIA, nunca teleporte: primeiro sobe rente
#                  à parede até os pés passarem do topo, depois avança por cima dele.
#                  Sai com velocidade para a frente, para a corrida continuar.
#  Espaço salta para trás (para longe da parede); Ctrl solta; S no chão solta.
#
#  ENTRADA: no ar, indo de FRENTE contra parede escalável (≤ 50° da normal),
#  agarra sozinho — sem tecla (decisão do dono, controles estilo Mirror's Edge).
#
#  Mesmo molde dos outros componentes: recebe e devolve a velocidade.
# ============================================================================

const SOBE := 2.2
const DESCE := 2.8
const LADO := 1.6
## Pressão contra a parede (m/s): mantém o contato entre quadros.
const ADERENCIA := 1.0
## Sonda à frente, a partir do centro do corpo.
const ALCANCE := 0.75
const ALTURA_PEITO := 0.3
const ALTURA_PES := -0.55
## Altura das mãos acima do centro do corpo, pendurado.
const ALTURA_MAOS := 0.85
## Indo de frente: o ângulo entre a direção e a normal (invertida) até 50°.
const COS_ENTRADA := 0.64
## Queda rápida demais não agarra (m/s).
const QUEDA_MAX := 14.0
## Depois de soltar/saltar, não reagarra por este tempo.
const CARENCIA := 0.35
## Saltar para trás.
const SALTO_FORA := 6.0
const SALTO_CIMA := 9.0
## Subir a borda: velocidade de subida, de avanço e o quanto avança.
const SUBIDA_BORDA := 3.6
const AVANCO_BORDA := 3.0
## 0,9 m: o centro do corpo termina ~0,4 m para dentro do topo (com 0,7 ficava a
## 0,2 m, metade da cápsula sobre a quina — medido 03/10).
const AVANCO_DIST := 0.9
## Do centro do corpo aos pés (cápsula do jogador ~0,81 m) + folga.
const CENTRO_AOS_PES := 0.85

var ativo := false
var estado := ""
## Normal da parede (aponta para FORA dela).
var normal := Vector3.ZERO
## Altura (mundo) do topo da borda, quando conhecida.
var topo_y := 0.0
## 0..1 dentro de "subindo" (a animação usa).
var progresso_subida := 0.0

var _carencia := 0.0
var _dist_face := 0.45           # do centro do corpo à face da parede (medido)
var _avancou := 0.0
var _subida_total := 0.0


func passar_tempo(delta: float) -> void:
	_carencia = maxf(_carencia - delta, 0.0)


## No ar, indo contra uma parede escalável: agarra. Devolve true se agarrou.
func tentar_agarrar(corpo: CharacterBody3D, vel: Vector3, desejo: Vector3) -> bool:
	if ativo or _carencia > 0.0 or vel.y < -QUEDA_MAX:
		return false
	var plano := Vector3(vel.x, 0.0, vel.z)
	var dir := plano.normalized() if plano.length() > 1.5 else Vector3(desejo.x, 0.0, desejo.z).normalized()
	if dir == Vector3.ZERO:
		return false
	var h := _raio(corpo, ALTURA_PEITO, dir, ALCANCE)
	if h.is_empty() or not escalavel(h["collider"]):
		return false
	var n: Vector3 = h["normal"]
	if -dir.dot(n) < COS_ENTRADA:
		return false
	ativo = true
	estado = "escalando"
	normal = Vector3(n.x, 0.0, n.z).normalized()
	_dist_face = _distancia_da_face(corpo, h)
	progresso_subida = 0.0
	return true


## `q`: o MoveFrame do quadro. Devolve a velocidade.
func atualizar(delta: float, corpo: CharacterBody3D, q: MoveFrame, vel: Vector3) -> Vector3:
	if not ativo:
		return vel
	if estado == "subindo":
		return _subir_borda(delta, corpo)
	if q.espaco_agora:
		var saida := normal * SALTO_FORA + Vector3.UP * SALTO_CIMA
		_soltar()
		return saida
	if q.soltar_agora:
		_soltar()
		return normal * 1.0
	var direita := (-normal).cross(Vector3.UP).normalized()

	# A parede continua à frente do peito? Segue a normal nova (parede curva).
	var peito := _raio(corpo, ALTURA_PEITO, -normal, ALCANCE + 0.2)
	if not peito.is_empty() and escalavel(peito["collider"]):
		var n: Vector3 = peito["normal"]
		normal = Vector3(n.x, 0.0, n.z).normalized()
		_dist_face = _distancia_da_face(corpo, peito)

	# O topo: acima das mãos não há mais parede e há chão logo atrás da face.
	var topo := _achar_topo(corpo)
	var nas_maos := topo != INF and topo - corpo.global_position.y <= ALTURA_MAOS + 0.05
	if nas_maos:
		topo_y = topo
		estado = "borda"
	elif peito.is_empty():
		_soltar()                           # a parede acabou (de lado ou embaixo)
		return vel
	else:
		estado = "escalando"

	var sobe := clampf(q.f, -1.0, 1.0)
	var lado := clampf(q.r, -1.0, 1.0)
	if estado == "borda":
		if sobe > 0.1:
			estado = "subindo"
			_avancou = 0.0
			_subida_total = maxf(topo_y + CENTRO_AOS_PES - corpo.global_position.y, 0.01)
			progresso_subida = 0.0
			return _subir_borda(delta, corpo)
		sobe = minf(sobe, 0.0)              # pendurado: não passa da borda
		# Mãos presas na borda: o corpo fica na altura em que elas alcançam o topo.
		var alvo_y := topo_y - ALTURA_MAOS
		var vy := clampf((alvo_y - corpo.global_position.y) / maxf(delta, 0.001), -2.0, 2.0)
		if sobe < -0.1:
			vy = -DESCE
			estado = "escalando"
		# De lado, na borda, só se ela continua para aquele lado.
		var vl := lado * LADO if absf(lado) > 0.1 and _ha_parede_ao_lado(corpo, direita * signf(lado)) else 0.0
		return direita * vl - normal * ADERENCIA + Vector3.UP * vy

	if sobe < -0.1 and corpo.is_on_floor():
		_soltar()                           # desceu até o chão
		return Vector3.ZERO
	var v_vert := (SOBE if sobe > 0.0 else DESCE) * sobe
	var v_lado := 0.0
	if absf(lado) > 0.1 and _ha_parede_ao_lado(corpo, direita * signf(lado)):
		v_lado = lado * LADO
	return direita * v_lado - normal * ADERENCIA + Vector3.UP * v_vert


## Larga sem impulso (arremesso, morte, outro sistema tomou o corpo).
func cancelar() -> void:
	if ativo:
		_soltar()


## Uma peça é escalável quando o corpo dela (ou o pai) tem a meta `escalavel`
## (o MapaMontador põe a partir da loja).
static func escalavel(colisor: Object) -> bool:
	var n := colisor as Node
	for i in 3:
		if n == null:
			return false
		if n.has_meta("escalavel"):
			return bool(n.get_meta("escalavel"))
		n = n.get_parent()
	return false


func _soltar() -> void:
	ativo = false
	estado = ""
	progresso_subida = 0.0
	_carencia = CARENCIA


## Subir a borda sem teleporte: sobe rente à parede até os pés passarem do topo,
## depois avança por cima. Termina com velocidade para a frente.
func _subir_borda(delta: float, corpo: CharacterBody3D) -> Vector3:
	var frente := -normal
	var falta := topo_y + CENTRO_AOS_PES - corpo.global_position.y
	if falta > 0.0 and _avancou <= 0.0:
		progresso_subida = clampf(1.0 - falta / _subida_total, 0.0, 1.0) * 0.7
		return Vector3.UP * minf(SUBIDA_BORDA, falta / maxf(delta, 0.001) + 0.5)
	_avancou += AVANCO_BORDA * delta
	progresso_subida = 0.7 + 0.3 * clampf(_avancou / AVANCO_DIST, 0.0, 1.0)
	if _avancou >= AVANCO_DIST:
		_soltar()
		_carencia = CARENCIA
		return frente * AVANCO_BORDA
	return frente * AVANCO_BORDA + Vector3.DOWN * 0.5


## Altura do topo logo atrás da face da parede, ou INF se não há topo ao alcance
## das mãos (+0,5 m de folga).
func _achar_topo(corpo: CharacterBody3D) -> float:
	var espaco := corpo.get_world_3d().direct_space_state
	# Logo atrás da face (0,15 m): parede fina também tem topo.
	var base := corpo.global_position - normal * (_dist_face + 0.15)
	var de := base + Vector3.UP * (ALTURA_MAOS + 0.5)
	# A cabeça precisa estar livre: se há parede na altura de cima, não é topo.
	var alto := _raio(corpo, ALTURA_MAOS + 0.5, -normal, ALCANCE + 0.2)
	if not alto.is_empty():
		return INF
	var par := PhysicsRayQueryParameters3D.create(de, base + Vector3.UP * (ALTURA_PEITO - 0.2))
	par.exclude = [corpo.get_rid()]
	var h := espaco.intersect_ray(par)
	if h.is_empty() or (h["normal"] as Vector3).y < 0.7:
		return INF
	return (h["position"] as Vector3).y


func _distancia_da_face(corpo: CharacterBody3D, acerto: Dictionary) -> float:
	var d := ((acerto["position"] as Vector3) - corpo.global_position)
	return maxf(Vector3(d.x, 0.0, d.z).length(), 0.1)


func _ha_parede_ao_lado(corpo: CharacterBody3D, lado: Vector3) -> bool:
	var espaco := corpo.get_world_3d().direct_space_state
	var de := corpo.global_position + Vector3.UP * ALTURA_PEITO + lado * 0.45
	var par := PhysicsRayQueryParameters3D.create(de, de - normal * (ALCANCE + 0.2))
	par.exclude = [corpo.get_rid()]
	var h := espaco.intersect_ray(par)
	return not h.is_empty() and escalavel(h["collider"])


func _raio(corpo: CharacterBody3D, altura: float, direcao: Vector3, alcance: float) -> Dictionary:
	var espaco := corpo.get_world_3d().direct_space_state
	var de := corpo.global_position + Vector3.UP * altura
	var par := PhysicsRayQueryParameters3D.create(de, de + direcao * alcance)
	par.exclude = [corpo.get_rid()]
	var h := espaco.intersect_ray(par)
	if h.is_empty() or absf((h["normal"] as Vector3).y) >= 0.3 or h["collider"] is CharacterBody3D:
		return {}
	return h
