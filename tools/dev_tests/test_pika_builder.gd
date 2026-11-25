extends SceneTree
# ============================================================================
#  PIKA PIKA NO MI REFEITA NO BUILDER — em jogo (06/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_pika_builder.gd
#
#  Lê a Pika PUBLICADA NO PROJETO (`tools/criar_pika_pika.gd` → res://mapas/skills) e
#  confere o pedido do dono, com o jogador de verdade (Modo História, mapa e progresso
#  de TESTE), pelas TECLAS (begin_charge/release_charge):
#    Z — um raio só, instantâneo, até 40 m;
#    X — sobe (do chão), vira luz, zigue-zague esquerda/direita/esquerda (21 m) e a
#        esfera que explode no chão no fim (sem cair antes dela);
#    C — sai PARA O ALVO (mesmo atrás do jogador), fere várias vezes, soltar encerra;
#    V — segue o código da Pika.
#
#  RODADA 2 (07/10/2026, pedido do dono):
#    Z — segurando NÃO sai nada e a estrela cresce NA MÃO; soltar dispara para onde o
#        retículo está NO SOLTAR; o raio nasce na mão e passa no retículo; o empurrão
#        vai de 1× (toque) a 1,5× (carga cheia);
#    X — inimigo perto do caminho: termina EM CIMA dele (a esfera cai nele, não anda os
#        21 m); na arena, do spawn (onde caía no buraco): pára antes do vazio e não morre;
#    C — chuva na área mirada: as bolinhas caem até ~9 m do ponto mirado, ferem quem
#        está no meio e não quem está longe; soltar pára as ondas e o que saiu cai.
#
#  RODADA 3 (07/10/2026): F = voo de luz pela TECLA F de verdade (história: roteada pela
#  HistoriaHud; arena: pelo Player): segurando, o corpo some e voa ~30 m/s para onde a
#  câmera aponta, gastando energia; soltar pára e ele cai. O menu de técnicas mostra o F.
# ============================================================================

const MAPA := "user://test_pika_builder_mapa.json"
const PROGRESSO := "user://test_pika_builder.json"
const DANO_C_ARENA := 40.0

