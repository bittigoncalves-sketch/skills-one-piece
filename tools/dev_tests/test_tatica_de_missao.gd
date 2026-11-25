extends SceneTree
## Posicionamento dos inimigos em missão (08/11/2026): atirador sobe num posto alto com pulo duplo e mira; espadachins cercam o jogador
## defendendo, com no máximo um na frente (os outros vão para trás). E o jogador não é travado pela roda de inimigos.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_tatica_de_missao.gd
var total := 0
var falhas := 0

func _init() -> void:
	rodar.call_deferred()

func ok(c: bool, m: String) -> void:
	total += 1
	falhas += 0 if c else 1
	print(("  ✅ " if c else "  ❌ ") + m)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _caixa(centro: Vector3, tamanho: Vector3) -> void:
	var c := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tamanho
	cs.shape = b
	c.add_child(cs)
	c.position = centro
	current_scene.add_child(c)

func _nascer(id: String, pos: Vector3, faccao := "raid:east_blue") -> PersonagemMinePiece:
	var f: Dictionary = DadosEastBlue.ficha(id).duplicate(true)
	f["faccao"] = faccao
	var p := PersonagemMinePiece.new()
	p.montar(f, "mp_" + id)
	p.position = pos
	p.ponto_de_origem = pos
	current_scene.add_child(p)
	return p

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_tatica_de_missao.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	var base: Vector3 = j.global_position

	print("-- papéis --")
	ok(TaticaDeMissao.papel_de(DadosEastBlue.ficha("helmeppo"), "helmeppo") == TaticaDeMissao.Papel.ATIRADOR, "Helmeppo (pistola) é atirador")
	ok(TaticaDeMissao.papel_de(DadosEastBlue.ficha("pirate"), "pirate") == TaticaDeMissao.Papel.ESPADACHIM, "o pirata de espada é espadachim")
	ok(TaticaDeMissao.papel_de(DadosEastBlue.ficha("higuma"), "higuma") == TaticaDeMissao.Papel.NENHUM and TaticaDeMissao.papel_de(DadosEastBlue.ficha("zoro_east_blue"), "zoro_east_blue") == TaticaDeMissao.Papel.NENHUM,
		"chefe e aliado não têm tática")

	print("\n-- atirador: posto alto com pulo duplo e mira --")
	_caixa(base + Vector3(22, 3.0, -8), Vector3(6, 6, 6))        # um "prédio" de 6 m, a ~24 m (o posto do atirador fica a 16–36 m, 15/11/2026)
	var tiro := _nascer("helmeppo", base + Vector3(2, 0.2, -28))
	await quadros(5)
	tiro.cerebro.alvo = j
	var t: TaticaDeMissao = tiro.get_node("TaticaDeMissao")
	var maximo_de_pulos := 0
	var alto := false
	var mirou := false
	for i in 900:
		await quadros(1)
		tiro.cerebro.alvo = j
		maximo_de_pulos = maxi(maximo_de_pulos, t.pulos_dados)
		if t.estado == TaticaDeMissao.Estado.NO_POSTO:
			alto = alto or tiro.global_position.y - base.y > 2.0
			mirou = mirou or tiro._clipe_atual.contains("right_arm_front")
			if mirou:
				break
	ok(maximo_de_pulos == 2, "deu os DOIS pulos (pulo duplo): %d" % maximo_de_pulos)
	ok(alto and t.estado == TaticaDeMissao.Estado.NO_POSTO, "chegou ao posto alto (%.1f m acima do chão)" % (tiro.global_position.y - base.y))
	ok(mirou, "e mira: toca o braço estendido (%s)" % tiro._clipe_atual)

	print("\n-- espadachins cercam, no máximo um na frente (com o cerco LIGADO: por padrão eles vão direto, 15/11/2026) --")
	TaticaDeMissao.cercar_o_jogador = true
	var frente := TaticaDeMissao.frente_do_jogador(j)
	var grupo: Array[PersonagemMinePiece] = []
	for i in 4:
		var lado := frente.cross(Vector3.UP) * (float(i) - 1.5) * 3.0
		var p := _nascer("pirate", base + frente * 12.0 + lado + Vector3(0, 0.2, 0))
		p.ponto_de_origem = base
		grupo.append(p)
	await quadros(30)         # o `ao_nascer` do mod sorteia armas (às vezes um fuzil, que faria dele atirador): a mão fica só com espada
	for p in grupo:
		var eq := McEntidade.de(p)
		eq.setItemSlot(&"MAINHAND", Mc.novo(&"ItemStack", [Mc.item(&"minepiece:saber")]))
		eq.setItemSlot(&"OFFHAND", Mc.novo(&"ItemStack", [Mc.item(&"minecraft:air")]) if false else McItem.pilha(null, 0))
	await quadros(40)
	for p in grupo:
		p.cerebro.alvo = j
	for i in 600:
		await quadros(1)
		for p in grupo:
			p.cerebro.alvo = j
	var na_frente := 0
	var atras := 0
	var perto := 0
	for p in grupo:
		var v: Vector3 = p.global_position - j.global_position
		v.y = 0.0
		var a := absf(rad_to_deg(frente.signed_angle_to(v, Vector3.UP)))
		if a <= 60.0:
			na_frente += 1
		if a >= 90.0:
			atras += 1
		if v.length() < 5.0:
			perto += 1
	ok(perto == 4, "os 4 chegaram perto do jogador (%d)" % perto)
	ok(na_frente <= 1, "no máximo UM na frente (%d)" % na_frente)
	ok(atras >= 3, "os outros foram para trás/lados (%d atrás)" % atras)

	print("\n-- chefe em campo: os espadachins atacam com tudo --")
	var tats: Array = grupo.map(func(p): return p.get_node("TaticaDeMissao"))
	ok(tats.all(func(t): return not t._ataque_total), "sem chefe em campo, o cerco continua")
	var chefe_raid := _nascer("higuma", base + Vector3(-25, 0.2, 5))
	chefe_raid.ponto_de_origem = base
	await quadros(60)
	ok(tats.all(func(t): return t._ataque_total and not t.dirige(j)), "chefe spawnado: o cerco e a defesa acabam (ataque total)")
	chefe_raid.set_meta(VidaEmBarras.META_MORTE_ABSOLUTA, true)   # 10 barras (10/11/2026): o teste quer o chefe MORTO
	chefe_raid.take_damage(1000000.0, j.global_position)
	await quadros(60)
	ok(tats.all(func(t): return not t._ataque_total), "chefe derrotado: voltam à tática")

	print("\n-- uma arma só (raid) --")
	ok(ArmaUnica.preferir_fogo(20.0) and not ArmaUnica.preferir_fogo(12.0), "nasceu longe (20 m): fuzil; nasceu perto (12 m): espada")
	var duas := _nascer("pirate", base + Vector3(30, 0.2, 30))
	var eu := McEntidade.de(duas)
	eu.setItemSlot(&"MAINHAND", Mc.novo(&"ItemStack", [Mc.item(&"minepiece:rifle")]))
	eu.setItemSlot(&"OFFHAND", Mc.novo(&"ItemStack", [Mc.item(&"minepiece:saber")]))
	ok(ArmaUnica.armas_nas_maos(duas).size() == 2, "com fuzil e sabre nas mãos")
	ok(ArmaUnica.aplicar(duas, true) == "fogo" and ArmaUnica.armas_nas_maos(duas).values() == ["fogo"], "longe: fica só o fuzil")
	eu.setItemSlot(&"OFFHAND", Mc.novo(&"ItemStack", [Mc.item(&"minepiece:saber")]))
	ok(ArmaUnica.aplicar(duas, false) == "corte" and ArmaUnica.armas_nas_maos(duas).values() == ["corte"], "perto: fica só a espada")
	ok(ArmaUnica.aplicar(duas, true) == "", "com uma só, não mexe em nada")

	print("\n-- brilho amarelo atrás de estrutura --")
	var olho: Vector3 = j.global_position + Vector3(0, 1.7, 0)
	var escondido_p := _nascer("pirate", base + Vector3(-40, 0.2, -40))
	escondido_p.set_meta("raider", true)
	await quadros(5)
	ok(not BrilhoDeRaid.escondido(olho, escondido_p), "à vista: não brilha")
	var meio: Vector3 = (olho + escondido_p.global_position) * 0.5
	_caixa(meio + Vector3(0, 1.5, 0), Vector3(3, 6, 3))
	await quadros(3)
	ok(BrilhoDeRaid.escondido(olho, escondido_p), "atrás de uma estrutura: escondido")
	BrilhoDeRaid.definir(escondido_p, true)
	var mi := escondido_p._modelo.find_children("*", "MeshInstance3D", true, false)
	ok(not mi.is_empty() and (mi[0] as MeshInstance3D).material_overlay == BrilhoDeRaid.material() and BrilhoDeRaid.material().no_depth_test,
		"o brilho amarelo é desenhado por cima de tudo (sem teste de profundidade)")
	BrilhoDeRaid.definir(escondido_p, false)
	ok((mi[0] as MeshInstance3D).material_overlay == null, "e apaga quando volta à vista")

	print("\n-- sem bloqueio físico: o jogador anda no meio da roda --")
	var p0: Vector3 = j.global_position
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_W
	ev.keycode = KEY_W
	ev.pressed = true
	Input.parse_input_event(ev)
	await quadros(30)
	ev.pressed = false
	Input.parse_input_event(ev)
	ok(j.global_position.distance_to(p0) > 0.8, "andou %.2f m em meio segundo, cercado" % j.global_position.distance_to(p0))
	print("\n-- anti stun-lock: o jogador sempre recupera o controle --")
	var cobaia := Node3D.new()
	current_scene.add_child(cobaia)
	RecepcaoDeDano.aplicar(cobaia, 0.3)
	var t0: float = float(cobaia.get_meta("_dano_pose_t"))
	RecepcaoDeDano.aplicar(cobaia, 0.3)
	ok(float(cobaia.get_meta("_dano_pose_t")) == t0, "um golpe durante o tranco NÃO reinicia o relógio")
	while RecepcaoDeDano.tick(cobaia, 0.1):
		pass
	RecepcaoDeDano.aplicar(cobaia, 0.3)
	ok(not cobaia.has_meta("_dano_pose_t"), "logo depois que acaba, outro golpe não prende de novo (janela de %.1f s)" % RecepcaoDeDano.IMUNIDADE_APOS_TRANCO)
	cobaia.set_meta("_dano_pose_imune_ate", 0)
	RecepcaoDeDano.aplicar(cobaia, 0.3)
	ok(cobaia.has_meta("_dano_pose_t"), "passada a janela, o tranco volta a valer")
	print("\nTATICA_DE_MISSAO %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
