extends SceneTree
# ============================================================================
#  MEDIDOR DA INVESTIDA DA GURA GURA (Z) — o braço direito está ERGUIDO?
#
#  POR QUE ESTE MEDIDOR EXISTE
#  ---------------------------
#  O dono jogou e disse: "no Z a animação deveria levantar o braço direito
#  enquanto corre" — e não levanta. "Levantado" é adjetivo; adjetivo não fecha
#  bug. Aqui a pergunta vira NÚMERO, e o número é geométrico (posição do punho
#  no mundo), não o euler que a pose escreveu: dois eulers diferentes podem dar
#  o mesmo braço, e o euler sozinho já enganou este projeto antes.
#
#  MEDIDAS (todas no referencial do MODELO, que é quem gira com o personagem):
#    ELEV — ângulo entre a direção do braço e o CHÃO (para baixo).
#             0° = pendurado    90° = horizontal (apontando)    180° = pra cima
#           O membro pende no -Y local do nó (convenção do rig, ver a IK da
#           perna no ProceduralAnimator), então a direção é -basis.y.
#    ΔY   — altura do PUNHO em relação ao OMBRO, em metros. É o que o olho lê
#           como "erguido": punho acima do ombro => ΔY positivo.
#    FWD  — quanto o punho está À FRENTE do ombro, em metros (eixo -Z do
#           modelo). Separa "levantado" de "esticado apontando", que têm ELEV
#           parecido perto de 90° mas FWD muito diferente.
#
#  O braço ESQUERDO é medido junto de propósito: durante a investida ele NÃO é
#  tocado por pose nenhuma, então ele é o CONTROLE — a mesma corrida, o mesmo
#  quadro, o mesmo filtro de rigidez. Se o direito não se separar do esquerdo, a
#  pose não está chegando no rig.
#
#  ⚠️ CAMINHO DE VERDADE, não campo forçado: a investida é ligada por
#  `begin_charge("Z")` com a Gura Gura equipada — o mesmo caminho da tecla. A
#  armadilha conhecida deste projeto é a sonda que escreve o estado interno na
#  mão: ela mede o vazio, porque o jogo chega lá por outro caminho.
#
#  USO (precisa de janela: a corrida de referência lê TECLADO, e o MoveFrame só
#  aceita tecla com o mouse CAPTURADO):
#      DISPLAY=:1 godot --path . --script tools/dev_tests/medir_gura_rush.gd
# ============================================================================

const QUADROS_CORRIDA := 70    # corrida de referência (W+Shift)
const AMOSTRA_CORRIDA := 40    # só a segunda metade: a primeira é a transição
const QUADROS_RUSH := 36       # 0,6 s a 60 Hz = a investida inteira
const PULA_RUSH := 8           # blend da pose (taxa 25 => ~0,12 s p/ 95%)

var _teclas := {}

