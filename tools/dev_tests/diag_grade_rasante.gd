extends SceneTree
# ============================================================================
#  A GRADE DO CHAO ENGROSSA EM ANGULO RASANTE?
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/diag_grade_rasante.gd -- <pasta>
#
#  O clipe `03_pulo_de_lado` mostrou o defeito de um jeito que nenhuma captura
#  anterior tinha mostrado: no MESMO quadro, a metade ESQUERDA da tela tem
#  bandas escuras larguissimas e a metade DIREITA tem a mesma grade fina e
#  correta. Assimetria dentro de um quadro so.
#
#  Isso aponta para o `fwidth` da grade em `cel.gdshader`:
#      vec2 d = abs(fract(c - 0.5) - 0.5) / max(fwidth(c), vec2(0.00001));
#      float linha = 1.0 - min(min(d.x, d.y) / grade_largura, 1.0);
#  `fwidth` e a variacao do valor entre pixels VIZINHOS. Numa linha vista quase
#  de perfil, a coordenada de mundo anda muito de um pixel para o outro, o
#  `fwidth` estoura, `d` desaba e `linha` vai a 1 — ou seja, o escurecimento da
#  LINHA passa a cobrir a celula inteira. E o `min(d.x, d.y)` faz o eixo pior
#  mandar nos dois.
#
#  A medicao e por VARREDURA HORIZONTAL, nao vertical como antes: as bandas aqui
#  correm na diagonal, e uma coluna vertical cruzaria poucas delas.
# ============================================================================

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/grade"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000:
		await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar:
		placar.time_left = 1.0e9
	_esconder_2d(get_root())

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority():
			p = n
			break
	if p == null:
		print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true)
		e.global_position = Vector3(0, 1, -900)
	var lajes: MultiMeshInstance3D = null
	for n in _todos(get_root()):
		if n is MultiMeshInstance3D and n.name == "Lajes":
			lajes = n
			break
	var mat := lajes.material_override as ShaderMaterial

	# O enquadramento exato do clipe que denunciou o defeito.
	p.global_position = Vector3(0, 2.0, 0)
	p.velocity = Vector3.ZERO
	p._yaw = PI * 0.5
	p._pitch = -0.25
	p._camera.apontar(PI * 0.5, -0.25)

	print("=== varredura HORIZONTAL, metade esquerda vs metade direita ===")
	await _tirar(saida, "1_como_esta", mat)
	mat.set_shader_parameter("usar_grade", false)
	await _tirar(saida, "2_sem_grade", mat)
	mat.set_shader_parameter("usar_grade", true)
	# Se a causa e o `fwidth` estourando, LIMITAR a largura da linha resolve.
	# `grade_largura` menor = linha mais fina em pixels.
	mat.set_shader_parameter("grade_largura", 0.5)
	await _tirar(saida, "3_largura_0.5", mat)
	mat.set_shader_parameter("grade_largura", 1.5)

	# ⚠️ A grade nao explica: sem ela a esquerda continua ~30% escurecida. No
	# enquadramento ha uma FILEIRA DE BLOCOS a esquerda, e sol baixo faz sombra
	# comprida. Este e o teste que separa "defeito" de "sombra funcionando".
	var sol: DirectionalLight3D = null
	for n in _todos(get_root()):
		if n is DirectionalLight3D and (n as DirectionalLight3D).shadow_enabled:
			sol = n
			break
	sol.shadow_enabled = false
	await _tirar(saida, "4_SEM_sombra", mat)
	sol.shadow_enabled = true
	# E com a borda de sombra MACIA (sem o smoothstep duro do cel), para ver
	# quanto do incomodo e a sombra existir e quanto e ela ter borda de faca.
	var liso := StandardMaterial3D.new()
	liso.albedo_color = Color(0.46, 0.46, 0.46)
	liso.roughness = 1.0
	lajes.material_override = liso
	await _tirar(saida, "5_sombra_macia_liso", mat)
	lajes.material_override = mat

	# `sombra_min = 1.0` faz `luz = mix(1,1,...) = 1` SEMPRE. Se o escurecimento
	# sobreviver a isso, ele nao nasce no light() — nasce no fragment().
	var sm0 = mat.get_shader_parameter("sombra_min")
	mat.set_shader_parameter("sombra_min", 1.0)
	await _tirar(saida, "6_sombra_min_1.0", mat)
	mat.set_shader_parameter("sombra_min", sm0)
	# E o inverso: albedo BRANCO com o light() intacto separa "a cor de base
	# mudou" de "a luz mudou".
	var cor0 = mat.get_shader_parameter("cor")
	mat.set_shader_parameter("cor", Color(1, 1, 1))
	await _tirar(saida, "7_albedo_branco", mat)
	mat.set_shader_parameter("cor", cor0)

	print("\n✓ em %s" % saida)
	quit()

func _tirar(saida: String, nome: String, _m: ShaderMaterial) -> void:
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 500:
		await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [saida, nome])
	var linha_y := 430    # bem no chao, abaixo do horizonte
	var txt := "%-16s |" % nome
	for metade in [[60, 620, "esq"], [660, 1220, "dir"]]:
		var escuros := 0
		var total := 0
		var soma := 0.0
		for x in range(metade[0], metade[1]):
			var c := img.get_pixel(x, linha_y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			soma += l
			total += 1
		var media := soma / float(total)
		# "escuro" = abaixo de 92% da media da propria metade: conta quanto da
		# faixa esta tomada por linha, sem depender do brilho absoluto.
		for x in range(metade[0], metade[1]):
			var c := img.get_pixel(x, linha_y)
			var l: float = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			if l < media * 0.92:
				escuros += 1
		txt += " %s: %4.1f%% da linha escurecida |" % [metade[2], 100.0 * escuros / float(total)]
	print(txt)

func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children():
		out.append_array(_todos(f))
	return out

func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem:
			f.visible = false
		else:
			_esconder_2d(f)
