extends Node
## História offline. Usa a etapa exclusiva de montaria do Player e sua colisão real.
const VISUAL := preload("res://src/historia/equipamentos/bicicleta_de_gelo_visual.gd")
const VELOCIDADE := 10.0
const VELOCIDADE_RAPIDA := 15.0
const ACELERACAO := 12.0
const ALTURA_CENTRO := .8
const IMPULSO_PULO := 8.0
const DURACAO_GIRO := .48
var jogador: Player
var visual: Node3D
var _volume: CollisionShape3D
var piloto := Callable()
var _quadro := MoveFrame.new()
var _fase := 0.0
var _modelo_posicao := Vector3.ZERO
var _ik := AplicadorDePose.new()
var _distancia_rastro := 0.0
var _trilha: Array[Dictionary] = []
var pulos := 0
var giro := 0.0
var _tempo_giro := -1.0
var _rumo := 0.0
var _empinada := 0.0
var _inclinacao := 0.0
var _modelo_rotacao := Vector3.ZERO

func _ready() -> void:
	jogador = get_parent() as Player

func ativa() -> bool:
	return is_instance_valid(jogador) and jogador.montaria == self

func disponivel() -> bool:
	if not is_instance_valid(jogador) or jogador.current_fruit_id != "hie_hie" or not jogador.capacidades.can_use_fruit or jogador.is_suppressed: return false
	var modo := get_tree().current_scene
	return modo != null and modo.get("progressao") != null and modo.progressao.item_em_uso() == "fruta"

func alternar() -> bool:
	if ativa(): return desmontar()
	if not disponivel() or not jogador.is_multiplayer_authority(): return false
	if not jogador.corpo_livre_para_golpe() or jogador.esta_atacando() or jogador._voo.ativo() or jogador._dash.ativo(): return false
	var agua := AguaDoMundo.nivel_em(jogador.global_position.x, jogador.global_position.z)
	# Não materializa em queda, mergulho ou dentro de outra montaria.
	if not jogador.is_on_floor() and (is_nan(agua) or absf(jogador.global_position.y - agua - ALTURA_CENTRO) > .45): return false
	# Espaço do veículo e do ciclista: impede criar rodas dentro de uma parede.
	var forma := BoxShape3D.new()
	forma.size = Vector3(.8,2.0,2.5)
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform = Transform3D(Basis(Vector3.UP, jogador.modelo_visual().rotation.y), jogador.global_position + Vector3.UP*.24)
	consulta.collision_mask = jogador.collision_mask
	consulta.exclude = [jogador.get_rid()]
	if not jogador.get_world_3d().direct_space_state.intersect_shape(consulta,1).is_empty(): return false
	_volume = CollisionShape3D.new()
	_volume.name = "VolumeBicicleta"
	_volume.shape = forma
	jogador.add_child(_volume)
	_volume.position.y = .24
	_volume.rotation.y = jogador.modelo_visual().rotation.y
	jogador.combate_direcional.cancelar(&"bicicleta")
	_modelo_posicao = jogador.modelo_visual().position
	_modelo_rotacao = jogador.modelo_visual().rotation
	_ik.montar(jogador.modelo_visual())
	jogador.montaria = self
	jogador.set_meta("montado", true)
	jogador.set_meta("bicicleta_gelo", true)
	visual = VISUAL.new()
	jogador.add_child(visual)
	visual.position.y = -ALTURA_CENTRO
	visual.rotation.y = jogador.modelo_visual().rotation.y
	_rumo = visual.rotation.y
	pulos = 0
	giro = 0.0
	_tempo_giro = -1.0
	_empinada = 0.0
	_inclinacao = 0.0
	_fase = 0.0
	_quadro = MoveFrame.new()
	return true

