class_name PonteBlender
extends RefCounted
# ============================================================================
#  A PONTE PARA O BLENDER — as duas conversões, num lugar só.
#
#  Usada por três pontas:
#    tools/exportar_para_blender.gd          (.res -> .glb)
#    tools/importar_do_blender.gd            (.glb -> .res)
#    tools/dev_tests/test_ida_e_volta_blender.gd  (prova que a pose sobrevive)
#
#  O teste faz a volta INTEIRA em memória, então ele exercita este arquivo — o
#  mesmo que as ferramentas usam. Duplicar a conversão no teste deixaria ele
#  passar com as ferramentas quebradas.
#
#  ------------------------------------------------------------------------
#  POR QUE O CLIPE SAI DAQUI REAMOSTRADO E ESTICADO NO TEMPO
#  ------------------------------------------------------------------------
#  Dois problemas do exportador glTF do Godot, os dois medidos:
#
#  1) Ele REAMOSTRA toda animação a **30 fps fixos**, e isso não é configurável
#     de GDScript (`GLTFState.bake_fps` só vale na importação — pôr 60 ou 120
#     devolve as mesmas 39 chaves de 1,25 s).
#
#  2) Ele trata a faixa `:rotation` como ROTAÇÃO: converte cada chave para
#     quaternion e interpola por **slerp**. O jogo interpola a mesma faixa em
#     **euler linear** (`value_track_interpolate`). Longe do gimbal as duas
#     curvas coincidem; perto dele, não. No `chapa_2`, entre duas chaves em que
#     a canela cruza x ≈ −π/2, o euler dispara de (−1,44; 2,38; −2,21) para
#     (−1,78; 3,65; −3,50) — a MESMA rotação andando pouco — e as duas
#     interpolações se afastam **6,04°** no meio do intervalo.
#
#  Esticar o tempo sozinho não resolve o (2): o exportador continua fazendo
#  slerp entre as MESMAS chaves decimadas, só que mais espaçadas. Medido: subir
#  a superamostragem de 3 para 10 só levava o desvio de 6,4° para 6,0° — platô.
#
#  A solução ataca os dois: **reamostrar o clipe com a interpolação do JOGO**
#  antes de exportar (aí cada chave nova já está na curva que o jogo toca, e o
#  slerp entre vizinhas tem pouco espaço para divergir) e **esticar o tempo** por
#  K para que a grade de 30 fps do exportador caia exatamente em cima delas.
#
#      FPS_ALVO = 30 · SUPERAMOSTRA  do movimento original
#
#  O fator viaja no NOME da animação (`punching__x2`), não numa constante que as
#  duas pontas teriam que adivinhar: assim a volta desfaz o esticamento no que
#  saiu daqui e deixa em paz um `.glb` autorado do zero no Blender.
#
#  Custo para quem edita: no Blender o clipe dura K vezes mais e tem K vezes
#  mais quadros. Para animar isso é a favor — mais resolução na linha do tempo.
# ============================================================================

const SUPERAMOSTRA := 2.0
const FPS_EXPORTADOR := 30.0                       # fixo no GLTFDocument
const FPS_ALVO := FPS_EXPORTADOR * SUPERAMOSTRA    # 60 fps do movimento original
const SUFIXO := "__x"
# Abaixo disto o papel é considerado parado (o Blender exporta faixa constante
# quando o osso não foi tocado).
const AMPLITUDE_MIN_DEG := 0.5

static func nome_exportado(nome: String) -> String:
	return "%s%s%d" % [nome, SUFIXO, int(SUPERAMOSTRA)]

# "punching__x2" -> {"nome": "punching", "escala": 2.0}
# "meu_clipe"    -> {"nome": "meu_clipe", "escala": 1.0}
static func nome_importado(bruto: String) -> Dictionary:
	var corte := bruto.rfind(SUFIXO)
	if corte > 0:
		var n := bruto.substr(corte + SUFIXO.length())
		if n.is_valid_float() and n.to_float() > 0.0:
			return {"nome": bruto.substr(0, corte), "escala": n.to_float()}
	return {"nome": bruto, "escala": 1.0}

# --------------------------------------------------------------- DECIMAÇÃO
# Tolerância padrão, em graus. Usada pelo `tools/bake_mixamo.gd` (no bake) e
# pelo `tools/importar_do_blender.gd` (na volta do Blender), para um clipe que
# atravessa o Blender não chegar denso de novo.
#
# POR QUE DECIMAR. Amostrar todo frame de toda faixa dava 54.548 chaves nos 29
# clipes — 145 por osso. Ninguém ajusta uma curva de 145 chaves, nem no Blender
# nem no `tools/anim_editor`. A 1° sobram ~23%, ~34 por osso, e a pose não muda
# mais que 1° em NENHUM instante.
const DECIMA_TOL_DEG := 1.0

