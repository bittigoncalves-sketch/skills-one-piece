extends Node
## Um dono temporário do movimento por ser vivo. A IA não disputa a órbita nem
## a queda; NPCs estáticos conservam sua identidade e ganham um corpo móvel auxiliar.
var alvo: Node3D
var origem: Node3D
var em_orbita := true
var _corpo: PhysicsBody3D
var _auxiliar: CharacterBody3D
var _modo := Node.PROCESS_MODE_INHERIT
var _modo_desabilitado := CollisionObject3D.DISABLE_MODE_REMOVE
var _camada := 0
var _mascara := 0
var _velocidade := Vector3.ZERO
var _tempo_queda := 0.0
var _encerrado := false
var _fase := 0.0
var _altura := 2.0
var _raio := 1.1


static func _meta(no: Node, chave: String) -> Variant:
	return no.get_meta(chave) if no.has_meta(chave) else null


static func vivo(no: Node) -> bool:
	if not is_instance_valid(no) or not no is Node3D or not no.is_inside_tree() or no.is_queued_for_deletion():
		return false
	if not (no.is_in_group("player") or no.is_in_group("animais") or no.is_in_group("pets_historia") \
		or no.is_in_group("enemy") or no.is_in_group("npc")):
		return false
	var vida: Variant = no.get("health")
	return (vida == null or float(vida) > 0.0) and bool(no.get("visible"))


static func seres_vivos(arvore: SceneTree) -> Array[Node3D]:
	var vistos := {}
	var resultado: Array[Node3D] = []
	for grupo in ["player", "animais", "pets_historia", "enemy", "npc"]:
		for no in arvore.get_nodes_in_group(grupo):
			var dono: Object = HurtboxDeCombate.dono_de(no)
			if dono is Node3D and vivo(dono) and not vistos.has(dono.get_instance_id()):
				vistos[dono.get_instance_id()] = true
				resultado.append(dono)
	return resultado


static func centro(no: Node3D) -> Vector3:
	for filho in no.get_children():
		if filho is CollisionShape3D and not filho.disabled:
			return filho.global_position
	return no.global_position + Vector3.UP * 0.8


static func tomar(no: Node3D, dono: Node3D, indice := 0) -> Node:
	if not vivo(no) or not no is PhysicsBody3D or no == dono:
		return null
	if is_instance_valid(_meta(no, "captura_vento")) or is_instance_valid(_meta(no, "arremesso_vento")):
		return null
	if no.get_multiplayer().has_multiplayer_peer() and not no.get_multiplayer().is_server():
		return null
	var captura: Node = load("res://src/historia/bosses/harpia/captura_vento.gd").new()
	no.get_tree().root.add_child(captura)
	captura._iniciar(no, dono, indice)
	return captura


static func aplicar_arremesso(no: Node3D, impulso: Vector3) -> bool:
	if not vivo(no) or not impulso.is_finite():
		return false
	if no.get_multiplayer().has_multiplayer_peer() and not no.get_multiplayer().is_server():
		return false
	var captura: Node = (_meta(no, "captura_vento") if no.has_meta("captura_vento") else _meta(no, "arremesso_vento"))
	if is_instance_valid(captura):
		captura.soltar(impulso)
		return true
	if no.has_method("receber_arremesso"):
		_desocupar(no)
		no.receber_arremesso(impulso)
		return true
	captura = tomar(no, null)
	if captura == null:
		return false
	captura.soltar(impulso)
	return true


static func _desocupar(no: Node3D) -> void:
	# Ambos os caminhos restauram colisão e posição ATUAL, sem busca/teleporte.
	for campo in ["navegacao", "montaria"]:
		var controle: Variant = no.get(campo)
		if is_instance_valid(controle) and controle.has_method("liberar_para_captura"):
			controle.liberar_para_captura()
	# Capturar primeiro a montaria também libera o cavaleiro antes da IA ser suspensa.
	if no.has_meta("cavaleiro"):
		var id := int(no.get_meta("cavaleiro"))
		var cavaleiro: Object = instance_from_id(id)
		if is_instance_valid(cavaleiro):
			var montaria: Variant = cavaleiro.get("montaria")
			if is_instance_valid(montaria):
				montaria.liberar_para_captura()


func _iniciar(no: Node3D, dono: Node3D, indice: int) -> void:
	alvo = no
	origem = dono
	_desocupar(alvo)
	_modo = alvo.process_mode
	_modo_desabilitado = (alvo as PhysicsBody3D).disable_mode
	_camada = (alvo as PhysicsBody3D).collision_layer
	_mascara = (alvo as PhysicsBody3D).collision_mask
	_fase = float(indice) * 2.399963
	_altura = 1.4 + fmod(float(indice) * 1.15, 3.2)
	_raio = 0.9 + fmod(float(indice) * 0.37, 0.7)
	alvo.set_meta("captura_vento", self)
	if alvo.has_method("iniciar_captura_vento"):
		alvo.iniciar_captura_vento(self)
	else:
		# Inclui descendentes: ações de IA, timers e ataques deixam de rodar.
		# CollisionObject3D normalmente sai do mundo quando process_mode=DISABLED;
		# o colisor precisa continuar ativo para nosso move_and_collide respeitar chão.
		(alvo as PhysicsBody3D).disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
		alvo.process_mode = Node.PROCESS_MODE_DISABLED
	alvo.tree_exiting.connect(_alvo_saindo, CONNECT_ONE_SHOT)
	if alvo is CharacterBody3D:
		_corpo = alvo
		(alvo as CharacterBody3D).velocity = Vector3.ZERO
	else:
		_auxiliar = CharacterBody3D.new()
		_auxiliar.name = "CorpoTemporarioDoVendaval"
		add_child(_auxiliar)
		_auxiliar.global_transform = alvo.global_transform
		var formas := 0
		for filho in alvo.get_children():
			if not filho is CollisionShape3D or filho.disabled or filho.shape == null:
				continue
			var copia := CollisionShape3D.new()
			if filho.shape is ConcavePolygonShape3D:
				# Inimigos colocados como malha côncava precisam de volume convexo.
				var caixa: AABB = filho.shape.get_debug_mesh().get_aabb()
				var forma := BoxShape3D.new()
				forma.size = caixa.size.max(Vector3.ONE * 0.1)
				copia.shape = forma
				copia.transform = filho.transform
				copia.position += caixa.get_center()
			else:
				copia.shape = filho.shape
				copia.transform = filho.transform
			_auxiliar.add_child(copia)
			formas += 1
		if formas == 0:
			var copia := CollisionShape3D.new()
			var forma := CapsuleShape3D.new()
			forma.radius = 0.45
			forma.height = 1.8
			copia.shape = forma
			copia.position.y = 0.9
			_auxiliar.add_child(copia)
		_corpo = _auxiliar
	# Camada zero impede colisões recíprocas entre capturados; máscara 1 conserva
	# paredes, chão, barcos e cenário. Não alteramos colisores de cenário.
	(alvo as PhysicsBody3D).collision_layer = 0
	_corpo.collision_layer = 0
	_corpo.collision_mask = 1
	set_physics_process(true)