var _ok_n := 0
var _falhas := 0
var p: Node3D
var cena: Node


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	SkillsPublicadas.recarregar()
	_ok("a Pika do projeto tem Z, X e C do Builder e o V do jogo (%s)" % str(KitDoBuilder.teclas("pika_pika")),
		KitDoBuilder.pelo_builder("pika_pika", "Z") and KitDoBuilder.pelo_builder("pika_pika", "X")
		and KitDoBuilder.pelo_builder("pika_pika", "C") and not KitDoBuilder.pelo_builder("pika_pika", "V"))
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	root.get_node("GameFlow").start_story()
	await _fisica(120)
	cena = current_scene
	p = get_first_node_in_group("player")
	(cena.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _fisica(20)
	_ok("comeu a Pika (%s)" % p.get("current_fruit_id"), str(p.get("current_fruit_id")) == "pika_pika")
	await _z()
	await _x()
	await _c()
	await _v()
	await _f("história")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	await _x_na_arena()
	print("\nPIKA_BUILDER %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _z() -> void:
	await _no_lugar(Vector3(0, 0.8, 0), 0.0)
	var b := _boneco(Vector3(0.5, 1.0, -25.0))
	var outro := _boneco(Vector3(9.0, 1.0, -18.0))
	await _fisica(12)
	await _mirar_em(b.global_position + Vector3.UP * 0.4)
	var vida := float(b.get("health"))
	var vida_outro := float(outro.get("health"))
	# Toque (aperta e solta no quadro seguinte): sai na hora, empurrão 1×.
	var e := await _tecla("Z", 1)
	await _fisica(12)
	var dano := vida - float(b.get("health"))
	var esperado := 98.0 * PerfilDeFrutas.ESCALA_DA_ARENA
	_ok("Z (toque): um raio só acerta o boneco a 25 m (%.2f; quer %.2f)" % [dano, esperado], absf(dano - esperado) < 0.6)
	_ok("Z (toque): empurrão 1× (%.2f)" % (e.multiplicador_de_empurrao() if is_instance_valid(e) else -1.0),
		is_instance_valid(e) and absf(e.multiplicador_de_empurrao() - 1.0) < 0.05)
	await _fisica(40)

	# Segurando: nada sai; a estrela cresce NA MÃO. Gira a mira para o outro boneco e solta.
	vida = float(b.get("health"))
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["Z"] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge("Z")
	await _fisica(20)
	e = _executor("pika_raio_z")
	var estrela := _vfx(e, "Estrela")
	var mao := p.find_child("Hand_R", true, false) as Node3D
	var tam0: float = estrela.get_node("Pontas").scale.x if estrela else 0.0
	await _mirar_em(outro.global_position + Vector3.UP * 0.4, 30)
	await _fisica(75)                                   # bem mais que 1,5 s (carga cheia)
	var tam1: float = estrela.get_node("Pontas").scale.x if estrela else 0.0
	var na_mao := estrela.global_position.distance_to(mao.global_position) if estrela and mao else INF
	_ok("Z segurando: nada sai (boneco %.1f → %.1f, outro %.1f → %.1f)" % [vida, float(b.get("health")),
		vida_outro, float(outro.get("health"))],
		is_equal_approx(vida, float(b.get("health"))) and is_equal_approx(vida_outro, float(outro.get("health"))))
	_ok("Z segurando: a estrela de quatro pontas está na mão (%.2f m) e cresce (%.2f → %.2f)" % [na_mao, tam0, tam1],
		estrela != null and na_mao < 0.15 and tam1 > tam0 * 1.5)
	var retic := _ponto_do_reticulo()
	p.release_charge("Z")
	var linha := {}
	for i in 12:
		await physics_frame
		if linha.is_empty():
			var feixe := _vfx(e, "Feixe")
			if feixe and mao:
				linha = {"de": feixe.global_position, "dir": -feixe.global_basis.z.normalized(), "mao": mao.global_position}
	_ok("Z solto: sai para a mira do SOLTAR — acerta o outro boneco (%.1f → %.1f), não o primeiro" % [vida_outro,
		float(outro.get("health"))], float(outro.get("health")) < vida_outro - 0.5 and is_equal_approx(vida, float(b.get("health"))))
	var erro := INF
	var da_mao := INF
	if not linha.is_empty():
		var t := maxf(0.0, (retic - linha.de).dot(linha.dir))
		erro = retic.distance_to(linha.de + linha.dir * t)
		da_mao = (linha.de as Vector3).distance_to(linha.mao)
	_ok("Z calibrado: o raio nasce na mão (%.2f m) e passa no retículo (%.2f m)" % [da_mao, erro], da_mao < 0.15 and erro < 0.3)
	_ok("Z carregado: empurrão 1,5× (%.2f)" % (e.multiplicador_de_empurrao() if is_instance_valid(e) else -1.0),
		is_instance_valid(e) and absf(e.multiplicador_de_empurrao() - 1.5) < 0.05)
	var recarga: float = (p.get("_fruit_cooldowns") as Dictionary).get("Z", 0.0)
	_ok("Z carregado: a recarga conta do DISPARO (faltam %.1f s de 5 depois de segurar 2 s)" % recarga, recarga > 4.5)
	b.queue_free()
	outro.queue_free()
	await _fisica(40)


func _x() -> void:
	await _no_lugar(Vector3(0, 0.8, 0), 0.0)
	var de := p.global_position
	var fim := _boneco(Vector3(-5.0, 1.0, -21.0))      # embaixo do fim do zigue-zague
	await _fisica(12)
	var vida := float(fim.get("health"))
	_tecla("X", 1)
	var maior := 0.0
	var sumiu := false
	var lado_min := 0.0
	var lado_max := 0.0
	var modelo: Node3D = p.get("_char_model")
	for i in 90:
		await physics_frame
		maior = maxf(maior, p.global_position.y - de.y)
		sumiu = sumiu or not modelo.visible
		lado_min = minf(lado_min, p.global_position.x - de.x)
		lado_max = maxf(lado_max, p.global_position.x - de.x)
	var fim_x := p.global_position - de
	await _fisica(60)
	_ok("X: sobe do chão (+%.1f m)" % maior, maior > 5.0)
	_ok("X: vira luz (o corpo some na viagem)", sumiu)
	_ok("X: zigue-zague esquerda e direita (x de %.1f a %.1f m), 21 m à frente (z %.1f)" % [lado_min, lado_max, fim_x.z],
		lado_min < -3.5 and lado_max > 3.5 and absf(fim_x.z + 21.0) < 1.5)
	_ok("X: a esfera explode no chão e fere quem está embaixo do fim (%.1f → %.1f)" % [vida, float(fim.get("health"))],
		float(fim.get("health")) < vida - 0.5)
	_ok("X: depois pousa (+%.1f m)" % (p.global_position.y - de.y), p.global_position.y - de.y < 1.0)
	fim.queue_free()
	await _fisica(60)

	# Inimigo perto do caminho (a perna 2 passa a ~3 m dele): termina EM CIMA dele.
	await _no_lugar(Vector3(0, 0.8, 0), 0.0)
	de = p.global_position
	var perto := _boneco(Vector3(4.0, 1.0, -10.0))
	await _fisica(12)
	vida = float(perto.get("health"))
	_tecla("X", 1)
	var mais_longe := 0.0
	for i in 90:
		await physics_frame
		mais_longe = minf(mais_longe, p.global_position.z - de.z)
	var onde := Vector2(p.global_position.x - perto.global_position.x, p.global_position.z - perto.global_position.z).length()
	_ok("X com inimigo perto: termina em cima dele (a %.1f m no plano) sem andar os 21 m (foi até z %.1f)" % [onde, mais_longe],
		onde < 1.5 and mais_longe > -14.0)
	_ok("X com inimigo perto: a esfera cai nele (%.1f → %.1f)" % [vida, float(perto.get("health"))],
		float(perto.get("health")) < vida - 0.5)
	perto.queue_free()
	await _fisica(60)


func _c() -> void:
	await _no_lugar(Vector3(0, 0.8, 0), 0.0)
	var meio := Vector3(0.0, 0.0, -16.0)                 # o chão mirado
	var no_meio := _boneco(meio + Vector3(0.6, 1.0, 0.0))
	var longe := _boneco(meio + Vector3(22.0, 1.0, 0.0))
	await _fisica(12)
	await _mirar_em(meio)
	var vida := float(no_meio.get("health"))
	var vida_longe := float(longe.get("health"))
	var escala := PerfilDeFrutas.ESCALA_DA_ARENA
	# Custo de quadro: o mesmo intervalo SEM a chuva, para comparar.
	var base_ms := 0.0
	for i in 60:
		await physics_frame
		base_ms = maxf(base_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["C"] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge("C")
	var e := _executor("pika_yasakani_c")
	await _fisica(2)
	e = _executor("pika_yasakani_c")
	var estouros: Array[Vector3] = []
	var vistos := {}
	var pior_ms := 0.0
	for i in 175:                                       # segura até o fim (1,9 s) e o voo
		await physics_frame
		pior_ms = maxf(pior_ms, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		_anotar_estouros(e, estouros, vistos)
	p.release_charge("C")
	var longe_max := 0.0
	for x in estouros:
		longe_max = maxf(longe_max, Vector2(x.x - meio.x, x.z - meio.z).length())
	var dano := vida - float(no_meio.get("health"))
	print("      C: %.1f estouros de %d no boneco do meio (segurando tudo)" % [dano / (DANO_C_ARENA * escala), estouros.size()])
	_ok("C: chuva na área mirada — %d estouros, o mais longe a %.1f m do ponto mirado (área 9 m)" % [estouros.size(), longe_max],
		estouros.size() >= 90 and longe_max < 10.5)
	_ok("C: fere quem está no meio (%.2f = %.0f da arena) e não quem está a 22 m (%.1f → %.1f)" % [dano, dano / escala,
		vida_longe, float(longe.get("health"))], dano > 0.0 and is_equal_approx(vida_longe, float(longe.get("health"))))
	print("      C: pior quadro de física — sem chuva %.2f ms, com chuva %.2f ms" % [base_ms, pior_ms])
	no_meio.queue_free()
	longe.queue_free()
	await _fisica(60)

	# Soltar cedo: as ondas param; o que já saiu cai (estoura depois do soltar).
	await _no_lugar(Vector3(0, 0.8, 0), 0.0)
	await _mirar_em(meio)
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["C"] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge("C")
	await _fisica(2)
	e = _executor("pika_yasakani_c")
	estouros.clear()
	vistos.clear()
	await _fisica(28)                                   # ~0,5 s: duas ondas
	var bolinhas := 0
	if is_instance_valid(e):
		bolinhas = (e.get("_manuais") as Array).size()
	p.release_charge("C")
	var antes := estouros.size()
	for i in 90:
		await physics_frame
		_anotar_estouros(e, estouros, vistos)
	_ok("C solto cedo: só as ondas até ali (%d bolinhas no ar ao soltar) e elas caem depois (%d estouros)" % [bolinhas,
		estouros.size() - antes], bolinhas > 0 and bolinhas <= 28 and estouros.size() - antes >= bolinhas / 2)
	_ok("C solto cedo: a skill termina", cena.find_children("SkillBuilder_pika_yasakani_c", "", true, false).is_empty())
	await _fisica(30)


func _v() -> void:
	await _no_lugar(Vector3(0, 0.8, 0), 0.0)
	p.call("_fire_skill", "V", Vector3.FORWARD, p.global_position, 0.0, 0, "fruit", "pika_pika")
	await _fisica(4)
	_ok("V segue o código da Pika (nenhum executor do Builder)", cena.find_children("SkillBuilder_*", "", true, false).is_empty())


## Arena (singleplayer): do spawn, olhando −Z, o zigue-zague de 21 m acabava sobre um
## buraco e o jogador morria ("caiu do mapa", visto no `test_frutas`). Agora pára antes.
func _x_na_arena() -> void:
	root.get_node("GameFlow").start_singleplayer()
	await _fisica(180)
	cena = current_scene
	p = null
	for n in get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
	p.equip_fruit("pika_pika")
	p.set("combat_mode", "fruit")
	await _fisica(20)
	var de := p.global_position
	var mortes := [0]
	if p.has_signal("died"):
		p.connect("died", func(_a = null) -> void: mortes[0] += 1)
	p.set("_yaw", 0.0)
	p.call("_update_pivot")
	_tecla("X", 1)
	var menor_y := de.y
	for i in 150:
		await physics_frame
		menor_y = minf(menor_y, p.global_position.y)
	var chao := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP, p.global_position + Vector3.DOWN * 60.0, 1, [p.get_rid()])
	var tem := not p.get_world_3d().direct_space_state.intersect_ray(chao).is_empty()
	_ok("X na arena, do spawn: pára antes do vazio (chão embaixo: %s; menor altura %.1f; partida %.1f)" % [tem, menor_y, de.y],
		tem and menor_y > de.y - 3.0 and mortes[0] == 0)
	await _fisica(120)
	await _f("arena")


## F: voo de luz pela tecla F de verdade.
func _f(rotulo: String) -> void:
	p.global_position = p.global_position if rotulo == "arena" else Vector3(0, 0.8, 0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.set("_pitch", 0.12)                    # câmera um pouco para cima
	p.call("_update_pivot")
	await _fisica(40)
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)["F"] = 0.0
	p.set("_intervalo_golpe", 0.0)
	var cam: Camera3D = p.get("_cam")
	var frente := -cam.global_transform.basis.z
	var de := p.global_position
	var energia0 := float(p.get("energy"))
	_tecla_f(true)
	await _fisica(60)                        # 1 s voando
	var e := _executor("pika_voo_f")
	var modelo: Node3D = p.get("_char_model")
	var andou := p.global_position - de
	var gasto := energia0 - float(p.get("energy"))
	var angulo := rad_to_deg(andou.normalized().angle_to(frente)) if andou.length() > 0.1 else 180.0
	_ok("%s, F: segurando, o corpo vira luz (%s) e voa %.1f m em 1 s para onde a câmera aponta (%.0f° da câmera)" % [rotulo,
		not modelo.visible, andou.length(), angulo], e != null and not modelo.visible and andou.length() > 20.0 and angulo < 20.0)
	var maximo := float(p.get("max_energy"))
	_ok("%s, F: gasta energia voando (%.1f de %.0f em 1 s ≈ 2 %% + 5 %%/s)" % [rotulo, gasto, maximo],
		gasto > maximo * 0.05 and gasto < maximo * 0.10)
	var y_solto := p.global_position.y
	_tecla_f(false)
	await _fisica(40)
	_ok("%s, F: soltou — pára de voar e cai (%.1f → %.1f m), o corpo volta" % [rotulo, y_solto, p.global_position.y],
		p.global_position.y < y_solto - 0.5 and modelo.visible and _executor("pika_voo_f") == null)
	if rotulo == "história":
		var tecnicas := cena.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n.has_method("slots_na_tela"))
		var tem_f := false
		for t in tecnicas:
			tem_f = tem_f or "F" in t.call("slots_na_tela")
		_ok("história, F: o menu de técnicas mostra o F", tem_f)
	await _fisica(90)


func _tecla_f(apertada: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_F
	ev.physical_keycode = KEY_F
	ev.pressed = apertada
	Input.parse_input_event(ev)


# ------------------------------------------------------------------ apoio

## Toque numa tecla; devolve o executor do Builder que nasceu (ou null).
func _tecla(slot: String, quadros: int) -> Node:
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge(slot)
	for i in quadros:
		await physics_frame
	var e: Node = _executor({"Z": "pika_raio_z", "X": "pika_yata_x", "C": "pika_yasakani_c"}.get(slot, ""))
	p.release_charge(slot)
	return e


func _executor(id: String) -> Node:
	var achados := cena.find_children("SkillBuilder_" + id, "", true, false)
	return achados[achados.size() - 1] if not achados.is_empty() else null


## O nó vivo do primeiro bloco de VFX com este estilo no executor (ou null).
func _vfx(e: Node, estilo: String) -> Node3D:
	if not is_instance_valid(e):
		return null
	var estado: Dictionary = e.get("_estado")
	for ev: Dictionary in (e.get("skill") as Dictionary).get("eventos", []):
		if str(ev.tipo) == "vfx" and str(ev.get("parametros", {}).get("estilo", "")) == estilo:
			var st: Dictionary = estado.get(ev.id, {})
			if st.has("no") and is_instance_valid(st.no):
				return st.no as Node3D
	return null


func _anotar_estouros(e: Variant, lista: Array[Vector3], vistos: Dictionary) -> void:
	if not is_instance_valid(e):
		return
	for x: Dictionary in e.get("_explosoes"):
		if is_instance_valid(x.no) and not vistos.has(x.no):
			vistos[x.no] = true
			lista.append((x.no as Node3D).global_position)


func _ponto_do_reticulo() -> Vector3:
	var cam: Camera3D = p.get("_cam")
	var frente := -cam.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + frente * 150.0)
	q.exclude = [(p as CollisionObject3D).get_rid()]
	q.collision_mask = ~HurtboxDeCombate.CAMADA & 0xFFFFFFFF
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else cam.global_position + frente * 150.0


func _mirar_em(ponto: Vector3, quadros := 30) -> void:
	var cam: Camera3D = p.get("_cam")
	for i in quadros:
		var de := cam.global_position
		var d := (ponto - de).normalized()
		p.set("_yaw", atan2(-d.x, -d.z))
		p.set("_pitch", asin(clampf(d.y, -1.0, 1.0)))
		p.call("_update_pivot")
		await process_frame


func _boneco(pos: Vector3) -> Node3D:
	var b := BonecoDeDuelo.new()
	b.position = pos
	cena.add_child(b)
	return b


func _no_lugar(pos: Vector3, yaw: float) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.set("_yaw", yaw)
	p.set("_pitch", 0.0)
	p.call("_update_pivot")
	await _fisica(15)
	for b in get_nodes_in_group("enemy"):
		if b is BonecoDeDuelo:
			b.call("parar")


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
