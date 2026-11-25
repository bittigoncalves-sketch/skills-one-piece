extends Node
## Z da espada da história: giro contínuo; primeiro inimigo ou novo Z encerra.
## Não usa os slots da arena nem altera a imunidade concedida por outras skills.
const Sweep := preload("res://src/combat/SwordSweep.gd")
const ESTILO := preload("res://src/combat/direcional/estilos/espada.tres")
const META := &"giro_espada_ativo"
const VELOCIDADE := TAU * 1.6
const ENTRADA := 0.16
## Distância entre as palmas ao longo do cabo (direita junto à guarda).
const SEPARACAO_DAS_MAOS := 0.15
const EMPURRAO := 10.0
const RAIO := 0.12
const MASCARA := 15 | (1 << 20)
## ×10 em 23/10/2026: energia virou 100 por nível (era 10 no nível 1) (era 5 e 2/s).
const CUSTO := 50.0
const CUSTO_POR_SEGUNDO := 20.0

## DESLIGADO a pedido do dono (12/11/2026: "retira o giro cortante das espadas, Z fica sem por enquanto"). O código e os testes ficam; GATILHO para religar: o dono pedir o Z
## da espada de volta (os testes `test_giro_espada_historia` e `test_pegada_giro_espada` ligam por conta própria).
static var ligado := false
var ativo := false
var _arma: Node
var _jogador: Node3D
var _ex: ExecutorCorpoACorpo
var _tempo := 0.0
var _angulo := 0.0
var _base_anterior := Vector3.INF
var _ponta_anterior := Vector3.INF
var _pose: Dictionary
var _guarda: Dictionary
var _modelo: Node3D
var _rastro: WeaponTrail3D
var _marca_base: Node3D
var _marca_ponta: Node3D


func _ready() -> void:
	_arma = get_parent()
	_jogador = _arma.get_parent()
	_ex = _jogador.get("combate_direcional")
	# Depois da locomoção e do animador: o corpo inteiro e o encaixe giram juntos.
	process_physics_priority = 100
	_guarda = PoseDeCombate.da_chave(ESTILO.guarda, ESTILO.guarda,
		PoseDeCombate.papeis_de([ESTILO.guarda]))
	_pose = _guarda.duplicate(true)
	# Pegada à frente do corpo: o braço esquerdo alcança o cabo sem esticar a IK.
	_pose["mao_R"] = Vector3(0.24, 1.21, -0.20)
	_pose["cotovelo_R"] = Vector3(1, -0.25, 0.3)
	_pose["cotovelo_L"] = Vector3(-1, -0.3, -0.8)
	_pose["rot"]["Torso"] = Vector3(0, 0, -0.08)
	_pose["rot"]["SpineMid"] = Vector3(-0.06, 0, 0)
	_pose["rot"]["Head"] = Vector3.ZERO
	# Espada +Y radial (+X do corpo), fio -X tangencial (-Z). Socket vira PI em X.
	var lamina := Basis(Vector3.BACK, Vector3.RIGHT, Vector3.UP)
	_pose["rot"]["Wrist_R"] = (lamina * Basis(Vector3.RIGHT, PI)).get_euler()
	# Palmas em lados opostos do cabo, polegares voltados para a guarda.
	_pose["rot"]["Wrist_L"] = (lamina * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, PI)).get_euler()
	_marca_base = Node3D.new()
	_marca_ponta = Node3D.new()
	_jogador.add_child(_marca_base)
	_jogador.add_child(_marca_ponta)
	_rastro = WeaponTrail3D.new()
	_rastro.name = "RastroDoGiro"
	_rastro.life_time = 0.11
	_rastro.startColor = Color(0.86, 0.94, 1.0, 0.32)
	_rastro.target_base = _marca_base
	_rastro.target_tip = _marca_ponta
	_jogador.add_child(_rastro)
	_rastro.set_process(false)


func alternar() -> bool:
	if not ligado:
		return false
	if ativo:
		encerrar()
		return true
	if not _arma.ativa or not _ex.ator.pode_iniciar() \
			or _ex.estado not in [_ex.Estado.NEUTRO, _ex.Estado.GUARDA, _ex.Estado.BAIXANDO] \
			or _ex.get("_t_recuperacao_pendente") > 0.0:
		return false
	_modelo = _jogador.modelo_visual()
	if float(_jogador.energy) + 0.001 < CUSTO: return false
	if not is_instance_valid(_modelo):
		return false
	_jogador.gastar_energia(CUSTO)
	_preparar_pegada()
	_ex.cancelar(&"giro_da_espada")
	_jogador.entrada_combate_direcional.atualizar_defesa(false)
	_jogador.entrada_combate_direcional.esquecer_gesto()
	_tempo = 0.0
	_angulo = _modelo.rotation.y
	_base_anterior = Vector3.INF
	_ponta_anterior = Vector3.INF
	ativo = true
	_jogador.set_meta(META, true)
	_rastro.clear()
	_rastro.emit(true)
	return true


