extends SceneTree
# ============================================================================
#  CAMUFLAGEM TRANSPARENTE (Suke Suke Z) × IA DOS INIMIGOS — 15/11/2026.
#  A skill deve fazer o inimigo PERDER o jogador. Antes só o modelo ficava translúcido e toda IA
#  seguia perseguindo. Agora, camuflado, o jogador só é sentido a ≤ 4 m (CerebroDeInimigo e CerebroMinePiece).
#    godot --headless --path . --script tools/dev_tests/test_camuflagem_inimigos.gd
# ============================================================================
var _ok_n := 0
var _falhas := 0

func _ok(cond: bool, rotulo: String) -> void:
	if cond: _ok_n += 1
	else: _falhas += 1
	print("   %s %s" % ["✓" if cond else "❌", rotulo])

func quadros(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	executar.call_deferred()

func executar() -> void:
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("mapa_forcado", "res://tools/dev_tests/fixtures/mapa_baseplate.json")
	modo.set("progresso_forcado", "user://test_camuflagem.json")
	root.get_node("GameFlow").start_story()
	await quadros(200)
	var j = get_first_node_in_group("player")
	j.set_meta("damage_immune", true)
	j.global_position = Vector3(0, 1, 0)
	var boneco := BonecoDeDuelo.new()
	current_scene.add_child(boneco)
	boneco.global_position = Vector3(0, 1, -10)
	var cerebro := CerebroDeInimigo.new()
	current_scene.add_child(cerebro)
	cerebro.montar(boneco, func(): return j, Vector3(0, 0, -10), 0.0)
	cerebro.set_physics_process(false)      # só se mede a ESCOLHA do alvo; o boneco não corre atrás do jogador no meio do teste
	await quadros(5)
	_ok(not j.esta_camuflado(), "o jogador começa visível")
	_ok(cerebro._alvo_valido() == j, "visível a 10 m: o inimigo vê o jogador")
	modo.equipar_fruta(j, "")
	j.equip_fruit("suke_suke")
	await quadros(10)
	j.call("_aplicar_invisibilidade", true)
	boneco.global_position = Vector3(0, 1, -10)
	_ok(j.esta_camuflado(), "camuflagem ligada: esta_camuflado()")
	j.global_position = Vector3(0, 1, 0)      # posições fixadas no mesmo quadro da checagem (o jogador se mexe entre quadros)
	boneco.global_position = Vector3(0, 1, -10)
	_ok(cerebro._alvo_valido() == null, "camuflado a 10 m: o inimigo perde o jogador")
	j.global_position = Vector3(0, 1, -7.5)      # a 2,5 m do boneco
	boneco.global_position = Vector3(0, 1, -10)
	_ok(cerebro._alvo_valido() == j, "camuflado a 2,5 m: o inimigo ainda o sente")
	j.call("_aplicar_invisibilidade", false)
	_ok(cerebro._alvo_valido() == j, "revelado: o inimigo volta a ver o jogador")
	modo.set("mapa_forcado", "")
	modo.set("progresso_forcado", "")
	print("\nCAMUFLAGEM %d conferem | %d divergem" % [_ok_n, _falhas])
	quit(1 if _falhas > 0 else 0)
