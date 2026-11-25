extends SceneTree
## LUTA, 20/11/2026: Z segurado repete com o MESMO dano; combate aéreo: o soco sai na mira da câmera (lados, cima e baixo); X/C medidos.
## (teclas reais, pela HUD), dano do mod (soco 9, pesado 11 × CNT6), empurrão forte em Z e X, no C só o último golpe empurra e os da rajada
## paralisam. Não cita classes do jogo por nome (o `--script` compilaria o Player cedo).
##   godot --headless --path . --fixed-fps 60 --script res://tools/dev_tests/test_luta_ar_e_segurar.gd
const ID := "estilo_de_combate_base"
var p: Node3D
var c
var alvo: Node3D
var passou := 0
var falhas := 0
var Imob: GDScript
var Bal: GDScript
var Cat: GDScript

class Alvo extends StaticBody3D:
	var health := 50000.0
	var hits := 0
	var danos: Array[float] = []
	var kbs: Array[float] = []
	var preso: Array[bool] = []
	func take_damage(d: float, _origem := Vector3.ZERO, kb := Vector3.ZERO, _stun := 0.0) -> void:
		danos.append(d)
		kbs.append(kb.length())
		preso.append(bool(get_meta("is_frozen", false)))
		health -= d
		hits += 1

func _init() -> void: _rodar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1
func tecla(codigo: Key, apertou: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = apertou
	Input.parse_input_event(ev)

func _limpar() -> void:
	await frames(3)
	Imob.liberar(alvo)
	c.recargas.clear()
	c.imunidade.clear()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.health = 50000.0
	alvo.hits = 0
	alvo.danos.clear()
	alvo.kbs.clear()
	alvo.preso.clear()
	alvo.position = Vector3(0, 1, -1.6)
	await frames(5)

func _rodar() -> void:
	await process_frame
	Imob = load("res://src/combat/frutas_mine_piece/imobilizacao_mine_piece.gd")
	Bal = load("res://src/combat/Balance.gd")
	Cat = load("res://src/combat/frutas_mine_piece/catalogo.gd")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_luta_ar_e_segurar.json"))
	modo.set("progresso_forcado", "user://test_luta_ar_e_segurar.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	for no in current_scene.find_children("*", "CicloDiaNoite", true, false):
		no.pausado = true
	var prog = current_scene.progressao
	await frames(10)
	c = load("res://src/combat/frutas_mine_piece/controlador.gd").de(p)
	var a := Alvo.new()
	a.collision_layer = 1
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.2, 2.0, 1.2)
	col.shape = caixa
	a.add_child(col)
	current_scene.add_child(a)
	a.add_to_group("enemy")
	alvo = a

	print("\n-- catálogo e equipamento --")
	ok("Luta no catálogo nativo e FORA da loja", Cat.contem(ID) and not Cat.ids().has(ID))
	ok("Luta é o item ativo e o controlador nativo a assumiu", prog.item_em_uso() == "luta" and c != null and c.fruta_id == ID and c.fruta_ativa())
	ok("teclas diretas Z/X/C = 1/2/3", c.tem_teclas_diretas() and Cat.FICHAS[ID].teclas_diretas == {"Z": 1, "X": 2, "C": 3})
	ok("não depende do Skills Builder (progressão sem kit)", prog.tem_estilo_base() and prog.fruta_a_equipar() == ID)
	var escala := 0.1       # PerfilDeFrutas.ESCALA_DO_MOD: dano do mod = dano × 10 × 0,1
	var forca := 3.0        # o efeito Força do nível 1 soma +3 de dano físico em todo golpe (progressão do mod, não da Luta)
	var tab: Dictionary = Bal.MINE_PIECE_LUTA

	var dano_z := float(tab.soco.dano) * escala + 3.0

	print("\n-- Z segurado --")
	await _limpar()
	tecla(KEY_Z, true)
	await frames(100)
	var n_seg: int = alvo.hits
	tecla(KEY_Z, false)
	ok("segurar Z repete o soco (%d contatos em 1,7 s)" % n_seg, n_seg >= 3)
	var igual: bool = not alvo.danos.is_empty()
	for d in alvo.danos:
		igual = igual and is_equal_approx(d, alvo.danos[0])
	ok("o dano NÃO muda ao segurar (%s)" % str(alvo.danos), igual and is_equal_approx(alvo.danos[0], dano_z))
	await frames(40)
	var depois: int = alvo.hits
	await frames(40)
	ok("soltar Z encerra a sequência", alvo.hits == depois and not c.ativo)
	await _limpar()
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(60)
	ok("toque curto continua sendo UM soco", alvo.hits == 1)

	print("\n-- no ar: o soco segue a mira --")
	for caso in [["frente", 0.0, null], ["para cima", 0.9, null], ["para baixo", -0.9, null]]:
		await _limpar()
		p.global_position = Vector3(0, 8, 0)
		p.velocity = Vector3.ZERO
		p._pitch = float(caso[1])
		p._update_pivot()
		await frames(2)
		var d: Vector3 = c.olhar()
		alvo.position = c.pe() + Vector3.UP * 1.3 + d.normalized() * 2.5
		await frames(1)
		tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
		await frames(8)
		# O punho-fantasma é a barra comprida (escala z > 1): o eixo dela tem de ser o da mira, também para cima e para baixo.
		var barra: Node3D = null
		for m in c.executor.find_children("*", "MeshInstance3D", true, false):
			if not m.is_queued_for_deletion() and m.material_override != null and (m as Node3D).scale.z > 1.5:
				barra = m
		var alinhamento := 0.0
		var sentido := Vector3.ZERO
		if barra != null:
			alinhamento = absf(barra.global_basis.z.normalized().dot(d.normalized()))
			sentido = (barra.global_position - (c.pe() + Vector3.UP * 1.3)).normalized()
		ok("punho-fantasma %s: eixo na mira (%.2f) e posição na mira (%.2f)" % [caso[0], alinhamento, sentido.dot(d.normalized())], barra != null and alinhamento > 0.97 and sentido.dot(d.normalized()) > 0.85)
		await frames(6)
		ok("no ar, mira %s (y da mira %.2f): acerta o alvo na linha da mira" % [caso[0], d.y], alvo.hits == 1)
		await frames(40)
	await _limpar()
	p.global_position = Vector3(0, 8, 0)
	p._pitch = 0.9
	p._update_pivot()
	await frames(2)
	alvo.position = Vector3(0, 8 - 3.0, -1.6)       # bem abaixo: a mira para cima NÃO pode acertar
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(14)
	ok("mirando para cima, um alvo ABAIXO não é atingido", alvo.hits == 0)
	await frames(40)

	print("\n-- visual, braço no ar e liberação do C --")
	await _limpar()
	tecla(KEY_Z, true); await frames(1); tecla(KEY_Z, false)
	await frames(8)
	var cubos: int = c.executor.find_children("*", "MeshInstance3D", true, false).size()
	ok("o contato do Z cria o visual voxel (%d cubos)" % cubos, cubos >= 5)
	await frames(50)
	ok("e ele some sozinho", c.executor.find_children("*", "MeshInstance3D", true, false).size() == 0 or c.executor.find_children("*", "MeshInstance3D", true, false).all(func(m): return m.is_queued_for_deletion()))
	await _limpar()
	tecla(KEY_X, true)
	await frames(30)
	var aura_viva: bool = c.executor._aura != null and is_instance_valid(c.executor._aura)
	ok("segurar X acende a aura do punho", aura_viva)
	ok("segurar X usa a pose própria de carga (%s) sem reiniciar o clipe (t=%.2f s)" % [c._clipe, c._clipe_t], c._clipe == "carga_x" and c._clipe_t > 0.15)
	var meta_pose: Dictionary = p.get_meta("pose_de_skill", {})
	ok("a pose de carga está aplicada no corpo com peso cheio (torso %s)" % str(meta_pose.get("Torso", null)), meta_pose.has("Torso") and absf((meta_pose["Torso"] as Vector3).y) > deg_to_rad(55.0))
	var escala_a: float = c.executor._aura.scale.x if aura_viva else 0.0
	await frames(40)
	ok("a aura cresce com a carga (%.2f → %.2f)" % [escala_a, c.executor._aura.scale.x if c.executor._aura != null else 0.0], c.executor._aura != null and c.executor._aura.scale.x > escala_a)
	tecla(KEY_X, false)
	var clipe_visto := ""
	for i in 20:
		await physics_frame
		if c._clipe == "punch_right":
			clipe_visto = c._clipe
			break
	ok("ao soltar, o soco assume a pose (%s)" % clipe_visto, clipe_visto == "punch_right")
	await frames(60)
	ok("soltar X leva a aura embora", c.executor._aura == null)
	await _limpar()
	tecla(KEY_X, true)
	await frames(30)
	p.health -= 1.0                       # apanhar cancela a carga
	await frames(10)
	tecla(KEY_X, false)
	ok("cancelar no meio da carga não deixa aura nem inclinação", c.executor._aura == null and c.pose_extra.is_empty())
	p.health = p.max_health
	await _limpar()
	p.global_position = Vector3(0, 8, 0)
	p._pitch = 0.9
	p._update_pivot()
	await frames(2)
	tecla(KEY_Z, true); await frames(4)
	ok("no ar, mirando para cima, o braço que bate inclina (%s)" % str(c.pose_extra), not c.pose_extra.is_empty() and float(c.pose_extra.values()[0].x) > 20.0)
	tecla(KEY_Z, false)
	await frames(40)
	ok("e a inclinação sai ao terminar", c.pose_extra.is_empty())

	print("\n-- C: os punhos-fantasma alternam os lados --")
	await _limpar()
	var lados := {}
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	for i in 140:
		await physics_frame
		for m in c.executor.find_children("*", "MeshInstance3D", true, false):
			if m.is_queued_for_deletion() or m.material_override == null or (m as Node3D).scale.z < 1.5 or lados.has(m.get_instance_id()):
				continue
			var rel: Vector3 = (m as Node3D).global_position - (c.pe() + Vector3.UP * 1.3)
			lados[m.get_instance_id()] = signf(rel.dot(p.global_basis.x))
	var d_ = 0
	var e_ = 0
	for v in lados.values():
		d_ += 1 if v > 0.0 else 0
		e_ += 1 if v < 0.0 else 0
	ok("a rajada solta barras dos DOIS lados (%d à direita, %d à esquerda)" % [d_, e_], d_ >= 2 and e_ >= 2)

	print("\n-- C num alvo que JÁ estava imobilizado por outra técnica --")
	await _limpar()
	Imob.aplicar(alvo, 30.0)
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	ok("o MESMO alvo tem a imobilização de outra origem preservada após o golpe final", Imob.ativa(alvo))
	Imob.liberar(alvo)

	print("\n-- C prende primeiro e OUTRA técnica imobiliza o mesmo alvo depois (ordem inversa) --")
	await _limpar()
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(45)
	ok("no meio da rajada o alvo está preso pela Luta", Imob.ativa(alvo))
	Imob.aplicar(alvo, 30.0)                           # outra origem estende a MESMA imobilização
	await frames(150)
	ok("a rajada acabou e a imobilização mais longa da outra técnica sobrevive ao final (%.1f s)" % Imob.restante(alvo), not c.ativo and Imob.ativa(alvo) and Imob.restante(alvo) > 20.0)
	Imob.liberar(alvo)
	await _limpar()
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	ok("sem interferência, o final continua soltando o alvo da rajada (empurrão previsto)", not Imob.ativa(alvo) and alvo.kbs.size() > 0 and alvo.kbs[alvo.kbs.size() - 1] > 20.0)

	print("\n-- origem: outra técnica prende por POUCO tempo logo antes do final (a heurística por tempo falharia) --")
	await _limpar()
	tecla(KEY_C, true)
	await frames(110)
	tecla(KEY_C, false)
	await frames(2)
	Imob.aplicar(alvo, 0.4, "outra_tecnica")           # curta: <= limite antigo; a posse por origem tem de protegê-la
	await frames(8)                                    # o final sai ~2 ticks depois
	var final_saiu: bool = alvo.hits > 0 and alvo.kbs[alvo.kbs.size() - 1] > 20.0
	ok("o final saiu (%s) e o token curto da outra técnica ainda segura o alvo (%.2f s)" % [str(final_saiu), Imob.restante(alvo)], final_saiu and Imob.ativa(alvo))
	await frames(70)
	ok("e a imobilização termina sozinha depois (sem alvo preso para sempre)", not Imob.ativa(alvo) and not c.ativo)
	await _limpar()
	Imob.aplicar(alvo, 0.3, "A")
	Imob.aplicar(alvo, 5.0, "B")
	ok("duas origens no mesmo nó: tirar a A mantém a B", not Imob.liberar_origem(alvo, "A") and Imob.ativa(alvo))
	ok("tirar a última solta o alvo", Imob.liberar_origem(alvo, "B") and not Imob.ativa(alvo))

	print("\n-- expiração e recriação: o token da Luta expira e OUTRA origem recria o nó antes do final --")
	await _limpar()
	Imob.aplicar(alvo, 0.05, "luta_teste")             # o token da rajada...
	await frames(12)                                   # ...expira e o nó cai
	ok("o token da rajada expirou e o alvo está livre", not Imob.ativa(alvo))
	Imob.aplicar(alvo, 3.0, "outra_origem")            # outra técnica recria o nó
	ok("o final da rajada (liberar_origem do token que já não existe) NÃO derruba o que a outra criou", not Imob.liberar_origem(alvo, "luta_teste") and Imob.ativa(alvo) and Imob.restante(alvo) > 2.0)
	Imob.liberar(alvo)

	print("\n-- X: níveis da aura legíveis --")
	ok("nível 0 sem carga, 1 ao começar, 2 em ~1/3, 3 em ~2/3 (%d %d %d %d)" % [c.executor.Visual.nivel_de_carga(0, 25), c.executor.Visual.nivel_de_carga(1, 25), c.executor.Visual.nivel_de_carga(9, 25), c.executor.Visual.nivel_de_carga(17, 25)], c.executor.Visual.nivel_de_carga(0, 25) == 0 and c.executor.Visual.nivel_de_carga(1, 25) == 1 and c.executor.Visual.nivel_de_carga(9, 25) == 2 and c.executor.Visual.nivel_de_carga(17, 25) == 3)
	await _limpar()
	tecla(KEY_X, true)
	await frames(75)
	ok("segurando, a aura ganha o anel de satélites (%d)" % (c.executor._aura.get_child_count() if c.executor._aura != null else -1), c.executor._aura != null and c.executor._aura.get_child_count() == 8)
	tecla(KEY_X, false)
	await frames(80)

	print("\n-- C: o golpe final só solta quem a rajada prendeu --")
	await _limpar()
	var outro := Alvo.new()
	outro.collision_layer = 1
	var col2 := CollisionShape3D.new()
	var cx := BoxShape3D.new()
	cx.size = Vector3(1.2, 2.0, 1.2)
	col2.shape = cx
	outro.add_child(col2)
	current_scene.add_child(outro)
	outro.add_to_group("enemy")
	outro.global_position = Vector3(2.0, 1, 1.5)       # dentro dos 6 m do golpe, mas ATRÁS do jogador: a rajada não o atinge
	await frames(2)
	Imob.aplicar(outro, 6.0)                            # congelado por OUTRA técnica
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	ok("a rajada acertou o alvo da frente", alvo.hits >= 7)
	ok("o congelamento de outra origem sobrevive ao golpe final", Imob.ativa(outro))
	Imob.liberar(outro)
	outro.queue_free()

	print("\n-- cenários extras --")
	# 1) dois alvos na frente: ambos apanham a rajada inteira e ambos ficam presos entre os socos
	await _limpar()
	var b2 := Alvo.new()
	b2.collision_layer = 1
	var cb := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(1.2, 2.0, 1.2)
	cb.shape = bx
	b2.add_child(cb)
	current_scene.add_child(b2)
	b2.add_to_group("enemy")
	b2.global_position = Vector3(1.0, 1, -2.4)
	await frames(2)
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	ok("dois alvos: os dois apanham a rajada (%d e %d contatos)" % [alvo.hits, b2.hits], alvo.hits >= 7 and b2.hits >= 7)
	var presos2 := 0
	for i in range(1, b2.preso.size() - 1):
		presos2 += 1 if b2.preso[i] else 0
	ok("o segundo alvo também fica paralisado entre os socos (%d de %d)" % [presos2, maxi(b2.preso.size() - 2, 0)], presos2 >= b2.preso.size() - 2 and b2.preso.size() >= 4)
	ok("ninguém fica preso depois do fim", not Imob.ativa(alvo) and not Imob.ativa(b2) and not c.ativo)
	b2.queue_free()
	await frames(2)

	# 2) cancelar no meio da rajada: para de bater e solta todos em < 1 s
	await _limpar()
	tecla(KEY_C, true)
	await frames(45)
	var antes_cancel: int = alvo.hits
	p.health -= 1.0
	await frames(5)
	tecla(KEY_C, false)
	var no_cancel: int = alvo.hits
	await frames(70)
	ok("cancelar a rajada no meio: nenhum soco depois (%d → %d)" % [no_cancel, alvo.hits], alvo.hits <= no_cancel + 1 and not c.ativo)
	ok("e o alvo não fica preso", not Imob.ativa(alvo))
	p.health = p.max_health

	# 3) Z segurado sem energia: só a repetição que dá para pagar
	await _limpar()
	p.energy = 3.0                                # soco custa 2: o 1º paga e sobra 1 → nenhuma repetição cabe
	tecla(KEY_Z, true)
	for i in 100:
		await physics_frame
		p.energy = minf(p.energy, 1.0)            # segura a regeneração: o teste mede a falta de energia, não a recarga
	tecla(KEY_Z, false)
	ok("Z segurado sem energia para repetir: um soco só (%d)" % alvo.hits, alvo.hits == 1 and not c.ativo)

	# 4) alvo sai da área no meio da rajada: nada quebra e a técnica fecha
	await _limpar()
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(25)
	var antes_saida: int = alvo.hits
	alvo.global_position = Vector3(0, 1, -40)
	await frames(150)
	ok("alvo que sai da área: parou de apanhar (%d → %d) e a técnica terminou" % [antes_saida, alvo.hits], alvo.hits <= antes_saida + 1 and not c.ativo)

	# 5) X: tocar não carrega, segurar ao teto dá +50 % e a aura nunca vaza para o golpe seguinte
	await _limpar()
	tecla(KEY_X, true); await frames(1); tecla(KEY_X, false)
	await frames(90)
	ok("X tocado e aura limpa (aura %s)" % str(c.executor._aura), alvo.hits == 1 and c.executor._aura == null and is_equal_approx(alvo.danos[0], float(tab.pesado.dano) * escala + forca))

	print("\n-- alvo jogador (PvP) --")
	await _limpar()
	alvo.remove_from_group("enemy")
	alvo.add_to_group("player")
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	var n_pvp: int = alvo.hits
	var presos_pvp := 0
	for i in range(1, alvo.preso.size() - 1):
		presos_pvp += 1 if alvo.preso[i] else 0
	ok("jogador na frente apanha a rajada (%d contatos) e fica congelado entre os socos (%d)" % [n_pvp, presos_pvp], n_pvp >= 7 and presos_pvp >= n_pvp - 2)
	ok("o jogador atingido sai livre do congelamento no fim", not bool(alvo.get_meta("is_frozen", false)) and not Imob.ativa(alvo))
	ok("o golpe final empurra o jogador (%.1f)" % (alvo.kbs[n_pvp - 1] if n_pvp > 0 else 0.0), n_pvp > 0 and alvo.kbs[n_pvp - 1] > 20.0)
	alvo.remove_from_group("player")
	alvo.add_to_group("enemy")

	print("\n-- legibilidade: o visual não esconde o alvo na câmera real --")
	await _limpar()
	var cam: Camera3D = p._cam
	var vp := cam.get_viewport().get_visible_rect().size
	var foco := vp.y / (2.0 * tan(deg_to_rad(cam.fov) * 0.5))
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	var pico := 0.0
	var pico_final := 0.0
	var pico_total := 0
	for i in 150:
		await physics_frame
		var retangulo := Rect2()
		var primeiro := true
		for sx in [-0.6, 0.6]:
			for sy in [-1.0, 1.0]:
				for sz in [-0.6, 0.6]:
					var ponto: Vector3 = alvo.global_position + Vector3(sx, sy, sz)
					if cam.is_position_behind(ponto):
						continue
					var q := cam.unproject_position(ponto)
					retangulo = Rect2(q, Vector2.ZERO) if primeiro else retangulo.expand(q)
					primeiro = false
		if primeiro or retangulo.get_area() < 1.0:
			continue
		var coberto := 0.0
		var vivos := 0
		for m in c.executor.find_children("*", "MeshInstance3D", true, false):
			if m.is_queued_for_deletion() or m.material_override == null:
				continue
			var n3 := m as Node3D
			if cam.is_position_behind(n3.global_position):
				continue
			vivos += 1
			var prof := maxf(0.5, cam.global_position.distance_to(n3.global_position))
			var lado_px := maxf(n3.scale.x, n3.scale.y) * foco / prof
			var centro_px := cam.unproject_position(n3.global_position)
			var quadro_px := Rect2(centro_px - Vector2.ONE * lado_px * 0.5, Vector2.ONE * lado_px)
			coberto += quadro_px.intersection(retangulo).get_area()
		var razao := coberto / retangulo.get_area()
		if c.executor._acertou_final:
			pico_final = maxf(pico_final, razao)
		elif razao > pico:
			pico = razao
			pico_total = vivos
	ok("no pico da rajada os cubos cobrem %.0f%% do retângulo do alvo (%d cubos), abaixo de 35%%" % [pico * 100.0, pico_total], pico < 0.35)
	ok("o golpe final é mais forte e ainda deixa o alvo legível (%.0f%%, entre a rajada e 60%%)" % [pico_final * 100.0], pico_final < 0.6)

	print("\n-- X e C (medição) --")
	await _limpar()
	tecla(KEY_X, true); await frames(1); tecla(KEY_X, false)
	await frames(95)
	print("X danos ", alvo.danos, " kbs ", alvo.kbs, " ativo ", c.ativo, " energia ", p.energy)
	await _limpar()
	tecla(KEY_C, true); await frames(1); tecla(KEY_C, false)
	await frames(180)
	print("C danos ", alvo.danos, " kbs ", alvo.kbs, " preso ", alvo.preso, " energia ", p.energy)

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("LUTA_AR_E_SEGURAR %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
