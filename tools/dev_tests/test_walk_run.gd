extends SceneTree
# Valida a animação de WALK e RUN contra a especificação:
#  - loop perfeito (pose em fase p == pose em p+2π)
#  - pé sem deslizar: no apoio o pé anda para trás na velocidade do corpo
#  - pé plantado: o pé de apoio não sobe nem desce
#  - braços opostos às pernas
#  - movimento vertical do tronco a cada passo
#  - cabeça estável olhando para frente
#  - inclinação do tronco (corrida entre 10° e 15°)
# Uso: godot --headless --path . -s tools/dev_tests/test_walk_run.gd

const DT := 1.0 / 60.0

# ---------------------------------------------------------------- CRITÉRIOS
# O deslize e a cadência PUXAM PARA LADOS OPOSTOS, e nenhum ajuste satisfaz os
# dois: com pé cravado vale ω = π·v/passada, então cadência = v/passada. Com
# `Player.SPEED = 4.2` num corpo de 1,5 m (perna medida: 0,47 m no base, 0,61 m
# na nami) o pé cravado exige ~7,9 passos por segundo — o dobro de um humano
# correndo. A passada não resolve: ela já bate no teto geométrico
# 2·√(alcance²−H²) em qualquer velocidade acima de ~0,5, e alongá-la o bastante
# para zerar o deslize com a cadência de hoje pediria o quadril a 10 cm do chão.
#
# Medido em 2026-08-10 (base/WALK), variando só a altura do quadril e o freio de
# cadência para MANTER a cadência constante:
#   H=0,80·perna  passada 0,49 m  deslize 45%  amplitude da coxa  87°  (hoje)
#   H=0,70·perna  passada 0,59 m  deslize 34%  amplitude da coxa 108°
#   H=0,60·perna  passada 0,65 m  deslize 26%  amplitude da coxa 125°
# Ou seja: dá para comprar deslize com agachamento, e o preço é a silhueta.
#
# A decisão do projeto é MANTER o walk aprovado pelo dono. Então o teto de
# deslize aqui é o orçamento aceito — e a cadência ganhou teto próprio, para que
# ninguém "conserte" o deslize acelerando as pernas. O conserto de verdade é
# reduzir `Player.SPEED`; quando isso acontecer, estes dois tetos apertam.
const DESLIZE_TETO := 0.50        # fração da velocidade do corpo
const CADENCIA_TETO := {"WALK": 5.0, "RUN": 7.5}   # passos por segundo
# Distância máxima entre o deslize MEDIDO na pose e o que a conta do animador
# promete. É este item que pega a fórmula descolando da geometria (já aconteceu).
const COERENCIA_TOL := 0.06

func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	var falhas := 0
	for cid in ["base", "nami"]:
		for caso in [["WALK", 4.2, false], ["RUN", 7.0, true]]:
			var nome: String = "%s / %s" % [cid, caso[0]]
			var vel := Vector3(0, 0, -float(caso[1]))
			var sprint: bool = caso[2]
			print("\n===== ", nome, " =====")
			var data := CharacterBuilder.build_character(cid)
			var modelo: Node3D = data["node"]
			get_root().add_child(modelo)
			# O jogo normaliza TODO personagem para CHAR_TARGET_H antes de medir o
			# corpo. Sem repetir isso aqui, o `base` (3,6 m cru) mede perna de
			# 1,66 m e a cadência calculada não é a que roda em jogo.
			_normaliza(modelo, data.get("skinned", false))
			await process_frame
			var prof := BodyScanner.scan(modelo)
			var nodes: Dictionary = prof["nodes"]
			var anim := ProceduralAnimator.new()
			modelo.add_child(anim)
			anim.setup(prof)
			for i in 90:
				anim.update(vel, true, false, DT, 0.0, sprint)

			falhas += _checa(anim, nodes, prof, modelo, vel, sprint, float(caso[1]), String(caso[0]))
			modelo.queue_free()

	print("\n================================")
	if falhas == 0:
		print("✅ WALK/RUN dentro da especificação")
	else:
		print("❌ ", falhas, " item(ns) fora da spec")
	quit(1 if falhas > 0 else 0)

