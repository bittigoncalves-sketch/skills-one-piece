extends SceneTree
## Campanha real, save descartável, input real do HUD e capturas opcionais.
const P = preload("res://src/historia/tripulantes/provisoes.gd")
const SAVE := "user://test_alimentacao.json"
const PASTA := "res://art_src/validation/alimentacao"
var falhas := 0
var total := 0
var capturar := false
var j: Node3D
var controle: Node
var hud: Node
var prog: ProgressaoDoPersonagem
var camera: Camera3D
var camera_jogo: Camera3D
func _init() -> void: executar.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func ok(sim: bool, texto: String) -> void:
	total += 1
	if not sim: falhas += 1
	print(("OK: " if sim else "FALHOU: ") + texto)
func clique(pressionado := true) -> void:
	var evento := InputEventMouseButton.new()
	evento.button_index = MOUSE_BUTTON_RIGHT
	evento.pressed = pressionado
	hud._input(evento)
func selecionar(item: String) -> void:
	prog.item_ativo = item
	prog.mudou.emit()
func foto(nome: String) -> void:
	if not capturar: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PASTA.path_join(nome + ".png"))
func executar() -> void:
	await process_frame
	capturar = "--capturar" in OS.get_cmdline_user_args()
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.mapa_forcado = "res://tools/dev_tests/fixtures/mapa_baseplate.json"
	modo.progresso_forcado = SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	# Este teste começa com personagem já escolhido; seleção tem teste próprio.
	var personagem = ProgressaoDoPersonagem.carregar(SAVE)
	personagem.corpo = "feminino" if "--feminino" in OS.get_cmdline_user_args() else "masculino"
	personagem.salvar(SAVE)
	root.get_node("GameFlow").start_story()
	await frames(160)
	var cena = current_scene
	j = cena.jogador_local()
	prog = cena.progressao
	hud = cena.get("_hud")
	if j == null:
		push_error("ALIMENTACAO: cenário não montou")
		quit(1)
		return
	controle = j.get_node("AlimentacaoVisual")
	ok(controle != null, "apresentação existe no jogador da campanha")
	j.set_meta("damage_immune", true)
	j._char_model.rotation.y = 0
	P.guardar(prog, "pao", 3)
	P.guardar(prog, "agua_potavel", 3)
	if capturar:
		camera_jogo = root.get_camera_3d()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		root.size = Vector2i(1280, 800)
		camera = Camera3D.new()
		cena.add_child(camera)
		camera.global_position = j.global_position + Vector3(1.5, .85, -2.3)
		camera.look_at(j.global_position + Vector3(0, .20, 0))
		camera.fov = 42
		camera.make_current()
	selecionar("comida")
	await frames(4)
	ok(is_instance_valid(controle.visual), "pão aparece ao equipar comida com estoque")
	await foto("01_pao_equipado")
	P.estado(prog).fome = 100.0
	var fome: float = P.estado(prog).fome
	clique()
	ok(controle.tempo == 0 and P.quantidade_comida(prog) == 2, "clique consome uma unidade e inicia comer")
	clique(false)
	ok(P.quantidade_comida(prog) == 2, "soltar botão não duplica consumo")
	await frames(43)
	ok(j.has_meta("alimentacao_pose") and controle.tempo > .5, "animação chega ao contato")
	var boca: Vector3 = j._proc_anim._n["Head"].to_global(Vector3(0,.12,-.22))
	ok(controle.visual.global_position.distance_to(boca) < .12, "pão alcança a região da boca no contato")
	await foto("02_mordida")
	if capturar and is_instance_valid(camera_jogo):
		camera_jogo.make_current()
		await foto("04_comer_camera_jogo")
		camera.make_current()
	for papel in ["UpperArm_R", "ForeArm_R", "Head"]:
		print("RIG ",papel," pos=", j._proc_anim._n[papel].global_position," rest=",j._proc_anim._rest.get(papel))
	print("POSE_COMER ", j._proc_anim._n["UpperArm_R"].rotation, " ", j._proc_anim._n["ForeArm_R"].rotation)
	print("MAO ",j._rig.item_handle.global_position," CABECA ",j._proc_anim._n["Head"].global_position)
	await frames(85)
	ok(not j.has_meta("alimentacao_pose") and controle.tempo < 0, "fim da ação devolve locomoção")
	selecionar("agua")
	await frames(4)
	await foto("03a_agua_equipada")
	clique()
	ok(P.quantidade_agua(prog) == 2 and controle.tipo == "agua", "água usa seu próprio asset e ação")
	await frames(60)
	boca = j._proc_anim._n["Head"].to_global(Vector3(0,.12,-.22))
	ok(controle.visual.to_global(controle.contato_local()).distance_to(boca) < .08, "gargalo alcança a boca durante o gole")
	await foto("03_gole")
	print("GARGALO ", controle.visual.to_global(controle.contato_local()), " BOCA ", j._proc_anim._n["Head"].to_global(Vector3(0,.12,-.22)))
	print("POSE_BEBER ", j._proc_anim._n["UpperArm_R"].rotation, " ", j._proc_anim._n["ForeArm_R"].rotation)
	print("MAO ",j._rig.item_handle.global_position," CABECA ",j._proc_anim._n["Head"].global_position)
	# A corrida não pode sobrepor os braços da alimentação.
	var braco: Node3D = j._proc_anim._n["UpperArm_R"]
	var antes := braco.quaternion
	j._proc_anim.update(Vector3(0,0,-4), true, false, 1.0/60.0, 0.0, true)
	if j.modelo_visual().has_meta("corpo_historia"):
		# A IK pode compensar o movimento do tronco com outra rotação de braço.
		# O contrato visível é o contato, não repetir o ângulo do rig antigo.
		boca = j._proc_anim._n["Head"].to_global(Vector3(0,.136,-.246))
		print("CONTATO_CORRIDA ", controle.visual.to_global(controle.contato_local()).distance_to(boca))
		ok(controle.visual.to_global(controle.contato_local()).distance_to(boca) < .08,
			"corrida preserva contato da garrafa com a boca")
	else:
		ok(antes.angle_to(braco.quaternion) < .12, "corrida preserva o braço que leva a garrafa à boca")
	selecionar("luta")
	await frames(2)
	ok(not is_instance_valid(controle.visual) and not j.has_meta("alimentacao_pose"), "troca de slot remove item e pose")
	P.estado(prog).estoque.pao = 1
	selecionar("comida")
	clique()
	await frames(3)
	ok(is_instance_valid(controle.visual) and P.quantidade_comida(prog) == 0, "última unidade continua visível durante mordida")
	await frames(200)      # comer agora leva ~2,1 s (pão), 20/11/2026
	ok(not is_instance_valid(controle.visual), "estoque vazio esconde item após terminar")
	clique()
	ok(controle.tempo < 0 and P.quantidade_comida(prog) == 0, "sem estoque não inicia animação nem fica negativo")
	selecionar("agua")
	clique()
	await frames(10)
	j.health = 0
	j.morrendo = true
	await frames(2)
	print("MORTE health=", j.health, " pose=", j.has_meta("alimentacao_pose"), " visual=", is_instance_valid(controle.visual))
	ok(not is_instance_valid(controle.visual) and not j.has_meta("alimentacao_pose"), "morte limpa visual e pose")
	j.health = j.max_health
	j.morrendo = false
	await frames(3)
	ok(is_instance_valid(controle.visual) and controle.tempo < 0, "reviver remonta item sem repetir consumo")
	# Alteração de corpo recria o encaixe; não deve manter referência ao nó antigo.
	j._rig.montar(j.character_id)
	await frames(5)
	ok(is_instance_valid(controle.visual) and controle.visual.get_parent() == j._rig.item_handle, "troca de rig remonta no encaixe novo")
	ok(P.estado(prog).fome >= fome, "regra de nutrição preservada")
	P.guardar(prog, "pao", 2)
	selecionar("comida")
	clique()
	j.set_meta("custom_pose", "dano")
	await frames(2)
	ok(not j.has_meta("alimentacao_pose"), "reação de dano cancela a pose de alimentação")
	j.remove_meta("custom_pose")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("ALIMENTACAO: %d/%d passaram; %d falhas" % [total - falhas, total, falhas])
	quit(1 if falhas else 0)
