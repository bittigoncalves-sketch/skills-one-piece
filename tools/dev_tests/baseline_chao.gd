extends SceneTree
# ============================================================================
#  BASELINE do escurecimento assimétrico do chão — com validação de conteúdo.
#
#  Uso:
#    DISPLAY=:1 godot --path . -s tools/dev_tests/baseline_chao.gd -- <pasta>
#
#  ⚠️ CORRIGE UMA FALHA DA MEDIÇÃO ANTERIOR. A métrica que produziu o número
#  "esquerda 30,0% / direita 0,5%" varria uma linha horizontal e comparava as
#  duas metades da TELA — sem nunca conferir se as duas metades mostram a mesma
#  coisa. Se a esquerda tiver blocos e a direita não, o número compara blocos com
#  chão e a "assimetria" pode não existir.
#
#  Aqui cada pixel da linha é classificado por RAIO antes de entrar na conta:
#  só pixels que acertam a `Plataforma` contam para o escurecimento do chão. Os
#  outros são reportados à parte, para ficar explícito o que há em cada metade.
#
#  Registra também todo o estado que o protocolo pede (câmera, luz, material,
#  resolução, renderizador), para os experimentos seguintes serem comparáveis.
# ============================================================================

const LINHA_Y := 430

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var saida: String = args[0] if args.size() > 0 else "/tmp/baseline"
	DirAccess.make_dir_recursive_absolute(saida)

	await process_frame
	get_root().get_node("GameFlow").start_singleplayer()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 5000: await process_frame
	var placar := get_first_node_in_group("scoreboard")
	if placar: placar.time_left = 1.0e9
	_esconder_2d(get_root())

	var p: Node3D = null
	for n in get_root().get_tree().get_nodes_in_group("player"):
		if n.is_multiplayer_authority(): p = n; break
	if p == null: print("❌ sem jogador"); quit(1); return
	for e in get_root().get_tree().get_nodes_in_group("enemy"):
		e.set_meta("is_frozen", true); e.global_position = Vector3(0, 1, -900)

	# ---------- o enquadramento canônico deste defeito ----------
	p.global_position = Vector3(0, 2.0, 0)
	p.velocity = Vector3.ZERO
	p._yaw = PI * 0.5
	p._pitch = -0.25
	p._camera.apontar(PI * 0.5, -0.25)
	for i in 40: await process_frame

	var cam: Camera3D = p._camera.camera()
	var lajes: MultiMeshInstance3D = null
	var luzes: Array = []
	for n in _todos(get_root()):
		if n is MultiMeshInstance3D and n.name == "Lajes": lajes = n
		elif n is DirectionalLight3D: luzes.append(n)
	var mat := lajes.material_override as ShaderMaterial

	print("############ BASELINE ############")
	print("renderizador : %s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("resolução    : %d x %d" % [get_root().size.x, get_root().size.y])
	print("câmera pos   : %s" % str(cam.global_position))
	print("câmera rot   : %s (yaw=%.2f pitch=%.2f)" % [str(cam.global_rotation), p._yaw, p._pitch])
	print("câmera fov   : %.1f  near=%.3f far=%.1f" % [cam.fov, cam.near, cam.far])
	print("chão         : topo em y=0, plano (MultiMesh '%s', %d instâncias)" % [
		lajes.name, lajes.multimesh.instance_count])
	for l in luzes:
		var d: DirectionalLight3D = l
		print("luz          : %-14s rot=%s energia=%.2f sombra=%s" % [
			d.name, str(d.global_rotation), d.light_energy, str(d.shadow_enabled)])
	print("material     : %s" % mat.shader.resource_path)
	for u in mat.shader.get_shader_uniform_list():
		var v = mat.get_shader_parameter(u["name"])
		if v != null:
			print("   %-14s = %s" % [u["name"], str(v)])

	# ---------------- ETAPA 3: bisseção -----------------
	var sol: DirectionalLight3D = null
	for l in luzes:
		if (l as DirectionalLight3D).shadow_enabled:
			sol = l
			break

	await _experimento(cam, saida, "A_baseline_cel", mat, lajes, sol, true)

	# B — MESMO fragment(), SEM light(). A bisseção pedida.
	var b := ShaderMaterial.new()
	b.shader = load("res://src/fx/shaders/cel_sem_light.gdshader")
	for u in mat.shader.get_shader_uniform_list():
		var v = mat.get_shader_parameter(u["name"])
		if v != null:
			b.set_shader_parameter(u["name"], v)
	lajes.material_override = b
	await _experimento(cam, saida, "B_cel_SEM_light", mat, lajes, sol, true)
	lajes.material_override = mat

	# C — controle: material padrão do Godot, mesmo albedo.
	var c := StandardMaterial3D.new()
	c.albedo_color = mat.get_shader_parameter("cor")
	c.roughness = 1.0
	lajes.material_override = c
	await _experimento(cam, saida, "C_StandardMaterial3D", mat, lajes, sol, true)
	lajes.material_override = mat

	# D — REABRE a hipótese 1 (sombra). A medição que a descartou usava a métrica
	# INVÁLIDA (média sobre pixels que incluíam os próprios escurecidos e sem
	# classificar conteúdo). Evidência nova sobre a medição justifica repetir.
	await _experimento(cam, saida, "D_baseline_SEM_sombra", mat, lajes, sol, false)

	# ---- ETAPA 4: dentro do fragment(), a única coisa que varia é a GRADE ----
	# A grade foi "descartada" antes, mas com a métrica INVÁLIDA. Reaberta.
	var g0 = mat.get_shader_parameter("usar_grade")
	mat.set_shader_parameter("usar_grade", false)
	await _experimento(cam, saida, "E_SEM_grade", mat, lajes, sol, true)
	mat.set_shader_parameter("usar_grade", g0)

	var f0 = mat.get_shader_parameter("grade_forca")
	mat.set_shader_parameter("grade_forca", 0.0)
	await _experimento(cam, saida, "F_grade_forca_0", mat, lajes, sol, true)
	mat.set_shader_parameter("grade_forca", f0)

	# ---- ETAPA 5: QUAL É a forma dos pixels escuros? ----
	# Contiguo = uma regiao (sombra/oclusao). Periodico = padrao (grade/moire).
	mat.set_shader_parameter("usar_grade", false)
	await _perfil(cam, saida, "cel_sem_grade", mat, lajes, null)
	mat.set_shader_parameter("usar_grade", g0)
	var c2 := StandardMaterial3D.new()
	c2.albedo_color = mat.get_shader_parameter("cor")
	c2.roughness = 1.0
	await _perfil(cam, saida, "padrao", mat, lajes, c2)

	# ---- A CÉLULA QUE FALTAVA NA MATRIZ ----
	# Testei (grade LIGADA, light REMOVIDO) e (grade DESLIGADA, light ligado).
	# Nunca testei os DOIS desligados juntos. Se as duas fontes produzem banda
	# sozinhas, nenhum teste isolado podia zerar — e era exatamente essa a
	# contradição "troca o material inteiro resolve, parâmetro nenhum resolve".
	var bg := ShaderMaterial.new()
	bg.shader = load("res://src/fx/shaders/cel_sem_light.gdshader")
	for u in mat.shader.get_shader_uniform_list():
		var v = mat.get_shader_parameter(u["name"])
		if v != null:
			bg.set_shader_parameter(u["name"], v)
	bg.set_shader_parameter("usar_grade", false)
	lajes.material_override = bg
	await _experimento(cam, saida, "G_SEM_light_E_SEM_grade", mat, lajes, sol, true)
	await _perfil(cam, saida, "sem_light_sem_grade", mat, lajes, bg)

	# ---- SSAO reaberto (hipótese 5) com a métrica VÁLIDA ----
	# SSAO escurece a luz AMBIENTE. O shader do jogo desliga o especular e usa
	# lambert; o StandardMaterial3D não. Se o peso do ambiente for diferente
	# entre os dois, o MESMO SSAO aparece num e some no outro.
	var env: Environment = null
	for n in _todos(get_root()):
		if n is WorldEnvironment and (n as WorldEnvironment).environment:
			env = (n as WorldEnvironment).environment
			break
	print("\nssao: on=%s raio=%.2f int=%.2f  |  ambiente: fonte=%d energia=%.2f" % [
		str(env.ssao_enabled), env.ssao_radius, env.ssao_intensity,
		env.ambient_light_source, env.ambient_light_energy])
	env.ssao_enabled = false
	lajes.material_override = bg
	await _experimento(cam, saida, "H_semLight_semGrade_SEM_SSAO", mat, lajes, sol, true)
	lajes.material_override = mat
	await _experimento(cam, saida, "I_cel_completo_SEM_SSAO", mat, lajes, sol, true)
	env.ssao_enabled = true

	# ---- ETAPA 4/5: a última diferença declarada é o `render_mode` ----
	for par in [["J_sem_render_mode", "exp_J_sem_rendermode"],
				["M_sem_escrever_ALPHA", "exp_M_sem_alpha"]]:
		var v := ShaderMaterial.new()
		v.shader = load("res://src/fx/shaders/%s.gdshader" % par[1])
		for u in mat.shader.get_shader_uniform_list():
			var val = mat.get_shader_parameter(u["name"])
			if val != null:
				v.set_shader_parameter(u["name"], val)
		v.set_shader_parameter("usar_grade", false)
		lajes.material_override = v
		await _experimento(cam, saida, par[0], mat, lajes, sol, true)
	lajes.material_override = mat
	quit()

# Imprime o perfil de luminancia ao longo da metade esquerda, com a posicao de
# MUNDO de cada amostra. A forma do perfil diz o que e o escurecimento.
func _perfil(cam: Camera3D, saida: String, nome: String, mat: ShaderMaterial,
		lajes: MultiMeshInstance3D, troca: Material) -> void:
	var antes := lajes.material_override
	if troca:
		lajes.material_override = troca
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600: await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/perfil_%s.png" % [saida, nome])
	var espaco := (get_root().world_3d as World3D).direct_space_state
	print("\n---- perfil: %s (metade esquerda) ----" % nome)
	print("  x | luminância | mundo (x, z)      | dist")
	for x in range(60, 621, 20):
		var c := img.get_pixel(x, LINHA_Y)
		var l: float = 0.2126*c.r + 0.7152*c.g + 0.0722*c.b
		var de := cam.project_ray_origin(Vector2(x, LINHA_Y))
		var dir := cam.project_ray_normal(Vector2(x, LINHA_Y))
		var par := PhysicsRayQueryParameters3D.create(de, de + dir * 500.0)
		var h := espaco.intersect_ray(par)
		var q: Vector3 = h["position"] if not h.is_empty() else Vector3.ZERO
		print("%4d | %.4f | (%7.2f, %7.2f) | %5.1f" % [
			x, l, q.x, q.z, de.distance_to(q)])
	lajes.material_override = antes

func _experimento(cam: Camera3D, saida: String, nome: String, mat: ShaderMaterial,
		lajes: MultiMeshInstance3D, sol: DirectionalLight3D, com_sombra: bool) -> void:
	if sol:
		sol.shadow_enabled = com_sombra
	var t := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t < 600: await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [saida, nome])
	_medir(img, cam, nome)
	if sol:
		sol.shadow_enabled = true

