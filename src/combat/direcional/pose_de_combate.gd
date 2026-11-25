class_name PoseDeCombate
extends RefCounted
# ============================================================================
#  AVALIAÇÃO DA POSE — tempo de um golpe → pose do corpo. Função PURA.
#
#  Plano: docs/PLANO_COMBATE_HISTORIA.md (D5, D7). Não conhece nó, rig nem
#  executor: recebe a ficha e um instante, devolve números. Quem aplica no corpo é
#  o `AplicadorDePose`; quem decide o instante é o executor. Por ser pura, o teste
#  confere continuidade e chaves sem subir cena nenhuma.
#
#  ------------------------------------------------------------ A LINHA DO TEMPO
#      guarda (t = 0) → chaves do golpe → guarda (t = duração)
#  A guarda nas pontas é o que deixa dois golpes emendarem sem estalo: um termina
#  exatamente onde o próximo começa.
#
#  --------------------------------------------------------------- O TRAÇADO
#  Entre chaves, Hermite com tangente por diferença finita (Catmull-Rom não
#  uniforme): a mão PASSA pela chave do meio com velocidade, em vez de parar nela
#  como faria uma interpolação linear chave a chave — é a diferença entre um gancho
#  com arco e um braço que anda em segmentos. Nas pontas (guarda) a tangente é zero:
#  o golpe sai do repouso e volta a ele. A `curva` de cada chave redistribui o
#  tempo do trecho que chega nela (acelerar para o contato, perder força depois).
#
#  --------------------------------------------------------------- A SAÍDA
#  Um dicionário reaproveitável (o chamador passa o mesmo a cada quadro):
#      "rot":   { papel: Vector3 em RADIANOS }
#      "mao_R", "mao_L":           Vector3 — alvo do punho, espaço do corpo
#      "cotovelo_R", "cotovelo_L": Vector3 — direção do cotovelo, espaço do corpo
#      "pe_R", "pe_L", "joelho_R", "joelho_L": o mesmo para as pernas
#      "quadril":                  Vector3 — deslocamento do quadril, espaço do corpo
# ============================================================================

## Tudo o que é ALVO (não rotação) e se interpola igual: mãos, pés, polos e quadril.
const ALVOS := ["mao_R", "mao_L", "cotovelo_R", "cotovelo_L", "pe_R", "pe_L", "joelho_R", "joelho_L", "quadril"]

# "g:golpe:guarda" → linha do tempo pré-montada; "r:guarda:pico:herança" → par da
# reação; "q:pose:herança" → postura parada. Montar é caro (dicionários por chave); amostrar a cada
# quadro não pode ser.
static var _cache := {}


## Pose de uma chave, completando com a guarda o que ela não escreve.
static func da_chave(chave: ChaveDePose, guarda: ChaveDePose, papeis: Array) -> Dictionary:
	var rot := {}
	for papel in papeis:
		var graus: Vector3 = chave.rotacoes.get(papel, guarda.rotacoes.get(papel, Vector3.ZERO))
		rot[papel] = graus * (PI / 180.0)
	return {
		"rot": rot,
		"mao_R": chave.mao_direita if chave.usa_mao_direita else guarda.mao_direita,
		"cotovelo_R": chave.cotovelo_direito if chave.usa_mao_direita else guarda.cotovelo_direito,
		"mao_L": chave.mao_esquerda if chave.usa_mao_esquerda else guarda.mao_esquerda,
		"cotovelo_L": chave.cotovelo_esquerdo if chave.usa_mao_esquerda else guarda.cotovelo_esquerdo,
		"pe_R": chave.pe_direito if chave.usa_pes else guarda.pe_direito,
		"joelho_R": chave.joelho_direito if chave.usa_pes else guarda.joelho_direito,
		"pe_L": chave.pe_esquerdo if chave.usa_pes else guarda.pe_esquerdo,
		"joelho_L": chave.joelho_esquerdo if chave.usa_pes else guarda.joelho_esquerdo,
		"quadril": chave.quadril if chave.usa_pes else guarda.quadril,
	}


