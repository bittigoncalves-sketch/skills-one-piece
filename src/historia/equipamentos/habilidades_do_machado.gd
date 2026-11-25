class_name HabilidadesDoMachado
extends Node
## Z e X do machado da história (17/10/2026). Mora como filho do `MachadoDaHistoria` e só
## age com o machado na mão (item ativo da barra). Quem aperta a tecla é a `HistoriaHud`.
##
##  Z — MACHADO GIRATÓRIO: o jogador ergue o machado atrás do ombro e o arremessa; ele sai
##      girando, fere o primeiro inimigo e cai ali. No instante do arremesso o item ativo vira
##      o COMBATE CORPO A CORPO ("luta"). Parado, o machado volta à mão quando o jogador
##      ENCOSTA nele (`MachadoLancado.recolhido`) ou escolhe o machado na barra de itens.
##  X — CORTE HORIZONTAL: o jogador executa o corte lateral do machado (as duas mãos no
##      cabo, fio à frente) e, quando a lâmina entra na fase ATIVA, solta uma meia-lua plana
##      (`CorteHorizontal`) que atravessa os inimigos à frente. Alterna golpe e contragolpe.
##
## Custos e recargas são números do corpo da história (vida 20, energia 10 no nível 1).

const Missoes := preload("res://src/historia/missoes/missoes.gd")

## ×10 em 23/10/2026: energia virou 100 por nível (era 10 no nível 1) (era 2 e 3).
const CUSTO := {"Z": 20.0, "X": 30.0}
const RECARGA := {"Z": 6.0, "X": 4.0}
const NOMES := {"Z": "Machado giratório", "X": "Corte horizontal"}
## Arremesso: ergue (0 → LEVANTAR), solta em LIBERAR, segue o braço até FIM.
const LEVANTAR := 0.15
const LIBERAR := 0.24
const FIM := 0.42
## Mira assistida do arremesso: inimigo a até 14° do retículo e 26 m.
const CONE_DE_MIRA := 14.0
const ALCANCE_DA_MIRA := 26.0

var recarga := {"Z": 0.0, "X": 0.0}
var lancado: MachadoLancado = null

var _arma: Node
var _jogador: Node3D
var _ex: ExecutorCorpoACorpo
var _t := -1.0                    # relógio do arremesso (< 0 = parado)
var _liberou := false
var _rumo := Vector3.FORWARD
var _guarda: Dictionary
var _pose_erguida: Dictionary
var _pose_solta: Dictionary
var _pose := {}
var _acao_x := -1
var _contragolpe := false
var _ligou_fase := false


func _ready() -> void:
	_arma = get_parent()
	_jogador = _arma.get_parent() as Node3D
	_ex = _jogador.combate_direcional
	# Depois do executor e do animador: a pose do arremesso vence no quadro.
	process_physics_priority = 100


# ------------------------------------------------------------------ interface
## Estado de uma tecla para a janela de técnicas.
func estado_da_tecla(slot: String) -> Dictionary:
	var custo: float = CUSTO[slot]
	return {"recarga": float(recarga[slot]), "recarga_total": float(RECARGA[slot]), "custo": custo,
		"bloqueada": float(_jogador.max_energy) + 0.001 < custo,
		"sem_energia": float(_jogador.energy) + 0.001 < custo}


func pode_agir() -> bool:
	if not _arma.ativa or _t >= 0.0 or not is_instance_valid(_ex) or _ex.ator == null:
		return false
	if not _jogador.corpo_livre_para_golpe() or not _ex.ator.pode_iniciar():
		return false
	return _ex.estado in [ExecutorCorpoACorpo.Estado.NEUTRO, ExecutorCorpoACorpo.Estado.GUARDA,
		ExecutorCorpoACorpo.Estado.BAIXANDO] and float(_ex.get("_t_recuperacao_pendente")) <= 0.0


func _liberada(slot: String) -> bool:
	return float(recarga[slot]) <= 0.0 and float(_jogador.energy) + 0.001 >= float(CUSTO[slot])


