extends SceneTree
# ============================================================================
#  SEGURANDO SKILL DO BUILDER NÃO ANDA (07/10/2026).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_segurar_sem_andar.gd
#
#  Pedido do dono: "quando o jogador está segurando uma skill ele não consegue se mover
#  a não ser que a skill diga o contrário". Modo História (mapa e progresso de TESTE),
#  Pika publicada no projeto, teclas de verdade:
#    • segurando o Z (Carregar e soltar): W não anda, Espaço não pula, Q não esquiva;
#    • soltou: volta a andar;
#    • a mesma skill com "Pode andar enquanto segura" (pasta de teste): anda segurando.
# ============================================================================

const PASTA := "user://test_segurar_sem_andar_skills"

var _ok_n := 0
var _falhas := 0
var p: Node3D


func _init() -> void:
	_executar.call_deferred()


func _executar() -> void:
	await process_frame
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_segurar_sem_andar.json")
	root.get_node("GameFlow").start_story()
	await _fisica(150)
	p = get_first_node_in_group("player")
	(current_scene.get("progressao") as ProgressaoDoPersonagem).comer_fruta("pika_pika")
	await _fisica(20)

	# 1. Segurando o Z: nada se mexe pela entrada.
	await _no_lugar()
	var de := p.global_position
	_segurar("Z")
	await _fisica(10)
	_tecla(KEY_W, true)
	await _fisica(30)
	_tecla(KEY_W, false)
	var andou := _plano(p.global_position - de)
	_tecla(KEY_SPACE, true)
	await _fisica(6)
	_tecla(KEY_SPACE, false)
	await _fisica(10)
	var subiu := p.global_position.y - de.y
	_tecla(KEY_Q, true)
	await _fisica(3)
	_tecla(KEY_Q, false)
	await _fisica(20)
	var esquivou := _plano(p.global_position - de)
	_ok("segurando o Z: W não anda (%.2f m), Espaço não pula (%.2f m), Q não esquiva (%.2f m)" % [andou, subiu, esquivou],
		andou < 0.2 and subiu < 0.2 and esquivou < 0.2)
	p.release_charge("Z")
	await _fisica(40)
	de = p.global_position
	_tecla(KEY_W, true)
	await _fisica(30)
	_tecla(KEY_W, false)
	_ok("soltou: volta a andar (%.2f m)" % _plano(p.global_position - de), _plano(p.global_position - de) > 1.0)

	# 2. A mesma skill com "Pode andar enquanto segura".
	SkillsPublicadas.pasta_forcada = PASTA
	SkillsPublicadas.recarregar()
	SkillsPublicadas.reconstruir_fruta_da_arena("pika_pika", "Pika Pika no Mi", "#ffd23f")
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://mapas/skills/pika_raio_z.json"))
	s.ativacao["andar_segurando"] = true
	var r := SkillsPublicadas.publicar(s)
	_ok("skill com \"Pode andar enquanto segura\" é válida (%s)" % str(r.get("erros", [])), bool(r.ok))
	await _no_lugar()
	de = p.global_position
	_segurar("Z")
	await _fisica(10)
	_tecla(KEY_W, true)
	await _fisica(30)
	_tecla(KEY_W, false)
	_ok("com a opção ligada, anda segurando (%.2f m)" % _plano(p.global_position - de), _plano(p.global_position - de) > 1.0)
	p.release_charge("Z")
	SkillsPublicadas.pasta_forcada = ""
	SkillsPublicadas.recarregar()
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nSEGURAR_SEM_ANDAR %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)


func _segurar(slot: String) -> void:
	p.set("energy", float(p.get("max_energy")))
	(p.get("_fruit_cooldowns") as Dictionary)[slot] = 0.0
	p.set("_intervalo_golpe", 0.0)
	p.begin_charge(slot)


func _no_lugar() -> void:
	for k in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_Q]:
		_tecla(k, false)
	p.global_position = Vector3(0, 0.8, 0)
	p.velocity = Vector3.ZERO
	await _fisica(90)                # recargas do Q e do Z (zeradas à mão) e o pouso


func _plano(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func _tecla(codigo: Key, pressionada: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = codigo
	ev.keycode = codigo
	ev.pressed = pressionada
	Input.parse_input_event(ev)


func _fisica(n: int) -> void:
	for i in n:
		await physics_frame


func _ok(rotulo: String, cond: bool) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])
