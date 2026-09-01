extends SceneTree
## Baseline de qualidade gráfica por perfil.
##
## Uso (requer uma sessão gráfica, não headless):
##   DISPLAY=:1 godot --path . -s tools/dev_tests/medir_qualidade_grafica.gd -- pc /tmp/grafico_pc.json
## Perfis aceitos: celular, tablet, pc. O resultado é JSON comparável em CI.

const AMOSTRAS := 360 # ~6 s a 60 FPS, depois de a arena estabilizar
const AMOSTRAS_ESTRESSE := 90 # pico simultâneo (~1,5 s), antes do VFX expirar
const Fx = preload("res://src/effects/FxUtil.gd")
const FxQualityPolicy = preload("res://src/effects/FxQuality.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var perfil := str(args[0]) if not args.is_empty() else "pc"
	if perfil not in ["celular", "tablet", "pc"]:
		push_error("perfil inválido: %s" % perfil)
		quit(2)
		return
	var saida := str(args[1]) if args.size() > 1 else "/tmp/qualidade_%s.json" % perfil
	var estresse := args.size() > 2 and str(args[2]) == "stress"
	await process_frame
	var fluxo := get_root().get_node_or_null("GameFlow")
	if fluxo == null:
		push_error("GameFlow não encontrado")
		quit(1)
		return
	# Não persiste a preferência do usuário: a sonda só simula cada perfil.
	fluxo.device = perfil
	fluxo.start_singleplayer()
	var inicio := Time.get_ticks_msec()
	while Time.get_ticks_msec() - inicio < 5000:
		await process_frame
	if estresse:
		_criar_estresse_vfx()
		await create_timer(0.12).timeout
	var dados := await _amostrar(perfil, AMOSTRAS_ESTRESSE if estresse else AMOSTRAS)
	dados["cenario"] = "estresse_vfx" if estresse else "arena_padrao"
	var arquivo := FileAccess.open(saida, FileAccess.WRITE)
	if arquivo == null:
		push_error("não foi possível gravar %s" % saida)
		quit(1)
		return
	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()
	print("[Qualidade] %s | %.1f FPS | %.2f ms/frame | %.2f ms CPU | %.0f draw calls | %d luzes | %d partículas estimadas" % [
		perfil, dados["fps_medio"], dados["frame_ms_medio"], dados["cpu_process_ms_medio"], dados["draw_calls_medios"],
		dados["luzes_maximas"], dados["particulas_maximas"]])
	print("[Qualidade] relatório: ", saida)
	quit()

func _criar_estresse_vfx() -> void:
	var cena := current_scene
	if cena == null:
		push_warning("[Qualidade] estresse sem cena")
		return
	# Sonda visual isolada: sem habilidade, DamageZone, colisão ou estado de
	# jogador. Representa três explosões hero e dois impactos padrão idênticos
	# entre perfis, para medir exclusivamente a política de qualidade.
	var raiz := Node3D.new()
	raiz.name = "StressVfxVisualOnly"
	cena.add_child(raiz)
	var origem := Vector3(0.0, 1.8, 0.0)
	for no in get_nodes_in_group("player"):
		if no is Node3D:
			origem = (no as Node3D).global_position + Vector3.UP * 1.8
			break
	var offsets := [Vector3(-4.0, 0.0, -3.0), Vector3(0.0, 0.7, -5.0), Vector3(4.0, 0.0, -3.0)]
	for offset in offsets:
		var hero := _particulas_estresse(700, 1.4, "hero", Color(1.0, 0.38, 0.04, 0.95), 1.0)
		raiz.add_child(hero)
		hero.add_to_group("qualidade_estresse_vfx")
		hero.global_position = origem + offset
		if FxQualityPolicy.permite_luz("hero"):
			var luz := OmniLight3D.new()
			luz.light_color = Color(1.0, 0.32, 0.05)
			luz.light_energy = 2.2 * FxQualityPolicy.fator("hero")
			luz.omni_range = 7.0
			raiz.add_child(luz)
			luz.global_position = origem + offset
	for offset in [Vector3(-1.8, -0.5, -1.5), Vector3(1.8, -0.5, -1.5)]:
		var padrao := _particulas_estresse(150, 0.85, "padrao", Color(1.0, 0.78, 0.20, 0.8), 0.45)
		raiz.add_child(padrao)
		padrao.add_to_group("qualidade_estresse_vfx")
		padrao.global_position = origem + offset
	Fx.autofree(raiz, 2.5)

func _particulas_estresse(quantidade: int, vida: float, categoria: String,
		cor: Color, tamanho: float) -> GPUParticles3D:
	var processo := ParticleProcessMaterial.new()
	processo.direction = Vector3(0.0, 1.0, 0.0)
	processo.spread = 180.0
	processo.initial_velocity_min = 2.0
	processo.initial_velocity_max = 5.5
	processo.gravity = Vector3(0.0, 1.4, 0.0)
	processo.scale_min = 0.35
	processo.scale_max = 1.2
	processo.color_ramp = Fx.gradient([cor, Color(cor.r, cor.g * 0.35, 0.02, 0.35), Color(cor.r, 0.02, 0.0, 0.0)])
	return Fx.particles(quantidade, vida, true, processo, Fx.grain(tamanho), 0.9, categoria)

func _amostrar(perfil: String, amostras: int) -> Dictionary:
	var soma_fps := 0.0
	var soma_ms := 0.0
	var soma_draw := 0.0
	var soma_objetos := 0.0
	var luzes_max := 0
	var particulas_max := 0
	var inicio_us := Time.get_ticks_usec()
	for _i in amostras:
		await process_frame
		soma_fps += Engine.get_frames_per_second()
		soma_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		soma_draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		soma_objetos += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		var cena := current_scene
		if cena:
			var contagem := _contar_custo_visual(cena)
			luzes_max = maxi(luzes_max, contagem["luzes"])
			particulas_max = maxi(particulas_max, contagem["particulas"])
	return {
		"perfil": perfil,
		"amostras": amostras,
		"fps_medio": soma_fps / amostras,
		"frame_ms_medio": float(Time.get_ticks_usec() - inicio_us) / 1000.0 / amostras,
		"cpu_process_ms_medio": soma_ms / amostras,
		"draw_calls_medios": soma_draw / amostras,
		"objetos_renderizados_medios": soma_objetos / amostras,
		"luzes_maximas": luzes_max,
		"particulas_maximas": particulas_max,
	}

func _contar_custo_visual(no: Node) -> Dictionary:
	var luzes := 1 if no is Light3D else 0
	var particulas := 0
	if no is GPUParticles3D and ((no as GPUParticles3D).emitting or no.is_in_group("qualidade_estresse_vfx")):
		particulas = (no as GPUParticles3D).amount
	for filho in no.get_children():
		var parcial := _contar_custo_visual(filho)
		luzes += int(parcial["luzes"])
		particulas += int(parcial["particulas"])
	return {"luzes": luzes, "particulas": particulas}
