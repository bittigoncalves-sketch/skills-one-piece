extends SceneTree
## Integração com mapa e save isolados; entrada real e medidas no corpo físico.
var j: Node
var bici: Node
var agua: Node
var hud: Node
var prog: RefCounted
var falhas := 0
var total := 0
var tela := false
const PASTA := "res://art_src/validation/sharkman_manobras"

func _init() -> void: rodar.call_deferred()

func ok(valor: bool, texto: String) -> void:
	total += 1
	print(("OK " if valor else "FALHA ") + texto)
	if not valor: falhas += 1

func quadros(n: int) -> void:
	for i in n: await physics_frame

func tecla(k: Key, ligada: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = ligada
	Input.parse_input_event(e)

func montar() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_F
	e.physical_keycode = KEY_F
	e.pressed = true
	hud._unhandled_input(e)

func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = "user://teste_sharkman_manobras.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	root.get_node("GameFlow").start_story()
	await quadros(100)
	j = current_scene.jogador_local()
	bici = j.get_node("BicicletaDeGelo")
	agua = current_scene.get_node("JogadorNaAgua")
	hud = current_scene.get_node("HistoriaHud")
	prog = current_scene.progressao
	await testar_bicicleta()
	await testar_sharkman(modo)
	await testar_luz()
	for k: Key in [KEY_W, KEY_SHIFT, KEY_SPACE, KEY_CTRL]: tecla(k, false)
	var cena := current_scene
	current_scene = null
	cena.queue_free()
	await quadros(4)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	modo.mapa_forcado = ""
	modo.progresso_forcado = ""
	print("SHARKMAN_MANOBRAS %d/%d; falhas=%d" % [total-falhas,total,falhas])
	quit(1 if falhas else 0)

func testar_bicicleta() -> void:
	prog.comer_fruta("hie_hie")
	j.position = Vector3(0, .85, 0)
	j.velocity = Vector3.ZERO
	j._yaw = 0.0
	await quadros(20)
	montar()
	ok(bici.ativa(), "F monta bicicleta")
	var origem: float = j.position.y
	tecla(KEY_SPACE, true)
	await quadros(10)
	ok(j.position.y > origem + .5 and bici.pulos == 1, "Espaço salta no chão")
	await quadros(3)
	ok(bici.pulos == 1, "segurar Espaço não repete salto")
	tecla(KEY_SPACE, false)
	await quadros(2)
	tecla(KEY_SPACE, true)
	await quadros(12)
	ok(bici.pulos == 2 and bici.giro > 1.0 and bici.giro < TAU, "segundo Espaço inicia salto com giro")
	ok(absf(angle_difference(j.modelo_visual().rotation.y, bici.visual.rotation.y)) < .001,
		"ciclista acompanha o giro da bicicleta")
	if tela: await foto_bici("giro")
	tecla(KEY_SPACE, false)
	await quadros(2)
	var vy: float = j.velocity.y
	tecla(KEY_SPACE, true)
	await quadros(2)
	ok(bici.pulos == 2 and j.velocity.y < vy, "terceiro Espaço não dá impulso")
	tecla(KEY_SPACE, false)
	var max_giro: float = bici.giro
	for i in 25:
		await physics_frame
		max_giro = maxf(max_giro, bici.giro)
	ok(is_equal_approx(max_giro, TAU), "giro completa exatamente 360 graus")
	await quadros(55)
	ok(j.is_on_floor() and bici.pulos == 0, "pouso no chão recupera os dois saltos")
	tecla(KEY_W, true)
	tecla(KEY_CTRL, true)
	await quadros(35)
	ok(bici.visual.rotation.x > .35, "Ctrl empina com movimento")
	if tela: await foto_bici("empinada")
	tecla(KEY_CTRL, false)
	j._yaw = .8
	await quadros(3)
	ok(absf(bici.visual.rotation.z) > .01, "inclina ao fazer curva")
	tecla(KEY_W, false)
	await quadros(20)
	hud.alternar_status()
	tecla(KEY_SPACE, true)
	await quadros(3)
	ok(bici.pulos == 0, "menu bloqueia salto")
	tecla(KEY_SPACE, false)
	hud.alternar_status()
	var nivel := AguaDoMundo.nivel_em(300, 300)
	j.position = Vector3(300, nivel + bici.ALTURA_CENTRO, 300)
	j.velocity = Vector3.ZERO
	await quadros(4)
	tecla(KEY_SPACE, true)
	await quadros(12)
	ok(j.position.y > nivel + bici.ALTURA_CENTRO + .6, "salta a partir da superfície do mar")
	tecla(KEY_SPACE, false)
	await quadros(90)
	ok(bici.ativa() and bici.pulos == 0 and absf(j.position.y - nivel - bici.ALTURA_CENTRO) < .1,
		"pousa sobre o gelo do mar e recupera saltos")
	tecla(KEY_SPACE, true)
	await quadros(5)
	tecla(KEY_SPACE, false)
	await quadros(2)
	tecla(KEY_SPACE, true)
	await quadros(5)
	montar()
	ok(not bici.ativa() and absf(j.modelo_visual().rotation.x) < .001
		and absf(j.modelo_visual().rotation.z) < .001, "desmontar durante manobra restaura postura")
	tecla(KEY_SPACE, false)
	j.position = Vector3(0, .85, 0)
	j.velocity = Vector3.ZERO
	prog.ativar_item("luta")
	await quadros(35)

func testar_sharkman(modo: GDScript) -> void:
	prog.definir_fruta_ativa(false)
	hud.alternar_status()
	var seletor: OptionButton = hud.janela_de_status().find_child("EscolherRaca", true, false)
	seletor.select(1)
	seletor.item_selected.emit(1)
	ok(prog.raca == "sharkman", "M permite escolher Sharkman")
	ok(j.modelo_visual().get_meta("raca_id", "") == "sharkman", "modelo recebe raça da campanha")
	var materiais: Array = j.modelo_visual().get_meta("sharkman_materiais_originais", [])
	ok(materiais.size() >= 8, "pele Sharkman aplicada às partes do corpo")
	var dorsal: Node3D = j.modelo_visual().find_child("SharkmanHistoriaDorsal", true, false)
	var malha: MeshInstance3D = dorsal.get_child(0)
	var tamanho: Vector3 = malha.global_basis.get_scale() * malha.mesh.get_aabb().size
	ok(tamanho.y < .6 and tamanho.z < .5, "barbatana dorsal proporcional em metros: " + str(tamanho))
	ok(prog.get_script().carregar(modo.progresso_forcado).raca == "sharkman", "save recarrega raça Sharkman")
	var dados: Dictionary = prog.para_dict()
	dados.raca = "raca_invalida"
	ok(prog.get_script().de_dict(dados).raca == "humano", "raça inválida migra para humano")
	hud.alternar_status()
	j._yaw = 0.0
	tecla(KEY_W, true)
	tecla(KEY_SHIFT, true)
	await quadros(70)
	var corrida: float = Vector2(j.velocity.x, j.velocity.z).length()
	tecla(KEY_SHIFT, false)
	var nivel := AguaDoMundo.nivel_em(300, 0)
	j.position = Vector3(300, nivel - .4, 0)
	j.velocity = Vector3.ZERO
	await quadros(80)
	var normal: float = Vector2(j.velocity.x, j.velocity.z).length()
	ok(j.modo_na_agua == "nadando" and absf(normal - corrida) < .05,
		"nado normal = corrida (%.3f / %.3f m/s)" % [normal, corrida])
	j.energy = j.max_energy
	var energia: float = j.energy
	tecla(KEY_SHIFT, true)
	await quadros(40)
	var rapido: float = Vector2(j.velocity.x, j.velocity.z).length()
	ok(absf(rapido - normal * 2.0) < .05, "nado rápido = 2x normal (%.3f m/s)" % rapido)
	ok(j.energy < energia - .4, "nado rápido consome energia líquida")
	j.energy = 0.0
	await quadros(3)
	ok(not agua.nado_rapido and absf(Vector2(j.velocity.x, j.velocity.z).length() - normal) < .05,
		"energia esgotada volta ao nado normal")
	await quadros(30)
	ok(not agua.nado_rapido, "exaustão não alterna velocidades a cada quadro")
	tecla(KEY_SHIFT, false)
	tecla(KEY_W, false)
	j.position = Vector3(300, nivel - 5, 0)
	j.velocity = Vector3.ZERO
	j.set_physics_process(false)
	var vida: float = j.health
	for i in 40: agua._physics_process(1.0)
	ok(agua.folego == agua.FOLEGO_MAXIMO and j.health == vida, "40 s submerso: respiração infinita e nenhum dano")
	prog.definir_raca("humano")
	var restaurados := true
	for registro: Dictionary in materiais:
		restaurados = restaurados and registro.no.material_override == registro.material
	ok(restaurados, "trocar para humano restaura materiais originais")
	agua._physics_process(31.0)
	ok(agua.folego == 0.0 and j.health < vida, "controle humano perde fôlego e sofre dano")
	prog.definir_raca("sharkman")
	agua._physics_process(.1)
	ok(agua.folego == agua.FOLEGO_MAXIMO, "trocar para Sharkman restaura fôlego")
	j.health = j.max_health
	j.set_physics_process(true)
	j.position = Vector3(0, .85, 0)
	j.velocity = Vector3.ZERO
	await quadros(35)
	ok(j.modo_na_agua.is_empty() and j.fator_da_agua == 1.0, "voltar à terra limpa nado")

func testar_luz() -> void:
	var luz := current_scene.get_node("LuzDeMergulho")
	await quadros(50)
	ok(not luz.luz.visible, "luz subaquática apagada na terra")
	var nivel := AguaDoMundo.nivel_em(300, 0)
	j.set_physics_process(false)
	j.position = Vector3(300, nivel - 8, 0)
	await quadros(90)
	ok(luz.luz.visible and luz.luz.light_energy > 2.0, "mergulho acende preenchimento do fundo")
	ok(luz.global_position.distance_to(j.position + Vector3.UP * 1.5) < .01, "luz acompanha jogador")
	if tela: await fotos_mergulho(luz)
	j.position = Vector3(0, .85, 0)
	await quadros(90)
	ok(not luz.luz.visible, "emergir apaga iluminação gradualmente")
	j.set_physics_process(true)

func foto_bici(nome: String) -> void:
	j.set_physics_process(false)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.position = j.position + Vector3(3, 1.4, 3)
	cam.look_at(j.position + Vector3.UP * .3)
	cam.make_current()
	await foto(nome)
	cam.queue_free()
	j.set_physics_process(true)

func fotos_mergulho(luz: Node) -> void:
	# Mesmo enquadramento/material: luz desligada e ligada, sem mudar o ambiente.
	var raio := PhysicsRayQueryParameters3D.create(j.position + Vector3.UP * 3,
		j.position - Vector3.UP * 100, 1, [j.get_rid()])
	var contato: Dictionary = j.get_world_3d().direct_space_state.intersect_ray(raio)
	ok(not contato.is_empty(), "captura encontra o fundo real do mar")
	if contato.is_empty(): return
	j.position = contato.position + Vector3.UP * 2.0
	await quadros(80)
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.position = j.position + Vector3(4, 1, 6)
	cam.look_at(j.position - Vector3.UP)
	cam.make_current()
	luz.set_process(false)
	luz.luz.visible = false
	await foto("mergulho_sem_luz")
	luz.luz.visible = true
	await foto("mergulho_com_luz")
	luz.set_process(true)
	cam.queue_free()

func foto(nome: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var pasta := ProjectSettings.globalize_path(PASTA)
	DirAccess.make_dir_recursive_absolute(pasta)
	ok(root.get_texture().get_image().save_png(pasta.path_join(nome + ".png")) == OK, "captura " + nome)
