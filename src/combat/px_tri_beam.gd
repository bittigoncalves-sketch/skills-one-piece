class_name PXTriBeam
extends Node3D
## Ultimate do Pacifista: os emissores da boca e das duas palmas convergem no
## ponto mirado. Os tres canhoes sao canonicos; a salva simultanea e uma
## adaptacao de gameplay para o slot V.

const TEMPO_CARGA := 0.65
const DURACAO_FEIXE := 0.42
const DURACAO_RESOLUCAO := 0.38
const ALCANCE := 26.0
# O maior elemento visivel (anel) chega a ~3,4 m. A hitbox antiga tinha 4,5 m e
# acertava mais de um metro alem do telegraph aprovado.
const RAIO_EXPLOSAO := 3.4
const COR_LASER := Color(1.0, 0.86, 0.06, 0.96)
const COR_NUCLEO := Color(1.0, 0.98, 0.58, 1.0)

var _caster: Node3D
var _aim := Vector3.FORWARD
var _origem_mira := Vector3.ZERO
var _dano := 0.0
var _spec = null
var _tempo := 0.0
var _disparou := false
var _ultimo_impacto := Vector3.ZERO
var _emissores: Array[Node3D] = []
var _cargas: Array[MeshInstance3D] = []
var _guias: Array[MeshInstance3D] = []
var _feixes: Array[MeshInstance3D] = []
var _halos: Array[MeshInstance3D] = []
var _alvo := Vector3.ZERO
var _ocultou_feixes := false
var _cast_token := 0
var _estado_finalizado := false


static func criar(mundo: Node, caster: Node3D, origem_mira: Vector3, aim: Vector3,
		dano: float, spec = null, cast_token: int = 0) -> PXTriBeam:
	var no := PXTriBeam.new()
	no._caster = caster
	no._origem_mira = origem_mira
	no._aim = aim.normalized()
	no._dano = dano
	no._spec = spec
	no._cast_token = cast_token
	mundo.add_child(no)
	# O cast pode nascer durante o flush da fisica (RPC local). Esperar a entrada
	# completa na arvore evita consultar global_transform de filhos ainda soltos.
	no.call_deferred("_preparar")
	return no


func _preparar() -> void:
	_emissores = [_achar("Head"), _achar("ForeArm_L"), _achar("ForeArm_R")]
	_alvo = _ponto_de_impacto()
	for i in 3:
		var orb := MeshInstance3D.new()
		var esfera := SphereMesh.new()
		esfera.radius = 0.15
		esfera.height = 0.30
		orb.mesh = esfera
		var material_carga := FxUtil.mesh_emissive_material(COR_LASER, 5.0, true)
		# Boca e palma esquerda ficam parcialmente atrás do corpo na câmera TPS.
		# A carga é informação de antecipação, então deve continuar legível mesmo
		# quando o próprio personagem ocluir o emissor por alguns pixels.
		material_carga.no_depth_test = true
		orb.material_override = material_carga
		add_child(orb)
		_cargas.append(orb)
		var guia := BeamVisual3D.criar(self, Vector3.ZERO, Vector3.ZERO, 0.032,
			Color(1.0, 0.82, 0.08, 0.42), 3.0, true)
		var material_guia := guia.material_override as StandardMaterial3D
		if material_guia != null:
			material_guia.no_depth_test = true
		guia.visible = false
		_guias.append(guia)
	_atualizar_cargas(0.0)


