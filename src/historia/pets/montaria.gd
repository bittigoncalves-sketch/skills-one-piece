extends Node
## Dono exclusivo da física durante a montaria. A IA do pet fica suspensa e volta
## no mesmo modo ao desmontar. História usa host_offline; não é um protocolo de rede.
const Ficha := preload("res://src/historia/pets/ficha_montaria.gd")
const Locomocao := preload("res://src/historia/pets/locomocao_de_montaria.gd")
const ALCANCE := 2.8
signal aviso(texto: String)
var jogador_de: Callable
var biblioteca: BibliotecaDeModelos
var pet: CharacterBody3D
var jogador: CharacterBody3D
var perfil := {}
var _camada := 0
var _mascara := 0
var _ia_ligada := true
var _ponto_anterior := Vector3.ZERO
var _quadro := MoveFrame.new()
var _tempo := 0.0
var _volume_cavaleiro: CollisionShape3D
var _distancia_camera := 4.0
## Corrida de caranguejos (06/10/2026, pedido do dono: "não é possível sair do caranguejo
## até o fim da corrida"). Com texto, Y não desmonta: avisa o texto.
var trava := ""
## Quem conduz no lugar do teclado (contagem da corrida parada, piloto automático dos
## testes): Callable(delta) -> {dir: Vector3, correr: bool, saltar: bool}.
var piloto := Callable()

func ativa() -> bool:
	return is_instance_valid(pet) and is_instance_valid(jogador)

func candidato() -> CharacterBody3D:
	var j: Node3D = jogador_de.call() if jogador_de.is_valid() else null
	if not is_instance_valid(j) or not j.is_inside_tree():
		return null
	var melhor: CharacterBody3D
	var distancia := INF
	for n in get_tree().get_nodes_in_group("pets_historia"):
		if not n is CharacterBody3D or not _elegivel(n, j):
			continue
		var p := Ficha.perfil(n)
		var centro: Vector3 = n.global_position + Vector3.UP * float(p["altura"]) * n.global_basis.get_scale().y * .5
		var d: float = j.global_position.distance_to(centro)
		if d < distancia and d <= ALCANCE + float(p["raio"]):
			var q := PhysicsRayQueryParameters3D.create(j.global_position, centro, 1)
			q.exclude = [j.get_rid(), n.get_rid()]
			if j.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				melhor = n
				distancia = d
	return melhor

func _elegivel(n: CharacterBody3D, j: Node3D) -> bool:
	if not n.is_inside_tree() or n.is_queued_for_deletion() or float(n.get("health")) <= 0.0:
		return false
	var dono: Callable = n.get("alvo_de")
	return dono.is_valid() and dono.call() == j and not n.has_meta("cavaleiro") \
		and (Ficha.modelo(n) == "caranguejo_grande" or n is PetDomado) \
		and Ficha.classificado(biblioteca, Ficha.modelo(n))

## Devolve false só quando Y deve continuar para a doma existente.
func interagir() -> bool:
	if ativa():
		if not trava.is_empty():
			aviso.emit(trava)
			return true
		desmontar()
		return true
	var proximo := candidato()
	if proximo == null:
		return false
	montar(proximo)
	return true

