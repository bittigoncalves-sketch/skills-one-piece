extends SceneTree
const PASTA := "res://art_src/validation/flor_de_buda/"
var total := 0
var falhas := 0
var _meta_ctl: StringName   # lido em tempo de execução: referência estática compilava o Player antes dos autoloads

class Alvo extends Node3D:
	var health := 1000.0
	var hits := 0
	var empurrao := Vector3.ZERO
	func _ready() -> void:
		add_to_group(AlvosDeGolpe.GRUPO)
	func take_damage(dano: float, _origem: Vector3, impulso: Vector3, _stun: float) -> void:
		health -= dano
		hits += 1
		empurrao = impulso

func _init() -> void:
	executar.call_deferred()

func verificar(condicao: bool, descricao: String) -> void:
	total += 1
	if not condicao: falhas += 1
	print(("PASS " if condicao else "FALHA ")+descricao)

func quadros(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func alvo(pos: Vector3, aliado := false) -> Alvo:
	var a := Alvo.new()
	current_scene.add_child(a)
	a.global_position = pos
	if aliado: a.set_meta("membro_tripulacao", true)
	return a

func executar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://flor_buda_teste.json")
	root.get_node("GameFlow").start_story()
	await quadros(240)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	# O mod libera golpes por conquista (como `varredura_frutas_do_mod.gd`): sem isto a fruta lista só 1 técnica.
	var avancos = McEntidade.de(j).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	await quadros(10)
	modo.equipar_fruta(j,"hito_hito_daibutsu")
	await quadros(12)
	var c = j.get_node("FrutaMinePiece")
	_meta_ctl = load("res://src/combat/frutas_mine_piece/controlador.gd").META
	verificar(is_instance_valid(c.flor_de_buda), "componente carregado sem erro de compilação")
	if not is_instance_valid(c.flor_de_buda):
		quit(1)
		return
	var flor = c.flor_de_buda
	j.max_energy = 500.0
	j.energy = 500.0
	c._sincronizar_para_o_mod()
	var energia: float = j.energy
	c.usar_tecla("X",true)
	verificar(not flor.ativo and j.energy == energia, "sem transformação recusa sem gastar energia")
	verificar(c.mapa_de_teclas().X == 1001, "X aponta para Flor de Buda")
	verificar(c.mapa_de_teclas().C == int(c._lista[1].numero), "antiga X preservada em C")
	verificar(c.mapa_de_teclas().V == int(c._lista[2].numero), "antiga C preservada em V")
	var linha: Dictionary = c.estado_das_tecnicas().filter(func(e): return e.nome == "Flor de Buda")[0]
	verificar(linha.tecla == "X" and linha.requisito != "", "HUD informa nome, tecla e transformação exigida")
	c.transformar(false)
	await quadros(20)
	# A transformação ocupa o controlador (~2 s); a Flor só vale depois dela. Esperar o fim em vez de contar quadros fixos.
	var _n := 0
	while c.ativo and _n < 400:
		await quadros(5)
		_n += 5
	j.energy = 1.0
	c._sincronizar_para_o_mod()
	c.usar_tecla("X",true)
	verificar(not flor.ativo and j.energy == 1.0, "energia insuficiente não inicia")
	j.energy = 500.0
	c._sincronizar_para_o_mod()
	var pe: Vector3 = j._char_model.global_position
	var perto := alvo(pe+Vector3(5,1,0))
	var duplicado := alvo(pe+Vector3(-5,1,0))
	duplicado.add_to_group("enemy")
	var longe := alvo(pe+Vector3(13,1,0))
	var amigo := alvo(pe+Vector3(3,1,0),true)
	# Mesmo caminho usado pelo HUD, incluindo apertar e soltar.
	var tecla := InputEventKey.new()
	tecla.keycode = KEY_X
	tecla.physical_keycode = KEY_X
	tecla.pressed = true
	Input.parse_input_event(tecla)
	verificar(flor.ativo, "tecla X real inicia")
	verificar(is_equal_approx(j.energy,460.0), "cobra 40 de energia uma vez")
	c.usar_tecla("X",true)
	verificar(is_equal_approx(j.energy,460.0), "repetição de X não duplica custo")
	tecla = InputEventKey.new()
	tecla.keycode = KEY_X
	tecla.physical_keycode = KEY_X
	tecla.pressed = false
	Input.parse_input_event(tecla)
	verificar(flor.ativo, "soltar X mantém a sequência")
	verificar(c.controla_movimento() and j.has_meta(_meta_ctl), "senta com movimento e outros golpes bloqueados")
	c.usar_tecla("Z",true)
	c.transformar(false)
	verificar(c.forma_atual() == 1 and c.selecao == 1001, "outra técnica e J não interrompem a preparação")
	await quadros(48)
	verificar(perto.hits == 0, "antecipação não causa dano")
	var forma: FormaZoan = j.get_node("FormaZoan")
	verificar(forma.peso_flor > 0.95, "pose sentada chega ao peso completo")
	verificar(get_nodes_in_group("flor_de_buda_vfx").size() == 1, "uma flor visual por conjuração")
	await foto(j,"01_sentado",15.0)
	await quadros(30)
	verificar(perto.hits == 1 and perto.health < 1000.0, "explosão causa um acerto no alvo próximo")
	verificar(duplicado.hits == 1, "alvo em dois grupos não recebe dano duplicado")
	verificar(amigo.hits == 0, "tripulante aliado protegido")
	verificar(longe.hits == 0, "alvo fora do raio não é atingido")
	verificar(perto.empurrao.length() > 0.0, "explosão empurra o inimigo")
	await foto(j,"02_explosao",25.0)
	await quadros(18)
	await foto(j,"03_ondas_e_raios",25.0)
	await quadros(80)
	verificar(not flor.ativo and not c.controla_movimento(), "movimento liberado ao terminar")
	verificar(is_zero_approx(forma.peso_flor), "pose restaurada ao terminar")
	verificar(get_nodes_in_group("flor_de_buda_vfx").is_empty(), "efeitos removidos ao terminar")
	verificar(perto.hits == 1, "luzes decorativas não repetem o dano")
	verificar(not j.has_meta(_meta_ctl), "trava de combate removida")
	verificar(flor.recarga > 0, "recarga continua depois da animação")
	energia = j.energy
	c.usar_tecla("X",true)
	verificar(not flor.ativo and j.energy == energia, "recarga impede novo uso sem gastar energia")
	flor.recarga = 0.0
	c.usar_tecla("X",true)
	await quadros(6)
	j.morrendo = true
	await quadros(3)
	verificar(not flor.ativo and get_nodes_in_group("flor_de_buda_vfx").is_empty(), "morte cancela pose e VFX")
	verificar(perto.hits == 1, "cancelamento antes da explosão não causa dano")
	j.morrendo = false
	flor.recarga = 0.0
	c.usar_tecla("X",true)
	await quadros(6)
	modo.equipar_fruta(j,"gomu_gomu")
	await quadros(8)
	verificar(get_nodes_in_group("flor_de_buda_vfx").is_empty(), "troca de fruta remove VFX em andamento")
	verificar(not j.has_meta(_meta_ctl), "troca de fruta libera combate")
	verificar(perto.hits == 1, "troca de fruta cancela dano pendente")
	print("FLOR_DE_BUDA: %d verificações, %d falhas" % [total,falhas])
	quit(1 if falhas else 0)

func foto(j: Node3D, nome: String, tamanho: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var vp := SubViewport.new()
	vp.size = Vector2i(1400,1000)
	vp.world_3d = j.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = tamanho
	var centro: Vector3 = j._char_model.global_position+Vector3.UP*1.5
	var frente: Vector3 = -j._char_model.global_basis.z.normalized()
	camera.global_position = centro+frente*20+j._char_model.global_basis.x.normalized()*9+Vector3.UP*12
	camera.look_at(centro)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(PASTA+nome+".png"))
	vp.queue_free()
	await process_frame
