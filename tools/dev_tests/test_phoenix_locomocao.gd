extends SceneTree
## Contrato de locomoção no Modo História: Player, colisão e fênix reais.
## SOP_PORTA=24710 godot --headless --path . --script tools/dev_tests/test_phoenix_locomocao.gd
var p: Node3D
var passou := 0
var falhas := 0

func _init() -> void:
	_rodar.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1

func tecla(codigo: Key, pressionada: bool) -> void:
	var evento := InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = pressionada
	Input.parse_input_event(evento)

func cast(slot: String) -> void:
	p._fruit_cooldowns.clear()
	p._server_cast_next_ms.clear()
	p.energy = p.max_energy
	p.begin_charge(slot)
	p.release_charge(slot)
	await frames(3)

func _rodar() -> void:
	await process_frame
	var modo: Script = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_phoenix_locomocao.json")
	root.get_node("GameFlow").start_story()
	await frames(150)
	p = get_first_node_in_group("player")
	ok("jogador do modo história nasceu", p != null)
	if p == null:
		quit(1)
		return
	current_scene.progressao.comer_fruta("tori_tori_phoenix")
	p.combat_mode = "fruit"
	await frames(10)
	var controle: Node3D = p._phoenix
	ok("humano não entra no repouso da fênix", not controle.alternar_repouso())
	await cast("Z")
	ok("Z criou a forma", controle.transformado and is_instance_valid(controle.forma))
	if not is_instance_valid(controle.forma):
		quit(1)
		return
	var forma: Node3D = controle.forma
	await frames(70)
	ok("apoio das garras alinhado aos pés do jogador", is_equal_approx(forma.position.y, -0.8))
	ok("forma parada sobre chão real", p.is_on_floor() and forma.estado_animacao == "parado")
	tecla(KEY_M, true)
	tecla(KEY_M, false)
	await frames(3)
	tecla(KEY_H, true)
	tecla(KEY_H, false)
	await frames(3)
	ok("H não atravessa menu de status", p._menu_de_tela_aberto() and not controle.sentado)
	tecla(KEY_M, true)
	tecla(KEY_M, false)
	await frames(3)
	tecla(KEY_H, true)
	tecla(KEY_H, false)
	await frames(70)
	ok("H senta pela entrada real", controle.sentado and forma.estado_animacao == "sentado")
	var repeticao := InputEventKey.new()
	repeticao.keycode = KEY_H
	repeticao.physical_keycode = KEY_H
	repeticao.pressed = true
	repeticao.echo = true
	controle._unhandled_key_input(repeticao)
	ok("repetição de H não alterna a postura", controle.sentado)
	var antes: Vector3 = p.global_position
	await frames(30)
	ok("repouso não desloca o colisor", antes.distance_to(p.global_position) < 0.02)
	tecla(KEY_H, true)
	tecla(KEY_H, false)
	await frames(70)
	ok("H levanta novamente", not controle.sentado and forma.estado_animacao == "parado")
	controle.alternar_repouso()
	await frames(65)
	tecla(KEY_W, true)
	await frames(50)
	ok("andar cancela repouso e anima marcha", not controle.sentado and forma.estado_animacao == "andando")
	ok("marcha acompanha deslocamento real", p.global_position.distance_to(antes) > 1.0)
	ok("não senta durante deslocamento", not controle.alternar_repouso())
	tecla(KEY_W, false)
	await frames(60)
	controle.alternar_repouso()
	await frames(65)
	await cast("F")
	ok("decolagem cancela repouso", controle.voo > 0 and not controle.sentado)
	var altura_inicial: float = p.global_position.y
	await frames(60)
	ok("voo decola sem teleporte", not p.is_on_floor() and p.global_position.y > altura_inicial + 0.3)
	ok("forma acompanha voo", forma.estado_animacao == "voando")
	ok("não senta no ar", not controle.alternar_repouso())
	var antes_desligar: Vector3 = p.global_position
	await cast("F")
	ok("desligar voo preserva posição física", controle.voo == 0 and p.global_position.distance_to(antes_desligar) < 0.4)
	ok("queda mantém forma no ar até contato", not p.is_on_floor() and forma.estado_animacao == "pousando")
	await frames(140)
	ok("pouso termina sobre colisão real", p.is_on_floor() and forma.estado_animacao == "parado")
	ok("pouso preserva altura de apoio e transformação finita", is_equal_approx(forma.position.y, -0.8) and forma.transform.is_finite())
	controle.alternar_repouso()
	await frames(60)
	p.take_damage(1.0)
	await frames(5)
	ok("dano interrompe repouso", not controle.sentado)
	p.clear_spawned_skills()
	# Deixa feedback e timers do dano terminarem antes de encerrar a árvore.
	await frames(70)
	ok("limpeza remove postura e asset", not controle.sentado and not controle.transformado and controle.get_child_count() == 0)
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("PHOENIX LOCOMOCAO: %d passou / %d falhou" % [passou, falhas])
	quit(1 if falhas else 0)