func _checa(anim, nodes: Dictionary, prof: Dictionary, modelo: Node3D,
		vel: Vector3, sprint: bool, planar: float, caso: String) -> int:
	var falhas := 0
	var n := 600
	var coxa_l: Array[float] = []
	var braco_l: Array[float] = []
	var torso_y: Array[float] = []
	var cabeca: Array[float] = []
	var tronco: Array[float] = []
	var pe_apoio: Array[float] = []
	# Séries POR LADO, em metros e relativas ao quadril:
	#   fr = quanto o pé está à frente;  al = altura do pé (com o bob do corpo,
	#   que é o que decide qual pé está no chão);  cru = altura sem o bob.
	var fr := {"L": [] as Array[float], "R": [] as Array[float]}
	var al := {"L": [] as Array[float], "R": [] as Array[float]}
	var cru := {"L": [] as Array[float], "R": [] as Array[float]}

	for i in n:
		anim.update(vel, true, false, DT, 0.0, sprint)
		coxa_l.append((nodes["Thigh_L"] as Node3D).rotation.x)
		braco_l.append((nodes["UpperArm_L"] as Node3D).rotation.x)
		torso_y.append((nodes["Torso"] as Node3D).position.y)
		cabeca.append(-(nodes["Head"] as Node3D).rotation.x - (nodes["Torso"] as Node3D).rotation.x)
		tronco.append(-(nodes["Torso"] as Node3D).rotation.x)
		# Geometria do pé a partir dos ângulos (vale nos dois tipos de rig).
		# ALTURA: somada ao bob do tronco, senão mede-se o pé subindo junto com o
		# quadril — que é justamente o movimento que a IK compensa de propósito.
		var bob: float = (nodes["Torso"] as Node3D).position.y
		for lado in ["L", "R"]:
			var p := _pe_lado(prof, nodes, lado)
			fr[lado].append(p.x)
			al[lado].append(p.y + bob)
			cru[lado].append(p.y)
		pe_apoio.append(minf(al["L"][i], al["R"][i]))

	# 1. LOOP: a série tem que se repetir. Compara o começo com um ciclo depois.
	var per := _periodo(coxa_l)
	if per > 0:
		var erro := 0.0
		for i in range(0, min(30, coxa_l.size() - per)):
			erro = maxf(erro, absf(coxa_l[i] - coxa_l[i + per]))
		# ATENÇÃO ao ler: este `per` é o ATRASO INTEIRO que melhor casa a série, e
		# costuma cair num MÚLTIPLO do ciclo — o ciclo real é fracionário (27,6
		# quadros) e nenhum atraso inteiro fecha nele. O ciclo de verdade sai
		# medido em `_ciclo()`, no bloco do deslize.
		print("  loop: fecha com atraso de %d frames, erro máx %.4f rad" % [per, erro])
		if erro > 0.05:
			print("  ✗ o ciclo não fecha (loop visível)")
			falhas += 1
	else:
		print("  ✗ não achei período — a marcha não está ciclando")
		falhas += 1

	# 2. BRAÇO OPOSTO À PERNA: correlação tem que ser negativa
	var corr := _corr(coxa_l, braco_l)
	print("  braço x perna: correlação %+.2f (tem que ser negativa)" % corr)
	if corr > -0.3:
		print("  ✗ braço não está oposto à perna")
		falhas += 1

	# 3. TRONCO sobe e desce
	var amp_y := _amp(torso_y)
	print("  bob do tronco: %.4f" % amp_y)
	if amp_y < 0.001:
		print("  ✗ tronco sem movimento vertical")
		falhas += 1

	# 4. PÉ PLANTADO: variação da altura do pé de apoio
	var var_apoio := _amp(pe_apoio)
	print("  altura do pé de apoio varia: %.4f" % var_apoio)
	if var_apoio > 0.02:
		print("  ✗ o pé de apoio sobe/desce (não está cravado)")
		falhas += 1

	# 5. DESLIZE — MEDIDO NA POSE QUE SAIU, nunca pela fórmula do animador.
	# Já houve uma cópia da fórmula aqui, e ela mascarou o estado real (ver
	# docs/erros.md, 2026-08-07). Chamar `anim.deslize()` para IMPRIMIR o número
	# tem o mesmo defeito com outra roupa: é o animador se dando nota.
	#
	# O que é medido: com o corpo a v, a posição do pé no chão é
	#   s(t) = v·t + frente(t)   ->   pé cravado  <=>  d(frente)/dt = −v.
	# `frente` vem das rotações que de fato ficaram nas juntas (já filtradas pela
	# rigidez), então o filtro entra na conta em vez de escapar dela.
	# Só o MIOLO do apoio conta — as trocas de pé são descartadas.
	var slips: Array[float] = []
	for i in range(2, n - 2):
		var lado: String = "L" if al["L"][i] < al["R"][i] else "R"
		if lado != ("L" if al["L"][i - 2] < al["R"][i - 2] else "R"):
			continue
		if lado != ("L" if al["L"][i + 2] < al["R"][i + 2] else "R"):
			continue
		slips.append((planar + (fr[lado][i + 1] - fr[lado][i - 1]) / (2.0 * DT)) / planar)
	var deslize: float = absf(_mediana(slips))
	var v_pe: float = planar * (1.0 - deslize)
	# Métricas do porte da marcha (é aqui que se vê se um conserto de deslize foi
	# pago com passada absurda ou perna de hélice).
	var passada := _amp(fr["L"])
	var ciclo := _ciclo(fr["L"])                    # frames por ciclo (2 passos)
	var cadencia: float = (2.0 / (ciclo * DT)) if ciclo > 0.0 else 0.0
	var quadril := 0.0
	for i in n:
		quadril = maxf(quadril, -minf(cru["L"][i], cru["R"][i]))
	var speed01: float = planar / 4.2
	var modelo_pct: float = anim.deslize(planar, speed01, sprint) * 100.0

	print("  passada %.3f m | cadência %.2f passos/s | quadril %.3f m | coxa amp %.1f°" % [
		passada, cadencia, quadril, rad_to_deg(_amp(coxa_l))])
	print("  pé no apoio: %.2f m/s vs corpo %.2f m/s (deslize MEDIDO %.0f%%) | ciclo %.1f frames" % [
		v_pe, planar, deslize * 100.0, ciclo])
	if deslize * 100.0 > DESLIZE_TETO * 100.0:
		print("  ✗ deslize acima do orçamento aceito (teto %.0f%%)" % [DESLIZE_TETO * 100.0])
		falhas += 1
	# 5b. A pose entrega o que a conta promete? Divergência aqui = fórmula e
	# geometria descolaram (passada saturando num lado só, filtro comendo a
	# amplitude, cadência batendo no teto sem ninguém ver).
	if absf(deslize * 100.0 - modelo_pct) > COERENCIA_TOL * 100.0:
		print("  ✗ pose x conta do animador: medido %.0f%% vs previsto %.0f%%" % [
			deslize * 100.0, modelo_pct])
		falhas += 1
	# 5c. CADÊNCIA com teto: o deslize só zera acelerando as pernas, e é
	# exatamente isso que arruína o walk aprovado. Sem este item, "consertar" o
	# deslize passa no teste destruindo o feel.
	var cad_teto: float = CADENCIA_TETO[caso]
	if cadencia > cad_teto:
		print("  ✗ marcha frenética: %.2f passos/s (teto %.1f)" % [cadencia, cad_teto])
		falhas += 1

	# 6. CABEÇA estável (olhar quase nivelado)
	var olhar := rad_to_deg(_media(cabeca))
	print("  olhar resultante: %+.1f° (perto de 0 = olhando pra frente)" % olhar)
	if absf(olhar) > 12.0:
		print("  ✗ cabeça não está estável")
		falhas += 1

	# 7. INCLINAÇÃO do tronco
	var inc := rad_to_deg(_media(tronco))
	print("  inclinação do tronco: %+.1f°" % inc)
	if sprint and (inc < 9.0 or inc > 16.0):
		print("  ✗ corrida fora dos 10-15° pedidos")
		falhas += 1
	if not sprint and (inc < 2.0 or inc > 9.0):
		print("  ✗ caminhada com inclinação fora do razoável")
		falhas += 1
	return falhas

