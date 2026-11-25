extends SceneTree
var j: Node
var c: Node
var hud: Node
var falhas := 0
var total := 0
var tela := false
const CAPTURAS := "res://art_src/validation/machado_bicicleta"
func _init() -> void: rodar.call_deferred()
func ok(sim: bool, texto: String) -> void:
	total += 1
	print(("OK " if sim else "FALHA ") + texto)
	if not sim: falhas += 1
func quadros(n: int) -> void:
	for i in n: await physics_frame
func f() -> void:
	var evento := InputEventKey.new()
	evento.keycode = KEY_F
	evento.physical_keycode = KEY_F
	evento.pressed = true
	hud._unhandled_input(evento)
func rodar() -> void:
	tela = OS.get_cmdline_user_args().has("--tela")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = "user://test_bicicleta_de_gelo.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(modo.progresso_forcado))
	root.get_node("GameFlow").start_story()
	await quadros(100)
	j = current_scene.jogador_local()
	c = j.get_node("BicicletaDeGelo")
	hud = current_scene.get_node("HistoriaHud")
	var prog = current_scene.progressao
	ok(not c.alternar(), "sem Hie não monta")
	prog.comer_fruta("hie_hie")
	await quadros(10)
	j.global_position = Vector3(0,.85,0)
	j.velocity = Vector3.ZERO
	await quadros(20)
	var posicao_modelo: Vector3 = j.modelo_visual().position
	var camada: int = j.collision_layer
	var mascara: int = j.collision_mask
	f()
	await quadros(3)
	ok(c.ativa() and is_instance_valid(c.visual), "F da HUD monta bicicleta com Hie equipada")
	ok(j.collision_layer == camada and j.collision_mask == mascara, "preserva colisão do jogador")
	ok(not j.corpo_livre_para_golpe(), "montado bloqueia ataque a pé")
	ok(hud._tecnicas.texto_da_linha("F").contains("Bicicleta"), "HUD mostra F da bicicleta")
	if not c.ativa():
		quit(1)
		return
	c.piloto = func(_delta): return {"dir": Vector3.FORWARD, "correr": false}
	var inicio: Vector3 = j.global_position
	await quadros(90)
	var distancia: float = inicio.distance_to(j.global_position)
	ok(distancia > 8, "pedala em terra: %.2f m" % distancia)
	var quadril: Node3D = c._ik.no("Torso")
	ok(quadril.global_position.distance_to(c.visual.to_global(Vector3(0,1.18,.28))) < .03, "quadril encaixa no selim")
	ok(c._fase > 0 and c._trilha.size() > 0, "pedais e rastro acompanham movimento")
	if tela: await foto("bicicleta_terra")
	# Parede real: condução passa por move_and_slide, nunca teleporte horizontal.
	var parede := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(10,5,.5)
	forma.shape = caixa
	parede.add_child(forma)
	current_scene.add_child(parede)
	parede.global_position = j.global_position + Vector3(0,1,-3)
	await quadros(60)
	ok(j.global_position.z > parede.global_position.z + 1.2, "volume da bicicleta impede roda de atravessar parede")
	parede.queue_free()
	f()
	await quadros(2)
	ok(not c.ativa() and not j.has_meta("bicicleta_gelo"), "segundo F desmonta e limpa pose")
	ok(j.modelo_visual().position.is_equal_approx(posicao_modelo) and j.get_node_or_null("VolumeBicicleta") == null, "desmontar restaura modelo e remove volume adicional")
	# Monta em terra e atravessa mar real registrado pelo modo.
	j.global_position = Vector3(0,.85,0)
	j.velocity = Vector3.ZERO
	await quadros(20)
	f()
	var mar := AguaDoMundo.nivel_em(300,300)
	ok(not is_nan(mar), "cenário registra mar fora da ilha")
	j.global_position = Vector3(300,mar + c.ALTURA_CENTRO,300)
	j.velocity = Vector3.ZERO
	await quadros(120)
	ok(c.ativa() and absf(j.global_position.y-mar-c.ALTURA_CENTRO) < .12, "pedala sobre água sem afundar")
	ok(j.global_position.z < 290, "avança sobre o mar")
	if tela: await foto("bicicleta_mar")
	j.set_meta("is_frozen", true)
	await quadros(3)
	ok(not c.ativa(), "congelamento desmonta")
	j.set_meta("is_frozen", false)
	j.global_position = Vector3(0,.85,0)
	j.velocity = Vector3.ZERO
	await quadros(20)
	f()
	prog.ativar_item("luta")
	await quadros(3)
	ok(not c.ativa(), "troca de item desmonta")
	ok(not c.alternar(), "fruta guardada não monta")
	prog.ativar_item("fruta")
	c.piloto = Callable()
	await quadros(10)
	for i in 5:
		f()
		await quadros(2)
		ok(c.ativa(), "repetição %d monta" % i)
		f()
		await quadros(2)
	await quadros(160)
	ok(c._trilha.is_empty() and not is_instance_valid(c.visual), "rastro e bicicleta são liberados após desmontar")
	f()
	await quadros(3)
	ok(c.ativa(), "montada ao sair da cena para exercitar limpeza")
	var cena := current_scene
	current_scene = null
	cena.queue_free()
	await quadros(4)
	print("BICICLETA %d/%d; falhas=%d" % [total-falhas,total,falhas])
	quit(1 if falhas else 0)
func foto(nome: String) -> void:
	var cam := Camera3D.new()
	current_scene.add_child(cam)
	cam.global_position = j.global_position + Vector3(3,1.4,3)
	cam.look_at(j.global_position + Vector3.UP*.1)
	cam.make_current()
	# Congela física da captura para enquadramento repetível.
	var piloto_anterior: Callable = c.piloto
	c.piloto = func(_delta): return {"dir": Vector3.ZERO}
	await process_frame
	await RenderingServer.frame_post_draw
	var pasta := ProjectSettings.globalize_path(CAPTURAS)
	DirAccess.make_dir_recursive_absolute(pasta)
	ok(root.get_texture().get_image().save_png(pasta.path_join(nome+".png")) == OK, "captura " + nome)
	c.piloto = piloto_anterior
	cam.queue_free()