func _achar(nome: String) -> Node3D:
	var encontrado := _caster.find_child(nome, true, false)
	return encontrado as Node3D if encontrado is Node3D else null


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_caster):
		queue_free()
		return
	if _cargas.is_empty():
		return
	if not _disparou:
		if (_cast_token > 0 and int(_caster.get_meta("px_token_V", 0)) != _cast_token) \
				or bool(_caster.get_meta("px_tri_beam_cancelado", false)) \
				or not bool(_caster.get_meta("px_tri_beam_ativo", false)):
			_finalizar_estado()
			queue_free()
			return
	_tempo += delta
	if not _disparou:
		_atualizar_cargas(clampf(_tempo / TEMPO_CARGA, 0.0, 1.0))
		if _tempo >= TEMPO_CARGA:
			_disparar()
	elif not _ocultou_feixes and _tempo >= TEMPO_CARGA + DURACAO_FEIXE:
		_ocultou_feixes = true
		# O disparo ja aconteceu e agora e irrevogavel; aqui termina a janela de
		# compromisso do jogador. A resolucao visual continua por conta propria.
		_finalizar_estado()
		for feixe in _feixes:
			feixe.visible = false
		for halo in _halos:
			halo.visible = false
		for orb in _cargas:
			orb.visible = false
	elif _tempo >= TEMPO_CARGA + DURACAO_FEIXE + DURACAO_RESOLUCAO:
		_finalizar_estado()
		queue_free()


func _atualizar_cargas(progresso: float) -> void:
	var posicoes := _posicoes_dos_emissores()
	for i in _cargas.size():
		_cargas[i].global_position = posicoes[i]
		var pulso := 0.72 + progresso * 0.48 + sin(_tempo * 24.0 + i * 1.7) * 0.07
		_cargas[i].scale = Vector3.ONE * pulso
		# Nos 30% finais, linhas-guia tornam as três origens e a convergência
		# legíveis antes do clarão principal.
		if progresso >= 0.70:
			BeamVisual3D.atualizar(_guias[i], posicoes[i], _alvo, 0.026)
			_guias[i].visible = true
		else:
			_guias[i].visible = false


func _posicoes_dos_emissores() -> Array[Vector3]:
	return [_ponto_da_boca(), _ponto_da_mao("L"), _ponto_da_mao("R")]


func _ponto_da_boca() -> Vector3:
	if is_instance_valid(_emissores[0]):
		return _emissores[0].global_position + _aim * 0.22 + Vector3.DOWN * 0.08
	return _caster.global_position + Vector3.UP * 1.58 + _aim * 0.22


## A mão é a ponta do antebraço no -Y local do rig. Somar apenas `aim` ao pivô
## do ForeArm punha as três cargas no torso, como apareceu na gravação.
func _ponto_da_mao(lado: String) -> Vector3:
	var modelo = _caster.get("_char_model")
	if modelo is Node3D and (modelo as Node3D).is_inside_tree():
		var m3 := modelo as Node3D
		var ombro := m3.find_child("UpperArm_" + lado, true, false)
		var antebraco := m3.find_child("ForeArm_" + lado, true, false)
		if ombro is Node3D and antebraco is Node3D:
			var inv := m3.global_transform.affine_inverse()
			var p_ombro: Vector3 = inv * (ombro as Node3D).global_position
			var p_antebraco: Vector3 = inv * (antebraco as Node3D).global_position
			var comprimento := p_ombro.distance_to(p_antebraco)
			var dir_local := (inv.basis * (antebraco as Node3D).global_transform.basis
				* Vector3(0, -1, 0)).normalized()
			return m3.global_transform * (p_antebraco + dir_local * comprimento)
	var direita := _caster.global_transform.basis.x.normalized()
	var sinal := -1.0 if lado == "L" else 1.0
	return _caster.global_position + Vector3.UP * 1.12 + direita * sinal * 0.72 + _aim * 0.25


func _disparar() -> void:
	_disparou = true
	for orb in _cargas:
		# Mantém três bocas de fogo durante o disparo: sem estas âncoras os halos
		# convergentes podem ser lidos como um único feixe grosso.
		orb.scale = Vector3.ONE * 0.92
	for guia in _guias:
		guia.visible = false
	var fontes := _posicoes_dos_emissores()
	for fonte in fontes:
		_criar_feixe(fonte, _alvo)
	_criar_impacto(_alvo)