## Tecla Z. Devolve true se o arremesso começou.
func lancar() -> bool:
	if lancado != null or not pode_agir() or not _liberada("Z"):
		return false
	_jogador.gastar_energia(float(CUSTO["Z"]))
	recarga["Z"] = float(RECARGA["Z"])
	var aim: Vector3 = _jogador.mira_do_cast()["aim"]
	var rumo: Vector3 = _jogador.rumo_ao_ponto_mirado(aim, 40.0)
	# Quase horizontal: o machado não sobe aos céus nem se enterra aos próprios pés.
	rumo.y = clampf(rumo.y, -0.3, 0.3)
	_rumo = _mirar_no_inimigo(rumo.normalized())
	_montar_poses()
	_ex.cancelar(&"arremesso")
	_jogador.entrada_combate_direcional.atualizar_defesa(false)
	_jogador.entrada_combate_direcional.esquecer_gesto()
	_jogador.set_meta(META_ACAO, true)
	_t = 0.0
	_liberou = false
	return true


## Tecla X. Devolve true se o corte começou.
func cortar() -> bool:
	if not pode_agir() or not _liberada("X"):
		return false
	var direcao := GolpeDirecional.Direcao.PARA_ESQUERDA if not _contragolpe else GolpeDirecional.Direcao.PARA_DIREITA
	if not _ex.pedir_ataque(direcao) or _ex.estado != ExecutorCorpoACorpo.Estado.PREPARO:
		return false   # ficou no buffer ou foi recusado: não cobra nada
	_jogador.gastar_energia(float(CUSTO["X"]))
	recarga["X"] = float(RECARGA["X"])
	_acao_x = _ex.id_acao
	_contragolpe = not _contragolpe
	if not _ligou_fase:
		_ex.fase_mudou.connect(_ao_mudar_fase)
		_ligou_fase = true
	return true


## O machado deixou a mão por outro motivo (menu, troca de item): o arremesso em curso
## morre sem soltar nada — depois de solto, o voo é do próprio machado.
func abortar() -> void:
	if _t >= 0.0 and not _liberou:
		_encerrar_arremesso()
	_acao_x = -1


## Escolher o machado na barra com ele no chão o traz de volta (um machado só).
func recolher_lancado() -> void:
	if is_instance_valid(lancado):
		lancado.queue_free()
	lancado = null


# --------------------------------------------------------------------- quadro
func _physics_process(delta: float) -> void:
	for slot in recarga:
		recarga[slot] = maxf(0.0, float(recarga[slot]) - delta * Lentidao.fator(_jogador))
	if _t < 0.0:
		return
	if not is_instance_valid(_ex) or not _jogador.corpo_livre_para_golpe():
		_encerrar_arremesso()
		return
	_t += delta
	if not _liberou and _t >= LIBERAR:
		_soltar()
	if _t >= FIM:
		_encerrar_arremesso()
		return
	var pose := _pose
	if _t < LEVANTAR:
		PoseDeCombate.misturar(_guarda, _pose_erguida, smoothstep(0.0, LEVANTAR, _t), pose)
	else:
		PoseDeCombate.misturar(_pose_erguida, _pose_solta, smoothstep(LEVANTAR, LIBERAR, _t), pose)
	_ex.ator.aplicar_pose(pose, 1.0, _ex.estilo, Vector3.ZERO, delta)


## "Lança o machado no inimigo": com um inimigo vivo perto da mira (até `CONE_DE_MIRA`), o
## arremesso sai para o centro dele; sem ninguém, vai para onde o retículo aponta.
func _mirar_no_inimigo(rumo: Vector3) -> Vector3:
	var origem := _jogador.global_position + Vector3.UP * 0.4
	var melhor := rumo
	var menor_angulo := deg_to_rad(CONE_DE_MIRA)
	for no in _jogador.get_tree().get_nodes_in_group("enemy"):
		if not (no is Node3D) or not is_instance_valid(no) or no.get("health") == null or float(no.get("health")) <= 0.0:
			continue
		var centro := AlvosDeGolpe.centro(no as Node3D)
		var para := centro - origem
		if para.length() > ALCANCE_DA_MIRA or para.length() < 0.5:
			continue
		var angulo := rumo.angle_to(para.normalized())
		if angulo < menor_angulo:
			menor_angulo = angulo
			melhor = para.normalized()
	return melhor


