class_name LaserPX
extends Node3D
# ============================================================================
#  PX LASER BEAM — o Z do estilo Pacifista.
#
#  Pedido do dono (2026-09-01): "um laser que enquanto segurado no Z, ou 3
#  segundos não se passaram, causa dano constante no alvo. O laser atual está
#  na vertical e está bem ruim."
#
#  ------------------------------------------------------- POR QUE UM NÓ PRÓPRIO
#  O `_cast_laser` de FightingStyles nasce, empurra um cilindro e morre — não há
#  onde pendurar "enquanto segurado". Um feixe sustentado tem estado (quanto
#  falta, quando foi o último pulso) e precisa de um quadro para redesenhar. Um
#  nó autossuficiente é o mesmo caminho já usado pelo pilar do Hibashira, e evita
#  espalhar mais um relógio pelo Player, que já tem muitos.
#
#  ------------------------------------------------------- POR QUE FILHO DO CASTER
#  Sendo filho do jogador, o feixe herda o giro do corpo de graça: mirar para os
#  lados durante os 3 s funciona sem replicar nada, porque quem já é replicado é
#  o corpo. A inclinação (pitch) vem do `aim` do disparo, convertida para o
#  espaço LOCAL do caster — em espaço global ela brigaria com o giro do corpo.
#
#  ------------------------------------------------------- DANO CONSTANTE, TETO INTACTO
#  O feixe inteiro vale o dano declarado do slot Z (`Balance`), fatiado entre os
#  pulsos: segurar os 3 s entrega o total, soltar na metade entrega metade. Sem
#  isso o Pacifista teria um Z fora da escala de todos os outros estilos, e o
#  `test_balance` cairia — o teto por slot é dele, não deste arquivo.
#
#  ⚠️ A DamageZone só aplica dano no SERVIDOR (ver DamageZone). Este nó roda em
#  todos os peers porque o VFX é presentation; o dano continua autoritativo.
# ============================================================================

const DURACAO := 3.0        # teto pedido pelo dono: 3 s de feixe, nem que segure mais
const INTERVALO := 0.2      # 15 pulsos ao longo dos 3 s: contínuo ao olho, barato na rede
const ALCANCE := 18.0
const RAIO_DANO := 0.24     # levemente maior que o halo (0,187 m), tolerancia visivel e justa
const RAIO_FEIXE := 0.085
const COR_LASER := Color(1.0, 0.86, 0.08, 0.96)
const COR_NUCLEO := Color(1.0, 0.98, 0.58, 1.0)

var _caster: Node3D = null
var _dano_total: float = 0.0
var _spec = null
var _restante: float = DURACAO
var _ate_o_pulso: float = 0.0
var _pivo: Node3D = null
var _feixe: MeshInstance3D = null
var _halo: MeshInstance3D = null
var _impacto: MeshInstance3D = null
var _saida: MeshInstance3D = null
var _fluxos: Array[MeshInstance3D] = []
var _tempo_visual := 0.0
var _pulsos: int = int(DURACAO / INTERVALO)
var _cast_token: int = 0
var _estado_finalizado := false


static func criar(mundo: Node, caster: Node3D, origem_mira: Vector3, aim: Vector3,
		dano_total: float, spec = null, cast_token: int = 0) -> LaserPX:
	var no := LaserPX.new()
	no._caster = caster
	no._dano_total = dano_total
	no._spec = spec
	no._cast_token = cast_token
	caster.add_child(no)
	no._montar(origem_mira, aim)
	return no


func _montar(origem_mira: Vector3, aim: Vector3) -> void:
	position = Vector3.UP * 1.1
	_pivo = Node3D.new()
	add_child(_pivo)
	# A direção da mira foi calculada a partir de `origem_mira`, que fica 1,5 m à
	# frente do corpo. Aplicá-la sem correção a um feixe que nasce no peito cria
	# duas retas paralelas: o dano pode pegar, mas a imagem passa ao lado do alvo.
	# Primeiro recuperamos o ponto real visto pela câmera e só então ligamos o
	# peito a esse ponto.
	var ponto_alvo := origem_mira + aim.normalized() * ALCANCE
	var query := PhysicsRayQueryParameters3D.create(origem_mira, ponto_alvo)
	query.collide_with_areas = false
	if _caster is CollisionObject3D:
		query.exclude = [(_caster as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ponto_alvo = hit.position
	var dir_corrigida := (ponto_alvo - _pivo.global_position).normalized()
	# A direção corrigida vira local para continuar acompanhando o giro do corpo.
	var local: Vector3 = (_caster.global_transform.basis.inverse() * dir_corrigida).normalized()
	_pivo.basis = Basis.looking_at(local, _cima_para(local))

	# Duas camadas com material de MALHA, sem billboard. `BeamVisual3D` alinha o
	# eixo Y do cilindro diretamente a inicio -> fim; a GPU não gira nada depois.
	var inicio := _pivo.global_position
	var fim := inicio + _direcao() * ALCANCE
	_halo = BeamVisual3D.criar(self, inicio, fim, RAIO_FEIXE * 2.2,
		Color(1.0, 0.72, 0.02, 0.34), 4.0, true)
	_feixe = BeamVisual3D.criar(self, inicio, fim, RAIO_FEIXE, COR_NUCLEO, 5.0, true)
	_feixe.set_meta("px_laser_core", true)
	_impacto = MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = RAIO_FEIXE * 3.8
	esfera.height = RAIO_FEIXE * 7.6
	_impacto.mesh = esfera
	_impacto.material_override = FxUtil.mesh_emissive_material(COR_LASER, 6.0, true)
	add_child(_impacto)
	_saida = MeshInstance3D.new()
	_saida.mesh = esfera.duplicate()
	_saida.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 4.0, true)
	add_child(_saida)
	for i in 3:
		var pulso := MeshInstance3D.new()
		var grao := SphereMesh.new()
		grao.radius = RAIO_FEIXE * 1.45
		grao.height = RAIO_FEIXE * 2.9
		pulso.mesh = grao
		pulso.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 5.0, true)
		add_child(pulso)
		_fluxos.append(pulso)
	# O primeiro quadro ja respeita cobertura; antes havia um flash de 18 m
	# atravessando a parede ate o primeiro `_physics_process` corrigir o tamanho.
	_desenhar(_comprimento())


