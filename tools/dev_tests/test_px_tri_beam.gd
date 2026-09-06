extends SceneTree
## Regressao do V Pacifista: tres emissores convergem e uma unica explosao
## aplica o teto do slot no ponto mirado.

var _ok := 0
var _falhas := 0


func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 6000:
		await process_frame
	var p: Node3D
	for no in get_nodes_in_group("player"):
		if no.is_multiplayer_authority():
			p = no
			break
	if p == null:
		print("sem jogador")
		quit(1)
		return
	p.combat_mode = "style"
	p.current_style_idx = 1
	p.energy = p.max_energy
	p._skill_cooldowns["V"] = 0.0
	if p.get("_style_cooldowns") != null:
		p._style_cooldowns["V"] = 0.0

	var alvo: Node3D
	for no in get_nodes_in_group("enemy"):
		if no is Node3D and no.has_method("take_damage"):
			alvo = no
			break
	if alvo != null:
		alvo.set_physics_process(false)
		if alvo is CharacterBody3D:
			(alvo as CharacterBody3D).velocity = Vector3.ZERO
		var cam := p.get("_cam") as Camera3D
		var frente := (-cam.global_basis.z).normalized()
		var ate_jogador := maxf((p.global_position - cam.global_position).dot(frente), 0.0)
		alvo.global_position = cam.global_position + frente * (ate_jogador + 8.0)
		# Sincroniza a caixa no broadphase antes de calcular a mira usada pelo V.
		await physics_frame
		await physics_frame
		var query := PhysicsRayQueryParameters3D.create(cam.global_position,
			cam.global_position + frente * 150.0)
		query.exclude = [p.get_rid()]
		query.collide_with_areas = false
		var hit := p.get_world_3d().direct_space_state.intersect_ray(query)
		_checar("o raio da camera encontra o alvo preparado",
			not hit.is_empty() and hit.get("collider") == alvo)
	var vida0 := float(alvo.health) if alvo != null else 0.0

	p.begin_charge("V")
	p.release_charge("V")
	await _quadros(2)
	var ctrl := _achar_controle()
	_checar("V cria o controlador do Tri-Beam", ctrl != null)
	_checar("existem tres cargas, uma por emissor", ctrl != null and ctrl._cargas.size() == 3)
	if ctrl != null:
		var fontes: Array[Vector3] = ctrl._posicoes_dos_emissores()
		var separacao := minf(fontes[0].distance_to(fontes[1]), minf(
			fontes[0].distance_to(fontes[2]), fontes[1].distance_to(fontes[2])))
		print("separacao minima entre emissores: %.2f m" % separacao)
		_checar("boca e palmas sao tres origens separadas", separacao > 0.25)
		for carga in ctrl._cargas:
			var mat := carga.material_override as StandardMaterial3D
			_checar("carga amarela e sem billboard", mat != null
				and mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED
				and mat.albedo_color.g > mat.albedo_color.b * 1.4)
	await _quadros(35)
	ctrl = _achar_controle()
	var guias_visiveis := 0
	if ctrl != null:
		for guia in ctrl._guias:
			if guia.visible:
				guias_visiveis += 1
	_checar("fim da carga mostra tres guias de convergencia", guias_visiveis == 3)
	await _quadros(10)
	ctrl = _achar_controle()
	var feixes := 0
	if ctrl != null:
		for filho in ctrl.get_children():
			if filho.has_meta("px_tri_beam"):
				feixes += 1
	_checar("boca e duas palmas disparam tres feixes", feixes == 3)
	_checar("os tres feixes convergem no mesmo impacto", _convergem(ctrl))
	_checar("o disparo dura pelo menos dez quadros a 30 fps",
		float(PXTriBeam.DURACAO_FEIXE) * 30.0 >= 10.0)
	if ctrl != null:
		for feixe in ctrl._feixes:
			var mat := feixe.material_override as StandardMaterial3D
			_checar("feixe principal amarelo e sem billboard", mat != null
				and mat.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED
				and mat.albedo_color.g > mat.albedo_color.b * 1.4)
	if ctrl != null and alvo != null:
		var ponto_impacto: Vector3 = ctrl._ultimo_impacto
		var erro_impacto: float = ponto_impacto.distance_to(alvo.global_position)
		print("distancia impacto/alvo: %.2f" % erro_impacto)
		_checar("o impacto termina na superficie do alvo", erro_impacto < 1.0)
	_checar("a explosao causa dano no alvo mirado", alvo != null and float(alvo.health) < vida0)
	# Deixa a fase de resolução e a DamageZone encerrarem antes de desmontar a
	# SceneTree; sair com tweens vivos mascara vazamento real com aviso do motor.
	await _quadros(55)

	print("%d conferem | %d divergem" % [_ok, _falhas])
	quit(1 if _falhas else 0)


func _achar_controle() -> Node:
	for no in _todos_os_nos(get_root()):
		if no is PXTriBeam and not no.is_queued_for_deletion():
			return no
	return null


func _todos_os_nos(raiz: Node) -> Array:
	var fila: Array = [raiz]
	var saida: Array = []
	while not fila.is_empty():
		var no: Node = fila.pop_back()
		saida.append(no)
		for filho in no.get_children():
			fila.append(filho)
	return saida


func _convergem(ctrl: Node) -> bool:
	if ctrl == null:
		return false
	var pontas: Array[Vector3] = []
	for filho in ctrl.get_children():
		if filho.has_meta("px_tri_beam"):
			var eixo: Vector3 = filho.global_basis.y.normalized()
			var meia: float = (filho.mesh as CylinderMesh).height * 0.5
			var a: Vector3 = filho.global_position + eixo * meia
			var b: Vector3 = filho.global_position - eixo * meia
			pontas.append(a if a.distance_to(ctrl._ponto_de_impacto()) < b.distance_to(ctrl._ponto_de_impacto()) else b)
	return pontas.size() == 3 and pontas[0].distance_to(pontas[1]) < 0.08 and pontas[1].distance_to(pontas[2]) < 0.08


func _quadros(n: int) -> void:
	for i in n:
		await physics_frame


func _checar(texto: String, condicao: bool) -> void:
	print("%s %s" % ["✓" if condicao else "❌", texto])
	if condicao:
		_ok += 1
	else:
		_falhas += 1
