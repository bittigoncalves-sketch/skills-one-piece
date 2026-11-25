extends SceneTree
## Kira Kira X/C: pedras cúbicas, hitbox do cubo, dano, recarga e limpeza.
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
		var hb := Node3D.new()
		hb.name = "Hurtbox"
		add_child(hb)
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		col.shape = cap
		hb.add_child(col)
	func take_damage(valor: float, _origem: Vector3, recebido: Vector3, _stun: float) -> void:
		hits += 1
		dano += valor
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
			jogador.energy = maxf(jogador.energy, 100.0)
		await physics_frame
		await process_frame

func alvo_em(pos: Vector3) -> Alvo:
	var a := Alvo.new()
	current_scene.add_child(a)
	a.global_position = pos
	return a

func rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://kira_pedras_teste.json")
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
	var p = c.kira_pedras
	var Pedra = load("res://src/combat/kira/kira_pedra.gd")
	jogador.max_energy = 2000.0
	jogador.energy = 2000.0
	jogador.set_meta("damage_immune", true)
	DanoDaHistoria.ligar_para(true)

	# --- hitbox do cubo (função pura) -------------------------------------------------
	var teste := alvo_em(Vector3(0, 0, 0))
	teste.global_position = Vector3(100, 1, 100)
	var meia := 0.4
	ok(Pedra.cubo_toca_alvo(teste, teste.global_position + Vector3(0.7, 0, 0), 0.0, meia),
		"cubo encostado na lateral da cápsula acerta (aresta 0,8 + raio 0,4)")
	ok(not Pedra.cubo_toca_alvo(teste, teste.global_position + Vector3(0.9, 0, 0), 0.0, meia),
		"cubo 0,1 m além da lateral não acerta")
	ok(Pedra.cubo_toca_alvo(teste, teste.global_position + Vector3(0, 1.2, 0), 0.0, meia),
		"cubo sobre a cabeça da cápsula acerta")
	ok(not Pedra.cubo_toca_alvo(teste, teste.global_position + Vector3(0, 1.6, 0), 0.0, meia),
		"cubo bem acima da cabeça não acerta")
	# na diagonal a esfera inscrita (0,4+0,4 = 0,8) falharia a 0,85 m; a quina do cubo (0,57 m) ainda alcança
	ok(Pedra.cubo_toca_alvo(teste, teste.global_position + Vector3(0.6, 0, 0.6), 0.0, meia),
		"cubo acerta pela quina na diagonal onde uma esfera de mesmo raio erraria")
	teste.queue_free()

	# --- X ------------------------------------------------------------------------------
	var frente: Vector3 = c.olhar()
	frente.y = 0.0
	frente = frente.normalized()
	var inicio: Vector3 = jogador.global_position
	var alvo := alvo_em(inicio + frente * 14.0)
	var lado := alvo_em(inicio + frente * 14.0 + frente.cross(Vector3.UP).normalized() * 6.0)
	ok(c.mapa_de_teclas().get("X", 0) == p.NUMERO_X and c.mapa_de_teclas().get("C", 0) == p.NUMERO_C, "X e C mapeados para as pedras de diamante")
	var energia: float = jogador.energy
	c.usar_tecla("X", true)
	c.usar_tecla("X", false)
	ok(p.ativo and absf(energia - jogador.energy - p.CUSTO_X) < 0.01, "X cobra energia uma vez e inicia")
	ok(jogador.has_meta("pose_externa"), "X põe o braço em pose de arremesso")
	await quadros(6)
	ok(get_nodes_in_group("kira_pedra").size() >= 1, "X cria pedras cúbicas")
	var pedra = get_nodes_in_group("kira_pedra")[0]
	var malha: MeshInstance3D = pedra.get_child(0)
	ok(malha.mesh is BoxMesh and (malha.mesh as BoxMesh).size.is_equal_approx(Vector3.ONE * p.TAMANHO_X), "a pedra é um cubo de 0,8 m")
	for i in 120:
		await quadros(1)
	ok(alvo.hits >= 1, "pedras do X acertam o alvo na mira (%d acertos)" % alvo.hits)
	ok(alvo.hits <= p.PEDRAS_DO_X, "cada pedra acerta no máximo uma vez (%d acertos)" % alvo.hits)
	ok(alvo.impulso.dot(frente) > 5.0, "pedra empurra o alvo para frente")
	ok(lado.hits == 0, "inimigo 6 m fora da mira não é atingido")
	ok(get_nodes_in_group("kira_pedra").is_empty(), "pedras somem depois de quebrar")
	ok(not p.ativo and not jogador.has_meta("pose_externa"), "fim do X solta a pose")
	ok(c.recarga_da_tecnica(p.NUMERO_X) > 0.0, "X tem recarga própria")
	var energia2: float = jogador.energy
	c.usar_tecla("X", true)
	ok(not p.ativo and absf(energia2 - jogador.energy) < 0.5, "recarga impede novo X sem cobrar")
	# parede entre jogador e alvo bloqueia
	alvo.queue_free()
	lado.queue_free()

	# --- C ------------------------------------------------------------------------------
	c._recargas.clear()
	await quadros(2)
	var gigante_alvo := alvo_em(inicio + frente * 20.0)
	var vizinho := alvo_em(inicio + frente * 20.0 + frente.cross(Vector3.UP).normalized() * 3.5)
	var distante := alvo_em(inicio + frente * 20.0 + frente.cross(Vector3.UP).normalized() * 12.0)
	jogador.energy = 2000.0
	c.usar_tecla("C", true)
	c.usar_tecla("C", false)
	await quadros(4)
	ok(p.ativo and not get_nodes_in_group("kira_pedra").is_empty(), "C cria a pedra gigante")
	var g = get_nodes_in_group("kira_pedra")[0]
	ok(is_equal_approx(((g.get_child(0) as MeshInstance3D).mesh as BoxMesh).size.x, p.TAMANHO_C), "a pedra do C é um cubo de 3,2 m")
	for i in 200:
		await quadros(1)
	ok(gigante_alvo.hits == 1, "pedra gigante acerta o alvo uma vez")
	ok(vizinho.hits == 1 and distante.hits == 0, "explosão da pedra gigante pega quem está perto e poupa quem está longe")
	ok(gigante_alvo.dano > vizinho.dano and vizinho.dano > 0.0, "alvo direto leva mais que o vizinho")
	ok(get_nodes_in_group("kira_pedra").is_empty(), "pedra gigante some depois de quebrar")

	# --- parede ---------------------------------------------------------------------------
	var parede := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(10, 6, 0.5)
	cs.shape = caixa
	parede.add_child(cs)
	parede.collision_layer = 1
	current_scene.add_child(parede)
	parede.global_position = inicio + frente * 7.0 + Vector3.UP * 1.0
	var atras := alvo_em(inicio + frente * 12.0)
	c._recargas.clear()
	jogador.energy = 2000.0
	c.usar_tecla("X", true)
	for i in 120:
		await quadros(1)
	ok(atras.hits == 0, "parede bloqueia as pedras do X")
	print("RESULTADO: %d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)
