extends SceneTree
## Integração via teclas reais; controles negativos provam borda/teto.
var p: Node3D
var falhas := 0
var checks := 0


func _init() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_agachar.json")
	# Este teste começa com personagem já escolhido; seleção tem teste próprio.
	var personagem = ProgressaoDoPersonagem.carregar("user://test_agachar.json")
	personagem.corpo = "masculino"
	personagem.salvar("user://test_agachar.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	p = get_first_node_in_group("player")
	if p == null:
		push_error("Sem jogador"); quit(1); return
	p.capacidades = CapacidadesDoJogador.completas()
	await posicionar(Vector3(0, 0.81, 0))
	var altura: float = p._colisor.shape.height
	var base: float = p._colisor.position.y - altura * 0.5
	var camera_y: float = p._camera.position.y
	tecla(KEY_CTRL, true)
	await quadros(25)
	verificar(p._agachar.ativo and not p._deslize.ativo(), "Ctrl parado agacha sem deslizar")
	verificar(is_equal_approx(p._colisor.shape.height, altura * 1.5 / 1.8), "altura 1,5/1,8")
	verificar(is_equal_approx(p._colisor.position.y - p._colisor.shape.height * 0.5, base), "pés mantêm a base")
	verificar(p._camera.position.y < camera_y - 0.25, "câmera baixa")
	verificar(p._proc_anim._pose_agachar.peso > 0.99, "pose agachada integrada")
	var sola := INF
	for malha: MeshInstance3D in p._proc_anim._pose_agachar._solas:
		for i in 8:
			sola = minf(sola, (malha.global_transform * malha.get_aabb().get_endpoint(i)).y)
	var apoio: float = p.global_position.y + p._colisor.position.y - p._colisor.shape.height * 0.5
	verificar(absf(sola - apoio) < 0.01, "sola visual apoiada (erro %.4f m)" % absf(sola - apoio))
	verificar(p.net_agachado, "estado publicado para rede")
	var hb: CollisionShape3D = p.get_node("Hurtbox/Forma")
	verificar(is_equal_approx(hb.shape.size.y, p._colisor.shape.height), "hurtbox acompanha altura")
	var main = load("res://Main.gd").new()
	var sync: MultiplayerSynchronizer = main._make_player_sync()
	verificar(sync.replication_config.has_property(NodePath(".:net_agachado")), "estado registrado no sincronizador")
	sync.free()
	main.free()
	var copia = load("res://Player.gd").new()
	copia.name = "AgacharRemoto"
	copia.colisor_capsula = true
	copia.set_multiplayer_authority(999)
	root.add_child(copia)
	copia.position = Vector3(100, 5, 100)
	copia.net_agachado = true
	copia.net_on_floor = true
	await quadros(30)
	verificar(copia._agachar.ativo and copia._proc_anim._pose_agachar.peso > 0.99,
		"cópia remota aplica colisão e pose")
	verificar(is_equal_approx(copia._colisor.shape.height, p._colisor.shape.height), "mesma altura local/remota")
	copia.net_agachado = false
	await quadros(30)
	verificar(not copia._agachar.ativo and is_equal_approx(copia._colisor.shape.height, altura),
		"cópia remota levanta")
	copia.queue_free()
	var caixa = load("res://Player.gd").new()
	caixa.name = "AgacharCaixa"
	caixa.set_multiplayer_authority(998)
	root.add_child(caixa)
	caixa.position = Vector3(110, 5, 100)
	caixa.net_agachado = true
	caixa.net_on_floor = true
	await quadros(20)
	verificar(caixa._colisor.shape is BoxShape3D and is_equal_approx(caixa._colisor.shape.size.y, altura * 1.5 / 1.8),
		"arena também reduz colisor de caixa")
	caixa.queue_free()
	tecla(KEY_W, true)
	tecla(KEY_SHIFT, true)
	await quadros(35)
	var velocidade: float = Vector2(p.velocity.x, p.velocity.z).length()
	# Minecraft: agachado anda 1,295 blocos/s (entrada ×0,3) — era 30%% de SPEED na locomoção antiga.
	var agachado_mc := 1.295 * MundoMinePiece.METROS_POR_BLOCO
	verificar(absf(velocidade - agachado_mc) < 0.08, "Ctrl+Shift anda na velocidade agachada do Minecraft (%.3f m/s, esperado %.3f)" % [velocidade, agachado_mc])
	tecla(KEY_D, true)
	await quadros(25)
	velocidade = Vector2(p.velocity.x, p.velocity.z).length()
	# Quirk fiel ao 1.20.1: agachado, a entrada diagonal (0,29; 0,29) tem módulo < 1 e NÃO é
	# normalizada — a diagonal sai √2 mais rápida que a reta (corrigido só no 1.21.2 do original).
	verificar(absf(velocidade - agachado_mc * sqrt(2.0)) < 0.08, "diagonal agachada = reta × √2, como no 1.20.1 (%.3f m/s)" % velocidade)
	tecla(KEY_CTRL, false)
	await quadros(25)
	verificar(not p._agachar.ativo and is_equal_approx(p._colisor.shape.height, altura), "soltar restaura altura")
	await posicionar(Vector3(0, 0.81, 0))
	var teto := bloco(Vector3(0, 1.55, -2), Vector3(4, 0.3, 3))
	tecla(KEY_W, true)
	await quadros(70)
	verificar(p.global_position.z > -0.9, "controle: teto bloqueia personagem em pé: %s" % p.global_position)
	tecla(KEY_CTRL, true)
	await quadros(65)
	verificar(p.global_position.z < -1.0, "agachado entra no vão")
	tecla(KEY_W, false)
	await quadros(12)
	tecla(KEY_CTRL, false)
	await quadros(20)
	verificar(p._agachar.ativo, "soltar sob teto mantém postura")
	tecla(KEY_Q, true)
	await quadros(3)
	tecla(KEY_Q, false)
	verificar(not p.esquivando(), "Q não levanta através do teto")
	tecla(KEY_W, true)
	await quadros(180)
	verificar(not p._agachar.ativo, "sair do teto levanta automaticamente")
	teto.queue_free()
	await posicionar(Vector3(0, 0.81, 0))
	tecla(KEY_CTRL, true)
	await quadros(10)
	tecla(KEY_SPACE, true)
	await quadros(3)
	tecla(KEY_SPACE, false)
	verificar(p.velocity.y > 0.0, "permite pulo agachado")
	await quadros(80)

	var plataforma := bloco(Vector3(0, 10, 0), Vector3(4, 1, 4))
	for direcao in [Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		await posicionar(Vector3(0, 11.31, 0))
		tecla(KEY_CTRL, true)
		tecla(KEY_D, direcao.x > 0)
		tecla(KEY_S, direcao.y > 0)
		await quadros(210)
		verificar(p.global_position.y > 11.1 and p.is_on_floor(),
			"borda %s segura: %s" % [direcao, p.global_position])
	tecla(KEY_CTRL, false)
	await quadros(70)
	verificar(p.global_position.y < 9.5, "controle: sem Ctrl cai da borda")

	await posicionar(Vector3(0, 11.31, 0))
	tecla(KEY_CTRL, true)
	tecla(KEY_D, true)
	await quadros(140)
	tecla(KEY_SPACE, true)
	await quadros(3)
	tecla(KEY_SPACE, false)
	await quadros(100)
	verificar(p.global_position.x > 2.6, "pulo libera a saída da borda")
	await posicionar(Vector3(1.7, 11.31, 0))
	tecla(KEY_CTRL, true)
	await quadros(12)
	p._vida._empurrao = Vector3(18, 0, 0)
	await quadros(40)
	verificar(p.global_position.x > 2.6, "empurrão externo vence proteção da borda")
	var degrau := bloco(Vector3(4, 9.7, 0), Vector3(4, 1, 4))
	await posicionar(Vector3(0, 11.31, 0))
	tecla(KEY_CTRL, true)
	tecla(KEY_D, true)
	await quadros(230)
	verificar(p.global_position.x > 3.0 and p.is_on_floor(),
		"permite descer degrau menor que meio bloco: %s" % p.global_position)
	degrau.queue_free()

	await posicionar(Vector3(0, 0.81, 0))
	tecla(KEY_CTRL, true)
	await quadros(10)
	tecla(KEY_Q, true)
	await quadros(3)
	tecla(KEY_Q, false)
	verificar(p.esquivando() and not p._agachar.ativo, "Q em espaço livre cancela postura")
	tecla(KEY_CTRL, false)
	await quadros(65)
	tecla(KEY_CTRL, true)
	await quadros(12)
	tecla(KEY_CTRL, false)
	p.net_force_respawn()
	verificar(not p._agachar.ativo and not p.net_agachado, "respawn limpa postura")
	await posicionar(Vector3(0, 0.81, 0))
	var raca_original := Visual.raca
	Visual.raca = "gigante"
	p._aplicar_escala_de_raca()
	var altura_gigante: float = p._colisor.shape.height
	tecla(KEY_CTRL, true)
	await quadros(20)
	verificar(is_equal_approx(p._colisor.shape.height, altura_gigante * 1.5 / 1.8), "gigante preserva proporção")
	tecla(KEY_CTRL, false)
	await quadros(20)
	verificar(is_equal_approx(p._colisor.shape.height, altura_gigante), "gigante recupera altura exata")
	Visual.raca = raca_original
	p._aplicar_escala_de_raca()
	tecla(KEY_CTRL, true)
	var quadro := MoveFrame.new()
	quadro.ler(0, false)
	verificar(not quadro.agachar_segurado, "menu bloqueia entrada de Ctrl")
	tecla(KEY_CTRL, false)
	plataforma.queue_free()
	await posicionar(Vector3(0, 0.81, 0))
	print("AGACHAR: %d checks, %d falhas" % [checks, falhas])
	quit(1 if falhas else 0)


func posicionar(pos: Vector3) -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SHIFT, KEY_CTRL, KEY_SPACE, KEY_Q]:
		tecla(k, false)
	p._agachar.cancelar()
	p._parkour.cancelar()
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p._yaw = 0.0
	await quadros(12)


func bloco(pos: Vector3, tamanho: Vector3) -> StaticBody3D:
	var corpo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var forma := BoxShape3D.new()
	forma.size = tamanho
	col.shape = forma
	corpo.add_child(col)
	root.add_child(corpo)
	corpo.position = pos
	return corpo


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func tecla(codigo: Key, pressionada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = pressionada
	Input.parse_input_event(evento)


func verificar(condicao: bool, mensagem: String) -> void:
	checks += 1
	if not condicao:
		falhas += 1
	print(("✓ " if condicao else "❌ ") + mensagem)