## Os papéis que alguma pose da lista gira. Fora deles o corpo é do animador.
static func papeis_de(chaves: Array) -> Array:
	var papeis := []
	for c in chaves:
		if c == null:
			continue
		for papel in (c as ChaveDePose).rotacoes:
			if not papeis.has(papel):
				papeis.append(papel)
	return papeis


static func limpar_cache() -> void:
	_cache.clear()


## Pose do golpe `t` segundos depois de começar. Escreve em `saida`.
static func amostrar(golpe: GolpeDirecional, guarda: ChaveDePose, t: float, saida: Dictionary) -> void:
	var linha: Dictionary = _linha(golpe, guarda)
	var tempos: PackedFloat32Array = linha["tempos"]
	var poses: Array = linha["poses"]
	var curvas: PackedInt32Array = linha["curvas"]
	var n := tempos.size()
	t = clampf(t, 0.0, tempos[n - 1])
	var i := 0
	while i < n - 2 and tempos[i + 1] <= t:
		i += 1
	var h := tempos[i + 1] - tempos[i]
	var u := (t - tempos[i]) / h if h > 0.0 else 1.0
	var k := ChaveDePose.aplicar_curva(curvas[i + 1], u)
	var h00 := 2.0 * k * k * k - 3.0 * k * k + 1.0
	var h10 := k * k * k - 2.0 * k * k + k
	var h01 := -2.0 * k * k * k + 3.0 * k * k
	var h11 := k * k * k - k * k

	var p0: Dictionary = poses[i]
	var p1: Dictionary = poses[i + 1]
	var t0: Dictionary = linha["tangentes"][i]
	var t1: Dictionary = linha["tangentes"][i + 1]
	var rot: Dictionary = saida.get("rot", {})
	rot.clear()   # papel de outra pose não pode sobrar com valor velho
	for papel in linha["papeis"]:
		if papel in ["Wrist_R", "Wrist_L"]:
			# A arma precisa girar pelo arco curto. Hermite de Euler podia inverter
			# o fio ao atravessar ±180° ou torcer o corte vertical para o plano lateral.
			rot[papel] = _orientacao(p0["rot"][papel], p1["rot"][papel], k)
			continue
		rot[papel] = h00 * p0["rot"][papel] + h10 * h * t0["rot"][papel] \
			+ h01 * p1["rot"][papel] + h11 * h * t1["rot"][papel]
	saida["rot"] = rot
	for chave in ALVOS:
		saida[chave] = h00 * p0[chave] + h10 * h * t0[chave] + h01 * p1[chave] + h11 * h * t1[chave]


## Pose de reação: sobe da guarda à pose do tranco, segura, volta. `u` = 0..1 do hitstun.
## `heranca`: de onde as duas poses completam o que não escrevem — a GUARDA DO ESTILO.
## Sem ela, cada pose herdaria de `guarda`; uma guarda erguida sem pés punha o tornozelo na
## origem do corpo (medido em 17/09: perna esticada e passo sem parar com o RMB segurado).
static func reacao(guarda: ChaveDePose, pico: ChaveDePose, u: float, saida: Dictionary, heranca: ChaveDePose = null) -> void:
	var base := heranca if heranca != null else guarda
	var chave_cache := "r:%d:%d:%d" % [guarda.get_instance_id(), pico.get_instance_id(), base.get_instance_id()]
	if not _cache.has(chave_cache):
		var papeis := papeis_de([base, guarda, pico])
		_cache[chave_cache] = [da_chave(guarda, base, papeis), da_chave(pico, base, papeis)]
	var a: Dictionary = _cache[chave_cache][0]
	var b: Dictionary = _cache[chave_cache][1]
	var peso := 0.0
	if u < 0.3:
		peso = ChaveDePose.aplicar_curva(ChaveDePose.Curva.DESACELERA, u / 0.3)
	elif u < 0.55:
		peso = 1.0
	else:
		peso = 1.0 - ChaveDePose.aplicar_curva(ChaveDePose.Curva.SUAVE, (u - 0.55) / 0.45)
	misturar(a, b, peso, saida)


