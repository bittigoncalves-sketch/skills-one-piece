extends Node3D
## Forma e voo pertencem à fruta; movimento é consumido pelo Player na locomoção.
const ID := "tori_tori_phoenix"
const Forma := preload("res://src/effects/phoenix/forma_phoenix.gd")
const Efeito := preload("res://src/effects/phoenix/efeito_phoenix.gd")
const DURACAO_VOO := 12.0
var ator: CharacterBody3D
var transformado := false
var sentado := false
var voo := 0.0
var investida := 0.0
var rumo := Vector3.FORWARD
var forma: Node3D
var zona: DamageZone

func _ready() -> void:
	ator = get_parent()
	# Este componente nasce depois de o Player receber a autoridade da rede.
	set_multiplayer_authority(ator.get_multiplayer_authority())

func pode(tecla: String) -> bool:
	return ator.current_fruit_id == ID and tecla in ["Z","X","C","V","F"] \
		and ator.corpo_livre_para_golpe() and investida <= 0.0 \
		and (tecla != "F" or transformado)

func desligando(tecla: String) -> bool:
	return (tecla == "Z" and transformado) or (tecla == "F" and voo > 0)

func executar(tecla: String, direcao: Vector3, spec: DamageSpec) -> void:
	if not pode(tecla): return
	sentado = false
	var mundo: Node3D = ator._get_skills_container()
	AudioFX.whoosh(mundo, ator.global_position, 1.25 if tecla in ["X","C"] else 0.85)
	match tecla:
		"Z":
			if transformado:
				cancelar()
			else:
				transformado = true
				forma = Forma.new()
				add_child(forma)
				# A origem do asset é o apoio das garras; o Player tem os pés a -0,8 m.
				forma.position.y = -0.8
				ator.set_meta("phoenix_transformado", true)
				ator._atualizar_visibilidade_corpo()
		"F":
			voo = 0.0 if voo > 0 else DURACAO_VOO
		"C":
			investida = 0.7
			rumo = direcao.normalized()
			zona = DamageZone.new()
			mundo.add_child(zona)
			zona.global_position = ator.global_position + Vector3.UP*0.5
			zona.setup(spec.dano, 21.0, Vector3.ZERO, 0.7, ator, 1.5)
			zona.collision_mask = 15
			zona.feedback_global = false
			spec.marcar(zona)
			_pulso(mundo, "C", direcao, spec)
		"X", "V":
			_pulso(mundo, tecla, direcao, spec)
	ator.set_meta("is_casting", false)

func _pulso(mundo: Node3D, tecla: String, direcao: Vector3, spec: DamageSpec) -> void:
	var e := Efeito.new()
	e.ator = ator
	e.tipo = tecla
	e.spec = spec
	e.rumo = direcao.normalized()
	mundo.add_child(e)
	e.global_position = ator.global_position + Vector3.UP*0.55
	if tecla == "X":
		e.global_position += direcao*1.5
		e.look_at(e.global_position + direcao, Vector3.UP)

func _physics_process(delta: float) -> void:
	if ator.current_fruit_id != ID or ator.health <= 0:
		cancelar()
		return
	if not ator.corpo_livre_para_golpe() or ator.fruta_bloqueada_por_dano():
		voo = 0.0
		investida = 0.0
		if is_instance_valid(zona): zona.queue_free()
	voo = maxf(0, voo-delta)
	investida = maxf(0, investida-delta)
	if is_instance_valid(zona):
		var antes := zona.global_position
		zona.global_position = ator.global_position + Vector3.UP*0.5
		zona._varrer_caminho(antes, zona.global_position)
	if is_instance_valid(forma):
		forma.rotation.y = ator.modelo_visual().rotation.y
		var no_chao: bool = ator.is_on_floor() if ator._is_authority else ator.net_on_floor
		var movimento: Vector3 = ator.velocity if ator._is_authority else ator.net_velocity
		var em_voo := voo > 0 or investida > 0
		if sentado and (not no_chao or em_voo or Vector2(movimento.x, movimento.z).length() > 0.25 \
				or not ator.corpo_livre_para_golpe() or ator.fruta_bloqueada_por_dano() \
				or ator._charging or ator._intervalo_golpe > 0.0 or ator.get_meta("is_casting", false)):
			_sincronizar_repouso(false)
		# O visual distingue voo ativo de queda: desligar F não inventa chão nem
		# teleporta. O contato de move_and_slide inicia o amortecimento do pouso.
		var velocidade_local := forma.global_basis.orthonormalized().inverse() * movimento
		forma.atualizar_movimento(velocidade_local, no_chao, em_voo, sentado)
		forma.ataque = 1.0 if investida > 0 else 0.0
		forma.visible = not ator._camera.em_primeira_pessoa()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode != KEY_H and event.keycode != KEY_H:
		return
	if not is_instance_valid(ator) or not ator._is_authority or ator._menu_de_tela_aberto():
		return
	if alternar_repouso():
		get_viewport().set_input_as_handled()

## H: repousar no chão. Andar, saltar ou usar uma técnica levanta a ave.
## Só muda a apresentação; colisão e deslocamento continuam pertencendo ao Player.
func alternar_repouso() -> bool:
	if not transformado or not is_instance_valid(ator) or not ator._is_authority \
			or not ator.is_on_floor() or controla_movimento() \
			or not ator.corpo_livre_para_golpe() or ator.fruta_bloqueada_por_dano() \
			or ator._charging or ator._intervalo_golpe > 0.0 or ator.get_meta("is_casting", false) \
			or Vector2(ator.velocity.x, ator.velocity.z).length() > 0.25:
		return false
	_sincronizar_repouso(not sentado)
	return true

func _sincronizar_repouso(valor: bool) -> void:
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		_aplicar_repouso.rpc(valor)
	else:
		_aplicar_repouso(valor)

@rpc("authority", "call_local", "reliable")
func _aplicar_repouso(valor: bool) -> void:
	# O pedido chega apenas do dono deste Player. Cada cópia também cancela
	# repouso ao receber movimento, perda do chão ou uma técnica replicada.
	sentado = valor and transformado and not controla_movimento()

func controla_movimento() -> bool:
	return voo > 0 or investida > 0

func velocidade(delta: float, atual: Vector3, q: MoveFrame, mira: Vector3) -> Vector3:
	if investida > 0: return rumo*27.0
	# WASD relativo à câmera; parado paira, W segue também a inclinação da mira.
	var desejada := (mira*q.f + q.direita*q.r).limit_length()*15.0
	if q.espaco_segurado: desejada.y += 9.0
	if Input.is_physical_key_pressed(KEY_CTRL): desejada.y -= 9.0
	if voo > DURACAO_VOO-0.45: desejada.y = maxf(desejada.y, 5.0)
	var resultado := atual.move_toward(desejada, delta*40.0)
	resultado.y = desejada.y # O voo substitui a gravidade aplicada antes pelo Player.
	return resultado

func cancelar() -> void:
	var tinha_forma := transformado
	transformado = false
	sentado = false
	voo = 0.0
	investida = 0.0
	if is_instance_valid(forma):
		forma.queue_free()
	forma = null
	if is_instance_valid(zona): zona.queue_free()
	zona = null
	if is_instance_valid(ator): ator.set_meta("phoenix_transformado", false)
	if tinha_forma and is_instance_valid(ator): ator._atualizar_visibilidade_corpo()
