class_name MinkAnimado
extends Node3D
## Controlador de orelhas e caudas Mink penduradas no rig hierárquico.
## A malha continua sendo uma peça normal de raça; este nó só lhe dá um pivô
## vivo, mantendo a mesma aparência também na prévia de customização.

const LIMIAR_MOVIMENTO := 0.6
const LIMIAR_SUBINDO := 0.5
const SUAVIDADE := 8.0
const SEGMENTOS_DA_CAUDA := 5

var _tipo := "orelha" # "orelha" | "cauda"
var _lado := 1.0
var _base := Vector3.ZERO
var _t := 0.0
var _dono: CharacterBody3D = null
var _procurou_dono := false
var _segmentos: Array[Node3D] = []


## Troca o pivô estático criado por `Adornos` por um pivô animável sem perder
## posição, rotação, escala ou a marca que permite removê-lo ao trocar de raça.
static func vincular(peca: MeshInstance3D, tipo: String, lado: float) -> MinkAnimado:
	var pai := peca.get_parent() as Node3D
	if pai == null:
		return null
	var anim := MinkAnimado.new()
	anim.name = peca.name
	anim._tipo = tipo
	anim._lado = lado
	if peca.has_meta(Adornos.META_SEGUE_COR):
		anim.set_meta(Adornos.META_SEGUE_COR, peca.get_meta(Adornos.META_SEGUE_COR))
	# A origem da cauda é a face que encosta no Torso, não o centro da caixa.
	# Ela é calculada uma vez na montagem e `_process` nunca escreve `position`:
	# a conexão com o corpo permanece fixa, mesmo em pulo, queda ou corrida.
	if tipo == "cauda":
		var tamanho := peca.mesh.get_aabb().size if peca.mesh != null else Vector3(0.2, 0.2, 1.0)
		anim.position = peca.position - peca.transform.basis * Vector3(0.0, 0.0, tamanho.z * 0.5)
	else:
		anim.position = peca.position
	anim.rotation = peca.rotation
	anim.scale = peca.scale
	anim._base = anim.rotation
	pai.remove_child(peca)
	pai.add_child(anim)
	if tipo == "cauda":
		anim._montar_cauda(peca)
		peca.queue_free()
		return anim
	peca.name = "Geometria"
	peca.position = Vector3.ZERO
	peca.rotation = Vector3.ZERO
	peca.scale = Vector3.ONE
	anim.add_child(peca)
	return anim


## Substitui a caixa única por cinco elos. Cada elo nasce na ponta do anterior,
## logo pode curvar sem abrir uma fenda e sem deslocar a raiz presa no Torso.
func _montar_cauda(original: MeshInstance3D) -> void:
	var tamanho := original.mesh.get_aabb().size if original.mesh != null else Vector3(0.2, 0.2, 1.0)
	var comprimento := tamanho.z / float(SEGMENTOS_DA_CAUDA)
	var material := original.material_override
	var pai_do_elo: Node3D = self
	for i in SEGMENTOS_DA_CAUDA:
		var elo := Node3D.new()
		elo.name = "Segmento_%d" % i
		# O primeiro começa no encaixe; os demais começam exatamente na ponta
		# anterior. Só estas rotações recebem animação, nunca a posição da raiz.
		if i > 0:
			elo.position = Vector3(0.0, 0.0, comprimento)
		pai_do_elo.add_child(elo)
		_segmentos.append(elo)

		var malha := MeshInstance3D.new()
		malha.name = "Pelo_%d" % i
		var caixa := BoxMesh.new()
		var espessura := perfil_espessura_cauda(i)
		caixa.size = Vector3(tamanho.x * espessura, tamanho.y * espessura, comprimento + 0.008)
		malha.mesh = caixa
		malha.position = Vector3(0.0, 0.0, comprimento * 0.5)
		malha.material_override = material
		elo.add_child(malha)
		_adicionar_tufos(elo, caixa.size, comprimento, material, i)
		pai_do_elo = elo


## Perfil de lobo: raiz discreta, massa de pelo maior na metade final e uma
## ponta que volta a afinar. O penúltimo já começa a fechar a silhueta para a
## redução não parecer um corte brusco no último elo.
static func perfil_espessura_cauda(indice: int) -> float:
	const PERFIL := [0.68, 0.88, 1.14, 0.96, 0.66]
	return float(PERFIL[clampi(indice, 0, PERFIL.size() - 1)])