func atualizar(delta: float) -> bool:
	if not ativa(): return false
	var atordoado: bool = jogador._fsm != null and jogador._fsm.state != null and jogador._fsm.state.name == "Stunned"
	if not disponivel() or jogador.health <= 0 or jogador._eliminado or jogador._arremesso.ativo() or atordoado or jogador.get_meta("is_frozen", false) or jogador.esta_capturado_pelo_vento():
		desmontar(true)
		return false
	var hud := get_tree().get_first_node_in_group("hud")
	var livre: bool = hud == null or not hud.is_menu_open()
	_quadro.ler(jogador._yaw, livre)
	var comando: Dictionary = piloto.call(delta) if piloto.is_valid() else {
		"dir": _quadro.dir, "correr": _quadro.sprint, "pular": _quadro.espaco_agora,
		"empinar": Input.is_physical_key_pressed(KEY_CTRL)}
	conduzir(comando.get("dir", Vector3.ZERO) if livre else Vector3.ZERO,
		livre and comando.get("correr", false), delta,
		livre and comando.get("pular", false), livre and comando.get("empinar", false))
	return true

func conduzir(direcao: Vector3, correr: bool, delta: float, pular := false, empinar := false) -> void:
	if delta <= 0.0: return
	var inicio := jogador.global_position
	var agua := AguaDoMundo.nivel_em(inicio.x, inicio.z)
	var apoiada := jogador.is_on_floor() or (not is_nan(agua)
		and absf(inicio.y - agua - ALTURA_CENTRO) < .08 and jogador.velocity.y <= .1)
	if apoiada:
		pulos = 0
	if pular and (apoiada or pulos < 2):
		# Sair de uma borda consome o primeiro salto; resta só o aéreo.
		pulos = 1 if apoiada else 2
		jogador.velocity.y = IMPULSO_PULO
		if pulos == 2: _tempo_giro = 0.0
	var alvo := Vector3(direcao.x,0,direcao.z).limit_length() * (VELOCIDADE_RAPIDA if correr else VELOCIDADE) * Lentidao.fator(jogador)
	jogador.velocity.x = move_toward(jogador.velocity.x, alvo.x, ACELERACAO*delta)
	jogador.velocity.z = move_toward(jogador.velocity.z, alvo.z, ACELERACAO*delta)
	jogador.velocity.y = maxf(-25, jogador.velocity.y - jogador.GRAVITY*delta)
	if not is_nan(agua) and inicio.y >= agua + ALTURA_CENTRO - .2 and inicio.y + jogador.velocity.y*delta <= agua + ALTURA_CENTRO:
		jogador.velocity.y = (agua + ALTURA_CENTRO - inicio.y) / delta
	jogador.move_and_slide()
	var real := (jogador.global_position - inicio) / delta
	var distancia := Vector2(real.x, real.z).length() * delta
	var rumo_antes := _rumo
	if distancia > .001:
		_rumo = lerp_angle(_rumo, atan2(-real.x,-real.z), 1-exp(-10*delta))
	# O giro é visual: não vira a direção do impulso nem roda o colisor na parede.
	if _tempo_giro >= 0.0:
		_tempo_giro = minf(_tempo_giro + delta, DURACAO_GIRO)
		var t := _tempo_giro / DURACAO_GIRO
		giro = TAU * smoothstep(0.0, 1.0, t)
		if t >= 1.0: _tempo_giro = -1.0
	else:
		giro = 0.0
	var peso := 1.0 - exp(-9.0 * delta)
	_empinada = lerpf(_empinada, .48 if empinar and apoiada and distancia > .01 else 0.0, peso)
	var curva := clampf(angle_difference(rumo_antes, _rumo) / delta * .13, -.28, .28)
	_inclinacao = lerpf(_inclinacao, curva if apoiada else 0.0, peso)
	visual.rotation = Vector3(_empinada, _rumo + giro, _inclinacao)
	# Pivotar na roda traseira mantém o pneu apoiado durante a empinada.
	var apoio := Vector3(0, .46, .78)
	visual.position = Vector3(0, -ALTURA_CENTRO, 0) + Basis(Vector3.UP, _rumo + giro) * apoio - visual.basis * apoio
	jogador.modelo_visual().rotation = visual.rotation
	_volume.rotation.y = _rumo
	_fase += distancia * 2.2
	jogador.set_meta("bicicleta_fase", _fase)
	jogador._proc_anim.update(real, true, false, delta, 0.0)
	visual.animar(distancia, _fase)
	_encaixar_ciclista(delta)
	_distancia_rastro += distancia
	if _distancia_rastro >= .65:
		_distancia_rastro = 0
		_deixar_gelo()
	HurtboxDeCombate.sincronizar(jogador)