func _init() -> void:
	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	await _esperar(3.0)

	var p: Node = null
	for x in get_root().get_tree().get_nodes_in_group("player"):
		if x.is_multiplayer_authority():
			p = x
	if p == null:
		print("### SEM PLAYER — a porta 24565 pode estar ocupada")
		quit(1)
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		print("### mouse nao capturou — rode COM janela (DISPLAY=:1)")
		quit(1)
		return

	p.global_position = Vector3(0, 3, 0)
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	p._pitch = 0.0
	p.equip_fruit("gura_gura")
	await _quadros(30)

	# ---------------------------------------------------- 1) CORRIDA NORMAL
	_aplicar([KEY_W, KEY_SHIFT])
	var corrida := []
	for i in QUADROS_CORRIDA:
		await _quadros(1)
		if i >= QUADROS_CORRIDA - AMOSTRA_CORRIDA:
			corrida.append(_amostra(p))
	_aplicar([])
	await _quadros(45)     # solta tudo e deixa a pose voltar ao normal

	# ------------------------------------------------------- 2) INVESTIDA Z
	p.global_position = Vector3(0, 3, 0)
	p.velocity = Vector3.ZERO
	p._skill_cooldowns["Z"] = 0.0
	p.energy = p.max_energy
	# ESPERA O CHÃO, não um número fixo de quadros. Cair de 3 m leva ~38 quadros;
	# com uma espera fixa de 20 a investida começava NO AR, e aí a fase da marcha
	# só avança em parte dos quadros (`_phase` exige `on_floor`). O resultado era
	# um número de cadência que mudava entre rodadas do MESMO código — medição
	# que não repete não serve de antes/depois.
	var espera := 0
	while not p.is_on_floor() and espera < 240:
		await _quadros(1)
		espera += 1
	await _quadros(15)

	p.begin_charge("Z")            # CAMINHO DE VERDADE (mesmo da tecla Z)
	if not p._gura_rush_active:
		print("### begin_charge('Z') NÃO ligou a investida — nada a medir")
		quit(1)
		return

	var rush := []
	var fase_ini: float = p._proc_anim._phase
	for i in QUADROS_RUSH:
		await _quadros(1)
		if not p._gura_rush_active:
			break
		if i >= PULA_RUSH:
			rush.append(_amostra(p))
	var fase_fim: float = p._proc_anim._phase

	_aplicar([])
	print("")
	print("╔════════════════════════════════════════════════════════════════════╗")
	print("║  GURA GURA Z — O BRAÇO DIREITO ESTÁ ERGUIDO?                       ║")
	print("╚════════════════════════════════════════════════════════════════════╝")
	_relatar("CORRIDA NORMAL (W+Shift)", corrida)
	_relatar("INVESTIDA Z (gura_rush) — investida inteira", rush)
	# A pose ASSENTADA é o que o olho vê na maior parte da investida: os primeiros
	# quadros são a SUBIDA do braço (o filtro de rigidez tem que percorrer ~2,9
	# rad), e misturar a subida na média esconde onde o braço realmente chega.
	var assentada: Array = rush.slice(maxi(rush.size() - 12, 0))
	_relatar("INVESTIDA Z — pose ASSENTADA (últimos 12 quadros)", assentada)

	# A corrida tem que CONTINUAR lendo como corrida: a fase da marcha avança e
	# as coxas ainda varrem. Braço erguido com perna parada não é o pedido.
	print("")
	print("  marcha durante a investida: fase avançou %.2f rad (%.2f ciclos)" % [
		fase_fim - fase_ini, (fase_fim - fase_ini) / TAU])
	print("  varredura da coxa direita na investida: %.1f°  (na corrida: %.1f°)" % [
		_faixa(rush, "coxa_R"), _faixa(corrida, "coxa_R")])

	# VEREDITO: "erguido" = punho ACIMA do ombro e braço passando bem de 90°.
	# VEREDITO — a MEIA T tem duas metades, e as duas são obrigatórias.
	var elev_r: float = _media(assentada, "elev_R")
	var out_r: float = _media(assentada, "out_R")
	var fwd_r: float = _media(assentada, "fwd_R")
	var elev_l: float = _media(assentada, "elev_L")
	var dy_l: float = _media(assentada, "dy_L")
	print("")
	print("  separação direito−esquerdo (assentada): ELEV %+.1f° | FORA %+.2f" % [
		elev_r - elev_l, out_r - _media(assentada, "out_L")])

	# 1) DIREITO na horizontal e PARA O LADO. `out` alto com `fwd` baixo é o que
	#    separa o T do braço socando à frente — os dois têm ELEV perto de 90°.
	var direito_ok: bool = elev_r > 70.0 and elev_r < 110.0 and out_r > 0.60 and absf(fwd_r) < 0.35
	# 2) ESQUERDO NÃO subiu junto: continua na corrida, punho abaixo do ombro.
	var esquerdo_ok: bool = elev_l < 60.0 and dy_l < 0.0
	if direito_ok:
		print("  ✔ direito em T: ELEV %.1f° (horizontal), FORA %+.2f, FRENTE %+.2f" % [elev_r, out_r, fwd_r])
	else:
		print("  ✗ direito NÃO está em T: ELEV %.1f°, FORA %+.2f, FRENTE %+.2f" % [elev_r, out_r, fwd_r])
	if esquerdo_ok:
		print("  ✔ esquerdo NÃO levantado: ELEV %.1f°, punho %+.2f (abaixo do ombro)" % [elev_l, dy_l])
	else:
		print("  ✗ esquerdo SUBIU junto: ELEV %.1f°, punho %+.2f" % [elev_l, dy_l])
	quit()

