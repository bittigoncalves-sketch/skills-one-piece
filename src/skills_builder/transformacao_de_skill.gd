extends Node3D
## Um bloco de transformação, compartilhado pela timeline da prévia e do jogo.
## Só desenha: nunca troca o corpo, a IA, a colisão, a vida ou o asset salvo no mapa.
const Visual := preload("res://src/skills_builder/visual_de_transformacao.gd")
const GRUPO_ASSETS := &"assets_transformaveis"
const PILHA := &"transformacoes_visuais"
const OCULTADORES := &"ocultadores_transformacao"
const VISIBILIDADE := &"visibilidade_antes_transformacao"
const MAX_ALVOS := 32
var _entradas: Array[Dictionary] = []


static func iniciar(pai: Node, usuario: Node3D, p: Dictionary, candidatos: Array = []) -> Node3D:
	var bloco := new()
	bloco.set_meta("visual_transformacao", true)
	pai.add_child(bloco)
	for alvo in selecionar(usuario, p, candidatos):
		bloco._transformar(alvo, p)
	bloco.atualizar(0.0)
	return bloco


static func selecionar(usuario: Node3D, p: Dictionary, candidatos: Array = []) -> Array[Node3D]:
	var modo := str(p.get("alvo", "Usuário"))
	if modo == "Usuário": return [usuario]
	var lista := candidatos.duplicate()
	if lista.is_empty():
		lista = AlvosDeGolpe.todos(usuario.get_tree())
		lista.append_array(usuario.get_tree().get_nodes_in_group("alvo_previa_transformacao"))
		lista.append_array(usuario.get_tree().get_nodes_in_group(GRUPO_ASSETS))
	var saida: Array[Node3D] = []
	for n in lista:
		if not is_instance_valid(n) or not n is Node3D or n == usuario or n in saida:
			continue
		if not n.is_inside_tree() or not n.is_visible_in_tree(): continue
		if "health" in n and float(n.get("health")) <= 0.0: continue
		if n.get_world_3d() != usuario.get_world_3d(): continue
		var asset: bool = n.is_in_group(GRUPO_ASSETS)
		var inimigo: bool = AlvosDeGolpe.e_alvo(n) or n.is_in_group("alvo_previa_transformacao")
		if usuario.is_in_group("enemy") and n.is_in_group("enemy"): inimigo = false
		if modo == "Assets ao redor" and not asset: continue
		if modo in ["Inimigo mais próximo", "Inimigos ao redor"] and not inimigo: continue
		if modo == "Inimigos e assets ao redor" and not (inimigo or asset): continue
		if usuario.global_position.distance_to(n.global_position) <= float(p.get("raio", 8.0)):
			saida.append(n)
	saida.sort_custom(func(a, b): return usuario.global_position.distance_squared_to(a.global_position) < usuario.global_position.distance_squared_to(b.global_position))
	return saida.slice(0, 1 if modo == "Inimigo mais próximo" else MAX_ALVOS)


func _transformar(alvo: Node3D, p: Dictionary) -> void:
	var malhas: Array[GeometryInstance3D] = []
	_coletar(alvo, malhas)
	if malhas.is_empty(): return
	var caixa := AABB()
	var primeira := true
	for m in malhas:
		if not m is MeshInstance3D or m.mesh == null: continue
		var local: AABB = (alvo.global_transform.affine_inverse() * m.global_transform) * m.get_aabb()
		caixa = local if primeira else caixa.merge(local)
		primeira = false
	if primeira: caixa = AABB(Vector3(-.5, 0, -.5), Vector3(1, 2, 1))
	var fx := Visual.criar(p, caixa.size * alvo.global_basis.get_scale().abs())
	if fx == null:
		push_warning("Transformação: o modelo selecionado não está disponível: " + str(p.get("modelo", "")))
		return # não esconder nada quando não há forma para mostrar
	add_child(fx)
	var pilha: Array = alvo.get_meta(PILHA, [])
	pilha.append(fx)
	alvo.set_meta(PILHA, pilha)
	for m in malhas: _ocultar(m)
	_entradas.append({"alvo": alvo, "fx": fx, "centro": caixa.get_center(), "malhas": malhas})


func atualizar(tempo: float) -> void:
	for e in _entradas.duplicate():
		if not is_instance_valid(e.alvo):
			_restaurar(e)
			_entradas.erase(e)
			continue
		var alvo: Node3D = e.alvo
		if "health" in alvo and float(alvo.get("health")) <= 0.0:
			_restaurar(e)
			_entradas.erase(e)
			continue
		var fx: Node3D = e.fx
		# Uma reconstrução do rig/equipamento também deve permanecer transformada.
		var atuais: Array[GeometryInstance3D] = []
		_coletar(alvo, atuais)
		for m in atuais:
			if not m in e.malhas:
				e.malhas.append(m)
				_ocultar(m)
		var pilha: Array = alvo.get_meta(PILHA, [])
		fx.visible = not pilha.is_empty() and pilha.back() == fx and alvo.is_visible_in_tree()
		fx.global_position = alvo.to_global(e.centro)
		fx.global_basis = alvo.global_basis.orthonormalized()
		Visual.animar(fx, tempo)


func encerrar() -> void:
	for e in _entradas: _restaurar(e)
	_entradas.clear()
	queue_free()


func _exit_tree() -> void:
	for e in _entradas: _restaurar(e)
	_entradas.clear()


func _restaurar(e: Dictionary) -> void:
	for m in e.malhas:
		if not is_instance_valid(m): continue
		var usuarios: Dictionary = m.get_meta(OCULTADORES, {})
		usuarios.erase(get_instance_id())
		if usuarios.is_empty():
			m.visible = bool(m.get_meta(VISIBILIDADE, m.visible))
			m.remove_meta(OCULTADORES)
			m.remove_meta(VISIBILIDADE)
		else: m.set_meta(OCULTADORES, usuarios)
	if is_instance_valid(e.alvo):
		var pilha: Array = e.alvo.get_meta(PILHA, [])
		pilha.erase(e.fx)
		if pilha.is_empty(): e.alvo.remove_meta(PILHA)
		else:
			e.alvo.set_meta(PILHA, pilha)
			if is_instance_valid(pilha.back()): pilha.back().visible = true
	if is_instance_valid(e.fx):
		e.fx.visible = false
		e.fx.queue_free()


func _ocultar(m: GeometryInstance3D) -> void:
	var usuarios: Dictionary = m.get_meta(OCULTADORES, {})
	if usuarios.is_empty(): m.set_meta(VISIBILIDADE, m.visible)
	usuarios[get_instance_id()] = true
	m.set_meta(OCULTADORES, usuarios)
	m.visible = false


static func _coletar(no: Node, malhas: Array[GeometryInstance3D]) -> void:
	if no.has_meta("visual_transformacao"): return
	if no is GeometryInstance3D and not no is Label3D:
		malhas.append(no)
	for filho in no.get_children(): _coletar(filho, malhas)
