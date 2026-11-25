extends SceneTree
# ============================================================================
#  GORO GORO (MINE PIECE) — a tradução do mod no Modo História (18/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_goro_mine_piece.gd
#
#  Confere o pedido do dono: o vendedor vende a "Goro Goro (Mine Piece)" por 1 moeda;
#  comida, R troca e Z usa; cada técnica sai e fere um boneco à frente; a recarga é a
#  do mod (global); o Mamaragan abre o Raigo; os eventos criados (toque duplo,
#  defesa perfeita → Kari Krash) disparam; a transformação elemental e o voo seguem
#  a regra do dono; e as regras do Minecraft traduzidas (imunidade de 10 ticks,
#  empurrão, voo) dão os números do Java.
#  Sem os assets do mod (importar_goro.py) a lógica roda igual; só faltam efeitos.
# ============================================================================

const MAPA := "user://test_goro_mine_piece_mapa.json"
const PROGRESSO := "user://test_goro_mine_piece.json"
const DIST := 4.0
# Carregados já com o jogo de pé: no `--script` os autoloads ainda não são identificadores
# quando o teste compila, e o controlador depende do Player.
var G: GDScript
var M: GDScript

var _ok_n := 0
var _falhas := 0
var p: Node3D
var prog: ProgressaoDoPersonagem
var boneco: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	G = load("res://src/combat/goro_mine_piece/goro_goro_mine_piece.gd")
	M = load("res://src/combat/goro_mine_piece/mundo_mine_piece.gd")
	_regras_do_minecraft()
	var lido := MapaArquivo.carregar("res://tools/dev_tests/fixtures/mapa_baseplate.json")
	MapaArquivo.salvar(MAPA, lido["mapa"])
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", MAPA)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSO))
	modo.set("progresso_forcado", PROGRESSO)
	get_root().get_node("GameFlow").start_story()
	for i in 120:
		await physics_frame
	p = get_first_node_in_group("player")
	prog = current_scene.get("progressao")
	p.set_meta("damage_immune", true)

	# ---------------------------------------------------------------- loja
	var ids := PerfilDeFrutas.frutas_a_venda()
	_ok("o vendedor tem a fruta", ids.has(G.ID))
	_ok("preço pela raridade, lendária (%d)" % PerfilDeFrutas.preco_na_loja(G.ID), PerfilDeFrutas.preco_na_loja(G.ID) == PerfilDeFrutas.PRECO_POR_PODER[4])
	_ok("nome \"%s\"" % PerfilDeFrutas.nome_da_fruta(G.ID), PerfilDeFrutas.nome_da_fruta(G.ID) == "Goro Goro (Mine Piece)")
	prog.ouro = PerfilDeFrutas.preco_na_loja(G.ID)
	var loja := preload("res://src/historia/npcs/loja_de_frutas.gd").new()
	var linha := {}
	for l in loja.linhas(prog, null):
		if str(l.get("id", "")) == G.ID:
			linha = l
	_ok("a loja lista a fruta pelo preço da raridade (%s)" % str(linha.get("preco", "?")), int(linha.get("preco", -1)) == PerfilDeFrutas.preco_na_loja(G.ID))
	var msg: String = loja.executar(prog, null, "comprar", G.ID)
	_ok("comprar pelo preço (%s)" % msg, prog.ouro == 0 and prog.quantas_akuma(G.ID) == 1)
	_ok("comer a comprada", prog.comer_fruta_comprada(G.ID))
	for i in 20:
		await physics_frame
	var goro = G.de(p)
	_ok("o controlador está no corpo e a fruta ativa", goro != null and goro.fruta_ativa())
	_ok("ficha sem técnicas Z/X/C/V da arena (perfil %s)" % str(p.perfil_de_frutas.fruta if p.perfil_de_frutas else null),
		p.perfil_de_frutas != null and p.perfil_de_frutas.fruta == G.ID and p.perfil_de_frutas.slots().is_empty())
	if goro == null:
		_fim(modo)
		return

	# ------------------------------------------------------------------ R
	var vistos := [goro.selecao]
	for i in 4:
		goro.trocar(false)
		vistos.append(goro.selecao)
	_ok("R cicla Vari → El Thor → Sango → Mamaragan → Vari %s" % str(vistos), vistos == [21, 22, 23, 25, 21])
	goro.trocar(true)
	_ok("Shift+R volta (%d)" % goro.selecao, goro.selecao == 25)
	_ok("Raigo fora do ciclo sem Mamaragan", not 29 in goro.numeros_validos())

	# --------------------------------------------------------- alvo à frente
	boneco = BonecoDeDuelo.new()
	boneco.name = "AlvoGoro"
	current_scene.add_child(boneco)
	# Energia do mod (A9): nível 20 = 4000, onde cabe o Raigo (1500).
	prog.nivel = maxi(prog.nivel, 20)
	prog.mudou.emit()
	for i in 5:
		await physics_frame
	_ok("energia máxima do mod, nível 20: 4000 (%.0f)" % float(p.max_energy), is_equal_approx(float(p.max_energy), 4000.0))
	await _a_postos()

	# ------------------------------------------------------- Z: as técnicas
	# Custos do mod, sem conversão (A9, 27/10/2026).
	for t in [[21, "Vari", 5.0, 200.0], [22, "El Thor", 10.0, 400.0], [23, "Sango", 10.0, 400.0]]:
		await _a_postos()
		goro.selecao = t[0]
		var energia := float(p.energy)
		var antes := float(boneco.get("health"))
		var pos := p.global_position
		goro.usar(true)
		for i in 6:
			await physics_frame
		# 0,1 s de regeneração no meio (10/s desde 23/10/2026): soma de volta.
		# 0,1 s de regeneração do mod no meio (em dobro com a vida cheia): soma de volta.
		var gasto := energia - float(p.energy) + float(p._vida.regen_energia_do_modo) * 2.0 * 0.1 * float(p._vida.fator_de_regeneracao)
		goro.usar(false)
		for i in 150:
			await physics_frame
		var dano := antes - float(boneco.get("health"))
		_ok("%s fere o boneco (%.1f)" % [t[1], dano], dano > 0.5)
		_ok("%s cobra %.0f ⚡ (gastou %.2f)" % [t[1], t[3], gasto], absf(gasto - t[3]) < 2.0)
		_ok("%s: recarga do mod %.1f s" % [t[1], goro.recarga_total], is_equal_approx(goro.recarga_total, t[2]))
		if t[0] == 21:
			_ok("Vari teleporta rumo ao alvo (%.1f m)" % pos.distance_to(p.global_position), pos.distance_to(p.global_position) > 0.5)
		_ok("%s termina" % t[1], int(goro.D.skill) == 0 and not p.has_meta(G.META_ATIVA))

	# -------------------------------------------------- recarga global do mod
	await _a_postos()
	goro.selecao = 21
	_ok("começa o Vari", goro.comecar(21))
	goro.z = false
	for i in 40:
		await physics_frame
	_ok("a MESMA técnica em recarga não sai de novo", not goro.comecar(21))
	_ok("mas outra sai com a primeira em curso: nenhuma trava as outras (24/11/2026)", goro.comecar(22) and goro.sessoes.size() == 2)
	goro.z = false

	# ------------------------------------------------- El Thor do céu (Shift)
	await _a_postos()
	goro.selecao = 22
	var antes_q := float(boneco.get("health"))
	goro.usar(true)
	for i in 3:
		await physics_frame
	goro.usar(false)
	goro._executar("shift", 1)
	for i in 120:
		await physics_frame
	goro._executar("shift", 0)
	_ok("El Thor com Shift (pilar do céu) fere (%.1f)" % (antes_q - float(boneco.get("health"))),
		antes_q - float(boneco.get("health")) > 0.5)

	# ------------------------------------------------- Mamaragan → Raigo
	await _a_postos()
	goro.selecao = 25
	goro.usar(true)
	await physics_frame
	goro.usar(false)
	for i in 60:
		await physics_frame
	_ok("Mamaragan liga 60 s de tempestade (%.1f)" % goro.mamaragan, goro.mamaragan > 55.0)
	_ok("o R já cai no Raigo (%d)" % goro.selecao, goro.selecao == 29 and 29 in goro.numeros_validos())
	await _a_postos()
	var antes_r := float(boneco.get("health"))
	goro.selecao = 29
	_ok("Raigo cobra 1500, o custo do mod", G.energia_de(29) == 1500.0 and is_equal_approx(G.recarga_de(29), 37.5))
	goro.usar(true)
	await physics_frame
	goro.usar(false)
	var meteoro: Node = null
	for i in 10:
		await physics_frame
	for n in current_scene.get_children():
		if n.get_script() == preload("res://src/combat/goro_mine_piece/meteoro_raigo.gd"):
			meteoro = n
	_ok("o Raigo cria o meteoro 128 blocos acima", meteoro != null and (meteoro as Node3D).global_position.y > p.global_position.y + 100.0)
	var menor_vida := float(boneco.get("health"))
	for i in 60 * 16:
		await physics_frame
		menor_vida = minf(menor_vida, float(boneco.get("health")))     # o boneco regenera e a tempestade sorteia raios: vale o pior momento, não o saldo final
		if not is_instance_valid(meteoro):
			break
	_ok("o meteoro caiu, explodiu e sumiu", not is_instance_valid(meteoro))
	_ok("a explosão do Raigo fere (%.1f, com a tempestade)" % (float(boneco.get("max_health")) - menor_vida), float(boneco.get("max_health")) - menor_vida > 0.5)
	goro.mamaragan = 0.0

	# ------------------------------------------------------ passiva (28)
	await _a_postos()
	var de_p := p.global_position
	await _toque_fisico(KEY_W)
	for i in 50:
		await physics_frame
	_ok("toque duplo em W teleporta (%.1f m)" % de_p.distance_to(p.global_position), de_p.distance_to(p.global_position) > 1.0)
	_ok("a passiva não custa energia", is_equal_approx(float(p.energy), float(p.max_energy)))

	# --------------------------------------------- Kari Krash (defesa perfeita)
	await _a_postos()
	var antes_k := float(boneco.get("health"))
	var ex = p.combate_direcional
	_ok("o corpo tem combate direcional (aparo)", ex != null)
	if ex != null:
		for i in 3:
			await physics_frame
		ex.aparou.emit(null, p.global_position)
		await physics_frame
		await physics_frame
		_ok("aparo vira o Kari Krash (skill %d)" % int(goro.D.skill), int(goro.D.skill) == 27)
		for i in 30:
			await physics_frame
		_ok("Kari Krash fere (%.1f) e não cobra energia" % (antes_k - float(boneco.get("health"))),
			antes_k - float(boneco.get("health")) > 0.5 and is_equal_approx(float(p.energy), float(p.max_energy)))

	# ------------------------------------------- sem transformação elemental nem voo forçado
	await _a_postos()
	var base_vel: Variant = p.speed_multiplier
	for i in 4:
		p.health -= 0.5
		for q in 4:
			await physics_frame
	_ok("4 golpes em 3 s NÃO transformam o corpo (SEM_LOGIA)", not goro.elemental.ativa and G.SEM_LOGIA)
	_ok("e a velocidade não muda (%.2f)" % p.speed_multiplier, is_equal_approx(p.speed_multiplier, base_vel))
	_ok("nem o voo assume o movimento", not goro.controla_movimento())
	p.health = p.max_health
	for i in 3:
		await physics_frame
	p.health -= p.max_health * 0.3
	for i in 3:
		await physics_frame
	_ok("perder 30% da vida de uma vez também não transforma", not goro.elemental.ativa)
	p.health = p.max_health

	# ----------------------------------------------- técnicas em paralelo
	await _a_postos()
	p.max_energy = 6000.0
	p.energy = p.max_energy
	goro.mamaragan = 1.0   # libera o Raigo (29) no ciclo
	var pico := 0
	for numero in [21, 22, 23, 25]:
		goro.selecao = numero
		goro.z = true
		goro.comecar(numero)
		for i in 3:
			await physics_frame
		pico = maxi(pico, goro.sessoes.size())
	_ok("Vari, El Thor, Sango e Mamaragan vivos ao mesmo tempo (pico %d)" % pico, pico >= 3)
	_ok("cada técnica com a recarga própria", float(goro.recargas.get(21, 0.0)) > 0.0 and float(goro.recargas.get(22, 0.0)) > 0.0 and float(goro.recargas.get(23, 0.0)) > 0.0)
	var recarga_vari: float = goro.recargas[21]
	_ok("o HUD mostra a recarga de cada uma (%.1f)" % recarga_vari, absf(float(goro.estado_das_tecnicas()[0].recarga) - recarga_vari) < 0.01)
	goro.mamaragan = 0.0
	goro.z = false
	for numero in [21, 22, 23, 25]:
		goro._soltar(numero)   # soltar a tecla de cada uma: só a técnica dela deixa de ser segurada
	for i in 600:
		await physics_frame
		if goro.sessoes.is_empty():
			break
	_ok("terminam todas e o corpo volta ao repouso", goro.sessoes.is_empty() and int(goro.D.skill) == 0 and not goro.controla_movimento())
	for cue in ["carga", "estalo", "vari_trovao", "el_thor_feixe", "el_thor_queda", "sango_raio", "mamaragan_trovao", "raigo_chamado", "raigo_impacto", "kari_krash", "passiva"]:
		var cam := "res://assets/mine_piece/goro/sons/goro_%s.wav" % cue
		_ok("som novo carregável: " + cue, ResourceLoader.exists(cam) and load(cam) is AudioStream)
	p.energy = p.max_energy

	# ------------------------------------------------------ trocar de fruta
	prog.tirar_fruta()
	modo.equipar_fruta(p, "")
	for i in 5:
		await physics_frame
	_ok("trocar de fruta tira o controlador e desfaz o buff", G.de(p) == null and is_equal_approx(p.speed_multiplier, 1.0))
	_fim(modo)