## Pequenos tufos sobrepostos quebram a silhueta de cubos lisos sem precisar de
## textura externa. Como são filhos do elo, acompanham exatamente a curvatura.
func _adicionar_tufos(elo: Node3D, tamanho: Vector3, comprimento: float,
		material: Material, indice: int) -> void:
	var pontos := [
		Vector3(tamanho.x * 0.48, tamanho.y * 0.34, comprimento * 0.26),
		Vector3(-tamanho.x * 0.48, tamanho.y * 0.34, comprimento * 0.54),
		Vector3(tamanho.x * 0.30, -tamanho.y * 0.48, comprimento * 0.76),
		Vector3(-tamanho.x * 0.30, -tamanho.y * 0.48, comprimento * 0.16),
	]
	for j in pontos.size():
		var tufo := MeshInstance3D.new()
		tufo.name = "Tufo_%d_%d" % [indice, j]
		var caixa := BoxMesh.new()
		caixa.size = Vector3(tamanho.x * 0.16, tamanho.y * 0.16, comprimento * 0.48)
		tufo.mesh = caixa
		tufo.position = pontos[j]
		tufo.rotation = Vector3((0.20 if j % 2 == 0 else -0.20),
			(0.18 if j < 2 else -0.18), 0.0)
		tufo.material_override = material
		elo.add_child(tufo)


func _process(delta: float) -> void:
	_t += delta
	var estado := estado_atual()
	var alvo := _base + _ajuste(estado)
	if _tipo == "cauda":
		# A raiz acompanha só o começo do gesto; o resto é distribuído pela cadeia
		# para formar uma curva contínua, em vez de um bloco rígido girando inteiro.
		alvo = _base + Vector3((alvo.x - _base.x) * 0.18,
			(alvo.y - _base.y) * 0.22, (alvo.z - _base.z) * 0.18)
	rotation = rotation.lerp(alvo, clampf(SUAVIDADE * delta, 0.0, 1.0))
	if _tipo == "cauda":
		_animar_elos_da_cauda(estado, delta)


func _animar_elos_da_cauda(estado: String, delta: float) -> void:
	var inclinacao := inclinacao_cauda(estado)
	var balanco := 0.0
	if estado == "andando":
		balanco = sin(_t * 7.0) * 0.30
	elif estado == "correndo":
		balanco = sin(_t * 11.0) * 0.58
	for i in _segmentos.size():
		var elo := _segmentos[i]
		var frac := float(i + 1) / float(_segmentos.size())
		# A ponta recebe mais do gesto e uma onda atrasada: é o que transforma os
		# cinco blocos numa cauda flexível durante o deslocamento.
		var onda := sin(_t * (11.0 if estado == "correndo" else 7.0) - float(i) * 0.82)
		var alvo := Vector3(inclinacao * (0.16 + frac * 0.46),
			balanco * (0.28 + frac * 1.12) + onda * 0.11 * frac, 0.0)
		elo.rotation = elo.rotation.lerp(alvo, clampf(SUAVIDADE * delta, 0.0, 1.0))


## Função pura para que os estados de corrida/pulo/queda possam ser testados
## sem precisar injetar teclas em um CharacterBody3D.
static func estado_de(no_chao: bool, velocidade: Vector3, correndo: bool) -> String:
	if not no_chao:
		return "pulando" if velocidade.y > LIMIAR_SUBINDO else "caindo"
	if Vector2(velocidade.x, velocidade.z).length() < LIMIAR_MOVIMENTO:
		return "repouso"
	return "correndo" if correndo else "andando"


## +X gira uma cauda que aponta para trás (+Z) para BAIXO; -X a ergue.
## Isto mantém explicitamente a linguagem pedida: desce no pulo, sobe na queda.
static func inclinacao_cauda(estado: String) -> float:
	match estado:
		"andando": return -0.10
		"correndo": return -0.20
		"pulando": return 0.62
		"caindo": return -0.58
	return 0.0


func _ajuste(estado: String) -> Vector3:
	if _tipo == "cauda":
		var balanco := 0.0
		if estado == "andando":
			balanco = sin(_t * 7.0) * 0.30
		elif estado == "correndo":
			balanco = sin(_t * 11.0) * 0.58
		return Vector3(inclinacao_cauda(estado), balanco, balanco * 0.34)

	# Orelhas têm uma oscilação discreta em repouso e vibram mais quando o Mink
	# ganha velocidade. O lado inverte o balanço para elas não dançarem juntas.
	var amplitude := 0.035
	var frequencia := 2.4
	if estado == "andando":
		amplitude = 0.10
		frequencia = 6.0
	elif estado == "correndo":
		amplitude = 0.18
		frequencia = 9.0
	elif estado == "pulando":
		amplitude = 0.12
		frequencia = 4.0
	elif estado == "caindo":
		amplitude = 0.08
		frequencia = 3.0
	return Vector3(0.0, 0.0, _lado * sin(_t * frequencia) * amplitude)


func estado_atual() -> String:
	var p := corpo()
	if p == null:
		return "repouso"
	return estado_de(p.is_on_floor(), p.velocity, _correndo(p))


func _correndo(p: CharacterBody3D) -> bool:
	return p.has_method("_is_sprinting") and bool(p.call("_is_sprinting"))


func corpo() -> CharacterBody3D:
	if _procurou_dono:
		return _dono
	_procurou_dono = true
	var no: Node = get_parent()
	while no != null:
		if no is CharacterBody3D:
			_dono = no as CharacterBody3D
			break
		no = no.get_parent()
	return _dono