func _soltar() -> void:
	_liberou = true
	var visual: Node3D = _arma.get("_visual")
	var origem := _jogador.global_position + Vector3.UP * 0.7 + _rumo * 0.5
	var orientacao := Basis.looking_at(_rumo, Vector3.UP)
	if is_instance_valid(visual):
		origem = visual.global_position
		orientacao = visual.global_basis
	lancado = MachadoLancado.lancar(_jogador, origem, _rumo, orientacao)
	lancado.recolhido.connect(_ao_recolher)
	lancado.acertou.connect(func(_alvo: Node3D) -> void:
		_ex.ator.tremer_camera(0.14)
		AudioFX.impact(_jogador.get_parent(), lancado.global_position, 0.8))
	_ex.ator.tremer_camera(0.08)
	# Mãos livres, imediatamente: o jogador passa ao combate corpo a corpo.
	var modo := _modo()
	if modo != null:
		modo.progressao.largar_machado()
	var hud := _jogador.get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("avisar"):
		hud.avisar("Machado lançado  ·  encoste nele para pegar de volta")


func _ao_recolher() -> void:
	recolher_lancado()
	var modo := _modo()
	if modo != null and modo.progressao.itens_da_barra().has("machado"):
		modo.progressao.ativar_item("machado")
		var hud := _jogador.get_tree().get_first_node_in_group("hud")
		if hud != null and hud.has_method("avisar"):
			hud.avisar("Machado de volta à mão")


func _encerrar_arremesso() -> void:
	_t = -1.0
	_liberou = false
	if is_instance_valid(_jogador):
		_jogador.remove_meta(META_ACAO)


func _ao_mudar_fase(id_acao: int, fase: GolpeDirecional.Fase) -> void:
	if id_acao != _acao_x or fase != GolpeDirecional.Fase.ATIVO:
		return
	_acao_x = -1
	var frente: Vector3 = _ex.ator.base_do_corpo() * Vector3.FORWARD
	var origem := _jogador.global_position + Vector3.UP * 0.3 + frente * 0.9
	CorteHorizontal.criar(_jogador, origem, frente)
	_ex.ator.tremer_camera(0.1)


func _modo() -> Node:
	return _jogador.get_tree().get_first_node_in_group("modo_historia")


# --------------------------------------------------------------------- poses
## Meta que congela o executor enquanto o arremesso comanda o corpo (o mesmo papel do
## `giro_espada_ativo` da espada).
const META_ACAO := &"machado_arremesso_ativo"


func _montar_poses() -> void:
	var estilo: EstiloCorpoACorpo = _ex.estilo
	var papeis := PoseDeCombate.papeis_de([estilo.guarda])
	_guarda = PoseDeCombate.da_chave(estilo.guarda, estilo.guarda, papeis)
	_pose = _guarda.duplicate(true)
	_pose_erguida = _guarda.duplicate(true)
	_pose_solta = _guarda.duplicate(true)
	# Ergue: cabo para cima e para trás, por cima do ombro direito; o tronco gira para trás.
	_aplicar_pegada(_pose_erguida, Vector3(0.26, 1.50, 0.02), Vector3(0.15, 0.95, 0.30), Vector3(-1, 0, 0))
	_pose_erguida["rot"]["Torso"] = Vector3(0, deg_to_rad(18.0), 0)
	_pose_erguida["rot"]["SpineMid"] = Vector3(deg_to_rad(-8.0), deg_to_rad(8.0), 0)
	_pose_erguida["rot"]["Head"] = Vector3(0, deg_to_rad(-10.0), 0)
	# Solta: braço esticado à frente, tronco desenrolado.
	_aplicar_pegada(_pose_solta, Vector3(0.20, 1.34, -0.55), Vector3(0.0, 0.25, -1.0), Vector3(-1, 0, 0))
	_pose_solta["rot"]["Torso"] = Vector3(0, deg_to_rad(-16.0), 0)
	_pose_solta["rot"]["SpineMid"] = Vector3(deg_to_rad(6.0), deg_to_rad(-6.0), 0)
	_pose_solta["rot"]["Head"] = Vector3(0, deg_to_rad(8.0), 0)


func _aplicar_pegada(pose: Dictionary, pega: Vector3, cabo: Vector3, fio: Vector3) -> void:
	var p := PegadaDoMachado.calcular(pega, cabo, fio)
	pose["mao_R"] = p["mao_R"]
	pose["mao_L"] = p["mao_L"]
	pose["cotovelo_R"] = Vector3(0.8, -0.4, 0.3)
	pose["cotovelo_L"] = Vector3(-0.8, -0.5, 0.3)
	pose["rot"]["Wrist_R"] = p["punho_R"]
	pose["rot"]["Wrist_L"] = p["punho_L"]
