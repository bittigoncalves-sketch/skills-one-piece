extends Node
## Brilliant Punk: investida de diamante. O servidor controla movimento e dano.
const NUMERO := 1201
const CUSTO := 200.0
const RECARGA := 5.0
const DURACAO := 1.6
const VELOCIDADE := 16.0
const RAIO := 1.7                      # contato: era 1,15, a investida passava ao lado do alvo
const ALCANCE_MIRA := 26.0             # mira assistida: alvo dentro deste alcance e do cone abaixo
const CONE_MIRA := 0.7                 # cos(~45°): meia abertura do cone de busca
const LANCAMENTO_HORIZONTAL := 22.0    # m/s do arremesso: ~17 m num inimigo do East Blue (decaimento 14 m/s²); 30 dava 32 m e jogava o alvo fora da ilha
const LANCAMENTO_VERTICAL := 9.0
const MULT_DANO_ALVO := 1.5            # o alvo do impacto leva mais que quem só pega a onda
const RAIO_EXPLOSAO := 4.5
const RAIO_DETECCAO := 9.0
const PARTICULAS_RADIAIS := 32
const MAX_ALVOS_ESTILHACOS := 48
const EMPURRAO_EXPLOSAO := 20.0
const DANO_DO_MOD := 15.0
const POSE := {"Torso": Vector3(-0.38, 0, 0), "UpperArm_R": Vector3(-1.15, 0, -0.18), "UpperArm_L": Vector3(0.45, 0, 0.22), "Thigh_R": Vector3(0.35, 0, 0), "Thigh_L": Vector3(-0.35, 0, 0)}

var controlador: Node
var ativo := false
var tempo := 0.0
var direcao := Vector3.FORWARD
var anterior := Vector3.ZERO
var spec: DamageSpec
var forma_anterior := 0


func iniciar() -> bool:
	var a: Player = controlador.ator
	if not controlador.servidor() or ativo or controlador.ativo or not controlador.fruta_ativa() or a.morrendo or not a.corpo_livre_para_golpe():
		return false
	if controlador.recarga_da_tecnica(NUMERO) > 0.0 or a.energy + 0.001 < CUSTO:
		return false
	# O servidor não controla a câmera de outro cliente; usa o facing replicado.
	var mira: Vector3 = controlador.olhar() if a._is_authority else RosaDosVentos.frente(a.net_facing)
	direcao = Vector3(mira.x, 0.0, mira.z).normalized()
	if direcao.length_squared() < 0.01:
		direcao = -a.global_basis.z.normalized()
		direcao.y = 0.0
		direcao = direcao.normalized()
	direcao = _direcao_assistida(direcao)
	a.gastar_energia(CUSTO)
	controlador._sincronizar_para_o_mod()
	controlador.iniciar_recarga(NUMERO, RECARGA)
	controlador.selecao = NUMERO
	controlador.ativo = true
	a.set_meta(ControladorFrutaMinePiece.META, controlador.get_instance_id())
	forma_anterior = controlador.forma_atual()
	controlador.mostrar_forma_kira(true, forma_anterior, direcao)
	ativo = true
	tempo = 0.0
	anterior = a.global_position + Vector3.UP * 0.9
	var dano := DANO_DO_MOD * MundoMinePiece.DANO_DA_ARENA_POR_DANO_DO_MOD * a.escala_de_dano_da_fruta("kira_kira")
	spec = DamageSpec.avulso(dano).para_cast()
	PoderDaFruta.ativacao(a, "kira_kira", CUSTO)
	return true


func _physics_process(delta: float) -> void:
	if not ativo:
		return
	var a: Player = controlador.ator
	if not is_instance_valid(a) or not controlador.fruta_ativa() or a.morrendo or not a.corpo_livre_para_golpe():
		cancelar()
		return
	var atual: Vector3 = a.global_position + Vector3.UP * 0.9
	var contato := _primeiro_contato(anterior, atual + direcao * 0.65)
	if not contato.is_empty():
		_explodir(contato.posicao, contato.alvo)
		cancelar()
		return
	anterior = atual
	# Interrompe antes do próximo passo se o corpo estiver chegando ao cenário.
	var frente := atual + direcao * (VELOCIDADE * delta + 0.55)
	if not _linha_do_mundo(atual, frente).is_empty():
		_explodir(atual)
		cancelar()
		return
	tempo += delta
	if tempo >= DURACAO:
		_explodir(atual)
		cancelar()


