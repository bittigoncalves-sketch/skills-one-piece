extends Node
## Stone Throwing (X) e Giant Rock Throwing (C) da Kira Kira. Substitui o `rock_fragment` redondo do mod
## por cubos de pedra (`kira_pedra.gd`). O servidor decide dano e hitbox; todos desenham a mesma pedra.
const KiraPedra = preload("res://src/combat/kira/kira_pedra.gd")
const NUMERO_X := 24
const NUMERO_C := 25
const CUSTO_X := 150.0
const CUSTO_C := 500.0
const RECARGA_X := 3.75
const RECARGA_C := 12.5
const PEDRAS_DO_X := 6
const INTERVALO_X := 0.13
const TAMANHO_X := 0.8
const TAMANHO_C := 3.2
const DANO_X_DO_MOD := 12.0
const DANO_C_DO_MOD := 45.0
const ALCANCE_MIRA := 48.0
const CONE_MIRA := 0.985                # cos(~10°): alvo que o retículo quase pega vira o alvo
const POSE_X := {"Torso": Vector3(-0.08, 0, 0), "UpperArm_R": Vector3(-1.45, 0, -0.1), "UpperArm_L": Vector3(0.3, 0, 0.2)}
const POSE_C := {"Torso": Vector3(-0.15, 0, 0), "UpperArm_R": Vector3(-2.7, 0, -0.25), "UpperArm_L": Vector3(-2.7, 0, 0.25)}

var controlador: Node
var ativo := false
var _tecla := ""
var _tempo := 0.0
var _lancadas := 0
var _destino := Vector3.ZERO
var _dano := 0.0
var _duracao := 0.0


func numero_de(tecla: String) -> int:
	return NUMERO_X if tecla == "X" else NUMERO_C if tecla == "C" else 0


func iniciar(tecla: String) -> bool:
	var a: Player = controlador.ator
	var numero := numero_de(tecla)
	var custo := CUSTO_X if tecla == "X" else CUSTO_C
	if numero == 0 or not controlador.servidor() or ativo or controlador.ativo or not controlador.fruta_ativa() \
			or a.morrendo or not a.corpo_livre_para_golpe():
		return false
	if controlador.recarga_da_tecnica(numero) > 0.0 or a.energy + 0.001 < custo:
		return false
	a.gastar_energia(custo)
	controlador._sincronizar_para_o_mod()
	controlador.iniciar_recarga(numero, RECARGA_X if tecla == "X" else RECARGA_C)
	controlador.selecao = numero
	_tecla = tecla
	_destino = _ponto_de_mira()
	_dano = (DANO_X_DO_MOD if tecla == "X" else DANO_C_DO_MOD) * MundoMinePiece.DANO_DA_ARENA_POR_DANO_DO_MOD \
		* a.escala_de_dano_da_fruta("kira_kira")
	_tempo = 0.0
	_lancadas = 0
	_duracao = PEDRAS_DO_X * INTERVALO_X + 0.4 if tecla == "X" else 1.3
	ativo = true
	controlador.mostrar_pose_kira(POSE_X if tecla == "X" else POSE_C)
	PoderDaFruta.ativacao(a, "kira_kira", custo)
	if tecla == "C":
		_lancar_gigante()
	return true


func _physics_process(delta: float) -> void:
	if not ativo:
		return
	var a: Player = controlador.ator
	if not is_instance_valid(a) or not controlador.fruta_ativa() or a.morrendo:
		cancelar()
		return
	_tempo += delta
	if _tecla == "X":
		while _lancadas < PEDRAS_DO_X and _tempo >= _lancadas * INTERVALO_X:
			_lancar_pedra_do_x()
	if _tempo >= _duracao:
		cancelar()


## Ponto que o retículo marca; um inimigo quase na linha da mira vira o ponto (centro dele).
func _ponto_de_mira() -> Vector3:
	var a: Player = controlador.ator
	var origem: Vector3 = a.global_position + Vector3.UP * 0.9
	var rumo: Vector3 = controlador.olhar() if a._is_authority else RosaDosVentos.frente(a.net_facing)
	rumo = rumo.normalized()
	var melhor: Node3D = null
	var melhor_cos := CONE_MIRA
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(a, alvo) or CombatResolver.e_fogo_amigo(alvo, a):
			continue
		var para := AlvosDeGolpe.centro(alvo) - origem
		var dist := para.length()
		if dist < 1.0 or dist > ALCANCE_MIRA:
			continue
		var c := rumo.dot(para / dist)
		if c > melhor_cos:
			melhor_cos = c
			melhor = alvo
	if melhor != null:
		return AlvosDeGolpe.centro(melhor)
	return AlvosDeGolpe.ponto_mirado(a.get_world_3d(), origem, rumo, ALCANCE_MIRA, [a.get_rid()])


func _frente_plana() -> Vector3:
	var a: Player = controlador.ator
	var f := _destino - a.global_position
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.01 else -a.global_basis.z


func _lancar_pedra_do_x() -> void:
	var a: Player = controlador.ator
	var frente := _frente_plana()
	var lado := frente.cross(Vector3.UP).normalized()
	# Surge num arco à frente do corpo (como o mod, ±45°) e parte para o ponto de mira.
	var origem: Vector3 = a.global_position + frente * randf_range(1.2, 2.2) + lado * randf_range(-1.6, 1.6) \
		+ Vector3.UP * randf_range(0.0, 1.1)
	var alvo := _destino + Vector3(randf_range(-0.25, 0.25), randf_range(-0.2, 0.2), randf_range(-0.25, 0.25))
	controlador.mostrar_pedra_kira(origem, alvo, TAMANHO_X, "pedra_x", _dano, 0.0, 42.0, 0.0, 0.0)
	_lancadas += 1


func _lancar_gigante() -> void:
	var a: Player = controlador.ator
	var frente := _frente_plana()
	var chao: Vector3 = AlvosDeGolpe.ponto_mirado(a.get_world_3d(), a.global_position + frente * 5.5 + Vector3.UP * 3.0,
		Vector3.DOWN, 8.0, [a.get_rid()])
	var centro := chao + Vector3.UP * (TAMANHO_C * 0.5 + 0.15)   # 0,15 m acima do chão: não raspa o piso ao partir
	controlador.mostrar_pedra_kira(centro, _destino, TAMANHO_C, "pedra_c", _dano, 5.5, 32.0, TAMANHO_C * 0.55 + 0.3, 0.9)


func cancelar() -> void:
	if not ativo:
		return
	ativo = false
	if is_instance_valid(controlador):
		controlador.mostrar_pose_kira({})


func _exit_tree() -> void:
	cancelar()
