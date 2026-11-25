extends SceneTree
# ============================================================================
#  HIE HIE NO MI REFEITA (07/10/2026) — Z do Builder, todos os golpes congelam 0,7 s.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_hie_builder.gd
#
#  Pedido do dono: "todos os golpes irão congelar por 0.7 segundos [0,5 s de imunidade
#  depois]; deixar o novo teste de skill Z no lugar do Z antigo e melhorar o teste".
#  Modo História (mapa e progresso de TESTE), a Hie comida, teclas de verdade:
#    • a Hie é reconstruída: Z = `Z_ice` (Builder), X/C/V do código;
#    • Z: recua, 3 salvas de 8 estacas saindo ENTRE AS MÃOS, fere o boneco sem passar do
#      teto (192 da arena) e o CONGELA 0,7 s — com a física dele parada nesse tempo;
#    • imunidade de 0,5 s: congelar de novo logo depois não pega; passado, pega;
#    • X, C e o campo do V (código) congelam 0,7 s;
#    • o jogador congelado não anda; descongelado, anda;
#    • na arena, a Hie também tem o Z novo.
# ============================================================================

const MAPA := "res://tools/dev_tests/fixtures/mapa_baseplate.json"
const PROGRESSO := "user://test_hie_builder.json"
const MODO := "res://src/historia/ModoHistoria.gd"