## `direto`: monta neste pet mesmo que outro esteja mais perto (a corrida põe o jogador
## no próprio caranguejo); ele ainda precisa ser elegível (pet do jogador, vivo).
func montar(alvo: CharacterBody3D, direto := false) -> bool:
	var j: CharacterBody3D = jogador_de.call() if jogador_de.is_valid() else null
	if ativa() or not is_instance_valid(j) or not j.is_multiplayer_authority():
		return false
	if alvo != candidato() and not (direto and is_instance_valid(alvo) and _elegivel(alvo, j)):
		return false
	if not j.corpo_livre_para_golpe() or j.esta_atacando() or j._voo.ativo() or j.esquivando():
		aviso.emit("Termine a ação atual para montar")
		return false
	jogador = j
	pet = alvo
	perfil = Ficha.perfil(pet)
	var visual: Node3D = pet.get("visual") if perfil["largo"] else pet.get("_visual")
	var forma := CapsuleShape3D.new()
	forma.radius = .42
	forma.height = 1.35
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = forma
	consulta.transform.origin = visual.to_global(perfil["assento"]) + Vector3.UP * .35
	consulta.exclude = [j.get_rid(), pet.get_rid()]
	consulta.collision_mask = 1
	if not j.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty():
		pet = null
		jogador = null
		aviso.emit("Não há espaço sobre o pet para montar")
		return false
	_volume_cavaleiro = CollisionShape3D.new()
	_volume_cavaleiro.name = "VolumeDoCavaleiro"
	_volume_cavaleiro.shape = forma
	pet.add_child(_volume_cavaleiro)
	_volume_cavaleiro.position = pet.to_local(consulta.transform.origin)
	_volume_cavaleiro.scale = Vector3.ONE / pet.global_basis.get_scale()
	_ponto_anterior = j.global_position
	_camada = j.collision_layer
	_mascara = j.collision_mask
	_ia_ligada = pet.is_physics_processing()
	pet.set_physics_process(false)
	pet.set_meta("cavaleiro", j.get_instance_id())
	pet.tree_exiting.connect(_pet_saindo, CONNECT_ONE_SHOT)
	j.tree_exiting.connect(_jogador_saindo, CONNECT_ONE_SHOT)
	j.montaria = self
	j.set_meta("montado", true)
	j.set_meta("montaria_larga", perfil["largo"])
	j.collision_layer = 0
	j.collision_mask = 0
	j.velocity = Vector3.ZERO
	pet.velocity = Vector3.ZERO
	_quadro = MoveFrame.new()
	_distancia_camera = j._camera.distancia
	j._camera.distancia = maxf(_distancia_camera, 5.5 if perfil["largo"] else 4.5)
	aviso.emit("Montado em %s  ·  WASD mover  ·  Shift correr  ·  Espaço saltar  ·  Y desmontar" % str(pet.get("nome_exibido")))
	return true

## Chamado pela etapa de locomoção do Player, antes de gravidade/parkour/move_and_slide.
func atualizar(delta: float) -> bool:
	if not ativa():
		return false
	var atordoado: bool = jogador._fsm != null and jogador._fsm.state != null and jogador._fsm.state.name == "Stunned"
	if jogador.health <= 0.0 or float(pet.get("health")) <= 0.0 or jogador._arremesso.ativo() \
			or atordoado or jogador.get_meta("is_frozen", false) or jogador.get_meta("custom_pose", "") == "knockdown":
		desmontar(true)
		return false
	if piloto.is_valid():
		var c: Dictionary = piloto.call(delta)
		conduzir(c.get("dir", Vector3.ZERO), bool(c.get("correr", false)), bool(c.get("saltar", false)), delta)
		return true
	var hud := get_tree().get_first_node_in_group("hud")
	var livre: bool = hud == null or not hud.is_menu_open()
	_quadro.ler(jogador._yaw, livre)
	conduzir(_quadro.dir, _quadro.sprint, _quadro.espaco_agora, delta)
	return true

func conduzir(direcao: Vector3, correr: bool, saltar: bool, delta: float) -> void:
	if not ativa():
		return
	_tempo += delta
	var real := Locomocao.mover(pet, perfil, direcao, correr, saltar, delta)
	var visual := Locomocao.visual_de(pet, perfil)
	jogador.velocity = real
	var modelo: Node3D = jogador.get("_char_model")
	modelo.global_rotation = Vector3(0, visual.global_rotation.y - float(perfil["desvio_yaw"]), 0)
	var anim: Node = jogador.get("_proc_anim")
	if anim != null:
		anim.update(real, true, false, delta, 0.0)
		var quadril: Node3D = anim._n.get("Torso")
		var assento: Vector3 = visual.to_global(perfil["assento"])
		jogador.global_position = assento - (quadril.global_position - jogador.global_position) if quadril != null else assento
	HurtboxDeCombate.sincronizar(jogador)