## Varrer o trecho percorrido e escolher o primeiro alvo, mesmo que o grupo esteja em outra ordem.
func _primeiro_contato(de: Vector3, ate: Vector3) -> Dictionary:
	var a: Player = controlador.ator
	var bloqueio := _linha_do_mundo(de, ate)
	if not bloqueio.is_empty():
		ate = (bloqueio.position as Vector3) - direcao * 0.02
	var primeiro := {}
	var menor := INF
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(a, alvo) or CombatResolver.e_fogo_amigo(alvo, a):
			continue
		var centro := AlvosDeGolpe.centro(alvo)
		var perto := Geometry3D.get_closest_point_to_segment(centro, de, ate)
		if AlvosDeGolpe.distancia_ao_corpo(alvo, perto) > RAIO:
			continue
		if not _linha_do_mundo(perto, centro).is_empty():
			continue
		var distancia := de.distance_squared_to(perto)
		if distancia < menor:
			menor = distancia
			primeiro = {"alvo": alvo, "posicao": perto}
	return primeiro


## Corpos vivos dividem a camada 1 com o cenário. Ignorá-los no raio de parede
## permite acertá-los sem permitir que um obstáculo atrás deles fique invisível.
func _linha_do_mundo(de: Vector3, ate: Vector3) -> Dictionary:
	if de.distance_squared_to(ate) < 0.000001:
		return {}
	var a: Player = controlador.ator
	var q := PhysicsRayQueryParameters3D.create(de, ate, 1, [a.get_rid()])
	for i in 64:
		var contato := a.get_world_3d().direct_space_state.intersect_ray(q)
		if contato.is_empty():
			return {}
		var no: Variant = contato.get("collider")
		if no is CharacterBody3D or (no is Node and AlvosDeGolpe.e_alvo(no)):
			var excluidos: Array[RID] = q.exclude
			excluidos.append(contato.rid)
			q.exclude = excluidos
			continue
		return contato
	return {"position": de} # não atravessar a cena se o limite for excedido


func _explodir(centro: Vector3, principal: Node3D = null) -> void:
	var a: Player = controlador.ator
	var direcoes := PackedVector3Array()
	# Distribuição na esfera inteira, inclusive acima e abaixo da explosão.
	for i in PARTICULAS_RADIAIS:
		var y := 1.0 - 2.0 * (float(i) + 0.5) / float(PARTICULAS_RADIAIS)
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var angulo := float(i) * 2.39996323
		direcoes.append(Vector3(cos(angulo) * r, y, sin(angulo) * r))
	var alvos := AlvosDeGolpe.todos(get_tree())
	var detectados: Array[Dictionary] = []
	for alvo in alvos:
		if not MundoMinePiece.atacavel(a, alvo) or CombatResolver.e_fogo_amigo(alvo, a):
			continue
		var distancia := AlvosDeGolpe.distancia_ao_corpo(alvo, centro)
		if distancia > RAIO_DETECCAO:
			continue
		var destino := AlvosDeGolpe.centro(alvo)
		if not _linha_do_mundo(centro, destino).is_empty():
			continue
		var rumo := destino - centro
		if rumo.length_squared() > 0.0001:
			detectados.append({"distancia": distancia, "direcao": rumo.normalized()})
	detectados.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.distancia) < float(y.distancia))
	for i in mini(detectados.size(), MAX_ALVOS_ESTILHACOS):
		direcoes.append(detectados[i].direcao)
	controlador.mostrar_explosao_kira(centro, direcoes, spec.dano * 0.4, principal != null)
	for alvo in alvos:
		if not MundoMinePiece.atacavel(a, alvo) or CombatResolver.e_fogo_amigo(alvo, a):
			continue
		if AlvosDeGolpe.distancia_ao_corpo(alvo, centro) > RAIO_EXPLOSAO:
			continue
		var centro_alvo := AlvosDeGolpe.centro(alvo)
		if not _linha_do_mundo(centro, centro_alvo).is_empty():
			continue
		var afastar := centro_alvo - centro
		afastar.y = 0.0
		if afastar.length_squared() < 0.001:
			afastar = direcao
		if alvo == principal:
			# O alvo do impacto é arremessado para longe na direção da investida.
			CombatResolver.aplicar(alvo, spec.dano * MULT_DANO_ALVO, spec.cast_id, spec.teto, centro,
				direcao * LANCAMENTO_HORIZONTAL + Vector3.UP * LANCAMENTO_VERTICAL, 0.7, 0.0, false, null, a)
		else:
			CombatResolver.aplicar(alvo, spec.dano, spec.cast_id, spec.teto, centro,
				afastar.normalized() * EMPURRAO_EXPLOSAO + Vector3.UP * 4.0, 0.4, 0.0, false, null, a)


