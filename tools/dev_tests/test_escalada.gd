extends SceneTree
# ============================================================================
#  ESCALADA FRONTAL — fatia 3 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md (03/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_escalada.gd
#
#  Pedido do dono: "Corrida → salto → contato com parede → agarrar → escalar";
#  como uma escada; no topo "agarrar borda → subir → continuar correndo"; "Não
#  deve existir teleporte para cima"; só superfícies marcadas escalam. Teclas de
#  verdade, jogador de verdade, mapa plano do Modo História. Mede:
#    A corrida + salto contra a parede escalável → agarra sozinho;
#    B sobe com W na velocidade da escada, de frente para a parede;
#    C no topo sobe a borda SEM TELEPORTE e sai correndo por cima;
#    D pendurado na borda fica parado; W sobe;
#    E Espaço salta para trás; F Ctrl solta; G parede sem marca não agarra;
#    H S até o chão solta; I A/D anda de lado e para na quina;
#    J a loja diz quem escala e a peça montada carrega a meta `escalavel`.
# ============================================================================

const FACE_A := -5.0        # face da parede escalável A (normal +Z)
## Mais alta que o pulo do Civil (16 m/s contra 32 m/s² ≈ 4 m): com parede baixa o
## salto passa por cima e pousa no topo — certo, mas não é o que se mede aqui.
const TOPO_A := 6.0

var _ok_n := 0
var _falhas := 0
var p: Node3D
var dt := 1.0 / 60.0


