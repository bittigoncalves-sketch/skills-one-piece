extends Node3D
## Vida em golpes, independente do nível/dano; relógio de jogo respeita pausa.
signal colhida(quantidade: int)
signal regenerou
const REGENERACAO := 600.0
const MADEIRA_ARVORE := Vector2i(5, 7)
const MADEIRA_ARBUSTO := 1
const CAMADA_COLETA := 1 << 21
var corpo: StaticBody3D
var vida := 3
var vida_maxima := 3
var derrubada := false
var restante := 0.0
var arbusto := false
var _modelo: Node3D
var _original := Transform3D.IDENTITY
var _camada := 0
var _mascara := 0
var _sensor: StaticBody3D
var _barra: Node3D
var _preenchimento: MeshInstance3D
var _texto: Label3D
var _tween: Tween
var _ultimo_golpe := {}
var _tempo_barra := 0.0
var _pe := Vector3.ZERO
var _altura := 0.0

func preparar(alvo: StaticBody3D, p: Dictionary, pequeno: bool) -> void:
	add_to_group("vegetacao_coletavel")
	corpo = alvo
	arbusto = pequeno
	vida_maxima = 1 if arbusto else 3
	vida = vida_maxima
	_modelo = corpo.get_node("Modelo") as Node3D
	_original = _modelo.transform
	_camada = corpo.collision_layer
	_mascara = corpo.collision_mask
	_pe = Vector3(0, -p.tamanho.y * .5, 0)
	corpo.set_meta("vegetacao_coletavel", self)
	# Arbustos atravessáveis continuam atravessáveis, com sensor só do machado.
	if arbusto or corpo.get_node_or_null("Colisao") == null:
		_sensor = StaticBody3D.new()
		_sensor.collision_layer = CAMADA_COLETA
		_sensor.collision_mask = 0
		_sensor.set_meta("vegetacao_coletavel", self)
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = p.tamanho if arbusto else Vector3(.6, p.tamanho.y, .6)
		forma.shape = caixa
		_sensor.add_child(forma)
		add_child(_sensor)
	_altura = p.tamanho.y
	set_process(false)

func receber_machadada(jogador: Player, acao: int) -> bool:
	if not multiplayer.is_server() or derrubada or not is_instance_valid(jogador): return false
	var arma := jogador.get_node_or_null("MachadoDaHistoria")
	var ex := jogador.combate_direcional
	if arma == null or not arma.ativa or ex.estilo.id != &"machado" or ex.estado != ExecutorCorpoACorpo.Estado.ATIVO or ex.id_acao != acao:
		return false
	var id := jogador.get_instance_id()
	if _ultimo_golpe.get(id, -1) == acao: return false
	_ultimo_golpe[id] = acao
	vida -= 1
	if _barra == null: _montar_barra(_altura)
	_atualizar_barra()
	_tempo_barra = 4.0
	set_process(true)
	if _tween != null: _tween.kill()
	_modelo.transform = _original
	_tween = create_tween()
	if vida == 0:
		derrubada = true
		restante = REGENERACAO
		corpo.set_deferred("collision_layer", 0)
		corpo.set_deferred("collision_mask", 0)
		if _sensor != null: _sensor.set_deferred("collision_layer", 0)
		var direcao := corpo.global_position - jogador.global_position
		direcao.y = 0
		var eixo := corpo.global_basis.inverse() * Vector3.UP.cross(direcao.normalized())
		if eixo.length_squared() < .01: eixo = Vector3.RIGHT
		_tween.tween_method(_inclinar.bind(eixo.normalized()), 0.0, 1.45, .75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.tween_callback(func(): _modelo.visible = false)
		colhida.emit(MADEIRA_ARBUSTO if arbusto else randi_range(MADEIRA_ARVORE.x, MADEIRA_ARVORE.y))
	else:
		_tween.tween_property(_modelo, "rotation:z", _modelo.rotation.z + .025, .07)
		_tween.tween_property(_modelo, "transform", _original, .22)
	return true

func _inclinar(angulo: float, eixo: Vector3) -> void:
	var giro := Basis(eixo, angulo)
	_modelo.transform = Transform3D(giro * _original.basis, _pe + giro * (_original.origin - _pe))

func _process(delta: float) -> void:
	_tempo_barra = maxf(0.0, _tempo_barra - delta)
	_barra.visible = _tempo_barra > 0.0
	if derrubada:
		restante = maxf(0.0, restante - delta)
		if restante == 0.0: regenerar()
	elif _tempo_barra == 0.0:
		set_process(false)

func regenerar() -> void:
	if not derrubada: return
	if _tween != null: _tween.kill()
	_modelo.transform = _original
	_modelo.visible = true
	corpo.set_deferred("collision_layer", _camada)
	corpo.set_deferred("collision_mask", _mascara)
	if _sensor != null: _sensor.set_deferred("collision_layer", CAMADA_COLETA)
	vida = vida_maxima
	derrubada = false
	restante = 0.0
	_ultimo_golpe.clear()
	_atualizar_barra()
	_barra.visible = false
	set_process(false)
	regenerou.emit()

func altura_do_marcador() -> float:
	return _pe.y + (1.3 if arbusto else minf(_altura, 2.6))

func _montar_barra(_altura_do_modelo: float) -> void:
	_barra = Node3D.new()
	_barra.name = "VidaVegetacao"
	_barra.position.y = altura_do_marcador()
	add_child(_barra)
	for frente in [false, true]:
		var malha := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1.05 if frente else 1.12, .09 if frente else .16)
		malha.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_color = Color("78d790") if frente else Color("192c31")
		mat.render_priority = 1 if frente else 0
		malha.material_override = mat
		malha.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_barra.add_child(malha)
		if frente: _preenchimento = malha
	_texto = Label3D.new()
	_texto.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_texto.no_depth_test = true
	_texto.font_size = 44
	_texto.pixel_size = .006
	_texto.position.y = .22
	_barra.add_child(_texto)
	_atualizar_barra()
	_barra.visible = false

func _atualizar_barra() -> void:
	# Tamanho do QuadMesh (em vez de scale) mantém a proporção no billboard.
	(_preenchimento.mesh as QuadMesh).size.x = maxf(.001, 1.05 * float(vida) / vida_maxima)
	_preenchimento.visible = vida > 0
	_texto.text = "%s · %d/%d" % ["Arbusto" if arbusto else "Árvore", vida, vida_maxima]
