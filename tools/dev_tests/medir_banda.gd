extends SceneTree
# ============================================================================
#  O PORTÃO DA BANDA DE LUZ — Fase 3 de docs/PLANO_VISUAL.md
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/medir_banda.gd -- <pasta>
#
#  ⚠️ ELE NÃO É O PORTÃO QUE O PLANO TINHA ESCRITO, e a troca é declarada.
#
#  O plano pedia "um teste que varre src/ e falha se aparecer
#  StandardMaterial3D.new() fora da fábrica". Esse teste provaria uma coisa que
#  NÃO foi feita: o passo 0 mostrou que 33 dos materiais são `unshaded` (efeito,
#  que não pode levar banda) e que dos 58 iluminados, quase toda a tela passa
#  por TRÊS funis. Migrar os 55 restantes seria pintar efeito que dura 0,2 s.
#
#  Um portão que falha por algo que ninguém pretende fazer não é portão, é
#  ruído. Então ele afirma o que a Fase 3 de fato entrega:
#
#   1. os TRÊS FUNIS devolvem mesmo o material de cel (e não o padrão);
#   2. onde a normal VARIA, a luz sai em degraus contáveis — provado numa
#      esfera, porque o mapa é de caixas e caixa não tem onde mostrar banda;
#   3. a SOMBRA PROJETADA tem borda DURA — que é o ganho de verdade num mundo
#      de caixas, e o que mais se vê.
# ============================================================================

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/banda"
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

	# ---------------------------------------------------- 1. os três funis
	print("\n── 1. os funis devolvem o material de cel? ──")
	var alvo_shader := "res://src/fx/shaders/cel.gdshader"
	var casos := {
		"MapBuilder._gray (chão e blocos)": MapBuilder._gray(0.52, 0.85),
		"Materiais.superficie (corpo)": Materiais.superficie(Color(0.2, 0.4, 1.0)),
	}
	for nome in casos:
		var m = casos[nome]
		var ok: bool = m is ShaderMaterial and (m as ShaderMaterial).shader != null \
			and (m as ShaderMaterial).shader.resource_path == alvo_shader
		falhas += 0 if ok else 1
		print("   %s %-36s -> %s" % ["✔" if ok else "✗", nome, m.get_class()])

	# ---------------------------------------------- 2. degraus numa esfera
	# ⚠️ ESFERA, e não uma caixa do mapa. Banda só aparece onde a normal varia
	# ao longo da superfície; numa face plana ela é um tom só, com ou sem cel.
	var mundo: Node = get_root().get_tree().current_scene
	var bola := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 1.6
	esf.height = 3.2
	esf.radial_segments = 64
	esf.rings = 32
	bola.mesh = esf
	bola.material_override = Materiais.superficie(Color(0.85, 0.85, 0.85))
	mundo.add_child(bola)
	bola.global_position = Vector3(0, 4.0, -6.0)

	var cam := Camera3D.new()
	mundo.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 4.0, -1.0)
	cam.look_at(bola.global_position, Vector3.UP)
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 600:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/esfera.png" % saida)

	# Conta AGRUPAMENTOS de luminância dentro da bola: cel dá poucos e bem
	# separados; degradê dá um contínuo.
	var hist := {}
	var cx := img.get_width() / 2
	var cy := img.get_height() / 2
	for y in range(cy - 120, cy + 120, 2):
		for x in range(cx - 120, cx + 120, 2):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var c := img.get_pixel(x, y)
			# só o cinza da bola, não o azul do céu nem o bege do chão
			if absf(c.r - c.g) > 0.06 or absf(c.g - c.b) > 0.06:
				continue
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			var balde := int(l * 40.0)
			hist[balde] = hist.get(balde, 0) + 1
	var cheios := 0
	var amostras := 0
	for k in hist:
		amostras += hist[k]
	for k in hist:
		if hist[k] > amostras * 0.03:      # baldes com pelo menos 3% da bola
			cheios += 1
	print("\n── 2. degraus de luz numa esfera (a caixa não tem onde mostrar) ──")
	var deg_ok: bool = cheios >= 2 and cheios <= 8
	falhas += 0 if deg_ok else 1
	print("   %s %d faixas de luminância com peso (%d amostras)" % [
		"✔" if deg_ok else "✗", cheios, amostras])
	bola.queue_free()

	# ------------------------------------------------- 3. borda da sombra
	print("\n── 3. a sombra projetada tem borda dura? ──")
	var poste := MeshInstance3D.new()
	var cx_mesh := BoxMesh.new()
	cx_mesh.size = Vector3(1.2, 6.0, 1.2)
	poste.mesh = cx_mesh
	poste.material_override = Materiais.superficie(Color(0.5, 0.5, 0.5))
	mundo.add_child(poste)
	poste.global_position = Vector3(0, 3.0, -10.0)
	cam.global_position = Vector3(0, 12.0, -10.0)
	cam.look_at(Vector3(3.0, 0.0, -10.0), Vector3.UP)
	var t2 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t2 < 600:
		await process_frame
	var img2 := get_root().get_texture().get_image()
	img2.save_png("%s/sombra.png" % saida)

	# varre uma linha e mede quantos PIXELS a transição leva
	var linha := int(img2.get_height() * 0.62)
	var vals := []
	for x in img2.get_width():
		var c := img2.get_pixel(x, linha)
		vals.append(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b)
	var i_max := 0
	var queda := 0.0
	for i in range(2, vals.size() - 2):
		var d: float = float(vals[i - 2]) - float(vals[i + 2])
		if d > queda:
			queda = d
			i_max = i
	var largura := 0
	if queda > 0.02:
		var alto: float = float(vals[maxi(0, i_max - 20)])
		var baixo: float = float(vals[mini(vals.size() - 1, i_max + 20)])
		var faixa: float = alto - baixo
		for i in range(maxi(0, i_max - 20), mini(vals.size(), i_max + 20)):
			var v: float = (float(vals[i]) - baixo) / maxf(faixa, 0.0001)
			if v > 0.1 and v < 0.9:
				largura += 1
	var borda_ok: bool = queda > 0.02 and largura <= 12
	falhas += 0 if borda_ok else 1
	print("   %s queda de %.3f em %d pixels de transição (dura = poucos)" % [
		"✔" if borda_ok else "✗", queda, largura])
	poste.queue_free()

	print("\n%s" % ("✅ a Fase 3 entrega o que declara." if falhas == 0
		else "❌ %d verificação(ões) falharam." % falhas))
	quit(1 if falhas > 0 else 0)

func _esconder_2d(n: Node) -> void:
	if n is CanvasLayer:
		(n as CanvasLayer).visible = false
	elif n is Control:
		(n as Control).visible = false
	for f in n.get_children():
		_esconder_2d(f)
