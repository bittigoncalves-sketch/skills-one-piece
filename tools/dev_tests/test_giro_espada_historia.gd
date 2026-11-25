extends SceneTree
## Input do HUD, corpo/encaixe reais, imunidade e varredura com inimigos/parede.
var pasta := "res://art_src/validation/espada_historia_2026-10-06/giro_z"
const SAVE := "user://test_giro_espada_historia.json"
var jogador: Node
var arma: Node
var giro: Node
var ex: Node
var prog: RefCounted
var total := 0
var falhas := 0
var tela := false


func _init() -> void:
	rodar.call_deferred()


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func verificar(sim: bool, texto: String) -> void:
	total += 1
	falhas += 0 if sim else 1
	print(("OK " if sim else "FALHA ") + texto)


func z(pressionada := true, eco := false) -> void:
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_Z
	tecla.physical_keycode = KEY_Z
	tecla.pressed = pressionada
	tecla.echo = eco
	Input.parse_input_event(tecla)


func foto(nome: String) -> void:
	if not tela:
		return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(pasta.path_join(nome + ".png"))


func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	for argumento in OS.get_cmdline_user_args():
		if argumento.begins_with("--capturas="):
			pasta = argumento.trim_prefix("--capturas=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(pasta))
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	root.get_node("GameFlow").start_story()
	for i in 900:                          # espera o jogador nascer: 120 quadros fixos não bastam mais (a carga cresceu) e, sem jogador, o script abortava SEM `quit` e o teste travava
		await physics_frame
		if i >= 60 and get_first_node_in_group("player") != null:
			break
	for i in 30:
		await physics_frame
	jogador = get_first_node_in_group("player")
	prog = current_scene.progressao
	arma = jogador.get_node("EspadaDaHistoria")
	giro = arma.giro
	giro.ligado = true
	ex = jogador.combate_direcional
	jogador.global_position = Vector3(0, 0.85, 0)
	jogador._yaw = 0.0
	jogador.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	z()
	await quadros(2)
	z(false)
	verificar(not giro.ativo, "Z sem espada não inicia")
	prog.nivel = maxi(prog.nivel, 100) # 10000 de energia (100 × nível; giro ×10): os 1000 de antes. Mede contato/pose.
	prog.equipamentos["espada"] = 1      # a espada inicial saiu do kit (só as lâminas do Epic Fight)
	prog.equipar_espada(true)
	jogador.energy = jogador.max_energy
	await quadros(10)
	verificar(current_scene._hud._tecnicas.slots_na_tela() == ["Z"], "HUD da espada mostra só Z")
	current_scene._hud.alternar_inventario()
	z()
	await quadros(2)
	z(false)
	verificar(not giro.ativo, "inventário aberto bloqueia início")
	current_scene._hud.alternar_inventario()
	z()
	await quadros(2)
	z(false)
	verificar(giro.ativo, "Z inicia e soltar mantém giro")
	z(true, true)
	await quadros(20)
	verificar(giro.ativo, "repetição automática da tecla não cancela")
	verificar(current_scene._hud._tecnicas.texto_da_linha("Z").contains("imune"), "HUD informa imunidade e cancelamento")
	verificar(not ex.pedir_ataque(0), "clique não mistura ataque com giro")
	var vida: float = jogador.health
	var impulso: Vector3 = jogador._vida._empurrao
	jogador.take_damage(5.0, Vector3.BACK, Vector3.RIGHT * 9.0, 0.4)
	verificar(is_equal_approx(jogador.health, vida) and jogador._vida._empurrao == impulso, "giro bloqueia dano e knockback recebidos")
	# O dano direcional tenta reagir ANTES de chamar take_damage: conferir esse caminho.
	var boneco = load("res://src/combat/direcional/boneco_de_duelo.gd").new()
	boneco.position = Vector3(0, 0.85, -6)
	current_scene.add_child(boneco)
	await quadros(5)
	boneco.combate_direcional.pedir_ataque(0)
	boneco.combate_direcional._contato(jogador, jogador.global_position, Vector3.BACK)
	verificar(ex.estado == ex.Estado.NEUTRO and not ex.em_hitstop() and is_equal_approx(jogador.health, vida), "golpe inimigo não atordoa nem aplica hitstop durante giro")
	var camera := jogador.get_viewport().get_camera_3d()
	var frente_camera: Basis = camera.global_basis
	var visual: Node3D = arma.get("_visual")
	if visual == null:             # falha RÁPIDA e dita: antes o script abortava sem `quit` e o teste ficava pendurado até o timeout
		print("FALHA: EspadaDaHistoria._visual é nulo (a espada não montou o visual; o sistema da espada mudou?)")
		quit(1)
		return
	var centro_anterior := visual.to_global(Vector3(0, 0.7, 0))
	var fio_anterior := -visual.global_basis.x.normalized()
	var yaw_anterior: float = jogador.modelo_visual().rotation.y
	var rotacao := 0.0
	var alinhamento := 1.0
	for i in 75:
		await quadros(1)
		var centro := visual.to_global(Vector3(0, 0.7, 0))
		var fio := -visual.global_basis.x.normalized()
		var yaw: float = jogador.modelo_visual().rotation.y
		rotacao += wrapf(yaw - yaw_anterior, -PI, PI)
		var viagem := centro - centro_anterior
		if viagem.length() > 0.001:
			alinhamento = minf(alinhamento, (fio + fio_anterior).normalized().dot(viagem.normalized()))
		yaw_anterior = yaw
		centro_anterior = centro
		fio_anterior = fio
		if i in [8, 23, 38, 53]:
			await foto("giro_%02d" % i)
	verificar(rotacao > TAU, "corpo completa voltas (%.2f rad)" % rotacao)
	verificar(alinhamento > 0.93, "fio acompanha a viagem da lâmina (mínimo %.3f)" % alinhamento)
	verificar(camera.global_basis.is_equal_approx(frente_camera), "câmera não gira junto com corpo")
	await quadros(600)
	verificar(giro.ativo and is_equal_approx(boneco.health, boneco.max_health), "sem timeout e sem atingir alvo distante após 10 s")
	z()
	await quadros(2)
	z(false)
	verificar(not giro.ativo and not jogador.has_meta("giro_espada_ativo"), "segundo Z cancela e remove imunidade")
	# Atacante em ZERO: sem o empurrão Minecraft da história (23/10/2026), que levaria o
	# jogador 2 m para −z, para além da parede do controle negativo logo abaixo.
	jogador.remove_meta("mc_inv_ate")
	jogador.take_damage(50.0, Vector3.ZERO, Vector3.ZERO, 0.0)      # 50 cru: a defesa da história o reduz a ~2, acima da regeneração natural entre os quadros
	verificar(jogador.health < vida - 0.5, "dano volta após cancelar (a defesa da história reduz os 2,0 crus, mas o dano entra)")
	await quadros(45)
	# Controle negativo: uma parede entre lâmina e alvo impede contato.
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = Vector3(4, 3, 0.12)
	cs.shape = forma
	parede.add_child(cs)
	current_scene.add_child(parede)
	parede.global_position = Vector3(0, 1.5, -0.72)
	boneco.global_position = Vector3(0, jogador.global_position.y, -1.5)
	await quadros(3)
	giro.alternar()
	await quadros(100)
	verificar(giro.ativo and is_equal_approx(boneco.health, boneco.max_health), "parede bloqueia dano e não encerra giro")
	giro.encerrar()
	parede.queue_free()
	await quadros(3)
	# Um corpo amigável na trajetória não é um inimigo da técnica.
	boneco.remove_from_group("enemy")
	giro.alternar()
	await quadros(60)
	verificar(giro.ativo and is_equal_approx(boneco.health, boneco.max_health), "alvo sem grupo enemy não toma dano nem encerra")
	giro.encerrar()
	boneco.add_to_group("enemy")
	# Em cada quadrante, contato único, término e impulso real no inimigo.
	for angulo in [0.0, PI * 0.5, PI, PI * 1.5]:
		boneco.global_position = jogador.global_position + Vector3(sin(angulo), 0, cos(angulo)) * 1.45
		boneco._empurrao = Vector3.ZERO
		boneco.remove_meta("mc_inv_ate")      # invulnerabilidade do Minecraft conta em ms REAIS: no headless os 20 quadros entre quadrantes cabem na janela e o 2º acerto zerava (flaky)
		boneco.velocity = Vector3.ZERO
		await quadros(3)
		var antes: float = boneco.health
		var pos_antes: Vector3 = boneco.global_position
		giro.alternar()
		for i in 100:
			await quadros(1)
			if not giro.ativo:
				break
		verificar(not giro.ativo and is_equal_approx(antes - boneco.health, 30.0 + float(jogador.get_meta("bonus_fisico_historia", 0.0))), "contato %.0f°: dano único e encerra" % rad_to_deg(angulo))
		verificar(boneco._empurrao.length() > 7.0, "contato %.0f°: knockback aplicado" % rad_to_deg(angulo))
		await quadros(20)
		verificar(boneco.global_position.distance_to(pos_antes) > 0.3 and is_equal_approx(antes - boneco.health, 30.0 + float(jogador.get_meta("bonus_fisico_historia", 0.0))), "inimigo desloca sem receber dano repetido")
	boneco.queue_free()
	await quadros(3)
	# O jogador pode caminhar para levar a lâmina até o adversário.
	var pos_jogador: Vector3 = jogador.global_position
	giro.alternar()
	var andar := InputEventKey.new()
	andar.physical_keycode = KEY_W
	andar.keycode = KEY_W
	andar.pressed = true
	Input.parse_input_event(andar)
	await quadros(30)
	andar.pressed = false
	Input.parse_input_event(andar)
	verificar(giro.ativo and jogador.global_position.distance_to(pos_jogador) > 0.4, "deslocamento por W continua durante o giro")
	giro.encerrar()
	await quadros(30)
	ex.erguer_guarda()
	verificar(giro.alternar(), "pode iniciar a técnica saindo da guarda")
	giro.encerrar()
	ex.baixar_guarda()
	await quadros(20)
	# Outra imunidade não pode ser removida ao encerrar a técnica.
	jogador.set_meta("damage_immune", true)
	giro.alternar()
	giro.encerrar()
	verificar(jogador.get_meta("damage_immune"), "preserva imunidade concedida por outro sistema")
	jogador.remove_meta("damage_immune")
	giro.alternar()
	prog.equipar_espada(false)
	verificar(not giro.ativo and not jogador.has_meta("giro_espada_ativo"), "desequipar encerra giro e imunidade")
	await quadros(5)
	verificar(not current_scene._hud._tecnicas.visible or not current_scene._hud._tecnicas.texto_da_linha("Z").contains("Giro cortante"), "HUD da técnica da espada some sem espada (a Luta pode ocupar o painel)")
	prog.equipar_espada(true)
	await quadros(5)
	giro.alternar()
	jogador.set_meta("is_frozen", true)
	await quadros(2)
	verificar(not giro.ativo and not jogador.has_meta("giro_espada_ativo"), "incapacitação externa encerra imunidade")
	jogador.remove_meta("is_frozen")
	await quadros(5)
	giro.alternar()
	jogador._setup_character_model("base")
	await quadros(5)
	verificar(not giro.ativo and not jogador.has_meta("giro_espada_ativo"), "troca de rig limpa giro e imunidade")
	verificar(ex.pedir_ataque(0), "cliques continuam funcionando após técnica")
	await quadros(80)
	# Inimigo de mapa sem IA também recebe impulso e volta ao spawn ao renascer.
	var estatico = load("res://src/historia/inimigo_do_mapa.gd").new()
	var colisao := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(0.6, 1.4, 0.6)
	colisao.shape = caixa
	colisao.position.y = 0.7
	estatico.add_child(colisao)
	current_scene.add_child(estatico)
	estatico.add_to_group("enemy")
	estatico.global_position = jogador.global_position + Vector3(0, -0.75, -1.45)
	await quadros(3)
	var origem: Vector3 = estatico.global_position
	giro.alternar()
	await quadros(65)
	verificar(not giro.ativo and is_equal_approx(estatico.health, 250.0 - (30.0 + float(jogador.get_meta("bonus_fisico_historia", 0.0)))), "giro acerta inimigo estático do mapa")
	verificar(estatico.global_position.distance_to(origem) > 0.3, "inimigo estático recebe deslocamento de knockback")
	estatico.take_damage(1000.0)
	estatico._renascer()
	verificar(estatico.global_position.is_equal_approx(origem), "inimigo empurrado renasce na posição original")
	var barreira := StaticBody3D.new()
	var cs_barreira := CollisionShape3D.new()
	var forma_barreira := BoxShape3D.new()
	forma_barreira.size = Vector3(3, 3, 0.2)
	cs_barreira.shape = forma_barreira
	barreira.add_child(cs_barreira)
	current_scene.add_child(barreira)
	barreira.global_position = origem + Vector3(0, 1, -0.8)
	await quadros(3)
	estatico.take_damage(0.0, Vector3.ZERO, Vector3.FORWARD * 10.0)
	await quadros(40)
	verificar(estatico.global_position.z > barreira.global_position.z + 0.3, "knockback do inimigo estático respeita parede")
	barreira.queue_free()
	estatico.queue_free()
	await quadros(3)
	giro.alternar()
	arma.remove_child(giro)
	verificar(not jogador.has_meta("giro_espada_ativo"), "remoção do componente limpa imunidade")
	giro.queue_free()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("GIRO Z DA ESPADA: %d/%d passaram" % [total - falhas, total])
	quit(1 if falhas else 0)