# Pé de um lado, relativo ao quadril. A coxa carrega +lean para cancelar o tombo
# do torso, então a rotação do torso entra na conta — sem isso mede-se um
# balanço que não existe no mundo.
func _pe_lado(prof: Dictionary, nodes: Dictionary, lado: String) -> Vector2:
	var m: Dictionary = prof["metrics"]
	var L1: float = m.get("thigh_len", 0.3)
	var L2: float = m.get("shin_len", 0.3)
	var tronco_x: float = (nodes["Torso"] as Node3D).rotation.x
	var a: float = (nodes["Thigh_" + lado] as Node3D).rotation.x + tronco_x
	var b: float = a + (nodes["Shin_" + lado] as Node3D).rotation.x
	return Vector2(L1 * sin(a) + L2 * sin(b), -(L1 * cos(a) + L2 * cos(b)))

func _mediana(a: Array[float]) -> float:
	if a.is_empty():
		return 0.0
	var c := a.duplicate()
	c.sort()
	return c[c.size() / 2]

# Frames por ciclo, pelos cruzamentos ascendentes da média. Ao contrário do
# casamento por atraso inteiro (`_periodo`), aceita período FRACIONÁRIO — a
# marcha real dá 27,6 quadros, e nenhum atraso inteiro fecha nela.
func _ciclo(s: Array[float]) -> float:
	var med := _media(s)
	var cruz: Array[float] = []
	for i in range(1, s.size()):
		if s[i - 1] <= med and s[i] > med:
			cruz.append(float(i - 1) + (med - s[i - 1]) / maxf(s[i] - s[i - 1], 1e-9))
	if cruz.size() < 2:
		return 0.0
	return (cruz[cruz.size() - 1] - cruz[0]) / float(cruz.size() - 1)