## Mira assistida (22/11/2026): o jogador tinha dificuldade de acertar. Escolhe o inimigo mais alinhado
## dentro do cone, com linha de visão, e mira onde ele estará quando a investida chegar (previsão linear).
## A direção é fixada no início: é ela que a rede replica, então a investida não vira no meio do caminho.
func _direcao_assistida(base: Vector3) -> Vector3:
	var a: Player = controlador.ator
	var origem: Vector3 = a.global_position + Vector3.UP * 0.9
	var melhor: Node3D = null
	var melhor_cos := CONE_MIRA
	for alvo in AlvosDeGolpe.todos(get_tree()):
		if not MundoMinePiece.atacavel(a, alvo) or CombatResolver.e_fogo_amigo(alvo, a):
			continue
		var centro := AlvosDeGolpe.centro(alvo)
		var rumo := centro - origem
		rumo.y = 0.0
		var dist := rumo.length()
		if dist < 0.5 or dist - AlvosDeGolpe.distancia_ao_corpo(alvo, origem) > ALCANCE_MIRA:
			continue
		var c := base.dot(rumo / dist)
		if c <= melhor_cos or not _linha_do_mundo(origem, centro).is_empty():
			continue
		melhor_cos = c
		melhor = alvo
	if melhor == null:
		return base
	var ponto := AlvosDeGolpe.centro(melhor)
	var v: Variant = melhor.get("velocity")
	if v is Vector3:
		var tempo := origem.distance_to(ponto) / VELOCIDADE
		ponto += Vector3((v as Vector3).x, 0.0, (v as Vector3).z) * minf(tempo, DURACAO) * 0.8
	var novo := Vector3(ponto.x - origem.x, 0.0, ponto.z - origem.z)
	return novo.normalized() if novo.length_squared() > 0.01 else base


func velocidade(atual: Vector3) -> Vector3:
	return Vector3(direcao.x * VELOCIDADE, atual.y, direcao.z * VELOCIDADE)


func cancelar() -> void:
	if not ativo:
		return
	ativo = false
	if spec != null:
		CombatResolver.encerrar(spec.cast_id)
		spec = null
	if is_instance_valid(controlador):
		controlador.ativo = false
		var a: Player = controlador.ator
		if is_instance_valid(a):
			a.velocity.x = 0.0
			a.velocity.z = 0.0
			if int(a.get_meta(ControladorFrutaMinePiece.META, 0)) == controlador.get_instance_id():
				a.remove_meta(ControladorFrutaMinePiece.META)
		controlador.mostrar_forma_kira(false, forma_anterior, direcao)


func _exit_tree() -> void:
	cancelar()


func estado() -> Dictionary:
	return {"nome": "Brilliant Punk", "tecla": "Z", "selecionada": ativo, "custo": CUSTO,
		"recarga": controlador.recarga_da_tecnica(NUMERO), "recarga_total": RECARGA,
		"sem_energia": controlador.ator.energy + 0.001 < CUSTO, "bloqueada": controlador.ator.max_energy + 0.001 < CUSTO}