func _ponto_de_impacto() -> Vector3:
	# A direcao recebida foi calculada a partir da origem do cast. Refazer este
	# raio a partir da cabeca mudava a reta e, em mira baixa, acertava o piso
	# antes do alvo (visivel na gravacao: V entra em recarga mas o dano nao sobe).
	var fim := _origem_mira + _aim * ALCANCE
	var query := PhysicsRayQueryParameters3D.create(_origem_mira, fim)
	query.collide_with_areas = false
	if _caster is CollisionObject3D:
		query.exclude = [(_caster as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return fim if hit.is_empty() else hit.position


func _criar_feixe(de: Vector3, ate: Vector3) -> void:
	var halo := BeamVisual3D.criar(self, de, ate, 0.10,
		Color(1.0, 0.70, 0.01, 0.34), 4.0, true)
	var feixe := BeamVisual3D.criar(self, de, ate, 0.040, COR_NUCLEO, 5.5, true)
	feixe.set_meta("px_tri_beam", true)
	_halos.append(halo)
	_feixes.append(feixe)


func _criar_impacto(alvo: Vector3) -> void:
	_ultimo_impacto = alvo
	var zone := DamageZone.new()
	get_parent().add_child(zone)
	zone.global_position = alvo
	zone.setup(_dano, 34.0, Vector3.ZERO, 0.28, _caster, RAIO_EXPLOSAO, null, 0.55)
	zone.derruba = 0.8
	zone.exige_linha_de_visao = true
	# Recuar para o lado do atirador evita iniciar o raio numericamente dentro da
	# face da parede em que o laser explodiu.
	zone.origem_linha_de_visao = alvo - _aim * 0.08
	if _spec != null:
		_spec.marcar(zone)

	var impacto := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.52
	esfera.height = 1.04
	impacto.mesh = esfera
	impacto.material_override = FxUtil.mesh_emissive_material(COR_LASER, 6.0, true)
	add_child(impacto)
	impacto.global_position = alvo
	var nucleo := MeshInstance3D.new()
	var nucleo_mesh := SphereMesh.new()
	nucleo_mesh.radius = 0.24
	nucleo_mesh.height = 0.48
	nucleo.mesh = nucleo_mesh
	nucleo.material_override = FxUtil.mesh_emissive_material(COR_NUCLEO, 6.0, true)
	add_child(nucleo)
	nucleo.global_position = alvo
	var tw := create_tween()
	var duracao_impacto := DURACAO_FEIXE + DURACAO_RESOLUCAO
	tw.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(impacto, "scale", Vector3.ONE * RAIO_EXPLOSAO, duracao_impacto)
	tw.parallel().tween_property(impacto, "transparency", 1.0, duracao_impacto)
	var tw_core := create_tween()
	tw_core.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw_core.tween_property(nucleo, "scale", Vector3.ONE * 2.8, DURACAO_FEIXE)
	tw_core.tween_property(nucleo, "transparency", 1.0, DURACAO_RESOLUCAO)
	# Anel no chão/espaço dá paralaxe e volume à esfera unshaded, que sozinha
	# seria lida como um disco amarelo chapado.
	var anel := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.40
	torus.outer_radius = 0.52
	anel.mesh = torus
	anel.material_override = FxUtil.mesh_emissive_material(
		Color(1.0, 0.74, 0.03, 0.58), 4.0, true)
	add_child(anel)
	anel.global_position = alvo
	var tw_anel := create_tween()
	tw_anel.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw_anel.tween_property(anel, "scale", Vector3.ONE * (RAIO_EXPLOSAO * 1.45),
		duracao_impacto)
	tw_anel.parallel().tween_property(anel, "transparency", 1.0, duracao_impacto)


func _finalizar_estado() -> void:
	if _estado_finalizado:
		return
	_estado_finalizado = true
	if is_instance_valid(_caster) and _caster.has_method("finalizar_skill_pacifista"):
		_caster.finalizar_skill_pacifista("V", _cast_token)