## Uma pose de postura parada (a guarda, a guarda erguida). `heranca` como em `reacao`.
static func guarda(guarda_chave: ChaveDePose, saida: Dictionary, heranca: ChaveDePose = null) -> void:
	var base := heranca if heranca != null else guarda_chave
	var chave_cache := "q:%d:%d" % [guarda_chave.get_instance_id(), base.get_instance_id()]
	if not _cache.has(chave_cache):
		_cache[chave_cache] = da_chave(guarda_chave, base, papeis_de([base, guarda_chave]))
	var q: Dictionary = _cache[chave_cache]
	misturar(q, q, 0.0, saida)


## Mistura duas poses. Papel que só uma delas gira parte do repouso (zero) na outra.
## `saida` pode ser `a` ou `b` — os valores são lidos antes de escritos.
static func misturar(a: Dictionary, b: Dictionary, peso: float, saida: Dictionary) -> void:
	var novo := {}
	for papel in a["rot"]:
		var de: Vector3 = a["rot"][papel]
		var para: Vector3 = b["rot"].get(papel, Vector3.ZERO)
		novo[papel] = _orientacao(de, para, peso) if papel in ["Wrist_R", "Wrist_L"] else de.lerp(para, peso)
	for papel in b["rot"]:
		if not novo.has(papel):
			var para: Vector3 = b["rot"][papel]
			novo[papel] = _orientacao(Vector3.ZERO, para, peso) if papel in ["Wrist_R", "Wrist_L"] else Vector3.ZERO.lerp(para, peso)
	saida["rot"] = novo
	for chave in ALVOS:
		saida[chave] = (a[chave] as Vector3).lerp(b[chave], peso)


## Retorna Euler apenas como transporte no contrato da pose; mistura é quaternion.
static func _orientacao(de: Vector3, para: Vector3, peso: float) -> Vector3:
	var a := Quaternion.from_euler(de)
	var b := Quaternion.from_euler(para)
	return a.slerp(b, clampf(peso, 0.0, 1.0)).get_euler()


# ------------------------------------------------------------------ interno
static func _linha(golpe: GolpeDirecional, guarda: ChaveDePose) -> Dictionary:
	var chave_cache := "g:%d:%d" % [golpe.get_instance_id(), guarda.get_instance_id()]
	if _cache.has(chave_cache):
		return _cache[chave_cache]
	var todas: Array = [guarda]
	todas.append_array(golpe.chaves)
	var papeis := papeis_de(todas)
	var tempos := PackedFloat32Array([0.0])
	var curvas := PackedInt32Array([ChaveDePose.Curva.SUAVE])
	var poses: Array = [da_chave(guarda, guarda, papeis)]
	for c in golpe.chaves:
		tempos.append(c.tempo_em(golpe))
		curvas.append(c.curva)
		poses.append(da_chave(c, guarda, papeis))
	tempos.append(golpe.duracao())
	curvas.append(ChaveDePose.Curva.SUAVE)
	poses.append(poses[0])

	# Tangentes: zero nas pontas (sai e volta ao repouso), diferença finita no meio.
	var n := poses.size()
	var tangentes: Array = []
	for j in n:
		var tg := {"rot": {}}
		var dt := tempos[mini(j + 1, n - 1)] - tempos[maxi(j - 1, 0)]
		var ponta := j == 0 or j == n - 1 or dt <= 0.0
		for papel in papeis:
			tg["rot"][papel] = Vector3.ZERO if ponta else \
				((poses[j + 1]["rot"][papel] as Vector3) - poses[j - 1]["rot"][papel]) / dt
		for chave in ALVOS:
			tg[chave] = Vector3.ZERO if ponta else ((poses[j + 1][chave] as Vector3) - poses[j - 1][chave]) / dt
		tangentes.append(tg)

	var linha := {"papeis": papeis, "tempos": tempos, "curvas": curvas, "poses": poses, "tangentes": tangentes}
	_cache[chave_cache] = linha
	return linha