# Menor período que repete a série. Pega o PRIMEIRO mínimo bom, não o global:
# múltiplos do período também casam, e o global pode cair num deles (foi assim
# que o teste reportou 91 frames num ciclo real de 15).
func _periodo(s: Array[float]) -> int:
	var janela := 40
	var melhor := 0
	var melhor_err := 1e9
	for p in range(5, min(160, s.size() - janela)):
		var e := 0.0
		for i in range(0, janela):
			e += absf(s[i] - s[i + p])
		e /= janela
		if e < melhor_err:
			melhor_err = e
			melhor = p
		if e < 0.004:      # já fecha bem: é o período fundamental
			return p
	return melhor if melhor_err < 0.02 else 0

func _corr(a: Array[float], b: Array[float]) -> float:
	var ma := _media(a)
	var mb := _media(b)
	var num := 0.0
	var da := 0.0
	var db := 0.0
	for i in a.size():
		var x: float = a[i] - ma
		var y: float = b[i] - mb
		num += x * y
		da += x * x
		db += y * y
	return num / maxf(sqrt(da * db), 0.0001)

func _media(a: Array[float]) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)

func _amp(a: Array[float]) -> float:
	var lo := 1e9
	var hi := -1e9
	for v in a:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo

# Mesma normalização de altura que o Player faz (CHAR_TARGET_H).
func _normaliza(modelo: Node3D, skinnado: bool) -> void:
	var ab: AABB = PlayerModelKit.skeleton_aabb(modelo) if skinnado else PlayerModelKit.model_aabb(modelo)
	if ab.size.y < 0.001:
		return
	var k: float = 1.5 / ab.size.y
	modelo.scale = Vector3(k, k, k)