var _ok_n := 0
var _falhas := 0
var p: Node3D
var cena: Node


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	SkillsPublicadas.recarregar()
	_ok("a Hie é reconstruída: Z = %s (Builder); X, C e V do código" % KitDoBuilder.skill("Z", "hie_hie").get("identificacao", {}).get("id", "?"),
		str(KitDoBuilder.skill("Z", "hie_hie").get("identificacao", {}).get("id", "")) == "Z_ice"
		and not KitDoBuilder.pelo_builder("hie_hie", "X") and not KitDoBuilder.pelo_builder("hie_hie", "C") and not KitDoBuilder.pelo_builder("hie_hie", "V"))
	_ok("a fruta de teste \"fruta do gelo\" saiu do catálogo", SkillsPublicadas.fruta("fruta_do_gelo").is_empty()
		and not "fruta_do_gelo" in PerfilDeFrutas.frutas_a_venda())
	var modo = load(MODO)
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(150)
	cena = current_scene
	p = get_first_node_in_group("player")
	(cena.get("progressao") as ProgressaoDoPersonagem).comer_fruta("hie_hie")
	await _fisica(20)
	_ok("comeu a Hie (%s)" % p.get("current_fruit_id"), str(p.get("current_fruit_id")) == "hie_hie")
	await _z()
	await _imunidade()
	await _codigo("X", 1, Vector3(0, 1, -8))
	await _codigo("C", 2, Vector3(0, 1, -6))
	await _campo_do_v()
	await _jogador_congelado()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	await _arena()
	print("\nHIE_BUILDER %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _z() -> void:
	await _no_lugar()
	var b := _boneco(Vector3(0, 1, -10))
	await _fisica(10)
	await _mirar_em(b.global_position + Vector3.UP * 0.4)
	var de := p.global_position
	var vida := float(b.health)
	_preparar("Z")
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	var e: Node = null
	var estacas := {}
	var longe_das_maos := 0.0
	var congelou_em := -1.0
	var descongelou_em := -1.0
	var fisica_parada := false
	var t := 0.0
	for i in 150:
		await physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if e == null:
			var achados := cena.find_children("SkillBuilder_Z_ice", "", true, false)
			e = achados[0] if not achados.is_empty() else null
		if is_instance_valid(e):
			for m in e.get("_manuais"):
				if is_instance_valid(m.no) and not estacas.has(m.no) and str(m.get("bloco", "")).begins_with("salva_"):
					estacas[m.no] = true
					var d := _osso("Hand_R")
					var l := _mao_esquerda()
					# Visto um quadro depois de nascer: já andou vel × passo (30 m/s → 0,5 m).
					var nasceu: Vector3 = (m.no as Node3D).global_position - (m.vel as Vector3) / Engine.physics_ticks_per_second
					if d.is_finite() and l.is_finite():
						longe_das_maos = maxf(longe_das_maos, nasceu.distance_to((d + l) * 0.5))
		var preso := bool(b.get_meta("is_frozen", false))
		if preso and congelou_em < 0.0:
			congelou_em = t
		if preso:
			fisica_parada = fisica_parada or not b.is_physics_processing()
		if congelou_em >= 0.0 and not preso and descongelou_em < 0.0:
			descongelou_em = t
	var recuou := p.global_position.z - de.z
	var dano := vida - float(b.health)
	var teto := 192.0 * PerfilDeFrutas.ESCALA_DA_ARENA
	_ok("Z: recua %.1f m (6,7)" % recuou, recuou > 5.0 and recuou < 8.0)
	_ok("Z: 3 salvas de 8 estacas (%d), saindo entre as mãos (pior %.2f m)" % [estacas.size(), longe_das_maos],
		estacas.size() == 24 and longe_das_maos < 0.25)
	_ok("Z: fere o boneco sem passar do teto (%.2f de %.2f)" % [dano, teto], dano > 0.0 and dano <= teto + 0.01)
	var duracao := descongelou_em - congelou_em
	_ok("Z: congela o boneco %.2f s (0,7) e a física dele pára enquanto isso (%s)" % [duracao, fisica_parada],
		congelou_em >= 0.0 and absf(duracao - 0.7) < 0.12 and fisica_parada)
	_ok("Z: a física do boneco volta depois (%s)" % b.is_physics_processing(), b.is_physics_processing())
	b.queue_free()
	await _fisica(40)


## 0,5 s de imunidade depois de descongelar.
func _imunidade() -> void:
	var b := _boneco(Vector3(3, 1, -5))
	await _fisica(10)
	IceFX.congelar(b)
	await _segundos(0.75)
	var solto := not bool(b.get_meta("is_frozen", false))
	await _segundos(0.2)
	IceFX.congelar(b)
	var pegou_imune := bool(b.get_meta("is_frozen", false))
	await _segundos(0.45)
	IceFX.congelar(b)
	var pegou_depois := bool(b.get_meta("is_frozen", false))
	_ok("imunidade: solto aos 0,75 s (%s); 0,2 s depois não congela (%s); 0,65 s depois congela (%s)" % [solto, pegou_imune, pegou_depois],
		solto and not pegou_imune and pegou_depois)
	b.queue_free()
	await _fisica(90)


## X e C (código): congelam 0,7 s.
func _codigo(slot: String, variante: int, onde: Vector3) -> void:
	await _no_lugar()
	var b := _boneco(onde)
	await _fisica(10)
	var dir: Vector3 = (b.global_position - p.global_position)
	dir.y = 0.0
	p.call("_fire_skill", slot, dir.normalized(), p.global_position + Vector3.UP * 0.5, 0.0, 0, "fruit", "hie_hie")
	var duracao := await _medir_gelo(b, 3.0)
	_ok("%s (código): congela %.2f s (0,7)" % [slot, duracao], absf(duracao - 0.7) < 0.12)
	b.queue_free()
	await _fisica(60)


## V: o campo congela 0,7 s, solta, 0,5 s imune, congela de novo.
func _campo_do_v() -> void:
	await _no_lugar()
	var b := _boneco(Vector3(2, 1, -2))
	await _fisica(10)
	p.call("_fire_skill", "V", Vector3.FORWARD, p.global_position, 0.0, 0, "fruit", "hie_hie")
	var primeira := await _medir_gelo(b, 4.0)
	var antes := Time.get_ticks_msec()
	var voltou := -1.0
	for i in 120:
		await physics_frame
		if bool(b.get_meta("is_frozen", false)):
			voltou = (Time.get_ticks_msec() - antes) / 1000.0
			break
	_ok("V (campo): congela %.2f s (0,7) e recongela %.2f s depois de soltar (≥ 0,5 de imunidade)" % [primeira, voltou],
		absf(primeira - 0.7) < 0.12 and voltou >= 0.45 and voltou < 1.0)
	b.queue_free()
	for n in cena.find_children("*", "", true, false):
		if n is Node3D and str(n.name).to_lower().contains("age"):
			pass
	await _segundos(1.0)


## O jogador congelado não anda.
func _jogador_congelado() -> void:
	await _no_lugar()
	await _segundos(1.5)                     # sai de qualquer imunidade
	var de := p.global_position
	IceFX.congelar(p)
	_tecla(KEY_W, true)
	await _segundos(0.55)
	var preso := Vector2(p.global_position.x - de.x, p.global_position.z - de.z).length()
	await _segundos(0.9)
	var solto := Vector2(p.global_position.x - de.x, p.global_position.z - de.z).length()
	_tecla(KEY_W, false)
	_ok("jogador congelado não anda (%.2f m em 0,55 s); descongelado anda (%.2f m)" % [preso, solto], preso < 0.1 and solto > 1.0)


func _arena() -> void:
	root.get_node("GameFlow").start_singleplayer()
	await _fisica(180)
	cena = current_scene
	p = null
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
	p.equip_fruit("hie_hie")
	p.set("combat_mode", "fruit")
	await _fisica(20)
	_preparar("Z")
	p.begin_charge("Z")
	await physics_frame
	p.release_charge("Z")
	await _fisica(5)
	_ok("arena: o Z da Hie é o novo (Builder)", not cena.find_children("SkillBuilder_Z_ice", "", true, false).is_empty())


# ------------------------------------------------------------------ apoio

## Espera congelar e mede quanto tempo fica (s; −1 se não congelou).
func _medir_gelo(b: Node, limite: float) -> float:
	var inicio := -1
	for i in int(limite * 60.0):
		await physics_frame
		var preso := bool(b.get_meta("is_frozen", false))
		if preso and inicio < 0:
			inicio = Time.get_ticks_msec()
		elif not preso and inicio >= 0:
			return (Time.get_ticks_msec() - inicio) / 1000.0
	return -1.0


func _preparar(slot: String) -> void:
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
	p.set("_intervalo_golpe", 0.0)


func _osso(nome: String) -> Vector3:
	var n := p.find_child(nome, true, false) as Node3D
	return n.global_position if n else Vector3.INF


func _mao_esquerda() -> Vector3:
	var n := p.find_child("ForeArm_L", true, false) as Node3D
	return n.global_transform * Vector3(0, -0.36, 0.02) if n else Vector3.INF


func _boneco(pos: Vector3) -> BonecoDeDuelo:
	var b := BonecoDeDuelo.new()
	b.position = pos
	cena.add_child(b)
	return b


func _no_lugar() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D]:
		_tecla(k, false)
	p.global_position = Vector3(0, 0.8, 0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.set("_pitch", 0.0)
	p.call("_update_pivot")
	await _fisica(20)
	for b in get_nodes_in_group("enemy"):
		if b is BonecoDeDuelo:
			b.call("parar")


func _mirar_em(ponto: Vector3) -> void:
	var cam: Camera3D = p.get("_cam")
	for i in 30:
		var d := (ponto - cam.global_position).normalized()
		p.set("_yaw", atan2(-d.x, -d.z))
		p.set("_pitch", asin(clampf(d.y, -1.0, 1.0)))
		p.call("_update_pivot")
		await process_frame


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)


func _segundos(s: float) -> void:
	await _fisica(int(round(s * Engine.physics_ticks_per_second)))


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
