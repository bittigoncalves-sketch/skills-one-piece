extends SceneTree
## Luta (Z/X/C do Estilo de Combate Base), 30/10/2026: Z e X empurram bem mais; no C só o ÚLTIMO golpe empurra e
## os da rajada PARALISAM o alvo (que é solto antes do golpe final para poder ser lançado).
## Não cita classes do jogo por nome no corpo do script (o `--script` compilaria o Player cedo e ele não nasceria).
##   godot --headless --path . --script res://tools/dev_tests/test_luta_empurrao_paralisia.gd
var p: Node3D
var alvo: Node3D
var passou := 0
var falhas := 0
var Imob: GDScript
var Bal: GDScript
var controlador: Node

class Alvo extends StaticBody3D:
	var health := 50000.0
	var hits := 0
	var kbs: Array[float] = []          # empurrão de CADA golpe, na ordem
	var preso: Array[bool] = []         # estava paralisado (is_frozen) quando o golpe chegou?
	func take_damage(d: float, _origem := Vector3.ZERO, kb := Vector3.ZERO, _stun := 0.0) -> void:
		kbs.append(kb.length())
		preso.append(bool(get_meta("is_frozen", false)))
		health -= d
		hits += 1

func _init() -> void: _rodar.call_deferred()

func frames(n: int) -> void:
	for i in n: await physics_frame

func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1

func _limpar() -> void:
	for e in current_scene.find_children("SkillBuilder_*", "", true, false): e.queue_free()
	await frames(3)
	Imob.liberar(alvo)
	controlador.recargas.clear()
	controlador.imunidade.clear()
	p.global_position = Vector3(0, 1, 0)
	p.velocity = Vector3.ZERO
	p.energy = p.max_energy
	p.health = p.max_health
	p._fruit_cooldowns.clear()
	p._skill_cooldowns.clear()
	p._server_cast_next_ms.clear()
	p._intervalo_golpe = 0.0
	p._trava_pos_fruta = 0.0
	p._fruit_damage_lock_timer = 0.0
	p._yaw = 0.0
	p._pitch = 0.0
	p._update_pivot()
	alvo.health = 50000.0
	alvo.hits = 0
	alvo.kbs.clear()
	alvo.preso.clear()
	alvo.position = Vector3(0, 1, -1.6)
	await frames(5)

func _cast(tecla: String) -> void:
	# A Luta nativa usa as teclas diretas encaminhadas pela HUD, não a API de
	# carga das antigas skills do Builder. Simula o mesmo input usado pelo jogo.
	var evento := InputEventKey.new()
	evento.keycode = KEY_Z if tecla == "Z" else (KEY_X if tecla == "X" else KEY_C)
	evento.physical_keycode = evento.keycode
	evento.pressed = true
	Input.parse_input_event(evento)
	await physics_frame
	evento = InputEventKey.new()
	evento.keycode = KEY_Z if tecla == "Z" else (KEY_X if tecla == "X" else KEY_C)
	evento.physical_keycode = evento.keycode
	evento.pressed = false
	Input.parse_input_event(evento)

func _rodar() -> void:
	await process_frame
	Imob = load("res://src/combat/frutas_mine_piece/imobilizacao_mine_piece.gd")
	Bal = load("res://src/combat/Balance.gd")
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_luta_empurrao.json"))
	modo.set("progresso_forcado", "user://test_luta_empurrao.json")
	root.get_node("GameFlow").start_story()
	await frames(120)
	p = get_first_node_in_group("player")
	for i in 480:
		if p != null: break
		await physics_frame
		p = get_first_node_in_group("player")
	if p == null:
		ok("jogador nasceu", false)
		quit(1)
		return
	var a := Alvo.new()
	a.collision_layer = 1
	var col := CollisionShape3D.new()
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(1.2, 2.0, 1.2)
	col.shape = caixa
	a.add_child(col)
	current_scene.add_child(a)
	a.add_to_group("enemy")
	alvo = a
	var prog = current_scene.progressao
	controlador = load("res://src/combat/frutas_mine_piece/controlador.gd").de(p)
	if controlador == null:
		ok("controlador nativo da Luta existe", false)
		quit(1)
		return
	ok("Luta equipada", prog.item_em_uso() == "luta")
	var tabela: Dictionary = Bal.MINE_PIECE_LUTA
	ok("números: rajada não empurra e paralisa; final empurra", tabela.rajada.empurrao == 0.0 and tabela.rajada.paralisia > 0.0
		and tabela.final.empurrao > tabela.pesado.empurrao * 0.7)

	var kb := {}
	for tecla in ["Z", "X"]:
		await _limpar()
		await _cast(tecla)
		await frames(70)
		kb[tecla] = alvo.kbs[0] if not alvo.kbs.is_empty() else 0.0
		ok("%s: um contato com empurrão (%.2f)" % [tecla, kb[tecla]], alvo.hits == 1 and kb[tecla] > 0.0)
	ok("X empurra 3× o Z (27 contra 9): %.2f / %.2f" % [kb["X"], kb["Z"]], absf(kb["X"] / maxf(kb["Z"], 0.0001) - 3.0) < 0.3)
	ok("Z empurra (9, eram 3 antes)", kb["Z"] > 0.0)

	await _limpar()
	await _cast("C")
	await frames(130)
	var n: int = alvo.kbs.size()
	ok("C acerta vários golpes (%d)" % n, n >= 7)
	var so_o_ultimo: bool = n >= 2 and alvo.kbs[n - 1] > 20.0
	for i in n - 1:
		so_o_ultimo = so_o_ultimo and alvo.kbs[i] < 0.001
	ok("C: só o último golpe empurra (último %.1f)" % (alvo.kbs[n - 1] if n > 0 else 0.0), so_o_ultimo)
	var presos := 0
	for i in range(1, n - 1):
		presos += 1 if alvo.preso[i] else 0
	ok("C: os golpes da rajada acham o alvo paralisado (%d de %d)" % [presos, maxi(n - 2, 0)], n >= 4 and presos >= n - 2)
	ok("C: o golpe final chega com o alvo SOLTO", n >= 2 and not alvo.preso[n - 1])
	await frames(40)
	ok("C: a paralisia acaba depois do golpe final", not Imob.ativa(alvo) and not alvo.get_meta("is_frozen", false))

	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("LUTA_EMPURRAO %d passaram / %d falhas" % [passou, falhas])
	quit(1 if falhas else 0)