func _preparar_pegada() -> void:
	var direita := Basis.from_euler(_pose["rot"]["Wrist_R"])
	var esquerda := Basis.from_euler(_pose["rot"]["Wrist_L"])
	# Os alvos da IK são os PUNHOS; a pega está dentro da palma, após Hand_*.
	# Medir os encaixes do rig evita deixar a mão apenas próxima da espada.
	var pega_direita: Vector3 = _pose["mao_R"] + direita * _deslocamento_da_pega("R")
	_pose["mao_L"] = pega_direita - Vector3.RIGHT * SEPARACAO_DAS_MAOS \
		- esquerda * _deslocamento_da_pega("L")


func _deslocamento_da_pega(lado: String) -> Vector3:
	var punho := _modelo.find_child("Wrist_" + lado, true, false) as Node3D
	var pega := _modelo.find_child("Weapon_" + lado, true, false) as Node3D
	if punho != null and pega != null:
		return punho.to_local(pega.global_position) * punho.global_basis.get_scale()
	# Proporções do rig base quando o modelo não expõe encaixes autorais.
	return Vector3(0.013 if lado == "R" else -0.013, -0.104, -0.05)


func encerrar() -> void:
	if not ativo:
		return
	ativo = false
	if is_instance_valid(_jogador):
		_jogador.remove_meta(META)
		_jogador.entrada_combate_direcional.atualizar_defesa(false)
	if is_instance_valid(_rastro):
		_rastro.emit(false)
	_base_anterior = Vector3.INF
	_ponta_anterior = Vector3.INF


func _physics_process(delta: float) -> void:
	if ativo:
		if not _arma.ativa or not _jogador.corpo_livre_para_golpe() \
				or not is_instance_valid(_modelo) or _modelo != _jogador.modelo_visual():
			encerrar()
		else:
			var custo := CUSTO_POR_SEGUNDO * delta
			if float(_jogador.energy) < custo:
				encerrar()
			else:
				_jogador.gastar_energia(custo)
				_avancar(delta * Lentidao.fator(_jogador))
	if is_instance_valid(_rastro):
		_rastro._process(delta)


func _avancar(delta: float) -> void:
	_tempo += delta
	_angulo = wrapf(_angulo + VELOCIDADE * delta, -PI, PI)
	_modelo.rotation.y = _angulo
	var peso := smoothstep(0.0, ENTRADA, _tempo)
	var pose := {}
	PoseDeCombate.misturar(_guarda, _pose, peso, pose)
	# Sem pés ancorados no mundo: eles acompanham a rotação do quadril.
	_ex.ator.aplicar_pose(pose, 1.0, ESTILO, Vector3.ZERO, delta, true)
	var base: Vector3 = _arma.ponto(&"EspadaBase")
	var ponta: Vector3 = _arma.ponto(&"EspadaPonta")
	if base == Vector3.INF or ponta == Vector3.INF:
		encerrar()
		return
	_marca_base.global_position = base.lerp(ponta, 0.3)
	_marca_ponta.global_position = ponta
	if _base_anterior != Vector3.INF:
		_varrer(base, ponta)
	_base_anterior = base
	_ponta_anterior = ponta


func _varrer(base: Vector3, ponta: Vector3) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	var espaco := _ex.ator.espaco()
	var excluir := _ex.ator.excluir()
	var peito := _jogador.global_position + Vector3.UP * 1.1
	var amostras := maxi(2, ceili(base.distance_to(ponta) / RAIO))
	for i in amostras + 1:
		var u := float(i) / amostras
		var inicio := _base_anterior.lerp(_ponta_anterior, u)
		var fim := base.lerp(ponta, u)
		for contato in Sweep.contacts(espaco, inicio, fim, RAIO, MASCARA, excluir):
			var alvo: Node3D = contato.body
			if not alvo.is_in_group("enemy") or alvo.get("health") == null or float(alvo.get("health")) <= 0.0:
				continue
			if not Sweep.visible(espaco, peito, base, MASCARA, excluir) \
					or not Sweep.visible(espaco, base, contato.position, MASCARA, excluir):
				continue
			var direcao := alvo.global_position - _jogador.global_position
			direcao.y = 0.0
			if direcao.length_squared() < 0.001:
				direcao = _modelo.global_basis.x
			# Uma aplicação, pelo mesmo funil dos cliques; usa o dano do corte lateral.
			var dano: float = ESTILO.golpe_para(GolpeDirecional.Direcao.PARA_ESQUERDA).dano
			CombatResolver.aplicar(alvo, dano, 0, 0.0, contato.position,
				direcao.normalized() * EMPURRAO, 0.3, 0.0, false, _jogador)
			_ex.ator.tremer_camera(0.12)
			encerrar()
			return


func _exit_tree() -> void:
	encerrar()
	for no in [_rastro, _marca_base, _marca_ponta]:
		if is_instance_valid(no):
			no.queue_free()
