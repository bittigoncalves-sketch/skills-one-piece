extends SceneTree
# ============================================================================
#  WALL RUN — fatia 2 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_corrida_na_parede.gd
#
#  Pedido do dono: "a parede continua sendo uma parede e a gravidade permanece
#  normal"; pés perto da parede, mão do lado dela apoiando, torso inclinado;
#  velocidade parcialmente mantida; "não poderá ficar parado na parede"; dá para
#  saltar para longe. Teclas de verdade, jogador de verdade, mapa plano do Modo
#  História com paredes montadas aqui. Mede:
#    A entrada e arco: entra no Espaço, sobe e desce, perde velocidade, acaba
#      sozinho, pés e mão perto da parede, corpo inclinado e olhando ao longo dela;
#    B sprint corre mais longe que a corrida (velocidade preservada);
#    C salto para longe: sai da parede para fora, para cima e para a frente;
#    D parede → salto → parede do outro lado;
#    E Ctrl solta; F recusa devagar e de frente (de frente não gruda mais);
#    G o embalo continua quando a parede acaba;
#    H buffer do Espaço (0,15 s antes do alcance); I coyote (parede acaba no ar).
# ============================================================================

const PAREDE_Z := -4.5          # plano da parede A (normal +Z)
const PAREDE_B_Z := -0.9        # plano da parede B (normal −Z), 3,6 m à frente
const RAIA_Z := -3.9            # corre a 0,6 m da parede A

var _ok_n := 0
var _falhas := 0
var p: Node3D
var dt := 1.0 / 60.0
var _parede_b: StaticBody3D