## UP alternativo quando a mira é quase vertical: `looking_at` com o UP paralelo
## à direção não tem solução e devolve a base identidade — que é exatamente o
## feixe em pé que o dono reclamou.
func _cima_para(dir: Vector3) -> Vector3:
	return Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD


func _desenhar(comp: float) -> void:
	var inicio := _pivo.global_position
	var dir := _direcao()
	var fim := inicio + dir * comp
	BeamVisual3D.atualizar(_halo, inicio, fim, RAIO_FEIXE * 2.2)
	BeamVisual3D.atualizar(_feixe, inicio, fim, RAIO_FEIXE)
	_saida.global_position = inicio
	_impacto.global_position = fim
	var respiracao := 0.88 + sin(_tempo_visual * 18.0) * 0.12
	_saida.scale = Vector3.ONE * respiracao
	_impacto.scale = Vector3.ONE * (1.0 + sin(_tempo_visual * 22.0) * 0.16)
	# Os pontos viajam jogador -> alvo e tornam a profundidade inequívoca mesmo
	# quando a câmera está exatamente atrás da linha do disparo.
	for i in _fluxos.size():
		var t := fposmod(_tempo_visual * 1.9 + float(i) / float(_fluxos.size()), 1.0)
		_fluxos[i].global_position = inicio.lerp(fim, t)
		_fluxos[i].scale = Vector3.ONE * (0.75 + sin(t * PI) * 0.55)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_caster):
		queue_free()
		return
	if _cast_token > 0 and int(_caster.get_meta("px_token_Z", 0)) != _cast_token:
		queue_free()
		return
	if bool(_caster.get_meta("px_laser_cancelado", false)) \
			or not bool(_caster.get_meta("px_laser_ativo", false)):
		_finalizar_estado()
		queue_free()
		return
	_restante -= delta
	_tempo_visual += delta
	if _restante <= 0.0:
		_caster.set_meta("px_laser_ativo", false)
		_finalizar_estado()
		queue_free()
		return

	var comp := _comprimento()
	_desenhar(comp)

	_ate_o_pulso -= delta
	if _ate_o_pulso <= 0.0:
		_ate_o_pulso = INTERVALO
		_pulsar(comp)


## Encurta o feixe até a primeira parede: sem isto ele atravessa o cenário e
## acerta quem está do outro lado.
func _comprimento() -> float:
	var espaco := get_world_3d().direct_space_state
	var de := _pivo.global_position
	var ate := de + _direcao() * ALCANCE
	var par := PhysicsRayQueryParameters3D.create(de, ate)
	par.exclude = [_caster.get_rid()]
	par.collide_with_areas = false
	var hit := espaco.intersect_ray(par)
	if hit.is_empty():
		return ALCANCE
	return de.distance_to(hit.position)


func _direcao() -> Vector3:
	return -_pivo.global_transform.basis.z


## Um pulso = uma DamageZone em forma de cápsula deitada sobre o feixe. A cápsula
## acerta TODOS no caminho, que é o que um laser faz; uma esfera na ponta
## deixaria passar quem estivesse no meio do trajeto.
func _pulsar(comp: float) -> void:
	if comp <= 0.025:
		return
	var zone := DamageZone.new()
	var mundo := _caster.get_parent()
	if mundo == null:
		return
	mundo.add_child(zone)

	var dir := _direcao()
	var meio := _pivo.global_position + dir * (comp * 0.5)
	zone.global_position = meio
	# CylinderShape nao possui as tampas que obrigavam a capsula a ultrapassar um
	# segmento curto junto da parede. O eixo Y usa a mesma base do visual.
	zone.global_basis = BeamVisual3D._base_com_y(dir)

	var forma := CylinderShape3D.new()
	forma.radius = RAIO_DANO
	forma.height = comp
	# Vida curta de propósito: quem dá a continuidade é a cadência dos pulsos, não
	# uma zona que fica no ar acumulando acertos.
	zone.setup(_dano_total / float(_pulsos), 4.0, Vector3.ZERO, 0.08, _caster, RAIO_DANO,
		forma, 0.12)
	if _spec != null:
		_spec.marcar(zone)


func _finalizar_estado() -> void:
	if _estado_finalizado:
		return
	_estado_finalizado = true
	if is_instance_valid(_caster) and _caster.has_method("finalizar_skill_pacifista"):
		_caster.finalizar_skill_pacifista("Z", _cast_token)
