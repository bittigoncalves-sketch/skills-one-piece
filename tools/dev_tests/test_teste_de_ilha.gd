extends SceneTree
# ============================================================================
#  LANÇADOR DE TESTE DE ILHA (18/10/2026, docs/ESTRUTURAS_MINE_PIECE_PLANO.md, E0).
#
#    "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_teste_de_ilha.gd [-- --ilha=<id>]
#
#  No MAPA VIVO: o jogador nasce na última ilha do cadastro, com dash, pulo no ar e a
#  Pika Pika; morre e renasce na mesma ilha; o save real não é tocado.
# ============================================================================

const TesteDeIlha := preload("res://src/historia/teste_de_ilha.gd")
const SAVE_REAL := "user://historia/progresso.json"

var total := 0
var falhas := 0


func _init() -> void:
	rodar.call_deferred()


func ok(cond: bool, msg: String) -> void:
	total += 1
	falhas += 0 if cond else 1
	print(("  ✅ " if cond else "  ❌ ") + msg)


func quadros(n: int) -> void:
	for i in n:
		await physics_frame


func rodar() -> void:
	await process_frame
	var antes := FileAccess.get_sha256(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	var args := PackedStringArray(["--teste-ilha"]) + OS.get_cmdline_user_args()
	var id := TesteDeIlha.ilha(args)
	ok(TesteDeIlha.preparar(args).is_empty(), "prepara o progresso de teste (ilha %s)" % id)
	ok(TesteDeIlha.preparar(PackedStringArray(["--ilha=nao_existe"])).begins_with("ilha desconhecida"),
		"ilha inexistente é recusada com motivo")
	TesteDeIlha.preparar(args)
	root.get_node("GameFlow").start_story()
	# Sem o tipo `Player`: no `--script` ele compilaria antes dos autoloads (FruitNet).
	var jogador: Node3D = null
	for i in 900:
		await physics_frame
		jogador = get_first_node_in_group("player") as Node3D
		if jogador != null and i > 60 and _na_ilha(jogador, id):
			break
	ok(jogador != null, "o jogador nasceu")
	if jogador == null:
		quit(1)
		return
	await quadros(30)
	ok(_na_ilha(jogador, id), "nasceu na ilha %s: %s" % [id, jogador.global_position])
	ok((jogador.get("ponto_de_renascimento") as Vector3).distance_to(jogador.global_position) < 3.0, "o ponto de renascer é ali")
	ok(jogador.get("capacidades").can_double_jump, "pulo no ar liberado")
	ok(jogador.get("capacidades").can_dash, "dash liberado")
	ok(jogador.get("current_fruit_id") == TesteDeIlha.FRUTA, "fruta equipada: %s" % jogador.get("current_fruit_id"))
	var ponto: Vector3 = jogador.get("ponto_de_renascimento")
	jogador.global_position += Vector3(40, 0, 25)
	jogador.call("die_and_respawn")
	var voltou := false
	for i in 900:
		await physics_frame
		if jogador.global_position.distance_to(ponto) < 3.0:
			voltou = true
			break
	ok(voltou, "morreu e renasceu na ilha (%s)" % jogador.global_position)
	var depois := FileAccess.get_sha256(SAVE_REAL) if FileAccess.file_exists(SAVE_REAL) else ""
	ok(antes == depois, "o save real ficou intocado")
	print("\n%d/%d" % [total - falhas, total])
	quit(1 if falhas > 0 else 0)


func _na_ilha(j: Node3D, id: String) -> bool:
	var caixas: Dictionary = current_scene.get("_ilhas").caixas if current_scene and current_scene.get("_ilhas") else {}
	var c: Rect2 = caixas.get(id, Rect2())
	return c.has_area() and c.grow(40.0).has_point(Vector2(j.global_position.x, j.global_position.z))