## Imunidade de 10 ticks, empurrão e voo: os números do Java, sem cena.
func _regras_do_minecraft() -> void:
	var im := {}
	var alvo := Node.new()
	var d1: float = M._passar_imunidade(alvo, 16.0, 100, im)
	var d2: float = M._passar_imunidade(alvo, 16.0, 105, im)
	var d3: float = M._passar_imunidade(alvo, 24.0, 106, im)
	var d4: float = M._passar_imunidade(alvo, 24.0, 110, im)
	alvo.free()
	_ok("invulnerableTime: 16, 0, +8 (diferença), 24 após 10 ticks → %s" % str([d1, d2, d3, d4]), [d1, d2, d3, d4] == [16.0, 0.0, 8.0, 24.0])
	_ok("tamanho do jogador no mod ≈ 1 (%.4f)" % M.tamanho(1.8, 0.6), absf(M.tamanho(1.8, 0.6) - 1.0026) < 0.001)
	var voo = load("res://src/combat/goro_mine_piece/voo_logia_mine_piece.gd").new()
	voo.v = Vector3.ZERO
	var v1: Variant = voo.tick(1, true, 0.0, Vector3.FORWARD, 1.0, false)
	# 0,75 × 1 × 1,5 = 1,125 passa do teto de 1 bloco/tick; depois a Queda Lenta e o ar.
	_ok("voo: subir dá (1 − 0,01) × 0,98 blocos/tick (%.3f)" % (v1.y / M.VELOCIDADE), absf(v1.y / M.VELOCIDADE - (1.0 - 0.01) * 0.98) < 0.001)
	voo.v = Vector3(0, 0, -0.9)
	voo.tick(1, false, 1.0, Vector3.FORWARD, 1.0, false)
	_ok("voo: cada eixo para no teto de 1 bloco/tick (%.3f)" % voo.v.z, absf(voo.v.z - (-1.0 * 0.91)) < 0.001)


