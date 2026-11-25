extends SceneTree
## Captura da luta do Buggy no ringue (22/11/2026). Weston isolado (docs/MODO_HISTORIA.md):
##   WAYLAND_DISPLAY=<socket> godot --display-driver wayland --rendering-driver vulkan --path . --resolution 1280x720 --script tools/dev_tests/captura_luta_do_buggy.gd -- <pasta>
var saida := "/tmp/luta_do_buggy"
func q(n: int) -> void:
	for i in n: await physics_frame
func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [saida, nome])
	print("CAPTURA ", nome)
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: saida = a[0]
	DirAccess.make_dir_recursive_absolute(saida)
	_rodar.call_deferred()
func _rodar() -> void:
	var R := RegrasDoDesafioBuggy
	var caminho := "user://captura_luta_buggy.json"
	var prog := ProgressaoDoPersonagem.new()
	prog.aceitar_missao("treino"); prog.contar_abate("treino"); prog.entregar_missao("treino")
	prog.nivel = R.NIVEL_DA_LUTA
	R._gravar(prog, R.ACEITOU)
	prog.aceitar_missao(R.MISSAO_LUTA)
	prog.salvar(caminho)
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", caminho)
	root.get_node("GameFlow").start_story()
	var p: Node3D = null
	var d = null
	for i in 2400:
		await physics_frame
		p = get_first_node_in_group("player")
		if p != null and current_scene != null and current_scene.get("desafio_buggy") != null:
			d = current_scene.desafio_buggy
			break
	await q(60)
	p.set_meta("damage_immune", true)
	p.global_position = d.chegada.buggy.global_position + Vector3(-5.0, 0.8, 0.0)
	for i in 400:
		await physics_frame
		if d.etapa == 3: break
	d.hud.caixa_de_fala().pular()
	for i in 300:
		await physics_frame
		if d.luta_ativa(): break
	var l = d.luta
	await q(20)
	await foto("01_entrando")
	for i in 120:
		await physics_frame
		if l.fase == LutaDoBuggy.Fase.ESPERANDO: break
	await foto("02_prompt")
	# acerta uma rodada de ataque e outra de defesa, fotografando o contato
	var viu_ataque := false
	var viu_defesa_ok := false
	var viu_defesa_falha := false
	for volta in 80:
		if l.fase != LutaDoBuggy.Fase.ESPERANDO:
			await physics_frame
			continue
		var defesa: bool = l.tipo_atual == RegrasDaLutaDoBuggy.Tipo.DEFESA
		if defesa and not viu_defesa_falha and viu_defesa_ok:
			l.apertar("Q")
			await q(16)
			await foto("05_levou")
			viu_defesa_falha = true
		elif defesa and not viu_defesa_ok:
			await q(8)
			await foto("03_defesa_aviso")
			l.apertar(l.tecla_atual)
			await q(16)
			await foto("04_defendeu")
			viu_defesa_ok = true
		elif not defesa and not viu_ataque:
			l.apertar(l.tecla_atual)
			await q(9)
			await foto("06_soco")
			viu_ataque = true
		else:
			l.apertar(l.tecla_atual)
		await q(2)
		if viu_ataque and viu_defesa_ok and viu_defesa_falha: break
	var g := 0
	while not l.regras.terminou() and g < 3000:
		g += 1
		if l.fase == LutaDoBuggy.Fase.ESPERANDO: l.apertar(l.tecla_atual)
		await physics_frame
	for i in 300:
		await physics_frame
		if l.fase == LutaDoBuggy.Fase.FIM: break
	await q(45)
	await foto("07_fim")
	quit()