# Decima TODAS as faixas VALUE do clipe, no lugar. Devolve o maior erro.
static func decimar(anim: Animation, tol_graus: float = DECIMA_TOL_DEG) -> float:
	if tol_graus <= 0.0:
		return 0.0
	var pior := 0.0
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_VALUE:
			pior = maxf(pior, decimar_faixa(anim, i, deg_to_rad(tol_graus)))
	return pior

# Remove as chaves que a interpolação LINEAR entre as vizinhas mantidas já
# reproduz dentro de `tol` (radianos, erro geodésico de ROTAÇÃO — não de euler:
# desdobrar o euler muda o número sem o membro se mexer, e já enganou uma
# medição antes; ver docs/ANIMACOES_MIXAMO.md, "Rebake de 2026-08-10").
# Primeira e última chave nunca saem. Devolve o maior erro cometido.
static func decimar_faixa(anim: Animation, ti: int, tol: float) -> float:
	var n := anim.track_get_key_count(ti)
	if n <= 2:
		return 0.0
	var t := []
	var v := []
	for k in n:
		t.append(anim.track_get_key_time(ti, k))
		v.append(anim.track_get_key_value(ti, k))
	var manter := [0]
	var pior := 0.0
	var i0 := 0
	for i in range(1, n):
		# candidata: descartar tudo entre i0 e i. Confere o erro em cada
		# descartada; se estourar, crava a chave anterior e recomeça dali.
		var erro := 0.0
		for j in range(i0 + 1, i):
			var u: float = (t[j] - t[i0]) / maxf(t[i] - t[i0], 0.0001)
			var lin: Vector3 = (v[i0] as Vector3).lerp(v[i], u)
			var d: Basis = Basis.from_euler(lin).inverse() * Basis.from_euler(v[j])
			erro = maxf(erro, absf(d.get_rotation_quaternion().get_angle()))
		if erro > tol:
			manter.append(i - 1)
			i0 = i - 1
		else:
			pior = maxf(pior, erro)
	if manter[manter.size() - 1] != n - 1:
		manter.append(n - 1)

	# reescreve a faixa só com as mantidas (de trás para frente, para os índices
	# não andarem embaixo da remoção)
	var guardar := {}
	for k in manter:
		guardar[k] = true
	for k in range(n - 1, -1, -1):
		if not guardar.has(k):
			anim.track_remove_key(ti, k)
	return pior


# ------------------------------------------------------------------- IDA
# Reamostra a FPS_ALVO com a interpolação do JOGO e devolve já esticado por
# SUPERAMOSTRA. Ver o cabeçalho: nenhum dos dois passos funciona sozinho.
static func preparar(src: Animation) -> Animation:
	var out := Animation.new()
	out.length = src.length * SUPERAMOSTRA
	out.loop_mode = src.loop_mode
	var passo := 1.0 / FPS_ALVO
	var n := int(round(src.length * FPS_ALVO)) + 1
	for i in src.get_track_count():
		if src.track_get_type(i) != Animation.TYPE_VALUE:
			continue
		var ti := out.add_track(Animation.TYPE_VALUE)
		out.track_set_path(ti, src.track_get_path(i))
		out.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		for fr in range(n):
			var t: float = minf(fr * passo, src.length)
			# euler linear = exatamente o que o `_apply_baked` toca
			out.track_insert_key(ti, t * SUPERAMOSTRA, src.value_track_interpolate(i, t))
	return out

# Monta a raiz que vai virar a cena glTF: o nó que tem o `Torso` como filho
# direto, solto dos nós de montagem do personagem.
#
# A raiz TEM que ser esse nó, e não o CharacterRoot. Duas razões, e as duas
# custaram um arquivo mudo:
#  • o `_convert_animation` do GLTFDocument resolve o caminho de cada faixa a
#    partir do PAI do AnimationPlayer, e os caminhos começam em `Torso`;
#  • a árvore real é `CharacterRoot_base > SkinPivot > GLBModel_base > Torso`, e
#    os dois nós do meio são de montagem, não do rig.
# Quando a faixa não resolve, o exportador DESCARTA a faixa e grava o arquivo
# assim mesmo — some sem erro.
static func soltar_rig(personagem: Node3D, adotante: Node) -> Node3D:
	var torso := personagem.find_child("Torso", true, false) as Node3D
	if torso == null:
		return null
	var modelo := torso.get_parent() as Node3D
	if modelo == null:
		return null
	# transformação acumulada dos nós de montagem (o SkinPivot do buggy gira
	# 180°; sem isso o boneco chegaria de costas no Blender)
	var acum := Transform3D()
	var n: Node3D = modelo
	while n != null and n != personagem:
		acum = n.transform * acum
		n = n.get_parent() as Node3D
	modelo.get_parent().remove_child(modelo)
	adotante.add_child(modelo)
	modelo.transform = acum
	return modelo

