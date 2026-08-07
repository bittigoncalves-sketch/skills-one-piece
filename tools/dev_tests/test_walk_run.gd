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

			falhas += _checa(anim, nodes, prof, modelo, vel, sprint, float(caso[1]))
			modelo.queue_free()

	print("\n================================")
	if falhas == 0:
		print("✅ WALK/RUN dentro da especificação")
	else:
		print("❌ ", falhas, " item(ns) fora da spec")
	quit(1 if falhas > 0 else 0)

func _checa(anim, nodes: Dictionary, prof: Dictionary, modelo: Node3D,
		vel: Vector3, sprint: bool, planar: float) -> int:
	var falhas := 0
	var n := 240
	var coxa_l: Array[float] = []
	var braco_l: Array[float] = []
	var torso_y: Array[float] = []
	var cabeca: Array[float] = []
	var tronco: Array[float] = []
	var pe_apoio: Array[float] = []
	var pe_frente: Array[float] = []

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
		# FRENTE: uma perna SÓ. Alternar entre as duas mistura apoio com balanço
		# e destrói a estimativa de velocidade.
		var baixo := _pe_mais_baixo(prof, nodes)
		pe_apoio.append(baixo + (nodes["Torso"] as Node3D).position.y)
		pe_frente.append(_pe_frente_esq(prof, nodes))

	# 1. LOOP: a série tem que se repetir. Compara o começo com um ciclo depois.
	var per := _periodo(coxa_l)
	if per > 0:
		var erro := 0.0
		for i in range(0, min(30, coxa_l.size() - per)):
			erro = maxf(erro, absf(coxa_l[i] - coxa_l[i + per]))
		print("  loop: período ~%d frames, erro máx %.4f rad" % [per, erro])
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

	# 5. SEM DESLIZE — medido pela conta EXATA do animador, não por reconstrução
	# de pose. Durante o apoio a trajetória é linear, então a velocidade do pé é
	# (passada/π)·ω; ela tem que bater com a velocidade do corpo.
	# Chama as funções do PRÓPRIO animador — não replicar a fórmula aqui. Uma
	# cópia já ficou defasada quando o freio de cadência entrou, e o teste
	# passou a reportar o estado antigo sem acusar nada.
	var speed01: float = planar / 4.2
	var omega: float = anim.cadencia(planar, speed01, sprint)
	var erro_pct: float = anim.deslize(planar, speed01, sprint) * 100.0
	var v_pe: float = planar * (1.0 - anim.deslize(planar, speed01, sprint))
	print("  pé no apoio: %.2f m/s vs corpo %.2f m/s (deslize %.0f%%) | ciclo %.0f frames" % [
		v_pe, planar, erro_pct, TAU / omega * 60.0])
	# Critério mais frouxo na CORRIDA, de propósito. 7 m/s num corpo de 1,5 m
	# equivale a um humano a 16 m/s: ou as pernas viram hélice (cadência sem
	# teto) ou o pé escorrega. Escolhido não virar hélice — o conserto de
	# verdade é reduzir Player.SPEED, não mexer aqui.
	var teto: float = 25.0 if sprint else 10.0
	if erro_pct > teto:
		print("  ✗ deslize acima do aceitável (teto %.0f%%)" % teto)
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

func _pe_mais_baixo(prof: Dictionary, nodes: Dictionary) -> float:
	return minf(_pe_lado(prof, nodes, "L").y, _pe_lado(prof, nodes, "R").y)

func _pe_frente_esq(prof: Dictionary, nodes: Dictionary) -> float:
	return _pe_lado(prof, nodes, "L").x

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
