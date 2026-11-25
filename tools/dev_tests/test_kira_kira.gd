extends SceneTree
## Modo História: textura, investida, dano, parede, recarga e limpeza.
var total := 0
var falhas := 0
var jogador

class Alvo extends StaticBody3D:
	var health := 1000.0
	var hits := 0
	var dano := 0.0
	var impulso := Vector3.ZERO
	func _ready() -> void:
		add_to_group(AlvosDeGolpe.GRUPO)
		collision_layer = 1
		collision_mask = 0
		var col := CollisionShape3D.new()
		var esfera := SphereShape3D.new()
		esfera.radius = 0.45
		col.shape = esfera
		add_child(col)
	func take_damage(valor: float, _origem: Vector3, recebido: Vector3, _stun: float) -> void:
		hits += 1
		dano += valor
		health -= valor
		impulso = recebido

func _init() -> void:
	rodar.call_deferred()

func ok(valor: bool, texto: String) -> void:
	total += 1
	if not valor: falhas += 1
	print(("PASS " if valor else "FALHA ") + texto)

func quadros(n: int) -> void:
	for i in n:
		if is_instance_valid(jogador):
			jogador.capacidades.can_use_fruit = true
		await physics_frame
		await process_frame

func criar_alvo(pos: Vector3) -> Alvo:
	var a := Alvo.new()
	current_scene.add_child(a)
	a.global_position = pos
	return a

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://kira_codex_teste.json")
	root.get_node("GameFlow").start_story()
	await quadros(200)
	jogador = get_first_node_in_group("player")
	var avancos = McEntidade.de(jogador).conquistas_do_jogador()
	for d in McConquistas.definicoes().values():
		if d != null:
			for criterio in d.criterios:
				avancos.award(d, criterio)
	var prog = current_scene.get("progressao")
	prog.fruta = "kira_kira"
	prog.fruta_ativa = true
	prog.skills["fruta"] = maxi(1, int(prog.skills.get("fruta", 0)))
	prog.item_ativo = prog.NENHUM_ITEM
	modo.equipar_fruta(jogador, "kira_kira")
	await quadros(15)
	var c = jogador.get_node("FrutaMinePiece")
	var k = c.kira_investida
	jogador.max_energy = 2000.0
	jogador.energy = 2000.0
	jogador.set_meta("damage_immune", true)
	DanoDaHistoria.ligar_para(true)
	ok(not FormaZoan.substitui_corpo("kira_kira"), "diamante é uma camada sobre o corpo")
	ok(c.mapa_de_teclas().get("Z", 0) == k.NUMERO and c.mapa_de_teclas().has("X") and c.mapa_de_teclas().has("C"), "Z próprio e demais técnicas preservadas")
	var frente: Vector3 = c.olhar()
	frente.y = 0.0
	frente = frente.normalized()
	var inicio: Vector3 = jogador.global_position
	var lado := frente.cross(Vector3.UP).normalized()
	var longe := criar_alvo(inicio + frente * 20.0 + Vector3.UP * 0.9)
	var a := criar_alvo(inicio + frente * 8.0 + Vector3.UP * 0.9)
	var proximo := criar_alvo(inicio + frente * 8.0 + lado * 2.5 + Vector3.UP * 0.9)
	var achado: Dictionary = k._primeiro_contato(inicio + Vector3.UP * 0.9, inicio + frente * 22.0 + Vector3.UP * 0.9)
	ok(achado.get("alvo") == a, "varredura escolhe primeiro inimigo mesmo quando o mais distante foi criado antes")
	var energia: float = jogador.energy
	jogador.remove_meta("damage_immune")
	var vida_antes: float = jogador.health
	c.usar_tecla("Z", true)
	c.usar_tecla("Z", false)
	ok(k.ativo and is_instance_valid(jogador.get_node_or_null("FormaZoan")) and jogador._char_model.visible, "Z transforma imediatamente mantendo o corpo")
	var malhas: Array[Node] = jogador._char_model.find_children("*", "MeshInstance3D", true, false)
	var diamante_ok: bool = not malhas.is_empty() and malhas.all(func(m): return m.material_overlay is ShaderMaterial and m.material_overlay.shader.resource_path == "res://src/combat/kira/diamante.gdshader")
	ok(diamante_ok, "material de diamante cobre as malhas articuladas")
	ok(absf(energia - jogador.energy - k.CUSTO) < 0.01, "Z cobra energia uma vez")
	jogador.take_damage(8.0)
	ok(is_equal_approx(jogador.health, vida_antes) and jogador.get_meta("kira_investida_imune", false), "jogador é imune a dano durante o Z")
	await quadros(15)
	ok(k.ativo and is_instance_valid(jogador.get_node_or_null("FormaZoan")), "corpo permanece transformado durante a investida")
	for i in 160:
		await quadros(1)
		if not k.ativo: break
	ok(not k.ativo and not is_instance_valid(jogador.get_node_or_null("FormaZoan")), "fim devolve a forma normal")
	ok(malhas.all(func(m): return not is_instance_valid(m) or not (m.material_overlay is ShaderMaterial and m.material_overlay.shader.resource_path == "res://src/combat/kira/diamante.gdshader")), "fim restaura os materiais do corpo")
	ok(jogador.global_position.distance_to(inicio) > 3.0, "jogador desloca-se na investida")
	ok((jogador.global_position - inicio).dot(frente) < 8.0, "Z para ao encontrar o primeiro inimigo")
	ok(a.hits == 1 and absf(a.dano - 7.5 * k.MULT_DANO_ALVO) < 0.01 and a.impulso.dot(frente) > 20.0 and a.impulso.y > 5.0, "alvo atingido leva o dano do impacto uma vez e é arremessado na direção da investida (%.2f, %d acertos)" % [a.dano, a.hits])
	ok(proximo.hits == 1 and proximo.impulso.dot(lado) > 1.0 and proximo.impulso.y > 0.0, "explosão atinge e empurra lateralmente o inimigo próximo")
	ok(longe.hits == 0, "explosão não atinge inimigos distantes")
	ok(not get_nodes_in_group("kira_explosao_visual").is_empty(), "impacto cria explosão de estilhaços")
	ok(not jogador.has_meta("kira_investida_imune"), "imunidade da investida termina no impacto")
	jogador.take_damage(8.0)
	ok(jogador.health < vida_antes, "jogador volta a receber dano depois do Z")
	jogador.health = vida_antes
	jogador.set_meta("damage_immune", true)
	a.queue_free()
	proximo.queue_free()
	longe.queue_free()
	ok(c.recarga_da_tecnica(k.NUMERO) > 0.0, "Z mantém recarga própria")
	c.usar_tecla("Z", true)
	ok(not k.ativo and not is_instance_valid(jogador.get_node_or_null("FormaZoan")), "recarga impede outra investida e transformação")
	await quadros(105)
	ok(get_nodes_in_group("kira_explosao_visual").is_empty(), "estilhaços são removidos após a explosão")
	# Alvos fora da onda inicial só podem ser feridos pelos fragmentos em voo.
	c.iniciar_recarga(k.NUMERO, 0.0)
	var centro_fragmentos: Vector3 = jogador.global_position + Vector3.UP * 0.9
	var direcoes_teste := [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.UP]
	var alvos_fragmentos: Array[Alvo] = []
	for sentido: Vector3 in direcoes_teste:
		alvos_fragmentos.append(criar_alvo(centro_fragmentos + sentido * 7.0))
	var bloqueado := criar_alvo(centro_fragmentos + Vector3.RIGHT * 7.0)
	var aliado := criar_alvo(centro_fragmentos + Vector3(0.7, 0.0, -0.7).normalized() * 7.0)
	aliado.set_meta("membro_tripulacao", true)
	var distante := criar_alvo(centro_fragmentos + Vector3(0.7, 0.0, 0.7).normalized() * 14.0)
	var parede_particulas := StaticBody3D.new()
	var col_particulas := CollisionShape3D.new()
	var parede_forma := BoxShape3D.new()
	parede_forma.size = Vector3(0.4, 6.0, 4.0)
	col_particulas.shape = parede_forma
	parede_particulas.add_child(col_particulas)
	current_scene.add_child(parede_particulas)
	parede_particulas.global_position = centro_fragmentos + Vector3.RIGHT * 3.5
	await quadros(4)
	c.usar_tecla("Z", true)
	k._explodir(centro_fragmentos)
	c.cancelar() # a nuvem continua em voo depois que a investida termina
	var nuvens := get_nodes_in_group("kira_explosao_visual")
	var direcoes_reais: PackedVector3Array = nuvens.back().direcoes if not nuvens.is_empty() else PackedVector3Array()
	var acima := false
	var abaixo := false
	for d in direcoes_reais:
		acima = acima or d.y > 0.5
		abaixo = abaixo or d.y < -0.5
	ok(direcoes_reais.size() >= 36 and acima and abaixo, "estilhaços saem em todas as direções e detectam inimigos próximos")
	ok(alvos_fragmentos.all(func(alvo): return alvo.hits == 0), "alvos distantes não sofrem dano antes de os estilhaços chegarem")
	var colado := criar_alvo(centro_fragmentos + Vector3.RIGHT * 4.05)
	load("res://src/combat/kira/kira_explosao.gd").criar(current_scene, centro_fragmentos, PackedVector3Array([Vector3.RIGHT]), jogador, 6.0)
	await quadros(55)
	ok(alvos_fragmentos.all(func(alvo): return alvo.hits == 1 and absf(alvo.dano - 3.0) < 0.01), "fragmentos causam dano uma vez a cada alvo em várias direções")
	ok(bloqueado.hits == 0, "parede bloqueia os fragmentos")
	ok(colado.hits == 0, "fragmento não atinge inimigo encostado atrás da parede")
	ok(aliado.hits == 0 and distante.hits == 0, "fragmentos preservam aliados e não alcançam o alvo distante")
	for alvo in alvos_fragmentos:
		alvo.queue_free()
	bloqueado.queue_free()
	colado.queue_free()
	aliado.queue_free()
	distante.queue_free()
	parede_particulas.queue_free()
	await quadros(8)
	c.iniciar_recarga(k.NUMERO, 0.0)
	c.transformar(false)
	await quadros(10)
	ok(c.forma_atual() > 0 and jogador._char_model.visible and is_instance_valid(jogador.get_node_or_null("FormaZoan")), "transformação manual mantém skin e camada de diamante")
	c.usar_tecla("Z", true)
	await quadros(135)
	ok(not k.ativo and c.forma_atual() > 0 and is_instance_valid(jogador.get_node_or_null("FormaZoan")), "investida preserva transformação anterior")
	c.transformar(false)
	await quadros(10)
	c.iniciar_recarga(k.NUMERO, 0.0)
	c.usar_tecla("Z", true)
	await quadros(5)
	c.cancelar()
	ok(not k.ativo and not is_instance_valid(jogador.get_node_or_null("FormaZoan")) and not jogador.has_meta("pose_externa"), "cancelamento limpa forma temporária e pose")
	ok(not jogador.has_meta("kira_investida_imune") and jogador.get_meta("damage_immune", false), "cancelamento limpa só a imunidade do Z")
	await quadros(5)
	c.iniciar_recarga(k.NUMERO, 0.0)
	var origem_longa: Vector3 = jogador.global_position
	var rumo_longo: Vector3 = c.olhar()
	rumo_longo.y = 0.0
	rumo_longo = rumo_longo.normalized()
	c.usar_tecla("Z", true)
	for i in 200:
		await quadros(1)
		if not k.ativo: break
	var distancia_longa: float = (jogador.global_position - origem_longa).dot(rumo_longo)
	ok(distancia_longa > 18.0, "Z sem obstáculos ultrapassa o alcance anterior (%.2f m)" % distancia_longa)
	ok(not get_nodes_in_group("kira_explosao_visual").is_empty(), "fim do percurso também cria explosão")
	c.iniciar_recarga(k.NUMERO, 0.0)
	frente = c.olhar()
	frente.y = 0.0
	frente = frente.normalized()
	var base: Vector3 = jogador.global_position
	var parede := StaticBody3D.new()
	parede.collision_layer = 1
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(8.0, 5.0, 0.5)
	col.shape = caixa
	parede.add_child(col)
	current_scene.add_child(parede)
	parede.global_position = base + frente * 2.0 + Vector3.UP
	parede.look_at(parede.global_position + frente)
	var atras := criar_alvo(base + frente * 3.0 + Vector3.UP * 0.9)
	await quadros(5)
	c.usar_tecla("Z", true)
	await quadros(90)
	ok(atras.hits == 0, "investida não causa dano através de parede")
	var avanco: float = (jogador.global_position - base).dot(frente)
	ok(avanco < 2.3, "colisão impede atravessar a parede (avanço %.2f m)" % avanco)
	parede.queue_free()
	await quadros(3)
	c.iniciar_recarga(k.NUMERO, 0.0)
	jogador.energy = 0.0
	c.usar_tecla("Z", true)
	ok(not k.ativo and not is_instance_valid(jogador.get_node_or_null("FormaZoan")), "sem energia não inicia nem transforma")
	jogador.energy = 2000.0
	c.usar_tecla("Z", true)
	ok(k.ativo and is_instance_valid(jogador.get_node_or_null("FormaZoan")), "investida reinicia após liberar energia")
	# Usa o receptor real do East Blue sem executar a IA: a explosão precisa chegar
	# ao take_damage e ao impulso do inimigo, não apenas a um alvo sintético.
	var npc = load("res://src/historia/east_blue/personagem_mine_piece.gd").new()
	npc.ficha = {"id": "kira_teste", "nome": "Alvo de teste", "vida": 100.0, "altura": 1.8, "largura": 0.6, "faccao": "pirata"}
	npc.max_health = 100.0
	npc.health = 100.0
	npc.add_to_group(AlvosDeGolpe.GRUPO)
	current_scene.add_child(npc)
	npc.global_position = jogador.global_position + lado * 2.0
	npc.set_physics_process(false)
	k._explodir(jogador.global_position + Vector3.UP * 0.9)
	ok(npc.health < npc.max_health and npc._empurrao.dot(lado) > 1.0, "explosão causa dano e empurra personagem real do Modo História")
	# Impacto direto: o inimigo atingido pela investida é arremessado para longe (impulso do mundo real).
	npc._empurrao = Vector3.ZERO
	npc.health = npc.max_health
	k.direcao = lado
	k._explodir(jogador.global_position + Vector3.UP * 0.9 + lado * 1.2, npc)
	ok(npc._empurrao.dot(lado) > 20.0, "alvo principal do impacto recebe impulso de arremesso (%.1f m/s)" % npc._empurrao.dot(lado))
	npc.remove_from_group(AlvosDeGolpe.GRUPO)
	npc.queue_free()
	# Mira assistida: alvo fora da linha da câmera, mas dentro do cone, entra na direção da investida.
	for velho in [longe, a, proximo]:
		if is_instance_valid(velho):
			velho.remove_from_group(AlvosDeGolpe.GRUPO)
			velho.queue_free()
	await quadros(2)
	var fora := criar_alvo(jogador.global_position + frente * 12.0 + lado * 5.0)
	var base_dir: Vector3 = frente
	var guiada: Vector3 = k._direcao_assistida(base_dir)
	var para_fora: Vector3 = (fora.global_position - jogador.global_position)
	para_fora.y = 0.0
	ok(guiada.dot(para_fora.normalized()) > 0.97 and guiada.dot(base_dir) < 0.97, "mira assistida vira a investida para o inimigo dentro do cone")
	var costas := criar_alvo(jogador.global_position - frente * 8.0)
	for resto in get_nodes_in_group(AlvosDeGolpe.GRUPO):
		if resto != costas:
			resto.remove_from_group(AlvosDeGolpe.GRUPO)
	ok(k._direcao_assistida(base_dir).dot(base_dir) > 0.999, "sem inimigo no cone a direção da câmera é mantida (atrás não conta)")
	costas.remove_from_group(AlvosDeGolpe.GRUPO)
	costas.queue_free()
	modo.equipar_fruta(jogador, "")
	await quadros(5)
	ok(not is_instance_valid(jogador.get_node_or_null("FormaZoan")) and not jogador.has_meta("pose_externa"), "retirar a fruta durante a investida limpa forma e pose")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