## Põe jogador e boneco no lugar, mira no boneco e recarrega tudo.
func _a_postos() -> void:
	var goro = G.de(p)
	if goro != null:
		goro.encerrar()
		goro.recarga = 0.0
		goro.recargas.clear()
		goro.imunidade.clear()
	for i in 30:
		await physics_frame
		if goro == null or int(goro.D.skill) == 0:
			break
	p.global_position = Vector3(0.0, 1.0, 0.0)
	p.velocity = Vector3.ZERO
	p.set("_yaw", 0.0)
	p.energy = p.max_energy
	boneco.call("parar")
	boneco.global_position = Vector3(0.0, 1.0, -DIST)
	boneco.set("health", float(boneco.get("max_health")))
	for i in 15:
		await physics_frame
	await _mirar(boneco)


func _toque_fisico(tecla: Key) -> void:
	# Toque de ~130 ms e intervalo de ~100 ms: o mod lê as teclas a cada 2 ticks (100 ms).
	for passo in [[true, 8], [false, 6], [true, 8], [false, 2]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = tecla
		ev.keycode = tecla
		ev.pressed = passo[0]
		Input.parse_input_event(ev)
		for i in passo[1]:
			await physics_frame


func _mirar(alvo: Node3D) -> void:
	var centro := AlvosDeGolpe.centro(alvo)
	var cam: Camera3D = p.get("_cam")
	for i in 40:
		var de := cam.global_position
		var frente := -cam.global_transform.basis.z
		var quer := (centro - de).normalized()
		if frente.angle_to(quer) < 0.008:
			return
		var dyaw := atan2(-quer.x, -quer.z) - atan2(-frente.x, -frente.z)
		var dpitch := asin(clampf(quer.y, -1.0, 1.0)) - asin(clampf(frente.y, -1.0, 1.0))
		p.set("_yaw", float(p.get("_yaw")) + wrapf(dyaw, -PI, PI))
		p.set("_pitch", clampf(float(p.get("_pitch")) + dpitch, -1.3, 1.3))
		p.call("_update_pivot")
		for q in 6:
			await physics_frame


func _fim(modo) -> void:
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nGORO_MINE_PIECE %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
