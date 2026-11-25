extends SceneTree
# ============================================================================
#  MOVIMENTAÇÃO DO MINECRAFT NO JOGADOR REAL (31/10/2026): teclas de verdade na baseplate.
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_movimento_minecraft_jogador.gd
#
#  Números do Minecraft 1.20.1 × 0,88 m por bloco: andar 4,317 b/s = 3,80 m/s; correr 5,612 b/s =
#  4,94 m/s; pulo 1,2522 b = 1,10 m. Mede também que o geppo (parkour) continua passando por cima.
# ============================================================================
var p: Node3D
var falhas := 0
var checks := 0
const B := 0.88


func _init() -> void:
	call_deferred("_rodar")


func _rodar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_mov_mc.json")
	root.get_node("GameFlow").start_story()
	await quadros(120)
	p = get_first_node_in_group("player")
	if p == null:
		push_error("Sem jogador"); quit(1); return
	p.capacidades = CapacidadesDoJogador.completas()
	print("\n-- andar / correr --")
	await posicionar(Vector3(0, 0.81, 0))
	tecla(KEY_W, true)
	await quadros(90)
	var v := Vector2(p.velocity.x, p.velocity.z).length()
	verificar(absf(v - 4.317 * B) < 0.15, "andar: %.3f m/s (Minecraft %.3f)" % [v, 4.317 * B])
	tecla(KEY_SHIFT, true)
	await quadros(90)
	v = Vector2(p.velocity.x, p.velocity.z).length()
	verificar(absf(v - 5.612 * B) < 0.2, "correr: %.3f m/s (Minecraft %.3f)" % [v, 5.612 * B])
	tecla(KEY_SHIFT, false)
	tecla(KEY_W, false)

	print("\n-- pulo --")
	await posicionar(Vector3(0, 0.81, 0))
	var y0: float = p.global_position.y
	var pico := y0
	tecla(KEY_SPACE, true)
	for i in 40:
		await physics_frame
		pico = maxf(pico, p.global_position.y)
		if i == 2:
			tecla(KEY_SPACE, false)
	var altura := pico - y0
	verificar(absf(altura - 1.2522 * B) < 0.12, "altura do pulo: %.3f m (Minecraft %.3f)" % [altura, 1.2522 * B])

	print("\n-- geppo continua por cima --")
	await posicionar(Vector3(0, 0.81, 0))
	tecla(KEY_SPACE, true)
	await quadros(2)
	tecla(KEY_SPACE, false)
	await quadros(14)
	var antes: float = p.global_position.y
	tecla(KEY_SPACE, true)
	await quadros(2)
	tecla(KEY_SPACE, false)
	var pico2 := antes
	for i in 40:
		await physics_frame
		pico2 = maxf(pico2, p.global_position.y)
	verificar(pico2 - antes > 1.0, "pulo no ar (geppo) ainda impulsiona: +%.2f m" % (pico2 - antes))

	print("\nMOV_MC_JOGADOR: %d checks, %d falhas" % [checks, falhas])
	quit(1 if falhas > 0 else 0)


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