# ----------------------------------------------------------------- VOLTA
# Converte uma Animation vinda do glTF (faixas de rotação em quaternion, ou
# value de euler) para o formato do jogo: faixas VALUE de euler com o caminho
# canônico do RigContrato, e o tempo dividido por `escala`.
#
# Devolve {"anim": Animation|null, "faltando": [papéis], "parados": [papéis]}.
# `anim` vem null quando falta algum papel — importar meio clipe deixaria o
# membro congelado na pose de repouso, e isso não aparece em teste automático
# nenhum, só em jogo.
static func converter(src: Animation, escala: float = 1.0) -> Dictionary:
	var por_papel := {}
	for i in src.get_track_count():
		var tipo := src.track_get_type(i)
		if tipo != Animation.TYPE_ROTATION_3D and tipo != Animation.TYPE_VALUE:
			continue
		if tipo == Animation.TYPE_VALUE and not String(src.track_get_path(i)).ends_with(":rotation"):
			continue
		var papel := RigContrato.papel_de(src.track_get_path(i))
		if not RigContrato.PAI.has(papel):
			continue
		var chaves := []
		for k in src.track_get_key_count(i):
			var v = src.track_get_key_value(i, k)
			var e: Vector3
			if v is Quaternion:
				e = Basis(v).get_euler()
			elif v is Vector3:
				e = v
			else:
				continue
			chaves.append({"t": src.track_get_key_time(i, k), "e": e})
		if not chaves.is_empty():
			por_papel[papel] = chaves

	var faltando := []
	for papel in RigContrato.PAPEIS:
		if not por_papel.has(papel):
			faltando.append(papel)
	if not faltando.is_empty():
		return {"anim": null, "faltando": faltando, "parados": []}

	var out := Animation.new()
	out.length = src.length / escala
	out.loop_mode = src.loop_mode
	var parados := []
	for papel in RigContrato.PAPEIS:
		var ti := out.add_track(Animation.TYPE_VALUE)
		out.track_set_path(ti, RigContrato.faixa(papel))
		out.track_set_interpolation_type(ti, Animation.INTERPOLATION_LINEAR)
		var ant := Vector3.ZERO
		var primeiro := true
		var amp := 0.0
		var base: Basis = Basis.from_euler(por_papel[papel][0]["e"])
		for c in por_papel[papel]:
			var e: Vector3 = c["e"]
			if not primeiro:
				e = euler_continuo(e, ant)
			ant = e
			primeiro = false
			out.track_insert_key(ti, float(c["t"]) / escala, e)
			var d: Basis = base.inverse() * Basis.from_euler(c["e"])
			amp = maxf(amp, absf(d.get_rotation_quaternion().get_angle()))
		if rad_to_deg(amp) < AMPLITUDE_MIN_DEG:
			parados.append(papel)
	return {"anim": out, "faltando": [], "parados": parados}

# Mesma correção do `bake_mixamo._euler_continuo`: escolhe, entre os eulers
# equivalentes, o que fica mais perto da chave anterior. Sem isso a faixa LINEAR
# faz o caminho longo entre +179° e −179° e o membro dá uma volta num frame.
static func euler_continuo(e: Vector3, ant: Vector3) -> Vector3:
	var melhor := e
	var custo := INF
	for c in [e, Vector3(PI - e.x, e.y + PI, e.z + PI)]:
		var w := Vector3(
			c.x + TAU * roundf((ant.x - c.x) / TAU),
			c.y + TAU * roundf((ant.y - c.y) / TAU),
			c.z + TAU * roundf((ant.z - c.z) / TAU))
		var d := maxf(absf(w.x - ant.x), maxf(absf(w.y - ant.y), absf(w.z - ant.z)))
		if d < custo:
			custo = d
			melhor = w
	return melhor

static func achar_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := achar_animation_player(c)
		if r:
			return r
	return null

# Maior distância angular entre duas Animations do rig, amostrada a `passo`.
# Mede ROTAÇÃO, não euler: desdobrar o euler muda o número sem o membro se
# mexer, e isso já enganou uma medição neste projeto.
# Devolve {"desvio": graus, "papel": String, "t": segundos}.
static func comparar(a: Animation, b: Animation, passo: float = 1.0 / 120.0) -> Dictionary:
	var pior := 0.0
	var papel_pior := ""
	var t_pior := 0.0
	for papel in RigContrato.PAPEIS:
		var ta := RigContrato.acha_faixa(a, papel)
		var tb := RigContrato.acha_faixa(b, papel)
		if ta < 0 or tb < 0:
			continue
		var t := 0.0
		while t <= a.length:
			var ea = a.value_track_interpolate(ta, t)
			var eb = b.value_track_interpolate(tb, t)
			if ea is Vector3 and eb is Vector3:
				var d: Basis = Basis.from_euler(ea).inverse() * Basis.from_euler(eb)
				var g := rad_to_deg(absf(d.get_rotation_quaternion().get_angle()))
				if g > pior:
					pior = g
					papel_pior = papel
					t_pior = t
			t += passo
	return {"desvio": pior, "papel": papel_pior, "t": t_pior}