func _init() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_corrida_na_parede.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	_parede(Vector3(0, 6, PAREDE_Z - 0.5), Vector3(60, 12, 1))

	print("-- A. corrida → Espaço → wall run --")
	await _correr([KEY_W], 30)
	var v_antes := _plano()
	var y0: float = p.global_position.y
	_tecla(KEY_SPACE, true)
	await physics_frame
	_tecla(KEY_SPACE, false)
	var entrou: bool = p._parkour.correndo_na_parede()
	var lado: int = p._parkour.parede.lado
	var v_entrada := _plano()
	var y_max := y0
	var dur := 0.0
	var vs := []
	var dist_max := 0.0
	var pe_min := INF
	var mao_min := INF
	var incl_max := 0.0
	var dot_frente := 1.0
	var vy_min := 0.0
	var dur_parede := 0.0
	while p._parkour.correndo_na_parede() and dur < 3.0:
		await physics_frame
		dur += dt
		if not p._parkour.correndo_na_parede():
			break
		y_max = maxf(y_max, p.global_position.y)
		vs.append(p._parkour.parede.velocidade_ao_longo())
		dist_max = maxf(dist_max, p.global_position.z - PAREDE_Z)
		vy_min = minf(vy_min, p.velocity.y)
		dur_parede = dur
		if dur > 0.2:
			var n: Dictionary = p._proc_anim._n
			pe_min = minf(pe_min, minf(_ate_parede(n.Foot_L), _ate_parede(n.Foot_R)))
			mao_min = minf(mao_min, _ate_parede(n.Hand_L))
			var cima: Vector3 = p._char_model.global_basis.y.normalized()
			incl_max = maxf(incl_max, rad_to_deg(asin(clampf(cima.dot(Vector3.BACK), -1.0, 1.0))))
			dot_frente = minf(dot_frente, (-p._char_model.global_basis.z).normalized().dot(Vector3.RIGHT))
	var v_saida := _plano()
	var caindo := true
	for i in 5:
		await physics_frame
	_tecla(KEY_W, false)
	var cai_ao_soltar: bool = not p._parkour.correndo_na_parede()
	_ok("entrou no Espaço correndo a %.1f m/s, parede à esquerda" % v_antes, entrou and lado == -1)
	_ok("guarda a velocidade: %.2f m/s na parede ≥ 90%% de %.2f" % [v_entrada, v_antes], v_entrada >= v_antes * 0.9)
	_ok("sobe e desce: ganhou %.2f m de altura (0,3–1,6 m) e a gravidade venceu (vy mín %.1f m/s)" % [y_max - y0, vy_min], y_max - y0 >= 0.3 and y_max - y0 <= 1.6 and vy_min < -1.0)
	var perde: bool = vs.size() > 10 and vs[vs.size() - 1] < vs[0] - 0.5
	_ok("perde velocidade na parede (%.2f → %.2f m/s)" % [vs[0] if vs.size() else 0.0, vs[vs.size() - 1] if vs.size() else 0.0], perde)
	_ok("não fica parado: acabou sozinho em %.2f s (≤ 1,8 s)" % dur, dur <= 1.85 and cai_ao_soltar)
	_ok("na corrida normal a parede dura o bastante para ler como wall run: %.2f s (≥ 0,75 s)" % dur_parede, dur_parede >= 0.75)
	_ok("fica rente à parede (centro a no máx. %.2f m)" % dist_max, dist_max < 0.9)
	_ok("pés perto da parede: %.2f m (≤ 0,25 m)" % pe_min, pe_min <= 0.25)
	_ok("mão do lado da parede apoia: %.2f m (≤ 0,25 m)" % mao_min, mao_min <= 0.25)
	_ok("corpo inclinado para longe da parede: %.0f° (15–35°)" % incl_max, incl_max >= 15.0 and incl_max <= 35.0)
	_ok("olha ao longo da parede (dot %.3f ≥ 0,95)" % dot_frente, dot_frente >= 0.95)
	_ok("G. o embalo continua na saída: %.2f m/s (≥ 2,2)" % v_saida, v_saida >= 2.2)

	print("-- B. sprint vai mais longe --")
	var x_corrida := await _distancia_na_parede([KEY_W])
	var x_sprint := await _distancia_na_parede([KEY_W, KEY_SHIFT])
	_ok("na parede: corrida %.2f m, sprint %.2f m (sprint > corrida)" % [x_corrida, x_sprint], x_sprint > x_corrida + 0.3)

	print("-- C. salto para longe --")
	await _correr([KEY_W], 30)
	await _espaco()
	for i in 12:
		await physics_frame
	var v_parede: float = p._parkour.parede.velocidade_ao_longo()
	_tecla(KEY_SPACE, true)
	await physics_frame
	_tecla(KEY_SPACE, false)
	var vs_salto: Vector3 = p.velocity
	_tecla(KEY_W, false)
	_ok("saiu da parede", not p._parkour.correndo_na_parede())
	_ok("para FORA (vz %.1f ≥ 5), para CIMA (vy %.1f ≥ 9) e para a FRENTE (vx %.1f ≥ 70%% de %.1f)" % [vs_salto.z, vs_salto.y, vs_salto.x, v_parede],
		vs_salto.z >= 5.0 and vs_salto.y >= 9.0 and vs_salto.x >= v_parede * 0.7)
	for i in 120:
		await physics_frame

	print("-- D. parede → salto → parede --")
	_parede_b = _parede(Vector3(0, 6, PAREDE_B_Z + 0.5), Vector3(60, 12, 1))
	await _correr([KEY_W], 30)
	await _espaco()
	for i in 10:
		await physics_frame
	await _espaco()
	var pegou_b := false
	var lado_b := 0
	for i in 60:
		await physics_frame
		if PAREDE_B_Z - p.global_position.z < 0.8 and not pegou_b:
			await _espaco()
			pegou_b = p._parkour.correndo_na_parede()
			lado_b = p._parkour.parede.lado
			break
	_tecla(KEY_W, false)
	_ok("pegou a parede do outro lado (lado %d, à direita)" % lado_b, pegou_b and lado_b == 1)
	_parede_b.queue_free()
	for i in 120:
		await physics_frame

	print("-- E. Ctrl solta --")
	await _correr([KEY_W], 30)
	await _espaco()
	for i in 8:
		await physics_frame
	_tecla(KEY_CTRL, true)
	await physics_frame
	_tecla(KEY_CTRL, false)
	var soltou: bool = not p._parkour.correndo_na_parede()
	_tecla(KEY_W, false)
	_ok("Ctrl larga a parede", soltou)
	for i in 90:
		await physics_frame

	print("-- F. recusas --")
	await _correr([KEY_W], 8)
	var v_devagar := _plano()
	await _espaco()
	var devagar_entrou: bool = p._parkour.correndo_na_parede()
	_tecla(KEY_W, false)
	_ok("devagar (%.1f m/s < 3,5) o Espaço é pulo, não wall run" % v_devagar, not devagar_entrou and v_devagar < 3.5)
	for i in 90:
		await physics_frame
	# De frente: corre direto para a parede (−Z).
	await _correr([KEY_W], 0, Vector3(5, 0.81, -1.0), 0.0)
	var de_frente := false
	for i in 40:
		await physics_frame
		if p.global_position.z - PAREDE_Z < 0.9:
			break
	await _espaco()
	for i in 20:
		await physics_frame
		de_frente = de_frente or p._parkour.correndo_na_parede()
	_tecla(KEY_W, false)
	_ok("de frente para a parede não entra no wall run (e não gruda mais)", not de_frente)
	for i in 90:
		await physics_frame

	print("-- H. buffer: Espaço no ar um pouco ANTES da parede começar --")
	# Parede C começa em x = 40. O Espaço no ar sai quando nenhuma sonda alcança
	# a parede ainda; dentro de 0,15 s ela entra no alcance.
	_parede(Vector3(55, 6, PAREDE_Z - 0.5), Vector3(30, 12, 1))
	await _correr([KEY_W], 0, Vector3(30, 0.81, RAIA_Z))
	while p.global_position.x < 36.0:
		await physics_frame
	await _espaco()                                   # pulo (no chão)
	while p.global_position.x < 38.9:
		await physics_frame
	var alcance_antes: bool = not p._parkour.parede._sondar_lados(p, Vector3.RIGHT).is_zero_approx()
	await _espaco()                                   # no ar, antes do alcance
	var entrou_buffer := false
	for i in 12:
		await physics_frame
		entrou_buffer = entrou_buffer or p._parkour.correndo_na_parede()
	_tecla(KEY_W, false)
	_ok("Espaço 0,15 s antes do alcance ainda entra (fora do alcance ao apertar: %s)" % (not alcance_antes), entrou_buffer and not alcance_antes)
	for i in 90:
		await physics_frame

	print("-- I. coyote: a parede acaba no meio do wall run --")
	_parede(Vector3(80.75, 6, PAREDE_Z - 0.5), Vector3(1.5, 12, 1))    # x 80..81,5: acaba no meio do arco
	await _correr([KEY_W], 0, Vector3(72, 0.81, RAIA_Z))
	while p.global_position.x < 79.6:
		await physics_frame
	await _espaco()
	var correu := false
	for i in 60:
		await physics_frame
		correu = correu or p._parkour.correndo_na_parede()
		if correu and not p._parkour.correndo_na_parede():
			break
	var no_ar: bool = not p.is_on_floor()
	await _espaco()
	var v_coyote: Vector3 = p.velocity
	_tecla(KEY_W, false)
	_ok("a parede acabou no ar (correu %s, no ar %s)" % [correu, no_ar], correu and no_ar)
	_ok("Espaço logo depois ainda salta da parede (vz %.1f ≥ 5, vy %.1f ≥ 9)" % [v_coyote.z, v_coyote.y], v_coyote.z >= 5.0 and v_coyote.y >= 9.0)
	for i in 90:
		await physics_frame

	var modo2 = load("res://src/historia/ModoHistoria.gd")
	modo2.set("mapa_forcado", "")
	modo2.set("progresso_forcado", "")
	print("\nCORRIDA_NA_PAREDE %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Corre `quadros` com as teclas a partir de `inicio` olhando para `yaw` (padrão:
## raia junto à parede A, correndo em +X).
func _correr(teclas: Array, quadros: int, inicio := Vector3(-14, 0.81, RAIA_Z), yaw := -PI / 2.0) -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE, KEY_CTRL]:
		_tecla(k, false)
	p._parkour.cancelar()
	p.global_position = inicio
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	for i in 40:
		await physics_frame
	for k in teclas:
		_tecla(k, true)
	for i in quadros:
		await physics_frame


func _distancia_na_parede(teclas: Array) -> float:
	await _correr(teclas, 45)
	await _espaco()
	var x0: float = p.global_position.x
	for i in 240:
		await physics_frame
		if not p._parkour.correndo_na_parede():
			break
	var d: float = p.global_position.x - x0
	for k in teclas:
		_tecla(k, false)
	for i in 90:
		await physics_frame
	return d


func _parede(centro: Vector3, tamanho: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	col.shape = caixa
	corpo.add_child(col)
	current_scene.add_child(corpo)
	corpo.global_position = centro
	return corpo


## Distância de um osso ao plano da parede A.
func _ate_parede(n: Node3D) -> float:
	return n.global_position.z - PAREDE_Z


func _plano() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _espaco() -> void:
	_tecla(KEY_SPACE, true)
	await physics_frame
	_tecla(KEY_SPACE, false)
	await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)