func orbitar(centro_tornado: Vector3, tempo: float, delta: float) -> void:
	if not em_orbita or _encerrado or not vivo(alvo):
		return
	var angulo := _fase + tempo * 4.0
	var desejada := centro_tornado + Vector3(cos(angulo) * _raio, _altura + sin(tempo * 2.0 + _fase) * .3, sin(angulo) * _raio)
	# Aproximação limitada evita saltos na captura inicial e órbitas através de paredes.
	_mover((desejada - alvo.global_position).limit_length(22.0 * delta))
	if alvo is CharacterBody3D:
		(alvo as CharacterBody3D).velocity = Vector3.ZERO


func _mover(deslocamento: Vector3) -> void:
	if not is_instance_valid(_corpo) or not deslocamento.is_finite():
		return
	var restante := deslocamento
	for tentativa in 3:
		if restante.length_squared() < 0.000001:
			break
		var contato := _corpo.move_and_collide(restante)
		if contato == null:
			break
		restante = contato.get_remainder().slide(contato.get_normal())
		if not em_orbita:
			_velocidade = _velocidade.slide(contato.get_normal())
	if _auxiliar != null:
		alvo.global_position = _auxiliar.global_position
	HurtboxDeCombate.sincronizar(alvo)


## Vetor zero = cancelamento excepcional: sem impulso, mas com queda segura.
func soltar(impulso: Vector3 = Vector3.ZERO) -> void:
	if _encerrado or not is_instance_valid(alvo):
		cancelar()
		return
	if _meta(alvo, "captura_vento") == self:
		alvo.remove_meta("captura_vento")
	em_orbita = false
	origem = null
	if alvo.has_method("receber_arremesso"):
		var jogador := alvo
		cancelar()
		if impulso.length_squared() > 0.01 and vivo(jogador):
			jogador.receber_arremesso(impulso)
		return
	alvo.set_meta("arremesso_vento", self)
	_velocidade = impulso
	_tempo_queda = 0.0


func _physics_process(delta: float) -> void:
	if _encerrado:
		return
	if not vivo(alvo):
		cancelar()
		return
	if em_orbita:
		if not is_instance_valid(origem) or origem.is_queued_for_deletion():
			soltar()
		return
	_tempo_queda += delta
	_velocidade.y = maxf(-45.0, _velocidade.y - 24.0 * delta)
	var posicao := _corpo.global_position
	_mover(_velocidade * delta)
	# Varredura curta pelo próprio volume identifica o piso, inclusive para NPC.
	var contato := _corpo.move_and_collide(Vector3.DOWN * .08, true)
	var pousou := contato != null and contato.get_normal().y > 0.55 and _velocidade.y <= 0.0
	# Um NPC estático precisa continuar caindo até encontrar piso; encerrar pelo
	# relógio o deixaria suspenso. Characters podem retomar sua própria gravidade.
	if pousou or (_tempo_queda >= 8.0 and alvo is CharacterBody3D) or alvo.global_position.y < -150.0:
		cancelar()
	elif alvo is CharacterBody3D:
		(alvo as CharacterBody3D).velocity = (_corpo.global_position - posicao) / maxf(delta, .001)


## Cancelamento imediato para morte/respawn/remoção. Não reposiciona o alvo.
func cancelar() -> void:
	if _encerrado:
		return
	_encerrado = true
	if is_instance_valid(alvo):
		if alvo.tree_exiting.is_connected(_alvo_saindo):
			alvo.tree_exiting.disconnect(_alvo_saindo)
		for chave in ["captura_vento", "arremesso_vento"]:
			if _meta(alvo, chave) == self:
				alvo.remove_meta(chave)
		alvo.process_mode = _modo
		(alvo as PhysicsBody3D).disable_mode = _modo_desabilitado
		var vida: Variant = alvo.get("health")
		(alvo as PhysicsBody3D).collision_layer = 0 if vida != null and float(vida) <= 0.0 and not alvo.has_method("receber_arremesso") else _camada
		(alvo as PhysicsBody3D).collision_mask = _mascara
		if alvo is CharacterBody3D:
			(alvo as CharacterBody3D).velocity = Vector3.ZERO
	set_physics_process(false)
	queue_free()


func _alvo_saindo() -> void:
	cancelar()


func _exit_tree() -> void:
	cancelar()