func _init() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_escalada.json")
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	if p == null:
		print("❌ sem jogador"); quit(1); return
	p.set_meta("damage_immune", true)
	dt = 1.0 / float(Engine.physics_ticks_per_second)
	var esc = p._parkour.escalada
	_caixa(Vector3(0, TOPO_A / 2.0, FACE_A - 1.0), Vector3(6, TOPO_A, 2), true)
	_caixa(Vector3(12, 1.2, FACE_A - 1.0), Vector3(4, 2.4, 2), true)      # B: borda baixa
	_caixa(Vector3(-12, 2.0, FACE_A - 1.0), Vector3(4, 4.0, 2), false)    # G: sem marca

	print("-- A. corrida + salto contra a parede → agarra --")
	await _posicionar(Vector3(0, 0.81, 0), 0.0)
	_tecla(KEY_W, true)
	while p.global_position.z > FACE_A + 2.2:
		await physics_frame
	await _espaco()
	var agarrou := false
	for i in 60:
		await physics_frame
		if esc.ativo:
			agarrou = true
			break
	_ok("agarrou sozinho, sem tecla de agarrar", agarrou)

	print("-- B/C. sobe como escada e sobe a borda sem teleporte --")
	var vys := []
	var passo_max := 0.0
	var antes: Vector3 = p.global_position
	var viu_subindo := false
	var dot_parede := 1.0
	var estados := {}
	for i in 420:
		await physics_frame
		var d: float = (p.global_position - antes).length()
		passo_max = maxf(passo_max, d)
		antes = p.global_position
		estados[esc.estado] = true
		if esc.estado == "escalando":
			vys.append(p.velocity.y)
			dot_parede = minf(dot_parede, (-p._char_model.global_basis.z).normalized().dot(Vector3.FORWARD))
		viu_subindo = viu_subindo or esc.estado == "subindo"
		if not esc.ativo and viu_subindo:
			break
	var v_subida := 0.0
	for v in vys:
		v_subida = maxf(v_subida, v)
	await physics_frame
	var pos_fim: Vector3 = p.global_position
	var em_cima: bool = p.is_on_floor() and pos_fim.y > TOPO_A + 0.5 and pos_fim.z < FACE_A - 0.3
	var v_saida := Vector2(p.velocity.x, p.velocity.z).length()
	# 15 quadros (0,25 s), ainda sobre a plataforma: com a movimentação do Minecraft, 0,5 s depois
	# o corpo já saiu da borda no ar e o arrasto do ar (0,91/tick) o freia.
	for i in 15:
		await physics_frame
	var v_correndo := Vector2(p.velocity.x, p.velocity.z).length()
	_tecla(KEY_W, false)
	_ok("sobe a %.2f m/s (escada: 1,8–2,6 m/s)" % v_subida, v_subida >= 1.8 and v_subida <= 2.6)
	_ok("de frente para a parede enquanto escala (dot %.3f ≥ 0,95)" % dot_parede, dot_parede >= 0.95)
	_ok("passou pela borda (estados %s)" % str(estados.keys()), viu_subindo)
	_ok("sem teleporte: maior passo por quadro %.3f m (≤ 0,10)" % passo_max, passo_max <= 0.10)
	_ok("terminou EM CIMA, apoiado (y %.2f, z %.2f: 0,3 m além da face)" % [pos_fim.y, pos_fim.z], em_cima)
	_ok("sai da borda andando: %.2f m/s, e 0,25 s depois anda a %.2f m/s" % [v_saida, v_correndo], v_saida >= 2.0 and v_correndo >= 3.5)

	print("-- D. pendurado na borda --")
	await _posicionar(Vector3(12, 1.6, FACE_A + 0.6), 0.0, false)
	p.velocity = Vector3(0, 0, -3)
	for i in 6:
		await physics_frame
	var na_borda := false
	for i in 20:
		await physics_frame
		na_borda = na_borda or esc.estado == "borda"
	var y0: float = p.global_position.y
	for i in 30:
		await physics_frame
	var parado: bool = absf(p.global_position.y - y0) < 0.05 and esc.estado == "borda"
	_ok("agarra a borda baixa e fica pendurado (Δy %.3f m)" % (p.global_position.y - y0), na_borda and parado)
	_tecla(KEY_W, true)
	for i in 90:
		await physics_frame
		if not esc.ativo:
			break
	_tecla(KEY_W, false)
	_ok("W na borda sobe para cima dela (y %.2f)" % p.global_position.y, not esc.ativo and p.global_position.y > 2.4 + 0.5)

	print("-- E. Espaço salta para trás --")
	await _agarrar_em_a()
	_tecla(KEY_SPACE, true)
	await physics_frame
	_tecla(KEY_SPACE, false)
	var vs: Vector3 = p.velocity
	_ok("solta e salta para TRÁS (vz %.1f ≥ 5) e para cima (vy %.1f ≥ 8)" % [vs.z, vs.y], not esc.ativo and vs.z >= 5.0 and vs.y >= 8.0)

	print("-- F. Ctrl solta --")
	await _agarrar_em_a()
	_tecla(KEY_CTRL, true)
	await physics_frame
	_tecla(KEY_CTRL, false)
	await physics_frame
	_ok("Ctrl larga a parede", not esc.ativo)

	print("-- H. S até o chão solta --")
	await _agarrar_em_a()
	_tecla(KEY_S, true)
	for i in 120:
		await physics_frame
		if not esc.ativo:
			break
	_tecla(KEY_S, false)
	await physics_frame
	_ok("desce e solta no chão", not esc.ativo and p.global_position.y < 1.2)

	print("-- I. A/D de lado, para na quina --")
	await _agarrar_em_a()
	var x0: float = p.global_position.x
	var agarrado_i: bool = esc.ativo
	_tecla(KEY_D, true)
	for i in 30:
		await physics_frame
	var andou: float = p.global_position.x - x0
	for i in 150:
		await physics_frame
	_tecla(KEY_D, false)
	_ok("D anda de lado (%.2f m em 0,5 s, agarrado antes: %s)" % [andou, agarrado_i], agarrado_i and andou >= 0.5 and andou <= 1.0)
	_ok("para na quina sem cair (x %.2f ≤ 3,0, ainda escalando)" % p.global_position.x, esc.ativo and p.global_position.x <= 3.0)

	print("-- G. parede sem marca não agarra --")
	await _posicionar(Vector3(-12, 0.81, 0), 0.0)
	_tecla(KEY_W, true)
	while p.global_position.z > FACE_A + 2.2:
		await physics_frame
	await _espaco()
	var agarrou_g := false
	for i in 60:
		await physics_frame
		agarrou_g = agarrou_g or esc.ativo
	_tecla(KEY_W, false)
	_ok("parede sem `escalavel` não agarra", not agarrou_g)

	print("-- J. loja → mapa: quem escala é o que a loja marca --")
	var bib := MapaMontador.biblioteca_em_uso()
	_ok("construção, muro e rocha marcados de início; adereço não (stone_wall %s, fantasy_house %s, floresta_boulder_01 %s, barrel %s)"
		% [bib.escalavel("stone_wall"), bib.escalavel("fantasy_house"), bib.escalavel("floresta_boulder_01"), bib.escalavel("barrel")],
		bib.escalavel("stone_wall") and bib.escalavel("fantasy_house") and bib.escalavel("floresta_boulder_01") and not bib.escalavel("barrel"))
	var raiz := Node3D.new()
	current_scene.add_child(raiz)
	var muro := MapaMontador.montar_peca(raiz, DocumentoMapa.peca_modelo("t_muro", "stone_wall", bib.tamanho_padrao("stone_wall"), Vector3(40, 0, 40)))
	var barril := MapaMontador.montar_peca(raiz, DocumentoMapa.peca_modelo("t_barril", "barrel", bib.tamanho_padrao("barrel"), Vector3(44, 0, 40)))
	_ok("a peça montada carrega a meta (muro %s, barril %s)" % [muro.get_meta("escalavel", null), barril.get_meta("escalavel", null)],
		muro.get_meta("escalavel", false) == true and barril.get_meta("escalavel", true) == false)
	raiz.queue_free()

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nESCALADA %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


## Põe o jogador agarrado na parede A, no meio da altura: no ar, empurrando W
## contra ela (sem direção pedida ele não agarra — certo: é preciso ir de frente).
func _agarrar_em_a() -> void:
	await _posicionar(Vector3(0, 1.6, FACE_A + 0.7), 0.0, false)
	_tecla(KEY_W, true)
	for i in 15:
		await physics_frame
		if p._parkour.escalada.ativo:
			break
	_tecla(KEY_W, false)
	await physics_frame


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