func _encaixar_ciclista(delta: float) -> void:
	var modelo := jogador.modelo_visual()
	var quadril := _ik.no("Torso")
	if quadril == null: return
	# O quadril assenta no selim; os alvos pertencem ao veículo, sem escala do rig.
	modelo.global_position += visual.to_global(Vector3(0,1.18,.28)) - quadril.global_position
	var pose := {"rot": {"Foot_R": Vector3.ZERO, "Foot_L": Vector3.ZERO}, "quadril": Vector3.ZERO}
	for lado: String in ["L", "R"]:
		var sinal := -1.0 if lado == "L" else 1.0
		pose["mao_"+lado] = _ik.para_corpo(visual.to_global(Vector3(sinal*.35,1.30,-.47)))
		pose["cotovelo_"+lado] = Vector3(sinal,-.4,.1)
		var pedal: Vector3 = visual.pedais.to_global(Vector3(sinal*.24,sinal*.16,0))
		pose["pe_"+lado] = _ik.para_corpo(pedal + Vector3.UP*.10)
		pose["joelho_"+lado] = Vector3(sinal*.15,0,-1)
	_ik.aplicar(pose, 1.0, 1.0, null, delta, false)
	if jogador._proc_anim._driver != null: jogador._proc_anim._driver.push()

func _deixar_gelo() -> void:
	var pe := jogador.global_position - Vector3.UP * ALTURA_CENTRO
	var agua := AguaDoMundo.nivel_em(pe.x, pe.z)
	if not jogador.is_on_floor() and (is_nan(agua) or absf(pe.y-agua) > .2): return
	var gelo := MeshInstance3D.new()
	var placa := CylinderMesh.new()
	placa.top_radius = .67
	placa.bottom_radius = .62
	placa.height = .04
	placa.radial_segments = 10
	gelo.mesh = placa
	gelo.material_override = visual.gelo
	jogador.get_parent().add_child(gelo)
	gelo.global_position = pe + Vector3.UP * .025
	gelo.scale.x = .65
	gelo.rotation.y = visual.rotation.y
	_trilha.append({"no": gelo, "vida": 2.5})

func _process(delta: float) -> void:
	for i in range(_trilha.size()-1,-1,-1):
		_trilha[i].vida -= delta
		var no: Node3D = _trilha[i].no
		if not is_instance_valid(no) or _trilha[i].vida <= 0:
			if is_instance_valid(no): no.queue_free()
			_trilha.remove_at(i)
		else:
			no.scale.y = minf(1.0, _trilha[i].vida)

func desmontar(_forcar := false, _preservar_posicao := false) -> bool:
	if not ativa(): return false
	jogador.modelo_visual().position = _modelo_posicao
	jogador.modelo_visual().rotation = Vector3(_modelo_rotacao.x, _rumo, _modelo_rotacao.z)
	pulos = 0
	giro = 0.0
	_tempo_giro = -1.0
	jogador.montaria = null
	jogador.set_meta("montado", false)
	jogador.remove_meta("bicicleta_gelo")
	jogador.remove_meta("bicicleta_fase")
	if is_instance_valid(_volume):
		jogador.remove_child(_volume)
		_volume.queue_free()
	_volume = null
	if is_instance_valid(visual): visual.queue_free()
	visual = null
	return true

func liberar_para_captura() -> bool:
	return desmontar(true)

func dica() -> String:
	return "Espaço · Pulo / pulo duplo 360°   Ctrl · Empinar   Shift · Acelerar   F · Desmontar" if ativa() else "F · Bicicleta de gelo"

func _exit_tree() -> void:
	desmontar(true)
	for parte in _trilha:
		if is_instance_valid(parte.no): parte.no.queue_free()
	_trilha.clear()
