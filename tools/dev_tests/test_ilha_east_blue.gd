extends SceneTree
## Ilha do East Blue no MAPA VIVO (17/10/2026): a ilha está cadastrada, os personagens das
## peças `mine_piece` nascem vivos na zona certa, com o modelo do mod (quando presente) e a
## IA; o jogador que chega a Orange Town é atacado pelo bando do Buggy.
##   "$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_ilha_east_blue.gd

const CENTRO := Vector3(3000, 0, 0)
var passou := 0
var falhas := 0


func _init() -> void: _rodar.call_deferred()


func frames(n: int) -> void:
	for i in n: await physics_frame


func ok(nome: String, cond: bool) -> void:
	print("%s %s" % ["OK" if cond else "FALHA", nome])
	if cond: passou += 1
	else: falhas += 1


func _rodar() -> void:
	await process_frame
	ok("a ilha está no cadastro", preload("res://src/historia/ilhas/ilhas.gd").existe("ilha_east_blue"))
	var modo = load("res://src/historia/ModoHistoria.gd")
	modo.set("progresso_forcado", "user://test_ilha_east_blue.json")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_ilha_east_blue.json"))
	root.get_node("GameFlow").start_story()
	await frames(240)
	# Os `mp_*` também povoam as ilhas das estruturas (18/10/2026, a 750 m ou mais): só os desta.
	var todos := get_nodes_in_group("personagens_east_blue").filter(func(p: Node3D):
		return Vector2(p.global_position.x - CENTRO.x, p.global_position.z - CENTRO.z).length() < 400.0)
	ok("63 personagens vivos na ilha (%d)" % todos.size(), todos.size() == 63)
	var por_zona := {}
	var com_modelo := 0
	var longe := 0
	for p: PersonagemMinePiece in todos:
		por_zona[str(p.ficha.zona)] = int(por_zona.get(str(p.ficha.zona), 0)) + 1
		if p.find_child("AnimationPlayer", true, false) != null:
			com_modelo += 1
		if Vector2(p.global_position.x - CENTRO.x, p.global_position.z - CENTRO.z).length() > 200.0:
			longe += 1
	print("  por zona: ", por_zona)
	ok("todos dentro da placa da ilha (%d fora)" % longe, longe == 0)
	ok("todos com o modelo convertido do mod (%d/%d)" % [com_modelo, todos.size()], com_modelo == todos.size())
	ok("Shanks é chefe e o bando dele é aliado", _achar(todos, "shanks") != null and _achar(todos, "shanks").is_in_group(BarrasDeChefes.GRUPO)
		and str(_achar(todos, "lucky_roux").ficha.faccao) == "aliado")

	# Chegando em Orange Town: o bando do Buggy reage.
	var p: Node3D = get_first_node_in_group("player")
	var buggy := _achar(todos, "buggy")
	var perto := buggy.global_position + Vector3(6, 1.5, 0)
	p.global_position = perto
	var vida0: float = p.health
	var atacou := false
	Mc.contadores.clear()
	for i in 900:
		await physics_frame
		if i % 30 == 0:
			p.global_position = perto
		atacou = atacou or buggy.cerebro.alvo == p
	var golpes := 0
	for k: String in Mc.contadores:
		if k.begins_with("hurt:jogador:vivo:"):
			golpes += int(Mc.contadores[k])
	print("  golpes da IA do mod no jogador: %d · distância final %.1f m" % [golpes, buggy.global_position.distance_to(p.global_position)])
	ok("o Buggy mira o jogador que chegou (alvo=%s, vida %.0f → %.0f)" % [str(buggy.cerebro.alvo), vida0, p.health], atacou)
	ok("e o jogador apanha (%d golpes da IA do mod)" % golpes, golpes > 0)

	print("\nILHA_EAST_BLUE: %d passaram / %d falharam" % [passou, falhas])
	modo.set("progresso_forcado", "")
	quit(1 if falhas > 0 else 0)


func _achar(todos: Array, id: String) -> PersonagemMinePiece:
	for p: PersonagemMinePiece in todos:
		if p.id_personagem == id:
			return p
	return null
