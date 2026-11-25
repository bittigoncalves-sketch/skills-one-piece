extends SceneTree
# ============================================================================
#  PARKOUR NA REDE — fatia 4 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_parkour_rede.gd
#
#  O que os OUTROS jogadores veem: wall run (corpo inclinado, mão na parede),
#  escalada, borda e inclinação de curva. Um processo só: um segundo Player com
#  autoridade de outro peer cai no caminho remoto (`_remote_process`); a cada quadro
#  o teste copia para ele os campos `net_*` do jogador local, exatamente o que o
#  `MultiplayerSynchronizer` do `Main.gd` faz. O transporte é o do Godot; aqui se
#  prova que (1) os campos estão na lista de sincronização, (2) o dono os publica
#  certo e (3) a cópia remota reproduz a apresentação a partir deles.
# ============================================================================

const CAMPOS := ["net_velocity", "net_facing", "net_on_floor", "net_parkour", "net_escalando",
	"net_parede_lado", "net_subida", "net_inclinacao", "net_acao_clipe", "net_acao_tempo"]
const PAREDE_Z := -4.5
const FACE_ESC := -5.0

var _ok_n := 0
var _falhas := 0
var p: Node3D
var copia: Node3D
var _espelhar := true


func _init() -> void:
	await process_frame
	print("-- 1. os campos novos estão na sincronização --")
	var main = load("res://Main.gd").new()
	var cfg: SceneReplicationConfig = main._make_player_sync().replication_config
	var faltam := []
	for c in ["net_parkour", "net_escalando", "net_parede_lado", "net_subida", "net_inclinacao", "net_acao_clipe", "net_acao_tempo"]:
		if not cfg.has_property(NodePath(".:" + c)):
			faltam.append(c)
	main.free()
	_ok("Main._make_player_sync replica os 7 campos de parkour/ação (faltam: %s)" % str(faltam), faltam.is_empty())

	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_parkour_rede.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	p.set_meta("damage_immune", true)
	_caixa(Vector3(0, 6, PAREDE_Z - 0.5), Vector3(60, 12, 1), false)          # parede do wall run
	_caixa(Vector3(40, 3, FACE_ESC - 1.0), Vector3(6, 6, 2), true)            # parede escalável
	copia = modo.colocar_civil(current_scene, 2, Vector3(0, 0.81, 30))
	for i in 10:
		await physics_frame
	_ok("a cópia é remota (autoridade de outro peer)", not copia.is_multiplayer_authority())
	_espelhar_sempre()

	print("-- 2. wall run --")
	await _posicionar(Vector3(-14, 0.81, -3.9), -PI / 2.0)
	_tecla(KEY_W, true)
	for i in 30:
		await physics_frame
	await _espaco()
	for i in 14:
		await physics_frame
	var dono_incl := _inclinacao(p)
	var copia_incl := _inclinacao(copia)
	var anim_c = copia._proc_anim
	_ok("dono publica \"wall_run\", lado %d" % p.net_parede_lado, p.net_parkour == "wall_run" and p.net_parede_lado == -1)
	_ok("a cópia inclina o corpo igual: dono %.1f°, cópia %.1f°" % [dono_incl, copia_incl], absf(dono_incl - copia_incl) < 3.0 and absf(copia_incl) > 15.0)
	_ok("a cópia toca a pose do wall run com a mão do lado certo (peso %.2f, lado %d)" % [anim_c._wallrun_w, anim_c.parede_lado], anim_c._wallrun_w > 0.8 and anim_c.parede_lado == -1)
	_tecla(KEY_W, false)
	for i in 90:
		await physics_frame
	_ok("fora da parede a cópia endireita (%.1f°)" % _inclinacao(copia), absf(_inclinacao(copia)) < 1.0)

	print("-- 3. escalada, borda e subida --")
	await _posicionar(Vector3(40, 1.6, FACE_ESC + 0.7), 0.0, false)
	_tecla(KEY_W, true)
	var viu_esc := 0.0
	var viu_subida := 0.0
	for i in 300:
		await physics_frame
		if p.net_escalando:
			viu_esc = maxf(viu_esc, copia._proc_anim._climb_w)
		if p.net_parkour == "subindo_borda":
			viu_subida = maxf(viu_subida, copia._proc_anim._subida_w)
		if p.global_position.y > 6.5 and not p._parkour.escalando():
			break
	_tecla(KEY_W, false)
	_ok("a cópia mostra a escada (peso da pose %.2f)" % viu_esc, viu_esc > 0.8)
	_ok("a cópia mostra a subida da borda (peso %.2f)" % viu_subida, viu_subida > 0.5)

	print("-- 4. inclinação de curva --")
	await _posicionar(Vector3(0, 0.81, 20), 0.0)
	_tecla(KEY_W, true)
	_tecla(KEY_SHIFT, true)
	for i in 60:
		await physics_frame
	_tecla(KEY_D, true)
	var pico_d := 0.0
	var pico_c := 0.0
	for i in 20:
		await physics_frame
		pico_d = maxf(pico_d, absf(p._loco_chao.inclinacao))
		pico_c = maxf(pico_c, absf(copia._proc_anim.loco_inclinacao))
	for k in [KEY_W, KEY_SHIFT, KEY_D]:
		_tecla(k, false)
	_ok("a cópia recebe a inclinação da curva (dono %.1f°, cópia %.1f°)" % [rad_to_deg(pico_d), rad_to_deg(pico_c)], pico_d > deg_to_rad(3.0) and absf(pico_d - pico_c) < deg_to_rad(1.5))

	print("-- 5. roll (Q) --")
	p.capacidades = CapacidadesDoJogador.completas()
	await _posicionar(Vector3(0, 0.81, 20), 0.0)
	_tecla(KEY_Q, true)
	await physics_frame
	_tecla(KEY_Q, false)
	var viu_roll := 0.0
	for i in 20:
		await physics_frame
		if copia._proc_anim.acao_clipe == DashController.CLIPE:
			viu_roll = maxf(viu_roll, copia._proc_anim._acao_w)
	_ok("a cópia toca o clipe do roll (peso %.2f)" % viu_roll, viu_roll > 0.9)

	print("-- 6. dash aéreo direcional (Q + D) --")
	p.capacidades.recarga_dash_no_ar = 0.0
	for i in 45: await physics_frame # terminar o roll antes de iniciar outra esquiva
	await _posicionar(Vector3(0, 40, 20), 0.0, false)
	for i in 2: await physics_frame
	_tecla(KEY_D, true)
	_tecla(KEY_Q, true)
	var viu_dash := false
	for i in 12:
		await physics_frame
		if copia._proc_anim.acao_clipe == DashNoAr.CLIPES["direita"] and copia._proc_anim._acao_w > 0.5:
			viu_dash = true
	_tecla(KEY_Q, false)
	_tecla(KEY_D, false)
	_ok("a cópia reproduz o clipe direcional do dash aéreo", viu_dash)
	for i in 20: await physics_frame
	_tecla(KEY_D, true)
	_tecla(KEY_Q, true)
	var viu_alternado := false
	for i in 12:
		await physics_frame
		if copia._proc_anim.acao_clipe == DashNoAr.CLIPES_ALTERNADOS["direita"] and copia._proc_anim._acao_w > 0.5:
			viu_alternado = true
	_tecla(KEY_Q, false)
	_tecla(KEY_D, false)
	_ok("a cópia reproduz a troca de perna no dash seguinte", viu_alternado)

	_espelhar = false
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nPARKOUR_REDE %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## O papel do MultiplayerSynchronizer: depois de cada quadro de física, copia os
## campos replicados do dono para a cópia (ela os usa no quadro seguinte).
func _espelhar_sempre() -> void:
	while _espelhar:
		await physics_frame
		if not is_instance_valid(copia):
			return
		for c in CAMPOS:
			copia.set(c, p.get(c))


## Ângulo (graus) entre o "para cima" do modelo e a vertical, com sinal pelo lado.
func _inclinacao(quem: Node3D) -> float:
	var cima: Vector3 = quem._char_model.global_basis.y.normalized()
	var frente: Vector3 = -quem._char_model.global_basis.z
	var direita := frente.cross(Vector3.UP).normalized()
	return rad_to_deg(asin(clampf(-cima.dot(direita), -1.0, 1.0)))


func _posicionar(pos: Vector3, yaw: float, assentar := true) -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_SPACE, KEY_CTRL]:
		_tecla(k, false)
	p._parkour.cancelar()
	p._parkour.escalada._carencia = 0.0
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._yaw = yaw
	if assentar:
		for i in 40:
			await physics_frame


func _caixa(centro: Vector3, tamanho: Vector3, escalavel: bool) -> void:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = tamanho
	col.shape = caixa
	corpo.add_child(col)
	if escalavel:
		corpo.set_meta("escalavel", true)
	current_scene.add_child(corpo)
	corpo.global_position = centro


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