# A medição honesta: classifica cada pixel por raio ANTES de contar.
func _medir(img: Image, cam: Camera3D, titulo: String) -> void:
	var espaco := (get_root().world_3d as World3D).direct_space_state
	print("\n---- %s ----" % titulo)
	print("metade | pixels | é chão | é bloco | é céu | escurecido (só chão)")
	for m in [[60, 620, "esq"], [660, 1220, "dir"]]:
		var lum: Array[float] = []
		var ehchao: Array[bool] = []
		var blocos := 0
		var ceu := 0
		for x in range(m[0], m[1]):
			var c := img.get_pixel(x, LINHA_Y)
			lum.append(0.2126*c.r + 0.7152*c.g + 0.0722*c.b)
			var de := cam.project_ray_origin(Vector2(x, LINHA_Y))
			var dir := cam.project_ray_normal(Vector2(x, LINHA_Y))
			var par := PhysicsRayQueryParameters3D.create(de, de + dir * 500.0)
			var hit := espaco.intersect_ray(par)
			if hit.is_empty():
				ehchao.append(false); ceu += 1
			elif (hit["collider"] as Node).name == "Plataforma":
				ehchao.append(true)
			else:
				ehchao.append(false); blocos += 1
		# média SÓ do chão, e escurecimento medido contra essa média
		var soma := 0.0
		var n := 0
		for i in lum.size():
			if ehchao[i]: soma += lum[i]; n += 1
		var media := soma / float(maxi(n, 1))
		var esc := 0
		for i in lum.size():
			if ehchao[i] and lum[i] < media * 0.92: esc += 1
		print("%-6s | %6d | %6d | %7d | %5d | %5.1f%% (%d de %d)" % [
			m[2], lum.size(), n, blocos, ceu,
			100.0 * esc / float(maxi(n, 1)), esc, n])

func _todos(n: Node) -> Array:
	var out: Array = [n]
	for f in n.get_children(): out.append_array(_todos(f))
	return out
func _esconder_2d(n: Node) -> void:
	for f in n.get_children():
		if f is CanvasLayer or f is CanvasItem: f.visible = false
		else: _esconder_2d(f)