# ---------------------------------------------------------------- amostragem
# Cinemática direta: lê onde os membros REALMENTE ficaram depois do filtro de
# rigidez, em vez do euler que a pose pediu. É a mesma disciplina do medidor de
# impacto do corpo a corpo — deslocamento do efetor, não ângulo autorado.
func _amostra(p: Node) -> Dictionary:
	var n: Dictionary = p._proc_anim._n
	var modelo: Node3D = p._char_model

	# ⚠️ MEDIR NO ESPAÇO DO MODELO, NUNCA NO MUNDO.
	# `PlayerRig._fit_model_to_body` põe escala NÃO-UNIFORME no `_char_model`
	# (`Vector3(ky, ky, ky*1.85)` — o voxel é engrossado 1,85× no Z). Isso
	# ESTICA tudo que aponta para frente/trás: no mundo, o mesmo braço "mede"
	# 0,82 m apontando à frente e 0,50 m pendurado, e o ângulo aparente
	# escorrega para a horizontal. Medido nesta sonda antes de eu perceber —
	# o comprimento do segmento variava com a pose, que é geometricamente
	# impossível num rig rígido e denunciou a anisotropia.
	# `affine_inverse()` do modelo desfaz a escala: dentro dele o rig volta a ser
	# rígido, FRENTE = -Z e CIMA = +Y, e o que se mede é a pose que o animador
	# de fato escreveu.
	var inv: Transform3D = modelo.global_transform.affine_inverse()
	var frente := Vector3(0, 0, -1)
	var d := {}
	for lado in ["R", "L"]:
		var ombro: Node3D = n["UpperArm_" + lado]
		var cotovelo: Node3D = n["ForeArm_" + lado]
		var p_ombro: Vector3 = inv * ombro.global_position
		var p_cotovelo: Vector3 = inv * cotovelo.global_position
		# Braço: direção OMBRO→COTOVELO, feita só de POSIÇÕES — imune a qualquer
		# escala que ainda sobre em nó intermediário.
		var dir_braco: Vector3 = (p_cotovelo - p_ombro).normalized()
		d["elev_" + lado] = rad_to_deg(Vector3.DOWN.angle_to(dir_braco))
		# PUNHO: não existe nó de mão no rig, então é a ponta do antebraço —
		# o -Y local do ForeArm, trazido para o espaço do modelo.
		var l_seg: float = p_ombro.distance_to(p_cotovelo)
		var dir_ante: Vector3 = (inv.basis * cotovelo.global_transform.basis * Vector3(0, -1, 0)).normalized()
		var punho: Vector3 = p_cotovelo + dir_ante * l_seg
		var rel: Vector3 = punho - p_ombro
		# Em FRAÇÃO DO ALCANCE (2 segmentos), não em unidade crua: assim o número
		# vale para qualquer porte. +1,00 = punho no topo do alcance, −1,00 =
		# braço pendurado, 0 = punho na altura do ombro.
		var alcance: float = maxf(2.0 * l_seg, 0.001)
		d["dy_" + lado] = rel.y / alcance
		d["fwd_" + lado] = rel.dot(frente) / alcance
		# LADO DE FORA do próprio braço. O braço direito do rig fica em -X e o
		# esquerdo em +X (é o sinal de `arm_out` na locomoção), então "abrir" é
		# um eixo diferente para cada lado. Sem normalizar por lado, o T do braço
		# direito apareceria como número negativo e o do esquerdo positivo.
		var fora := Vector3(-1, 0, 0) if lado == "R" else Vector3(1, 0, 0)
		d["out_" + lado] = rel.dot(fora) / alcance
		d["seg_" + lado] = l_seg
	# Coxa direita: prova de que a corrida continua acontecendo por baixo da pose.
	var p_quadril: Vector3 = inv * (n["Thigh_R"] as Node3D).global_position
	var p_joelho: Vector3 = inv * (n["Shin_R"] as Node3D).global_position
	d["coxa_R"] = rad_to_deg(Vector3.DOWN.angle_to((p_joelho - p_quadril).normalized()))
	return d

func _relatar(titulo: String, amostras: Array) -> void:
	print("")
	print("  ", titulo, "  (", amostras.size(), " quadros)")
	if amostras.is_empty():
		print("    (sem amostras)")
		return
	for lado in ["R", "L"]:
		print("    braço %s: ELEV méd %6.1f° (min %6.1f°, máx %6.1f°) | ΔY %+.2f | FORA %+.2f | FRENTE %+.2f" % [
			lado, _media(amostras, "elev_" + lado), _minimo(amostras, "elev_" + lado),
			_maximo(amostras, "elev_" + lado), _media(amostras, "dy_" + lado),
			_media(amostras, "out_" + lado), _media(amostras, "fwd_" + lado)])

func _media(a: Array, ch: String) -> float:
	if a.is_empty(): return 0.0
	var s := 0.0
	for x in a: s += float(x[ch])
	return s / a.size()

func _minimo(a: Array, ch: String) -> float:
	var m := INF
	for x in a: m = minf(m, float(x[ch]))
	return 0.0 if m == INF else m

func _maximo(a: Array, ch: String) -> float:
	var m := -INF
	for x in a: m = maxf(m, float(x[ch]))
	return 0.0 if m == -INF else m

func _faixa(a: Array, ch: String) -> float:
	if a.is_empty(): return 0.0
	return _maximo(a, ch) - _minimo(a, ch)

# ------------------------------------------------------------------ teclado
func _aplicar(teclas: Array) -> void:
	for k in _teclas.keys():
		if not teclas.has(k): _tecla(k, false)
	for k in teclas:
		if not _teclas.has(k): _tecla(k, true)
	_teclas.clear()
	for k in teclas: _teclas[k] = true

func _tecla(code: int, apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = apertada
	Input.parse_input_event(ev)

# `Engine.time_scale` volta a 1.0 todo quadro: o hit_stop do jogo põe a escala
# em 0.06 num impacto e isso multiplicaria o delta da física no meio da medição.
func _quadros(n: int) -> void:
	for i in n:
		Engine.time_scale = 1.0
		await physics_frame

func _esperar(s: float) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < int(s * 1000.0):
		await process_frame
