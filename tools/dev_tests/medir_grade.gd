extends SceneTree
# ============================================================================
#  O PORTÃO DA GRADE — Fase 4 de docs/PLANO_VISUAL.md
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_grade.gd -- <pasta>
#
#  A grade do chão não é enfeite: ela existe para dizer ao jogador ONDE a célula
#  acaba, num mapa em que o buraco tem exatamente o tamanho de uma célula e cair
#  é a principal forma de morrer. Uma grade bonita e desalinhada seria PIOR que
#  nenhuma — ela mentiria.
#
#  Por isso o teste central não é "tem linha?", é **"a linha cai onde a célula
#  de verdade acaba?"**. Ele pega a fronteira pela matemática do próprio
#  `MapBuilder`, projeta esse ponto do mundo na tela com `unproject_position` e
#  compara com o centro da célula. Se a grade estivesse em UV (o erro que o
#  `MultiMesh` de lajes fundidas convida), este teste reprovaria.
# ============================================================================

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/grade"
	DirAccess.make_dir_recursive_absolute(saida)
	var falhas := 0

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	_esconder_2d(get_root())
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)

	var mundo: Node = get_root().get_tree().current_scene

	# ---------------------------------- 1. a grade está SÓ no chão
	print("\n── 1. a grade vale só para o chão? ──")
	var chao := Materiais.chao(Color(0.46, 0.46, 0.46), MapBuilder.CELL) as ShaderMaterial
	var bloco := MapBuilder._gray(0.5, 0.8) as ShaderMaterial
	# ⚠️ `== true`, NÃO `bool(...)`. GDScript não tem construtor `bool()`, e a
	# chamada estoura em tempo de execução — o que dentro de uma cadeia de
	# `await` ABORTA a função e nunca chega no `quit()`. O teste não falha: ele
	# fica pendurado até o timeout. É a mesma armadilha registrada em
	# `docs/erros.md` para o `test_morte_limpa_cast`.
	#
	# E `get_shader_parameter` devolve `null` para o que nunca foi escrito, daí
	# o `!= true` do bloco em vez de `== false`.
	var c_ok: bool = chao.get_shader_parameter("usar_grade") == true
	var b_ok: bool = bloco.get_shader_parameter("usar_grade") != true
	var cel_ok: bool = absf(float(chao.get_shader_parameter("grade_celula")) - MapBuilder.CELL) < 0.001
	for par in [[c_ok, "o chão tem grade"], [b_ok, "o BLOCO não tem (a duplicação funcionou)"],
			[cel_ok, "a célula da grade = MapBuilder.CELL (%.1f m)" % MapBuilder.CELL]]:
		falhas += 0 if par[0] else 1
		print("   %s %s" % ["✔" if par[0] else "✗", par[1]])

	# ---------------------------------- 2. a linha cai na fronteira REAL
	print("\n── 2. a linha cai onde a célula de verdade acaba? ──")
	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.current = true
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 26.0
	cam.far = 300.0

	# Uma célula sólida perto do centro, longe de buraco e de bloco.
	var centro := MapBuilder._cell_center(11, 11)
	var alvo := Vector3(centro.x, 0.0, centro.y)
	cam.global_position = alvo + Vector3(0, 40, 0.01)
	cam.look_at(alvo, Vector3.FORWARD)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 700:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/de_cima.png" % saida)

	var meia: float = MapBuilder.CELL * 0.5
	var pontos := {
		"centro da célula": alvo,
		"fronteira +X": alvo + Vector3(meia, 0, 0),
		"fronteira -X": alvo + Vector3(-meia, 0, 0),
		"fronteira +Z": alvo + Vector3(0, 0, meia),
	}
	var lum := {}
	for nome in pontos:
		var px: Vector2 = cam.unproject_position(pontos[nome])
		var x := clampi(int(px.x), 0, img.get_width() - 1)
		var y := clampi(int(px.y), 0, img.get_height() - 1)
		var c := img.get_pixel(x, y)
		lum[nome] = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	var base: float = lum["centro da célula"]
	for nome in pontos:
		if nome == "centro da célula":
			print("   .. %-18s luminância %.4f (referência)" % [nome, base])
			continue
		var escureceu: float = base - float(lum[nome])
		var ok: bool = escureceu > 0.01
		falhas += 0 if ok else 1
		print("   %s %-18s %.4f  (%.4f mais escura que o centro)" % [
			"✔" if ok else "✗", nome, lum[nome], escureceu])

	# ---------------------------------- 3. sobrevive à distância (sem moiré)
	print("\n── 3. a linha aguenta distância? (mesma grossura, sem virar ruído) ──")
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	for d in [12.0, 40.0, 90.0]:
		cam.global_position = alvo + Vector3(0, d * 0.5, d)
		cam.look_at(alvo, Vector3.UP)
		var t2 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t2 < 450:
			await process_frame
		var im := get_root().get_texture().get_image()
		im.save_png("%s/dist_%02d.png" % [saida, int(d)])
		# contraste local numa faixa do chão: a grade tem que produzir variação,
		# e variação MODERADA — pouca = sumiu, muita = está aliasing
		var y := int(im.get_height() * 0.72)
		var vmin := 1.0
		var vmax := 0.0
		var trocas := 0
		var ant := -1
		for x in range(int(im.get_width() * 0.2), int(im.get_width() * 0.8)):
			var c := im.get_pixel(x, y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			vmin = minf(vmin, l)
			vmax = maxf(vmax, l)
			var e: int = 1 if l < 0.985 * vmax else 0
			if ant >= 0 and e != ant:
				trocas += 1
			ant = e
		var amp: float = vmax - vmin
		var ok2: bool = amp > 0.004 and trocas < 90
		falhas += 0 if ok2 else 1
		print("   %s a %4.0f m: amplitude %.4f, %d bordas na linha (muitas = moiré)" % [
			"✔" if ok2 else "✗", d, amp, trocas])

	print("\n%s" % ("✅ a grade está alinhada, restrita ao chão e legível à distância."
		if falhas == 0 else "❌ %d verificação(ões) falharam." % falhas))
	quit(1 if falhas > 0 else 0)

func _esconder_2d(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	elif n is Control:
		(n as Control).visible = false
	for f in n.get_children():
		_esconder_2d(f)
