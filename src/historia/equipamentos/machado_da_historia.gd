extends Node
## Usa o relógio/IK/cancelamento do combate. O M1 só colhe vegetação (sem dano a NPCs); o dano é das
## técnicas Z e X, em `habilidades_do_machado.gd` (17/10/2026).
const MODELO := preload("res://mapas/modelos/machado_lenhador.glb")
const ESTILO := preload("res://src/combat/direcional/estilos/machado.tres")
const BOXE := preload("res://src/combat/direcional/estilos/boxe.tres")
const VARREDURA := preload("res://src/combat/SwordSweep.gd")
const CAMADA_COLETA := 1 << 21
const FIO := Vector3(.43, .72, 0)
var ativa := false
var _visual: Node3D
var _jogador: Player
var _ex: ExecutorCorpoACorpo
var _anterior := Vector3.INF
var _acao := -1
var _acertou := false
var _alvo: Node
var _acao_colhida := -1
## Z e X (17/10/2026).
var habilidades: HabilidadesDoMachado

func _ready() -> void:
	_jogador = get_parent() as Player
	_ex = _jogador.combate_direcional
	# Depois do executor aplicar a pose, antes de ler a cabeça animada.
	process_physics_priority = 1
	habilidades = HabilidadesDoMachado.new()
	habilidades.name = "HabilidadesDoMachado"
	add_child(habilidades)

func aplicar(sim: bool) -> void:
	if ativa == sim: return
	ativa = sim
	_anterior = Vector3.INF
	if ativa:
		# Um machado só: o que estava no chão (arremesso do Z) some e volta para a mão.
		habilidades.recolher_lancado()
		_ex.trocar_estilo(ESTILO)
		_montar_visual()
	else:
		habilidades.abortar()
		if _ex.estilo.id == &"machado": _ex.trocar_estilo(BOXE)
		_tirar_visual()
	_jogador.entrada_combate_direcional.atualizar_defesa(false)
	_jogador.entrada_combate_direcional.esquecer_gesto()

## Reserva central: nem duas árvores contatadas no mesmo quadro recebem dano.
func reservar_alvo(alvo: Node, acao: int) -> bool:
	if acao == _acao_colhida: return false
	if is_instance_valid(_alvo) and not _alvo.derrubada and _alvo.vida < _alvo.vida_maxima and _alvo.lenhador_perto() and alvo != _alvo:
		return false
	_alvo = alvo
	_acao_colhida = acao
	return true

func _montar_visual() -> void:
	var mao: Node3D = _jogador.get("_rig").item_handle
	if not is_instance_valid(mao): return
	if is_instance_valid(_visual) and _visual.get_parent() == mao: return
	_tirar_visual()
	_visual = MODELO.instantiate() as Node3D
	_visual.name = "MachadoLenhador"
	# Fio alinhado ao plano vertical do corte, não de lado como uma espada.
	_visual.rotation.y = PI * .5
	mao.add_child(_visual)
	var escala := mao.global_basis.get_scale()
	_visual.scale = Vector3.ONE / escala
	_anterior = Vector3.INF

## O machado está na mão (modelo montado no encaixe)?
func visual_na_mao() -> bool:
	return is_instance_valid(_visual)

func ponta() -> Vector3:
	return _visual.to_global(FIO) if is_instance_valid(_visual) else Vector3.INF

func _physics_process(_delta: float) -> void:
	if not ativa: return
	_montar_visual()
	var agora := ponta()
	if agora == Vector3.INF: return
	if _acao != _ex.id_acao:
		_acao = _ex.id_acao
		_acertou = false
	if _ex.estado == ExecutorCorpoACorpo.Estado.ATIVO and not _acertou and multiplayer.is_server():
		var inicio := agora if _anterior == Vector3.INF else _anterior
		var espaco := _jogador.get_world_3d().direct_space_state
		var contatos := VARREDURA.query_segment(espaco, inicio, agora, .22, 1 | CAMADA_COLETA, [_jogador.get_rid()])
		for hit in contatos:
			if not hit.collider.has_meta("vegetacao_coletavel"): continue
			var alvo: Node = hit.collider.get_meta("vegetacao_coletavel")
			if not is_instance_valid(alvo): continue
			# A cabeça precisa tocar; o raio do peito impede colher através de paredes.
			var excluir: Array[RID] = [_jogador.get_rid(), alvo.corpo.get_rid(), hit.rid]
			var origem := _jogador.global_position + Vector3.UP * 1.05
			var no_alvo := Vector3(alvo.corpo.global_position.x, agora.y, alvo.corpo.global_position.z)
			if not VARREDURA.visible(espaco, origem, agora, 1, excluir): continue
			if not VARREDURA.visible(espaco, agora, no_alvo, 1, excluir): continue
			if alvo.receber_machadada(_jogador, _acao):
				_acertou = true
				_ex.pausar(.055)
				_jogador.add_camera_shake(.12)
				AudioFX.impact(_jogador.get_parent(), agora, .7)
				break
	_anterior = agora

func _tirar_visual() -> void:
	if is_instance_valid(_visual):
		_visual.get_parent().remove_child(_visual)
		_visual.queue_free()
	_visual = null

func _exit_tree() -> void:
	_tirar_visual()