func liberar_para_captura() -> bool:
	return desmontar(true, true)

func desmontar(forcar := false, preservar_posicao := false) -> bool:
	if not is_instance_valid(jogador):
		return false
	var ponto: Variant = jogador.global_position if preservar_posicao else _ponto_livre()
	if ponto == null and not forcar:
		aviso.emit("Sem espaço livre para desmontar. Afaste a montaria da parede.")
		return false
	var j := jogador
	if j.tree_exiting.is_connected(_jogador_saindo):
		j.tree_exiting.disconnect(_jogador_saindo)
	if is_instance_valid(_volume_cavaleiro):
		_volume_cavaleiro.get_parent().remove_child(_volume_cavaleiro)
		_volume_cavaleiro.queue_free()
	_volume_cavaleiro = null
	if is_instance_valid(pet):
		if pet.tree_exiting.is_connected(_pet_saindo):
			pet.tree_exiting.disconnect(_pet_saindo)
		pet.remove_meta("cavaleiro")
		pet.set_physics_process(_ia_ligada)
		pet.velocity = Vector3.ZERO
	j.collision_layer = _camada
	j.collision_mask = _mascara
	j.montaria = null
	j.set_meta("montado", false)
	j.remove_meta("montaria_larga")
	j.velocity = Vector3.ZERO
	j._camera.distancia = _distancia_camera
	if j.is_inside_tree():
		j.global_position = ponto if ponto is Vector3 else _ponto_anterior
	pet = null
	jogador = null
	perfil.clear()
	if not forcar:
		aviso.emit("Desmontou  ·  Y perto do pet para montar novamente")
	return true

func _ponto_livre() -> Variant:
	if not is_instance_valid(jogador) or not jogador.is_inside_tree() or not is_instance_valid(pet) or not pet.is_inside_tree():
		return null
	var forma := CapsuleShape3D.new()
	forma.radius = .38
	forma.height = 1.6
	var espaco := jogador.get_world_3d().direct_space_state
	var excluidos: Array[RID] = [jogador.get_rid(), pet.get_rid()]
	for raio: float in [float(perfil["raio"]) + 1.0, float(perfil["raio"]) + 1.8, float(perfil["raio"]) + 2.6]:
		for i in 8:
			var angulo := float(i) * TAU / 8
			var p := pet.global_position + Vector3(cos(angulo), 0, sin(angulo)) * raio
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3, p + Vector3.DOWN * 6, 1)
			q.exclude = excluidos
			var hit := espaco.intersect_ray(q)
			var agua := AguaDoMundo.nivel_em(p.x, p.z)
			if not is_nan(agua) and (hit.is_empty() or (hit["position"] as Vector3).y < agua - 1.0):
				p.y = agua - .3
			elif not hit.is_empty() and (hit["normal"] as Vector3).y >= .65:
				p = hit["position"] + Vector3.UP * .85
			else:
				continue
			# Não atravesse paredes para alcançar um ponto vazio do outro lado.
			var caminho := PhysicsRayQueryParameters3D.create(jogador.global_position + Vector3.UP * .3, p, 1)
			caminho.exclude = excluidos
			if not espaco.intersect_ray(caminho).is_empty():
				continue
			var volume := PhysicsShapeQueryParameters3D.new()
			volume.shape = forma
			volume.transform.origin = p
			volume.collision_mask = 1
			volume.exclude = excluidos
			if espaco.intersect_shape(volume, 1).is_empty():
				return p
	return null

func dica() -> String:
	if ativa():
		return "Y · travado até a chegada" if not trava.is_empty() else "Y · Desmontar"
	var proximo := candidato()
	return "Y · Montar em " + str(proximo.get("nome_exibido")) if proximo != null else ""

func _pet_saindo() -> void:
	desmontar(true)

func _jogador_saindo() -> void:
	desmontar(true)

func _exit_tree() -> void:
	if is_instance_valid(jogador):
		desmontar(true)
