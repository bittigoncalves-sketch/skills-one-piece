class_name PosesDeSkill
extends RefCounted
## POSES DO SKILLS BUILDER (06/10/2026) — pedido do dono: criar as poses de um golpe
## (carregar, segurar, soltar, final) no próprio Builder e encadeá-las com transição.
##
## Uma pose é um deslocamento de rotação por JUNTA do rig A (os 13 papéis do
## `BodyScanner`), em graus no arquivo e em radianos aqui. É a MESMA conta do
## `ProceduralAnimator` do jogo (rotação = repouso + deslocamento), então a pose feita
## no Base da prévia é a pose que o jogador faz em jogo.
##
## Na timeline, um bloco de Animação com "Pose" escolhida segura aquela pose enquanto
## dura. Entre um bloco e o seguinte o corpo TRANSITA: aproximação exponencial com o
## tempo de "Transição" do bloco que entra (a mesma em prévia e jogo, e reproduzível
## passo a passo, que é o que a régua da prévia precisa). "Pulso" acrescenta uma
## vibração leve por cima (tensão de quem segura um golpe carregado).

const PAPEIS: Array = BodyScanner.ROLES
const MAX_POSES := 16
const LIMITE_GRAUS := 180.0
## Amplitude do pulso em pulso = 1 (radianos) e frequência (Hz).
const PULSO_AMPLITUDE := 0.06
const PULSO_HZ := 7.0


## A pose `id` da skill, em radianos (papel → Vector3). {} se não existe.
static func pose(skill: Dictionary, id: String) -> Dictionary:
	if id.is_empty():
		return {}
	for p: Variant in skill.get("poses", []):
		if p is Dictionary and str(p.get("id", "")) == id:
			var saida := {}
			var ossos: Dictionary = p.get("ossos", {})
			for papel in ossos:
				var g: Array = ossos[papel]
				saida[str(papel)] = Vector3(deg_to_rad(float(g[0])), deg_to_rad(float(g[1])), deg_to_rad(float(g[2])))
			return saida
	return {}


static func ids(skill: Dictionary) -> Array[String]:
	var saida: Array[String] = []
	for p: Variant in skill.get("poses", []):
		if p is Dictionary:
			saida.append(str(p.get("id", "")))
	return saida


## O bloco de Pose ativo no instante `t` (o que começou por último, se houver dois):
## {"pose": dict, "transicao": s, "pulso": 0..1} — ou {} se nenhum.
static func alvo_no_tempo(skill: Dictionary, t: float, parametros: Callable) -> Dictionary:
	var melhor: Dictionary = {}
	var inicio := -1.0
	for e: Dictionary in skill.get("eventos", []):
		if str(e.get("tipo", "")) != "animacao" or not bool(e.get("habilitado", true)):
			continue
		var p: Dictionary = parametros.call(skill, e)
		var id := str(p.get("pose", ""))
		if id.is_empty():
			continue
		var ini := float(e.inicio)
		if t >= ini and t < ini + float(e.duracao) and ini >= inicio:
			inicio = ini
			melhor = {"pose": pose(skill, id), "transicao": float(p.get("transicao", 0.15)),
				"pulso": float(p.get("pulso", 0.0))}
	return melhor


## Um passo de transição: `atual` anda para `alvo` (juntas ausentes = 0) no tempo
## `transicao` (~95 % em `transicao` s). Devolve a pose nova.
static func aproximar(atual: Dictionary, alvo: Dictionary, transicao: float, dt: float) -> Dictionary:
	var a := 1.0 if transicao <= 0.0001 else 1.0 - exp(-3.0 * dt / transicao)
	var saida := {}
	for papel in PAPEIS:
		var de: Vector3 = atual.get(papel, Vector3.ZERO)
		var para: Vector3 = alvo.get(papel, Vector3.ZERO)
		var v := de.lerp(para, a)
		if v.length_squared() > 1e-8:
			saida[papel] = v
	return saida


## A pose com o pulso por cima (t = segundos, para a fase).
static func com_pulso(p: Dictionary, pulso: float, t: float) -> Dictionary:
	if pulso <= 0.0:
		return p
	var saida := p.duplicate()
	var s := sin(t * TAU * PULSO_HZ) * PULSO_AMPLITUDE * pulso
	for papel in ["UpperArm_L", "UpperArm_R", "ForeArm_L", "ForeArm_R", "Torso"]:
		saida[papel] = (saida.get(papel, Vector3.ZERO) as Vector3) + Vector3(s, s * 0.5, 0)
	return saida


## Erros de uma lista de poses (vazio = ok). Usado pelo contrato (`Dados.validar`).
static func erros(poses: Variant) -> Array[String]:
	var e: Array[String] = []
	if poses == null:
		return e
	if not poses is Array or (poses as Array).size() > MAX_POSES:
		e.append("poses: uma lista de até %d poses." % MAX_POSES)
		return e
	var vistos := {}
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9_-]{1,64}$")
	for i in (poses as Array).size():
		var p: Variant = poses[i]
		var local := "poses[%d]" % i
		if not p is Dictionary:
			e.append(local + " precisa ser um objeto.")
			continue
		for chave in p:
			if not chave in ["id", "nome", "ossos"]:
				e.append(local + ": campo desconhecido " + str(chave) + ".")
		var id: Variant = p.get("id")
		if not id is String or re.search(id) == null or vistos.has(id):
			e.append(local + ": id inválido ou repetido.")
		else:
			vistos[id] = true
		var nome: Variant = p.get("nome")
		if not nome is String or (nome as String).length() < 1 or (nome as String).length() > 40:
			e.append(local + ": nome de 1 a 40 letras.")
		var ossos: Variant = p.get("ossos")
		if not ossos is Dictionary:
			e.append(local + ".ossos precisa ser um objeto.")
			continue
		for papel in ossos:
			var g: Variant = ossos[papel]
			if not str(papel) in PAPEIS:
				e.append(local + ".ossos: junta desconhecida " + str(papel) + ".")
			elif not g is Array or (g as Array).size() != 3 or not (g as Array).all(func(v): return (v is float or v is int) and absf(float(v)) <= LIMITE_GRAUS):
				e.append(local + ".ossos." + str(papel) + ": três ângulos de −180 a 180.")
	return e
